import Foundation

enum MenuBarMetric: Int, CaseIterable, Identifiable {
    case icon = 1
    case rpm = 2
    case temperature = 4
    case targetRPM = 8
    case targetTemperature = 16
    case profile = 32

    static let preferenceKey = "menuBarMetrics"
    static let sensorKey = "menuBarTemperatureSensor"

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .icon: return String(localized: "Fan icon")
        case .rpm: return String(localized: "Fan RPM")
        case .temperature: return String(localized: "Temperature")
        case .targetRPM: return String(localized: "Target RPM")
        case .targetTemperature: return String(localized: "Target temperature")
        case .profile: return String(localized: "Profile")
        }
    }

    func isEnabled(in mask: Int) -> Bool { mask & rawValue != 0 }
}

extension VentDaemonManager {
    var actualRPM: Int? {
        let values = fans.map(\.currentRPM).filter { $0 >= 0 }
        return values.isEmpty ? nil : values.reduce(0, +) / values.count
    }

    var targetRPM: Int? {
        switch controlMode {
        case .auto: return nil
        case .autoTemp: return autoTemperatureRPM
        case .manualRPM:
            let values = fans.map(\.rpm).filter { $0 > 0 }
            return values.isEmpty ? nil : values.reduce(0, +) / values.count
        }
    }

    func menuBarSummary(mask: Int) -> String {
        guard daemonOnline else { return "" }
        let defaults = UserDefaults.standard
        let unit = TemperatureUnit(rawValue: defaults.string(forKey: "temperatureUnit") ?? "") ?? .celsius
        let sensor = defaults.string(forKey: MenuBarMetric.sensorKey) ?? ""
        let temperature = sensor.isEmpty ? averageTemperature : sensorTemperatures.first { $0.key == sensor }?.value
        func format(_ value: Double) -> String? {
            guard let rounded = Int(exactly: unit.convert(value).rounded()) else { return nil }
            return "\(rounded)\(unit.symbol)"
        }
        return MenuBarMetric.allCases.compactMap { metric -> String? in
            guard metric.isEnabled(in: mask) else { return nil }
            switch metric {
            case .icon: return nil
            case .rpm: return actualRPM.map { "\($0) RPM" }
            case .temperature: return temperature.flatMap(format)
            case .targetRPM: return targetRPM.map { "→\($0) RPM" }
            case .targetTemperature:
                guard controlMode == .autoTemp, let target = format(targetTemperature) else { return nil }
                return "→\(target)"
            case .profile: return profiles.first { $0.id == selectedProfileID }?.name
            }
        }.joined(separator: " · ")
    }
}
