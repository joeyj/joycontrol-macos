//
//  FlashMemory.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/30/21.
//

import Foundation

private let kBlankByte: Byte = 0xFF
let kFactoryLStickCalibration: Bytes = [0x00, 0x07, 0x70, 0x00, 0x08, 0x80, 0x00, 0x07, 0x70]
let kFactoryRStickCalibration: Bytes = [0x00, 0x08, 0x80, 0x00, 0x07, 0x70, 0x00, 0x07, 0x70]
private let kDefaultFlashMemory = Bytes(repeating: kBlankByte, count: 0x603D)
    + kFactoryLStickCalibration
    + kFactoryRStickCalibration
    + Bytes(repeating: kBlankByte, count: 0x80000 - 0x604E - 1)

struct FlashMemory {
    static var factoryDefault: FlashMemory {
        FlashMemory(data: kDefaultFlashMemory)
    }

    let data: Bytes

    private var isUserLStickCalibrationDataAvailable: Bool {
        data[0x8010] == 0xB2 && data[0x8011] == 0xA1
    }

    private var isUserRStickCalibrationDataAvailable: Bool {
        data[0x801B] == 0xB2 && data[0x801C] == 0xA1
    }

    private var factoryLStickCalibration: Bytes {
        Array(data[0x603D ... 0x6045])
    }

    private var factoryRStickCalibration: Bytes {
        Array(data[0x6046 ... 0x604E])
    }

    var leftStickCalibration: Bytes {
        if isUserLStickCalibrationDataAvailable {
            return Array(data[0x8012 ... 0x801A])
        }
        return factoryLStickCalibration
    }

    var rightStickCalibration: Bytes {
        if isUserRStickCalibrationDataAvailable {
            return Array(data[0x801D ... 0x8025])
        }
        return factoryRStickCalibration
    }
}
