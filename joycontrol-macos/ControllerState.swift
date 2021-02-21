//
//  ControllerState.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/29/21.
//

import Foundation
import os.log

public class ControllerState {
    private var logger = Logger()
    private var controllerProtocol: ControllerProtocol
    private var controller: Controller
    private var spiFlash: FlashMemory
    public var buttonState: ButtonState
    public var leftStickState: StickState?
    public var rightStickState: StickState?
    public var sendCompleteSemaphore = DispatchSemaphore(value: 0)
    public init(controllerProtocol: ControllerProtocol, controller: Controller, spiFlash: FlashMemory) {
        self.controllerProtocol = controllerProtocol
        self.controller = controller
        self.spiFlash = spiFlash

        buttonState = ButtonState(controller)

        // create left stick state
        leftStickState = nil
        rightStickState = nil
        if [Controller.proController, Controller.joyconL].contains(controller) {
            // load calibration data from memory
            var calibrationData = spiFlash.getUserLStickCalibration()
            if calibrationData == nil {
                calibrationData = spiFlash.getFactoryLStickCalibration()
            }
            let calibration = LeftStickCalibration.fromBytes(calibrationData!)

            leftStickState = try! StickState(calibration: calibration)
            try! leftStickState!.setCenter()
        }

        // create right stick state
        if [Controller.proController, Controller.joyconR].contains(controller) {
            // load calibration data from memory
            var calibrationData = spiFlash.getUserRStickCalibration()
            if calibrationData == nil {
                calibrationData = spiFlash.getFactoryRStickCalibration()
            }
            let calibration = RightStickCalibration.fromBytes(calibrationData!)

            rightStickState = try! StickState(calibration: calibration)
            try! rightStickState!.setCenter()
        }
        sendCompleteSemaphore = DispatchSemaphore(value: 0)
    }

    public func getController() -> Controller {
        return controller
    }

    public func getFlashMemory() -> FlashMemory? {
        return spiFlash
    }

    /// Invokes protocol.sendControllerState(). Returns after the controller state was sent.
    public func send() {
        try! controllerProtocol.sendControllerState()
    }

    /// Waits until the switch is paired with the controller and accepts button commands
    public func connect() {
        controllerProtocol.setPlayerLightsSemaphore.wait()
    }
}

public class StickCalibration: CustomDebugStringConvertible {
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
        return "hCenter:\(hCenter) vCenter:\(vCenter) hMaxAboveCenter:\(hMaxAboveCenter) " +
            "vMaxAboveCenter:\(vMaxAboveCenter) hMaxBelowCenter:\(hMaxBelowCenter) " +
            "vMaxBelowCenter:\(vMaxBelowCenter)"
    }
}

public enum LeftStickCalibration {
    public static func fromBytes(_ bytesLength9: Bytes) -> StickCalibration {
        let hMaxAboveCenter = Byte(UInt16(bytesLength9[1] << 8) & 0xF00 | UInt16(bytesLength9[0]))
        let vMaxAboveCenter = Byte((bytesLength9[2] << 4) | (bytesLength9[1] >> 4))
        let hCenter = Byte(UInt16(bytesLength9[4] << 8) & 0xF00 | UInt16(bytesLength9[3]))
        let vCenter = Byte((bytesLength9[5] << 4) | (bytesLength9[4] >> 4))
        let hMaxBelowCenter = Byte(UInt16(bytesLength9[7] << 8) & 0xF00 | UInt16(bytesLength9[6]))
        let vMaxBelowCenter = Byte((bytesLength9[8] << 4) | (bytesLength9[7] >> 4))

        return StickCalibration(hCenter, vCenter, hMaxAboveCenter, vMaxAboveCenter,
                                hMaxBelowCenter, vMaxBelowCenter)
    }
}

public enum RightStickCalibration {
    public static func fromBytes(_ bytesLength9: Bytes) -> StickCalibration {
        let hMaxAboveCenter = Byte(UInt16(bytesLength9[1] << 8) & 0xF00 | UInt16(bytesLength9[0]))
        let vMaxAboveCenter = Byte((bytesLength9[2] << 4) | (bytesLength9[1] >> 4))
        let hCenter = Byte(UInt16(bytesLength9[4] << 8) & 0xF00 | UInt16(bytesLength9[3]))
        let vCenter = Byte((bytesLength9[5] << 4) | (bytesLength9[4] >> 4))
        let hMaxBelowCenter = Byte(UInt16(bytesLength9[7] << 8) & 0xF00 | UInt16(bytesLength9[6]))
        let vMaxBelowCenter = Byte((bytesLength9[8] << 4) | (bytesLength9[7] >> 4))

        return StickCalibration(hCenter, vCenter, hMaxAboveCenter, vMaxAboveCenter,
                                hMaxBelowCenter, vMaxBelowCenter)
    }
}

public class StickState {
    private var hStick: Byte = 0
    private var vStick: Byte = 0
    private var calibration: StickCalibration?
    public init(horizontal: Byte = 0, vertical: Byte = 0, calibration: StickCalibration? = nil) throws {
        for val in [horizontal, vertical] {
            try! validate(val)
        }

        hStick = horizontal
        vStick = vertical

        self.calibration = calibration
    }

    private func validate(_ val: Byte) throws {
        if !(val >= 0 && val < 0xFF) { // 0x1000) { Why does this support larger than byte values?
            throw ApplicationError.general("Stick values must be in [0,\(0xFF))")
        }
    }

    public func setH(value: Byte) {
        try! validate(value)
        hStick = value
    }

    public func getH() -> Byte {
        return hStick
    }

    public func setV(value: Byte) {
        try! validate(value)
        vStick = value
    }

    public func getV() -> Byte {
        return vStick
    }

    public func setCenter() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter
    }

    public func isCenter(radius: Byte = 0) -> Bool {
        let calibration = try! getCalibration()

        return calibration.hCenter - radius <= hStick && hStick <= calibration.hCenter + radius
            && calibration.vCenter - radius <= vStick && vStick <= calibration.vCenter + radius
    }

    public func setUp() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter + calibration.vMaxAboveCenter
    }

    public func setDown() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter - calibration.vMaxBelowCenter
    }

    public func setLeft() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter - calibration.hMaxBelowCenter
        vStick = calibration.vCenter
    }

    public func setRight() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter + calibration.hMaxAboveCenter
        vStick = calibration.vCenter
    }

    public func setCalibration(calibration: StickCalibration) {
        self.calibration = calibration
    }

    public func getCalibration() throws -> StickCalibration {
        if calibration == nil {
            throw ApplicationError.general("No calibration data available.")
        }
        return calibration!
    }

    public func bytes() -> Bytes {
        let byte1 = 0xFF & hStick
        let byte2 = (hStick >> 8) | ((0xF & vStick) << 4)
        let byte3 = vStick >> 4
        return [byte1, byte2, byte3]
    }
}
