//
//  joycontrol_macosApp.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/24/21.
//

import SwiftUI

@main
struct JoycontrolMacosApp: App {
    // swiftlint:disable:next weak_delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
    var body: some Scene {
        WindowGroup {
            ContentView(toggleAllowPairing: NintendoSwitchBluetoothManager.shared.getIsScanEnabled())
        }
    }
}
