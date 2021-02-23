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
        setCenter()
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
        setVCenter()
        setHCenter()
    }

    func setHCenter() {
        hStick = calibration.hCenter
    }

    func setVCenter() {
        vStick = calibration.vCenter
    }

    func setVMin(force: Double = 1) {
        vStick = Byte(force * Double(calibration.vCenter - calibration.vMaxBelowCenter))
    }

    func setVMax(force: Double = 1) {
        vStick = Byte(force * Double(calibration.vCenter + calibration.vMaxAboveCenter))
    }

    func setHMin(force: Double = 1) {
        hStick = Byte(force * Double(calibration.hCenter - calibration.hMaxBelowCenter))
    }

    func setHMax(force: Double = 1) {
        hStick = Byte(force * Double(calibration.hCenter + calibration.hMaxAboveCenter))
    }

    func isCenter(radius: Byte = 0) -> Bool {
        calibration.hCenter - radius <= hStick && hStick <= calibration.hCenter + radius
            && calibration.vCenter - radius <= vStick && vStick <= calibration.vCenter + radius
    }

    func setPosition(_ direction: StickDirection, _ force: Double = 1) {
        switch direction {
        case .top:
            setUp(force: force)

        case .topRight:
            setHMax(force: force)
            setVMax(force: force)

        case .right:
            setRight(force: force)

        case .bottomRight:
            setHMax(force: force)
            setVMin(force: force)

        case .bottom:
            setDown(force: force)

        case .bottomLeft:
            setHMin(force: force)
            setVMin(force: force)

        case .left:
            setLeft(force: force)

        case .topLeft:
            setHMin(force: force)
            setVMax(force: force)
        }
    }

    func setUp(force: Double = 1) {
        setHCenter()
        setVMax(force: force)
    }

    func setDown(force: Double = 1) {
        setHCenter()
        setVMin(force: force)
    }

    func setLeft(force: Double = 1) {
        setHMin(force: force)
        setVCenter()
    }

    func setRight(force: Double = 1) {
        setHMax(force: force)
        setVCenter()
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
    private let spiFlash: FlashMemory
    let buttonState: ButtonState
    let leftStickState: StickState
    let rightStickState: StickState
    let sendCompleteSemaphore = DispatchSemaphore(value: 0)
    init(spiFlash: FlashMemory) {
        self.spiFlash = spiFlash

        buttonState = ButtonState()

        let leftStickCalibrationData = spiFlash.getUserLStickCalibration() ?? spiFlash.getFactoryLStickCalibration()

        let leftStickCalibration = StickCalibration(leftStickCalibrationData)

        leftStickState = StickState(calibration: leftStickCalibration)
        let rightStickCalibrationData = spiFlash.getUserRStickCalibration() ?? spiFlash.getFactoryRStickCalibration()

        let rightStickCalibration = StickCalibration(rightStickCalibrationData)

        rightStickState = StickState(calibration: rightStickCalibration)
    }
}
