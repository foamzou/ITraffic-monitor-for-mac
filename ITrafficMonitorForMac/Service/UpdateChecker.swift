//
//  UpdateChecker.swift
//  ITrafficMonitorForMac
//
//  Asks GitHub for the latest release tag and compares it with this build.
//
//  **Only ever from an explicit click.** iTraffic lists the network activity of
//  every process, including its own — a background poll would show up there as
//  unexplained traffic from the one tool whose job is to explain traffic. There
//  is deliberately no timer, no launch check and no "check automatically"
//  preference to forget about.
//
//  Written with completion handlers rather than async/await so it stays valid on
//  the 10.15 deployment target without back-deploying the concurrency runtime.
//

import Foundation

final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    @Published private(set) var state: State = .idle

    let currentVersion: String

    private let endpoint = URL(string:
        "https://api.github.com/repos/foamzou/ITraffic-monitor-for-mac/releases/latest")!
    private var resetWork: DispatchWorkItem?

    init(currentVersion: String? = nil) {
        self.currentVersion = currentVersion
            ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
            ?? "0"
    }

    func check() {
        if case .checking = state { return }
        resetWork?.cancel()
        state = .checking

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 10
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        // GitHub rejects requests without a User-Agent. Identify the app plainly;
        // nothing about the machine goes into it.
        request.setValue("iTraffic/\(currentVersion) (+https://github.com/foamzou/ITraffic-monitor-for-mac)",
                         forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self else { return }

            let next = Self.interpret(data: data,
                                      response: response,
                                      currentVersion: self.currentVersion)
            DispatchQueue.main.async {
                self.state = next
                // Transient outcomes fall back to showing the version number;
                // an available update stays put until it is acted on.
                if next == .upToDate || next == .failed {
                    self.scheduleReset()
                }
            }
        }.resume()
    }

    func openReleasePage() -> URL? {
        if case let .available(_, url) = state { return url }
        return nil
    }

    // MARK: - Internals

    private func scheduleReset() {
        let work = DispatchWorkItem { [weak self] in self?.state = .idle }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }

    private struct LatestRelease: Decodable {
        let tagName: String
        let htmlUrl: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    private static func interpret(data: Data?, response: URLResponse?, currentVersion: String) -> State {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let data = data,
              let release = try? JSONDecoder().decode(LatestRelease.self, from: data),
              let url = URL(string: release.htmlUrl)
        else { return .failed }

        let latest = normalise(release.tagName)
        guard isNewer(latest, than: normalise(currentVersion)) else { return .upToDate }
        return .available(version: latest, url: url)
    }

    /// "v0.2.1" -> "0.2.1"
    static func normalise(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Component-wise numeric compare, so 0.2.10 correctly beats 0.2.9 —
    /// which plain string comparison gets backwards.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
