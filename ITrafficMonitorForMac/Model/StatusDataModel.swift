//
//  StatusDataModel.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import Foundation

class StatusDataModel: ObservableObject {
    /// Machine-wide rate in bytes per second — the sum of every process's rate,
    /// so the menu bar and the popover list always agree.
    @Published var totalInBytesPerSec: Int = 0
    @Published var totalOutBytesPerSec: Int = 0

    public func update(totalInBytesPerSec: Int, totalOutBytesPerSec: Int) {
        self.totalInBytesPerSec = totalInBytesPerSec
        self.totalOutBytesPerSec = totalOutBytesPerSec
    }
}
