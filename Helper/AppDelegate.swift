//
//  AppDelegate.swift
//  eqMac2Helper
//
//  Created by Romans Kisils on 08/10/2017.
//  Copyright © 2017 Romans Kisils. All rights reserved.
//

import Cocoa
import Helper
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let helper = Helper()
        SMLoginItemSetEnabled(Bundle.main.bundleIdentifier! as CFString, true)
        helper.start()
    }

}

