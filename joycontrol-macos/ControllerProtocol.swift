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
    let spiFlash: FlashMemory
    let readyToAcceptInput = DispatchSemaphore(value: 0)
    private let transport: IOBluetoothL2CAPChannel
    private var inputReportTimer: Byte = 0x00
    private var inputReportMode: InputReportId?
    var controllerState: ControllerState
    private var inputReportModeTimer: Timer?
    var hostAddress: BluetoothAddress
    private weak var delegate: ControllerProtocolDelgate?
    init(
        spiFlash: FlashMemory,
        hostAddress: BluetoothAddress,
        delegate: ControllerProtocolDelgate,
        transport: IOBluetoothL2CAPChannel
    ) {
        self.spiFlash = spiFlash
        self.hostAddress = hostAddress
        self.delegate = delegate
        self.transport = transport
        controllerState = ControllerState(spiFlash: spiFlash)
        DispatchQueue.main.async {
            self.triggerResponseFromSwitch()
        }
    }

    private func triggerResponseFromSwitch() {
        logger.debug(#function)
        for _ in 1 ... 10 {
            let emptyInputReport = EmptyInputReport()
            write(emptyInputReport)
        }
    }

    /// Sets timer byte and current button state in the input report and sends it.
    private func write(_ inputReport: InputReport) {
        logger.debug(#function)

        guard transport.device.isConnected() else {
            logger.debug("Transport is not connected. Skipping write.")
            return
        }

        inputReport.setButtonStatus(controllerState.buttonState.bytes())
        let leftStick = controllerState.leftStickState.bytes()
        let rightStick = controllerState.rightStickState.bytes()
        inputReport.setStickStatus(leftStick, rightStick)
        inputReport.setTimer(inputReportTimer)
        let newTimerValue = UInt16(inputReportTimer) + UInt16(1)
        inputReportTimer = Byte(newTimerValue > Byte.max ? 0 : newTimerValue)
        logger.debug("\(inputReport.debugDescription)")
        var bytes = inputReport.bytes()
        let result = transport.writeSync(&bytes, length: UInt16(bytes.count))
        guard result == kIOReturnSuccess else {
            fatalError("Failed to write to transport. IOResult: \(result)")
        }
    }

    func connectionLost() {
        logger.debug(#function)
        inputReportModeTimer?.invalidate()
        inputReportMode = nil
        delegate?.controllerProtocolConnectionLost()
    }

    private func inputReportModeFull() {
        logger.debug(#function)
        if inputReportModeTimer != nil {
            logger.error("already in input report mode")
            return
        }
        var lastSent = Date()
        // send state at 66Hz
        let sendDelay = 0.015
        DispatchQueue.main.async {
            self.inputReportModeTimer = Timer.scheduledTimer(withTimeInterval: sendDelay, repeats: true) { _ in
                if Date().timeIntervalSince(lastSent).isLess(than: sendDelay) {
                    // don't send reports too closely together
                    return
                }
                let inputReport = IMUInputReport()

                self.write(inputReport)
                lastSent = Date()
            }
        }
    }

    func reportReceived(_ data: Bytes) {
        logger.debug(#function)

        let report = try! OutputReport(data)
        let outputReportId = report.getOutputReportId()
        if outputReportId == .subCommand {
            replyToSubCommand(report)
        } else {
            logger.debug("Output report \(String(describing: outputReportId)) not implemented - ignoring")
        }
    }

    private func replyToSubCommand(_ report: OutputReport) {
        let subCommand = report.getSubCommand()
        if subCommand == .none {
            logger.error("Received output report does not contain a sub command")
            return
        }
        logger.debug("received output report - Sub command \(String(describing: subCommand))")

        let subCommandData = report.getSubCommandData()!

        if subCommand == .setInputReportMode {
            commandSetInputReportMode(subCommandData)
        } else if subCommand == .setPlayerLights {
            readyToAcceptInput.signal()
        } else if subCommand == .setHCIState {
            // assume Nintendo Switch is going to sleep
            connectionLost()
        }

        let inputReportFactory = InputReportFactory.fromSubCommand(subCommand, subCommandData)

        guard inputReportFactory != nil else {
            logger.debug("Unable to create InputReport from SubCommand: \(String(describing: subCommand))")
            return
        }

        let inputReport = inputReportFactory!(self)

        write(inputReport)
    }

    private func commandSetInputReportMode(_ subCommandData: Bytes) {
        let requestedInputReportMode = InputReportId(rawValue: subCommandData[0])!
        if inputReportMode == requestedInputReportMode {
            let debugDesc = String(describing: requestedInputReportMode)
            logger.error("Already in input report mode \(debugDesc) - ignoring request")
        }

        if requestedInputReportMode == .imu {
            inputReportModeFull()
        } else {
            let debugDesc = String(describing: requestedInputReportMode)
            logger.debug("input report mode \(debugDesc) not implemented - ignoring request")
            return
        }

        logger.debug("Setting input report mode to \(String(describing: requestedInputReportMode))...")
        inputReportMode = requestedInputReportMode
    }

    deinit {}
}
