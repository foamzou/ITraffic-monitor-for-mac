//
//  Network.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import Foundation
import SwiftUI

class Network {
    @ObservedObject var viewModel = SharedStore.listViewModel
    @ObservedObject var statusDataModel = SharedStore.statusDataModel
    @ObservedObject var globalModel = SharedStore.globalModel

    private let interval = 2

    private lazy var runner: NettopRunner = {
        let r = NettopRunner(interval: interval)
        r.onFrame = { [weak self] lines in
            self?.handleFrame(lines)
        }
        return r
    }()

    public func startListenNetwork() {
        runner.start()
    }

    public func stopListenNetwork() {
        runner.stop()
    }

    private func handleFrame(_ lines: [String]) {
        tryToMakeAppSleepDeep()

        var totalInRate = 0
        var totalOutRate = 0
        let entities: [ProcessEntity] = lines.compactMap { line -> ProcessEntity? in
            guard let entity = parser(text: line) else { return nil }
            totalInRate += entity.inBytesPerSec
            totalOutRate += entity.outBytesPerSec
            return entity
        }

        DispatchQueue.main.async {
            self.statusDataModel.update(totalInBytesPerSec: totalInRate, totalOutBytesPerSec: totalOutRate)
            self.viewModel.updateData(newItems: entities)
        }
    }

    var sleepCounter = 0
    let MAX_COUNT = 30
    func tryToMakeAppSleepDeep() {
        if !globalModel.viewShowing && sleepCounter >= MAX_COUNT {
            globalModel.isSleepDeep = true
            if globalModel.controllerHaveBeenReleased == false {
                print("into sleep deep, release controller")
                DispatchQueue.main.async {
                    AppDelegate.popover.contentViewController = nil
                }
                globalModel.controllerHaveBeenReleased = true
            }
            return
        }
        if sleepCounter >= MAX_COUNT {
            sleepCounter = 0
        }
        if !globalModel.viewShowing {
            sleepCounter += 1
        }
        globalModel.isSleepDeep = false
    }

    /// nettop runs in delta mode (`-d`) on an `interval`-second sample, so every
    /// frame reports the bytes moved across that whole window. Normalise to
    /// bytes/sec right here, at the single point where raw nettop numbers enter
    /// the app — the status bar and the process list then read the same unit.
    ///
    /// Do not move this divide "up" to the aggregation point: 0.2.0 did exactly
    /// that, and the popover list kept rendering raw 2-second deltas, i.e. double
    /// the menu bar's rate (issue #28).
    func parser(text: String) -> ProcessEntity? {
        let item = text.split(separator: ",")
        if item.count < 3 {
            return nil
        }
        let inBytesPerSec  = (Int(item[1]) ?? 0) / interval
        let outBytesPerSec = (Int(item[2]) ?? 0) / interval

        let nameAndPid = item[0].split(separator: ".")
        guard nameAndPid.count >= 2 else {
            return nil
        }
        let pid = nameAndPid[nameAndPid.count - 1]
        var name = nameAndPid
        name.removeLast()

        return ProcessEntity(
            pid: Int(pid) ?? 0,
            name: name.joined(separator: "."),
            inBytesPerSec: inBytesPerSec,
            outBytesPerSec: outBytesPerSec
        )
    }
}
