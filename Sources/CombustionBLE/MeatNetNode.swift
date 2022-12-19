//  MeatNetNode.swift

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

/// Representation of a Node on the MeatNet BLE repeater network. Various products
/// can be a MeatNet Node.
public class MeatNetNode: Device {
    
    /// Serial Number
    @Published public internal(set) var serialNumberString: String?
    
    /// Dictionary of Probes connected to this Node's Network
    @Published public var probes: [UInt32 : Probe] = [:]
    
    
    init(_ advertising: AdvertisingData, isConnectable: Bool, RSSI: NSNumber, identifier: UUID) {
        super.init(uniqueIdentifier: identifier.uuidString, bleIdentifier: identifier, RSSI: RSSI)
        updateWithAdvertising(advertising, isConnectable: isConnectable, RSSI: RSSI)
    }
    
    
    func updateWithAdvertising(_ advertising: AdvertisingData, isConnectable: Bool, RSSI: NSNumber) {
        // Always update probe RSSI and isConnectable flag
        self.rssi = RSSI.intValue
        self.isConnectable = isConnectable
        
    }
    
    /// Adds Probe to dictionary of networked Probes, if not already present.
    func updateNetworkedProbe(probe : Probe) {
        probes[probe.serialNumber] = probe
    }


}
