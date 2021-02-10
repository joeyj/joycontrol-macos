//
//  ContentView.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/24/21.
//

import SwiftUI
import CoreBluetooth

protocol ControllerButtonDelegate {
    func controllerButtonPushed(buttons: [ControllerButton]) -> Void
    func setAllowPairing(_ value: Bool) -> Void
}

struct ContentView: View {
    init(delegate: ControllerButtonDelegate) {
        self.delegate = delegate
    }
    private var delegate: ControllerButtonDelegate
    @State private var toggleAllowPairing = false
    var body: some View {
        VStack(alignment: .center, spacing: nil, content: {
            Toggle("Allow Pairing", isOn:$toggleAllowPairing ).onChange(of: toggleAllowPairing, perform: { value in
                self.delegate.setAllowPairing(value)
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
    }
    func controllerButton(_ title: ControllerButton) -> Button<Text> {
        return Button(title.rawValue, action: {
            delegate.controllerButtonPushed(buttons: [title])
        })
    }
    
}

func controllerButton(title: String) -> Button<Text> {
    return Button(title, action: {})
}

class NoopControllerDelegate: ControllerButtonDelegate {
    func controllerButtonPushed(buttons: [ControllerButton]) {
    }
    func setAllowPairing(_ value: Bool) {
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(delegate: NoopControllerDelegate())
    }
}
