import Foundation

// Exercises the real URLSession/decoder boundary without contacting GitHub.
final class ReleaseProtocol: URLProtocol {
    static var respond: (URLRequest) -> (Int, Data) = { _ in (500, Data()) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.respond(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

enum UpdateIntegration {
    static func fixture(_ version: String, prerelease: Bool = false) -> [String: Any] {
        ["tag_name": version, "html_url": "https://github.com/Fallet666/vent/releases/tag/\(version)",
         "draft": false, "prerelease": prerelease,
         "assets": [["name": "Vent.dmg", "content_type": "application/octet-stream",
                     "browser_download_url": "https://github.com/Fallet666/vent/releases/download/\(version)/Vent.dmg"]]]
    }

    static func data(_ object: Any) -> Data { try! JSONSerialization.data(withJSONObject: object) }
    static func release(_ version: String, prerelease: Bool = false) -> GitHubRelease {
        try! JSONDecoder().decode(GitHubRelease.self, from: data(fixture(version, prerelease: prerelease)))
    }

    @MainActor static func run() async {
        let check = LifecycleIntegration.check
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ReleaseProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let stable = fixture("v1.3.7")
        let beta = fixture("v1.3.9-beta.2", prerelease: true)
        var requests: [String] = []
        ReleaseProtocol.respond = { request in
            requests.append(request.url!.absoluteString)
            if request.url!.path.hasSuffix("/latest") { return (200, data(stable)) }
            if request.url!.query?.contains("page=2") == true { return (200, data([beta])) }
            return (200, data(Array(repeating: stable, count: 100)))
        }
        do {
            let stableResult = try await ReleaseChecker.fetch(channel: .stable, session: session)
            check(stableResult?.tagName == "v1.3.7", "stable endpoint decoded")
            let betaResult = try await ReleaseChecker.fetch(channel: .beta, session: session)
            check(betaResult?.tagName == "v1.3.9-beta.2", "beta found on second page")
            check(requests.count == 3 && requests[0].hasSuffix("/latest") && requests[2].contains("page=2"), "correct endpoints and pagination")
            ReleaseProtocol.respond = { _ in (403, data(["message": "rate limited"])) }
            do {
                _ = try await ReleaseChecker.fetch(channel: .beta, session: session)
                check(false, "rate limit must fail")
            } catch { check(true, "rate limit rejected") }
            ReleaseProtocol.respond = { _ in (200, Data("invalid JSON".utf8)) }
            do {
                _ = try await ReleaseChecker.fetch(channel: .stable, session: session)
                check(false, "invalid JSON must fail")
            } catch { check(true, "invalid JSON rejected") }
            ReleaseProtocol.respond = { _ in (200, data(beta)) }
            do {
                _ = try await ReleaseChecker.fetch(channel: .stable, session: session)
                check(false, "unexpected prerelease from stable endpoint must fail")
            } catch { check(true, "unexpected stable response rejected") }
        } catch {
            check(false, "unexpected network fixture error: \(error)")
        }

        let defaults = UserDefaults.standard
        defaults.set(UpdateChannel.beta.rawValue, forKey: UpdateChannel.preferenceKey)
        defaults.set(true, forKey: VentDaemonManager.updateChecksEnabledKey)
        var pendingBeta: CheckedContinuation<GitHubRelease?, Error>?
        var fetched: [UpdateChannel] = []
        let manager = VentDaemonManager(startRefreshLoop: false, fetchRelease: { channel in
            fetched.append(channel)
            if channel == .beta {
                // Deliberately ignore cancellation to prove generation protection.
                return try await withCheckedThrowingContinuation { pendingBeta = $0 }
            }
            return release("v1.3.7")
        })
        manager.bundledVersion = "1.3.7"
        manager.checkForUpdates(manual: true)
        await LifecycleIntegration.waitUntil("beta request started") { pendingBeta != nil }
        defaults.set(UpdateChannel.stable.rawValue, forKey: UpdateChannel.preferenceKey)
        manager.updateChannelChanged()
        await LifecycleIntegration.waitUntil("stable check finished") { !manager.isCheckingForUpdates }
        check(manager.latestReleaseVersion == "v1.3.7" && !manager.appUpdateAvailable, "stable result replaces beta request")
        pendingBeta!.resume(returning: release("v1.3.9-beta.2", prerelease: true))
        try? await Task.sleep(nanoseconds: 100_000_000)
        check(manager.latestReleaseVersion == "v1.3.7" && !manager.appUpdateAvailable, "late beta cannot overwrite stable")
        check(manager.dmgDownloadURL?.path.contains("v1.3.7") == true, "late beta cannot overwrite asset")
        check(fetched == [.beta, .stable], "channel switch checks immediately")

        defaults.set(false, forKey: VentDaemonManager.updateChecksEnabledKey)
        defaults.set(UpdateChannel.beta.rawValue, forKey: UpdateChannel.preferenceKey)
        manager.updateChannelChanged()
        check(manager.latestReleaseVersion == nil && manager.dmgDownloadURL == nil, "switch clears cached offer")
        check(fetched.count == 2 && !manager.isCheckingForUpdates, "disabled automatic checks stay disabled")
        check(defaults.object(forKey: VentDaemonManager.lastUpdateCheckDateKey) == nil, "old channel throttle cleared")
        check(UpdateChannel.saved() == .beta, "channel persisted")

        let next = VentDaemonManager(startRefreshLoop: false, fetchRelease: { _ in release("v1.3.9-beta.2", prerelease: true) })
        next.bundledVersion = "1.3.9-beta.1"
        next.checkForUpdates(manual: true)
        await LifecycleIntegration.waitUntil("manual beta check finished") { !next.isCheckingForUpdates }
        check(next.appUpdateAvailable, "manual check works with automatic checks disabled")
        next.bundledVersion = "1.3.9-rc.1"
        check(!next.appUpdateAvailable, "older beta never offered as downgrade from RC")
        next.helperVersion = "1.3.9-beta.1"
        check(next.helperNeedsUpdate, "helper prerelease difference detected")
        print("PASS update service and channel lifecycle")
    }
}
