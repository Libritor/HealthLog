import 'dart:io';
import 'package:osc/osc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the OSC Service
final oscServiceProvider = Provider<OscService>((ref) {
  return OscService();
});

/// Provider for the target IP address - SET THIS TO YOUR VR HEADSET/PC IP
/// Your PC IP: 10.0.0.185
final oscTargetIpProvider = StateProvider<String>((ref) => '10.0.0.185');

/// Provider for the target Ports (default 5000, 5001)
final oscTargetPortsProvider = StateProvider<List<int>>((ref) => [5000, 5001]);

/// Provider to toggle streaming on/off
final isOscStreamingProvider = StateProvider<bool>((ref) => false);

class OscService {
  RawDatagramSocket? _socket;

  OscService() {
    _initSocket();
  }

  Future<void> _initSocket() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (e) {
      print('Error binding OSC socket: $e');
    }
  }

  /// Send an OSC message to the target IP/Port
  void send(String address, List<Object> arguments, String targetIp, int targetPort) {
    if (_socket == null) return;

    try {
      final message = OSCMessage(address, arguments: arguments);
      final bytes = message.toBytes();
      
      _socket!.send(
        bytes,
        InternetAddress(targetIp),
        targetPort,
      );
    } catch (e) {
      print('Error sending OSC message: $e');
    }
  }

  void dispose() {
    _socket?.close();
  }
}
