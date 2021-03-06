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
    private let logger = Logger()
    private let availableButtons: [ControllerButton] = [
        .y, .x, .b, .a, .r, .zr, .minus, .plus, .rightStick, .leftStick,
        .home, .capture, .down, .up, .right, .left, .l, .zl
    ]
    private var buttonStates: Bytes = [0, 0, 0]
    private var buttonFuncs: [ControllerButton: ((Bool) -> Void, () -> Bool)] = Dictionary()
    init() {
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 0), forKey: .y)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 1), forKey: .x)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 2), forKey: .b)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 3), forKey: .a)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 6), forKey: .r)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Index, 7), forKey: .zr)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 0), forKey: .minus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 1), forKey: .plus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 2), forKey: .rightStick)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 3), forKey: .leftStick)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 4), forKey: .home)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Index, 5), forKey: .capture)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 0), forKey: .down)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 1), forKey: .up)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 2), forKey: .right)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 3), forKey: .left)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 6), forKey: .l)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Index, 7), forKey: .zl)
    }

    private func buttonMethodFactory(_ byte: Int, _ bit: Byte) -> ((Bool) -> Void, () -> Bool) {
        func setter(pushed: Bool = true) {
            let tempByte = buttonStates[byte]

            if pushed != Utils.getBit(tempByte, bit) {
                let newValue = Utils.flipBit(tempByte, bit)
                logger.debug("Updating value for byte \(byte) with \(newValue)")
                buttonStates[byte] = newValue
            }
        }

        func getter() -> Bool {
            Utils.getBit(buttonStates[byte], bit)
        }
        return (setter, getter)
    }

    func setButton(_ button: ControllerButton, pushed: Bool = true) {
        logger.debug(#function)
        buttonFuncs[button]!.0(pushed)
    }

    func getButton(_ button: ControllerButton) -> Bool {
        logger.debug(#function)
        return buttonFuncs[button]!.1()
    }

    func getAvailableButtons() -> [ControllerButton] {
        availableButtons
    }

    func bytes() -> Bytes {
        let byte1Value = buttonStates[ButtonState.byte1Index]
        let byte2Value = buttonStates[ButtonState.byte2Index]
        let byte3Value = buttonStates[ButtonState.byte3Index]
        logger.debug("ButtonState::bytes: \(String(describing: [byte1Value, byte2Value, byte3Value]))")
        return [byte1Value, byte2Value, byte3Value]
    }

    func reset() {
        for index in 0 ... buttonStates.count - 1 {
            buttonStates[index] = 0
        }
    }

    deinit {}
}

/// Set given buttons in the controller state to the pressed down state.
func buttonPress(_ buttonState: ButtonState, _ controllerProtocol: ControllerProtocol, _ buttons: [ControllerButton]) throws {
    if buttons.isEmpty {
        throw ApplicationError.general("No Buttons were given.")
    }

    for button in buttons {
        buttonState.setButton(button, pushed: true)
    }
}

/// Set given buttons in the controller state to the unpressed state.
func buttonRelease(_ buttonState: ButtonState, _ controllerProtocol: ControllerProtocol, _ buttons: [ControllerButton]) throws {
    if buttons.isEmpty {
        throw ApplicationError.general("No Buttons were given.")
    }

    for button in buttons {
        buttonState.setButton(button, pushed: false)
    }
}

/// Shortly push the given buttons.
/// - Parameters:
///   - sec: Seconds to wait before releasing the button, default: 0.1
func buttonPush(_ buttonState: ButtonState, _ controllerProtocol: ControllerProtocol, _ buttons: [ControllerButton], sec: Double = 0.1) {
    try! buttonPress(buttonState, controllerProtocol, buttons)
    DispatchQueue.main.asyncAfter(deadline: .now() + sec) {
        try! buttonRelease(buttonState, controllerProtocol, buttons)
    }
}
