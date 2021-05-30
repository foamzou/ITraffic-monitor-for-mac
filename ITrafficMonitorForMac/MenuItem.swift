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
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.gray)
            .contentShape(Rectangle())
            .animation(.none)
            .onTapGesture {
                action?()
            }
    }
}
