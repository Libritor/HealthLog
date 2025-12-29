import Flutter
import UIKit
import CoreBluetooth

// Note: You must add Muse.framework to your Xcode project's "Frameworks, Libraries, and Embedded Content"
// and ensure "Embed & Sign" is selected.
// Since I cannot edit the Xcode project file directly to link the framework, 
// I am writing this code assuming the user will perform the linking step.

// We need to import the Muse framework. 
// If this fails to compile, it means the framework is not linked correctly in Xcode.
import Muse

class MuseManager: NSObject, MuseListener, MuseConnectionListener, MuseDataListener {
    
    private var manager: MuseManagerIos?
    private var connectedMuses = [String: Muse]()
    
    // Flutter Sinks
    var scanSink: FlutterEventSink?
    var eegSink: FlutterEventSink?
    var bandPowerSink: FlutterEventSink?
    var imuSink: FlutterEventSink?
    var fnirsSink: FlutterEventSink?
    var hsiSink: FlutterEventSink?
    var batterySink: FlutterEventSink?
    
    // Band Power Buffers: [DeviceId: [MetricName: Value]]
    private var bandPowerBuffers = [String: [String: Double]]()
    
    // HSI State: [DeviceId: [Channel: [Key: Value]]]
    private var deviceHsiState = [String: [String: [String: Any]]]()
    
    override init() {
        super.init()
        self.manager = MuseManagerIos.sharedManager()
        self.manager?.setMuseListener(self)
    }
    
    func startScan() {
        print("MuseManager: Starting scan")
        self.manager?.stopListening()
        self.manager?.startListening()
    }
    
    func stopScan() {
        print("MuseManager: Stopping scan")
        self.manager?.stopListening()
    }
    
    func connect(deviceId: String) {
        let muses = self.manager?.getMuses() ?? []
        if let muse = muses.first(where: { $0.getMacAddress() == deviceId }) {
            print("MuseManager: Connecting to \(deviceId)")
            
            muse.unregisterAllListeners()
            muse.register(self, type: .connection)
            
            // Register Data Listeners
            muse.register(self, type: .eeg)
            // Absolute band powers
            muse.register(self, type: .alphaAbsolute)
            muse.register(self, type: .betaAbsolute)
            muse.register(self, type: .deltaAbsolute)
            muse.register(self, type: .thetaAbsolute)
            muse.register(self, type: .gammaAbsolute)
            // Relative band powers
            muse.register(self, type: .alphaRelative)
            muse.register(self, type: .betaRelative)
            muse.register(self, type: .deltaRelative)
            muse.register(self, type: .thetaRelative)
            muse.register(self, type: .gammaRelative)
            muse.register(self, type: .accelerometer)
            muse.register(self, type: .gyro)
            muse.register(self, type: .ppg)
            muse.register(self, type: .hsiPrecision)
            muse.register(self, type: .isGood)
            muse.register(self, type: .battery)
            
            // Initialize buffers
            bandPowerBuffers[deviceId] = [:]
            
            // Set Preset
            // Note: Muse iOS SDK might handle presets differently or automatically.
            // We'll try to set it if possible, otherwise rely on default.
            // muse.setPreset(.preset22) // Example if available
            
            muse.runAsynchronously()
            connectedMuses[deviceId] = muse
        } else {
            print("MuseManager: Device \(deviceId) not found")
        }
    }
    
    func disconnect(deviceId: String) {
        if let muse = connectedMuses[deviceId] {
            muse.disconnect()
            connectedMuses.removeValue(forKey: deviceId)
            bandPowerBuffers.removeValue(forKey: deviceId)
            deviceHsiState.removeValue(forKey: deviceId)
        }
    }
    
    // MARK: - MuseListener
    
    func museListChanged() {
        let muses = self.manager?.getMuses() ?? []
        for muse in muses {
            let data: [String: Any] = [
                "id": muse.getMacAddress() ?? "unknown",
                "name": muse.getName() ?? "Muse",
                "battery": 0.0
            ]
            scanSink?(data)
        }
    }
    
    // MARK: - MuseConnectionListener
    
    func receive(_ packet: MuseConnectionPacket, muse: Muse?) {
        print("MuseManager: Connection state changed: \(packet.currentConnectionState)")
    }
    
    // MARK: - MuseDataListener
    
