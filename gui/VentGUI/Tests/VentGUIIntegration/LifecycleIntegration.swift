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

    @MainActor static func checkSliderScale() {
        let range = 1350.0...3275.0
        let ticks = SliderScale.multiples(of: 500, in: range)
        check(ticks == [1500, 2000, 2500, 3000], "RPM ticks align to absolute multiples")
        let rpm = SliderScale(range: range, step: 50, ticks: ticks)
        check(rpm.selection(at: 1945, magnetize: true) == 2000, "nearby drag snaps to round RPM")
        check(rpm.selection(at: 1910, magnetize: true) == 1900, "drag outside magnet keeps fine adjustment")
        check(rpm.selection(at: 1950, magnetize: false) == 1950, "keyboard can select an adjacent step")
        check(rpm.selection(at: 3275, magnetize: true) == 3275, "off-grid endpoint is reachable")

        let tempRange = 21.0...39.0
        let tempTicks = TemperatureUnit.celsius.sliderTicks(in: tempRange)
        check(tempTicks == [25, 30, 35], "temperature ticks align to absolute multiples")
        let temp = SliderScale(range: tempRange, step: 1, ticks: tempTicks)
        check(temp.selection(at: 29, magnetize: true) == 30, "temperature drag snaps near a tick")
        check(temp.selection(at: 28, magnetize: true) == 28, "other temperatures remain selectable")
        let fahrenheit = TemperatureUnit.fahrenheit
        let fahrenheitTicks = fahrenheit.sliderTicks(in: 20...35).map { fahrenheit.convert($0).rounded() }
        check(fahrenheitTicks == [70, 75, 90, 95], "Fahrenheit ticks are round and representable")

        let slider = TrackingSlider(frame: NSRect(x: 0, y: 0, width: 280, height: 28))
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.ticks = ticks
        let cell = slider.cell as! NSSliderCell
        guard let bitmap = slider.bitmapImageRepForCachingDisplay(in: slider.bounds) else {
            check(false, "AppKit slider can render")
            return
        }
        slider.cacheDisplay(in: slider.bounds, to: bitmap)
        let rects = slider.tickRects()
        check(rects.count == ticks.count, "AppKit lays out all round ticks")
        for (tick, rect) in zip(ticks, rects) {
            cell.doubleValue = tick
            check(abs(rect.midX - cell.knobRect(flipped: slider.isFlipped).midX) <= 2,
                  "tick aligns to the thumb at its numeric value")
        }
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

        if scenario == "profiles" {
            checkSliderScale()

            let delegate = NSApp.delegate as! AppDelegate
            let wasActive = NSApp.isActive
            delegate.perform(NSSelectorFromString("togglePopover"))
            let panel = NSApp.windows.compactMap { $0 as? VentPanel }.first
            check(panel?.isVisible == true && panel?.isKeyWindow == false, "panel opens without taking key status")
            delegate.perform(NSSelectorFromString("togglePopover"))
            check(panel?.isVisible == false && !manager.isPanelVisible, "status button closes non-key panel")
            delegate.perform(NSSelectorFromString("togglePopover"))
            try? await Task.sleep(nanoseconds: 250_000_000)
            check(panel?.isVisible == true && NSApp.isActive == wasActive, "rapid reopen keeps panel visible and activation unchanged")
            delegate.perform(NSSelectorFromString("togglePopover"))
            let lap = manager.profiles.first { $0.name == "Lap" }!
            let quiet = manager.profiles.first { $0.name == "Quiet" }!
            manager.isPanelVisible = true
            manager.applyProfile(lap)
            await waitUntil("Lap sent to helper") {
                VentDaemonClient.shared.modeStatus()?.targetTemperature == 30
            }
            manager.setControlMode(.auto)
            await waitUntil("Auto reached helper") { VentDaemonClient.shared.modeStatus()?.mode == .auto }
            check(manager.actualRPM == 0 && manager.targetRPM == nil, "Auto preserves stopped fan reading")
            check(manager.menuBarSummary(mask: MenuBarMetric.rpm.rawValue) == "0 RPM", "RPM-only status includes zero")
            manager.setControlMode(.autoTemp)
            await waitUntil("temperature mode restored") { VentDaemonClient.shared.modeStatus()?.mode == .autoTemp }
            check(manager.selectedProfileID == lap.id, "Lap highlighted after Auto round trip")
            manager.applyProfile(quiet)
            await waitUntil("Quiet sent as temperature profile") {
                let status = VentDaemonClient.shared.modeStatus()
                return status?.mode == .autoTemp && status?.targetTemperature == 70
            }
            let combined = MenuBarMetric.rpm.rawValue | MenuBarMetric.targetTemperature.rawValue | MenuBarMetric.profile.rawValue
            check(manager.menuBarSummary(mask: combined).contains("Quiet"), "combined menu display includes profile")
            for profile in manager.profiles { manager.deleteProfile(profile) }
            manager.loadProfiles()
            check(manager.profiles.isEmpty && manager.selectedProfileID == nil, "deleted built-in profiles stay deleted")
            NSApplication.shared.terminate(nil)
            return
        }

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
        if scenario == "updates" {
            Task { @MainActor in
                await UpdateIntegration.run()
                exit(0)
            }
            RunLoop.main.run()
            return
        }
        if scenario == "installer" {
            Task { @MainActor in
                do {
                    try await InstallerIntegration.run()
                    exit(0)
                } catch {
                    fputs("FAIL installer: \(error)\n", stderr)
                    exit(1)
                }
            }
            RunLoop.main.run()
            return
        }
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
