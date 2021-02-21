//
//  Common.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/28/21.
//
import Bluetooth
import Foundation
import IOBluetooth

typealias Byte = UInt8
typealias Bytes = [Byte]

enum Controller: Byte {
    case joyconL = 0x01,
         joyconR = 0x02,
         proController = 0x03
    var name: String {
        switch self {
        case Controller.joyconL:
            return "Joy-Con (L)"
        case Controller.joyconR:
            return "Joy-Con (R)"
        case Controller.proController:
            return "Pro Controller"
        }
    }
}

enum ArgumentError: Error {
    case invalid(_ message: String)
}

enum ApplicationError: Error {
    case general(_ message: String)
}

enum SubCommand: Byte {
    case none = 0,
         requestDeviceInfo = 0x02,
         setInputReportMode = 0x03,
         triggerButtonsElapsedTime = 0x04,
         setHCIState = 0x06,
         setShipmentState = 0x08,
         spiFlashRead = 0x10,
         setNfcIrMcuConfig = 0x21,
         setNfcIrMcuState = 0x22,
         setPlayerLights = 0x30,
         enable6axisSensor = 0x40,
         enableVibration = 0x48
}

enum OutputReportID: Byte {
    case subCommand = 0x01,
         rumbleOnly = 0x10,
         requestIrNfcMcu = 0x11
}

enum InputReportId: Byte {
    case standard = 0x21,
         imu = 0x30,
         setNfcData = 0x31
}

enum ControllerButton: String {
    // swiftlint:disable identifier_name
    case y,
         x,
         b,
         a,
         r,
         zr,
         minus,
         plus,
         rightStick,
         leftStick,
         home,
         capture,
         down,
         up,
         right,
         left,
         l,
         zl,
         sr,
         sl
    // swiftlint:enable identifier_name
}

enum Utils {
    static func getBit(_ value: Byte, _ bit: Byte) -> Bool {
        (value >> bit & 1) != 0
    }

    static func flipBit(_ value: Byte, _ bit: Byte) -> Byte {
        value ^ (1 << bit)
    }
}
