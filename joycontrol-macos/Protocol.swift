//
//  Protocol.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/28/21.
//

import Foundation
import IOBluetooth
import Bluetooth
import os.log

public protocol ControllerProtocolDelgate {
    func controllerProtocolConnectionLost()
}

public class ControllerProtocol {
    private var logger: Logger = Logger()
    public var controller: Controller
    public var spiFlash: FlashMemory
    public var setPlayerLightsSemaphore: DispatchSemaphore
    public var transport: IOBluetoothL2CAPChannel?
    private var inputReportTimer: Byte
    private var inputReportMode: InputReportId?
    private var dataReceived: DispatchSemaphore
    public var controllerState: ControllerState?
    private var inputReportModeTimer: Timer?
    private var hostAddress: BluetoothAddress
    private let delegate: ControllerProtocolDelgate
    public init(controller: Controller, spiFlash: FlashMemory, hostAddress: BluetoothAddress, delegate: ControllerProtocolDelgate) {
        self.controller = controller
        self.spiFlash = spiFlash
        
        self.inputReportTimer = 0x00
        
        self.dataReceived = DispatchSemaphore(value: 0)
        
        // nil = Just answer to sub commands
        self.inputReportMode = nil
        self.inputReportModeTimer = nil
        
        // This event gets triggered once the Switch assigns a player number to the controller and accepts user inputs
        self.setPlayerLightsSemaphore = DispatchSemaphore(value: 0)
        self.hostAddress = hostAddress
        self.delegate = delegate
        self.controllerState = ControllerState(controllerProtocol: self, controller: controller, spiFlash:spiFlash)
    }
    /// Waits for the controller state to be sent.
    /// - Throws: ApplicationError.general if the connection was lost.
    public func sendControllerState() throws {
        logger.info(#function)
        if self.transport == nil {
            throw ApplicationError.general("Transport not registered.")
        }
        
        self.controllerState!.sendCompleteSemaphore.wait() // wait for a send to complete
    }
    /// Sets timer byte and current button state in the input report and sends it.
    /// Fires sigIsSend event in the controller state afterwards.
    /// - Throws: ationError.general if the connection was lost.
    public func write(_ inputReport: InputReport) throws {
        logger.info(#function)
        if self.transport == nil {
            throw ApplicationError.general("Transport not registered.")
        }
        // set button and stick data of input report
        inputReport.setButtonStatus(self.controllerState!.buttonState.bytes())
        var leftStick: Bytes
        var rightStick: Bytes
        if self.controllerState!.leftStickState == nil {
            leftStick = [0x00, 0x00, 0x00]
        }
        else {
            leftStick = self.controllerState!.leftStickState!.bytes()
            
        }
        if self.controllerState!.rightStickState == nil {
            rightStick = [0x00, 0x00, 0x00] }
        else {
            rightStick = self.controllerState!.rightStickState!.bytes()
            
        }
        inputReport.setStickStatus(leftStick, rightStick)
        
        // set timer byte of input report
        inputReport.setTimer(self.inputReportTimer)
        let newTimerValue: UInt16 = UInt16(inputReportTimer) + UInt16(1)
        self.inputReportTimer = Byte(newTimerValue > Byte.max ? 0 : newTimerValue)
        logger.info("new inputReportTimer value: \(self.inputReportTimer)")
        var bytes =
            inputReport.bytes()
        self.transport!.writeSync(&bytes, length: UInt16(bytes.count))
        
        self.controllerState!.sendCompleteSemaphore.signal()
    }
    public func connectionMade(_ transport: IOBluetoothL2CAPChannel) {
        logger.info(#function)
        self.transport = transport
    }
    public func connectionLost() {
        if self.transport != nil {
            logger.info(#function)
            self.transport = nil
            self.inputReportModeTimer?.invalidate()
            self.inputReportMode = nil
        }
        delegate.controllerProtocolConnectionLost()
    }
    @objc func sendInputReport() throws {
        logger.info(#function)
        let inputReport = try! InputReport(nil)
        inputReport.setVibratorInput()
        inputReport.setMisc()
        if self.inputReportMode == nil {
            throw ApplicationError.general("Input report mode != set.")
        }
        inputReport.setInputReportId(self.inputReportMode!)
        
        // write IMU input report.
        // TODO: set some sensor data
        inputReport.set6axisData()
        
        // TODO NFC - set nfc data
        if inputReport.getInputReportId() == InputReportId.setNfcData {
            return
        }
        
        try! self.write(inputReport)
    }
    public func inputReportModeFull() throws {
        logger.info(#function)
        if self.inputReportModeTimer != nil {
            logger.info("already in input report mode")
            return
        }
        var lastSent = Date()
        // send state at 66Hz
        let sendDelay = 0.015 // 0.015 This appears too slow
        DispatchQueue.main.async {
            self.inputReportModeTimer = Timer.scheduledTimer(withTimeInterval: sendDelay, repeats: true) {
                _ in
                if(Date().timeIntervalSince(lastSent).isLess(than: sendDelay)){
                    // don't send reports too closely together
                    return
                }
                try! self.sendInputReport()
                lastSent = Date()
            }
        }
    }
    
    public func reportReceived(_ data: Bytes) {
        logger.info(#function)
        self.dataReceived.signal()
        
        let report = try! OutputReport(data)
        let outputReportId = report.getOutputReportId()
        if outputReportId == OutputReportID.subCommand {
            _ = try! self.replyToSubCommand(report)
        }
        else {
            logger.info("Output report \(String(describing: outputReportId)) not implemented - ignoring")
        }
    }
    private func replyToSubCommand(_ report: OutputReport) throws -> Bool {
        // classify sub command
        let subCommand = report.getSubCommand()
        if subCommand == SubCommand.none {
            throw ApplicationError.general("Received output report does not contain a sub command")
        }
        logger.info("received output report - Sub command \(String(describing: subCommand))")
        
        let subCommandData = report.getSubCommandData()!
        
        // answer to sub command
        if subCommand == SubCommand.requestDeviceInfo {
            self.commandRequestDeviceInfo(subCommandData)
        }
        else if subCommand == SubCommand.setShipmentState {
            self.commandSetShipmentState(subCommandData)
        }
        else if subCommand == SubCommand.spiFlashRead {
            self.commandSpiFlashRead(subCommandData)
        }
        else if subCommand == SubCommand.setInputReportMode {
            self.commandSetInputReportMode(subCommandData) // TODO: when to stop input report mode?
        }
        else if subCommand == SubCommand.triggerButtonsElapsedTime {
            try! self.commandTriggerButtonsElapsedTime(subCommandData)
        }
        else if subCommand == SubCommand.enable6axisSensor {
            self.commandEnable6axisSensor(subCommandData)
        }
        else if subCommand == SubCommand.enableVibration {
            self.commandEnableVibration(subCommandData)
        }
        else if subCommand == SubCommand.setNfcIrMcuConfig {
            self.commandSetNfcIrMcuConfig(subCommandData)
        }
        else if subCommand == SubCommand.setNfcIrMcuState {
            try! self.commandSetNfcIrMcuState(subCommandData)
        }
        else if subCommand == SubCommand.setPlayerLights {
            self.commandSetPlayerLights(subCommandData)
        }
        else if subCommand == SubCommand.setHCIState {
            // assume Nintendo Switch is going to sleep
            connectionLost()
        }
        else {
            logger.info("Sub command 0x{subCommand.value:02x} not implemented - ignoring")
        }
        return true
    }
    private func commandRequestDeviceInfo(_ subCommandData: Bytes) {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        inputReport.setAck(0x82)
        try! inputReport.sub0x02DeviceInfo(mac: hostAddress.bytes, controller:self.controller)
        
        try! self.write(inputReport)
    }
    private func commandSetShipmentState(_ subCommandData: Bytes) {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.setShipmentState)
        
        try! self.write(inputReport)
    }
    /// Replies with 0x21 input report containing requested data from the flash memory.
    /// - Parameter subCommandData: input report sub command data bytes
    private func commandSpiFlashRead(_ subCommandData: Bytes) {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0x90)
        
        // parse offset
        var offset = 0
        var digit = 1
        for i in (0...3) {
            offset += Int(subCommandData[i]) * digit
            digit *= 0x100
        }
        let size = subCommandData[4]
        
        let spiFlashData = Array(self.spiFlash.data[offset...offset + Int(size)-1])
        try! inputReport.sub0x10SpiFlashRead(offset, size, spiFlashData)
        try! self.write(inputReport)
    }
    private func commandSetInputReportMode(_ subCommandData: Bytes) {
        let requestedInputReportMode = InputReportId(rawValue: subCommandData[0])!
        if self.inputReportMode == requestedInputReportMode {
            logger.info("Already in input report mode \(String(describing: requestedInputReportMode)) - ignoring request")
        }
        // Start input report reader
        if [InputReportId.imu, InputReportId.setNfcData].contains(requestedInputReportMode) {
            try! self.inputReportModeFull()
        }
        else {
            logger.info("input report mode \(String(describing: requestedInputReportMode)) not implemented - ignoring request")
            return
        }
        
        logger.info("Setting input report mode to \(String(describing: requestedInputReportMode))...")
        self.inputReportMode = requestedInputReportMode
        
        // Send acknowledgement
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.setInputReportMode)
        
        try! self.write(inputReport)
    }
    private func commandTriggerButtonsElapsedTime(_ subCommandData: Bytes) throws {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0x83)
        inputReport.replyToSubCommandId(SubCommand.triggerButtonsElapsedTime)
        // Hack: We assume this command is only used during pairing - Set values so the Switch assigns a player number
        if self.controller == Controller.proController {
            try! inputReport.sub0x04TriggerButtonsElapsedTime(LMs:3000, RMs:3000)
        }
        else if [Controller.joyconL, Controller.joyconR].contains(self.controller) {
            // TODO: What do we do if we want to pair a combined JoyCon?
            try! inputReport.sub0x04TriggerButtonsElapsedTime(SLMs:3000, SRMs:3000)
        }
        else {
            throw ApplicationError.general(String(describing: self.controller))
        }
        
        try! self.write(inputReport)
    }
    private func commandEnable6axisSensor(_ subCommandData: Bytes) {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.enable6axisSensor)
        
        try! self.write(inputReport)
    }
    private func commandEnableVibration(_ subCommandData: Bytes) {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.enableVibration)
        
        try! self.write(inputReport)
    }
    private func commandSetNfcIrMcuConfig(_ subCommandData: Bytes) {
        // TODO NFC
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0xA0)
        inputReport.replyToSubCommandId(SubCommand.setNfcIrMcuConfig)
        
        let data: Bytes = [1, 0, 255, 0, 8, 0, 27, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 200]
        for i in (0...data.count-1) {
            inputReport.data[16 + i] = data[i]
        }
        try! self.write(inputReport)
    }
    private func commandSetNfcIrMcuState(_ subCommandData: Bytes) throws {
        // TODO NFC
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        if subCommandData[0] == 0x01 {
            // 0x01 = Resume
            inputReport.setAck(0x80)
            inputReport.replyToSubCommandId(SubCommand.setNfcIrMcuState)
        }
        else if subCommandData[0] == 0x00 {
            // 0x00 = Suspend
            inputReport.setAck(0x80)
            inputReport.replyToSubCommandId(SubCommand.setNfcIrMcuState)
        }
        else {
            throw ArgumentError.invalid("Argument \(subCommandData[0]) of \(SubCommand.setNfcIrMcuState) not implemented.")
        }
        try! self.write(inputReport)
    }
    private func commandSetPlayerLights(_ subCommandData: Bytes) {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        
        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.setPlayerLights)
        
        try! self.write(inputReport)
        
        self.setPlayerLightsSemaphore.signal()
    }
}
