import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/imu_sample.dart';

/// IMU data display widget (simplified numeric view)
class ImuChart extends StatefulWidget {
  final Stream<ImuSample> dataStream;

  const ImuChart({super.key, required this.dataStream});

  @override
  State<ImuChart> createState() => _ImuChartState();
}

class _ImuChartState extends State<ImuChart> {
  ImuSample? _latestSample;
  StreamSubscription<ImuSample>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.dataStream.listen((sample) {
      if (!mounted) return;
      setState(() {
        _latestSample = sample;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_latestSample == null) {
      return const Center(child: Text('Waiting for IMU data...'));
    }

    final sample = _latestSample!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gyroscope (°/s)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildValue('X', sample.gyroX, Colors.red),
              const SizedBox(width: 16),
              _buildValue('Y', sample.gyroY, Colors.green),
              const SizedBox(width: 16),
              _buildValue('Z', sample.gyroZ, Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Accelerometer (g)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildValue('X', sample.accelX, Colors.red),
              const SizedBox(width: 16),
              _buildValue('Y', sample.accelY, Colors.green),
              const SizedBox(width: 16),
              _buildValue('Z', sample.accelZ, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValue(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
