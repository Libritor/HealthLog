import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/eeg_sample.dart';
import '../../core/constants.dart';

/// Real-time EEG chart widget
/// Displays raw EEG data for selected channels in a scrolling time-series plot
class EegChart extends StatefulWidget {
  final Stream<EegSample> dataStream;
  final Set<String> visibleChannels;
  final int windowSeconds;

  const EegChart({
    super.key,
    required this.dataStream,
    this.visibleChannels = const {'TP9', 'AF7', 'AF8', 'TP10'},
    this.windowSeconds = AppConstants.eegDisplayWindowSeconds,
  });

  @override
  State<EegChart> createState() => _EegChartState();
}

class _EegChartState extends State<EegChart> {
  final Map<String, List<FlSpot>> _channelData = {
    'TP9': [],
    'AF7': [],
    'AF8': [],
    'TP10': [],
  };

  DateTime? _startTime;
  DateTime? _lastSampleTime;
  int _sampleCount = 0;

  StreamSubscription<EegSample>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.dataStream.listen(_onNewSample);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Throttle updates to ~30fps
  static const int _updateThrottleMs = 33;
  int _lastUpdateTimestamp = 0;

  // Adaptive Y-axis range
  double _minY = 700; // Typical Muse baseline start
  double _maxY = 1000;

  void _onNewSample(EegSample sample) {
    if (!mounted) return;
    
    _startTime ??= sample.timestamp;
    _lastSampleTime = sample.timestamp;
    _sampleCount++;

    // Add point to data buffer immediately
    final elapsed = sample.timestamp.difference(_startTime!).inMilliseconds / 1000.0;
    final windowLimit = elapsed - widget.windowSeconds;

    _addPoint('TP9', elapsed, sample.tp9, windowLimit);
    _addPoint('AF7', elapsed, sample.af7, windowLimit);
    _addPoint('AF8', elapsed, sample.af8, windowLimit);
    _addPoint('TP10', elapsed, sample.tp10, windowLimit);

    // Only trigger UI rebuild at 30fps
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastUpdateTimestamp >= _updateThrottleMs) {
      _lastUpdateTimestamp = now;
      
      // Update adaptive Y-axis
      _updateYAxisRange(windowLimit);
      
      setState(() {});
    }
  }

  void _updateYAxisRange(double windowLimit) {
    double visibleMin = double.infinity;
    double visibleMax = double.negativeInfinity;
    bool hasData = false;

    for (var channel in widget.visibleChannels) {
      final points = _channelData[channel];
      if (points == null || points.isEmpty) continue;

      for (var point in points) {
        if (point.x >= windowLimit) {
          if (point.y < visibleMin) visibleMin = point.y;
          if (point.y > visibleMax) visibleMax = point.y;
          hasData = true;
        }
      }
    }

    if (!hasData) return;

    // Add padding
    final padding = (visibleMax - visibleMin) * 0.1;
    visibleMin -= padding;
    visibleMax += padding;
    
    // Ensure minimum range to prevent flatline zoom-in
    if (visibleMax - visibleMin < 50) {
      final center = (visibleMax + visibleMin) / 2;
      visibleMin = center - 25;
      visibleMax = center + 25;
    }

    // Adaptive logic: Expand fast, shrink slow
    // Expand
    if (visibleMin < _minY) _minY = visibleMin;
    if (visibleMax > _maxY) _maxY = visibleMax;

    // Shrink (decay)
    // Move 5% towards the target per frame (at 30fps)
    if (visibleMin > _minY) _minY += (visibleMin - _minY) * 0.05;
    if (visibleMax < _maxY) _maxY -= (_maxY - visibleMax) * 0.05;
  }

  void _addPoint(String channel, double x, double y, double windowLimit) {
    _channelData[channel]!.add(FlSpot(x, y));

    // Remove old points outside the window efficiently
    // Since points are ordered, we can just remove from the start
    final list = _channelData[channel]!;
    while (list.isNotEmpty && list.first.x < windowLimit) {
      list.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_channelData.values.every((list) => list.isEmpty)) {
      return const Center(
        child: Text('Waiting for EEG data...'),
      );
    }

    // Calculate stable axis range based on the latest sample time
    // This ensures the window moves smoothly with the data
    final currentMaxX = (_sampleCount > 0 && _startTime != null && _lastSampleTime != null)
        ? (_lastSampleTime!.difference(_startTime!).inMilliseconds / 1000.0)
        : widget.windowSeconds.toDouble();
    
    final currentMinX = currentMaxX - widget.windowSeconds;

    final lines = <LineChartBarData>[];

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
    ];

    int colorIndex = 0;
    for (var channel in AppConstants.eegChannels) {
      if (widget.visibleChannels.contains(channel)) {
        lines.add(
          LineChartBarData(
            spots: _channelData[channel]!,
            color: colors[colorIndex % colors.length],
            barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }
      colorIndex++;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          lineBarsData: lines,
          minX: currentMinX,
          maxX: currentMaxX,
          minY: _minY,
          maxY: _maxY,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: const Text('µV'),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('Time (s)'),
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}
