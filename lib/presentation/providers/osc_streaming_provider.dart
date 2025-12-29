import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/muse/osc_service.dart';
import '../../domain/models/band_power_sample.dart';
import 'device_provider.dart';

/// Provider for the OSC Streaming Manager
final oscStreamingManagerProvider = Provider<OscStreamingManager>((ref) {
  return OscStreamingManager(ref);
});

class OscStreamingManager {
  final Ref ref;
  final Map<String, StreamSubscription> _subscriptions = {};

  OscStreamingManager(this.ref) {
    // Listen to streaming toggle
    ref.listen(isOscStreamingProvider, (previous, isStreaming) {
      if (isStreaming) {
        _startStreaming();
      } else {
        _stopStreaming();
      }
    });
  }

  void _startStreaming() {
    final connectedDevices = ref.read(connectedDevicesProvider);
    final deviceIds = connectedDevices.keys.toList();
    
    // Subscribe to all connected devices with person mapping
    for (int i = 0; i < deviceIds.length; i++) {
      _subscribeToDevice(deviceIds[i], i);
    }
  }

  void _stopStreaming() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Subscribe to a device's band power stream and send OSC messages
  /// 
  /// [deviceId] - The device identifier
  /// [deviceIndex] - The device index (0 = Person 1, 1 = Person 2, etc.)
  void _subscribeToDevice(String deviceId, int deviceIndex) {
    if (_subscriptions.containsKey(deviceId)) return;

    final oscService = ref.read(oscServiceProvider);
    
    // ============================================================================
    // 🎯 TARGET IP CONFIGURATION
    // ============================================================================
    // The target IP address is read from oscTargetIpProvider (default: '192.168.1.100')
    // Change this in the UI (OSC Settings dialog) or modify the default in osc_service.dart
    // ============================================================================
    
    // Subscribe to Band Powers
    final sub = ref.read(bandPowerStreamProvider(deviceId).stream).listen((sample) {
      // ============================================================================
      // 🎯 READING TARGET IP FROM PROVIDER
      // ============================================================================
      // This is where your PC/VR IP address is retrieved
      final targetIp = ref.read(oscTargetIpProvider);
      
      // Determine which person this device represents
      // Person 1 (index 0) → Port 5000, OSC address /person1/eeg
      // Person 2 (index 1) → Port 5001, OSC address /person2/eeg
      final int targetPort;
      final String oscAddress;
      
      if (deviceIndex == 0) {
        // First device = Person 1
        targetPort = 5000;
        oscAddress = '/person1/eeg';
      } else if (deviceIndex == 1) {
        // Second device = Person 2
        targetPort = 5001;
        oscAddress = '/person2/eeg';
      } else {
        // Additional devices (if any) - fallback to multi-port from provider
        final targetPorts = ref.read(oscTargetPortsProvider);
        targetPort = targetPorts.isNotEmpty ? targetPorts[deviceIndex % targetPorts.length] : 5000;
        oscAddress = '/person${deviceIndex + 1}/eeg';
      }

      // ============================================================================
      // 🎯 EXTRACTING AND AVERAGING BAND POWER VALUES
      // ============================================================================
      // This is where the band power values from your Muse headband are processed
      // We average across all 4 EEG channels (TP9, AF7, AF8, TP10)
      final bandPowers = _calculateAveragedBandPowers(sample);
      // bandPowers = [deltaAvg, thetaAvg, alphaAvg, betaAvg]
      
      // ============================================================================
      // 🎯 SENDING OSC MESSAGE
      // ============================================================================
      // Format: [delta, theta, alpha, beta] sent to targetIp:targetPort
      // with OSC address /person1/eeg or /person2/eeg
      oscService.send(
        oscAddress,
        bandPowers,
        targetIp,
        targetPort,
      );

    }, onError: (e) {
      print('Error streaming OSC for $deviceId: $e');
    });

    _subscriptions[deviceId] = sub;
  }
  
  /// Calculate averaged band powers across all 4 EEG channels
  /// 
  /// Returns a list of 4 floats: [delta, theta, alpha, beta]
  /// All values are ABSOLUTE band powers (not relative)
  List<double> _calculateAveragedBandPowers(BandPowerSample sample) {
    // ============================================================================
    // 🎯 BAND POWER AVERAGING CALCULATION
    // ============================================================================
    // Each band (delta, theta, alpha, beta) is averaged across 4 channels:
    // TP9 (left ear), AF7 (left forehead), AF8 (right forehead), TP10 (right ear)
    // ============================================================================
    
    // Delta band (0.5-4 Hz) - deep sleep, unconscious processes
    final deltaAvg = (sample.tp9.deltaAbsolute + 
                      sample.af7.deltaAbsolute + 
                      sample.af8.deltaAbsolute + 
                      sample.tp10.deltaAbsolute) / 4.0;
    
    // Theta band (4-8 Hz) - meditation, creativity, intuition
    final thetaAvg = (sample.tp9.thetaAbsolute + 
                      sample.af7.thetaAbsolute + 
                      sample.af8.thetaAbsolute + 
                      sample.tp10.thetaAbsolute) / 4.0;
    
    // Alpha band (8-13 Hz) - relaxation, calmness, flow state
    final alphaAvg = (sample.tp9.alphaAbsolute + 
                      sample.af7.alphaAbsolute + 
                      sample.af8.alphaAbsolute + 
                      sample.tp10.alphaAbsolute) / 4.0;
    
    // Beta band (13-30 Hz) - focus, alertness, active thinking
    final betaAvg = (sample.tp9.betaAbsolute + 
                     sample.af7.betaAbsolute + 
                     sample.af8.betaAbsolute + 
                     sample.tp10.betaAbsolute) / 4.0;
    
    // Return in the order expected by Unity/VR: [delta, theta, alpha, beta]
    return [deltaAvg, thetaAvg, alphaAvg, betaAvg];
  }
  
  /// Refresh subscriptions (call when new device connects)
  void refreshSubscriptions() {
    if (ref.read(isOscStreamingProvider)) {
      _startStreaming();
    }
  }
}
