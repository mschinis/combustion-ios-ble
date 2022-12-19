//  DeviceManager.swift

/*--
MIT License

Copyright (c) 2021 Combustion Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--*/

import Foundation
import SwiftUI
import NordicDFU

/// Singleton that provides list of detected Devices
/// (either via Bluetooth or from a list in the Cloud)
public class DeviceManager : ObservableObject {
    
    /// Serial Number value indicating 'No Probe'
    private let INVALID_PROBE_SERIAL_NUMBER = 0
    
    /// Singleton accessor for class
    public static let shared = DeviceManager()
    
    public enum Constants {
        public static let MINIMUM_PREDICTION_SETPOINT_CELSIUS = 0.0
        public static let MAXIMUM_PREDICTION_SETPOINT_CELSIUS = 102.0
    }
    
    /// Dictionary of discovered devices.
    /// key = string representation of device identifier (UUID)
    @Published public private(set) var devices : [String: Device] = [String: Device]()

    // Struct to store when BLE message was send and the completion handler for message
    private struct MessageHandler {
        let timeSent: Date
        let handler: (Bool) -> Void
    }
    
    /// Tracks whether MeatNet is enabled.
    private var meatNetEnabled : Bool = false;
    
    private let messageHandlers = MessageHandlers()
    
    public func addSimulatedProbe() {
        addDevice(device: SimulatedProbe())
    }
    
    public func initBluetooth() {
        BleManager.shared.initBluetooth()
    }
    
    /// Enables MeatNet repeater network.
    public func enableMeatNet() {
        meatNetEnabled = true;
    }
    
    /// Private initializer to enforce singleton
    private init() {
        BleManager.shared.delegate = self
        
        // Start a timer to set stale flag on devices
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            for key in devices.keys {
                devices[key]?.updateDeviceStale()
            }
        }
        
