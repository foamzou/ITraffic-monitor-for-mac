//
//  ProcessEntity.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//
import Cocoa
import Foundation

struct ProcessEntity: Identifiable {
    var id = UUID()
    
    public var pid: Int;
    public var name: String;
    public var inBytes: Int;
    public var outBytes: Int;
    public var icon: NSImage?;
    
    public init(pid: Int, name: String, inBytes: Int, outBytes: Int) {
        self.pid = pid
        self.name = name
        self.inBytes = inBytes
        self.outBytes = outBytes
        self.icon = nil
    }
}
