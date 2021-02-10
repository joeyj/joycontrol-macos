//
//  ControllerState.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/29/21.
//

import Foundation
import os.log

public class ControllerState {
    private var logger: Logger = Logger()
    private var controllerProtocol: ControllerProtocol
    private var controller: Controller
    private var spiFlash: FlashMemory
    public var buttonState: ButtonState
    public var leftStickState: StickState?
    public var rightStickState: StickState?
    public var sendCompleteSemaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    public init(controllerProtocol: ControllerProtocol, controller: Controller, spiFlash: FlashMemory) {
        self.controllerProtocol = controllerProtocol
        self.controller = controller
        self.spiFlash = spiFlash
        
        self.buttonState = ButtonState(controller)
        
        // create left stick state
        self.leftStickState = nil
        self.rightStickState = nil
        if [Controller.proController, Controller.joyconL].contains(controller) {
            // load calibration data from memory
            var calibrationData = spiFlash.getUserLStickCalibration()
            if calibrationData == nil {
                calibrationData = spiFlash.getFactoryLStickCalibration()
            }
            let calibration = LeftStickCalibration.fromBytes(calibrationData!)
            
            self.leftStickState = try! StickState(calibration: calibration)
            try! self.leftStickState!.setCenter()
        }
        
        // create right stick state
        if [Controller.proController, Controller.joyconR].contains(controller) {
            // load calibration data from memory
            var calibrationData = spiFlash.getUserRStickCalibration()
            if calibrationData == nil {
                calibrationData = spiFlash.getFactoryRStickCalibration()
            }
            let calibration = RightStickCalibration.fromBytes(calibrationData!)
            
            self.rightStickState = try! StickState(calibration: calibration)
            try! self.rightStickState!.setCenter()
        }
        self.sendCompleteSemaphore = DispatchSemaphore(value: 0)
    }
    public func getController() -> Controller {
        return self.controller
    }
    public func getFlashMemory() -> FlashMemory? {
        return self.spiFlash
    }
    ///Invokes protocol.sendControllerState(). Returns after the controller state was sent.
    public func send() {
        try! self.controllerProtocol.sendControllerState()
    }
    ///Waits until the switch is paired with the controller and accepts button commands
    public func connect() {
        self.controllerProtocol.setPlayerLightsSemaphore.wait()
    }
}

