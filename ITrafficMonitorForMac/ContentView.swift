//
//  ContentView.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/19.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel = SharedStore.listViewModel
    @ObservedObject var launchAtLogin = SharedStore.launchAtLogin

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image("Itraffic-logo-text")
                    .resizable()
                    .frame(width: 89.39, height: 20)
                // The version number doubles as the update entry point — clicking
                // the thing that states your version is where people already look,
                // and it costs the header no extra element.
                UpdateStatusView()
                Spacer()
                // Sibling app, not an upsell surface: a single glyph tucked into
                // the existing link row — no badge, no popup on launch, nothing
                // added to the process list. The tooltip carries the explanation
                // so the header stays a plain row of links.
                MenuIconItem(id: "menu.bytetally", glyph: "✨", action: {
                    NSWorkspace.shared.open(URL(string: "https://bytetally.app/?utm_source=itraffic&utm_medium=app")!)
                })
                .tooltipIfAvailable("Bytetally — the full edition from the same developer: usage history, charts and per-app limits")
                MenuItem(id: "menu.github", text: "Github", action: {
                    NSWorkspace.shared.open(URL(string: "https://github.com/foamzou/ITraffic-monitor-for-mac")!)
                })
                MenuItem(id: "menu.quit", text: "Quit", action: AppDelegate.quit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Process list (ScrollView + LazyVStack for full layout control;
            // SwiftUI List adds platform-specific leading insets that hid icons.)
            ScrollView {
                VStack(spacing: 0) {
                    let maxTotal = viewModel.items
                        .map { $0.inBytesPerSec + $0.outBytesPerSec }
                        .max() ?? 0
                    ForEach(viewModel.items) { entity in
                        ProcessRow(processEntity: entity, maxTotal: maxTotal)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                    }
                }
            }
            .frame(maxHeight: 420)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Launch at login", isOn: Binding(
                    get: { self.launchAtLogin.isEnabled },
                    set: { self.launchAtLogin.setEnabled($0) }))
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.system(size: 12))

                if launchAtLogin.requiresApproval {
                    Text("Allow iTraffic in System Settings to launch at login.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Login Items", action: launchAtLogin.openLoginItems)
                        .buttonStyle(BorderlessButtonStyle())
                        .font(.system(size: 11))
                }

                if let message = launchAtLogin.errorMessage {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 340)
        .background(Color("ContentBGColor"))
        .onAppear { self.launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            self.launchAtLogin.refresh()
        }
    }
}

struct ProcessRow: View {
    var processEntity: ProcessEntity
    var maxTotal: Int

    var body: some View {
        let appInfo = getAppInfo(pid: processEntity.pid, name: processEntity.name)
        let inActive  = processEntity.inBytesPerSec  > 0
        let outActive = processEntity.outBytesPerSec > 0
        let anyActive = inActive || outActive

        let total = processEntity.inBytesPerSec + processEntity.outBytesPerSec
        let totalRatio = maxTotal > 0 ? CGFloat(total) / CGFloat(maxTotal) : 0

        HStack(spacing: 8) {
            Image(nsImage: appInfo?.icon ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)

            Text(appInfo?.name ?? processEntity.name)
                .font(.system(size: 12, weight: anyActive ? .semibold : .regular))
                .foregroundColor(anyActive ? .primary : Color.primary.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Down: same size as up; color only when active
            HStack(spacing: 2) {
                Text("↓")
                    .font(.system(size: 10))
                    .foregroundColor(inActive ? .secondary : Color.secondary.opacity(0.35))
                Text(formatBytesCompact(bytes: processEntity.inBytesPerSec))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(inActive ? .primary : Color.secondary.opacity(0.35))
                    .frame(width: 44, alignment: .trailing)
            }

            // Up: symmetric — same dimensions, same color rules
            HStack(spacing: 2) {
                Text("↑")
                    .font(.system(size: 10))
                    .foregroundColor(outActive ? .secondary : Color.secondary.opacity(0.35))
                Text(formatBytesCompact(bytes: processEntity.outBytesPerSec))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(outActive ? .primary : Color.secondary.opacity(0.35))
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .contentShape(Rectangle())
        .background(
            // Single neutral activity bar. Length = this row's total
            // (in + out) / page-max-total. Direction info stays in
            // the numbers. Color.primary auto-adapts to dark mode.
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.07))
                        .frame(width: proxy.size.width * totalRatio)
                    Spacer(minLength: 0)
                }
            }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
