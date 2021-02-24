//
//  ControllerState.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/29/21.
//

import Foundation
import os.log

struct StickCalibration: CustomDebugStringConvertible {
    let hCenter: UInt16
    let vCenter: UInt16
    let hMaxAboveCenter: UInt16
    let vMaxAboveCenter: UInt16
    let hMaxBelowCenter: UInt16
    let vMaxBelowCenter: UInt16

    var bytes: [UInt16] {
        [
            hCenter, vCenter, hMaxAboveCenter, vMaxAboveCenter, hMaxBelowCenter, vMaxBelowCenter
        ]
    }

    var debugDescription: String {
        "hCenter:\(hCenter) vCenter:\(vCenter) hMaxAboveCenter:\(hMaxAboveCenter) " +
            "vMaxAboveCenter:\(vMaxAboveCenter) hMaxBelowCenter:\(hMaxBelowCenter) " +
            "vMaxBelowCenter:\(vMaxBelowCenter)"
    }

    private init(
        hCenter: UInt16,
        vCenter: UInt16,
        hMaxAboveCenter: UInt16,
        vMaxAboveCenter: UInt16,
        hMaxBelowCenter: UInt16,
        vMaxBelowCenter: UInt16
    ) {
        self.hCenter = hCenter
        self.vCenter = vCenter
        self.hMaxAboveCenter = hMaxAboveCenter
        self.vMaxAboveCenter = vMaxAboveCenter
        self.hMaxBelowCenter = hMaxBelowCenter
        self.vMaxBelowCenter = vMaxBelowCenter
    }

    static func fromLeftStick(_ bytesLength9: Bytes) -> StickCalibration {
        let hMaxAboveCenter = (UInt16(bytesLength9[1]) << 8) & 0xF00 | UInt16(bytesLength9[0])
        let vMaxAboveCenter = (UInt16(bytesLength9[2]) << 4) | (UInt16(bytesLength9[1]) >> 4)
        let hCenter = (UInt16(bytesLength9[4]) << 8) & 0xF00 | UInt16(bytesLength9[3])
        let vCenter = (UInt16(bytesLength9[5]) << 4) | (UInt16(bytesLength9[4]) >> 4)
        let hMaxBelowCenter = (UInt16(bytesLength9[7]) << 8) & 0xF00 | UInt16(bytesLength9[6])
        let vMaxBelowCenter = (UInt16(bytesLength9[8]) << 4) | (UInt16(bytesLength9[7]) >> 4)
        return StickCalibration(
            hCenter: hCenter,
            vCenter: vCenter,
            hMaxAboveCenter: hMaxAboveCenter,
            vMaxAboveCenter: vMaxAboveCenter,
            hMaxBelowCenter: hMaxBelowCenter,
            vMaxBelowCenter: vMaxBelowCenter
        )
    }

    static func fromRightStick(_ bytesLength9: Bytes) -> StickCalibration {
        let hCenter = (UInt16(bytesLength9[1]) << 8) & 0xF00 | UInt16(bytesLength9[0])
        let vCenter = (UInt16(bytesLength9[2]) << 4) | (UInt16(bytesLength9[1]) >> 4)
        let hMaxBelowCenter = (UInt16(bytesLength9[4]) << 8) & 0xF00 | UInt16(bytesLength9[3])
        let vMaxBelowCenter = (UInt16(bytesLength9[5]) << 4) | (UInt16(bytesLength9[4]) >> 4)
        let hMaxAboveCenter = (UInt16(bytesLength9[7]) << 8) & 0xF00 | UInt16(bytesLength9[6])
        let vMaxAboveCenter = (UInt16(bytesLength9[8]) << 4) | (UInt16(bytesLength9[7]) >> 4)
        return StickCalibration(
            hCenter: hCenter,
            vCenter: vCenter,
            hMaxAboveCenter: hMaxAboveCenter,
            vMaxAboveCenter: vMaxAboveCenter,
            hMaxBelowCenter: hMaxBelowCenter,
            vMaxBelowCenter: vMaxBelowCenter
        )
    }
}

class StickState {
    private var hStick: UInt16 = 0
    private var vStick: UInt16 = 0
    private let calibration: StickCalibration
    init(calibration: StickCalibration) {
        self.calibration = calibration
        setCenter()
    }

    private func validate(_ val: UInt16) throws {
        if !(val >= 0 && val < 0x1000) {
            throw ApplicationError.general("Stick values must be in [0,\(0x1000))")
        }
    }

    func setH(value: UInt16) {
        try! validate(value)
        hStick = value
    }

    func getH() -> UInt16 {
        hStick
    }

    func setV(value: UInt16) {
        try! validate(value)
        vStick = value
    }

    func getV() -> UInt16 {
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
        vStick = UInt16(force * Double(calibration.vCenter - calibration.vMaxBelowCenter))
    }

    func setVMax(force: Double = 1) {
        vStick = UInt16(force * Double(calibration.vCenter + calibration.vMaxAboveCenter))
    }

    func setHMin(force: Double = 1) {
        hStick = UInt16(force * Double(calibration.hCenter - calibration.hMaxBelowCenter))
    }

    func setHMax(force: Double = 1) {
        hStick = UInt16(force * Double(calibration.hCenter + calibration.hMaxAboveCenter))
    }

    func isCenter(radius: UInt16 = 0) -> Bool {
        calibration.hCenter - radius <= hStick && hStick <= calibration.hCenter + radius
            && calibration.vCenter - radius <= vStick && vStick <= calibration.vCenter + radius
    }

    func setPosition(_ direction: StickDirection, _ force: Double = 1) {
        switch direction {
        case .center:
            setCenter()

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
        let byte1 = Byte(0xFF & hStick)
        let byte2 = Byte((hStick >> 8) | ((0xF & vStick) << 4))
        let byte3 = Byte(vStick >> 4)
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

        let leftStickCalibration = StickCalibration.fromLeftStick(leftStickCalibrationData)

        leftStickState = StickState(calibration: leftStickCalibration)
        let rightStickCalibrationData = spiFlash.getUserRStickCalibration() ?? spiFlash.getFactoryRStickCalibration()

        let rightStickCalibration = StickCalibration.fromRightStick(rightStickCalibrationData)

        rightStickState = StickState(calibration: rightStickCalibration)
    }
}
