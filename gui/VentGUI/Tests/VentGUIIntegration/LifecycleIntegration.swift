import AppKit
import Foundation

@main
struct LifecycleIntegration {
    @MainActor static var notifications = 0

    @MainActor static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    @MainActor static func waitUntil(_ message: String, timeout: TimeInterval = 8, _ predicate: @escaping @MainActor () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        check(predicate(), message)
    }

    @MainActor static func command(_ value: String) {
        check(VentDaemonClient.shared.sendCommand("TEST " + value) == "OK", "fake helper command \(value)")
    }

    @MainActor static func run(_ scenario: String, manager: VentDaemonManager) async {
        fputs("TEST task entry: \(scenario)\n", stderr)
        if scenario == "unresponsive" {
            try? await Task.sleep(nanoseconds: 500_000_000)
            check(!manager.daemonOnline, "first probe cannot reach existing helper")
            var results: [Bool] = []
            manager.prepareForTermination { results.append($0) }
            manager.prepareForTermination { results.append($0) }
            await waitUntil("unresponsive helper rejects both quit requests") { results.count == 2 }
            check(results == [false, false], "an existing socket is not a missing helper")
            command("ONLINE")
            manager.refresh()
            await waitUntil("helper recovered") { manager.daemonOnline }
            NSApplication.shared.terminate(nil)
            return
        }
        if scenario == "first-drop" {
            await waitUntil("first VERSION in flight") { VentDaemonClient.shared.sendCommand("TEST VERSION_SEEN") == "1" }
            var results: [Bool] = []
            manager.prepareForTermination { results.append($0) }
            manager.prepareForTermination { results.append($0) }
            await waitUntil("both termination callbacks return") { results.count == 2 }
            check(results == [false, false] && !manager.isTerminating, "first heartbeat prevents offline exit; callbacks agree")
            command("ONLINE")
            NSApplication.shared.terminate(nil)
            return
        }
        if scenario == "missing" {
            try? await Task.sleep(nanoseconds: 500_000_000)
            check(!manager.daemonOnline, "missing helper remains offline")
            NSApplication.shared.terminate(nil)
            return
        }
        await waitUntil("initial refresh connected") { manager.daemonOnline && !manager.fans.isEmpty }
        check(!manager.isPanelVisible, "panel starts hidden")

        if scenario == "disabled" {
            command("RESET_COUNT")
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            check(VentDaemonClient.shared.sendCommand("TEST COUNT") == "0", "disabled hidden notifications do not poll")
            NSApplication.shared.terminate(nil)
            return
        }

        if scenario == "retry-notification" {
            command("HIGH")
            await waitUntil("failed notification retried while still loud") { notifications >= 2 }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            check(notifications == 2, "successful retry suppresses duplicates")
            NSApplication.shared.terminate(nil)
            return
        }

        if scenario == "monitor" {
            command("HIGH")
            await waitUntil("hidden high fan sends alert") { notifications == 1 }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            check(notifications == 1, "steady high fan sends only one alert")
            command("LOW")
            await waitUntil("quiet fan observed") { manager.fans.first?.currentRPM == 1000 }
            command("HIGH")
            await waitUntil("quiet to loud rearms alert") { notifications == 2 }
            command("OFFLINE")
            await waitUntil("offline detected") { !manager.daemonOnline }
            command("ONLINE")
            await waitUntil("reconnected") { manager.daemonOnline }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            check(notifications == 2, "offline reconnect while still loud does not duplicate alert")
            NSApplication.shared.terminate(nil)
            return
        }

        if scenario == "failure" || scenario == "timeout" {
            command(scenario == "failure" ? "AUTO_ERROR" : "AUTO_TIMEOUT")
            var result: Bool?
            manager.prepareForTermination { result = $0 }
            await waitUntil("failed restore returned", timeout: 9) { result != nil }
            check(result == false && !manager.isTerminating, "failed restore cancels termination")
            command("AUTO_OK")
            manager.setControlMode(.manualRPM)
            try? await Task.sleep(nanoseconds: 500_000_000)
            check(VentDaemonClient.shared.sendCommand("TEST WRITES")?.contains("MODE MANUAL") == true,
                  "controls work again after failed restore")
            command("RESET_LOG")
            NSApplication.shared.terminate(nil)
            return
        }

        // Commands accepted before exit must finish before the final Auto.
        command("DELAY_AUTO")
        manager.setControlMode(.manualRPM)
        manager.setAllFans(rpm: 2000)
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated {
                check(manager.isTerminating, "application stays alive pending delayed Auto")
                let delegate = NSApplication.shared.delegate as! AppDelegate
                check(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateLater,
                      "repeated quit shares pending termination")
                manager.setControlMode(.manualRPM)
                manager.setAllFans(rpm: 2500)
                command("GUARD_CHECKED")
            }
        }
        NSApplication.shared.terminate(nil)
    }

    @MainActor static func main() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 20) {
            fputs("FAIL: watchdog expired (main thread may be blocked)\n", stderr)
            exit(1)
        }
        fputs("TEST main entry\n", stderr)
        guard let path = ProcessInfo.processInfo.environment["VENT_SOCKET_PATH"],
              path.hasPrefix("/tmp/vent-test-"), path != "/tmp/ventd.sock" else {
            fputs("FAIL: isolated VENT_SOCKET_PATH required\n", stderr)
            exit(1)
        }
        let scenario = CommandLine.arguments.dropFirst().first ?? ""
        fputs("TEST before defaults\n", stderr)
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: VentDaemonManager.updateChecksEnabledKey)
        defaults.set(false, forKey: VentDaemonManager.pendingDaemonUpdateKey)
        defaults.set(scenario == "monitor" || scenario == "retry-notification", forKey: "loudFanNotificationEnabled")
        fputs("TEST before manager\n", stderr)
        let manager = VentDaemonManager(notifyLoudFans: { completion in
            notifications += 1
            completion(scenario != "retry-notification" || notifications > 1)
        })
        fputs("TEST after manager\n", stderr)
        let delegate = AppDelegate(daemon: manager)
        fputs("TEST before NSApplication.shared\n", stderr)
        let app = NSApplication.shared
        fputs("TEST after NSApplication.shared\n", stderr)
        app.delegate = delegate
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            fputs("FAIL: application did not terminate\n", stderr)
            exit(1)
        }
        Task { @MainActor in await run(scenario, manager: manager) }
        fputs("TEST before app.run\n", stderr)
        app.run()
        fputs("TEST after app.run\n", stderr)
        withExtendedLifetime(delegate) {}
    }
}
