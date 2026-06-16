import SwiftUI

struct ContentView: View {
    @EnvironmentObject var daemon: DaemonManager
    @AppStorage("temperatureUnit") private var temperatureUnitRaw = TemperatureUnit.celsius.rawValue
    @AppStorage(DaemonManager.updateChecksEnabledKey) private var updateChecksAutomatically = true
    @State private var showsSettings = false

    private var temperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnitRaw) ?? .celsius
    }

    var body: some View {
        VStack(spacing: 7) {
            if showsSettings {
                settingsView
            } else {
                mainView
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
    }

    @ViewBuilder
    private var mainView: some View {
        if daemon.daemonOnline {
            temperatureView
            modePicker
            activeModeView
        } else {
            offlineView
        }
    }

    private var temperatureView: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Average temperature")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(temperatureText(daemon.averageTemperature))
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(rpmSummaryTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(rpmSummaryText)
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { daemon.controlMode },
            set: { daemon.setControlMode($0) }
        )) {
            ForEach([FanControlMode.auto, .autoTemp, .manualRPM]) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var activeModeView: some View {
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

    private var offlineView: some View {
        VStack(spacing: 7) {
            Image(systemName: "fanblades.slash")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text("FanControl needs setup")
                .font(.headline)
            Text("Open settings to install or update the helper.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                showsSettings = true
            }
            .buttonStyle(.borderedProminent)
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

            VStack(alignment: .leading, spacing: 7) {
                Text("Helper")
                    .font(.caption)
                    .foregroundColor(.secondary)
                helperVersionView
                Button(daemon.isInstalling ? "Installing..." : installButtonTitle) {
                    daemon.installOrUpdateDaemon()
                }
                .buttonStyle(.borderedProminent)
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

            updatesSettingsView

            Button("Quit FanControl") {
                daemon.quit()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
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
                    Button("Download Update") {
                        daemon.openLatestRelease()
                    }
                    .buttonStyle(.borderedProminent)
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
    @EnvironmentObject var daemon: DaemonManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("macOS is controlling fan speed", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("FanControl is not overriding RPM in this mode.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .modeCard()
    }
}

struct AutoTempModeView: View {
    @EnvironmentObject var daemon: DaemonManager
    let temperatureUnit: TemperatureUnit

    @State private var targetTemperature = 0.0

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
            }

            if let config = daemon.config {
                Slider(
                    value: $targetTemperature,
                    in: config.minTargetTemperature...config.maxTargetTemperature,
                    step: 1
                ) { editing in
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
            targetTemperature = newValue
        }
    }

    private func formattedTemperature(_ celsius: Double) -> String {
        "\(Int(temperatureUnit.convert(celsius).rounded())) \(temperatureUnit.symbol)"
    }
}

struct ManualRPMModeView: View {
    @EnvironmentObject var daemon: DaemonManager

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
    @EnvironmentObject var daemon: DaemonManager
    @State private var sliderValue: Double = 0

    var body: some View {
        FanSliderShell(
            title: "All fans",
            rpm: Int(sliderValue),
            currentRPM: daemon.fans.first?.currentRPM,
            minRPM: daemon.commonMinRPM,
            maxRPM: daemon.commonMaxRPM,
            isDisabled: !daemon.hasValidCommonRange,
            sliderValue: $sliderValue,
            onRpmChange: { daemon.setAllFans(rpm: $0) }
        )
        .onAppear { sliderValue = Double(daemon.commonRPM) }
        .onChange(of: daemon.commonRPM) { newValue in
            sliderValue = Double(newValue)
        }
    }
}

struct FanSliderView: View {
    let fan: FanState
    let onRpmChange: (Int) -> Void

    @State private var sliderValue: Double = 0

    var body: some View {
        FanSliderShell(
            title: "Fan #\(fan.index)",
            rpm: Int(sliderValue),
            currentRPM: fan.currentRPM,
            minRPM: fan.minRPM,
            maxRPM: fan.maxRPM,
            isDisabled: !fan.hasValidRange,
            sliderValue: $sliderValue,
            onRpmChange: onRpmChange
        )
        .onAppear { sliderValue = Double(fan.rpm) }
        .onChange(of: fan.rpm) { newValue in
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
                    }
                }
                Spacer()
                Text("\(rpm) RPM")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }

            if maxRPM > minRPM {
                Slider(
                    value: $sliderValue,
                    in: Double(minRPM)...Double(maxRPM),
                    step: 50
                ) {
                    Text(title)
                } onEditingChanged: { editing in
                    if !editing {
                        onRpmChange(Int(sliderValue))
                    }
                }
                .disabled(isDisabled)

                HStack {
                    Text("\(minRPM)")
                    Spacer()
                    Text("\(maxRPM)")
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
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func settingsCard() -> some View {
        padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