    func receive(_ packet: MuseDataPacket, muse: Muse?) {
        guard let muse = muse, let deviceId = muse.getMacAddress() else { return }
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        
        switch packet.packetType() {
        case .eeg:
            let data: [String: Any] = [
                "deviceId": deviceId,
                "timestamp": timestamp,
                "tp9": packet.getEegChannelValue(.eeg1),
                "af7": packet.getEegChannelValue(.eeg2),
                "af8": packet.getEegChannelValue(.eeg3),
                "tp10": packet.getEegChannelValue(.eeg4),
                "drl": packet.getEegChannelValue(.auxLeft),
                "ref": packet.getEegChannelValue(.auxRight)
            ]
            eegSink?(data)
            
        case .alphaAbsolute: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "alpha_absolute")
        case .betaAbsolute: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "beta_absolute")
        case .deltaAbsolute: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "delta_absolute")
        case .thetaAbsolute: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "theta_absolute")
        case .gammaAbsolute: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "gamma_absolute")
        case .alphaRelative: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "alpha_relative")
        case .betaRelative: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "beta_relative")
        case .deltaRelative: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "delta_relative")
        case .thetaRelative: accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "theta_relative")
        case .gammaRelative:
            accumulateBandPower(deviceId: deviceId, timestamp: timestamp, packet: packet, type: "gamma_relative")
            // Flush after receiving the last band power type
            flushBandPowerBuffer(deviceId: deviceId, timestamp: timestamp)
            
        case .accelerometer:
            let data: [String: Any] = [
                "deviceId": deviceId,
                "timestamp": timestamp,
                "accel_x": packet.getAccelerometerValue(.x),
                "accel_y": packet.getAccelerometerValue(.y),
                "accel_z": packet.getAccelerometerValue(.z)
            ]
            imuSink?(data)
            
        case .gyro:
            let data: [String: Any] = [
                "deviceId": deviceId,
                "timestamp": timestamp,
                "gyro_x": packet.getGyroValue(.x),
                "gyro_y": packet.getGyroValue(.y),
                "gyro_z": packet.getGyroValue(.z)
            ]
            imuSink?(data)
            
        case .ppg:
            // PPG values are usually an array
            // Note: Swift SDK might expose values differently.
            // Assuming packet.values() returns [Double] or similar
            // We'll need to check the exact API. For now assuming standard access.
            // If packet.values() is not available, we might need to use getPpgChannelValue
            
            // Let's try to get raw values if possible, or map channels
            // Muse S has 3 PPG channels (Ambient, IR, Red) usually?
            // Or 6 if using multiple sensors?
            // The Android code mapped 6 values.
            // Let's assume we can get them by index if the API supports it.
            // If not, we might need to look at header.
            
            // Placeholder for PPG extraction
            let data: [String: Any] = [
                "deviceId": deviceId,
                "timestamp": timestamp,
                // "ppg0": ...
            ]
            fnirsSink?(data)
            
        case .battery:
            let level = packet.getBatteryValue(.chargePercentageRemaining)
            let data: [String: Any] = [
                "deviceId": deviceId,
                "level": Int(level)
            ]
            batterySink?(data)
            
        case .hsiPrecision:
            updateHsiState(deviceId: deviceId, packet: packet, isArtifact: false)
            
        case .isGood:
            updateHsiState(deviceId: deviceId, packet: packet, isArtifact: true)
            
        default:
            break
        }
    }
    
    func receive(_ packet: MuseArtifactPacket, muse: Muse?) {
        // Handle artifacts
    }
    
    // MARK: - Helpers
    
    private func accumulateBandPower(deviceId: String, timestamp: Int64, packet: MuseDataPacket, type: String) {
        if bandPowerBuffers[deviceId] == nil { bandPowerBuffers[deviceId] = [:] }
        
        // Assuming packet.getEegChannelValue works for band powers mapped to EEG channels
        // or we need to access values by index.
        // Android used values[0]..values[3]
        
        // Let's try to access by index if possible, or map to EEG1..EEG4
        let v0 = packet.getEegChannelValue(.eeg1)
        let v1 = packet.getEegChannelValue(.eeg2)
        let v2 = packet.getEegChannelValue(.eeg3)
        let v3 = packet.getEegChannelValue(.eeg4)
        
        bandPowerBuffers[deviceId]?["tp9_\(type)"] = v0
        bandPowerBuffers[deviceId]?["af7_\(type)"] = v1
        bandPowerBuffers[deviceId]?["af8_\(type)"] = v2
        bandPowerBuffers[deviceId]?["tp10_\(type)"] = v3
        
        // Flush is now handled in the gammaRelative case handler
    }
    
    private func flushBandPowerBuffer(deviceId: String, timestamp: Int64) {
        guard let buffer = bandPowerBuffers[deviceId], !buffer.isEmpty else { return }
        
        var data: [String: Any] = [
            "deviceId": deviceId,
            "timestamp": timestamp
        ]
        data.merge(buffer) { (_, new) in new }
        
        bandPowerSink?(data)
        bandPowerBuffers[deviceId]?.removeAll()
    }
    
    private func updateHsiState(deviceId: String, packet: MuseDataPacket, isArtifact: Bool) {
        if deviceHsiState[deviceId] == nil {
            deviceHsiState[deviceId] = [
                "TP9": ["value": 4, "artifact_free": false],
                "AF7": ["value": 4, "artifact_free": false],
                "AF8": ["value": 4, "artifact_free": false],
                "TP10": ["value": 4, "artifact_free": false]
            ]
        }
        
        if isArtifact {
            deviceHsiState[deviceId]?["TP9"]?["artifact_free"] = packet.getEegChannelValue(.eeg1) == 1.0
            deviceHsiState[deviceId]?["AF7"]?["artifact_free"] = packet.getEegChannelValue(.eeg2) == 1.0
            deviceHsiState[deviceId]?["AF8"]?["artifact_free"] = packet.getEegChannelValue(.eeg3) == 1.0
            deviceHsiState[deviceId]?["TP10"]?["artifact_free"] = packet.getEegChannelValue(.eeg4) == 1.0
        } else {
            deviceHsiState[deviceId]?["TP9"]?["value"] = Int(packet.getEegChannelValue(.eeg1))
            deviceHsiState[deviceId]?["AF7"]?["value"] = Int(packet.getEegChannelValue(.eeg2))
            deviceHsiState[deviceId]?["AF8"]?["value"] = Int(packet.getEegChannelValue(.eeg3))
            deviceHsiState[deviceId]?["TP10"]?["value"] = Int(packet.getEegChannelValue(.eeg4))
        }
        
        var data: [String: Any] = ["deviceId": deviceId]
        data.merge(deviceHsiState[deviceId]!) { (_, new) in new }
        hsiSink?(data)
    }
}
