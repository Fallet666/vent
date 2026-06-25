import Foundation

public enum VentUtils {
    public static func normalizedReleaseVersion(_ version: String) -> String {
        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionWithoutPrefix = trimmedVersion.hasPrefix("v") ? String(trimmedVersion.dropFirst()) : trimmedVersion
        guard let releaseVersion = versionWithoutPrefix.split(separator: "-").first else {
            return versionWithoutPrefix
        }
        return String(releaseVersion)
    }

    public static func compareReleaseVersions(_ leftVersion: String, _ rightVersion: String) -> ComparisonResult {
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

    public static func releaseVersionComponents(_ version: String) -> [Int] {
        normalizedReleaseVersion(version)
            .split(separator: ".")
            .map { versionPart in
                Int(versionPart.prefix { $0.isNumber }) ?? 0
            }
    }

    public static func hottestTemperature(from temperatures: [VentDaemonTemperature], minUsable: Double, maxUsable: Double) -> Double? {
        let validTemperatures = temperatures
            .filter { temperature in
                temperature.value.isFinite &&
                    temperature.value >= minUsable &&
                    temperature.value < maxUsable &&
                    !temperature.key.hasPrefix("Ta") &&
                    !temperature.key.hasPrefix("Tp") &&
                    temperature.key.range(of: "cal", options: .caseInsensitive) == nil
            }
            .map(\.value)
        guard !validTemperatures.isEmpty else { return nil }
        return validTemperatures.max()!
    }
}