        // Start a timer to check for BLE message timeouts
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            messageHandlers.checkForTimeout()
        }
    }
    
    /// Adds a device to the local list.
    /// - parameter device: Add device to list of known devices.
    private func addDevice(device: Device) {
        devices[device.uniqueIdentifier] = device
    }
    
    /// Removes all found devices from the list.
    func clearDevices() {
        devices.removeAll(keepingCapacity: false)
    }
    
    /// Returns list of probes
    /// - returns: List of all known probes.
    public func getProbes() -> [Probe] {
        return Array(devices.values).compactMap { device in
            return device as? Probe
        }
    }
    
    /// Returns list of displays
    /// - returns: List of all kitchen timers
    public func getDisplays() -> [Display] {
        if meatNetEnabled {
            return Array(devices.values).compactMap { device in
                return device as? Display
            }
        } else {
            return []
        }
    }
    
    /// Returns the nearest probe.
    /// - returns: Nearest probe, if any.
    public func getNearestProbe() -> Probe? {
        return getProbes().max{ $0.rssi < $1.rssi }
    }
    
    /// Returns list of devices.
    /// - returns: List of all known devices.
    public func getDevices() -> [Device] {
        return Array(devices.values)
    }
    
    /// Returns the nearest device.
    /// - returns: Nearest device, if any.
    public func getNearestDevice() -> Device? {
        return getDevices().max{ $0.rssi < $1.rssi }
    }
    
    func connectToDevice(_ device: Device) {
        if let _ = device as? SimulatedProbe, let bleIdentifier = device.bleIdentifier, let uuid = UUID(uuidString: bleIdentifier) {
            // If this device is a Simulated Probe, use a simulated connection.
            didConnectTo(identifier: uuid)
        }
        else if let bleIdentifier = device.bleIdentifier {
            // If this device has a BLE identifier (advertisements are directly detected rather than through MeatNet),
            // attempt to connect to it.
            BleManager.shared.connect(identifier: bleIdentifier)
        }
    }
    
    func disconnectFromDevice(_ device: Device) {
        if let _ = device as? SimulatedProbe, let bleIdentifier = device.bleIdentifier, let uuid = UUID(uuidString: bleIdentifier) {
            // If this device is a Simulated Probe, use a simulated disconnect.
            didDisconnectFrom(identifier: uuid)
        }
        else if let bleIdentifier = device.bleIdentifier {
            // If this device has a BLE identifier (advertisements are directly detected rather than through MeatNet),
            // attempt to disconnect from it.
            BleManager.shared.disconnect(identifier: bleIdentifier)
        }
    }
    
    /// Request log messages from the specified device.
    /// - parameter device: Device from which to request messages
    /// - parameter minSequence: Minimum sequence number to request
    /// - parameter maxSequence: Maximum sequence number to request
    func requestLogsFrom(_ device: Device, minSequence: UInt32, maxSequence: UInt32) {
        let request = LogRequest(minSequence: minSequence,
                                 maxSequence: maxSequence)
        // TODO - Request logs via Node.
        if let device = device as? Probe, let bleIdentifier = device.bleIdentifier {
            BleManager.shared.sendRequest(identifier: bleIdentifier, request: request)
        }
    }
    
    /// Set Probe ID on specified device.
    /// - parameter device: Device to set ID on
    /// - parameter ProbeID: New Probe ID
    /// - parameter completionHandler: Completion handler to be called operation is complete
    public func setProbeID(_ device: Device, id: ProbeID, completionHandler: @escaping MessageHandlers.SuccessCompletionHandler) {
        // TODO - Send request via Node.
        
        // Store completion handler
        messageHandlers.addSetIDCompletionHandler(device, completionHandler: completionHandler)
        
        // Send request to device
        if let device = device as? Probe, let bleIdentifier = device.bleIdentifier {
            let request = SetIDRequest(id: id)
            BleManager.shared.sendRequest(identifier: bleIdentifier, request: request)
        }
    }
    
    /// Set Probe Color on specified device.
    /// - parameter device: Device to set Color on
    /// - parameter ProbeColor: New Probe color
    /// - parameter completionHandler: Completion handler to be called operation is complete
    public func setProbeColor(_ device: Device,
                              color: ProbeColor,
                              completionHandler: @escaping MessageHandlers.SuccessCompletionHandler) {
        // TODO - Send request via Node.
        
        // Store completion handler
        messageHandlers.addSetColorCompletionHandler(device, completionHandler: completionHandler)

        // Send request to device
        if let device = device as? Probe, let bleIdentifier = device.bleIdentifier {
            let request = SetColorRequest(color: color)
            BleManager.shared.sendRequest(identifier: bleIdentifier, request: request)
        }
    }
    
    /// Sends a request to the device to set/change the set point temperature for the time to
    /// removal prediction.  If a prediction is not currently active, it will be started.  If a
    /// removal prediction is currently active, then the set point will be modified.  If another
    /// type of prediction is active, then the probe will start predicting removal.
    ///
    /// - parameter device: Device to set prediction on
    /// - parameter removalTemperatureC: the target removal temperature in Celsius
    /// - parameter completionHandler: Completion handler to be called operation is complete
    public func setRemovalPrediction(_ device: Device,
                                     removalTemperatureC: Double,
                                     completionHandler: @escaping MessageHandlers.SuccessCompletionHandler) {
        guard removalTemperatureC < Constants.MAXIMUM_PREDICTION_SETPOINT_CELSIUS,
              removalTemperatureC > Constants.MINIMUM_PREDICTION_SETPOINT_CELSIUS else {
            completionHandler(false)
            return
        }
        // TODO - Send request via Node.
        
        if let device = device as? Probe, let bleIdentifier = device.bleIdentifier {
            // Store completion handler
            messageHandlers.addSetPredictionCompletionHandler(device, completionHandler: completionHandler)
            
            // Send request to device
            let request = SetPredictionRequest(setPointCelsius: removalTemperatureC, mode: .timeToRemoval)
            BleManager.shared.sendRequest(identifier: bleIdentifier, request: request)
        }
    }
    
    
    /// Sends a request to the device to set the prediction mode to none, stopping any active prediction.
    ///
    /// - parameter device: Device to cancel prediction on
    /// - parameter completionHandler: Completion handler to be called operation is complete
    public func cancelPrediction(_ device: Device, completionHandler: @escaping MessageHandlers.SuccessCompletionHandler) {
        // TODO - Send request via Node.
        
        if let device = device as? Probe, let bleIdentifier = device.bleIdentifier {
            // Store completion handler
            messageHandlers.addSetPredictionCompletionHandler(device, completionHandler: completionHandler)
            
            // Send request to device
            let request = SetPredictionRequest(setPointCelsius: 0.0, mode: .none)
            BleManager.shared.sendRequest(identifier: bleIdentifier, request: request)
        }
    }
    
    /// Sends a request to the device to read Over Temperature flag
    ///
    /// - parameter device: Device to read flag from
    /// - parameter completionHandler: Completion handler to be called operation is complete
    public func readOverTemperatureFlag(_ device: Device,
                                        completionHandler: @escaping MessageHandlers.ReadOverTemperatureCompletionHandler) {
        // TODO - Send request via Node.
        
        if let device = device as? Probe, let bleIdentifier = device.bleIdentifier {
            // Store completion handler
            messageHandlers.addReadOverTemperatureCompletionHandler(device, completionHandler: completionHandler)
            
            // Send request to device
            let request = ReadOverTemperatureRequest()
            BleManager.shared.sendRequest(identifier: bleIdentifier, request: request)
        }
    }
    
    /// Set the DFU file to be used on displays with failed software upgrade.
    /// A failed upgrade will occur if the user kills the application in the middle of
    /// the software upgrade process.  After this method is called, DFU will be initiated
    /// when a device with failed software upgrade is detected.
    ///
    /// - displayDFUFile: Display DFU file
    /// - thermometerDFUFile: Thermometer DFU file
    public func restartFailedUpgradesWith(displayDFUFile: URL?, thermometerDFUFile: URL?) {
        DFUManager.shared.setDisplayDFU(displayDFUFile)
        DFUManager.shared.setThermometerDFU( thermometerDFUFile)
    }
}

