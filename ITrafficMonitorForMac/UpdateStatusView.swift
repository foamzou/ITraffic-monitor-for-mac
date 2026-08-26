//
//  UpdateStatusView.swift
//  ITrafficMonitorForMac
//
//  The version number in the header, doubling as the update check. Clicking it
//  checks; clicking it again once an update is found opens the release page.
//  Transient results (up to date / failed) revert to the version number on their
//  own, so the header never keeps stale state around.
//

import SwiftUI

struct UpdateStatusView: View {
    @ObservedObject var checker = SharedStore.updateChecker

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            .contentShape(Rectangle())
            .animation(.none)
            .onTapGesture { tap() }
            .tooltipIfAvailable(tooltip)
    }

    private var label: String {
        switch checker.state {
        case .idle:                     return "v\(checker.currentVersion)"
        case .checking:                 return "checking…"
        case .upToDate:                 return "up to date"
        case let .available(version, _): return "v\(version) ↑"
        case .failed:                   return "check failed"
        }
    }

    // Only an actual update earns more contrast than the version number normally
    // has; everything else stays at the header's usual secondary weight.
    private var color: Color {
        if case .available = checker.state { return .primary }
        return .secondary
    }

    private var tooltip: String {
        switch checker.state {
        case let .available(version, _):
            return "Version \(version) is available — click to open the release page"
        case .failed:
            return "Could not reach GitHub. Click to try again."
        default:
            return "Click to check for updates. iTraffic never checks on its own."
        }
    }

    private func tap() {
        if let url = checker.openReleasePage() {
            NSWorkspace.shared.open(url)
            return
        }
        checker.check()
    }
}