///Utility class to set buttons in the input report
///
///https://github.com/dekuNukem/NintendoSwitchReverseEngineering/blob/master/bluetoothHidNotes.md
///
///    Byte     0         1         2         3         4         5         6         7
///    1       Y         X         B         A         SR         SL         R         ZR
///    2       Minus     Plus     R Stick L Stick Home     Capture
///    3       Down     Up         Right     Left     SR         SL         L         ZL
public class ButtonState {
    private static let byte1Key: String = "byte1"
    private static let byte2Key: String = "byte2"
    private static let byte3Key: String = "byte3"
    public var controller: Controller
    private var logger: Logger = Logger()
    private var availableButtons: [ControllerButton]=[]
    private var buttonStates: Dictionary<String, Byte> = Dictionary()
    private var buttonFuncs: Dictionary<ControllerButton, ((Bool)->Void, ()->Bool)> = Dictionary()
    public init(_ controller: Controller) {
        self.controller = controller
        
        reset()
        
        // generating methods for each button
        func buttonMethodFactory(_ byte: String, _ bit: Byte) -> ((Bool)->Void, ()->Bool) {
            func setter(pushed:Bool=true) {
                let Byte = buttonStates[byte] ?? 0
                
                if pushed != Utils.getBit(Byte, bit) {
                    let newValue = Utils.flipBit(Byte, bit)
                    logger.info("Updating value for byte \(byte) with \(newValue)")
                    buttonStates.updateValue(newValue, forKey: byte)
                }
            }
            
            func getter() ->Bool {
                return Utils.getBit(buttonStates[byte] ?? 0, bit)
            }
            return (setter, getter)
        }
        
        if controller == Controller.proController {
            self.availableButtons = [ControllerButton.y, ControllerButton.x, ControllerButton.b, ControllerButton.a, ControllerButton.r, ControllerButton.zr,
                                      ControllerButton.minus, ControllerButton.plus, ControllerButton.rightStick, ControllerButton.leftStick, ControllerButton.home, ControllerButton.capture,
                                      ControllerButton.down, ControllerButton.up, ControllerButton.right, ControllerButton.left, ControllerButton.l, ControllerButton.zl]
        }
        else if controller == Controller.joyconR {
            self.availableButtons = [ControllerButton.y, ControllerButton.x, ControllerButton.b, ControllerButton.a, ControllerButton.sr, ControllerButton.sl, ControllerButton.r, ControllerButton.zr,
                                      ControllerButton.plus, ControllerButton.rightStick, ControllerButton.home]
        }
        else if controller == Controller.joyconL {
            self.availableButtons = [ControllerButton.minus, ControllerButton.leftStick, ControllerButton.capture,
                                      ControllerButton.down, ControllerButton.up, ControllerButton.right, ControllerButton.left, ControllerButton.sr, ControllerButton.sl, ControllerButton.l, ControllerButton.zl]
        }
        
        // byte 1
        if controller == Controller.proController || controller == Controller.joyconR {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 0), forKey: ControllerButton.y)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 1), forKey: ControllerButton.x)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 2), forKey: ControllerButton.b)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 3), forKey: ControllerButton.a)
            
            if controller == Controller.joyconR {
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 4), forKey: ControllerButton.sr)
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 5), forKey: ControllerButton.sl)
            }
            
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 6), forKey: ControllerButton.r)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte1Key, 7), forKey: ControllerButton.zr)
        }
        
        // byte 2
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Key, 0), forKey: ControllerButton.minus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Key, 1), forKey: ControllerButton.plus)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Key, 2), forKey: ControllerButton.rightStick)
        buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Key, 3), forKey: ControllerButton.leftStick)
        if controller == Controller.joyconR || controller == Controller.proController {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Key, 4), forKey: ControllerButton.home)
        }
        if controller == Controller.joyconL || controller == Controller.proController {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte2Key, 5), forKey: ControllerButton.capture)
        }
        // byte 3
        if controller == Controller.proController || controller == Controller.joyconL {
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 0), forKey: ControllerButton.down)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 1), forKey: ControllerButton.up)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 2), forKey: ControllerButton.right)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 3), forKey: ControllerButton.left)
            
            if controller == Controller.joyconL {
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 4), forKey: ControllerButton.sr)
                buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 5), forKey: ControllerButton.sl)
            }
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 6), forKey: ControllerButton.l)
            buttonFuncs.updateValue(buttonMethodFactory(ButtonState.byte3Key, 7), forKey: ControllerButton.zl)
        }
    }
    public func setButton(_ button: ControllerButton, pushed:Bool=true) throws {
        logger.info(#function)
        if !self.availableButtons.contains(button) {
            throw ApplicationError.general("Given button \"\(button)\" is not available to \(controller.name).")
        }
        buttonFuncs[button]!.0(pushed)
    }
    public func getButton(_ button: ControllerButton) throws  -> Bool{
        logger.info(#function)
        if !self.availableButtons.contains(button) {
            throw ApplicationError.general("Given button \"\(button)\" is not available to \(controller.name).")
        }
        return buttonFuncs[button]!.1()
    }
    public func getAvailableButtons() -> [ControllerButton] {
        return self.availableButtons
    }
    public func bytes() -> Bytes {
        logger.info(#function)
        logger.info("\(String(describing: [self.buttonStates[ButtonState.byte1Key]!, self.buttonStates[ButtonState.byte2Key]!, self.buttonStates[ButtonState.byte3Key]!]))")
        return [buttonStates[ButtonState.byte1Key]!, buttonStates[ButtonState.byte2Key]!, buttonStates[ButtonState.byte3Key]!]
    }
    public func reset() {
        buttonStates.updateValue(0, forKey: ButtonState.byte1Key)
        buttonStates.updateValue(0, forKey: ButtonState.byte2Key)
        buttonStates.updateValue(0, forKey: ButtonState.byte3Key)
    }
}

///Set given buttons in the controller state to the pressed down state and wait till send.
public func buttonPress(_ controllerState: ControllerState, _ buttons: [ControllerButton])throws  {
    if buttons.count == 0 {
        throw ApplicationError.general("No Buttons were given.")
    }
    
    let buttonState = controllerState.buttonState
    
    for button in buttons {
        // push button
        try! buttonState.setButton(button, pushed:true)
    }
    
    // wait until report is send
    controllerState.send()
}
///Set given buttons in the controller state to the unpressed state and wait till send.
public func buttonRelease(_ controllerState: ControllerState, _ buttons: [ControllerButton]) throws {
    if buttons.count == 0 {
        throw ApplicationError.general("No Buttons were given.")
    }
    
    let buttonState = controllerState.buttonState
    
    for button in buttons {
        // release button
        try! buttonState.setButton(button, pushed:false)
    }
    
    // wait until report is send
    controllerState.send()
}

/// Shortly push the given buttons. Wait until the controller state is sent.
/// - Parameters:
///   - sec: Seconds to wait before releasing the button, default: 0.1
public func buttonPush(controllerState: ControllerState, buttons: [ControllerButton], sec: Double=0.1) {
    try! buttonPress(controllerState, buttons)
    DispatchQueue.main.asyncAfter(deadline: .now() + sec) {
        try! buttonRelease(controllerState, buttons)
    }
}

public class StickCalibration : CustomDebugStringConvertible {
    public var hCenter: Byte
    public var vCenter: Byte
    public var hMaxAboveCenter: Byte
    public var vMaxAboveCenter: Byte
    public var hMaxBelowCenter: Byte
    public var vMaxBelowCenter: Byte
    
    public init(_ hCenter: Byte, _ vCenter: Byte, _ hMaxAboveCenter: Byte, _ vMaxAboveCenter: Byte, _ hMaxBelowCenter: Byte, _ vMaxBelowCenter: Byte) {
        self.hCenter = hCenter
        self.vCenter = vCenter
        self.hMaxAboveCenter = hMaxAboveCenter
        self.vMaxAboveCenter = vMaxAboveCenter
        self.hMaxBelowCenter = hMaxBelowCenter
        self.vMaxBelowCenter = vMaxBelowCenter
    }
    public var debugDescription: String {
        return "hCenter:\(self.hCenter) vCenter:\(self.vCenter) hMaxAboveCenter:\(self.hMaxAboveCenter) " +
            "vMaxAboveCenter:\(self.vMaxAboveCenter) hMaxBelowCenter:\(self.hMaxBelowCenter) " +
            "vMaxBelowCenter:\(self.vMaxBelowCenter)"
    }
}

public class LeftStickCalibration {
    public static func fromBytes(_ _9bytes: Bytes) -> StickCalibration {
        let hMaxAboveCenter: Byte = Byte(UInt16(_9bytes[1] << 8) & 0xF00 | UInt16(_9bytes[0]))
        let vMaxAboveCenter: Byte = Byte((_9bytes[2] << 4) | (_9bytes[1] >> 4))
        let hCenter: Byte =           Byte(UInt16(_9bytes[4] << 8) & 0xF00 | UInt16(_9bytes[3]))
        let vCenter: Byte =           Byte((_9bytes[5] << 4) | (_9bytes[4] >> 4))
        let hMaxBelowCenter: Byte = Byte(UInt16(_9bytes[7] << 8) & 0xF00 | UInt16(_9bytes[6]))
        let vMaxBelowCenter: Byte = Byte((_9bytes[8] << 4) | (_9bytes[7] >> 4))
        
        return StickCalibration(hCenter, vCenter, hMaxAboveCenter, vMaxAboveCenter,
                                hMaxBelowCenter, vMaxBelowCenter)
    }
}
public class RightStickCalibration {
    public static func fromBytes(_ _9bytes: Bytes) -> StickCalibration {
        let hMaxAboveCenter: Byte = Byte(UInt16(_9bytes[1] << 8) & 0xF00 | UInt16(_9bytes[0]))
        let vMaxAboveCenter: Byte = Byte((_9bytes[2] << 4) | (_9bytes[1] >> 4))
        let hCenter: Byte =           Byte(UInt16(_9bytes[4] << 8) & 0xF00 | UInt16(_9bytes[3]))
        let vCenter: Byte =           Byte((_9bytes[5] << 4) | (_9bytes[4] >> 4))
        let hMaxBelowCenter: Byte = Byte(UInt16(_9bytes[7] << 8) & 0xF00 | UInt16(_9bytes[6]))
        let vMaxBelowCenter: Byte = Byte((_9bytes[8] << 4) | (_9bytes[7] >> 4))
        
        return StickCalibration(hCenter, vCenter, hMaxAboveCenter, vMaxAboveCenter,
                                hMaxBelowCenter, vMaxBelowCenter)
    }
}
public class StickState {
    private var hStick: Byte = 0
    private var vStick: Byte = 0
    private var calibration: StickCalibration?
    public init(h: Byte = 0, v: Byte = 0, calibration: StickCalibration? = nil) throws {
        for val in [h, v] {
            try! validate(val)
        }
        
        self.hStick = h
        self.vStick = v
        
        self.calibration = calibration
    }
    private func validate(_ val: Byte) throws {
        if !(0 <= val && val < 0xFF) { //0x1000) { Why does this support larger than byte values?
            throw ApplicationError.general("Stick values must be in [0,\(0xFF))")
        }
    }
    public func setH(value: Byte) {
        try! validate(value)
        self.hStick = value
    }
    public func getH() -> Byte {
        return self.hStick
    }
    public func setV(value: Byte) {
        try! validate(value)
        self.vStick = value
    }
    public func getV() -> Byte {
        return self.vStick
    }
    public func setCenter() throws {
        let calibration = try! getCalibration()
        self.hStick = calibration.hCenter
        self.vStick = calibration.vCenter
    }
    public func isCenter(radius: Byte=0) -> Bool {
        let calibration = try! getCalibration()
        
        return calibration.hCenter - radius <= self.hStick && self.hStick <= calibration.hCenter + radius && calibration.vCenter - radius <= self.vStick && self.vStick <= calibration.vCenter + radius
    }
    public func setUp() throws {
        let calibration = try! getCalibration()
        self.hStick = calibration.hCenter
        self.vStick = calibration.vCenter + calibration.vMaxAboveCenter
    }
    public func setDown() throws {
        let calibration = try! getCalibration()
        self.hStick = calibration.hCenter
        self.vStick = calibration.vCenter - calibration.vMaxBelowCenter
    }
    public func setLeft() throws {
        let calibration = try! getCalibration()
        self.hStick = calibration.hCenter - calibration.hMaxBelowCenter
        self.vStick = calibration.vCenter
    }
    public func setRight() throws {
        let calibration = try! getCalibration()
        self.hStick = calibration.hCenter + calibration.hMaxAboveCenter
        self.vStick = calibration.vCenter
    }
    public func setCalibration(calibration: StickCalibration) {
        self.calibration = calibration
    }
    public func getCalibration() throws -> StickCalibration {
        if self.calibration == nil {
            throw ApplicationError.general("No calibration data available.")
        }
        return self.calibration!
    }
    
    public static func fromBytes(_3bytes: Bytes) -> StickState {
        let stickH = _3bytes[0] | ((_3bytes[1] & 0xF) << 8)
        let stickV = (_3bytes[1] >> 4) | (_3bytes[2] << 4)
        
        return try! StickState(h:stickH, v:stickV)
    }
    public func bytes() -> Bytes {
        let byte_1 = 0xFF & self.hStick
        let byte_2 = (self.hStick >> 8) | ((0xF & self.vStick) << 4)
        let byte_3 = self.vStick >> 4
        return [byte_1, byte_2, byte_3]
    }
}
