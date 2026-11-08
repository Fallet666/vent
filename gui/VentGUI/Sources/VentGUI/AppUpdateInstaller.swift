import Foundation

enum AppUpdateInstaller {
    struct Prepared {
        let workspace: URL
        let app: URL
        let destination: URL

        func discard() { try? FileManager.default.removeItem(at: workspace) }

        func launch(waitingFor processID: Int32) throws {
            let scriptURL = workspace.appendingPathComponent("install.sh")
            try AppUpdateInstaller.replacementScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path, destination.path, app.path, workspace.path, String(processID)]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
        }
    }

    static func prepare(dmg: URL, destination: URL, version: String) throws -> Prepared {
        let manager = FileManager.default
        // A sibling staging directory keeps renames on the same filesystem.
        let workspace = destination.deletingLastPathComponent().appendingPathComponent(".vent-update-\(UUID().uuidString)")
        try manager.createDirectory(at: workspace, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let prepared = Prepared(workspace: workspace, app: workspace.appendingPathComponent("Vent.app"), destination: destination)
        do {
            let mount = workspace.appendingPathComponent("mount")
            try manager.createDirectory(at: mount, withIntermediateDirectories: false)
            try run("/usr/bin/hdiutil", ["attach", dmg.path, "-mountpoint", mount.path, "-readonly", "-nobrowse", "-quiet"])
            defer { try? run("/usr/bin/hdiutil", ["detach", mount.path, "-quiet", "-force"]) }
            try manager.copyItem(at: mount.appendingPathComponent("Vent.app"), to: prepared.app)
            guard let bundle = Bundle(url: prepared.app),
                  bundle.bundleIdentifier == "dev.borninvoid.macfancontrol",
                  bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", prepared.app.path])
            return prepared
        } catch {
            prepared.discard()
            throw error
        }
    }

    private static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableRuntimeMismatch) }
    }

    // All paths are positional arguments, never interpolated into shell code.
    // The old bundle survives until staging and signature checks have succeeded.
    static let replacementScript = #"""
    #!/bin/bash
    set -euo pipefail
    app=$1
    staged=$2
    workspace=$3
    old_pid=$4
    backup="$workspace/Previous.app"
    moved_old=0
    installed=0
    finish() {
        status=$?
        trap - EXIT
        if [[ "$status" != 0 && "$moved_old" == 1 ]]; then
            if [[ "$installed" == 1 ]]; then /bin/rm -rf "$app"; fi
            if ! /bin/mv "$backup" "$app"; then
                # Preserve the backup for recovery if restoring also fails.
                exit "$status"
            fi
            /usr/bin/open "$app" || true
        fi
        /bin/rm -rf "$workspace"
        exit "$status"
    }
    trap finish EXIT
    for ((attempt=0; attempt<300; attempt++)); do
        if ! kill -0 "$old_pid" 2>/dev/null; then break; fi
        /bin/sleep 0.1
    done
    if kill -0 "$old_pid" 2>/dev/null; then exit 1; fi
    /bin/mv "$app" "$backup"
    moved_old=1
    /bin/mv "$staged" "$app"
    installed=1
    /usr/bin/open "$app"
    """#
}
