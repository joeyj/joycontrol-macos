//
//  BluetoothManager.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/15/21.
//
import SwiftUI
import BluetoothDarwin
import BluetoothHCI
import CBluetoothDarwin
import Foundation
import IOBluetooth
import os.log

public class BluetoothManager: NSObject, IOBluetoothL2CAPChannelDelegate, ObservableObject, IOBluetoothHostControllerDelegate {
    private static var controlPsm: BluetoothL2CAPPSM = BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDControl)
    private static var interruptPsm: BluetoothL2CAPPSM = BluetoothL2CAPPSM(kBluetoothL2CAPPSMHIDInterrupt)
    private var controlChannel: IOBluetoothL2CAPChannel?
    private var interruptChannel: IOBluetoothL2CAPChannel?
    private var serviceRecord: IOBluetoothSDPServiceRecord?
    private var hostAddress: BluetoothAddress?
    private var logger: Logger = Logger()
    public var controllerProtocol: ControllerProtocol?
    @objc @Published public var deviceAddress: String = ""
    public static var shared: BluetoothManager = BluetoothManager()
    private static let hostController = IOBluetoothHostController()
    private var connected: Bool = false
    
    private override init() {
        super.init()
        BluetoothManager.hostController.delegate = self
    }
    
    func stopScan() {
        logger.info(#function)
        let host = HostController.default!
        try! host.writeScanEnable(scanEnable: HCIWriteScanEnable.ScanEnable.noScans)
    }
    
    func startScan() {
        logger.info(#function)
        let host = HostController.default!
        try! host.writeScanEnable(scanEnable: HCIWriteScanEnable.ScanEnable.inquiryAndPageScan)
    }
    
    public func getIsScanEnabled() -> Bool {
        var readScanEnable: Int8 = 0
        BluetoothManager.hostController.bluetoothHCIReadScanEnable(&readScanEnable)
        return readScanEnable > 0
    }
    
    func ensureBluetoothControllerConfigured() {
        let host = HostController.default!
        let deviceName = "Pro Controller"
        try! host.writeLocalName(deviceName)
        
        let controller = BluetoothManager.hostController
        let classNum = 0x000508
        controller.delegate = self
        controller.bluetoothHCIWriteClass(ofDevice: BluetoothClassOfDevice(classNum))
        controller.bluetoothHCIWriteAuthenticationEnable(Byte(kAuthenticationDisabled.rawValue))
        controller.bluetoothHCIWriteSimplePairingMode(Byte(kBluetoothHCISimplePairingModeEnabled.rawValue))
        controller.bluetoothHCIWriteSimplePairingDebugMode(Byte(kBluetoothHCISimplePairingDebugModeEnabled.rawValue))
        
        let data = HCIWriteExtendedInquiryResponseData(deviceName:deviceName, modelId: "", fecRequired: false)!.getTuple()
        
        var response = BluetoothHCIExtendedInquiryResponse(data: data)
        controller.bluetoothHCIWriteExtendedInquiryResponse(Byte(kBluetoothHCIFECNotRequired.rawValue), in: &response)
        hostAddress = try! host.readDeviceAddress()
    }
    
    private func addSdpRecord() {
        let serviceDictionary = NSMutableDictionary(contentsOfFile: Bundle.main.path(forResource: "NintendoSwitchControllerSDP", ofType: "plist")!)
        self.serviceRecord = IOBluetoothSDPServiceRecord.publishedServiceRecord(with: serviceDictionary! as [NSObject : AnyObject])
        if serviceRecord == nil {
            logger.info("serviceRecord is nil")
            return
        }
        logger.info("\(self.serviceRecord!.debugDescription)")
    }
    
    func setupPeripheral() {
        stopScan()
        ensureBluetoothControllerConfigured()
        addSdpRecord()
        registerChannelOpenDelegate()
    }
    func registerChannelOpenDelegate(){
        guard IOBluetoothL2CAPChannel
                .register(forChannelOpenNotifications: self,
                          selector: #selector(newL2CAPChannelOpened), withPSM: BluetoothManager.controlPsm, direction: kIOBluetoothUserNotificationChannelDirectionIncoming) != nil else
        {
            logger.info("failed to register for channel \(BluetoothManager.controlPsm) open notifications.")
            return
        }
        guard IOBluetoothL2CAPChannel
                .register(forChannelOpenNotifications: self,
                          selector: #selector(newL2CAPChannelOpened), withPSM: BluetoothManager.interruptPsm, direction: kIOBluetoothUserNotificationChannelDirectionIncoming) != nil else
        {
            logger.info("failed to register for channel \(BluetoothManager.interruptPsm) open notifications.")
            return
        }
    }
    
    func setupNintendoSwitchDevice(_ address: String) {
        logger.info(#function)
        let nintendoSwitch = IOBluetoothDevice.init(addressString: address)!
        nintendoSwitch.openConnection()
        setupDevice(nintendoSwitch)
    }
    func cleanup() {
        logger.info("Removing service record")
        serviceRecord?.remove()
    }
    func setupDevice(_ device: IOBluetoothDevice){
        guard interruptChannel == nil && controlChannel == nil else {
            logger.info("Skipping \(#function) as interruptChannel and controlChannel are not nil")
            return
        }
        logger.info(#function)
        var channel: IOBluetoothL2CAPChannel? = IOBluetoothL2CAPChannel()
        if device.openL2CAPChannelSync(&channel, withPSM: BluetoothManager.controlPsm, delegate: self) != kIOReturnSuccess {
            logger.info("Failed to open l2cap channel \(BluetoothManager.controlPsm)")
        }
        var channel2: IOBluetoothL2CAPChannel? = IOBluetoothL2CAPChannel()
        if device.openL2CAPChannelSync(&channel2, withPSM: BluetoothManager.interruptPsm, delegate: self) != kIOReturnSuccess {
            logger.info("Failed to open l2cap channel \(BluetoothManager.interruptPsm)")
        }
    }
    
    @objc func newL2CAPChannelOpened(notification: IOBluetoothUserNotification, channel: IOBluetoothL2CAPChannel) {
        logger.info(#function)
        channel.setDelegate(self)
    }
    
    func getDataFromChannel(data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) -> Bytes {
        let opaquePointer = OpaquePointer(dataPointer)
        let unsafePointer = UnsafeMutablePointer<Byte>(opaquePointer)
        return Array(UnsafeBufferPointer<Byte>(start: unsafePointer, count: dataLength))
    }
    
    public func l2capChannelData(_ l2capChannel: IOBluetoothL2CAPChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        if l2capChannel == controllerProtocol?.transport {
            let data = getDataFromChannel(data: dataPointer, length: dataLength)
            controllerProtocol?.reportReceived(data)
        } else {
            fatalError("Received data from non-interrupt channel.")
        }
    }
    func sendEmptyInputReport(l2capChannel: IOBluetoothL2CAPChannel) -> IOReturn {
        logger.info(#function)
        var emptyInputReport = Bytes(repeating: 0, count: 364);
        emptyInputReport[0] = 0xA1
        return l2capChannel.writeSync(&emptyInputReport, length: UInt16(emptyInputReport.count))
    }
    func triggerResponseFromSwitch(l2capChannel: IOBluetoothL2CAPChannel){
        logger.info(#function)
        for _ in (1...10) {
            let result = sendEmptyInputReport(l2capChannel: l2capChannel)
            logger.info("Result: \(result)")
        }
    }
    
    public func l2capChannelOpenComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, status error: IOReturn) {
        logger.info(#function)
        guard error == kIOReturnSuccess else {
            logger.info("Channel open failed: \(error)")
            return
        }
        
        logger.info("\(l2capChannel.debugDescription)")
        switch l2capChannel.psm {
        case BluetoothManager.controlPsm:
            logger.info("Control PSM Channel Connected")
            self.controlChannel = l2capChannel
        case BluetoothManager.interruptPsm:
            logger.info("Interrupt PSM Channel Connected")
            self.interruptChannel = l2capChannel
            self.controllerProtocol = ControllerProtocol(controller: Controller.proController, spiFlash: try! FlashMemory(), hostAddress: hostAddress!)
            self.controllerProtocol?.connectionMade(l2capChannel)
            stopScan()
            triggerResponseFromSwitch(l2capChannel: l2capChannel)
            deviceAddress = l2capChannel.device.addressString.split(separator: "-").joined(separator: ":")
        default:
            return
        }
    }
    
    public func l2capChannelClosed(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        logger.info(#function)
        logger.info("\(l2capChannel.debugDescription)")
        if l2capChannel == self.controllerProtocol?.transport {
            controllerProtocol?.connectionLost()
            interruptChannel = nil
        }
        if l2capChannel == controlChannel {
            controlChannel = nil
        }
    }
    public func l2capChannelReconfigured(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        logger.info(#function)
        logger.info("\(l2capChannel.debugDescription)")
    }
    public func l2capChannelWriteComplete(_ l2capChannel: IOBluetoothL2CAPChannel!, refcon: UnsafeMutableRawPointer!, status error: IOReturn) {
        logger.info(#function)
    }
    public func l2capChannelQueueSpaceAvailable(_ l2capChannel: IOBluetoothL2CAPChannel!) {
        logger.info(#function)
        logger.info("\(l2capChannel.debugDescription)")
    }
    public func bluetoothHCIEventNotificationMessage(_ controller: IOBluetoothHostController, in message: IOBluetoothHCIEventNotificationMessageRef) {
        let isConnected = controller.powerState == kBluetoothHCIPowerStateON
        if isConnected != connected {
            logger.info("Detected powerState change: \(self.connected) -> \(isConnected)")
            connected = isConnected
            if connected {
                setupPeripheral()
            }
        }
    }
}
