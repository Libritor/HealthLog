import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/fnirs_sample.dart';
import '../../core/constants.dart';

/// fNIRS chart widget showing multiple wavelength channels over time
class FnirsChart extends StatefulWidget {
  final Stream<FnirsSample> dataStream;

  const FnirsChart({
    super.key,
    required this.dataStream,
  });

  @override
  State<FnirsChart> createState() => _FnirsChartState();
}

class _FnirsChartState extends State<FnirsChart> {
  final List<FlSpot> _nm730Data = [];
  final List<FlSpot> _nm850Data = [];
  final List<FlSpot> _ratioData = [];
  DateTime? _startTime;
  StreamSubscription<FnirsSample>? _subscription;

  // Helper to sanitize values - clamp to >= 0
  double _safeValue(double val) {
    if (val.isNaN || val.isInfinite) return 0.0;
    return val < 0 ? 0.0 : val;
  }

  @override
  void initState() {
    super.initState();
    _subscription = widget.dataStream.listen(_onNewSample);
  }

  void _onNewSample(FnirsSample sample) {
    if (!mounted) return;
    
    _startTime ??= sample.timestamp;
    final elapsed = sample.timestamp.difference(_startTime!).inMilliseconds / 1000.0;
    
    // Average left and right outer channels
    final nm730 = _safeValue((sample.nm730LeftOuter + sample.nm730RightOuter) / 2);
    final nm850 = _safeValue((sample.nm850LeftOuter + sample.nm850RightOuter) / 2);
    final ratio = nm730 > 0.001 ? _safeValue(nm850 / nm730) : 0.0;

    setState(() {
      _nm730Data.add(FlSpot(elapsed, nm730));
      _nm850Data.add(FlSpot(elapsed, nm850));
      _ratioData.add(FlSpot(elapsed, ratio));

      // Keep only last 20 seconds
      final windowLimit = elapsed - AppConstants.fnirsDisplayWindowSeconds;
      _nm730Data.removeWhere((spot) => spot.x < windowLimit);
      _nm850Data.removeWhere((spot) => spot.x < windowLimit);
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
    if (_nm730Data.isEmpty && _nm850Data.isEmpty) {
      return const Center(child: Text('Waiting for fNIRS data...'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: _nm730Data,
              color: Colors.red.shade400,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
            LineChartBarData(
              spots: _nm850Data,
              color: Colors.blue.shade400,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('μA', style: TextStyle(fontSize: 10)),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Time (s)', style: TextStyle(fontSize: 10)),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: const SideTitles(showTitles: false),
              axisNameWidget: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 12, height: 3, color: Colors.red.shade400),
                  const SizedBox(width: 4),
                  const Text('730nm', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 16),
                  Container(width: 12, height: 3, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  const Text('850nm', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          gridData: const FlGridData(show: true),
        ),
      ),
    );
  }
}
