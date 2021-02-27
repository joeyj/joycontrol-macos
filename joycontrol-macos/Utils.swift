//
//  Common.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/28/21.
//
import Bluetooth
import Foundation
import IOBluetooth

typealias Byte = UInt8
typealias Bytes = [Byte]

enum Controller: Byte {
    case
        proController = 0x03
    var name: String {
        switch self {
        case .proController:
            return "Pro Controller"
        }
    }
}

enum ArgumentError: Error {
    case invalid(_ message: String)
}

enum ApplicationError: Error {
    case general(_ message: String)
}

enum SubCommand: Byte {
    case none = 0,
         requestDeviceInfo = 0x02,
         setInputReportMode = 0x03,
         triggerButtonsElapsedTime = 0x04,
         setHCIState = 0x06,
         setShipmentState = 0x08,
         spiFlashRead = 0x10,
         setNfcIrMcuConfig = 0x21,
         setNfcIrMcuState = 0x22,
         setPlayerLights = 0x30,
         enable6axisSensor = 0x40,
         enableVibration = 0x48
}

enum OutputReportID: Byte {
    case subCommand = 0x01,
         rumbleOnly = 0x10,
         requestIrNfcMcu = 0x11
}

enum InputReportId: Byte {
    case none = 0x00,
         standard = 0x21,
         imu = 0x30,
         setNfcData = 0x31
}

enum ControllerButton: String {
    // swiftlint:disable identifier_name
    case y,
         x,
         b,
         a,
         r,
         zr,
         minus,
         plus,
         rightStick,
         leftStick,
         home,
         capture,
         down,
         up,
         right,
         left,
         l,
         zl,
         sr,
         sl
    // swiftlint:enable identifier_name
}

func addSdpRecordFromPlistOrFail(_ path: String) -> IOBluetoothSDPServiceRecord {
    let serviceDictionary = NSMutableDictionary(contentsOfFile: path)
    let serviceRecord = IOBluetoothSDPServiceRecord.publishedServiceRecord(with: serviceDictionary! as [NSObject: AnyObject])
    if serviceRecord == nil {
        fatalError("Failed to add SDP Service Record.")
    }
    return serviceRecord!
}

func registerL2CAPChannelOpenNotifications(
    psm: BluetoothL2CAPPSM,
    target: AnyObject,
    selector: Selector,
    direction: IOBluetoothUserNotificationChannelDirection = kIOBluetoothUserNotificationChannelDirectionIncoming
) {
    guard IOBluetoothL2CAPChannel
        .register(
            forChannelOpenNotifications: target,
            selector: selector,
            withPSM: psm,
            direction: direction
        ) != nil
    else {
        fatalError("Failed to register for channel \(psm) open notifications.")
    }
}

func registerHIDChannelsOpen(target: AnyObject, selector: Selector) {
    registerL2CAPChannelOpenNotifications(psm: BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDControl), target: target, selector: selector)
    registerL2CAPChannelOpenNotifications(psm: BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDInterrupt), target: target, selector: selector)
}

enum Utils {
    static func getBit(_ value: Byte, _ bit: Byte) -> Bool {
        (value >> bit & 1) != 0
    }

    static func flipBit(_ value: Byte, _ bit: Byte) -> Byte {
        value ^ (1 << bit)
    }
}

extension IOBluetoothDevice {
    func openL2CAPChannelOrFail(_ psm: BluetoothL2CAPPSM, _ channel: AutoreleasingUnsafeMutablePointer<IOBluetoothL2CAPChannel?>!, delegate: AnyObject!) {
        let result = openL2CAPChannelSync(channel, withPSM: psm, delegate: delegate)
        guard result == kIOReturnSuccess else { // if timeout, show dialog instead of fatalError?
            fatalError("Failed to open l2cap channel PSM: \(psm) result: \(result)")
        }
    }
}

extension IOBluetoothHostController {
    func setExtendedInquiryResponse(deviceName: String, modelId: String = "", fecRequired: Bool = false) {
        let data = HCIWriteExtendedInquiryResponseData(deviceName: deviceName, modelId: modelId, fecRequired: fecRequired)!.getTuple()

        var response = BluetoothHCIExtendedInquiryResponse(data: data)
        bluetoothHCIWriteExtendedInquiryResponse(Byte(kBluetoothHCIFECNotRequired.rawValue), in: &response)
    }

    func isScanEnable() -> Bool {
        var readScanEnable: Int8 = 0
        bluetoothHCIReadScanEnable(&readScanEnable)
        return readScanEnable > 0
    }
}

extension UnsafeMutableRawPointer {
    func readAsArray<T>(_ dataLength: Int) -> [T] {
        let opaquePointer = OpaquePointer(self)
        let unsafePointer = UnsafeMutablePointer<T>(opaquePointer)
        return Array(UnsafeBufferPointer<T>(start: unsafePointer, count: dataLength))
    }
}
