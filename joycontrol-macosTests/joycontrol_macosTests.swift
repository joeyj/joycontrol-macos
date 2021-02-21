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

    func testFlashMemoryInitsWithoutArgs() throws {
        XCTAssertNotNil { try! FlashMemory() }
    }
    
    func testFlashMemoryInitsWithoutArgsUsesFactoryDefaults() throws {
        let target = try! FlashMemory()
        XCTAssertEqual(kFactoryLStickCalibration, target.getFactoryLStickCalibration())
        XCTAssertEqual(kFactoryRStickCalibration, target.getFactoryRStickCalibration())
    }
}
