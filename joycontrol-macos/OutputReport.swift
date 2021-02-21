//
//  OutputReport.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/9/21.
//

import Foundation
public class OutputReport: CustomDebugStringConvertible {
    private var data: Bytes
    public init(_ data: Bytes? = nil) throws {
        var tempData = data ?? Array(repeating: 0x00, count: 50)
        if data == nil {
            tempData[0] = 0xA2
        }

        if tempData[0] != 0xA2 {
            throw ArgumentError.invalid("Output reports must start with a 0xA2 byte!")
        }
        self.data = tempData
    }

    public func getOutputReportId() -> OutputReportID {
        return OutputReportID(rawValue: data[1])!
    }

    public func setOutputReportId(_ outputReportId: OutputReportID) {
        data[1] = outputReportId.rawValue
    }

    public func getTimer() -> OutputReportID {
        return OutputReportID(rawValue: data[2])!
    }

    /// - Parameter timer: 0x0-0xF
    public func setTimer(_ timer: Byte) {
        data[2] = (timer % 0x10)
    }

    public func getRumbleData() -> Bytes {
        return Array(data[3 ... 10])
    }

    public func getSubCommand() -> SubCommand {
        if data.count < 12 {
            return SubCommand.none
        }
        return SubCommand(rawValue: data[11])!
    }

    public func setSubCommand(_ subCommand: SubCommand) {
        data[11] = subCommand.rawValue
    }

    public func getSubCommandData() -> Bytes? {
        if data.count < 13 {
            return nil
        }
        return Array(data[12...])
    }

    public func setSubCommandData(_ data: Bytes) {
        var index = 0
        for byte in data {
            self.data[12 + index] = byte
            index += 1
        }
    }

    /// Creates output report data with spi flash read sub command.
    /// - Parameters:
    ///   - offset: start byte of the spi flash to read in [0x00, 0x80000)
    ///   - size: size of data to be read in [0x00, 0x1D]
    public func sub0x10SpiFlashRead(offset: Int, size: Byte) throws {
        var tempOffset = offset
        if size > 0x1D {
            throw ArgumentError.invalid("Size read can not exceed \(0x1D)")
        }
        if tempOffset + Int(size) > 0x80000 {
            throw ArgumentError.invalid("Given address range exceeds max address \(0x80000 - 1)")
        }
        setOutputReportId(OutputReportID.subCommand)
        setSubCommand(SubCommand.spiFlashRead)
        // write offset to data
        for index in 12 ... 15 {
            data[index] = Byte(tempOffset % 0x100)
            tempOffset /= 0x100
        }
        data[16] = size
    }

    public func bytes() -> Bytes {
        return data
    }

    public var debugDescription: String {
        let (info, bytes) = (getOutputReportId() == OutputReportID.subCommand) ? (String(getSubCommand().rawValue), data.debugDescription) : ("", "")

        return "Output \(getOutputReportId()) \(info)\n\(bytes)"
    }
}
