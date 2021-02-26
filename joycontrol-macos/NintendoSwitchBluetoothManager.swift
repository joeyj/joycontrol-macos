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
    private static let deviceName = "Pro Controller"
    private static let controlPsm = BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDControl)
    private static let interruptPsm = BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDInterrupt)
    static let shared = NintendoSwitchBluetoothManager()
    private static let hostController = IOBluetoothHostController()
    private static let hostControllerDefault = HostController.default!
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
    @objc @Published var readyForInput: Bool = false

    override private init() {
        super.init()
        Self.hostController.delegate = self
    }

    func setScanEnabled(enabled: Bool) {
        logger.debug(#function)
        try! Self.hostControllerDefault.writeScanEnable(
            scanEnable: enabled ? .inquiryAndPageScan
                : .noScans
        )
    }

    func getIsScanEnabled() -> Bool {
        Self.hostController.isScanEnable()
    }

    func controllerProtocolConnectionLost() {
        interruptChannel = nil
        controlChannel = nil
        controllerProtocol = nil
        nintendoSwitch = nil
        interruptChannelOutgoing = nil
        controlChannelOutgoing = nil
        readyForInput = false
    }

    private func configureHostControllerForNintendoSwitch() {
        try! Self.hostControllerDefault.writeLocalName(Self.deviceName)

        let controller = Self.hostController
        let classNum = 0x000508
        controller.delegate = self
        controller.bluetoothHCIWriteClass(ofDevice: BluetoothClassOfDevice(classNum))
        controller.bluetoothHCIWriteAuthenticationEnable(Byte(kAuthenticationDisabled.rawValue))
        controller.bluetoothHCIWriteSimplePairingMode(Byte(kBluetoothHCISimplePairingModeEnabled.rawValue))
        controller.bluetoothHCIWriteSimplePairingDebugMode(Byte(kBluetoothHCISimplePairingDebugModeEnabled.rawValue))

        controller.setExtendedInquiryResponse(deviceName: Self.deviceName)
        hostAddress = try! Self.hostControllerDefault.readDeviceAddress()
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
            nintendoSwitch!.openL2CAPChannelOrFail(NintendoSwitchBluetoothManager.controlPsm, &controlChannelOutgoing)
            nintendoSwitch!.openL2CAPChannelOrFail(NintendoSwitchBluetoothManager.interruptPsm, &interruptChannelOutgoing)
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

    @objc
    func newL2CAPChannelOpened(notification _: IOBluetoothUserNotification, channel: IOBluetoothL2CAPChannel) {
        logger.debug(#function)
        channel.setDelegate(self)
    }

    func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        if l2capChannel.psm == Self.interruptPsm {
            let data: Bytes = dataPointer.readAsArray(dataLength)

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
            DispatchQueue.global(qos: .background).async {
                self.controllerProtocol!.readyToAcceptInput.wait()
                DispatchQueue.main.async {
                    self.readyForInput = true
                }
            }

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
            logger.error("controllerProtocol not initialized")
            return
        }
        logger.debug(#function)
        logger.debug("\(String(describing: buttons))")
        buttonPush(controllerProtocol!.controllerState.buttonState, controllerProtocol!, buttons)
    }

    deinit {
        logger.debug("Removing service record")
        serviceRecord?.remove()
    }
}
