#!/usr/bin/env python3
"""Publish a committed Vent release; see --help for recovery instructions."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
REPO = "Fallet666/vent"
VERSION = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(alpha|beta|rc)(?:\.(0|[1-9]\d*))?)?$")


def parse_version(value):
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError(f"Unsupported version: {value}")
    return tuple(int(part) for part in match.group(1, 2, 3)), match.group(4) is not None


def require_newer_than_latest(version, latest_tag):
    core, _ = parse_version(version)
    latest_core, latest_pre = parse_version(latest_tag.removeprefix("v"))
    if latest_pre or core <= latest_core:
        raise ValueError("Release core must be newer than the latest stable release")


def check_latest_policy(version):
    result = subprocess.run(["gh", "api", "--include", f"repos/{REPO}/releases/latest"],
                            cwd=ROOT, text=True, capture_output=True)
    if result.returncode:
        if re.match(r"^HTTP/\S+ 404(?:\s|$)", result.stdout):
            return
        raise ValueError(f"Unable to check latest stable release: {result.stderr.strip()}")
    latest = gh_json(f"repos/{REPO}/releases/latest")
    if latest.get("draft") or latest.get("prerelease"):
        raise ValueError("Latest stable release has unexpected state")
    require_newer_than_latest(version, latest["tag_name"])


def obsolete_releases(releases, stable_version):
    core, prerelease = parse_version(stable_version)
    if prerelease:
        raise ValueError("Cleanup requires a stable version")
    result = []
    for release in releases:
        try:
            release_core, is_prerelease = parse_version(release["tag_name"].removeprefix("v"))
        except (KeyError, ValueError):
            continue
        if not release.get("draft", False) and release.get("prerelease") and is_prerelease and release_core <= core:
            result.append((release["id"], release["tag_name"]))
    return result


def run(*args, cwd=ROOT, capture=False):
    return subprocess.run(args, cwd=cwd, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def verify_image(image, version, temporary):
    mount = temporary / "mount"
    mount.mkdir()
    run("hdiutil", "attach", str(image), "-mountpoint", str(mount), "-nobrowse", "-quiet", "-readonly")
    try:
        app = mount / "Vent.app"
        actual = run("/usr/libexec/PlistBuddy", "-c", "Print :CFBundleShortVersionString", str(app / "Contents/Info.plist"), capture=True).strip()
        build = run("/usr/libexec/PlistBuddy", "-c", "Print :CFBundleVersion", str(app / "Contents/Info.plist"), capture=True).strip()
        if actual != version or build != version:
            raise ValueError(f"DMG bundle version {actual}/{build} does not match {version}")
        run("codesign", "--verify", "--deep", "--strict", str(app))
    finally:
        run("hdiutil", "detach", str(mount), "-quiet")


def gh_json(*args):
    return json.loads(run("gh", "api", *args, capture=True))


def update_tap(version, sha, temporary):
    tap = temporary / "homebrew-tap"
    run("git", "clone", "https://github.com/Fallet666/homebrew-tap.git", str(tap))
    cask = tap / "Casks/vent.rb"
    content = cask.read_text()
    old = re.search(r'^\s*version "([^"]+)"', content, re.MULTILINE)
    if not old:
        raise ValueError("Cannot find Homebrew cask version")
    old_core, old_pre = parse_version(old.group(1))
    new_core, _ = parse_version(version)
    if old_core > new_core or (old_core == new_core and not old_pre and old.group(1) != version):
        raise ValueError("Homebrew cask is newer; refusing to overwrite it")
    old_sha = re.search(r'^\s*sha256 "([^"]+)"', content, re.MULTILINE)
    if old.group(1) == version and (not old_sha or old_sha.group(1) != sha):
        raise ValueError("Homebrew already points to this version with a different digest")
    content, count1 = re.subn(r'^(\s*version ")[^"]+(".*)$', rf'\g<1>{version}\2', content, count=1, flags=re.MULTILINE)
    content, count2 = re.subn(r'^(\s*sha256 ")[^"]+(".*)$', rf'\g<1>{sha}\2', content, count=1, flags=re.MULTILINE)
    if count1 != 1 or count2 != 1:
        raise ValueError("Cannot update Homebrew cask")
    cask.write_text(content)
    if run("git", "status", "--porcelain", cwd=tap, capture=True).strip():
        run("git", "add", "Casks/vent.rb", cwd=tap)
        run("git", "-c", "user.name=Vent release", "-c", "user.email=release@localhost", "commit", "-m", f"vent {version}", cwd=tap)
        run("git", "push", cwd=tap)
    pushed = run("git", "rev-parse", "HEAD", cwd=tap, capture=True).strip()
    upstream = run("git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}", cwd=tap, capture=True).strip()
    remote_head = run("git", "ls-remote", "origin", f"refs/heads/{upstream.removeprefix('origin/')}", cwd=tap, capture=True).split()
    if not remote_head or remote_head[0] != pushed:
        raise ValueError("Homebrew remote HEAD does not match the cask commit")
    final = cask.read_text()
    if not re.search(rf'^\s*version "{re.escape(version)}"\s*$', final, re.MULTILINE) or not re.search(rf'^\s*sha256 "{re.escape(sha)}"\s*$', final, re.MULTILINE):
        raise ValueError("Homebrew cask version or digest mismatch")


def main():
    parser = argparse.ArgumentParser(description="Publish an immutable committed Vent release. On partial failure inspect GitHub release, tag and tap; do not rerun blindly. Tags are retained when obsolete prereleases are removed.")
    parser.add_argument("version")
    parser.add_argument("--notes-file", type=Path)
    parser.add_argument("--artifact", type=Path, help="Existing DMG; requires sibling Vent-VERSION.build.json from the trusted build")
    args = parser.parse_args()
    _, prerelease = parse_version(args.version)
    tag = f"v{args.version}"
    branch = run("git", "branch", "--show-current", capture=True).strip()
    if not branch or (not prerelease and branch != "main"):
        raise ValueError("Stable releases require the main branch; detached HEAD is unsupported")
    origin = run("git", "remote", "get-url", "origin", capture=True).strip()
    if origin not in (f"https://github.com/{REPO}.git", f"https://github.com/{REPO}", f"git@github.com:{REPO}.git", f"git@github.com:{REPO}"):
        raise ValueError("Origin must point to the Vent GitHub repository")
    commit = run("git", "rev-parse", "HEAD", capture=True).strip()
    remote = run("git", "ls-remote", "origin", f"refs/heads/{branch}", capture=True).split()
    if not remote or remote[0] != commit:
        raise ValueError("Origin branch HEAD differs from local HEAD")
    if run("git", "status", "--porcelain", "--untracked-files=all", "--", "include", "src", "gui", "tests", "CMakeLists.txt", "package_dmg.sh", "release.sh", "scripts", capture=True).strip():
        raise ValueError("Product and release inputs must be committed and clean")
    header = (ROOT / "include/daemon_ipc.h").read_text()
    matches = re.findall(r'APP_VERSION\s*=\s*"([^"]+)"', header)
    if matches != [args.version]:
        raise ValueError("Committed APP_VERSION does not match requested version")
    if run("git", "tag", "--list", tag, capture=True).strip() or run("git", "ls-remote", "--tags", "origin", f"refs/tags/{tag}", capture=True).strip():
        raise ValueError(f"Tag {tag} already exists; refusing to overwrite")
    run("gh", "auth", "status")
    check_latest_policy(args.version)
    with tempfile.TemporaryDirectory(prefix="vent-release-") as name:
        temporary = Path(name)
        if args.artifact:
            source = args.artifact.resolve(strict=True)
            provenance = json.loads(source.with_suffix(".build.json").read_text())
            if (provenance.get("commit") != commit or provenance.get("sha256") != digest(source)
                    or provenance.get("version") != args.version or provenance.get("dirty") is not False):
                raise ValueError("Artifact provenance commit or sha256 does not match")
        else:
            run("swift", "run", "--package-path", "gui/VentGUI", "VentGUITests")
            run("./package_dmg.sh")
            source = ROOT / "dist" / f"Vent-{args.version}.dmg"
        image = temporary / f"Vent-{args.version}.dmg"
        shutil.copyfile(source, image)
        verify_image(image, args.version, temporary)
        sha = digest(image)
        # Recheck inputs and branch after a potentially long build.
        if run("git", "status", "--porcelain", "--untracked-files=all", "--", "include", "src", "gui", "tests", "CMakeLists.txt", "package_dmg.sh", "release.sh", "scripts", capture=True).strip():
            raise ValueError("Product inputs changed during build")
        if run("git", "rev-parse", "HEAD", capture=True).strip() != commit or run("git", "ls-remote", "origin", f"refs/heads/{branch}", capture=True).split()[0] != commit:
            raise ValueError("HEAD changed during build")
        sums = temporary / "SHA256SUMS"
        sums.write_text(f"{sha}  {image.name}\n")
        cmd = ["gh", "release", "create", tag, str(image), str(sums), "--repo", REPO, "--target", commit, "--title", f"Vent {args.version}"]
        cmd += ["--notes-file", str(args.notes_file.resolve(strict=True))] if args.notes_file else ["--notes", f"Release {tag}"]
        cmd += ["--prerelease", "--latest=false"] if prerelease else ["--latest"]
        check_latest_policy(args.version)
        print(f"Publishing {tag} at {commit}; SHA-256 {sha}", flush=True)
        run(*cmd)
        remote_tag = run("git", "ls-remote", "origin", f"refs/tags/{tag}", capture=True).split()
        if not remote_tag or remote_tag[0] != commit:
            raise ValueError("Published tag does not point to expected commit")
        release = gh_json(f"repos/{REPO}/releases/tags/{tag}")
        if release["draft"] or release["prerelease"] != prerelease:
            raise ValueError("Published release state is unexpected")
        (temporary / "download").mkdir()
        run("gh", "release", "download", tag, "--repo", REPO, "--pattern", image.name, "--dir", str(temporary / "download"))
        if digest(temporary / "download" / image.name) != sha:
            raise ValueError("Published asset digest mismatch")
        if prerelease:
            return
        latest = gh_json(f"repos/{REPO}/releases/latest")
        if latest["tag_name"] != tag:
            raise ValueError("Published release is not GitHub latest; leaving prereleases untouched")
        update_tap(args.version, sha, temporary)
        # --paginate with --slurp returns an array of pages, preserving all releases.
        pages = gh_json("--paginate", "--slurp", f"repos/{REPO}/releases?per_page=100")
        for release_id, old_tag in obsolete_releases([item for page in pages for item in page], args.version):
            if gh_json(f"repos/{REPO}/releases/latest")["tag_name"] != tag:
                raise ValueError("Latest release changed; stopping cleanup")
            print(f"Deleting obsolete prerelease {old_tag}; preserving tag", flush=True)
            run("gh", "api", "--method", "DELETE", f"repos/{REPO}/releases/{release_id}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, IndexError, subprocess.CalledProcessError) as error:
        print(f"Release stopped: {error}. If publication began, inspect the release, tag, asset and tap before recovery; do not rerun blindly.", file=sys.stderr)
        sys.exit(1)
