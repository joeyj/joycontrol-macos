//
//  HCIWriteExtendedInquiryResponse.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/8/21.
//

import Bluetooth
import Foundation

// swiftlint:disable:next line_length
typealias HCIWriteExtendedInquiryResponseBytes = (Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte, Byte)

struct HCIWriteExtendedInquiryResponseData {
    static let maxLength = 241

    let deviceName: String
    let modelId: String
    let fecRequired: Bool

    init?(deviceName: String, modelId: String, fecRequired: Bool) {
        guard (deviceName.utf8.count + modelId.utf8.count) <= Self.maxLength
        else { return nil }

        self.deviceName = deviceName
        self.modelId = modelId
        self.fecRequired = fecRequired
    }

    func getData() -> Data {
        let data = Data([fecRequired ? 1 : 0, Byte(deviceName.utf8.count + 1), 0x09])
            + deviceName.utf8
            + [Byte(modelId.utf8.count + 4), 0xFF, 0x4C, 0x00, 0x01]
            + modelId.utf8
            + Bytes(repeating: 0x00, count: Self.maxLength - (3 + deviceName.utf8.count + 5 + modelId.utf8.count))

        assert(data.count <= Self.maxLength)

        return data
    }

    func getTuple() -> HCIWriteExtendedInquiryResponseBytes {
        let data = Array(getData())
        let tuple = UnsafeMutablePointer<HCIWriteExtendedInquiryResponseBytes>
            .allocate(capacity: MemoryLayout<HCIWriteExtendedInquiryResponseBytes>.size)
        memcpy(tuple, data, data.count)
        return tuple.pointee
    }
}
