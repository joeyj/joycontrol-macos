//
//  InputReport.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/9/21.
//

import Bluetooth
import Foundation
let kDefaultInputReportData = [0xA1] + Bytes(repeating: 0x00, count: 361)
/// Class to create Input Reports.
///
/// Reference:
/// https://github.com/dekuNukem/NintendoSwitchReverseEngineering/blob/master/bluetoothHidNotes.md
class InputReport: CustomDebugStringConvertible {
    var data: Bytes

    var debugDescription: String {
        let reportId = "Input \(getInputReportId())"
        let subCommand: SubCommand
        let bytesDescription: String
        if getInputReportId() == InputReportId.standard {
            subCommand = getReplyToSubCommandId()
            bytesDescription = bytes().debugDescription
        } else {
            subCommand = SubCommand.none
            bytesDescription = ""
        }
        return "\(reportId) \(subCommand)\n\(bytesDescription)"
    }

    init(_ data: Bytes? = nil) throws {
        let tempData = data ?? kDefaultInputReportData
        if tempData[0] != 0xA1 {
            throw ArgumentError.invalid("Input reports must start with 0xA1")
        }
        self.data = tempData
    }

    /// Clear sub command reply data of 0x21 input reports
    func clearSubCommand() {
        for index in 14 ... 50 {
            data[index] = 0x00
        }
    }

    func getStickData() -> Bytes {
        // TODO: Not every input report has stick data
        return Array(data[7 ... 12])
    }

    func getSubCommandReplyData() throws -> Bytes {
        if data.count < 50 {
            throw ApplicationError.general("Not enough data")
        }
        return Array(data[16 ... 50])
    }

    func setStandardInputReport() {
        setInputReportId(InputReportId.standard)
    }

    /// - Parameter id: e.g. 0x21 Standard input reports used for sub command replies
    ///     0x30 Input reports with IMU data instead of sub command replies
    func setInputReportId(_ inputReportId: InputReportId) {
        data[1] = inputReportId.rawValue
    }

    func getInputReportId() -> InputReportId {
        InputReportId(rawValue: data[1])!
    }

    /// Input report timer[0x00 - 0xFF], usually set by the transport
    func setTimer(_ timer: Byte) {
        data[2] = timer
    }

    func setMisc() {
        // battery level + connection info
        data[3] = 0x8E
    }

    func setButtonStatus(_ buttonStatus: Bytes) {
        data[4] = buttonStatus[0]
        data[5] = buttonStatus[1]
        data[6] = buttonStatus[2]
    }

    func setStickStatus(_ leftStick: Bytes, _ rightStick: Bytes) {
        try? setLeftAnalogStick(leftStick)
        try? setRightAnalogStick(rightStick)
    }

    /// - Parameter leftStickBytes: 3 bytes
    func setLeftAnalogStick(_ leftStickBytes: Bytes) throws {
        if leftStickBytes.count != 3 {
            throw ArgumentError.invalid("Left stick status data must be exactly 3 bytes!")
        }
        data.replaceSubrange(8 ... 10, with: leftStickBytes)
    }

    /// - Parameter rightStickBytes: 3 bytes
    func setRightAnalogStick(_ rightStickBytes: Bytes) throws {
        if rightStickBytes.count != 3 {
            throw ArgumentError.invalid("Right stick status data must be exactly 3 bytes!")
        }
        data.replaceSubrange(11 ... 13, with: rightStickBytes)
    }

    func setVibratorInput() {
        // TODO:
        data[13] = 0x80
    }

    /// ACK byte for subcmd reply
    func setAck(_ ack: Byte) {
        // TODO:
        data[14] = ack
    }

    func getAck() -> Byte {
        data[14]
    }

    /// Set accelerator and gyro of 0x30 input reports
    func set6axisData() {
        // TODO:
        // HACK: Set all 0 for now
        for index in 14 ... 49 {
            data[index] = 0x00
        }
    }

    func setIrNfcData(data: Bytes) throws {
        if 50 + data.count > self.data.count {
            throw ArgumentError.invalid("Too much data.")
        }
        for index in 0 ... data.count - 1 {
            self.data[50 + index] = data[index]
        }
    }

    func replyToSubCommandId(_ subCommand: SubCommand) {
        data[15] = subCommand.rawValue
    }

    func getReplyToSubCommandId() -> SubCommand {
        if data.count < 16 {
            return SubCommand.none
        }
        return SubCommand(rawValue: data[15])!
    }

    /// Sub command 0x02 request device info response.
    /// - Parameters:
    ///   - mac: Controller MAC address in Big Endian(6 Bytes)
    ///   - fmVersion: TODO
    func sub0x02DeviceInfo(mac: BluetoothAddress.ByteValue, controller: Controller, fmVersion: (Byte, Byte)? = nil) {
        let fmVersion = fmVersion == nil ? (0x04, 0x00) : fmVersion!
        replyToSubCommandId(SubCommand.requestDeviceInfo)
        // sub command reply data
        let offset = 16
        data[offset] = fmVersion.0
        data[offset + 1] = fmVersion.1
        data[offset + 2] = controller.rawValue
        data[offset + 3] = 0x02
        data[offset + 4] = mac.0
        data[offset + 5] = mac.1
        data[offset + 6] = mac.2
        data[offset + 7] = mac.3
        data[offset + 8] = mac.4
        data[offset + 9] = mac.5
        data[offset + 10] = 0x01
        data[offset + 11] = 0x00 // 0x00: use default, 0x01: use SPI
    }

    func sub0x10SpiFlashRead(_ offset: Int, _ data: Bytes) throws {
        var tempOffset = offset
        let size = Byte(data.count)
        if size > 0x1D {
            throw ArgumentError.invalid("Size can not exceed \(0x1D)")
        }
        replyToSubCommandId(SubCommand.spiFlashRead)
        // write offset to data
        for index in 16 ... 19 {
            self.data[index] = Byte(tempOffset % 0x100)
            tempOffset /= 0x100
        }
        self.data[20] = size
        for index in 0 ... data.count - 1 {
            self.data[21 + index] = data[index]
        }
    }

    /// Set sub command data for 0x04 reply.Arguments are in ms and must be divisible by 10.
    func sub0x04TriggerButtonsElapsedTime(LMs: Int = 0, RMs: Int = 0, ZLMs: Int = 0, ZRMs: Int = 0, SLMs: Int = 0, SRMs: Int = 0, HOMEMs: Int = 0) throws {
        if ![LMs, RMs, ZLMs, ZRMs, SLMs, SRMs, HOMEMs].allSatisfy({ value in value < 10 * 0xFFFF }) {
            throw ArgumentError.invalid("Values can not exceed \(10 * 0xFFFF) ms.")
        }
        set(0, LMs)
        set(2, RMs)
        set(4, ZLMs)
        set(6, ZRMs)
        set(8, SLMs)
        set(10, SRMs)
        set(12, HOMEMs)
    }

    func set(_ offset: Byte, _ valueInMs: Int) {
        // reply data offset
        let subCommandOffset = 16
        let value = (valueInMs / 10)
        data[subCommandOffset + Int(offset)] = Byte(0xFF & value)
        data[subCommandOffset + Int(offset) + 1] = Byte((0xFF00 & value) >> 8)
    }

    func bytes() -> Bytes {
        let inputReportId = getInputReportId()
        if inputReportId == InputReportId.imu {
            return Array(data[0 ... 13])
        }
        if inputReportId == InputReportId.setNfcData {
            return Array(data[0 ... 362])
        }

        return Array(data[0 ... 50])
    }

    deinit {}
}
