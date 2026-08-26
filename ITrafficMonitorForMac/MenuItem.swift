//
//  MenuItem.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/29.
//

import Foundation
import SwiftUI

struct MenuItem: View {
    let id: String
    let text: String
    var action: (() -> Void)?

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(.gray)
            .contentShape(Rectangle())
            .animation(.none)
            .onTapGesture {
                action?()
            }
    }
}

/// Icon-only sibling of `MenuItem`.
///
/// A plain `Text` glyph rather than an SF Symbol: the emoji renders identically
/// all the way back to 10.15, and a Unicode glyph never needs `.resizable()`,
/// which is what stretches SF Symbols into thin sticks at small sizes.
struct MenuIconItem: View {
    let id: String
    let glyph: String
    var action: (() -> Void)?

    var body: some View {
        Text(glyph)
            .font(.system(size: 12))
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
            .animation(.none)
            .onTapGesture {
                action?()
            }
    }
}

extension View {
    /// `.help(_:)` landed in macOS 11; on Catalina the item simply has no
    /// tooltip rather than the whole header failing to build.
    @ViewBuilder
    func tooltipIfAvailable(_ text: String) -> some View {
        if #available(macOS 11.0, *) {
            self.help(text)
        } else {
            self
        }
    }
}
