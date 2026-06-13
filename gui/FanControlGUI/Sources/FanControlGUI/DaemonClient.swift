import Darwin
import Foundation

final class DaemonClient {
    static let shared = DaemonClient()
    private let sockPath = ProcessInfo.processInfo.environment["FANCTL_SOCKET_PATH"] ?? "/tmp/fanctl.sock"

    private init() {}

    func sendCommand(_ command: String) -> String? {
        let socketDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return nil }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = sockPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            close(socketDescriptor)
            return nil
        }

        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: Int8.self, capacity: pathBytes.count) { pathPointer in
                for (byteIndex, byte) in pathBytes.enumerated() {
                    pathPointer[byteIndex] = byte
                }
            }
        }

        let addressSize = MemoryLayout<sockaddr_un>.size
        let connectResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketDescriptor, $0, socklen_t(addressSize))
            }
        }

        guard connectResult == 0 else {
            close(socketDescriptor)
            return nil
        }

        let commandLine = command + "\n"
        commandLine.withCString { pointer in
            _ = write(socketDescriptor, pointer, commandLine.utf8.count)
        }

        var buffer = [UInt8](repeating: 0, count: 16_384)
        let bytesRead = read(socketDescriptor, &buffer, buffer.count - 1)
        close(socketDescriptor)

        guard bytesRead > 0 else { return nil }
        buffer[Int(bytesRead)] = 0
        return String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isRunning() -> Bool {
        sendCommand("HEARTBEAT")?.hasPrefix("OK") == true
    }

    func version() -> String? {
        guard let response = sendCommand("VERSION") else { return nil }
        let parts = response.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, parts[0] == "VERSION" else { return nil }
        return String(parts[1])
    }

    func fans() -> [DaemonFanInfo]? {
        guard let response = sendCommand("FANS") else { return nil }

        let lines = response.split(separator: "\n")
        guard let header = lines.first, header.hasPrefix("FANS") else { return nil }

        return lines.dropFirst().compactMap { line in
            let parts = line.split(separator: " ")
            guard parts.count >= 6,
                  let index = Int(parts[0]),
                  let currentRPM = Int(parts[1]),
                  let minRPM = Int(parts[2]),
                  let maxRPM = Int(parts[3]),
                  let targetRPM = Int(parts[4]),
                  let manualModeValue = Int(parts[5]) else {
                return nil
            }
            return DaemonFanInfo(
                index: index,
                currentRPM: currentRPM,
                minRPM: minRPM,
                maxRPM: maxRPM,
                targetRPM: targetRPM,
                manualMode: manualModeValue != 0
            )
        }
    }

    func temperatures() -> [DaemonTemperature]? {
        guard let response = sendCommand("TEMPS") else { return nil }

        let lines = response.split(separator: "\n")
        guard let header = lines.first, header.hasPrefix("TEMPS") else { return nil }

        return lines.dropFirst().compactMap { line in
            let parts = line.split(separator: " ")
            guard parts.count >= 2, let value = Double(parts[1]) else { return nil }
            return DaemonTemperature(key: String(parts[0]), value: value)
        }
    }

    func modeStatus() -> DaemonModeStatus? {
        guard let response = sendCommand("MODESTATUS") else { return nil }
        let parts = response.split(separator: " ")
        guard parts.count >= 5,
              parts[0] == "MODE",
              let mode = FanControlMode(daemonValue: String(parts[1])),
              let targetTemperature = Double(parts[2]),
              let averageTemperature = Double(parts[3]),
              let autoRPM = Double(parts[4]) else {
            return nil
        }
        return DaemonModeStatus(
            mode: mode,
            targetTemperature: targetTemperature,
            averageTemperature: averageTemperature > 0 ? averageTemperature : nil,
            autoRPM: autoRPM > 0 ? Int(autoRPM.rounded()) : nil
        )
    }

    func config() -> DaemonConfig? {
        guard let response = sendCommand("CONFIG") else { return nil }
        let parts = response.split(separator: " ")
        guard parts.count >= 6,
              parts[0] == "CONFIG",
              let minTargetTemperature = Double(parts[1]),
              let maxTargetTemperature = Double(parts[2]),
              let defaultTargetTemperature = Double(parts[3]),
              let minUsableTemperature = Double(parts[4]),
              let maxUsableTemperature = Double(parts[5]) else {
            return nil
        }
        return DaemonConfig(
            minTargetTemperature: minTargetTemperature,
            maxTargetTemperature: maxTargetTemperature,
            defaultTargetTemperature: defaultTargetTemperature,
            minUsableTemperature: minUsableTemperature,
            maxUsableTemperature: maxUsableTemperature
        )
    }

    @discardableResult
    func setMode(_ mode: FanControlMode, targetTemperature: Double? = nil) -> Bool {
        switch mode {
        case .auto:
            return sendCommand("MODE AUTO")?.hasPrefix("OK") == true
        case .manualRPM:
            return sendCommand("MODE MANUAL")?.hasPrefix("OK") == true
        case .autoTemp:
            guard let targetTemperature else { return false }
            let temperature = Int(targetTemperature.rounded())
            return sendCommand("MODE TEMP \(temperature)")?.hasPrefix("OK") == true
        }
    }

    @discardableResult
    func setFan(index: Int, rpm: Int) -> Bool {
        sendCommand("SET \(index) \(rpm)")?.hasPrefix("OK") == true
    }

    @discardableResult
    func setAllFans(rpm: Int) -> Bool {
        sendCommand("SETALL \(rpm)")?.hasPrefix("OK") == true
    }

    @discardableResult
    func setAuto(index: Int) -> Bool {
        sendCommand("AUTO \(index)")?.hasPrefix("OK") == true
    }

    @discardableResult
    func setAllAuto() -> Bool {
        sendCommand("AUTOALL")?.hasPrefix("OK") == true
    }
}

struct DaemonFanInfo {
    let index: Int
    let currentRPM: Int
    let minRPM: Int
    let maxRPM: Int
    let targetRPM: Int
    let manualMode: Bool
}

struct DaemonTemperature {
    let key: String
    let value: Double
}

enum FanControlMode: String, CaseIterable, Identifiable {
    case auto
    case manualRPM
    case autoTemp

    var id: String { rawValue }

    init?(daemonValue: String) {
        switch daemonValue {
        case "AUTO": self = .auto
        case "MANUAL_RPM": self = .manualRPM
        case "AUTO_TEMP": self = .autoTemp
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .manualRPM: return "Manual RPM"
        case .autoTemp: return "Auto Temp"
        }
    }
}

struct DaemonModeStatus {
    let mode: FanControlMode
    let targetTemperature: Double
    let averageTemperature: Double?
    let autoRPM: Int?
}

struct DaemonConfig {
    let minTargetTemperature: Double
    let maxTargetTemperature: Double
    let defaultTargetTemperature: Double
    let minUsableTemperature: Double
    let maxUsableTemperature: Double
}
