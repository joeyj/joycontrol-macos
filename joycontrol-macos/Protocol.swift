//
//  Protocol.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 1/28/21.
//

import Bluetooth
import Foundation
import IOBluetooth
import os.log

public protocol ControllerProtocolDelgate: class {
    func controllerProtocolConnectionLost()
}

// swiftlint:disable:next type_body_length
public class ControllerProtocol {
    private var logger = Logger()
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
    private weak var delegate: ControllerProtocolDelgate?
    public init(controller: Controller, spiFlash: FlashMemory,
                hostAddress: BluetoothAddress, delegate: ControllerProtocolDelgate) {
        self.controller = controller
        self.spiFlash = spiFlash

        inputReportTimer = 0x00

        dataReceived = DispatchSemaphore(value: 0)

        // nil = Just answer to sub commands
        inputReportMode = nil
        inputReportModeTimer = nil

        // This event gets triggered once the Switch assigns a player number to the controller and accepts user inputs
        setPlayerLightsSemaphore = DispatchSemaphore(value: 0)
        self.hostAddress = hostAddress
        self.delegate = delegate
        controllerState = ControllerState(controllerProtocol: self, controller: controller, spiFlash: spiFlash)
    }

    /// Waits for the controller state to be sent.
    /// - Throws: ApplicationError.general if the connection was lost.
    public func sendControllerState() throws {
        logger.info(#function)
        if transport == nil {
            throw ApplicationError.general("Transport not registered.")
        }

        controllerState!.sendCompleteSemaphore.wait() // wait for a send to complete
    }

    /// Sets timer byte and current button state in the input report and sends it.
    /// Fires sigIsSend event in the controller state afterwards.
    /// - Throws: ationError.general if the connection was lost.
    public func write(_ inputReport: InputReport) throws {
        logger.info(#function)
        if transport == nil {
            throw ApplicationError.general("Transport not registered.")
        }
        // set button and stick data of input report
        inputReport.setButtonStatus(controllerState!.buttonState.bytes())
        let leftStick = controllerState?.leftStickState?.bytes() ?? [0x00, 0x00, 0x00]
        let rightStick = controllerState?.rightStickState?.bytes() ?? [0x00, 0x00, 0x00]
        inputReport.setStickStatus(leftStick, rightStick)

        // set timer byte of input report
        inputReport.setTimer(inputReportTimer)
        let newTimerValue = UInt16(inputReportTimer) + UInt16(1)
        inputReportTimer = Byte(newTimerValue > Byte.max ? 0 : newTimerValue)
        logger.info("new inputReportTimer value: \(self.inputReportTimer)")
        var bytes = inputReport.bytes()
        transport!.writeSync(&bytes, length: UInt16(bytes.count))

        controllerState!.sendCompleteSemaphore.signal()
    }

    public func connectionMade(_ transport: IOBluetoothL2CAPChannel) {
        logger.info(#function)
        self.transport = transport
    }

    public func connectionLost() {
        if transport != nil {
            logger.info(#function)
            transport = nil
            inputReportModeTimer?.invalidate()
            inputReportMode = nil
        }
        delegate?.controllerProtocolConnectionLost()
    }

    @objc func sendInputReport() throws {
        logger.info(#function)
        let inputReport = try! InputReport(nil)
        inputReport.setVibratorInput()
        inputReport.setMisc()
        if inputReportMode == nil {
            throw ApplicationError.general("Input report mode != set.")
        }
        inputReport.setInputReportId(inputReportMode!)

        // write IMU input report.
        // TODO: set some sensor data
        inputReport.set6axisData()

        // TODO: NFC - set nfc data
        if inputReport.getInputReportId() == InputReportId.setNfcData {
            return
        }

        try! write(inputReport)
    }

    public func inputReportModeFull() throws {
        logger.info(#function)
        if inputReportModeTimer != nil {
            logger.info("already in input report mode")
            return
        }
        var lastSent = Date()
        // send state at 66Hz
        let sendDelay = 0.015 // 0.015 This appears too slow
        DispatchQueue.main.async {
            self.inputReportModeTimer = Timer.scheduledTimer(withTimeInterval: sendDelay, repeats: true) { _ in
                if Date().timeIntervalSince(lastSent).isLess(than: sendDelay) {
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
        dataReceived.signal()

        let report = try! OutputReport(data)
        let outputReportId = report.getOutputReportId()
        if outputReportId == OutputReportID.subCommand {
            _ = try! replyToSubCommand(report)
        } else {
            logger.info("Output report \(String(describing: outputReportId)) not implemented - ignoring")
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func replyToSubCommand(_ report: OutputReport) throws -> Bool {
        // classify sub command
        let subCommand = report.getSubCommand()
        if subCommand == SubCommand.none {
            throw ApplicationError.general("Received output report does not contain a sub command")
        }
        logger.info("received output report - Sub command \(String(describing: subCommand))")

        let subCommandData = report.getSubCommandData()!

        switch subCommand {
        case SubCommand.requestDeviceInfo:
            commandRequestDeviceInfo(subCommandData)
        case SubCommand.setShipmentState:
            commandSetShipmentState(subCommandData)
        case SubCommand.spiFlashRead:
            commandSpiFlashRead(subCommandData)
        case SubCommand.setInputReportMode:
            commandSetInputReportMode(subCommandData) // TODO: when to stop input report mode?
        case SubCommand.triggerButtonsElapsedTime:
            try! commandTriggerButtonsElapsedTime(subCommandData)
        case SubCommand.enable6axisSensor:
            commandEnable6axisSensor(subCommandData)
        case SubCommand.enableVibration:
            commandEnableVibration(subCommandData)
        case SubCommand.setNfcIrMcuConfig:
            commandSetNfcIrMcuConfig(subCommandData)
        case SubCommand.setNfcIrMcuState:
            try! commandSetNfcIrMcuState(subCommandData)
        case SubCommand.setPlayerLights:
            commandSetPlayerLights(subCommandData)
        case SubCommand.setHCIState:
            // assume Nintendo Switch is going to sleep
            connectionLost()
        default:
            logger.info("Sub command 0x{subCommand.value:02x} not implemented - ignoring")
        }
        return true
    }

    private func createStandardInputReport() -> InputReport {
        let inputReport = try! InputReport(nil)
        inputReport.setStandardInputReport()
        inputReport.setMisc()
        return inputReport
    }

    private func commandRequestDeviceInfo(_: Bytes) {
        let inputReport = createStandardInputReport()
        inputReport.setAck(0x82)
        try! inputReport.sub0x02DeviceInfo(mac: hostAddress.bytes, controller: controller)

        try! write(inputReport)
    }

    private func commandSetShipmentState(_: Bytes) {
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.setShipmentState)

        try! write(inputReport)
    }

    /// Replies with 0x21 input report containing requested data from the flash memory.
    /// - Parameter subCommandData: input report sub command data bytes
    private func commandSpiFlashRead(_ subCommandData: Bytes) {
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x90)

        // parse offset
        var offset = 0
        var digit = 1
        for index in 0 ... 3 {
            offset += Int(subCommandData[index]) * digit
            digit *= 0x100
        }
        let size = subCommandData[4]

        let spiFlashData = Array(spiFlash.data[offset ... offset + Int(size) - 1])
        try! inputReport.sub0x10SpiFlashRead(offset, size, spiFlashData)
        try! write(inputReport)
    }

    private func commandSetInputReportMode(_ subCommandData: Bytes) {
        let requestedInputReportMode = InputReportId(rawValue: subCommandData[0])!
        if inputReportMode == requestedInputReportMode {
            let debugDesc = String(describing: requestedInputReportMode)
            logger.info("Already in input report mode \(debugDesc) - ignoring request")
        }
        // Start input report reader
        if [InputReportId.imu, InputReportId.setNfcData].contains(requestedInputReportMode) {
            try! inputReportModeFull()
        } else {
            let debugDesc = String(describing: requestedInputReportMode)
            logger.info("input report mode \(debugDesc) not implemented - ignoring request")
            return
        }

        logger.info("Setting input report mode to \(String(describing: requestedInputReportMode))...")
        inputReportMode = requestedInputReportMode

        // Send acknowledgement
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.setInputReportMode)

        try! write(inputReport)
    }

    private func commandTriggerButtonsElapsedTime(_: Bytes) throws {
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x83)
        inputReport.replyToSubCommandId(SubCommand.triggerButtonsElapsedTime)
        // Hack: We assume this command is only used during pairing - Set values so the Switch assigns a player number
        if controller == Controller.proController {
            try! inputReport.sub0x04TriggerButtonsElapsedTime(LMs: 3000, RMs: 3000)
        } else if [Controller.joyconL, Controller.joyconR].contains(controller) {
            // TODO: What do we do if we want to pair a combined JoyCon?
            try! inputReport.sub0x04TriggerButtonsElapsedTime(SLMs: 3000, SRMs: 3000)
        } else {
            throw ApplicationError.general(String(describing: controller))
        }

        try! write(inputReport)
    }

    private func commandEnable6axisSensor(_: Bytes) {
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.enable6axisSensor)

        try! write(inputReport)
    }

    private func commandEnableVibration(_: Bytes) {
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.enableVibration)

        try! write(inputReport)
    }

    private func commandSetNfcIrMcuConfig(_: Bytes) {
        // TODO: NFC
        let inputReport = createStandardInputReport()

        inputReport.setAck(0xA0)
        inputReport.replyToSubCommandId(SubCommand.setNfcIrMcuConfig)

        let data: Bytes = [1, 0, 255, 0, 8, 0, 27, 1, 0, 0, 0, 0, 0, 0,
                           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                           0, 0, 0, 0, 200]
        for index in 0 ... data.count - 1 {
            inputReport.data[16 + index] = data[index]
        }
        try! write(inputReport)
    }

    private func commandSetNfcIrMcuState(_ subCommandData: Bytes) throws {
        // TODO: NFC
        let inputReport = createStandardInputReport()
        let argument = subCommandData[0]

        if argument == 0x01 {
            // 0x01 = Resume
            inputReport.setAck(0x80)
            inputReport.replyToSubCommandId(SubCommand.setNfcIrMcuState)
        } else if argument == 0x00 {
            // 0x00 = Suspend
            inputReport.setAck(0x80)
            inputReport.replyToSubCommandId(SubCommand.setNfcIrMcuState)
        } else {
            throw ArgumentError.invalid("Argument \(argument) of \(SubCommand.setNfcIrMcuState) not implemented.")
        }
        try! write(inputReport)
    }

    private func commandSetPlayerLights(_: Bytes) {
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(SubCommand.setPlayerLights)

        try! write(inputReport)

        setPlayerLightsSemaphore.signal()
    }
}
