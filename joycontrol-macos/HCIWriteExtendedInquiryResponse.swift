//
//  HCIWriteExtendedInquiryResponse.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/8/21.
//

import Bluetooth
import Foundation

public typealias HCIWriteExtendedInquiryResponseBytes = (Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte)

@frozen
public struct HCIWriteExtendedInquiryResponseData {
    public static let length = 241

    public let deviceName: String
    public let modelId: String
    public let fecRequired: Bool

    public init?(deviceName: String, modelId: String, fecRequired: Bool) {
        guard (deviceName.utf8.count + modelId.utf8.count) <= type(of: self).length
        else { return nil }

        self.deviceName = deviceName
        self.modelId = modelId
        self.fecRequired = fecRequired
    }

    public func getData() -> Data {
        let maxLength = type(of: self).length

        var data = Data([fecRequired ? 1 : 0, Byte(deviceName.utf8.count + 1), 0x09])

        data.append(contentsOf: deviceName.utf8)

        data.append(contentsOf: [Byte(modelId.utf8.count + 4), 0xFF, 0x4C, 0x00, 0x01])

        data.append(contentsOf: modelId.utf8)

        assert(data.count <= maxLength)

        if data.count < maxLength {
            data.append(contentsOf: [Byte](repeating: 0x00, count: maxLength - data.count))
        }

        return data
    }

    public func getTuple() -> HCIWriteExtendedInquiryResponseBytes {
        let data = Array(getData())
        let tuple = UnsafeMutablePointer<HCIWriteExtendedInquiryResponseBytes>.allocate(capacity: MemoryLayout<HCIWriteExtendedInquiryResponseBytes>.size)
        memcpy(tuple, data, data.count)
        return tuple.pointee
    }
}
