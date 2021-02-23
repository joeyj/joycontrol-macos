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
        .proController: [
            .y, .x, .b, .a, .r, .zr, .minus, .plus, .rightStick, .leftStick,
            .home, .capture, .down, .up, .right, .left, .l, .zl
        ],
        .joyconR: [
            .y, .x, .b, .a, .sr, .sl, .r, .zr, .plus, .rightStick, .home
        ],
        .joyconL: [
            .minus, .leftStick, .capture, .down, .up, .right, .left, .sr, .sl,
            .l, .zl
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

        if controller == .proController || controller == .joyconR {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 0), forKey: .y)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 1), forKey: .x)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 2), forKey: .b)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 3), forKey: .a)

            if controller == .joyconR {
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 4), forKey: .sr)
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 5), forKey: .sl)
            }

            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 6), forKey: .r)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 7), forKey: .zr)
        }

        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 0), forKey: .minus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 1), forKey: .plus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 2), forKey: .rightStick)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 3), forKey: .leftStick)
        if controller == .joyconR || controller == .proController {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 4), forKey: .home)
        }
        if controller == .joyconL || controller == .proController {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 5), forKey: .capture)
        }

        if controller == .proController || controller == .joyconL {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 0), forKey: .down)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 1), forKey: .up)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 2), forKey: .right)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 3), forKey: .left)

            if controller == .joyconL {
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 4), forKey: .sr)
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 5), forKey: .sl)
            }
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 6), forKey: .l)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 7), forKey: .zl)
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
        logger.debug(#function)
        if !availableButtons.contains(button) {
            throw ApplicationError.general("Given button \"\(button)\" is not available to \(controller.name).")
        }
        buttonFuncs[button]!.0(pushed)
    }

    func getButton(_ button: ControllerButton) throws -> Bool {
        logger.debug(#function)
        if !availableButtons.contains(button) {
            throw ApplicationError.general("Given button \"\(button)\" is not available to \(controller.name).")
        }
        return buttonFuncs[button]!.1()
    }

    func getAvailableButtons() -> [ControllerButton] {
        availableButtons
    }

    func bytes() -> Bytes {
        logger.debug(#function)
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
