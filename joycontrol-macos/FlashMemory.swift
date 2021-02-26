//
//  FlashMemory.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/30/21.
//

import Foundation

let kBlankByte: Byte = 0xFF
let kFactoryLStickCalibration: Bytes = [0x00, 0x07, 0x70, 0x00, 0x08, 0x80, 0x00, 0x07, 0x70]
let kFactoryRStickCalibration: Bytes = [0x00, 0x08, 0x80, 0x00, 0x07, 0x70, 0x00, 0x07, 0x70]
let kDefaultFlashMemory = Bytes(repeating: kBlankByte, count: 0x603D)
    + kFactoryLStickCalibration
    + kFactoryRStickCalibration
    + Bytes(repeating: kBlankByte, count: 0x80000 - 0x604E - 1)

class FlashMemory {
    let data: Bytes

    private var isUserLStickCalibrationDataAvailable: Bool {
        data[0x8010] == 0xB2 && data[0x8011] == 0xA1
    }

    private var isUserRStickCalibrationDataAvailable: Bool {
        data[0x801B] == 0xB2 && data[0x801C] == 0xA1
    }

    /// - Parameters:
    ///   - spiFlashMemoryData: data from a memory dump (can be created using dumpSpiFlash.py).
    ///   - size: size of the memory dump, should be constant
    init(spiFlashMemoryData: Bytes? = nil, size: Int = 0x80000) throws {
        let tempData = spiFlashMemoryData ?? kDefaultFlashMemory

        if tempData.count != size {
            throw ApplicationError.general("Given data size {len(spiFlashMemoryData)} does not match size {size}.")
        }
        data = tempData
    }

    func getFactoryLStickCalibration() -> Bytes {
        Array(data[0x603D ... 0x6045])
    }

    func getFactoryRStickCalibration() -> Bytes {
        Array(data[0x6046 ... 0x604E])
    }

    func getUserLStickCalibration() -> Bytes? {
        if isUserLStickCalibrationDataAvailable {
            return Array(data[0x8012 ... 0x801A])
        }
        return nil
    }

    func getUserRStickCalibration() -> Bytes? {
        if isUserRStickCalibrationDataAvailable {
            return Array(data[0x801D ... 0x8025])
        }
        return nil
    }

    deinit {}
}
