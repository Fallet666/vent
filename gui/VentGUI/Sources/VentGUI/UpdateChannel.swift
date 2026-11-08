import Foundation

public enum UpdateChannel: String, CaseIterable {
    case stable
    case beta

    public static let preferenceKey = "updateChannel"

    public static func saved(in defaults: UserDefaults = .standard) -> UpdateChannel {
        UpdateChannel(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .stable
    }
}

public struct GitHubAsset: Decodable {
    public let name: String
    public let browserDownloadURL: URL
    public let contentType: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
    }
}

public struct GitHubRelease: Decodable {
    public let tagName: String
    public let htmlURL: URL
    public let assets: [GitHubAsset]
    public let draft: Bool
    public let prerelease: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets, draft, prerelease
    }

    public var dmgDownloadURL: URL? {
        assets.first {
            $0.name.lowercased().hasSuffix(".dmg") &&
                $0.browserDownloadURL.scheme == "https" &&
                $0.browserDownloadURL.host == "github.com" &&
                $0.browserDownloadURL.path.hasPrefix("/Fallet666/vent/releases/download/")
        }?.browserDownloadURL
    }

    public var hasValidVersion: Bool {
        // Ignore unrelated tags, malformed identifiers and numbers outside Int's range.
        let pattern = #"^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"#
        guard tagName.range(of: pattern, options: .regularExpression) != nil else { return false }
        return VentUtils.normalizedReleaseVersion(tagName).split(separator: "+")[0]
            .split(separator: ".").allSatisfy { Int($0) != nil }
    }

    public static func newest(in releases: [GitHubRelease], channel: UpdateChannel) -> GitHubRelease? {
        releases.filter {
            !$0.draft && $0.hasValidVersion && $0.dmgDownloadURL != nil &&
                (channel == .beta || (!$0.prerelease && !$0.tagName.split(separator: "+")[0].contains("-")))
        }.max { VentUtils.compareReleaseVersions($0.tagName, $1.tagName) == .orderedAscending }
    }
}

public enum ReleaseChecker {
    public static func fetch(channel: UpdateChannel, session: URLSession = .shared) async throws -> GitHubRelease? {
        if channel == .stable {
            let data = try await request(path: "latest", session: session)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let stable = GitHubRelease.newest(in: [release], channel: channel) else {
                throw URLError(.cannotParseResponse)
            }
            return stable
        }

        var newest: GitHubRelease?
        var page = 1
        while true {
            try Task.checkCancellation()
            let data = try await request(path: "?per_page=100&page=\(page)", session: session)
            let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
            newest = GitHubRelease.newest(in: (newest.map { [$0] } ?? []) + releases, channel: channel)
            if releases.count < 100 { return newest }
            page += 1
        }
    }

    private static func request(path: String, session: URLSession) async throws -> Data {
        let separator = path.hasPrefix("?") ? "" : "/"
        let url = URL(string: "https://api.github.com/repos/Fallet666/vent/releases\(separator)\(path)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Vent", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
