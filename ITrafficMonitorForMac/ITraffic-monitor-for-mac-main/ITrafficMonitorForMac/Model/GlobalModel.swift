//
//  GlobalModel.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/30.
//

import Foundation

class GlobalModel: ObservableObject {
    @Published var viewShowing: Bool = false
    @Published var controllerHaveBeenReleased: Bool  = true
    @Published var isSleepDeep = false
}
