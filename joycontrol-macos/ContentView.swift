//
//  ContentView.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/24/21.
//

import Combine
import os.log
import SwiftUI

enum StickDirection: Int {
    case top = 0,
         right = 2,
         bottom = 4,
         left = 6,
         topRight = 1,
         bottomRight = 3,
         bottomLeft = 5,
         topLeft = -1
}

struct ContentView: View {
    let logger = Logger()
    @State var toggleAllowPairing: Bool
    @AppStorage("deviceAddress") private var deviceAddress: String = ""
    @ObservedObject var bluetoothManager = NintendoSwitchBluetoothManager.shared
    var body: some View {
        VStack {
            Toggle("Allow Pairing", isOn: $toggleAllowPairing)
                .onChange(of: toggleAllowPairing) { value in
                    setAllowPairing(value)
                }
            Text("Nintendo Switch Device Address:")
            TextField("Nintendo Switch Device Address", text: $deviceAddress)
                .frame(width: 170, height: 22, alignment: .center)
            HStack {
                Button("Connect") {
                    bluetoothManager.connectNintendoSwitch($deviceAddress.wrappedValue)
                }
                Button("Disconnect") {
                    bluetoothManager.disconnectNintendoSwitch()
                }
            }
            HStack(spacing: 120) {
                controllerButton(.zl)
                controllerButton(.zr)
            }
            HStack(spacing: 120) {
                controllerButton(.l)
                controllerButton(.r)
            }
            HStack(spacing: 100) {
                controllerButton(.minus)
                controllerButton(.plus)
            }
            HStack(spacing: 60) {
                controlStickView(.leftStick)
                VStack {
                    controllerButton(.x)
                    HStack(content: {
                        controllerButton(.y)
                        controllerButton(.a)
                    })
                    controllerButton(.b)
                }
            }
            HStack(spacing: 60) {
                VStack {
                    controllerButton(.up)
                    HStack {
                        controllerButton(.left)
                        controllerButton(.right)
                    }
                    controllerButton(.down)
                }
                controlStickView(.rightStick)
            }
            HStack(spacing: 60) {
                controllerButton(.capture)
                controllerButton(.home)
            }
        }
        .padding()
        .toggleStyle(SwitchToggleStyle())
        .onReceive(Just(bluetoothManager), perform: { output in
            if deviceAddress.isEmpty {
                deviceAddress = output.deviceAddress
            }
        })
    }

    @ViewBuilder
    private func controllerButton(_ title: ControllerButton) -> some View {
        Button(title.rawValue) {
            bluetoothManager.controllerButtonPushed(buttons: [title])
        }
    }

    @ViewBuilder
    private func controlStickView(_ button: ControllerButton) -> some View {
        VStack {
            HStack {
                controlStickDirectionButton(.topLeft)
                controlStickDirectionButton(.top)
                controlStickDirectionButton(.topRight)
            }
            HStack {
                controlStickDirectionButton(.left)
                controllerButton(button)
                controlStickDirectionButton(.right)
            }
            HStack {
                controlStickDirectionButton(.bottomLeft)
                controlStickDirectionButton(.bottom)
                controlStickDirectionButton(.bottomRight)
            }
        }
    }

    @ViewBuilder
    private func controlStickDirectionButton(_ direction: StickDirection) -> some View {
        Button(action: {}, label: {
            Text("↑").rotationEffect(.degrees(Double(direction.rawValue * 45)))
        })
    }

    private func setAllowPairing(_ allowPairing: Bool) {
        bluetoothManager.setScanEnabled(enabled: allowPairing)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(toggleAllowPairing: false)
    }
}
