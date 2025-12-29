package com.example.muse_headband_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.choosemuse.libmuse.*
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.museheadband/muse_commands"
    private val SCAN_CHANNEL = "com.museheadband/scan_stream"
    private val EEG_CHANNEL = "com.museheadband/eeg_stream"
    private val BAND_POWER_CHANNEL = "com.museheadband/bandpower_stream"
    private val IMU_CHANNEL = "com.museheadband/imu_stream"
    private val FNIRS_CHANNEL = "com.museheadband/fnirs_stream"
    private val HSI_CHANNEL = "com.museheadband/hsi_stream"
    private val BATTERY_CHANNEL = "com.museheadband/battery_stream"
    
    private lateinit var museManager: MuseManagerAndroid
    private val connectedMuses = mutableMapOf<String, Muse>()
    
    // Event Sinks
    private var scanEventSink: EventChannel.EventSink? = null
    private var eegEventSink: EventChannel.EventSink? = null
    private var bandPowerEventSink: EventChannel.EventSink? = null
    private var imuEventSink: EventChannel.EventSink? = null
    private var fnirsEventSink: EventChannel.EventSink? = null
    private var hsiEventSink: EventChannel.EventSink? = null
    private var batteryEventSink: EventChannel.EventSink? = null
    
    // Band power accumulator per device
    private val bandPowerBuffers = mutableMapOf<String, MutableMap<String, Double>>()

    // HSI state per device
    // Map<DeviceId, Map<ChannelName, Map<Key, Value>>>
    private val deviceHsiState = mutableMapOf<String, MutableMap<String, MutableMap<String, Any>>>()
    
    // Listener for Muse list changes
    private val museListener = object : MuseListener() {
        override fun museListChanged() {
            val muses = museManager.getMuses()
            Log.d("MuseSDK", "Muse list changed. Found ${muses.size} devices.")
            muses.forEach { muse ->
                Log.d("MuseSDK", "Discovered: ${muse.getName()} - ${muse.getMacAddress()}")
                val deviceData = mapOf(
                    "id" to muse.getMacAddress(),
                    "name" to muse.getName(),
                    "battery" to 0.0  // Placeholder, real battery comes from BATTERY packet
                )
                runOnUiThread {
                    scanEventSink?.success(deviceData)
                }
            }
        }
    }

    // Listener for connection state changes
    private val connectionListener = object : MuseConnectionListener() {
        override fun receiveMuseConnectionPacket(packet: MuseConnectionPacket, muse: Muse?) {
            Log.d("MuseSDK", "Connection state: ${packet.currentConnectionState}")
        }
    }

    // Listener for data packets
    private val dataListener = object : MuseDataListener() {
        override fun receiveMuseDataPacket(packet: MuseDataPacket, muse: Muse?) {
            val deviceId = muse?.getMacAddress() ?: "unknown"
            val timestamp = System.currentTimeMillis()

            when (packet.packetType()) {
                MuseDataPacketType.EEG -> {
                    // ... (Existing EEG handling)
                    val data = mapOf(
                        "deviceId" to deviceId,
                        "timestamp" to timestamp,
                        "tp9" to packet.getEegChannelValue(Eeg.EEG1),
                        "af7" to packet.getEegChannelValue(Eeg.EEG2),
                        "af8" to packet.getEegChannelValue(Eeg.EEG3),
                        "tp10" to packet.getEegChannelValue(Eeg.EEG4),
                        "drl" to packet.getEegChannelValue(Eeg.AUX_LEFT),
                        "ref" to packet.getEegChannelValue(Eeg.AUX_RIGHT)
                    )
                    runOnUiThread { eegEventSink?.success(data) }
                }
                MuseDataPacketType.ALPHA_ABSOLUTE -> accumulateBandPower(deviceId, timestamp, packet, "alpha_absolute")
                MuseDataPacketType.BETA_ABSOLUTE -> accumulateBandPower(deviceId, timestamp, packet, "beta_absolute")
                MuseDataPacketType.DELTA_ABSOLUTE -> accumulateBandPower(deviceId, timestamp, packet, "delta_absolute")
                MuseDataPacketType.THETA_ABSOLUTE -> accumulateBandPower(deviceId, timestamp, packet, "theta_absolute")
                MuseDataPacketType.GAMMA_ABSOLUTE -> accumulateBandPower(deviceId, timestamp, packet, "gamma_absolute")
                MuseDataPacketType.ALPHA_RELATIVE -> accumulateBandPower(deviceId, timestamp, packet, "alpha_relative")
                MuseDataPacketType.BETA_RELATIVE -> accumulateBandPower(deviceId, timestamp, packet, "beta_relative")
                MuseDataPacketType.DELTA_RELATIVE -> accumulateBandPower(deviceId, timestamp, packet, "delta_relative")
                MuseDataPacketType.THETA_RELATIVE -> accumulateBandPower(deviceId, timestamp, packet, "theta_relative")
                MuseDataPacketType.GAMMA_RELATIVE -> {
                    accumulateBandPower(deviceId, timestamp, packet, "gamma_relative")
                    flushBandPowerBuffer(deviceId, timestamp)
                }
                MuseDataPacketType.ACCELEROMETER -> {
                    val data = mapOf(
                        "deviceId" to deviceId,
                        "timestamp" to timestamp,
                        "accel_x" to packet.getAccelerometerValue(Accelerometer.X),
                        "accel_y" to packet.getAccelerometerValue(Accelerometer.Y),
                        "accel_z" to packet.getAccelerometerValue(Accelerometer.Z)
                    )
                    runOnUiThread { imuEventSink?.success(data) }
                }
                MuseDataPacketType.GYRO -> {
                    val data = mapOf(
                        "deviceId" to deviceId,
                        "timestamp" to timestamp,
                        "gyro_x" to packet.getGyroValue(Gyro.X),
                        "gyro_y" to packet.getGyroValue(Gyro.Y),
                        "gyro_z" to packet.getGyroValue(Gyro.Z)
                    )
                    runOnUiThread { imuEventSink?.success(data) }
                }
                MuseDataPacketType.PPG -> {
                    // ... (Existing PPG handling)
                    val values = packet.values()
                    val data = mapOf(
                        "deviceId" to deviceId,
                        "timestamp" to timestamp,
                        "ppg0" to values.getOrNull(0)?.toDouble(),
                        "ppg1" to values.getOrNull(1)?.toDouble(),
                        "ppg2" to values.getOrNull(2)?.toDouble(),
                        "ppg3" to values.getOrNull(3)?.toDouble(),
                        "ppg4" to values.getOrNull(4)?.toDouble(),
                        "ppg5" to values.getOrNull(5)?.toDouble()
                    )
                    runOnUiThread { fnirsEventSink?.success(data) }
                }
                MuseDataPacketType.HSI_PRECISION -> {
                    updateHsiState(deviceId, packet, isArtifactPacket = false)
                }
                MuseDataPacketType.IS_GOOD -> {
                    updateHsiState(deviceId, packet, isArtifactPacket = true)
                }
                MuseDataPacketType.BATTERY -> {
                    val batteryLevel = packet.getBatteryValue(Battery.CHARGE_PERCENTAGE_REMAINING)
                    Log.d("MuseSDK", "Battery level for $deviceId: $batteryLevel")
                    // Send as simple int or map? 
                    // Existing Dart code expects int stream for battery... 
                    // BUT we need deviceId to route it correctly in our new single-stream architecture!
                    // Let's check MusePlatformRepository.subscribeToBattery...
                    // It uses _platformChannel.getBatteryStream(deviceId).
                    // Wait, if we use single global stream, we should send a Map with deviceId.
                    // However, the current Dart implementation for battery is still PER-DEVICE:
                    // Stream<int> subscribeToBattery(String deviceId) { ... getBatteryStream(deviceId) ... }
                    // So we should probably keep sending just the int to the specific channel if we can?
                    // NO, we can't easily dynamically create channels per device in this setup.
                    // We should switch Battery to Global Stream pattern too.
                    
                    // For now, let's try to send it to the global battery channel as a Map, 
                    // and I will update the Dart side to handle it.
                    val data = mapOf(
                        "deviceId" to deviceId,
                        "level" to batteryLevel.toInt()
                    )
                    runOnUiThread { batteryEventSink?.success(data) }
                }
                else -> { }
            }
        }

        override fun receiveMuseArtifactPacket(packet: MuseArtifactPacket, muse: Muse?) {
            // Handle artifacts
        }
    }

    private fun updateHsiState(deviceId: String, packet: MuseDataPacket, isArtifactPacket: Boolean) {
        if (!deviceHsiState.containsKey(deviceId)) {
            deviceHsiState[deviceId] = mutableMapOf(
                "TP9" to mutableMapOf("value" to 4, "artifact_free" to false),
                "AF7" to mutableMapOf("value" to 4, "artifact_free" to false),
                "AF8" to mutableMapOf("value" to 4, "artifact_free" to false),
                "TP10" to mutableMapOf("value" to 4, "artifact_free" to false)
            )
        }

        val state = deviceHsiState[deviceId]!!
        
        // HSI_PRECISION: 1=Good, 2=Medium, 4=Bad
        // IS_GOOD: 1=Good (Artifact Free), 0=Bad (Artifact/Noise)
        
        if (isArtifactPacket) { // IS_GOOD packet
             // IS_GOOD values: 1=Good, 0=Bad
             state["TP9"]!!["artifact_free"] = packet.getEegChannelValue(Eeg.EEG1) == 1.0
             state["AF7"]!!["artifact_free"] = packet.getEegChannelValue(Eeg.EEG2) == 1.0
             state["AF8"]!!["artifact_free"] = packet.getEegChannelValue(Eeg.EEG3) == 1.0
             state["TP10"]!!["artifact_free"] = packet.getEegChannelValue(Eeg.EEG4) == 1.0
        } else { // HSI_PRECISION packet
             state["TP9"]!!["value"] = packet.getEegChannelValue(Eeg.EEG1).toInt()
             state["AF7"]!!["value"] = packet.getEegChannelValue(Eeg.EEG2).toInt()
             state["AF8"]!!["value"] = packet.getEegChannelValue(Eeg.EEG3).toInt()
             state["TP10"]!!["value"] = packet.getEegChannelValue(Eeg.EEG4).toInt()
        }

        // Send update
        val data = mutableMapOf<String, Any>("deviceId" to deviceId)
        data.putAll(state)
        runOnUiThread { hsiEventSink?.success(data) }
    }

    private fun accumulateBandPower(deviceId: String, timestamp: Long, packet: MuseDataPacket, type: String) {
        if (!bandPowerBuffers.containsKey(deviceId)) {
            bandPowerBuffers[deviceId] = mutableMapOf()
        }
        
        val buffer = bandPowerBuffers[deviceId]!!
        val values = packet.values()
        
        // Log.d("MuseSDK", "Band Power $type - values.size: ${values.size}")
        if (values.size >= 4) {
            val v0 = values[0].toDouble()
            val v1 = values[1].toDouble()
            val v2 = values[2].toDouble()
            val v3 = values[3].toDouble()
            // Log.d("MuseSDK", "Band Power $type values: [$v0, $v1, $v2, $v3]")
            buffer["tp9_$type"] = v0
            buffer["af7_$type"] = v1
            buffer["af8_$type"] = v2
            buffer["tp10_$type"] = v3
        }
    }

    private fun flushBandPowerBuffer(deviceId: String, timestamp: Long) {
        val buffer = bandPowerBuffers[deviceId]
        // Log.d("MuseSDK", "Flushing Band Power buffer - size: ${buffer?.size ?: 0}")
        if (buffer != null && buffer.isNotEmpty()) {  // Flush any available data
            val data = mutableMapOf<String, Any>(
                "deviceId" to deviceId,
                "timestamp" to timestamp
            )
            data.putAll(buffer)
            
            // Log.d("MuseSDK", "Sending Band Power data to Dart: ${buffer.keys.joinToString(", ")}")
            runOnUiThread { bandPowerEventSink?.success(data) }
            buffer.clear()
        } else {
            // Log.w("MuseSDK", "Band Power buffer is empty or null, not flushing")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        museManager = MuseManagerAndroid.getInstance()
        museManager.setContext(this)
        museManager.setMuseListener(museListener)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scan" -> {
                    museManager.stopListening()
                    museManager.startListening()
                    result.success(null)
                }
                "stopScan" -> {
                    museManager.stopListening()
                    result.success(null)
                }
                "connect" -> {
                    val deviceId = call.argument<String>("deviceId")
                    if (deviceId != null) {
                        val muse = museManager.getMuses().find { it.getMacAddress() == deviceId }
                        if (muse != null) {
                            muse.unregisterAllListeners()
                            muse.registerConnectionListener(connectionListener)
                            
                            // Register for EEG and Band Powers
                            muse.registerDataListener(dataListener, MuseDataPacketType.EEG)
                            muse.registerDataListener(dataListener, MuseDataPacketType.ALPHA_ABSOLUTE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.BETA_ABSOLUTE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.DELTA_ABSOLUTE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.THETA_ABSOLUTE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.GAMMA_ABSOLUTE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.ALPHA_RELATIVE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.BETA_RELATIVE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.DELTA_RELATIVE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.THETA_RELATIVE)
                            muse.registerDataListener(dataListener, MuseDataPacketType.GAMMA_RELATIVE)
                            
                            // Register for IMU (Accelerometer + Gyroscope)
                            muse.registerDataListener(dataListener, MuseDataPacketType.ACCELEROMETER)
                            muse.registerDataListener(dataListener, MuseDataPacketType.GYRO)
                            
                            // Register for fNIRS/PPG (Muse S Athena only - will be ignored on other models)
                            muse.registerDataListener(dataListener, MuseDataPacketType.PPG)

                            // Register for HSI and Artifacts
                            muse.registerDataListener(dataListener, MuseDataPacketType.HSI_PRECISION)
                            muse.registerDataListener(dataListener, MuseDataPacketType.IS_GOOD)

                            // Register for Battery
                            muse.registerDataListener(dataListener, MuseDataPacketType.BATTERY)
                            
                            // Initialize band power buffer
                            bandPowerBuffers[deviceId] = mutableMapOf()
                            
                            // Set preset based on device model
                            // Muse S (MU_03) supports PPG (fNIRS) -> PRESET_22
                            // Muse 2 (MU_02) and older -> PRESET_21
                            val model = muse.getModel()
                            Log.d("MuseSDK", "Device Model: $model")
                            
                            if (model == MuseModel.MU_03) {
                                Log.d("MuseSDK", "Setting PRESET_22 for Muse S (PPG enabled)")
                                muse.setPreset(MusePreset.PRESET_22)
                            } else {
                                Log.d("MuseSDK", "Setting PRESET_21 for Muse 2/Older (No PPG)")
                                muse.setPreset(MusePreset.PRESET_21)
                            }
                            
                            muse.runAsynchronously()
                            connectedMuses[deviceId] = muse
                            result.success(null)
                        } else {
                            result.error("DEVICE_NOT_FOUND", "Device not found", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "deviceId required", null)
                    }
                }
                "disconnect" -> {
                    val deviceId = call.argument<String>("deviceId")
                    connectedMuses[deviceId]?.disconnect()
                    connectedMuses.remove(deviceId)
                    bandPowerBuffers.remove(deviceId)
                    deviceHsiState.remove(deviceId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { scanEventSink = events }
                override fun onCancel(arguments: Any?) { scanEventSink = null }
            }
        )
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EEG_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eegEventSink = events }
                override fun onCancel(arguments: Any?) { eegEventSink = null }
            }
        )
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BAND_POWER_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { bandPowerEventSink = events }
                override fun onCancel(arguments: Any?) { bandPowerEventSink = null }
            }
        )
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, IMU_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { imuEventSink = events }
                override fun onCancel(arguments: Any?) { imuEventSink = null }
            }
        )
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FNIRS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { fnirsEventSink = events }
                override fun onCancel(arguments: Any?) { fnirsEventSink = null }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, HSI_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { hsiEventSink = events }
                override fun onCancel(arguments: Any?) { hsiEventSink = null }
            }
        )

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { batteryEventSink = events }
                override fun onCancel(arguments: Any?) { batteryEventSink = null }
            }
        )
    }
    
    override fun onDestroy() {
        super.onDestroy()
        connectedMuses.values.forEach { it.disconnect() }
        museManager.stopListening()
    }
}
