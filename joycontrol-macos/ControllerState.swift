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

    init(_ bytesLength9: Bytes) {
        hMaxAboveCenter = Byte(UInt16(bytesLength9[1] << 8) & 0xF00 | UInt16(bytesLength9[0]))
        vMaxAboveCenter = Byte((bytesLength9[2] << 4) | (bytesLength9[1] >> 4))
        hCenter = Byte(UInt16(bytesLength9[4] << 8) & 0xF00 | UInt16(bytesLength9[3]))
        vCenter = Byte((bytesLength9[5] << 4) | (bytesLength9[4] >> 4))
        hMaxBelowCenter = Byte(UInt16(bytesLength9[7] << 8) & 0xF00 | UInt16(bytesLength9[6]))
        vMaxBelowCenter = Byte((bytesLength9[8] << 4) | (bytesLength9[7] >> 4))
    }
}

class StickState {
    private var hStick: Byte = 0
    private var vStick: Byte = 0
    private let calibration: StickCalibration
    init(calibration: StickCalibration) {
        self.calibration = calibration
    }

    private func validate(_ val: Byte) throws {
        if !(val >= 0 && val < 0xFF) {
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

    func setCenter() {
        let calibration = getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter
    }

    func isCenter(radius: Byte = 0) -> Bool {
        let calibration = getCalibration()

        return calibration.hCenter - radius <= hStick && hStick <= calibration.hCenter + radius
            && calibration.vCenter - radius <= vStick && vStick <= calibration.vCenter + radius
    }

    func setUp() {
        let calibration = getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter + calibration.vMaxAboveCenter
    }

    func setDown() {
        let calibration = getCalibration()
        hStick = calibration.hCenter
        vStick = calibration.vCenter - calibration.vMaxBelowCenter
    }

    func setLeft() {
        let calibration = getCalibration()
        hStick = calibration.hCenter - calibration.hMaxBelowCenter
        vStick = calibration.vCenter
    }

    func setRight() {
        let calibration = getCalibration()
        hStick = calibration.hCenter + calibration.hMaxAboveCenter
        vStick = calibration.vCenter
    }

    func getCalibration() -> StickCalibration {
        calibration
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

        if [Controller.proController, Controller.joyconL].contains(controller) {
            let calibrationData = spiFlash.getUserLStickCalibration() ?? spiFlash.getFactoryLStickCalibration()

            let calibration = StickCalibration(calibrationData)

            leftStickState = StickState(calibration: calibration)
            leftStickState!.setCenter()
        } else {
            leftStickState = nil
        }

        if [Controller.proController, Controller.joyconR].contains(controller) {
            let calibrationData = spiFlash.getUserRStickCalibration() ?? spiFlash.getFactoryRStickCalibration()

            let calibration = StickCalibration(calibrationData)

            rightStickState = StickState(calibration: calibration)
            rightStickState!.setCenter()
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
        controllerProtocol.sendControllerState()
    }

    /// Waits until the switch is paired with the controller and accepts button commands
    func connect() {
        controllerProtocol.setPlayerLightsSemaphore.wait()
    }
}