extension DeviceManager : BleManagerDelegate {
    func didConnectTo(identifier: UUID) {
        guard let device = devices[identifier.uuidString] else { return }
        
        device.updateConnectionState(.connected)
    }
    
    func didFailToConnectTo(identifier: UUID) {
        guard let device = devices[identifier.uuidString] else { return }
        
        device.updateConnectionState(.failed)
    }
    
    func didDisconnectFrom(identifier: UUID) {
        guard let device = devices[identifier.uuidString] else { return }
        
        device.updateConnectionState(.disconnected)
        
        // Clear any pending message handlers
        messageHandlers.clearHandlersForDevice(identifier)
    }
    
    func updateDeviceWithStatus(identifier: UUID, status: ProbeStatus) {
        if let probe = devices[identifier.uuidString] as? Probe {
            probe.updateProbeStatus(deviceStatus: status)
        }
    }
    
    
    /// Searches for or creates a Device record for the Probe represented by specified AdvertisingData.
    /// - param advertising - Advertising data for the specified Probe
    /// - param isConnectable - Whether the Probe is currently connectable (only present if advertising is directly from Probe)
    /// - param rssi - Signal strength to Probe (only present if advertising is directly from Probe)
    /// - param identifier - BLE identifier (only present if advertising is directly from Probe)
    /// - return Probe that was updated or added, if any
    func updateProbeWithAdvertising(advertising: AdvertisingData, isConnectable: Bool?, rssi: NSNumber?, identifier: UUID?) -> Probe? {
        var foundProbe : Probe? = nil
        
        // If this advertising data was from a Probe, attempt to find its Device entry by its serial number.
        if advertising.serialNumber != INVALID_PROBE_SERIAL_NUMBER {
            let uniqueIdentifier = String(advertising.serialNumber)
            if let probe = devices[uniqueIdentifier] as? Probe {
                // If we already have an entry for this Probe, update its information.
                probe.updateWithAdvertising(advertising, isConnectable: isConnectable, RSSI: rssi)
                foundProbe = probe
            } else {
                // If we don't yet have an entry for this Probe, create one.
                let device = Probe(advertising, isConnectable: isConnectable, RSSI: rssi, identifier: identifier)
                addDevice(device: device)
                foundProbe = device
            }
        }
        
        return foundProbe
    }
    
