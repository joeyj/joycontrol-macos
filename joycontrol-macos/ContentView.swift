//
//  ContentView.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/24/21.
//

import Combine
import os.log
import SwiftUI

struct ContentView: View {
    let logger = Logger()
    @State var toggleAllowPairing: Bool
    @AppStorage("deviceAddress") private var deviceAddress: String = ""
    @ObservedObject var bluetoothManager = NintendoSwitchBluetoothManager.shared
    var body: some View {
        VStack(alignment: .center, spacing: nil, content: {
            Toggle("Allow Pairing", isOn: $toggleAllowPairing)
                .onChange(of: toggleAllowPairing) { value in
                    setAllowPairing(value)
                }
            TextField("Nintendo Switch Device Address", text: $deviceAddress)
            HStack(alignment: .center, spacing: nil, content: {
                Button("Connect", action: { bluetoothManager.connectNintendoSwitch($deviceAddress.wrappedValue)
                })
                Button("Disconnect", action: { bluetoothManager.disconnectNintendoSwitch($deviceAddress.wrappedValue)
                })
            })
            HStack(alignment: .center, spacing: 120, content: {
                controllerButton(ControllerButton.zl)
                controllerButton(ControllerButton.zr)
            })
            HStack(alignment: .center, spacing: 120, content: {
                controllerButton(ControllerButton.l)
                controllerButton(ControllerButton.r)
            })
            HStack(alignment: .center, spacing: 100, content: {
                controllerButton(ControllerButton.minus)
                controllerButton(ControllerButton.plus)
            })
            HStack(alignment: .center, spacing: 60, content: {
                controllerButton(ControllerButton.leftStick)
                VStack(alignment: .center, spacing: nil, content: {
                    controllerButton(ControllerButton.x)
                    HStack(content: {
                        controllerButton(ControllerButton.y)
                        controllerButton(ControllerButton.a)
                    })
                    controllerButton(ControllerButton.b)
                })
            })
            HStack(alignment: .center, spacing: 60, content: {
                VStack(alignment: .center, spacing: nil, content: {
                    controllerButton(ControllerButton.up)
                    HStack(content: {
                        controllerButton(ControllerButton.left)
                        controllerButton(ControllerButton.right)
                    })
                    controllerButton(ControllerButton.down)
                })
                controllerButton(ControllerButton.rightStick)
            })
            HStack(alignment: .center, spacing: 60, content: {
                controllerButton(ControllerButton.capture)
                controllerButton(ControllerButton.home)
            })
        })
            .padding()
            .toggleStyle(SwitchToggleStyle())
            .onReceive(Just(bluetoothManager), perform: { output in
                if deviceAddress.isEmpty {
                    deviceAddress = output.deviceAddress
                }
            })
    }

    private func controllerButton(_ title: ControllerButton) -> Button<Text> {
        Button(title.rawValue, action: {
            controllerButtonPushed(buttons: [title])
        })
    }

    private func controllerButtonPushed(buttons: [ControllerButton]) {
        guard bluetoothManager.controllerProtocol != nil else {
            logger.info("controllerProtocol not initialized")
            return
        }
        logger.info(#function)
        logger.info("\(String(describing: buttons))")
        buttonPush(controllerState: bluetoothManager.controllerProtocol!.controllerState!, buttons: buttons)
    }

    private func setAllowPairing(_ allowPairing: Bool) {
        if allowPairing {
            bluetoothManager.startScan()
        } else {
            bluetoothManager.stopScan()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(toggleAllowPairing: false)
    }
}
