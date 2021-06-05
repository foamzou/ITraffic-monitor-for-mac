//
//  Nettop.swift
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
    
    func debug(_ s: String) {
        let task = Process()
        task.launchPath = "/bin/bash"
        let command = "echo \"\(s)\" >> /tmp/temp.log"
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
    }
    
    public func startListenNetwork() {
        let duration = 2
        let nettopPath = Bundle.main.path(forResource: "nettop-line", ofType: nil)!
        let task = shellPipe("\"\(nettopPath)\" -P -d -L 0 -J bytes_in,bytes_out -t external -s \(duration) -c") { [self] output in
            tryToMakeAppSleepDeep()
            
            let rows = output.components(separatedBy: "|SPLIT|").map { String($0) }
            
            var totalInBytes = 0
            var totalOutBytes = 0
            let entities: [ProcessEntity] = rows.map { self.parser(text: $0, duration: duration) }.compactMap { entity-> ProcessEntity? in
                if (entity == nil) {
                    return nil;
                }
                totalInBytes += entity?.inBytes ?? 0
                totalOutBytes += entity?.outBytes ?? 0
                return entity
            }
            DispatchQueue.main.async {
                self.statusDataModel.update(totalInBytes: totalInBytes, totalOutBytes: totalOutBytes)
                self.viewModel.updateData(newItems: entities)
            }
        }
        task.resume()
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
    
    func parser(text: String, duration: Int) -> ProcessEntity? {
        let item = text.split(separator: ",")
        if item.count < 3 {
            return nil
        }
        let inBytes = (Int(item[1]) ?? 0) / duration
        let outBytes = (Int(item[2]) ?? 0) / duration

        let nameAndPid = item[0].split(separator: ".")
        let pid = nameAndPid[nameAndPid.count - 1]

        return ProcessEntity(pid: Int(pid) ?? 0, name: String(nameAndPid[0]), inBytes: inBytes, outBytes: outBytes)
    }

    @discardableResult
    func shellPipe(_ args: String..., onData: ((String) -> Void)? = nil, didTerminate: (() -> Void)? = nil) -> Process {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardInput = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c"] + args

        var firstLoad = true
        var buffer = Data()
        let outHandle = pipe.fileHandleForReading
        var str = ""
        var data = Data()
        outHandle.readabilityHandler = { _ in
            data = outHandle.availableData

            if data.count > 0 {
                buffer += data
                str = String(data: buffer, encoding: String.Encoding.utf8) ?? ""
                if str.last?.isNewline == true {
                    buffer.removeAll()
                    // There is wrong info when first load, skip it
                    if (firstLoad) {
                        firstLoad = false
                    } else {
                        onData?(str)
                    }
                }
                outHandle.waitForDataInBackgroundAndNotify() // todo memory leak here. Maybe should restart the sub-process in a while
            } else {
                buffer.removeAll()
            }
        }
        outHandle.waitForDataInBackgroundAndNotify()

        task.terminationHandler = { _ in
            try? outHandle.close()
            didTerminate?()
        }

        DispatchQueue(label: "shellPipe-\(UUID().uuidString)", qos: .background, attributes: .concurrent).async {
            do {
                try task.run()
            } catch {
                print("shell pipe executed with error", error)
            }
        }

        return task
    }
}
