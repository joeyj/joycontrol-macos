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
         topLeft = -1,
         center = -2
}

private let kControllerButtonToText: [ControllerButton: String] = [
    .leftStick: "🅛",
    .rightStick: "🅡",
    .minus: "-",
    .up: "↑",
    .left: "←",
    .right: "→",
    .down: "↓",
    .capture: "◍",
    .plus: "+",
    .x: "X",
    .y: "Y",
    .a: "A",
    .b: "B",
    .home: "⌂",
    .r: "🆁",
    .l: "🅻",
    .zl: "ZL",
    .zr: "ZR"
]

struct ContentView: View {
    let logger = Logger()
    @State var toggleAllowPairing: Bool
    var quickActions: [ControllerQuickActionTopLevel]
    @AppStorage("deviceAddress") private var deviceAddress: String = ""
    @ObservedObject var bluetoothManager = NintendoSwitchBluetoothManager.shared
    var body: some View {
        HStack {
            VStack {
                controllerButton(.zl)
                controllerButton(.l)
                HStack(alignment: .center) {
                    Spacer()
                    controllerButton(.minus)
                }
                controlStickView(.leftStick)
                    .padding(.bottom)
                VStack {
                    controllerButton(.up)
                    HStack(spacing: 26) {
                        controllerButton(.left)
                        controllerButton(.right)
                    }
                    controllerButton(.down)
                }
                .padding(.bottom)
                HStack(alignment: .center) {
                    Spacer()
                    controllerButton(.capture)
                }
            }.disabled(!bluetoothManager.readyForInput)
            VStack {
                VStack {
                    Toggle("Allow Pairing", isOn: $toggleAllowPairing)
                        .onChange(of: toggleAllowPairing) { value in
                            setAllowPairing(value)
                        }
                    Text("Nintendo Switch Device Address:")
                    TextField("Nintendo Switch Device Address", text: $deviceAddress)
                        .disabled(bluetoothManager.readyForInput)
                        .frame(width: 170, height: 22, alignment: .center)
                    HStack {
                        Button("Connect") {
                            bluetoothManager.connectNintendoSwitch($deviceAddress.wrappedValue)
                        }.disabled(bluetoothManager.readyForInput)
                        Button("Disconnect") {
                            bluetoothManager.disconnectNintendoSwitch()
                        }.disabled(!bluetoothManager.readyForInput)
                    }
                }.padding(.vertical)
                VStack {
                    Text("Quick Actions")
                        .font(.title2)
                    ForEach(quickActions) { item in
                        Text(item.name)
                            .font(.title3)
                            .padding(.top)
                        ForEach(item.children) { child in
                            Button(child.name) {
                                bluetoothManager.performQuickAction(quickAction: child)
                            }
                        }
                    }
                    .disabled(!bluetoothManager.readyForInput)
                }
                Spacer()
            }.frame(width: 300)
                .padding(.horizontal)
            VStack { controllerButton(.zr)
                controllerButton(.r)
                HStack(alignment: .center) {
                    controllerButton(.plus)
                    Spacer()
                }
                VStack {
                    controllerButton(.x)
                    HStack(spacing: 26) {
                        controllerButton(.y)
                        controllerButton(.a)
                    }
                    controllerButton(.b)
                }
                .padding(.bottom)
                controlStickView(.rightStick)
                    .padding(.bottom)
                HStack(alignment: .center) {
                    controllerButton(.home)
                    Spacer()
                }
            }.disabled(!bluetoothManager.readyForInput)
        }
        .toggleStyle(SwitchToggleStyle())
        .onReceive(Just(bluetoothManager), perform: { output in
            if deviceAddress.isEmpty {
                deviceAddress = output.deviceAddress
            }
        })
        .frame(width: 700, height: 460)
    }

    @ViewBuilder
    private func controllerButton(_ title: ControllerButton) -> some View {
        customButton(kControllerButtonToText[title] ?? title.rawValue) {
            if title == .leftStick || title == .rightStick {
                bluetoothManager.controlStickPushed(title, .center)
            }
            bluetoothManager.controllerButtonPushed(buttons: [title])
        }
    }

    @ViewBuilder
    private func customButton(_ text: String, degrees: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action, label: {
            Text(text)
                .frame(minWidth: 22)
                .font(.system(size: 22))
                .rotationEffect(.degrees(Double(degrees * 45)))
                .padding(.horizontal, 3)
        })

            .buttonStyle(PlainButtonStyle())
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .padding(.all, 3)
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
        customButton("↑", degrees: direction.rawValue) {
            bluetoothManager.controlStickPushed(button, direction)
        }
    }

    private func setAllowPairing(_ allowPairing: Bool) {
        bluetoothManager.setScanEnabled(enabled: allowPairing)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(toggleAllowPairing: false, quickActions: kQuickActions)
    }
}
