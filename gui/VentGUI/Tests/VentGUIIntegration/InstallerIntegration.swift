import Foundation

enum InstallerIntegration {
    @MainActor static func run() async throws {
        let check = LifecycleIntegration.check
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("vent-installer-test-\(UUID().uuidString)")
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: directory) }
        let fixtureBinary = URL(fileURLWithPath: ProcessInfo.processInfo.environment["VENT_TEST_FIXTURE"]!)
        let destination = directory.appendingPathComponent("Vent's $fixture.app")
        func makeApp(_ url: URL, version: String) throws {
            let contents = url.appendingPathComponent("Contents")
            try manager.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
            try manager.copyItem(at: fixtureBinary, to: contents.appendingPathComponent("MacOS/Fixture"))
            let info: [String: Any] = ["CFBundleIdentifier": "dev.vent.installer-fixture", "CFBundleExecutable": "Fixture",
                "CFBundleShortVersionString": version, "CFBundlePackageType": "APPL", "LSUIElement": true]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: contents.appendingPathComponent("Info.plist"))
        }
        func installedVersion() -> String? {
            let info = destination.appendingPathComponent("Contents/Info.plist")
            guard let data = try? Data(contentsOf: info),
                  let object = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
            return object["CFBundleShortVersionString"] as? String
        }
        try makeApp(destination, version: "1.3.9-beta.1")
        let badDMG = directory.appendingPathComponent("bad.dmg")
        try Data("invalid image".utf8).write(to: badDMG)
        do {
            _ = try AppUpdateInstaller.prepare(dmg: badDMG, destination: destination, version: "1.3.9")
            check(false, "corrupt DMG must fail before replacing app")
        } catch { check(installedVersion() == "1.3.9-beta.1", "bad DMG preserves installed app") }
        let dmg = URL(fileURLWithPath: ProcessInfo.processInfo.environment["VENT_TEST_DMG"]!)
        let imageVersion = ProcessInfo.processInfo.environment["VENT_TEST_DMG_VERSION"]!
        let ready = try AppUpdateInstaller.prepare(dmg: dmg, destination: destination, version: imageVersion)
        check(installedVersion() == "1.3.9-beta.1", "validated DMG staged without touching app")
        ready.discard()
        do {
            _ = try AppUpdateInstaller.prepare(dmg: dmg, destination: destination, version: "9.9.9")
            check(false, "wrong version must fail")
        } catch { check(installedVersion() == "1.3.9-beta.1", "wrong version preserves installed app") }

        // Execute the production replacement script and real LaunchServices open.
        // Only this tiny fixture is launched: no Vent delegate or hardware helper.
        let workspace = directory.appendingPathComponent("staging")
        try manager.createDirectory(at: workspace, withIntermediateDirectories: false)
        let staged = workspace.appendingPathComponent("Vent.app")
        try makeApp(staged, version: "1.3.9")
        let sleeper = Process()
        sleeper.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleeper.arguments = ["0.8"]
        try sleeper.run()
        let prepared = AppUpdateInstaller.Prepared(workspace: workspace, app: staged, destination: destination)
        try prepared.launch(waitingFor: sleeper.processIdentifier)
        try? await Task.sleep(nanoseconds: 150_000_000)
        check(installedVersion() == "1.3.9-beta.1", "replacement waits for old PID")
        await LifecycleIntegration.waitUntil("replacement completed") { !manager.fileExists(atPath: workspace.path) }
        check(installedVersion() == "1.3.9", "stable replaces beta at same path")
        let marker = directory.appendingPathComponent("started")
        await LifecycleIntegration.waitUntil("new fixture relaunched") { manager.fileExists(atPath: marker.path) }
        let started = try String(contentsOf: marker, encoding: .utf8)
        check(started == "1.3.9|beta", "restart preserves beta channel preference")
        try manager.removeItem(at: marker)

        let rollback = directory.appendingPathComponent("rollback")
        try manager.createDirectory(at: rollback, withIntermediateDirectories: false)
        let failed = AppUpdateInstaller.Prepared(workspace: rollback, app: rollback.appendingPathComponent("missing.app"), destination: destination)
        // The child has already exited, so this tests a failure after backup rename.
        sleeper.waitUntilExit()
        try failed.launch(waitingFor: sleeper.processIdentifier)
        await LifecycleIntegration.waitUntil("rollback completed") { !manager.fileExists(atPath: rollback.path) }
        check(installedVersion() == "1.3.9", "failed replacement restores previous bundle")
        await LifecycleIntegration.waitUntil("previous fixture relaunched") { manager.fileExists(atPath: marker.path) }

        let defaults = UserDefaults(suiteName: "dev.vent.helper-update-tests")!
        defer { defaults.removePersistentDomain(forName: "dev.vent.helper-update-tests") }
        defaults.set(true, forKey: VentDaemonManager.pendingDaemonUpdateKey)
        defaults.set("1.3.9", forKey: VentDaemonManager.pendingDaemonVersionKey)
        check(!VentDaemonManager.consumePendingHelperUpdate(currentVersion: "1.3.9-beta.1", defaults: defaults), "rollback does not update helper")
        defaults.set(true, forKey: VentDaemonManager.pendingDaemonUpdateKey)
        defaults.set("1.3.9", forKey: VentDaemonManager.pendingDaemonVersionKey)
        check(VentDaemonManager.consumePendingHelperUpdate(currentVersion: "1.3.9", defaults: defaults), "matching stable updates helper")
        check(!VentDaemonManager.consumePendingHelperUpdate(currentVersion: "1.3.9", defaults: defaults), "helper update consumed once")
        defaults.set(true, forKey: VentDaemonManager.pendingDaemonUpdateKey)
        check(VentDaemonManager.consumePendingHelperUpdate(currentVersion: "1.3.9", defaults: defaults), "legacy beta helper flag supported")
        print("PASS installer preparation, beta replacement, rollback and preferences")
    }
}
