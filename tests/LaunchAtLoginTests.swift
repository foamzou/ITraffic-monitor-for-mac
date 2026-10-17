import Foundation

/// Exercises file-backed login registration in an isolated directory. These
/// checks never register a real login item or change the current user's setup.
@main
struct LaunchAtLoginTests {
    static func main() throws {
        #if ITRAFFIC_UNSIGNED_BUILD
        precondition(LaunchAtLogin.serviceForCurrentBuild() == nil,
                     "Unsigned builds must not register with SMAppService")
        #else
        if #available(macOS 13.0, *) {
            precondition(LaunchAtLogin.serviceForCurrentBuild() != nil)
        }
        #endif
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("LaunchAgents/test.login.plist")
        let app = directory.appendingPathComponent("Applications/Test App.app")
        let item = LegacyLoginItem(fileURL: file, appURL: app, identifier: "test.login")

        precondition(!item.isEnabled, "Missing registration must default to off")
        try item.setEnabled(false)
        precondition(!FileManager.default.fileExists(atPath: file.path))

        try item.setEnabled(true)
        precondition(item.isEnabled)
        let data = try Data(contentsOf: file)
        let plist = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as! [String: Any]
        precondition(plist["Label"] as? String == "test.login")
        precondition(plist["ProgramArguments"] as? [String] == ["/usr/bin/open", app.path],
                     "An app path containing spaces must remain a single argument")
        precondition(plist["LimitLoadToSessionType"] as? String == "Aqua")
        precondition(plist["KeepAlive"] == nil, "Quitting must not relaunch the app")

        try item.setEnabled(true)
        precondition(item.isEnabled, "Repeated enabling must be safe")
        let movedItem = LegacyLoginItem(
            fileURL: file,
            appURL: directory.appendingPathComponent("Moved App.app"),
            identifier: "test.login")
        precondition(!movedItem.isEnabled, "A stale app path must not appear enabled")
        try movedItem.setEnabled(true)
        precondition(movedItem.isEnabled)

        try Data("invalid plist".utf8).write(to: file)
        precondition(!movedItem.isEnabled, "Malformed registration must appear off")
        try movedItem.setEnabled(true)
        try movedItem.setEnabled(false)
        try movedItem.setEnabled(false)
        precondition(!FileManager.default.fileExists(atPath: file.path))

        // A write failure must be propagated, rather than appearing successful.
        let blocked = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: blocked)
        let failingItem = LegacyLoginItem(
            fileURL: blocked.appendingPathComponent("test.plist"),
            appURL: app, identifier: "test.login")
        var didFail = false
        do { try failingItem.setEnabled(true) } catch { didFail = true }
        precondition(didFail)
        precondition(!failingItem.isEnabled)
        try checkModel(item: item)
        print("Launch-at-login compatibility checks passed")
    }

    static func checkModel(item: LegacyLoginItem) throws {
        let unsigned = LaunchAtLogin(
            legacyItem: item, systemService: nil, legacyNeedsApproval: { _ in false })
        precondition(!unsigned.isEnabled)
        precondition(!FileManager.default.fileExists(atPath: item.fileURL.path),
                     "Reading status must not create a registration")
        unsigned.setEnabled(true)
        precondition(unsigned.isEnabled && item.isEnabled && unsigned.errorMessage == nil)
        let saved = try Data(contentsOf: item.fileURL)
        let pending = LaunchAtLogin(
            legacyItem: item, systemService: nil, legacyNeedsApproval: { _ in true })
        precondition(pending.requiresApproval && pending.isEnabled)
        pending.refresh()
        let refreshed = try Data(contentsOf: item.fileURL)
        precondition(refreshed == saved,
                     "A refresh must not overwrite a registration denied in System Settings")
        pending.setEnabled(false)
        precondition(!pending.isEnabled && !pending.requiresApproval && !item.isEnabled)

        var status = LoginItemService.Status.notRegistered
        var denyRegistration = true
        var denyRemoval = false
        var registrations = 0
        let service = LoginItemService(
            status: { status },
            register: {
                registrations += 1
                if denyRegistration { throw NSError(domain: NSPOSIXErrorDomain, code: 1) }
                status = .enabled
            },
            unregister: {
                if denyRemoval { throw NSError(domain: NSPOSIXErrorDomain, code: 1) }
                status = .notRegistered
            })
        let signed = LaunchAtLogin(
            legacyItem: item, systemService: service, legacyNeedsApproval: { _ in false })
        signed.setEnabled(true)
        precondition(!signed.isEnabled && signed.errorMessage != nil)
        precondition(!item.isEnabled,
                     "A system permission denial must not fall back to a LaunchAgent")

        denyRegistration = false
        signed.setEnabled(true)
        precondition(signed.isEnabled && signed.errorMessage == nil)
        precondition(registrations == 2 && !item.isEnabled)
        status = .requiresApproval
        signed.refresh()
        precondition(signed.isEnabled && signed.requiresApproval)
        signed.setEnabled(true)
        precondition(registrations == 2, "Pending approval must not trigger re-registration")

        denyRemoval = true
        signed.setEnabled(false)
        precondition(signed.isEnabled && signed.errorMessage != nil)
        denyRemoval = false
        signed.setEnabled(false)
        precondition(!signed.isEnabled && !signed.requiresApproval && signed.errorMessage == nil)

        try item.setEnabled(true)
        signed.refresh()
        precondition(signed.isEnabled && registrations == 2,
                     "Recognising a legacy registration must not migrate it automatically")
        signed.setEnabled(true)
        precondition(signed.isEnabled && !item.isEnabled && registrations == 3)
        signed.setEnabled(false)
    }
}
