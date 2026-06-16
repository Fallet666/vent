import AppKit
import SwiftUI

@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let resizePanelNotification = Notification.Name("FanControlResizePanel")
    private static var sharedDelegate: AppDelegate?

    private var statusItem: NSStatusItem?
    private var panel: FanControlPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private let panelWidth: CGFloat = 320

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        sharedDelegate = delegate
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            button.title = ""
            button.image = loadMenuBarImage()
            button.target = self
            button.action = #selector(togglePopover)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resizePanelToFitContent),
            name: Self.resizePanelNotification,
            object: nil
        )
        installOutsideClickMonitors()

        DaemonManager.shared.refresh()
        DaemonManager.shared.checkForUpdatesIfEnabled()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    @objc private func togglePopover() {
        if panel?.isVisible == true && panel?.isKeyWindow == true {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPopover() {
        showPanel()
    }

    private func showPanel() {
        guard let button = statusItem?.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }
        DaemonManager.shared.refresh()

        let panel = panel ?? makePanel()
        self.panel = panel
        let panelSize = adaptivePanelSize(for: panel, screen: screen)
        panel.setContentSize(panelSize)
        panel.setFrameOrigin(panelOrigin(for: button, panelSize: panelSize, screen: screen))
        panel.displayIfNeeded()
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func closePanel() {
        panel?.orderOut(nil)
    }

    private func installOutsideClickMonitors() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.panel, event.window !== self.statusItem?.button?.window {
                self.closePanel()
            }
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePanelIfClickIsOutside()
            }
        }
    }

    private func closePanelIfClickIsOutside() {
        guard let panel, panel.isVisible else { return }
        if !panel.frame.contains(NSEvent.mouseLocation) {
            closePanel()
        }
    }

    @objc private func resizePanelToFitContent() {
        guard let panel,
              panel.isVisible else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let panel = self.panel,
                  let button = self.statusItem?.button,
                  let buttonWindow = button.window,
                  let screen = buttonWindow.screen ?? NSScreen.main else { return }
            panel.contentView?.layoutSubtreeIfNeeded()
            let panelSize = self.adaptivePanelSize(for: panel, screen: screen)
            var frame = panel.frame
            frame.origin = self.panelOrigin(for: button, panelSize: panelSize, screen: screen)
            frame.size = panelSize
            panel.setFrame(frame, display: true, animate: false)
        }
    }

    static func requestPanelResize() {
        NotificationCenter.default.post(name: resizePanelNotification, object: nil)
    }

    private func makePanel() -> FanControlPanel {
        let content = ContentView()
            .environmentObject(DaemonManager.shared)
            .environment(\.controlActiveState, .key)
            .frame(width: panelWidth)
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        let panel = FanControlPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 360),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hostingView
        return panel
    }

    private func adaptivePanelSize(for panel: NSPanel, screen: NSScreen) -> NSSize {
        panel.contentView?.layoutSubtreeIfNeeded()
        let fittingHeight = panel.contentView?.subviews.first?.fittingSize.height ?? panel.contentView?.fittingSize.height ?? 360
        let maxHeight = min(screen.visibleFrame.height - 24, 520)
        let height = min(max(fittingHeight, 250), maxHeight)
        return NSSize(width: panelWidth, height: ceil(height))
    }

    private func panelOrigin(for button: NSStatusBarButton, panelSize: NSSize, screen: NSScreen) -> NSPoint {
        guard let buttonWindow = button.window else { return NSPoint(x: 24, y: 24) }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visibleFrame = screen.visibleFrame
        let preferredX = buttonFrame.midX - panelSize.width / 2
        let preferredY = buttonFrame.minY - panelSize.height - 8
        let clampedX = min(max(preferredX, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let clampedY = max(preferredY, visibleFrame.minY + 8)
        return NSPoint(x: clampedX, y: clampedY)
    }

    @objc private func quit() {
        DaemonManager.shared.quit()
    }

    private func loadMenuBarImage() -> NSImage? {
        FanMenuBarIcon.make(size: 18)
    }
}

final class FanControlPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

@MainActor
final class DaemonManager: ObservableObject {
    static let shared = DaemonManager()
    static let updateChecksEnabledKey = "checkForUpdatesAutomatically"

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
    @Published var isUninstalling = false
    @Published var helperVersion: String?
    @Published var bundledVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    @Published var latestReleaseVersion: String?
    @Published var latestReleaseURL: URL?
    @Published var updateCheckMessage: String?
    @Published var isCheckingForUpdates = false

    private var refreshTask: Task<Void, Never>?
    private var smoothedAverageTemperature: Double?
    private let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/Fallet666/mac-manual-rpm/releases/latest")!

    private init() {
        UserDefaults.standard.register(defaults: [Self.updateChecksEnabledKey: true])
        startRefreshLoop()
    }

    func refresh() {
        daemonOnline = DaemonClient.shared.isRunning()
        guard daemonOnline else {
            fans = []
            averageTemperature = nil
            helperVersion = nil
            statusMessage = "Helper not installed"
            return
        }

        helperVersion = DaemonClient.shared.version()
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
        statusMessage = "Ready"
    }

    var helperNeedsUpdate: Bool {
        guard let helperVersion else { return !daemonOnline }
        return normalizedReleaseVersion(helperVersion) != normalizedReleaseVersion(bundledVersion)
    }

    var appUpdateAvailable: Bool {
        guard let latestReleaseVersion else { return false }
        return compareReleaseVersions(latestReleaseVersion, bundledVersion) == .orderedDescending
    }

    func checkForUpdatesIfEnabled() {
        guard UserDefaults.standard.bool(forKey: Self.updateChecksEnabledKey) else { return }
        checkForUpdates(manual: false)
    }

    func checkForUpdates(manual: Bool) {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        if manual {
            updateCheckMessage = "Checking for updates..."
        }

        Task.detached { [latestReleaseAPIURL] in
            do {
                var request = URLRequest(url: latestReleaseAPIURL)
                request.timeoutInterval = 6
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("FanControl", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                await MainActor.run {
                    self.latestReleaseVersion = release.tagName
                    self.latestReleaseURL = release.htmlURL
                    self.updateCheckMessage = self.appUpdateAvailable ?
                        "Version \(release.tagName) is available" : "FanControl is up to date"
                    self.isCheckingForUpdates = false
                }
            } catch {
                await MainActor.run {
                    if manual {
                        self.updateCheckMessage = "Could not check for updates"
                    }
                    self.isCheckingForUpdates = false
                }
            }
        }
    }

    func openLatestRelease() {
        guard let latestReleaseURL else { return }
        NSWorkspace.shared.open(latestReleaseURL)
    }

    private func normalizedReleaseVersion(_ version: String) -> String {
        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionWithoutPrefix = trimmedVersion.hasPrefix("v") ? String(trimmedVersion.dropFirst()) : trimmedVersion
        guard let releaseVersion = versionWithoutPrefix.split(separator: "-").first else {
            return versionWithoutPrefix
        }
        return String(releaseVersion)
    }

    private func compareReleaseVersions(_ leftVersion: String, _ rightVersion: String) -> ComparisonResult {
        let leftComponents = releaseVersionComponents(leftVersion)
        let rightComponents = releaseVersionComponents(rightVersion)
        let componentCount = max(leftComponents.count, rightComponents.count)

        for componentIndex in 0..<componentCount {
            let leftComponent = componentIndex < leftComponents.count ? leftComponents[componentIndex] : 0
            let rightComponent = componentIndex < rightComponents.count ? rightComponents[componentIndex] : 0
            if leftComponent > rightComponent {
                return .orderedDescending
            }
            if leftComponent < rightComponent {
                return .orderedAscending
            }
        }
        return .orderedSame
    }

    private func releaseVersionComponents(_ version: String) -> [Int] {
        normalizedReleaseVersion(version)
            .split(separator: ".")
            .map { versionPart in
                Int(versionPart.prefix { $0.isNumber }) ?? 0
            }
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
            "Target temperature updated" : "Failed to set target temperature"
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
        guard !isInstalling, !isUninstalling else { return }
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

    func uninstallDaemon() {
        guard !isInstalling, !isUninstalling else { return }
        isUninstalling = true
        statusMessage = "Requesting admin permission..."

        Task.detached {
            let result = FanControlInstaller.uninstallDaemon()
            await MainActor.run {
                self.isUninstalling = false
                self.statusMessage = result.message
                self.refresh()
            }
        }
    }

    func confirmAndUninstallDaemon() {
        guard !isInstalling, !isUninstalling else { return }
        let alert = NSAlert()
        alert.messageText = "Uninstall privileged helper?"
        alert.informativeText = "FanControl will switch fans back to Auto, stop the daemon, and remove installed helper binaries. The app itself will stay installed."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            uninstallDaemon()
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

        return runPrivilegedScript(script, successMessage: "Helper installed/updated")
    }

    static func uninstallDaemon() -> InstallResult {
        let script = """
        set -e
        if [ -S /tmp/fanctl.sock ]; then
            printf 'MODE AUTO\\n' | nc -U /tmp/fanctl.sock >/dev/null 2>&1 || true
            printf 'SHUTDOWN\\n' | nc -U /tmp/fanctl.sock >/dev/null 2>&1 || true
        fi
        launchctl bootout system/com.fanctl.daemon 2>/dev/null || true
        killall fanctld 2>/dev/null || true
        rm -f /Library/LaunchDaemons/com.fanctl.daemon.plist
        rm -f /usr/local/bin/fanctld /usr/local/bin/fanctl
        rm -f /tmp/fanctl.sock /tmp/fanctld.pid
        """

        return runPrivilegedScript(script, successMessage: "Helper uninstalled")
    }

    private static func runPrivilegedScript(_ script: String, successMessage: String) -> InstallResult {
        let tempScriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fancontrol-admin-\(UUID().uuidString).sh")

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
                return InstallResult(success: true, message: successMessage)
            }
            return InstallResult(success: false, message: "Admin action cancelled or failed")
        } catch {
            return InstallResult(success: false, message: "Admin action failed: \(error.localizedDescription)")
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
