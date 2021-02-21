//
//  ButtonState.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/20/21.
//

import Foundation
import os.log

/// Utility class to set buttons in the input report
///
/// https://github.com/dekuNukem/NintendoSwitchReverseEngineering/blob/master/bluetoothHidNotes.md
///
///    Byte     0         1         2         3         4         5         6         7
///    1        Y         X         B         A         SR        SL        R         ZR
///    2        Minus     Plus      R Stick   L Stick   Home      Capture
///    3        Down      Up        Right     Left      SR        SL        L         ZL
class ButtonState {
    private static let byte1Index = 0
    private static let byte2Index = 1
    private static let byte3Index = 2
    private static let controllerToButtons: [Controller: [ControllerButton]] = [
        Controller.proController: [
            ControllerButton.y, ControllerButton.x,
            ControllerButton.b, ControllerButton.a,
            ControllerButton.r, ControllerButton.zr,
            ControllerButton.minus, ControllerButton.plus,
            ControllerButton.rightStick, ControllerButton.leftStick,
            ControllerButton.home, ControllerButton.capture,
            ControllerButton.down, ControllerButton.up,
            ControllerButton.right, ControllerButton.left,
            ControllerButton.l, ControllerButton.zl
        ],
        Controller.joyconR: [
            ControllerButton.y, ControllerButton.x,
            ControllerButton.b, ControllerButton.a,
            ControllerButton.sr, ControllerButton.sl,
            ControllerButton.r, ControllerButton.zr,
            ControllerButton.plus, ControllerButton.rightStick,
            ControllerButton.home
        ],
        Controller.joyconL: [
            ControllerButton.minus, ControllerButton.leftStick,
            ControllerButton.capture, ControllerButton.down,
            ControllerButton.up, ControllerButton.right,
            ControllerButton.left, ControllerButton.sr,
            ControllerButton.sl, ControllerButton.l,
            ControllerButton.zl
        ]
    ]
    let controller: Controller
    private let logger = Logger()
    private let availableButtons: [ControllerButton]
    private var buttonStates: Bytes = [0, 0, 0]
    private var buttonFuncs: [ControllerButton: ((Bool) -> Void, () -> Bool)] = Dictionary()
    init(_ controller: Controller) {
        self.controller = controller

        availableButtons = ButtonState.controllerToButtons[controller]!

        if controller == Controller.proController || controller == Controller.joyconR {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 0), forKey: ControllerButton.y)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 1), forKey: ControllerButton.x)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 2), forKey: ControllerButton.b)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 3), forKey: ControllerButton.a)

            if controller == Controller.joyconR {
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 4), forKey: ControllerButton.sr)
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 5), forKey: ControllerButton.sl)
            }

            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 6), forKey: ControllerButton.r)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 7), forKey: ControllerButton.zr)
        }

        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 0), forKey: ControllerButton.minus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 1), forKey: ControllerButton.plus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 2), forKey: ControllerButton.rightStick)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 3), forKey: ControllerButton.leftStick)
        if controller == Controller.joyconR || controller == Controller.proController {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 4), forKey: ControllerButton.home)
        }
        if controller == Controller.joyconL || controller == Controller.proController {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 5), forKey: ControllerButton.capture)
        }

        if controller == Controller.proController || controller == Controller.joyconL {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 0), forKey: ControllerButton.down)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 1), forKey: ControllerButton.up)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 2), forKey: ControllerButton.right)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 3), forKey: ControllerButton.left)

            if controller == Controller.joyconL {
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 4), forKey: ControllerButton.sr)
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 5), forKey: ControllerButton.sl)
            }
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 6), forKey: ControllerButton.l)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 7), forKey: ControllerButton.zl)
        }
    }

    private func buttonMethodFactory(_ byte: Int, _ bit: Byte) -> ((Bool) -> Void, () -> Bool) {
        func setter(pushed: Bool = true) {
            let tempByte = buttonStates[byte]

            if pushed != Utils.getBit(tempByte, bit) {
                let newValue = Utils.flipBit(tempByte, bit)
                logger.info("Updating value for byte \(byte) with \(newValue)")
                buttonStates[byte] = newValue
            }
        }

        func getter() -> Bool {
            Utils.getBit(buttonStates[byte], bit)
        }
        return (setter, getter)
    }

    func setButton(_ button: ControllerButton, pushed: Bool = true) throws {
        logger.info(#function)
        if !availableButtons.contains(button) {
            throw ApplicationError.general("Given button \"\(button)\" is not available to \(controller.name).")
        }
        buttonFuncs[button]!.0(pushed)
    }

    func getButton(_ button: ControllerButton) throws -> Bool {
        logger.info(#function)
        if !availableButtons.contains(button) {
            throw ApplicationError.general("Given button \"\(button)\" is not available to \(controller.name).")
        }
        return buttonFuncs[button]!.1()
    }

    func getAvailableButtons() -> [ControllerButton] {
        availableButtons
    }

    func bytes() -> Bytes {
        logger.info(#function)
        let byte1Value = buttonStates[ButtonState.byte1Index]
        let byte2Value = buttonStates[ButtonState.byte2Index]
        let byte3Value = buttonStates[ButtonState.byte3Index]
        logger.info("\(String(describing: [byte1Value, byte2Value, byte3Value]))")
        return [byte1Value, byte2Value, byte3Value]
    }

    func reset() {
        for index in 0 ... buttonStates.count - 1 {
            buttonStates[index] = 0
        }
    }

    deinit {}
}

/// Set given buttons in the controller state to the pressed down state and wait till send.
func buttonPress(_ controllerState: ControllerState, _ buttons: [ControllerButton]) throws {
    if buttons.isEmpty {
        throw ApplicationError.general("No Buttons were given.")
    }

    let buttonState = controllerState.buttonState

    for button in buttons {
        // push button
        try! buttonState.setButton(button, pushed: true)
    }

    // wait until report is send
    controllerState.send()
}

/// Set given buttons in the controller state to the unpressed state and wait till send.
func buttonRelease(_ controllerState: ControllerState, _ buttons: [ControllerButton]) throws {
    if buttons.isEmpty {
        throw ApplicationError.general("No Buttons were given.")
    }

    let buttonState = controllerState.buttonState

    for button in buttons {
        // release button
        try! buttonState.setButton(button, pushed: false)
    }

    // wait until report is send
    controllerState.send()
}

/// Shortly push the given buttons. Wait until the controller state is sent.
/// - Parameters:
///   - sec: Seconds to wait before releasing the button, default: 0.1
func buttonPush(controllerState: ControllerState, buttons: [ControllerButton], sec: Double = 0.1) {
    try! buttonPress(controllerState, buttons)
    DispatchQueue.main.asyncAfter(deadline: .now() + sec) {
        try! buttonRelease(controllerState, buttons)
    }
}
