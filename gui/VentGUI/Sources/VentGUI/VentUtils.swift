import Foundation

public enum VentUtils {
    public static func normalizedReleaseVersion(_ version: String) -> String {
        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionWithoutPrefix = trimmedVersion.hasPrefix("v") ? String(trimmedVersion.dropFirst()) : trimmedVersion
        guard let releaseVersion = versionWithoutPrefix.split(whereSeparator: { $0 == "-" || $0 == "+" }).first else {
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
        let leftPrerelease = prereleaseIdentifiers(leftVersion)
        let rightPrerelease = prereleaseIdentifiers(rightVersion)
        if leftPrerelease.isEmpty && rightPrerelease.isEmpty { return .orderedSame }
        if leftPrerelease.isEmpty { return .orderedDescending }
        if rightPrerelease.isEmpty { return .orderedAscending }
        for (left, right) in zip(leftPrerelease, rightPrerelease) {
            if left == right { continue }
            let leftNumeric = left.allSatisfy { $0.isASCII && $0.isNumber }
            let rightNumeric = right.allSatisfy { $0.isASCII && $0.isNumber }
            if leftNumeric && rightNumeric {
                if left.count != right.count { return left.count > right.count ? .orderedDescending : .orderedAscending }
            } else if leftNumeric != rightNumeric {
                return leftNumeric ? .orderedAscending : .orderedDescending
            }
            return left > right ? .orderedDescending : .orderedAscending
        }
        if leftPrerelease.count == rightPrerelease.count { return .orderedSame }
        return leftPrerelease.count > rightPrerelease.count ? .orderedDescending : .orderedAscending
    }

    private static func prereleaseIdentifiers(_ version: String) -> [String] {
        let withoutBuild = version.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "+", maxSplits: 1).first ?? ""
        let parts = withoutBuild.split(separator: "-", maxSplits: 1)
        return parts.count == 2 ? parts[1].split(separator: ".").map(String.init) : []
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
