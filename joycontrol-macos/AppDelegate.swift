//
//  AppDelegate.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/15/21.
//

import SwiftUI
import Foundation

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationWillTerminate(_ notification: Notification) {
        NintendoSwitchBluetoothManager.shared.cleanup()
    }
}
