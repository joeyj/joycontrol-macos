//
//  ContentView.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/24/21.
//

import SwiftUI
import Combine
import os.log

struct ContentView: View {
    var logger: Logger = Logger()
    @AppStorage("toggleAllowPairing") private var toggleAllowPairing = false
    @AppStorage("deviceAddress") private var deviceAddress: String = ""
    @ObservedObject public var bluetoothManager: BluetoothManager = BluetoothManager.shared
    var body: some View {
        VStack(alignment: .center, spacing: nil, content: {
            Toggle("Allow Pairing", isOn:$toggleAllowPairing ).onChange(of: toggleAllowPairing, perform: { value in
                setAllowPairing(value)
            })
            TextField("Nintendo Switch Device Address", text: $deviceAddress)
            Button("Connect", action: { bluetoothManager.setupNintendoSwitchDevice($deviceAddress.wrappedValue)
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
                VStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, content: {
                    controllerButton(ControllerButton.x)
                    HStack(content: {
                        controllerButton(ControllerButton.y)
                        controllerButton(ControllerButton.a)
                    })
                    controllerButton(ControllerButton.b)
                })
            })
            HStack(alignment: .center, spacing: 60, content: {
                VStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: /*@START_MENU_TOKEN@*/nil/*@END_MENU_TOKEN@*/, content: {
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
        }).toggleStyle(SwitchToggleStyle())
        .onReceive(Just(bluetoothManager), perform: {_ in
            if deviceAddress == "" {
                deviceAddress = bluetoothManager.deviceAddress
            }
        })
    }
    func controllerButton(_ title: ControllerButton) -> Button<Text> {
        return Button(title.rawValue, action: {
            controllerButtonPushed(buttons: [title])
        })
    }
    func controllerButtonPushed(buttons: [ControllerButton]) {
        guard bluetoothManager.controllerProtocol != nil else {
            logger.info("controllerProtocol not initialized")
            return
        }
        logger.info(#function)
        logger.info("\(String(describing: buttons))")
        buttonPush(controllerState: bluetoothManager.controllerProtocol!.controllerState!,buttons:buttons)
    }
    func setAllowPairing(_ allowPairing: Bool) {
        if (allowPairing) {
            bluetoothManager.startScan()
        } else {
            bluetoothManager.stopScan()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
