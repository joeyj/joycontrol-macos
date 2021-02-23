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

protocol ControllerProtocolDelgate: AnyObject {
    func controllerProtocolConnectionLost()
}

class ControllerProtocol {
    private let logger = Logger()
    let controller: Controller
    let spiFlash: FlashMemory
    let setPlayerLightsSemaphore: DispatchSemaphore
    let transport: IOBluetoothL2CAPChannel
    private var inputReportTimer: Byte
    private var inputReportMode: InputReportId?
    private let dataReceived: DispatchSemaphore
    var controllerState: ControllerState?
    private var inputReportModeTimer: Timer?
    var hostAddress: BluetoothAddress
    private weak var delegate: ControllerProtocolDelgate?
    init(
        controller: Controller,
        spiFlash: FlashMemory,
        hostAddress: BluetoothAddress,
        delegate: ControllerProtocolDelgate,
        transport: IOBluetoothL2CAPChannel
    ) {
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
        self.transport = transport
        controllerState = ControllerState(controllerProtocol: self, controller: controller, spiFlash: spiFlash)
        DispatchQueue.main.async {
            self.triggerResponseFromSwitch()
        }
    }

    private func triggerResponseFromSwitch() {
        logger.debug(#function)
        for _ in 1 ... 10 {
            let emptyInputReport = try! InputReport()
            write(emptyInputReport)
        }
    }

    /// Waits for the controller state to be sent.
    /// - Throws: ApplicationError.general if the connection was lost.
    func sendControllerState() {
        logger.debug(#function)
        controllerState!.sendCompleteSemaphore.wait() // wait for a send to complete
    }

    /// Sets timer byte and current button state in the input report and sends it.
    /// Fires sigIsSend event in the controller state afterwards.
    /// - Throws: ationError.general if the connection was lost.
    private func write(_ inputReport: InputReport) {
        logger.debug(#function)

        guard transport.device.isConnected() else {
            logger.debug("Transport is not connected. Skipping write.")
            return
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
        let result = transport.writeSync(&bytes, length: UInt16(bytes.count))
        guard result == kIOReturnSuccess else {
            fatalError("Failed to write to transport. IOResult: \(result)")
        }

        controllerState!.sendCompleteSemaphore.signal()
    }

    func connectionLost() {
        logger.debug(#function)
        inputReportModeTimer?.invalidate()
        inputReportMode = nil
        delegate?.controllerProtocolConnectionLost()
    }

    @objc
    func sendInputReport() {
        logger.debug(#function)
        let inputReport = try! InputReport()
        inputReport.setVibratorInput()
        inputReport.setMisc()
        if inputReportMode == nil {
            fatalError("Input report mode != set.")
        }
        inputReport.setInputReportId(inputReportMode!)

        // write IMU input report.
        // TODO: set some sensor data
        inputReport.set6axisData()

        // TODO: NFC - set nfc data
        if inputReport.getInputReportId() == .setNfcData {
            return
        }

        write(inputReport)
    }

    private func inputReportModeFull() {
        logger.debug(#function)
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
                self.sendInputReport()
                lastSent = Date()
            }
        }
    }

    func reportReceived(_ data: Bytes) {
        logger.debug(#function)
        dataReceived.signal()

        let report = try! OutputReport(data)
        let outputReportId = report.getOutputReportId()
        if outputReportId == .subCommand {
            replyToSubCommand(report)
        } else {
            logger.info("Output report \(String(describing: outputReportId)) not implemented - ignoring")
        }
    }

    private func replyToSubCommand(_ report: OutputReport) {
        // classify sub command
        let subCommand = report.getSubCommand()
        if subCommand == .none {
            logger.error("Received output report does not contain a sub command")
            return
        }
        logger.info("received output report - Sub command \(String(describing: subCommand))")

        let subCommandData = report.getSubCommandData()!

        switch subCommand {
        case .setInputReportMode:
            commandSetInputReportMode(subCommandData) // TODO: when to stop input report mode?

        case .setPlayerLights:
            commandSetPlayerLights(subCommandData)

        case .setHCIState:
            // assume Nintendo Switch is going to sleep
            connectionLost()

        default:

            let inputReportFactory = InputReportFactory.fromSubCommand(subCommand, subCommandData)

            guard inputReportFactory != nil else {
                logger.debug("Unable to create InputReport from SubCommand: \(String(describing: subCommand))")
                return
            }

            let inputReport = inputReportFactory!(self)

            write(inputReport)
        }
    }

    private func commandSetInputReportMode(_ subCommandData: Bytes) {
        let requestedInputReportMode = InputReportId(rawValue: subCommandData[0])!
        if inputReportMode == requestedInputReportMode {
            let debugDesc = String(describing: requestedInputReportMode)
            logger.info("Already in input report mode \(debugDesc) - ignoring request")
        }
        // Start input report reader
        if [.imu, .setNfcData].contains(requestedInputReportMode) {
            inputReportModeFull()
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
        inputReport.replyToSubCommandId(.setInputReportMode)

        write(inputReport)
    }

    private func commandSetPlayerLights(_: Bytes) {
        let inputReport = createStandardInputReport()

        inputReport.setAck(0x80)
        inputReport.replyToSubCommandId(.setPlayerLights)

        write(inputReport)

        setPlayerLightsSemaphore.signal()
    }

    deinit {}
}
