import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../core/constants.dart';

/// fNIRS chart widget showing oxygenation proxy (850nm/730nm ratio)
class FnirsChart extends StatefulWidget {
  final Stream<FnirsSample> dataStream;
  final String location; // 'LEFT_OUTER', 'RIGHT_OUTER', etc.

  const FnirsChart({
    super.key,
    required this.dataStream,
    this.location = 'LEFT_OUTER',
  });

  @override
  State<FnirsChart> createState() => _FnirsChartState();
}

class _FnirsChartState extends State<FnirsChart> {
  final List<FlSpot> _ratioData = [];
  DateTime? _startTime;
  StreamSubscription<FnirsSample>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.dataStream.listen(_onNewSample);
  }

  void _onNewSample(FnirsSample sample) {
    if (!mounted) return; // Don't update if widget is disposed
    
    _startTime ??= sample.timestamp;
    final elapsed = sample.timestamp.difference(_startTime!).inMilliseconds / 1000.0;
    final ratio = sample.getOxygenationRatio(widget.location);

    setState(() {
      _ratioData.add(FlSpot(elapsed, ratio));

      // Keep only last 20 seconds
      final windowLimit = elapsed - AppConstants.fnirsDisplayWindowSeconds;
      _ratioData.removeWhere((spot) => spot.x < windowLimit);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ratioData.isEmpty) {
      return const Center(child: Text('Waiting for fNIRS data...'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: _ratioData,
              color: Colors.purple,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Oxy Ratio (850/730)'),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Time (s)'),
              sideTitles: SideTitles(showTitles: true),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          gridData: FlGridData(show: true),
        ),
      ),
    );
  }
}
