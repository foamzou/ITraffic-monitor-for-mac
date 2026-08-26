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
    /// Bytes per second. Already normalised by the sample interval in
    /// `Network.parser` — the name carries the unit so nothing downstream
    /// has to guess (that guess is what produced issue #28).
    public var inBytesPerSec: Int;
    public var outBytesPerSec: Int;
    public var icon: NSImage?;

    public init(pid: Int, name: String, inBytesPerSec: Int, outBytesPerSec: Int) {
        self.pid = pid
        self.name = name
        self.inBytesPerSec = inBytesPerSec
        self.outBytesPerSec = outBytesPerSec
        self.icon = nil
    }
}
