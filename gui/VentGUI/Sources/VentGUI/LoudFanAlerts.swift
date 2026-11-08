import Foundation
import UserNotifications

public struct LoudFanAlertState {
    private var isLoud = false

    public init() {}

    public static func noiseRatio(for fans: [FanState]) -> Double? {
        guard !fans.isEmpty, fans.allSatisfy({ $0.currentRPM >= 0 && $0.maxRPM > 0 }),
              let current = fans.map(\.currentRPM).max(),
              let maximum = fans.map(\.maxRPM).max() else { return nil }
        return Double(current) / Double(maximum)
    }

    public mutating func shouldNotify(enabled: Bool, noiseRatio: Double?) -> Bool {
        guard enabled else {
            isLoud = false
            return false
        }
        guard let noiseRatio, noiseRatio.isFinite, noiseRatio >= 0 else { return false }
        if noiseRatio < 0.65 {
            isLoud = false
        } else if noiseRatio >= 0.7 && !isLoud {
            isLoud = true
            return true
        }
        return false
    }
}

final class LoudFanNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LoudFanNotifier()

    private override init() { super.init() }

    func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion(granted)
        }
    }

    func send(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                completion(false)
                return
            }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Vent")
            content.body = String(localized: "Fans are running at high speed and may be loud.")
            content.sound = .default
            center.add(UNNotificationRequest(identifier: "loudFan", content: content, trigger: nil)) { error in
                completion(error == nil)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
