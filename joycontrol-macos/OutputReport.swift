//
//  OutputReport.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/9/21.
//

import Foundation
public class OutputReport : CustomDebugStringConvertible
{
    private var data: Bytes
    public init(_ data: Bytes? = nil) throws
    {
        var Data = data ?? Array(repeating: 0x00, count: 50)
        if (data == nil)
        {
            Data[0] = 0xA2
        }
        
        if (Data[0] != 0xA2)
        {
            throw ArgumentError.invalid("Output reports must start with a 0xA2 byte!")
        }
        self.data = Data
    }
    public func getOutputReportId() -> OutputReportID
    {
        return OutputReportID(rawValue: self.data[1])!
    }
    public func setOutputReportId(_ id: OutputReportID)
    {
        self.data[1] = id.rawValue
    }
    public func getTimer() -> OutputReportID
    {
        return OutputReportID(rawValue: self.data[2])!
    }
    /// - Parameter timer: 0x0-0xF
    public func setTimer(_ timer: Byte)
    {
        self.data[2] = (timer % 0x10)
    }
    public func getRumbleData() -> Bytes
    {
        return Array(self.data[3...10])
    }
    public func getSubCommand() -> SubCommand
    {
        if (self.data.count < 12)
        {
            return SubCommand.none
        }
        return SubCommand(rawValue: self.data[11])!
        
    }
    public func setSubCommand(_ id: SubCommand)
    {
        self.data[11] = id.rawValue
    }
    public func getSubCommandData() -> Bytes?
    {
        if (self.data.count < 13)
        {
            return nil
        }
        return Array(self.data[12...])
    }
    public func setSubCommandData(_ data: Bytes)
    {
        var i = 0
        for b in data
        {
            self.data[12 + i] = b
            i+=1
        }
    }
    /// Creates output report data with spi flash read sub command.
    /// - Parameters:
    ///   - offset: start byte of the spi flash to read in [0x00, 0x80000)
    ///   - size: size of data to be read in [0x00, 0x1D]
    public func sub0x10SpiFlashRead(offset: Int, size: Byte) throws
    {
        var Offset = offset
        if (size > 0x1D)
        {
            throw ArgumentError.invalid("Size read can not exceed \(0x1D)")
        }
        if (Offset + Int(size) > 0x80000)
        {
            throw ArgumentError.invalid("Given address range exceeds max address \(0x80000 - 1)")
        }
        self.setOutputReportId(OutputReportID.subCommand)
        self.setSubCommand(SubCommand.spiFlashRead)
        // write offset to data
        for i in (12...15)
        {
            self.data[i] = Byte((Offset % 0x100))
            Offset = Offset / 0x100
        }
        self.data[16] = size
    }
    public func bytes() -> Bytes
    {
        return self.data
    }
    public var debugDescription: String
    {
        let (info, bytes) = (self.getOutputReportId() == OutputReportID.subCommand) ? (String(self.getSubCommand().rawValue), self.data.debugDescription) : ("", "")
        
        return "Output \(self.getOutputReportId()) \(info)\n\(bytes)"
    }
}
