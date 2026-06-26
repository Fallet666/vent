import Darwin
import Foundation

public final class VentDaemonClient: Sendable {
    public static let shared = VentDaemonClient()
    private let sockPath = ProcessInfo.processInfo.environment["VENT_SOCKET_PATH"] ?? "/tmp/ventd.sock"

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

        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(socketDescriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(socketDescriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let commandLine = command + "\n"
        commandLine.withCString { pointer in
            var remaining = commandLine.utf8.count
            var offset = 0
            while remaining > 0 {
                let written = write(socketDescriptor, pointer.advanced(by: offset), remaining)
                guard written > 0 else { return }
                offset += written
                remaining -= written
            }
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
        return Self.parseVersion(response)
    }

    public static func parseVersion(_ response: String) -> String? {
        let parts = response.split(separator: " ", maxSplits: 1)
        guard parts.count == 2, parts[0] == "VERSION" else { return nil }
        return String(parts[1])
    }

    func fans() -> [VentDaemonFanInfo]? {
        guard let response = sendCommand("FANS") else { return nil }
        return Self.parseFans(response)
    }

    public static func parseFans(_ response: String) -> [VentDaemonFanInfo]? {
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
            return VentDaemonFanInfo(
                index: index,
                currentRPM: currentRPM,
                minRPM: minRPM,
                maxRPM: maxRPM,
                targetRPM: targetRPM,
                manualMode: manualModeValue != 0
            )
        }
    }

    func temperatures() -> [VentDaemonTemperature]? {
        guard let response = sendCommand("TEMPS") else { return nil }
        return Self.parseTemperatures(response)
    }

    public static func parseTemperatures(_ response: String) -> [VentDaemonTemperature]? {
        let lines = response.split(separator: "\n")
        guard let header = lines.first, header.hasPrefix("TEMPS") else { return nil }

        return lines.dropFirst().compactMap { line in
            let parts = line.split(separator: " ")
            guard parts.count >= 2, let value = Double(parts[1]) else { return nil }
            return VentDaemonTemperature(key: String(parts[0]), value: value)
        }
    }

    func modeStatus() -> VentDaemonModeStatus? {
        guard let response = sendCommand("MODESTATUS") else { return nil }
        return Self.parseModeStatus(response)
    }

    public static func parseModeStatus(_ response: String) -> VentDaemonModeStatus? {
        let parts = response.split(separator: " ")
        guard parts.count >= 5,
              parts[0] == "MODE",
              let mode = VentMode(daemonValue: String(parts[1])),
              let targetTemperature = Double(parts[2]),
              let averageTemperature = Double(parts[3]),
              let autoRPM = Double(parts[4]) else {
            return nil
        }
        return VentDaemonModeStatus(
            mode: mode,
            targetTemperature: targetTemperature,
            averageTemperature: averageTemperature > 0 ? averageTemperature : nil,
            autoRPM: autoRPM > 0 ? Int(autoRPM.rounded()) : nil
        )
    }

    func config() -> VentDaemonConfig? {
        guard let response = sendCommand("CONFIG") else { return nil }
        return Self.parseConfig(response)
    }

    public static func parseConfig(_ response: String) -> VentDaemonConfig? {
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
        return VentDaemonConfig(
            minTargetTemperature: minTargetTemperature,
            maxTargetTemperature: maxTargetTemperature,
            defaultTargetTemperature: defaultTargetTemperature,
            minUsableTemperature: minUsableTemperature,
            maxUsableTemperature: maxUsableTemperature
        )
    }

    @discardableResult
    func setMode(_ mode: VentMode, targetTemperature: Double? = nil) -> Bool {
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

public struct VentDaemonFanInfo {
    public let index: Int
    public let currentRPM: Int
    public let minRPM: Int
    public let maxRPM: Int
    public let targetRPM: Int
    public let manualMode: Bool

    public init(index: Int, currentRPM: Int, minRPM: Int, maxRPM: Int, targetRPM: Int, manualMode: Bool) {
        self.index = index
        self.currentRPM = currentRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.targetRPM = targetRPM
        self.manualMode = manualMode
    }
}

public struct VentDaemonTemperature {
    public let key: String
    public let value: Double

    public init(key: String, value: Double) {
        self.key = key
        self.value = value
    }
}

public enum VentMode: String, CaseIterable, Identifiable, Codable {
    case auto
    case manualRPM
    case autoTemp

    public var id: String { rawValue }

    public init?(daemonValue: String) {
        switch daemonValue {
        case "AUTO": self = .auto
        case "MANUAL_RPM": self = .manualRPM
        case "AUTO_TEMP": self = .autoTemp
        default: return nil
        }
    }

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .manualRPM: return "Manual RPM"
        case .autoTemp: return "Auto Temp"
        }
    }
}

public struct VentDaemonModeStatus {
    public let mode: VentMode
    public let targetTemperature: Double
    public let averageTemperature: Double?
    public let autoRPM: Int?

    public init(mode: VentMode, targetTemperature: Double, averageTemperature: Double?, autoRPM: Int?) {
        self.mode = mode
        self.targetTemperature = targetTemperature
        self.averageTemperature = averageTemperature
        self.autoRPM = autoRPM
    }
}

public struct VentDaemonConfig {
    public let minTargetTemperature: Double
    public let maxTargetTemperature: Double
    public let defaultTargetTemperature: Double
    public let minUsableTemperature: Double
    public let maxUsableTemperature: Double

    public init(minTargetTemperature: Double, maxTargetTemperature: Double, defaultTargetTemperature: Double, minUsableTemperature: Double, maxUsableTemperature: Double) {
        self.minTargetTemperature = minTargetTemperature
        self.maxTargetTemperature = maxTargetTemperature
        self.defaultTargetTemperature = defaultTargetTemperature
        self.minUsableTemperature = minUsableTemperature
        self.maxUsableTemperature = maxUsableTemperature
    }
}
