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
