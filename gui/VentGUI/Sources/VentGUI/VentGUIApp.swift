import AppKit
import SwiftUI

@MainActor
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let resizePanelNotification = Notification.Name("VentResizePanel")
    private static var sharedDelegate: AppDelegate?

    private var statusItem: NSStatusItem?
    private var panel: VentPanel?
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

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                self?.quit()
                return nil
            }
            return event
        }

        VentDaemonManager.shared.refresh()
        VentDaemonManager.shared.checkForUpdatesIfEnabled()

        performPendingDaemonUpdateIfNeeded()
    }

    private func performPendingDaemonUpdateIfNeeded() {
        guard UserDefaults.standard.bool(forKey: VentDaemonManager.pendingDaemonUpdateKey) else { return }
        UserDefaults.standard.set(false, forKey: VentDaemonManager.pendingDaemonUpdateKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            VentDaemonManager.shared.installOrUpdateDaemon()
        }
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
        VentDaemonManager.shared.refresh()

        let panel = panel ?? makePanel()
        self.panel = panel
        let panelSize = adaptivePanelSize(for: panel, screen: screen)
        panel.setContentSize(panelSize)
        panel.setFrameOrigin(panelOrigin(for: button, panelSize: panelSize, screen: screen))
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.animator().alphaValue = 1
        if let contentView = panel.contentView {
            contentView.layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                contentView.animator().layer?.transform = CATransform3DIdentity
            }
        }
    }

    private func closePanel() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
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

    private func makePanel() -> VentPanel {
        let content = ContentView()
            .environmentObject(VentDaemonManager.shared)
            .environment(\.controlActiveState, .key)
            .frame(width: panelWidth)
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        let panel = VentPanel(
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
        VentDaemonManager.shared.quit()
    }

    private func loadMenuBarImage() -> NSImage? {
        FanMenuBarIcon.make(size: 18)
    }
}

final class VentPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

@MainActor
final class VentDaemonManager: ObservableObject {
    static let shared = VentDaemonManager()
    static let updateChecksEnabledKey = "checkForUpdatesAutomatically"
    static let lastUpdateCheckDateKey = "lastUpdateCheckDate"
    static let onboardingCompletedKey = "onboardingCompleted"

    @AppStorage(onboardingCompletedKey) var hasCompletedOnboarding = false

    @Published var fans: [FanState] = []
    @Published var daemonOnline = false
    @Published var statusMessage = "Connecting..."
    @Published var averageTemperature: Double?
    @Published var controlMode: VentMode = .auto
    @Published var targetTemperature: Double = 0
    @Published var autoTemperatureRPM: Int?
    @Published var separateFans = false
    @Published var config: VentDaemonConfig?
    @Published var isInstalling = false
    @Published var isUninstalling = false
    @Published var helperVersion: String?
    @Published var bundledVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    @Published var latestReleaseVersion: String?
    @Published var latestReleaseURL: URL?
    @Published var updateCheckMessage: String?
    @Published var isCheckingForUpdates = false
    @Published var isRefreshing = false
    @Published var isDownloadingUpdate = false
    @Published var updateDownloadProgress: Double = 0
    @Published var isInstallingUpdate = false
    @Published var profiles: [VentProfile] = []
    @Published var selectedProfileID: UUID?

    private var refreshTask: Task<Void, Never>?
    private var smoothedAverageTemperature: Double?
    private let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/Fallet666/vent/releases/latest")!
    private var latestRelease: GitHubRelease?
    private var updateDownloader: UpdateDownloader?

