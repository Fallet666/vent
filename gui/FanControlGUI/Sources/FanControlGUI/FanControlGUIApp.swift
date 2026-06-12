import AppKit
import SwiftUI

@main
struct FanControlGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let popoverContent = ContentView()
            .environmentObject(DaemonManager.shared)
            .environment(\.controlActiveState, .key)
            .frame(width: 320)
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverContent)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            button.title = ""
            button.image = loadMenuBarImage()
            button.target = self
            button.action = #selector(togglePopover)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        DaemonManager.shared.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func quit() {
        DaemonManager.shared.quit()
    }

    private func loadMenuBarImage() -> NSImage? {
        let image = Bundle.main.url(forResource: "MacFanMenuBarTemplate", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        return image
    }
}

@MainActor
final class DaemonManager: ObservableObject {
    static let shared = DaemonManager()

    @Published var fans: [FanState] = []
    @Published var daemonOnline = false
    @Published var statusMessage = "Connecting..."
    @Published var averageTemperature: Double?
    @Published var controlMode: FanControlMode = .auto
    @Published var targetTemperature: Double = 55
    @Published var autoTemperatureRPM: Int?
    @Published var separateFans = false

    private var refreshTask: Task<Void, Never>?
    private var smoothedAverageTemperature: Double?

    private init() {
        startRefreshLoop()
    }

    func refresh() {
        daemonOnline = DaemonClient.shared.isRunning()
        guard daemonOnline else {
            fans = []
            averageTemperature = nil
            statusMessage = "Daemon offline - run install.sh"
            return
        }

        let daemonFans = DaemonClient.shared.fans() ?? []
        fans = daemonFans.map { fan in
            let preferredRPM = fan.targetRPM > 0 ? fan.targetRPM : fan.currentRPM
            let safeRPM = preferredRPM > 0 ? preferredRPM : fan.minRPM
            return FanState(
                index: fan.index,
                rpm: safeRPM,
                currentRPM: fan.currentRPM,
                minRPM: fan.minRPM,
                maxRPM: fan.maxRPM,
                manualMode: fan.manualMode
            )
        }

        let temperatures = DaemonClient.shared.temperatures() ?? []
        let fallbackAverageTemperature = averageTemperature(from: temperatures)
        if let modeStatus = DaemonClient.shared.modeStatus() {
            controlMode = modeStatus.mode
            targetTemperature = modeStatus.targetTemperature
            averageTemperature = smoothedTemperature(modeStatus.averageTemperature ?? fallbackAverageTemperature)
            autoTemperatureRPM = modeStatus.autoRPM
        } else {
            averageTemperature = smoothedTemperature(fallbackAverageTemperature)
        }
        statusMessage = "Daemon online - \(fans.count) fan(s)"
    }

    func setControlMode(_ mode: FanControlMode) {
        guard daemonOnline else { return }
        let ok = DaemonClient.shared.setMode(mode, targetTemperature: targetTemperature)
        if ok {
            controlMode = mode
            statusMessage = "Mode: \(mode.title)"
            refresh()
        } else {
            statusMessage = "Failed to set \(mode.title)"
        }
    }

    func setTargetTemperature(_ temperature: Double) {
        targetTemperature = min(max(temperature, 20), 95)
        guard daemonOnline, controlMode == .autoTemp else { return }
        statusMessage = DaemonClient.shared.setMode(.autoTemp, targetTemperature: targetTemperature) ?
            "Target temperature \(Int(targetTemperature.rounded())) C" : "Failed to set target temperature"
    }

    func setFan(index: Int, rpm: Int) {
        guard daemonOnline, controlMode == .manualRPM else { return }
        let clampedRPM = clamped(rpm: rpm, for: index)
        if !separateFans {
            for fanIndex in fans.indices {
                fans[fanIndex].rpm = clampedRPM
            }
            statusMessage = DaemonClient.shared.setAllFans(rpm: clampedRPM) ?
                "All fans set to \(clampedRPM) RPM" : "Failed to set all fans"
        } else {
            if let fanIndex = fans.firstIndex(where: { $0.index == index }) {
                fans[fanIndex].rpm = clampedRPM
            }
            statusMessage = DaemonClient.shared.setFan(index: index, rpm: clampedRPM) ?
                "Fan #\(index) set to \(clampedRPM) RPM" : "Failed to set fan #\(index)"
        }
    }

    func setAllFans(rpm: Int) {
        guard daemonOnline, controlMode == .manualRPM else { return }
        let clampedRPM = clampedForAllFans(rpm: rpm)
        for fanIndex in fans.indices {
            fans[fanIndex].rpm = clampedRPM
        }
        statusMessage = DaemonClient.shared.setAllFans(rpm: clampedRPM) ?
            "All fans set to \(clampedRPM) RPM" : "Failed to set all fans"
    }

    func setAutoAll() {
        guard daemonOnline else { return }
        statusMessage = DaemonClient.shared.setMode(.auto) ?
            "macOS controls fans automatically" : "Failed to return fans to auto mode"
        refresh()
    }

    func quit() {
        refreshTask?.cancel()
        NSApplication.shared.terminate(nil)
    }

    var commonMinRPM: Int {
        fans.map(\.minRPM).max() ?? 0
    }

    var commonMaxRPM: Int {
        fans.map(\.maxRPM).min() ?? 0
    }

    var commonRPM: Int {
        fans.first?.rpm ?? commonMinRPM
    }

    var hasValidCommonRange: Bool {
        commonMaxRPM > commonMinRPM
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func clamped(rpm: Int, for index: Int) -> Int {
        guard let fan = fans.first(where: { $0.index == index }), fan.hasValidRange else {
            return rpm
        }
        return min(max(rpm, fan.minRPM), fan.maxRPM)
    }

    private func clampedForAllFans(rpm: Int) -> Int {
        guard hasValidCommonRange else { return rpm }
        return min(max(rpm, commonMinRPM), commonMaxRPM)
    }

    private func averageTemperature(from temperatures: [DaemonTemperature]) -> Double? {
        let validTemperatures = temperatures
            .filter { temperature in
                temperature.value.isFinite &&
                    temperature.value >= 20 &&
                    temperature.value < 130 &&
                    !temperature.key.hasPrefix("Ta") &&
                    !temperature.key.hasPrefix("Tp")
            }
            .map(\.value)
        guard !validTemperatures.isEmpty else { return nil }
        return validTemperatures.reduce(0, +) / Double(validTemperatures.count)
    }

    private func smoothedTemperature(_ temperature: Double?) -> Double? {
        guard let temperature else { return smoothedAverageTemperature }
        guard let previousTemperature = smoothedAverageTemperature else {
            smoothedAverageTemperature = temperature
            return temperature
        }
        let smoothedTemperature = previousTemperature * 0.75 + temperature * 0.25
        smoothedAverageTemperature = smoothedTemperature
        return smoothedTemperature
    }
}

struct FanState: Identifiable {
    let id = UUID()
    let index: Int
    var rpm: Int
    var currentRPM: Int
    let minRPM: Int
    let maxRPM: Int
    let manualMode: Bool

    var hasValidRange: Bool {
        maxRPM > minRPM
    }
}
