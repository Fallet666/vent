#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

show_help() {
    cat << EOF
Usage: $(basename "$0") <version>

Create a new release:
  1. Update version in source files
  2. Build DMG
  3. Upload to GitHub release
  4. Update homebrew-tap

Examples:
  $(basename "$0") 1.3.2        # Release 1.3.2
  $(basename "$0") 1.4.0 alpha # Alpha release (prerelease)

EOF
}

if [[ $# -lt 1 ]]; then
    show_help
    exit 1
fi

VERSION="$1"
PRERELEASE=""
if [[ $# -ge 2 ]] && [[ "$2" == "alpha" || "$2" == "beta" || "$2" == "rc" ]]; then
    PRERELEASE="--prerelease"
fi

TAG="v$VERSION"

echo "=== Release $VERSION ==="

cd "$PROJECT_DIR"

# 1. Update version in source
echo "[1/5] Updating version to $VERSION..."
sed -i.bak "s/APP_VERSION = \"[^\"]*\"/APP_VERSION = \"$VERSION\"/" include/daemon_ipc.h
rm -f include/daemon_ipc.h.bak

# 2. Build DMG
echo "[2/5] Building DMG..."
VERSION="$VERSION" ./package_dmg.sh

# 3. Get sha256
SHA256=$(shasum -a 256 dist/Vent-$VERSION.dmg | cut -d' ' -f1)
echo "[3/5] SHA256: $SHA256"

# 4. Create GitHub release
echo "[4/5] Creating GitHub release..."
git add -A
git commit -m "Release $TAG"
git tag "$TAG"
git push
git push origin "$TAG"

gh release create "$TAG" \
    --title "Vent $VERSION" \
    --notes "Release $TAG" \
    $PRERELEASE \
    dist/Vent-$VERSION.dmg

# 5. Update homebrew-tap
echo "[5/5] Updating homebrew-tap..."
HOMEBREW_DIR=$(mktemp -d)
git clone "https://x-access-token:${GITHUB_TOKEN:-}@github.com/${REPO_OWNER:-Fallet666}/homebrew-tap.git" "$HOMEBREW_DIR" 2>/dev/null || \
git clone "https://github.com/Fallet666/homebrew-tap.git" "$HOMEBREW_DIR"
cd "$HOMEBREW_DIR"
sed -i '' "s/version \"[^\"]*\"/version \"$VERSION\"/" Casks/vent.rb
sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"$SHA256\"/" Casks/vent.rb
git config user.email "github-actions[bot]@users.noreply.github.com"
git config user.name "GitHub Actions"
git add Casks/vent.rb
git commit -m "vent $VERSION"
git push
rm -rf "$HOMEBREW_DIR"

echo ""
echo "=== Done ==="
echo "Release: https://github.com/Fallet666/vent/releases/tag/$TAG"
