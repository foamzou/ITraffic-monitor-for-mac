//
//  AppDelegate.swift
//  ITrafficMonitorForMac
//
//  Created by f.zou on 2021/5/19.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    static var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var contentView: ContentView!
    @ObservedObject var globalModel = SharedStore.globalModel
    
    static func quit() {
        NSApplication.shared.terminate(self)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.contentView = ContentView()
        let statusBarView = AnyView(StatusBarView())
        let network = Network()
        
        // Create the popover
        AppDelegate.popover = NSPopover()
        AppDelegate.popover.contentSize = NSSize(width: 320, height: 420)
        AppDelegate.popover.behavior = .transient
//        popover.contentViewController = NSHostingController(rootView: contentView.withGlobalEnvironmentObjects())
        
//        NSApp.activate(ignoringOtherApps: true)
        
        AppDelegate.popover.behavior = .transient
        AppDelegate.popover.animates = false
        // Create the status item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

        if let button = self.statusBarItem.button {
            button.action = #selector(togglePopover(_:))
            let view = NSHostingView(rootView: statusBarView)
            view.setFrameSize(NSSize(width: 67, height: NSStatusBar.system.thickness))
            
            button.subviews.forEach { $0.removeFromSuperview() }
            button.addSubview(view)
            self.statusBarItem.length = 67
        }
        
        network.startListenNetwork()
    }

    
    @objc func togglePopover(_ sender: AnyObject?) {
        print("click")
        self.globalModel.viewShowing = true
        NSApp.activate(ignoringOtherApps: true)
        
        if let button = self.statusBarItem.button {
            if AppDelegate.popover.isShown {
                AppDelegate.popover.performClose(sender)
            } else {
                if globalModel.controllerHaveBeenReleased == true {
                    print("new controller")
                    AppDelegate.popover.contentViewController = NSHostingController(rootView: self.contentView.withGlobalEnvironmentObjects())
                }
                
                AppDelegate.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                AppDelegate.popover.contentViewController?.view.viewDidMoveToWindow()
                AppDelegate.popover.contentViewController?.view.window?.becomeKey()
                AppDelegate.popover.contentViewController?.view.window?.makeKey()
                
                globalModel.controllerHaveBeenReleased = false
            }
        }
    }
    
    func applicationWillResignActive(_ aNotification: Notification)
    {
        print("lost focus")
        self.globalModel.viewShowing = false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("applicationWillTerminate")
    }

}
