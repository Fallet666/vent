import SwiftUI
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var daemon: VentDaemonManager
    @AppStorage("temperatureUnit") private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage(VentDaemonManager.updateChecksEnabledKey) private var updateChecksAutomatically = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("updateDaemonWithGUI") private var updateDaemonWithGUI = true
    @State private var launchAtLoginError: String?
    @State private var showsSettings = false
    @State private var showsProfileNameInput = false
    @State private var newProfileName = ""
    @State private var profileForRename: VentProfile?
    @State private var showsRenameInput = false
    @State private var renameText = ""

    private var temperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius
    }

    var body: some View {
        VStack(spacing: 7) {
            Group {
                if !daemon.hasCompletedOnboarding && !daemon.daemonOnline {
                    OnboardingView()
                        .environmentObject(daemon)
                        .frame(width: 296)
                } else if showsSettings {
                    settingsView
                } else {
                    mainView
                }
            }

            Divider()
            footerView
        }
        .padding(.horizontal, 12)
        .padding(.top, 15)
        .padding(.bottom, 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.58), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.7)
        )
        .compositingGroup()
        .onAppear { daemon.refresh() }
        .alert("Save Profile", isPresented: $showsProfileNameInput) {
            TextField("Profile name", text: $newProfileName)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                let trimmedName = newProfileName.trimmingCharacters(in: .whitespaces)
                if !trimmedName.isEmpty {
                    daemon.saveCurrentAsProfile(name: trimmedName)
                }
            }
        }
        .alert("Rename Profile", isPresented: $showsRenameInput) {
            TextField("Profile name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                let trimmedName = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmedName.isEmpty, let profile = profileForRename {
                    daemon.renameProfile(profile, newName: trimmedName)
                }
            }
        }
    }

    @ViewBuilder
    private var mainView: some View {
        if daemon.daemonOnline {
            temperatureView
            noiseWarningBanner
            profilePickerView
            modePicker
            activeModeView
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        } else {
            offlineView
        }
    }

    private var temperatureView: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Temperature")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(temperatureText(daemon.averageTemperature))
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: daemon.averageTemperature)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(rpmSummaryTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(rpmSummaryText)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: rpmSummaryText)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            if #available(macOS 26, *) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.08))
            }
        }
    }

    private var fansNoiseLevel: Double? {
        let maxFanRPMs = daemon.fans.map { Double($0.maxRPM) }
        let currentRPMs = daemon.fans.map { Double($0.currentRPM) }
        guard let maxMax = maxFanRPMs.max(), maxMax > 0 else { return nil }
        let maxCurrent = currentRPMs.max()!
        let ratio = maxCurrent / maxMax
        return ratio >= 0.7 ? ratio : nil
    }

    private var noiseWarningBanner: some View {
        Group {
            if let level = fansNoiseLevel {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption2)
                    Text("Fans at \(Int(level * 100))% — may be loud")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: fansNoiseLevel != nil)
    }

    private var profilePickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(daemon.profiles) { profile in
                    let isSelected = daemon.selectedProfileID == profile.id
                    Button {
                        daemon.applyProfile(profile)
                    } label: {
                        Text(profile.name)
                            .font(.caption)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 1.2 : 0.7)
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !profile.isStockProfile {
                            Button("Rename") {
                                profileForRename = profile
                                renameText = profile.name
                                showsRenameInput = true
                            }
                            Button("Delete", role: .destructive) {
                                withAnimation {
                                    daemon.deleteProfile(profile)
                                }
                            }
                        }
                    }
                }
                Button {
                    newProfileName = ""
                    showsProfileNameInput = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.7)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!daemon.daemonOnline)
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { daemon.controlMode },
            set: { daemon.setControlMode($0) }
        )) {
            ForEach([VentMode.auto, .autoTemp, .manualRPM]) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .modeCard()
    }

    private var activeModeView: some View {
        Group {
            switch daemon.controlMode {
            case .auto:
                AutoModeView()
                    .environmentObject(daemon)
            case .manualRPM:
                ManualRPMModeView()
                    .environmentObject(daemon)
            case .autoTemp:
                AutoTempModeView(temperatureUnit: temperatureUnit)
                    .environmentObject(daemon)
            }
        }
    }

    private var offlineView: some View {
        VStack(spacing: 7) {
            Image(systemName: "fanblades.slash")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
                .symbolVariant(.slash)
            Text("Vent needs setup")
                .font(.headline)
            Text("Open settings to install or update the helper.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                showsSettings = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Settings", systemImage: "gearshape")
                    .font(.headline)
                Spacer()
                Text("Manage helper and preferences")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Temperature Unit")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("Temperature Unit", selection: $temperatureUnitRaw) {
                    ForEach(TemperatureUnit.allCases) { unit in
                        Text(unit.title).tag(unit.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            .settingsCard()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            launchAtLoginError = nil
                        } catch {
                            launchAtLogin = !newValue
                            launchAtLoginError = error.localizedDescription
                        }
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .settingsCard()

            VStack(alignment: .leading, spacing: 7) {
                Text("Helper")
                    .font(.caption)
                    .foregroundColor(.secondary)
                helperVersionView
                Button(daemon.isInstalling ? "Installing..." : installButtonTitle) {
                    daemon.installOrUpdateDaemon()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(daemon.isInstalling || daemon.isUninstalling)
                if daemon.daemonOnline, daemon.helperVersion != nil {
                    Button(daemon.isUninstalling ? "Removing..." : "Uninstall Helper") {
                        daemon.confirmAndUninstallDaemon()
                    }
                    .foregroundColor(.red)
                    .disabled(daemon.isInstalling || daemon.isUninstalling)
                }
            }
            .settingsCard()

            VStack(alignment: .leading, spacing: 7) {
                Text("Profiles")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(daemon.profiles) { profile in
                    Button {
                        daemon.applyProfile(profile)
                    } label: {
                        HStack {
                            Text(profile.name)
                            Spacer()
                            if daemon.selectedProfileID == profile.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                            if !profile.isStockProfile {
                                Button("Rename") {
                                    profileForRename = profile
                                    renameText = profile.name
                                    showsRenameInput = true
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                                if daemon.profiles.count > 1 {
                                    Button("Delete") {
                                        withAnimation {
                                            daemon.deleteProfile(profile)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
            .settingsCard()

            updatesSettingsView
        }
        .onChange(of: updateChecksAutomatically) { newValue in
            if newValue {
                daemon.checkForUpdates(manual: false)
            } else {
                daemon.updateCheckMessage = nil
            }
        }
    }

    private var helperVersionView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("App version: \(daemon.bundledVersion)")
            Text("Helper version: \(daemon.helperVersion ?? "not installed")")
            if daemon.helperNeedsUpdate && daemon.daemonOnline {
                Text("Update available")
                    .foregroundColor(.orange)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }

    private var updatesSettingsView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Updates")
                .font(.caption)
                .foregroundColor(.secondary)
            Toggle("Check for updates automatically", isOn: $updateChecksAutomatically)
            Toggle("Update helper with app", isOn: $updateDaemonWithGUI)
                .help("When updating the app, also install the bundled helper daemon at the same time.")
            if let updateCheckMessage = daemon.updateCheckMessage {
                Text(updateCheckMessage)
                    .font(.caption)
                    .foregroundColor(daemon.appUpdateAvailable ? .orange : .secondary)
            }
            HStack(spacing: 8) {
                Button(daemon.isCheckingForUpdates ? "Checking..." : "Check Now") {
                    daemon.checkForUpdates(manual: true)
                }
                .disabled(daemon.isCheckingForUpdates)

                if daemon.appUpdateAvailable {
                    if daemon.isDownloadingUpdate {
                        ProgressView(value: daemon.updateDownloadProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 100)
                    } else if daemon.isInstallingUpdate {
                        Text("Installing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Install Update") {
                            daemon.downloadAndInstallUpdate()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                }
            }
        }
        .settingsCard()
    }

    private var footerView: some View {
        HStack(spacing: 8) {
            Button {
                showsSettings.toggle()
            } label: {
                Image(systemName: showsSettings ? "xmark" : "gearshape")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help(showsSettings ? "Close settings" : "Settings")
            Spacer()
            Button("Quit") {
                daemon.quit()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundColor(.red)
        }
    }

    private var rpmSummaryTitle: String {
        switch daemon.controlMode {
        case .auto: return "Fan RPM"
        case .manualRPM: return "Target RPM"
        case .autoTemp: return "Auto RPM"
        }
    }

    private var rpmSummaryText: String {
        guard let rpm = rpmSummaryValue else { return "--" }
        return "\(rpm)"
    }

    private var rpmSummaryValue: Int? {
        if daemon.controlMode == .autoTemp, let autoRPM = daemon.autoTemperatureRPM {
            return autoRPM
        }
        let values = daemon.fans.compactMap { fan -> Int? in
            if daemon.controlMode == .manualRPM {
                return fan.rpm > 0 ? fan.rpm : nil
            }
            if fan.currentRPM > 0 {
                return fan.currentRPM
            }
            return fan.rpm > 0 ? fan.rpm : nil
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / values.count
    }

    private var installButtonTitle: String {
        if !daemon.daemonOnline {
            return "Install Helper"
        }
        guard daemon.helperVersion != nil else {
            return "Install Helper"
        }
        return daemon.helperNeedsUpdate ? "Update Helper" : "Reinstall Helper"
    }

    private func temperatureText(_ celsius: Double?) -> String {
        guard let celsius else { return "-- \(temperatureUnit.symbol)" }
        return "\(Int(temperatureUnit.convert(celsius).rounded())) \(temperatureUnit.symbol)"
    }
}

struct AutoModeView: View {
    @EnvironmentObject var daemon: VentDaemonManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("macOS is controlling fan speed", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Vent is not overriding RPM in this mode.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .modeCard()
    }
}

struct AutoTempModeView: View {
    @EnvironmentObject var daemon: VentDaemonManager
    let temperatureUnit: TemperatureUnit

    @State private var targetTemperature = 0.0
    @State private var isEditingTemperature = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Target temperature")
                        .font(.subheadline.weight(.semibold))
                    Text("Fans adjust automatically")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(formattedTemperature(targetTemperature))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: targetTemperature)
            }

            if let config = daemon.config {
                NativeSlider(
                    value: $targetTemperature,
                    range: config.minTargetTemperature...config.maxTargetTemperature,
                    step: 1
                ) { editing in
                    isEditingTemperature = editing
                    if !editing {
                        daemon.setTargetTemperature(targetTemperature)
                    }
                }
            } else {
                Text("Waiting for helper config...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Cooler")
                Spacer()
                Text("Quieter")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .modeCard()
        .onAppear { targetTemperature = daemon.targetTemperature }
        .onChange(of: daemon.targetTemperature) { newValue in
            guard !isEditingTemperature else { return }
            targetTemperature = newValue
        }
    }

    private func formattedTemperature(_ celsius: Double) -> String {
        "\(Int(temperatureUnit.convert(celsius).rounded())) \(temperatureUnit.symbol)"
    }
}

struct ManualRPMModeView: View {
    @EnvironmentObject var daemon: VentDaemonManager

    var body: some View {
        VStack(spacing: 7) {
            Toggle("Separate fans", isOn: $daemon.separateFans)
                .toggleStyle(.switch)
                .onChange(of: daemon.separateFans) { _ in
                    AppDelegate.requestPanelResize()
                }

            if daemon.separateFans {
                if daemon.fans.count <= 2 {
                    VStack(spacing: 7) {
                        separateFanSliders
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 7) {
                            separateFanSliders
                        }
                    }
                    .frame(maxHeight: 260)
                }
            } else {
                CommonFanSliderView()
                    .environmentObject(daemon)
            }
        }
    }

    private var separateFanSliders: some View {
        ForEach(daemon.fans) { fan in
            FanSliderView(
                fan: fan,
                onRpmChange: { rpm in
                    daemon.setFan(index: fan.index, rpm: rpm)
                }
            )
        }
    }
}

struct CommonFanSliderView: View {
    @EnvironmentObject var daemon: VentDaemonManager
    @State private var sliderValue: Double = 0
    @State private var isEditingFanSlider = false

    var body: some View {
        FanSliderShell(
            title: "All fans",
            rpm: Int(sliderValue),
            currentRPM: daemon.fans.first?.currentRPM,
            minRPM: daemon.commonMinRPM,
            maxRPM: daemon.commonMaxRPM,
            isDisabled: !daemon.hasValidCommonRange,
            sliderValue: $sliderValue,
            isEditing: $isEditingFanSlider,
            onRpmChange: { daemon.setAllFans(rpm: $0) }
        )
        .onAppear { sliderValue = Double(daemon.commonRPM) }
        .onChange(of: daemon.commonRPM) { newValue in
            guard !isEditingFanSlider else { return }
            sliderValue = Double(newValue)
        }
    }
}

struct FanSliderView: View {
    let fan: FanState
    let onRpmChange: (Int) -> Void

    @State private var sliderValue: Double = 0
    @State private var isEditingFanSlider = false

    var body: some View {
        FanSliderShell(
            title: "Fan #\(fan.index)",
            rpm: Int(sliderValue),
            currentRPM: fan.currentRPM,
            minRPM: fan.minRPM,
            maxRPM: fan.maxRPM,
            isDisabled: !fan.hasValidRange,
            sliderValue: $sliderValue,
            isEditing: $isEditingFanSlider,
            onRpmChange: onRpmChange
        )
        .onAppear { sliderValue = Double(fan.rpm) }
        .onChange(of: fan.rpm) { newValue in
            guard !isEditingFanSlider else { return }
            sliderValue = Double(newValue)
        }
    }
}

struct FanSliderShell: View {
    let title: String
    let rpm: Int
    let currentRPM: Int?
    let minRPM: Int
    let maxRPM: Int
    let isDisabled: Bool
    @Binding var sliderValue: Double
    @Binding var isEditing: Bool
    let onRpmChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let currentRPM {
                        Text("Current \(currentRPM) RPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: currentRPM)
                    }
                }
                Spacer()
                Text("\(rpm) RPM")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: rpm)
            }

            if maxRPM > minRPM {
                NativeSlider(
                    value: $sliderValue,
                    range: Double(minRPM)...Double(maxRPM),
                    step: 50,
                    isEnabled: !isDisabled
                ) { editing in
                    isEditing = editing
                    if !editing {
                        onRpmChange(Int(sliderValue))
                    }
                }

                HStack {
                    Text("\(minRPM)")
                        .contentTransition(.numericText())
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: minRPM)
                    Spacer()
                    Text("\(maxRPM)")
                        .contentTransition(.numericText())
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: maxRPM)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            } else {
                Text("RPM range unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .modeCard()
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    var symbol: String { title }

    func convert(_ celsius: Double) -> Double {
        switch self {
        case .celsius:
            return celsius
        case .fahrenheit:
            return celsius * 9 / 5 + 32
        }
    }
}

private extension View {
    func modeCard() -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            }
    }

    func settingsCard() -> some View {
        padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if #available(macOS 26, *) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            }
    }
}
