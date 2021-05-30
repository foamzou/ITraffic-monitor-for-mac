//
//  StatusDataModel.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import Foundation

class StatusDataModel: ObservableObject {
    @Published var totalInBytes: Int = 0
    @Published var totalOutBytes: Int = 0
    
    public func update(totalInBytes: Int, totalOutBytes: Int) {
        self.totalInBytes = totalInBytes
        self.totalOutBytes = totalOutBytes
    }
}