    private init() {
        UserDefaults.standard.register(defaults: [
            Self.updateChecksEnabledKey: true,
            "updateDaemonWithGUI": true
        ])
        startRefreshLoop()
        loadProfiles()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let online = VentDaemonClient.shared.isRunning()
            guard online else {
                DispatchQueue.main.async {
                    self.isRefreshing = false
                    self.fans = []
                    self.averageTemperature = nil
                    self.helperVersion = nil
                    self.statusMessage = "Helper not installed"
                }
                return
            }

            let version = VentDaemonClient.shared.version()
            let daemonFans = VentDaemonClient.shared.fans() ?? []
            let daemonConfig = VentDaemonClient.shared.config()
            let temperatures = VentDaemonClient.shared.temperatures() ?? []
            let modeStatus = VentDaemonClient.shared.modeStatus()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.helperVersion = version
                if let daemonConfig {
                    self.config = daemonConfig
                    if self.targetTemperature <= 0 {
                        self.targetTemperature = daemonConfig.defaultTargetTemperature
                    }
                }
                self.fans = daemonFans.map { fan in
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

                let fallbackAverageTemperature = self.hottestTemperature(from: temperatures)
                if let modeStatus {
                    self.controlMode = modeStatus.mode
                    self.targetTemperature = modeStatus.targetTemperature
                    self.averageTemperature = self.smoothedTemperature(modeStatus.averageTemperature ?? fallbackAverageTemperature)
                    self.autoTemperatureRPM = modeStatus.autoRPM
                } else {
                    self.averageTemperature = self.smoothedTemperature(fallbackAverageTemperature)
                }
                self.daemonOnline = true
                self.statusMessage = "Ready"
                self.isRefreshing = false
            }
        }
    }

    var helperNeedsUpdate: Bool {
        guard let helperVersion else { return !daemonOnline }
        return normalizedReleaseVersion(helperVersion) != normalizedReleaseVersion(bundledVersion)
    }

    var appUpdateAvailable: Bool {
        guard let latestReleaseVersion else { return false }
        return compareReleaseVersions(latestReleaseVersion, bundledVersion) == .orderedDescending
    }

    var dmgDownloadURL: URL? {
        latestRelease?.assets.first(where: { $0.contentType == "application/x-apple-diskimage" })?.browserDownloadURL
    }

    func checkForUpdatesIfEnabled() {
        guard UserDefaults.standard.bool(forKey: Self.updateChecksEnabledKey) else { return }
        checkForUpdates(manual: false)
    }

    private static let updateCheckInterval: TimeInterval = 24 * 60 * 60

    private func shouldPerformScheduledCheck() -> Bool {
        guard UserDefaults.standard.bool(forKey: Self.updateChecksEnabledKey) else { return false }
        let lastCheckDate = UserDefaults.standard.object(forKey: Self.lastUpdateCheckDateKey) as? Date ?? .distantPast
        return Date().timeIntervalSince(lastCheckDate) >= Self.updateCheckInterval
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
                request.setValue("Vent", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                await MainActor.run {
                    UserDefaults.standard.set(Date(), forKey: Self.lastUpdateCheckDateKey)
                    self.latestRelease = release
                    self.latestReleaseVersion = release.tagName
                    self.latestReleaseURL = release.htmlURL
                    self.updateCheckMessage = self.appUpdateAvailable ?
                        "Version \(release.tagName) is available" : "Vent is up to date"
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

    static let pendingDaemonUpdateKey = "pendingDaemonUpdateAfterGUI"

    func downloadAndInstallUpdate() {
        guard let dmgURL = dmgDownloadURL else {
            updateCheckMessage = "Download URL not available"
            return
        }

        let shouldUpdateDaemon = UserDefaults.standard.bool(forKey: "updateDaemonWithGUI")
        if shouldUpdateDaemon {
            UserDefaults.standard.set(true, forKey: Self.pendingDaemonUpdateKey)
        }

        isDownloadingUpdate = true
        updateDownloadProgress = 0
        updateCheckMessage = "Starting download..."
        isCheckingForUpdates = false

        let downloader = UpdateDownloader()
        updateDownloader = downloader
        downloader.onProgressUpdate = { [weak self] progress in
            self?.updateDownloadProgress = progress
            self?.updateCheckMessage = "Downloading... \(Int(progress * 100))%"
        }
        downloader.onDownloadComplete = { [weak self] downloadResult in
            self?.updateDownloader = nil
            switch downloadResult {
            case .success(let fileURL):
                self?.performInstall(from: fileURL)
            case .failure(let downloadError):
                self?.isDownloadingUpdate = false
                self?.updateCheckMessage = "Download failed: \(downloadError.localizedDescription)"
                UserDefaults.standard.set(false, forKey: Self.pendingDaemonUpdateKey)
            }
        }
        downloader.startDownload(from: dmgURL)
    }

    private func performInstall(from dmgURL: URL) {
        isDownloadingUpdate = false
        isInstallingUpdate = true
        updateCheckMessage = "Installing..."

        let appPath = Bundle.main.bundlePath
        let mountPoint = "/tmp/fancontrol_mount"
        let scriptPath = "/tmp/fancontrol_update.sh"

        let script = """
        #!/bin/bash
        sleep 2
        /usr/bin/hdiutil attach "\(dmgURL.path)" -mountpoint "\(mountPoint)" -nobrowse -quiet
        /bin/rm -rf "\(appPath)"
        /bin/cp -R "\(mountPoint)/Vent.app" "\(appPath)"
        /usr/bin/hdiutil detach "\(mountPoint)" -quiet -force
        /bin/rm -f "\(dmgURL.path)" "\(scriptPath)"
        /usr/bin/open "\(appPath)"
        """

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath]
            try process.run()
        } catch {
            isInstallingUpdate = false
            updateCheckMessage = "Install failed: \(error.localizedDescription)"
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
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

    func setControlMode(_ mode: VentMode) {
        guard daemonOnline else { return }
        selectedProfileID = nil
        let modeTargetTemperature = targetTemperature > 0 ? targetTemperature : config?.defaultTargetTemperature
        controlMode = mode
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = VentDaemonClient.shared.setMode(mode, targetTemperature: modeTargetTemperature)
        }
    }

    func setTargetTemperature(_ temperature: Double) {
        if let config {
            targetTemperature = min(max(temperature, config.minTargetTemperature), config.maxTargetTemperature)
        } else {
            targetTemperature = temperature
        }
        selectedProfileID = nil
        guard daemonOnline, controlMode == .autoTemp else { return }
        let temp = targetTemperature
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = VentDaemonClient.shared.setMode(.autoTemp, targetTemperature: temp)
        }
    }

    func setFan(index: Int, rpm: Int) {
        guard daemonOnline else { return }
        selectedProfileID = nil
        let clampedRPM = clamped(rpm: rpm, for: index)
        let currentMode = controlMode
        let temp = targetTemperature
        let isSeparate = separateFans
        if let fanIndex = fans.firstIndex(where: { $0.index == index }) {
            fans[fanIndex].rpm = clampedRPM
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if currentMode != .manualRPM {
                VentDaemonClient.shared.setMode(.manualRPM, targetTemperature: temp)
            }
            if isSeparate {
                let _ = VentDaemonClient.shared.setFan(index: index, rpm: clampedRPM)
            } else {
                let _ = VentDaemonClient.shared.setAllFans(rpm: clampedRPM)
            }
        }
    }

    func setAllFans(rpm: Int) {
        guard daemonOnline else { return }
        selectedProfileID = nil
        let clampedRPM = clampedForAllFans(rpm: rpm)
        let currentMode = controlMode
        let temp = targetTemperature
        for fanIndex in fans.indices {
            fans[fanIndex].rpm = clampedRPM
        }
        DispatchQueue.global(qos: .userInitiated).async {
            if currentMode != .manualRPM {
                let _ = VentDaemonClient.shared.setMode(.manualRPM, targetTemperature: temp)
            }
            let _ = VentDaemonClient.shared.setAllFans(rpm: clampedRPM)
        }
    }

    func setAutoAll() {
        guard daemonOnline else { return }
        selectedProfileID = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let _ = VentDaemonClient.shared.setMode(.auto)
        }
    }

    func installOrUpdateDaemon() {
        guard !isInstalling, !isUninstalling else { return }
        isInstalling = true
        statusMessage = "Requesting admin permission..."

        Task.detached {
            let result = VentInstaller.installOrUpdateDaemon()
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
            let result = VentInstaller.uninstallDaemon()
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
        alert.informativeText = "Vent will switch fans back to Auto, stop the daemon, and remove installed helper binaries. The app itself will stay installed."
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
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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

    private func hottestTemperature(from temperatures: [VentDaemonTemperature]) -> Double? {
        let validTemperatures = temperatures
            .filter { temperature in
                temperature.value.isFinite &&
                    temperature.value >= (config?.minUsableTemperature ?? 0) &&
                    temperature.value < (config?.maxUsableTemperature ?? Double.greatestFiniteMagnitude) &&
                    !temperature.key.hasPrefix("Ta") &&
                    !temperature.key.hasPrefix("Tp") &&
                    !temperature.key.contains("cal")
            }
            .map(\.value)
        guard !validTemperatures.isEmpty else { return nil }
        return validTemperatures.max()!
    }

    private func smoothedTemperature(_ temperature: Double?) -> Double? {
        guard let temperature else { return smoothedAverageTemperature }
        guard let previousTemperature = smoothedAverageTemperature else {
            smoothedAverageTemperature = temperature
            return temperature
        }
        let smoothedTemperature = previousTemperature * 0.85 + temperature * 0.15
        smoothedAverageTemperature = smoothedTemperature
        return smoothedTemperature
    }
}

final class UpdateDownloader: NSObject, URLSessionDownloadDelegate {
    var onProgressUpdate: ((Double) -> Void)?
    var onDownloadComplete: ((Result<URL, Error>) -> Void)?
    private var session: URLSession?

    func startDownload(from downloadURL: URL) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        let task = session?.downloadTask(with: downloadURL)
        task?.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        onProgressUpdate?(progress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let stableURL = URL(fileURLWithPath: "/tmp/fancontrol_update.dmg")
        try? FileManager.default.removeItem(at: stableURL)
        do {
            try FileManager.default.moveItem(at: location, to: stableURL)
            onDownloadComplete?(.success(stableURL))
        } catch {
            onDownloadComplete?(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let downloadError = error {
            onDownloadComplete?(.failure(downloadError))
        }
    }
}

struct InstallResult {
    let success: Bool
    let message: String
}

enum VentInstaller {
    static func installOrUpdateDaemon() -> InstallResult {
        guard let ventdPath = bundledOrDevelopmentBinary(named: "ventd"),
              let ventctlPath = bundledOrDevelopmentBinary(named: "ventctl") else {
            return InstallResult(success: false, message: "Bundled daemon binaries not found")
        }

        let script = """
        set -e
        mkdir -p /usr/local/bin
        cp -f \(shellQuoted(ventdPath)) /usr/local/bin/ventd
        cp -f \(shellQuoted(ventctlPath)) /usr/local/bin/ventctl
        chmod 755 /usr/local/bin/ventd /usr/local/bin/ventctl
        chown root:wheel /usr/local/bin/ventd /usr/local/bin/ventctl 2>/dev/null || true
        launchctl bootout system/com.vent.daemon 2>/dev/null || true
        killall ventd 2>/dev/null || true
        rm -f /tmp/ventd.sock /tmp/ventd.pid
        touch /var/log/ventd.log /var/log/ventd.err
        chmod 644 /var/log/ventd.log /var/log/ventd.err
        cat > /Library/LaunchDaemons/com.vent.daemon.plist << 'PLISTEOF'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.vent.daemon</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/ventd</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>ThrottleInterval</key>
            <integer>5</integer>
            <key>StandardOutPath</key>
            <string>/var/log/ventd.log</string>
            <key>StandardErrorPath</key>
            <string>/var/log/ventd.err</string>
        </dict>
        </plist>
        PLISTEOF
        chmod 644 /Library/LaunchDaemons/com.vent.daemon.plist
        launchctl bootstrap system /Library/LaunchDaemons/com.vent.daemon.plist 2>/dev/null || launchctl load /Library/LaunchDaemons/com.vent.daemon.plist
        """

        return runPrivilegedScript(script, successMessage: "Helper installed/updated")
    }

    static func uninstallDaemon() -> InstallResult {
        let script = """
        set -e
        if [ -S /tmp/ventd.sock ]; then
            printf 'MODE AUTO\\n' | nc -U /tmp/ventd.sock >/dev/null 2>&1 || true
            printf 'SHUTDOWN\\n' | nc -U /tmp/ventd.sock >/dev/null 2>&1 || true
        fi
        launchctl bootout system/com.vent.daemon 2>/dev/null || true
        killall ventd 2>/dev/null || true
        rm -f /Library/LaunchDaemons/com.vent.daemon.plist
        rm -f /usr/local/bin/ventd /usr/local/bin/ventctl
        rm -f /tmp/ventd.sock /tmp/ventd.pid
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

struct VentProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var mode: VentMode
    var targetTemperature: Double
    var separateFans: Bool
    var fanRPMs: [Int]

    var isStockProfile: Bool {
        Self.stockProfileIDs.contains(id)
    }

    private static let stockProfileIDs: Set<UUID> = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
    ]
}

extension VentDaemonManager {
    private static let profilesKey = "savedProfiles"
    private static let selectedProfileIDKey = "selectedProfileID"

    private static let quietProfile = VentProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Quiet",
        mode: .auto,
        targetTemperature: 70,
        separateFans: false,
        fanRPMs: []
    )

    private static let normalProfile = VentProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Normal",
        mode: .autoTemp,
        targetTemperature: 45,
        separateFans: false,
        fanRPMs: []
    )

    private static let gamingProfile = VentProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Gaming",
        mode: .autoTemp,
        targetTemperature: 55,
        separateFans: false,
        fanRPMs: []
    )

    private static let lapProfile = VentProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Lap",
        mode: .autoTemp,
        targetTemperature: 30,
        separateFans: false,
        fanRPMs: []
    )

    private static var stockProfiles: [VentProfile] {
        [quietProfile, normalProfile, gamingProfile, lapProfile]
    }

    private static let stockProfileIDs: Set<UUID> = {
        [quietProfile.id, normalProfile.id, gamingProfile.id, lapProfile.id]
    }()

    func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: Self.profilesKey),
              let loaded = try? JSONDecoder().decode([VentProfile].self, from: data), !loaded.isEmpty else {
            profiles = Self.stockProfiles
            UserDefaults.standard.set(try? JSONEncoder().encode(profiles), forKey: Self.profilesKey)
            selectedProfileID = Self.normalProfile.id
            UserDefaults.standard.set(selectedProfileID?.uuidString, forKey: Self.selectedProfileIDKey)
            return
        }
        profiles = loaded
        let customProfiles = profiles.filter { !$0.isStockProfile }
        profiles = Self.stockProfiles + customProfiles
        if let savedID = UserDefaults.standard.string(forKey: Self.selectedProfileIDKey),
           let uuid = UUID(uuidString: savedID),
           profiles.contains(where: { $0.id == uuid }) {
            selectedProfileID = uuid
        } else {
            selectedProfileID = profiles.first?.id
        }
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: Self.profilesKey)
        UserDefaults.standard.set(selectedProfileID?.uuidString, forKey: Self.selectedProfileIDKey)
    }

    func saveCurrentAsProfile(name: String) {
        let rpmValues = fans.map { $0.currentRPM > 0 ? $0.currentRPM : $0.rpm }
        let newProfile = VentProfile(
            id: UUID(),
            name: name,
            mode: controlMode,
            targetTemperature: targetTemperature,
            separateFans: separateFans,
            fanRPMs: rpmValues
        )
        profiles.append(newProfile)
        selectedProfileID = newProfile.id
        persistProfiles()
    }

    func applyProfile(_ profile: VentProfile) {
        guard daemonOnline else { return }

        selectedProfileID = profile.id
        persistProfiles()

        let mode = profile.mode
        let temp = profile.targetTemperature
        let separate = profile.separateFans
        let rpms = profile.fanRPMs
        let fanCount = fans.count

        DispatchQueue.global(qos: .userInitiated).async {
            VentDaemonClient.shared.setMode(mode, targetTemperature: temp)
            if mode == .autoTemp {
                VentDaemonClient.shared.setMode(.autoTemp, targetTemperature: temp)
            }
            if mode == .manualRPM {
                if !separate, let firstRPM = rpms.first {
                    VentDaemonClient.shared.setAllFans(rpm: firstRPM)
                } else {
                    for (index, rpmValue) in rpms.enumerated() {
                        guard index < fanCount else { break }
                        VentDaemonClient.shared.setFan(index: index, rpm: rpmValue)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            if mode == .manualRPM {
                self.separateFans = separate
            }
        }
    }

    func deleteProfile(_ profile: VentProfile) {
        profiles.removeAll { $0.id == profile.id }
        if profiles.isEmpty {
            profiles = Array(Self.stockProfiles)
        }
        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }
        persistProfiles()
    }

    func renameProfile(_ profile: VentProfile, newName: String) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index].name = newName
        persistProfiles()
    }

    private func syncSelectedProfileWithDaemon(mode: VentMode, targetTemp: Double) {
        let match: VentProfile? = {
            switch mode {
            case .auto:
                return profiles.first { $0.mode == .auto && $0.isStockProfile }
            case .autoTemp:
                return profiles.filter({ $0.mode == .autoTemp && $0.isStockProfile })
                    .min(by: { abs($0.targetTemperature - targetTemp) < abs($1.targetTemperature - targetTemp) })
            case .manualRPM:
                return nil
            }
        }()
        if let match {
            selectedProfileID = match.id
            persistProfiles()
        }
    }
}
