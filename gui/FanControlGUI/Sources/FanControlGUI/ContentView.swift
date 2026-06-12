import SwiftUI

struct ContentView: View {
    @EnvironmentObject var daemon: DaemonManager

    var body: some View {
        VStack(spacing: 10) {
            if daemon.daemonOnline {
                temperatureView
                modePicker
                activeModeView
            } else {
                offlineView
            }

            Divider()
            footerView
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onAppear { daemon.refresh() }
    }

    private var temperatureView: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Average temperature")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(temperatureText)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
            }
            Spacer()
            if let autoRPM = daemon.autoTemperatureRPM, daemon.controlMode == .autoTemp {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Auto RPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(autoRPM)")
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { daemon.controlMode },
            set: { daemon.setControlMode($0) }
        )) {
            ForEach(FanControlMode.allCases) { mode in
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
            AutoTempModeView()
                .environmentObject(daemon)
        }
    }

    private var offlineView: some View {
        VStack(spacing: 8) {
            Image(systemName: "fanblades.slash")
                .font(.system(size: 34))
                .foregroundColor(.secondary)
            Text("Daemon is not running")
                .font(.headline)
            Text("Run ./install.sh from the project folder")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var footerView: some View {
        HStack {
            Text(daemon.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer()
            Button("Quit") {
                daemon.quit()
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
    }

    private var temperatureText: String {
        guard let averageTemperature = daemon.averageTemperature else { return "-- C" }
        return "\(Int(averageTemperature.rounded())) C"
    }
}

struct AutoModeView: View {
    @EnvironmentObject var daemon: DaemonManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("macOS controls the fans automatically", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Use this mode for normal daily work. Manual RPM and temperature target controls are disabled.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Apply Auto Mode") {
                daemon.setAutoAll()
            }
            .buttonStyle(.borderedProminent)
        }
        .modeCard()
    }
}

struct AutoTempModeView: View {
    @EnvironmentObject var daemon: DaemonManager
    @State private var targetTemperature = 55.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target notebook temperature")
                        .font(.subheadline.weight(.semibold))
                    Text("Daemon adjusts RPM automatically")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(targetTemperature.rounded())) C")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }

            Slider(value: $targetTemperature, in: 20...95, step: 1) { editing in
                if !editing {
                    daemon.setTargetTemperature(targetTemperature)
                }
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
}

struct ManualRPMModeView: View {
    @EnvironmentObject var daemon: DaemonManager

    var body: some View {
        VStack(spacing: 10) {
            Toggle("Separate fans", isOn: $daemon.separateFans)
                .toggleStyle(.switch)

            if daemon.separateFans {
                ForEach(daemon.fans) { fan in
                    FanSliderView(
                        fan: fan,
                        onRpmChange: { rpm in
                            daemon.setFan(index: fan.index, rpm: rpm)
                        }
                    )
                }
            } else {
                CommonFanSliderView()
                    .environmentObject(daemon)
            }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
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

private extension View {
    func modeCard() -> some View {
        padding(10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
