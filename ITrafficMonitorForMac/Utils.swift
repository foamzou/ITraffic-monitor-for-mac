//
//  Utils.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/23.
//

import Foundation
import Cocoa

func formatBytes(bytes: Int) -> String {
    let kbyte = Float(bytes) / 1024
    if kbyte <= 0 {
        return "0 KB/s"
    }
    if kbyte < 1024 {
        return String(format:"%.1f KB/s", kbyte)
    }
    return String(format:"%.1f MB/s", kbyte / 1024)
}

struct AppInfo {
    var icon: NSImage
    var name: String?
    var updateTime: Int
}

var APP_INFO_CACHE = [String : AppInfo]()
var CACHE_TTL = 3600

func getAppInfo(pid: Int, name: String) -> AppInfo? {
    let timestamp = Int(NSDate().timeIntervalSince1970)
    
    let cacheKey = "\(name)\(pid)"
    let appInfoInCache = APP_INFO_CACHE[cacheKey]
    let updateTimeInCache = appInfoInCache?.updateTime ?? 0
    if appInfoInCache != nil || (timestamp - updateTimeInCache) < CACHE_TTL {
        return appInfoInCache!
    }
    print("\(pid) not hit cache")
    let appIns = NSRunningApplication(processIdentifier: pid_t(pid))
    
    let icon = resize(image: (appIns?.icon ?? NSImage(named: "blank"))!, w: 16, h: 16)
    
    APP_INFO_CACHE[cacheKey] = AppInfo(icon: icon, name: appIns?.localizedName ?? name, updateTime: timestamp)
    return APP_INFO_CACHE[cacheKey]
}

func resize(image: NSImage, w: Int, h: Int) -> NSImage {
    let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
    let newImage = NSImage(size: destSize)
    newImage.lockFocus()
    image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height), from: NSMakeRect(0, 0, image.size.width, image.size.height), operation: .colorBurn, fraction: CGFloat(1))
    newImage.unlockFocus()
    newImage.size = destSize
    return newImage
}
