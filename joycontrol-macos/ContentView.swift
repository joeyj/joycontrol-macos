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
        HStack {
            VStack {
                controllerButton(.zl)
                controllerButton(.l)
                HStack(alignment: .center) {
                    Spacer()
                    controllerButton(.minus, "-")
                }
                controlStickView(.leftStick)
                    .padding(.bottom)
                VStack {
                    controllerButton(.up, "↑")
                    HStack(spacing: 26) {
                        controllerButton(.left, "←")
                        controllerButton(.right, "→")
                    }
                    controllerButton(.down, "↓")
                }
                .padding(.bottom)
                HStack(alignment: .center) {
                    Spacer()
                    controllerButton(.capture, "◍")
                }
            }
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
            }
            .padding(.horizontal)
            VStack { controllerButton(.zr)
                controllerButton(.r)
                HStack(alignment: .center) {
                    controllerButton(.plus, "+")
                    Spacer()
                }
                VStack {
                    controllerButton(.x, "X")
                    HStack(spacing: 26) {
                        controllerButton(.y, "Y")
                        controllerButton(.a, "A")
                    }
                    controllerButton(.b, "B")
                }
                .padding(.bottom)
                controlStickView(.rightStick)
                    .padding(.bottom)
                HStack(alignment: .center) {
                    controllerButton(.home, "⌂")
                    Spacer()
                }
            }
        }
        .toggleStyle(SwitchToggleStyle())
        .onReceive(Just(bluetoothManager), perform: { output in
            if deviceAddress.isEmpty {
                deviceAddress = output.deviceAddress
            }
        })
        .frame(width: 580, height: 340)
    }

    @ViewBuilder
    private func controllerButton(_ title: ControllerButton, _ text: String? = nil) -> some View {
        Button(text ?? title.rawValue) {
            bluetoothManager.controllerButtonPushed(buttons: [title])
        }
    }

    @ViewBuilder
    private func controlStickView(_ button: ControllerButton) -> some View {
        VStack {
            HStack {
                controlStickDirectionButton(.topLeft, button)
                controlStickDirectionButton(.top, button)
                controlStickDirectionButton(.topRight, button)
            }
            HStack {
                controlStickDirectionButton(.left, button)
                controllerButton(button)
                controlStickDirectionButton(.right, button)
            }
            HStack {
                controlStickDirectionButton(.bottomLeft, button)
                controlStickDirectionButton(.bottom, button)
                controlStickDirectionButton(.bottomRight, button)
            }
        }
        .padding(.bottom)
    }

    @ViewBuilder
    private func controlStickDirectionButton(_ direction: StickDirection, _ button: ControllerButton) -> some View {
        Button(action: {
            bluetoothManager.controlStickPushed(button, direction)
        }, label: {
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
