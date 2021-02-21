//
//  AppDelegate.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/15/21.
//

import Foundation
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationWillTerminate(_: Notification) {
        NintendoSwitchBluetoothManager.shared.cleanup()
    }
}