    /// Determines which Device to create/update based on received AdvertisingData.
    /// - param advertising - Advertising data for the specified Probe
    /// - param isConnectable - Whether the advertising device is currently connectable
    /// - param rssi - Signal strength to advertising device
    /// - param identifier - BLE identifier of advertising device
    func updateDeviceWithAdvertising(advertising: AdvertisingData, isConnectable: Bool, rssi: NSNumber, identifier: UUID) {
        switch(advertising.type) {
        case .probe:
            let _ = updateProbeWithAdvertising(advertising: advertising, isConnectable: isConnectable, rssi: rssi, identifier: identifier)
            
        case .display:
            // If this advertising data was from a Node, attempt to find its Device entry by its BLE identifier.
            if(meatNetEnabled) {
                let uniqueIdentifier = identifier.uuidString
                if let node = devices[uniqueIdentifier] as? MeatNetNode {
                    node.updateWithAdvertising(advertising, isConnectable: isConnectable, RSSI: rssi)
                    
                    // Also update the probe associated with this advertising data
                    if let probe = updateProbeWithAdvertising(advertising: advertising, isConnectable: nil, rssi: nil, identifier: nil) {
                        node.updateNetworkedProbe(probe: probe)
                    }
                    
                } else {
                    let node = Display(advertising, isConnectable: isConnectable, RSSI: rssi, identifier: identifier)
                    addDevice(device: node)
                    
                    // Also update the probe associated with this advertising data
                    if let probe = updateProbeWithAdvertising(advertising: advertising, isConnectable: nil, rssi: nil, identifier: nil) {
                        node.updateNetworkedProbe(probe: probe)
                    }
                }
            }
            
        case .unknown:
            print("Found device with unknown type")
            
        }
    }
    
    func updateDeviceFwVersion(identifier: UUID, fwVersion: String) {
        if let device = devices[identifier.uuidString]  {
            device.firmareVersion = fwVersion
            
            // TODO : remove this at some point
            // Prior to v0.8.0, the firmware did not support the Session ID command
            // Therefore, add a hardcoded session for backwards compatibility
            if(Version.isBefore(deviceFirmware: fwVersion, comparison: "v0.8.0")) {
                let fakeSessionInfo = SessionInformation(sessionID: 0, samplePeriod: 1000)
                updateDeviceWithSessionInformation(identifier: identifier, sessionInformation: fakeSessionInfo)
            }
        }
    }
    
    func updateDeviceSerialNumber(identifier: UUID, serialNumber: String) {
        if let timer = devices[identifier.uuidString] as? Display {
            timer.serialNumberString = serialNumber
        }
    }
    
    func updateDeviceHwRevision(identifier: UUID, hwRevision: String) {
        if let device = devices[identifier.uuidString]  {
            device.hardwareRevision = hwRevision
        }
    }
    
    func handleUARTResponse(identifier: UUID, response: Response) {
        if let logResponse = response as? LogResponse {
            updateDeviceWithLogResponse(identifier: identifier, logResponse: logResponse)
        }
        else if let setIDResponse = response as? SetIDResponse {
            messageHandlers.callSetIDCompletionHandler(identifier, response: setIDResponse)
        }
        else if let setColorResponse = response as? SetColorResponse {
            messageHandlers.callSetColorCompletionHandler(identifier, response: setColorResponse)
        }
        else if let sessionResponse = response as? SessionInfoResponse {
            if(sessionResponse.success) {
                updateDeviceWithSessionInformation(identifier: identifier, sessionInformation: sessionResponse.info)
            }
        }
        else if let setPredictionResponse = response as? SetPredictionResponse {
            messageHandlers.callSetPredictionCompletionHandler(identifier, response: setPredictionResponse)
        }
        else if let readOverTemperatureResponse = response as? ReadOverTemperatureResponse {
            messageHandlers.callReadOverTemperatureCompletionHandler(identifier, response: readOverTemperatureResponse)
        }
    }
    
    private func updateDeviceWithLogResponse(identifier: UUID, logResponse: LogResponse) {
        guard logResponse.success else { return }
        
        if let probe = devices[identifier.uuidString] as? Probe {
            probe.processLogResponse(logResponse: logResponse)
        }
    }
    
    private func updateDeviceWithSessionInformation(identifier: UUID, sessionInformation: SessionInformation) {
        if let probe = devices[identifier.uuidString] as? Probe {
            probe.updateWithSessionInformation(sessionInformation)
        }
    }
}
