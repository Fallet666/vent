import AppKit
import SwiftUI

@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static var sharedDelegate: AppDelegate?

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        sharedDelegate = delegate
        application.delegate = delegate
        application.run()
    }

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

        DispatchQueue.main.async { [weak self] in
            self?.showPopover()
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
    @Published var targetTemperature: Double = 0
    @Published var autoTemperatureRPM: Int?
    @Published var separateFans = false
    @Published var config: DaemonConfig?
    @Published var isInstalling = false

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
            statusMessage = "Daemon offline"
            return
        }

        let daemonFans = DaemonClient.shared.fans() ?? []
        if let daemonConfig = DaemonClient.shared.config() {
            config = daemonConfig
            if targetTemperature <= 0 {
                targetTemperature = daemonConfig.defaultTargetTemperature
            }
        }
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
        let modeTargetTemperature = targetTemperature > 0 ? targetTemperature : config?.defaultTargetTemperature
        let ok = DaemonClient.shared.setMode(mode, targetTemperature: modeTargetTemperature)
        if ok {
            controlMode = mode
            statusMessage = "Mode: \(mode.title)"
            refresh()
        } else {
            statusMessage = "Failed to set \(mode.title)"
        }
    }

    func setTargetTemperature(_ temperature: Double) {
        if let config {
            targetTemperature = min(max(temperature, config.minTargetTemperature), config.maxTargetTemperature)
        } else {
            targetTemperature = temperature
        }
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

    func installOrUpdateDaemon() {
        guard !isInstalling else { return }
        isInstalling = true
        statusMessage = "Requesting admin permission..."

        Task.detached {
            let result = FanControlInstaller.installOrUpdateDaemon()
            await MainActor.run {
                self.isInstalling = false
                self.statusMessage = result.message
                self.refresh()
            }
        }
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
                    temperature.value >= (config?.minUsableTemperature ?? 0) &&
                    temperature.value < (config?.maxUsableTemperature ?? Double.greatestFiniteMagnitude) &&
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

struct InstallResult {
    let success: Bool
    let message: String
}

enum FanControlInstaller {
    static func installOrUpdateDaemon() -> InstallResult {
        guard let fanctldPath = bundledOrDevelopmentBinary(named: "fanctld"),
              let fanctlPath = bundledOrDevelopmentBinary(named: "fanctl") else {
            return InstallResult(success: false, message: "Bundled daemon binaries not found")
        }

        let script = """
        set -e
        mkdir -p /usr/local/bin
        cp -f \(shellQuoted(fanctldPath)) /usr/local/bin/fanctld
        cp -f \(shellQuoted(fanctlPath)) /usr/local/bin/fanctl
        chmod 755 /usr/local/bin/fanctld /usr/local/bin/fanctl
        chown root:wheel /usr/local/bin/fanctld /usr/local/bin/fanctl 2>/dev/null || true
        launchctl bootout system/com.fanctl.daemon 2>/dev/null || true
        killall fanctld 2>/dev/null || true
        rm -f /tmp/fanctl.sock /tmp/fanctld.pid
        touch /var/log/fanctl.log /var/log/fanctl.err
        chmod 644 /var/log/fanctl.log /var/log/fanctl.err
        cat > /Library/LaunchDaemons/com.fanctl.daemon.plist << 'PLISTEOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.fanctl.daemon</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/fanctld</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>ThrottleInterval</key>
            <integer>5</integer>
            <key>StandardOutPath</key>
            <string>/var/log/fanctl.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/fanctl.err</string>
        </dict>
        </plist>
        PLISTEOF
        chmod 644 /Library/LaunchDaemons/com.fanctl.daemon.plist
        launchctl bootstrap system /Library/LaunchDaemons/com.fanctl.daemon.plist 2>/dev/null || launchctl load /Library/LaunchDaemons/com.fanctl.daemon.plist
        """

        let tempScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fancontrol-install-\(UUID().uuidString).sh")

        do {
            try script.write(to: tempScriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptURL.path)
            defer { try? FileManager.default.removeItem(at: tempScriptURL) }

            let command = "/bin/bash \(shellQuoted(tempScriptURL.path))"
            let appleScript = "do shell script \(appleScriptString(command)) with administrator privileges"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", appleScript]
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return InstallResult(success: true, message: "Daemon installed/updated")
            }
            return InstallResult(success: false, message: "Install cancelled or failed")
        } catch {
            return InstallResult(success: false, message: "Install failed: \(error.localizedDescription)")
        }
    }

    private static func bundledOrDevelopmentBinary(named name: String) -> String? {
        if let bundledURL = Bundle.main.url(forResource: name, withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundledURL.path) {
            return bundledURL.path
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        let projectFromLocalAppBundle = bundleParent.deletingLastPathComponent()
        let developmentCandidates = [
            URL(fileURLWithPath: currentDirectory).appendingPathComponent("build/\(name)").path,
            URL(fileURLWithPath: currentDirectory).deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("build/\(name)").path,
            projectFromLocalAppBundle.appendingPathComponent("build/\(name)").path,
        ]

        return developmentCandidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
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
