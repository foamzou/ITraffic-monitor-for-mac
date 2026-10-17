import Combine
import Foundation
import ServiceManagement

/// Reads the system's state rather than keeping a separate preference that can
/// become stale when someone edits Login Items in System Settings.
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    private let legacyItem: LegacyLoginItem
    private let systemService: LoginItemService?
    private let legacyNeedsApproval: (URL) -> Bool

    init(legacyItem: LegacyLoginItem? = nil,
         systemService: LoginItemService? = LaunchAtLogin.serviceForCurrentBuild(),
         legacyNeedsApproval: @escaping (URL) -> Bool = LaunchAtLogin.legacyNeedsApproval) {
        let identifier = (Bundle.main.bundleIdentifier ?? "com.foamzou.ITrafficMonitorForMac")
            + ".launch-at-login"
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        self.legacyItem = legacyItem ?? LegacyLoginItem(
            fileURL: directory.appendingPathComponent(identifier + ".plist"),
            appURL: Bundle.main.bundleURL,
            identifier: identifier)
        self.systemService = systemService
        self.legacyNeedsApproval = legacyNeedsApproval
        refresh()
    }

    func refresh() {
        let legacyEnabled = legacyItem.isEnabled
        if let service = systemService {
            let status = service.status()
            requiresApproval = status == .requiresApproval
                || (legacyEnabled && legacyNeedsApproval(legacyItem.fileURL))
            // A pending registration stays switchable so it can be cancelled.
            // Also recognise an older registration after a macOS upgrade.
            isEnabled = status == .enabled || requiresApproval || legacyEnabled
        } else {
            isEnabled = legacyEnabled
            requiresApproval = legacyEnabled && legacyNeedsApproval(legacyItem.fileURL)
        }
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if let service = systemService {
                if enabled {
                    if service.status() != .enabled && service.status() != .requiresApproval {
                        try service.register()
                    }
                } else if service.status() == .enabled || service.status() == .requiresApproval {
                    try service.unregister()
                }
                // Only migrate the old registration after an explicit change.
                // Never re-enable an item in response to a status refresh.
                try legacyItem.setEnabled(false)
            } else {
                try legacyItem.setEnabled(enabled)
            }
        } catch {
            errorMessage = "Could not change launch at login: " + error.localizedDescription
        }
        refresh()
    }

    func openLoginItems() {
        if #available(macOS 13.0, *) {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    static func serviceForCurrentBuild() -> LoginItemService? {
        // SMAppService requires code signing. CI deliberately disables signing,
        // so select its backend at build time, never after a permission denial.
        #if !ITRAFFIC_UNSIGNED_BUILD
        if #available(macOS 13.0, *) {
            return LoginItemService(
                status: {
                    switch SMAppService.mainApp.status {
                    case .enabled: return .enabled
                    case .requiresApproval: return .requiresApproval
                    default: return .notRegistered
                    }
                },
                register: { try SMAppService.mainApp.register() },
                unregister: { try SMAppService.mainApp.unregister() })
        }
        #endif
        return nil
    }

    static func legacyNeedsApproval(_ url: URL) -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.statusForLegacyPlist(at: url) == .requiresApproval
        }
        return false
    }
}

/// Injectable system operations let tests simulate denial and external changes
/// without registering anything in the current user's Login Items.
struct LoginItemService {
    enum Status { case notRegistered, enabled, requiresApproval }
    let status: () -> Status
    let register: () throws -> Void
    let unregister: () throws -> Void
}

/// Used on macOS 10.15–12 and unsigned CI builds. launchd reads this file on the
/// next login. No helper, administrator access, shell, or keep-alive is needed.
struct LegacyLoginItem {
    let fileURL: URL
    let appURL: URL
    let identifier: String

    var isEnabled: Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
        else { return false }
        return plist["Label"] as? String == identifier
            && plist["RunAtLoad"] as? Bool == true
            && plist["ProgramArguments"] as? [String] == arguments
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            let plist: [String: Any] = [
                "Label": identifier,
                "ProgramArguments": arguments,
                "RunAtLoad": true,
                "LimitLoadToSessionType": "Aqua"
            ]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } else if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private var arguments: [String] { ["/usr/bin/open", appURL.path] }
}
