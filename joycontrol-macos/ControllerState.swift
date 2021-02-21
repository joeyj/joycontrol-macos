//
//  ControllerState.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/29/21.
//

import Foundation
import os.log

struct StickCalibration: CustomDebugStringConvertible {
    let hCenter: Byte
    let vCenter: Byte
    let hMaxAboveCenter: Byte
    let vMaxAboveCenter: Byte
    let hMaxBelowCenter: Byte
    let vMaxBelowCenter: Byte

    var debugDescription: String {
        "hCenter:\(hCenter) vCenter:\(vCenter) hMaxAboveCenter:\(hMaxAboveCenter) " +
            "vMaxAboveCenter:\(vMaxAboveCenter) hMaxBelowCenter:\(hMaxBelowCenter) " +
            "vMaxBelowCenter:\(vMaxBelowCenter)"
    }

    init(_ hCenter: Byte, _ vCenter: Byte, _ hMaxAboveCenter: Byte, _ vMaxAboveCenter: Byte, _ hMaxBelowCenter: Byte, _ vMaxBelowCenter: Byte) {
        self.hCenter = hCenter
        self.vCenter = vCenter
        self.hMaxAboveCenter = hMaxAboveCenter
        self.vMaxAboveCenter = vMaxAboveCenter
        self.hMaxBelowCenter = hMaxBelowCenter
        self.vMaxBelowCenter = vMaxBelowCenter
    }
}

enum LeftStickCalibration {
    static func fromBytes(_ bytesLength9: Bytes) -> StickCalibration {
        let hMaxAboveCenter = Byte(UInt16(bytesLength9[1] << 8) & 0xF00 | UInt16(bytesLength9[0]))
        let vMaxAboveCenter = Byte((bytesLength9[2] << 4) | (bytesLength9[1] >> 4))
        let hCenter = Byte(UInt16(bytesLength9[4] << 8) & 0xF00 | UInt16(bytesLength9[3]))
        let vCenter = Byte((bytesLength9[5] << 4) | (bytesLength9[4] >> 4))
        let hMaxBelowCenter = Byte(UInt16(bytesLength9[7] << 8) & 0xF00 | UInt16(bytesLength9[6]))
        let vMaxBelowCenter = Byte((bytesLength9[8] << 4) | (bytesLength9[7] >> 4))

        return StickCalibration(
            hCenter,
            vCenter,
            hMaxAboveCenter,
            vMaxAboveCenter,
            hMaxBelowCenter,
            vMaxBelowCenter
        )
    }
}

enum RightStickCalibration {
    static func fromBytes(_ bytesLength9: Bytes) -> StickCalibration {
        let hMaxAboveCenter = Byte(UInt16(bytesLength9[1] << 8) & 0xF00 | UInt16(bytesLength9[0]))
        let vMaxAboveCenter = Byte((bytesLength9[2] << 4) | (bytesLength9[1] >> 4))
        let hCenter = Byte(UInt16(bytesLength9[4] << 8) & 0xF00 | UInt16(bytesLength9[3]))
        let vCenter = Byte((bytesLength9[5] << 4) | (bytesLength9[4] >> 4))
        let hMaxBelowCenter = Byte(UInt16(bytesLength9[7] << 8) & 0xF00 | UInt16(bytesLength9[6]))
        let vMaxBelowCenter = Byte((bytesLength9[8] << 4) | (bytesLength9[7] >> 4))

        return StickCalibration(
            hCenter,
            vCenter,
            hMaxAboveCenter,
            vMaxAboveCenter,
            hMaxBelowCenter,
            vMaxBelowCenter
        )
    }
}

class StickState {
    private var hStick: Byte = 0
    private var vStick: Byte = 0
    private let calibration: StickCalibration?
    init(horizontal: Byte = 0, vertical: Byte = 0, calibration: StickCalibration? = nil) throws {
        self.calibration = calibration
        for val in [horizontal, vertical] {
            try! validate(val)
        }

        hStick = horizontal
        vStick = vertical
    }

    private func validate(_ val: Byte) throws {
        if !(val >= 0 && val < 0xFF) { // 0x1000) { Why does this support larger than byte values?
            throw ApplicationError.general("Stick values must be in [0,\(0xFF))")
        }
    }

    func setH(value: Byte) {
        try! validate(value)
        hStick = value
    }

    func getH() -> Byte {
        hStick
    }

    func setV(value: Byte) {
        try! validate(value)
        vStick = value
    }

    func getV() -> Byte {
        vStick
    }

    func setCenter() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter
    }

    func isCenter(radius: Byte = 0) -> Bool {
        let calibration = try! getCalibration()

        return calibration.hCenter - radius <= hStick && hStick <= calibration.hCenter + radius
            && calibration.vCenter - radius <= vStick && vStick <= calibration.vCenter + radius
    }

    func setUp() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter + calibration.vMaxAboveCenter
    }

    func setDown() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter - calibration.vMaxBelowCenter
    }

    func setLeft() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter - calibration.hMaxBelowCenter
        vStick = calibration.vCenter
    }

    func setRight() throws {
        let calibration = try! getCalibration()
        hStick = calibration.hCenter + calibration.hMaxAboveCenter
        vStick = calibration.vCenter
    }

    func getCalibration() throws -> StickCalibration {
        if calibration == nil {
            throw ApplicationError.general("No calibration data available.")
        }
        return calibration!
    }

    func bytes() -> Bytes {
        let byte1 = 0xFF & hStick
        let byte2 = (hStick >> 8) | ((0xF & vStick) << 4)
        let byte3 = vStick >> 4
        return [byte1, byte2, byte3]
    }

    deinit {}
}

struct ControllerState {
    private let logger = Logger()
    private let controllerProtocol: ControllerProtocol
    private let controller: Controller
    private let spiFlash: FlashMemory
    let buttonState: ButtonState
    let leftStickState: StickState?
    let rightStickState: StickState?
    let sendCompleteSemaphore = DispatchSemaphore(value: 0)
    init(controllerProtocol: ControllerProtocol, controller: Controller, spiFlash: FlashMemory) {
        self.controllerProtocol = controllerProtocol
        self.controller = controller
        self.spiFlash = spiFlash

        buttonState = ButtonState(controller)

        // create left stick state
        if [Controller.proController, Controller.joyconL].contains(controller) {
            // load calibration data from memory
            let calibrationData = spiFlash.getUserLStickCalibration() ?? spiFlash.getFactoryLStickCalibration()

            let calibration = LeftStickCalibration.fromBytes(calibrationData)

            leftStickState = try! StickState(calibration: calibration)
            try! leftStickState!.setCenter()
        } else {
            leftStickState = nil
        }

        // create right stick state
        if [Controller.proController, Controller.joyconR].contains(controller) {
            // load calibration data from memory
            let calibrationData = spiFlash.getUserRStickCalibration() ?? spiFlash.getFactoryRStickCalibration()

            let calibration = RightStickCalibration.fromBytes(calibrationData)

            rightStickState = try! StickState(calibration: calibration)
            try! rightStickState!.setCenter()
        } else {
            rightStickState = nil
        }
    }

    func getController() -> Controller {
        controller
    }

    func getFlashMemory() -> FlashMemory? {
        spiFlash
    }

    /// Invokes protocol.sendControllerState(). Returns after the controller state was sent.
    func send() {
        try! controllerProtocol.sendControllerState()
    }

    /// Waits until the switch is paired with the controller and accepts button commands
    func connect() {
        controllerProtocol.setPlayerLightsSemaphore.wait()
    }
}
