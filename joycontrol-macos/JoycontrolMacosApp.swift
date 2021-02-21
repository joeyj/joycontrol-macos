//
//  joycontrol_macosApp.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/24/21.
//

import SwiftUI

@main
struct JoycontrolMacosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(toggleAllowPairing: NintendoSwitchBluetoothManager.shared.getIsScanEnabled())
        }
    }
}
