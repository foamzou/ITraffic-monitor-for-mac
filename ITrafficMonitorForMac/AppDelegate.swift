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

    var popover: NSPopover!
    var statusBarItem: NSStatusItem!

    static func quit() {
        NSApplication.shared.terminate(self)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentView = ContentView()
        let statusBarView = AnyView(StatusBarView())
        let network = Network()
        
        // Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView.withGlobalEnvironmentObjects())
        
        NSApp.activate(ignoringOtherApps: true)
        
        self.popover = popover
        self.popover.behavior = .transient
        self.popover.animates = false
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
        if let button = self.statusBarItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                self.popover.contentViewController?.view.viewDidMoveToWindow()
                self.popover.contentViewController?.view.window?.becomeKey()
                self.popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        print("applicationWillTerminate")
    }


}
