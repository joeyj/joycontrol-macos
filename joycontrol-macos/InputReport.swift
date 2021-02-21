//
//  InputReport.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/9/21.
//

import Bluetooth
import Foundation
/// Class to create Input Reports.
///
/// Reference:
/// https://github.com/dekuNukem/NintendoSwitchReverseEngineering/blob/master/bluetoothHidNotes.md
public class InputReport: CustomDebugStringConvertible {
    public var data: Bytes
    public init(_ data: Bytes?) throws {
        if data == nil {
            self.data = Bytes(repeating: 0x00, count: 364)
            self.data[0] = 0xA1
        } else {
            if data![0] != 0xA1 {
                throw ArgumentError.invalid("Input reports must start with 0xA1")
            }
            self.data = data!
        }
    }

    /// Clear sub command reply data of 0x21 input reports
    public func clearSubCommand() {
        for i in 14 ... 50 {
            data[i] = 0x00
        }
    }

    public func getStickData() -> Bytes {
        // TODO: Not every input report has stick data
        return Array(data[7 ... 12])
    }

    public func getSubCommandReplyData() throws -> Bytes {
        if data.count < 50 {
            throw ApplicationError.general("Not enough data")
        }
        return Array(data[16 ... 50])
    }

    public func setStandardInputReport() {
        setInputReportId(InputReportId.standard)
    }

    /// - Parameter id: e.g. 0x21 Standard input reports used for sub command replies
    ///     0x30 Input reports with IMU data instead of sub command replies
    public func setInputReportId(_ id: InputReportId) {
        data[1] = id.rawValue
    }

    public func getInputReportId() -> InputReportId {
        return InputReportId(rawValue: data[1])!
    }

    /// Input report timer[0x00 - 0xFF], usually set by the transport
    public func setTimer(_ timer: Byte) {
        data[2] = timer
    }

    public func setMisc() {
        // battery level + connection info
        data[3] = 0x8E
    }

    public func setButtonStatus(_ buttonStatus: Bytes) {
        data[4] = buttonStatus[0]
        data[5] = buttonStatus[1]
        data[6] = buttonStatus[2]
    }

    public func setStickStatus(_ leftStick: Bytes, _ rightStick: Bytes) {
        try? setLeftAnalogStick(leftStick)
        try? setRightAnalogStick(rightStick)
    }

    /// - Parameter leftStickBytes: 3 bytes
    public func setLeftAnalogStick(_ leftStickBytes: Bytes) throws {
        if leftStickBytes.count != 3 {
            throw ArgumentError.invalid("Left stick status data must be exactly 3 bytes!")
        }
        data.replaceSubrange(8 ... 10, with: leftStickBytes)
    }

    /// - Parameter rightStickBytes: 3 bytes
    public func setRightAnalogStick(_ rightStickBytes: Bytes) throws {
        if rightStickBytes.count != 3 {
            throw ArgumentError.invalid("Right stick status data must be exactly 3 bytes!")
        }
        data.replaceSubrange(11 ... 13, with: rightStickBytes)
    }

    public func setVibratorInput() {
        // TODO:
        data[13] = 0x80
    }

    /// ACK byte for subcmd reply
    public func setAck(_ ack: Byte) {
        // TODO:
        data[14] = ack
    }

    public func getAck() -> Byte {
        return data[14]
    }

    /// Set accelerator and gyro of 0x30 input reports
    public func set6axisData() {
        // TODO:
        // HACK: Set all 0 for now
        for i in 14 ... 49 {
            data[i] = 0x00
        }
    }

    public func setIrNfcData(data: Bytes) throws {
        if 50 + data.count > self.data.count {
            throw ArgumentError.invalid("Too much data.")
        }
        for i in 0 ... data.count - 1 {
            self.data[50 + i] = data[i]
        }
    }

    public func replyToSubCommandId(_ id: SubCommand) {
        data[15] = id.rawValue
    }

    public func getReplyToSubCommandId() -> SubCommand {
        if data.count < 16 {
            return SubCommand.none
        }
        return SubCommand(rawValue: data[15])!
    }

    /// Sub command 0x02 request device info response.
    /// - Parameters:
    ///   - mac: Controller MAC address in Big Endian(6 Bytes)
    ///   - fmVersion: TODO
    public func sub0x02DeviceInfo(mac: BluetoothAddress.ByteValue, fmVersion: Bytes? = nil, controller: Controller) throws
    {
        let fmVersion = fmVersion == nil ? [0x04, 0x00] : fmVersion!
        if fmVersion.count != 2 {
            throw ArgumentError.invalid("Firmware version must consist of 2 bytes!")
        }
        replyToSubCommandId(SubCommand.requestDeviceInfo)
        // sub command reply data
        let offset = 16
        data[offset] = fmVersion[0]
        data[offset + 1] = fmVersion[1]
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

    public func sub0x10SpiFlashRead(_ offset: Int, _ size: Byte, _ data: Bytes) throws {
        var Offset = offset
        if data.count != size {
            throw ArgumentError.invalid("Length of data \(data.count) does not match size \(size)")
        }
        if size > 0x1D {
            throw ArgumentError.invalid("Size can not exceed \(0x1D)")
        }
        replyToSubCommandId(SubCommand.spiFlashRead)
        // write offset to data
        for i in 16 ... 19 {
            self.data[i] = Byte(Offset % 0x100)
            Offset = Offset / 0x100
        }
        self.data[20] = size
        for i in 0 ... data.count - 1 {
            self.data[21 + i] = data[i]
        }
    }

    /// Set sub command data for 0x04 reply.Arguments are in ms and must be divisible by 10.
    public func sub0x04TriggerButtonsElapsedTime(LMs: Int = 0, RMs: Int = 0, ZLMs: Int = 0, ZRMs: Int = 0, SLMs: Int = 0, SRMs: Int = 0, HOMEMs: Int = 0) throws
    {
        if ![LMs, RMs, ZLMs, ZRMs, SLMs, SRMs, HOMEMs].allSatisfy({ x in x < 10 * 0xFFFF }) {
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

    public func set(_ offset: Byte, _ ms: Int) {
        // reply data offset
        let subCommandOffset = 16
        let value = (ms / 10)
        data[subCommandOffset + Int(offset)] = Byte(0xFF & value)
        data[subCommandOffset + Int(offset) + 1] = Byte((0xFF00 & value) >> 8)
    }

    public func bytes() -> Bytes {
        let Id = getInputReportId()
        if Id == InputReportId.imu {
            return Array(data[0 ... 13])
        }
        if Id == InputReportId.setNfcData {
            return Array(data[0 ... 362])
        }

        return Array(data[0 ... 50])
    }

    public var debugDescription: String {
        let Id = "Input \(getInputReportId())"
        var Info = SubCommand.none
        var Bytes = ""
        if getInputReportId() == InputReportId.standard {
            Info = getReplyToSubCommandId()
            Bytes = bytes().debugDescription
        }
        return "\(Id) \(Info)\n\(Bytes)"
    }
}
