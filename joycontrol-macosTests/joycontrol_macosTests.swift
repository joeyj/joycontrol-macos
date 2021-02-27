//
//  joycontrol_macosTests.swift
//  joycontrol-macosTests
//
//  Created by Joey Jacobs on 2/9/21.
//

@testable import joycontrol_macos
import XCTest

class joycontrol_macosTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFlashMemoryInitsWithoutArgsUsesFactoryDefaults() throws {
        let target = FlashMemory.factoryDefault
        XCTAssertEqual(kFactoryLStickCalibration, target.leftStickCalibration)
        XCTAssertEqual(kFactoryRStickCalibration, target.rightStickCalibration)
    }

    func testLeftStickCalibrationFromFactoryBytes() throws {
        let expected: [UInt16] = [2048, 2048, 1792, 1792, 1792, 1792]
        let result = StickCalibration.fromLeftStick(kFactoryLStickCalibration)
        XCTAssertEqual(expected, result.bytes)
    }

    func testRightStickCalibrationFromFactoryBytes() throws {
        let expected: [UInt16] = [2048, 2048, 1792, 1792, 1792, 1792]
        let result = StickCalibration.fromRightStick(kFactoryRStickCalibration)
        XCTAssertEqual(expected, result.bytes)
    }
}
