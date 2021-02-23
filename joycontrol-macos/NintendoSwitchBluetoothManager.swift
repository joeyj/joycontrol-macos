//
//  BluetoothManager.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/15/21.
//
import BluetoothDarwin
import BluetoothHCI
import CBluetoothDarwin
import Foundation
import IOBluetooth
import os.log
import SwiftUI

class NintendoSwitchBluetoothManager: NSObject, IOBluetoothL2CAPChannelDelegate, ObservableObject, IOBluetoothHostControllerDelegate, ControllerProtocolDelgate {
    private static let controlPsm = BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDControl)
    private static let interruptPsm = BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDInterrupt)
    static let shared = NintendoSwitchBluetoothManager()
    private static let hostController = IOBluetoothHostController()
    private var controlChannel: IOBluetoothL2CAPChannel?
    private var interruptChannel: IOBluetoothL2CAPChannel?
    private var controlChannelOutgoing: IOBluetoothL2CAPChannel?
    private var interruptChannelOutgoing: IOBluetoothL2CAPChannel?
    private var serviceRecord: IOBluetoothSDPServiceRecord?
    private var hostAddress: BluetoothAddress?
    private let logger = Logger()
    private var controllerProtocol: ControllerProtocol?
    private var nintendoSwitch: IOBluetoothDevice?
    @objc @Published var deviceAddress: String = ""
    private var connected: Bool = false

    override private init() {
        super.init()
        NintendoSwitchBluetoothManager.hostController.delegate = self
    }

    func setScanEnabled(enabled: Bool) {
        logger.debug(#function)
        let host = HostController.default!
        try! host.writeScanEnable(
            scanEnable: enabled ? HCIWriteScanEnable.ScanEnable.inquiryAndPageScan
                : HCIWriteScanEnable.ScanEnable.noScans
        )
    }

    func getIsScanEnabled() -> Bool {
        var readScanEnable: Int8 = 0
        NintendoSwitchBluetoothManager.hostController.bluetoothHCIReadScanEnable(&readScanEnable)
        return readScanEnable > 0
    }

    func controllerProtocolConnectionLost() {
        interruptChannel = nil
        controlChannel = nil
        controllerProtocol = nil
        nintendoSwitch = nil
        interruptChannelOutgoing = nil
        controlChannelOutgoing = nil
    }

    private func configureHostControllerForNintendoSwitch() {
        let host = HostController.default!
        let deviceName = "Pro Controller"
        try! host.writeLocalName(deviceName)

        let controller = NintendoSwitchBluetoothManager.hostController
        let classNum = 0x000508
        controller.delegate = self
        controller.bluetoothHCIWriteClass(ofDevice: BluetoothClassOfDevice(classNum))
        controller.bluetoothHCIWriteAuthenticationEnable(Byte(kAuthenticationDisabled.rawValue))
        controller.bluetoothHCIWriteSimplePairingMode(Byte(kBluetoothHCISimplePairingModeEnabled.rawValue))
        controller.bluetoothHCIWriteSimplePairingDebugMode(Byte(kBluetoothHCISimplePairingDebugModeEnabled.rawValue))

        let data = HCIWriteExtendedInquiryResponseData(deviceName: deviceName, modelId: "", fecRequired: false)!.getTuple()

        var response = BluetoothHCIExtendedInquiryResponse(data: data)
        controller.bluetoothHCIWriteExtendedInquiryResponse(Byte(kBluetoothHCIFECNotRequired.rawValue), in: &response)
        hostAddress = try! host.readDeviceAddress()
        serviceRecord = addSdpRecordFromPlistOrFail(Bundle.main.path(forResource: "NintendoSwitchControllerSDP", ofType: "plist")!)
        logger.debug("\(self.serviceRecord!.debugDescription)")
        registerHIDChannelsOpen(target: self, selector: #selector(newL2CAPChannelOpened))
    }

    private func onBluetoothPoweredOn() {
        configureHostControllerForNintendoSwitch()
    }

    private func onBluetoothPoweredOff() {}

    func connectNintendoSwitch(_ address: String) {
        logger.debug(#function)
        guard nintendoSwitch == nil else {
            logger.error("Nintendo Switch is already connected. Skipping.")
            return
        }
        DispatchQueue.main.async { [self] in
            nintendoSwitch = IOBluetoothDevice(addressString: address)!
            nintendoSwitch!.openConnection()
            openL2CAPChannelOrFail(nintendoSwitch!, NintendoSwitchBluetoothManager.controlPsm, &controlChannelOutgoing)
            openL2CAPChannelOrFail(nintendoSwitch!, NintendoSwitchBluetoothManager.interruptPsm, &interruptChannelOutgoing)
        }
    }

    func disconnectNintendoSwitch() {
        logger.debug(#function)
        DispatchQueue.main.async { [self] in
            interruptChannelOutgoing?.close()
            controlChannelOutgoing?.close()
            nintendoSwitch?.closeConnection()
        }
    }

    func controlStickPushed(_ button: ControllerButton, _ direction: StickDirection) {
        switch button {
        case .leftStick:
            controllerProtocol?.controllerState.leftStickState.setPosition(direction)

        case .rightStick:
            controllerProtocol?.controllerState.rightStickState.setPosition(direction)

        default:
            fatalError("Only \(ControllerButton.leftStick) and \(ControllerButton.rightStick) are supported.")
        }
    }

    private func openL2CAPChannelOrFail(_ device: IOBluetoothDevice, _ psm: BluetoothL2CAPPSM, _ channel: AutoreleasingUnsafeMutablePointer<IOBluetoothL2CAPChannel?>!) {
        let result = device.openL2CAPChannelSync(channel, withPSM: psm, delegate: self)
        guard result == kIOReturnSuccess else { // if timeout, show dialog instead of fatalError?
            fatalError("Failed to open l2cap channel PSM: \(psm) result: \(result)")
        }
    }

    @objc
    func newL2CAPChannelOpened(notification _: IOBluetoothUserNotification, channel: IOBluetoothL2CAPChannel) {
        logger.debug(#function)
        channel.setDelegate(self)
    }

    private func getDataFromChannel(data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) -> Bytes {
        let opaquePointer = OpaquePointer(dataPointer)
        let unsafePointer = UnsafeMutablePointer<Byte>(opaquePointer)
        return Array(UnsafeBufferPointer<Byte>(start: unsafePointer, count: dataLength))
    }

    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        if l2capChannel == controllerProtocol?.transport {
            let data = getDataFromChannel(data: dataPointer, length: dataLength)
            controllerProtocol?.reportReceived(data)
        } else {
            fatalError("Received data from non-interrupt channel.")
        }
    }

    func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status error: IOReturn) {
        logger.debug(#function)
        guard error == kIOReturnSuccess else {
            logger.error("Channel open failed: \(error)")
            return
        }

        logger.debug("\(l2capChannel.debugDescription)")
        switch l2capChannel.psm {
        case NintendoSwitchBluetoothManager.controlPsm:
            logger.info("Control PSM Channel Connected")
            controlChannel = l2capChannel

        case NintendoSwitchBluetoothManager.interruptPsm:
            logger.info("Interrupt PSM Channel Connected")
            interruptChannel = l2capChannel
            controllerProtocol = ControllerProtocol(spiFlash: try! FlashMemory(), hostAddress: hostAddress!, delegate: self, transport: l2capChannel)
            nintendoSwitch = l2capChannel.device
            deviceAddress = l2capChannel.device.addressString.split(separator: "-").joined(separator: ":")

        default:
            return
        }
    }

    func l2capChannelClosed(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        logger.debug(#function)
        logger.debug("\(l2capChannel.debugDescription)")
        if l2capChannel == interruptChannel {
            if controllerProtocol == nil {
                controllerProtocolConnectionLost()
            } else {
                controllerProtocol!.connectionLost()
            }
        }
    }

    func l2capChannelWriteComplete(_: IOBluetoothL2CAPChannel!, refcon _: UnsafeMutableRawPointer!, status _: IOReturn) {
        logger.debug(#function)
    }

    func bluetoothHCIEventNotificationMessage(_ controller: IOBluetoothHostController, in _: IOBluetoothHCIEventNotificationMessageRef) {
        let isConnected = controller.powerState == kBluetoothHCIPowerStateON
        if isConnected != connected {
            logger.debug("Detected powerState change: \(self.connected) -> \(isConnected)")
            connected = isConnected
            if connected {
                onBluetoothPoweredOn()
            } else {
                onBluetoothPoweredOff()
            }
        }
    }

    func controllerButtonPushed(buttons: [ControllerButton]) {
        guard controllerProtocol != nil else {
            logger.info("controllerProtocol not initialized")
            return
        }
        logger.debug(#function)
        logger.info("\(String(describing: buttons))")
        buttonPush(controllerProtocol!.controllerState.buttonState, controllerProtocol!, buttons)
    }

    deinit {
        logger.debug("Removing service record")
        serviceRecord?.remove()
    }
}
