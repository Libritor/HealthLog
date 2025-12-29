import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/models/band_power_sample.dart';

/// Band power chart widget
class BandPowerChart extends StatefulWidget {
  final Stream<BandPowerSample> dataStream;
  final bool showRelative; // true = relative, false = absolute

  const BandPowerChart({
    super.key,
    required this.dataStream,
    this.showRelative = false,
  });

  @override
  State<BandPowerChart> createState() => _BandPowerChartState();
}

class _BandPowerChartState extends State<BandPowerChart> {
  BandPowerSample? _latestSample;
  StreamSubscription<BandPowerSample>? _subscription;

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
      return const Center(child: Text('Waiting for band power data...'));
    }

    final sample = _latestSample!;

    // Helper to sanitize values
    double safeValue(double val) {
      if (val.isNaN || val.isInfinite) return 0.0;
      return val;
    }

    // Average across all 4 channels for simplicity
    final delta = safeValue(widget.showRelative
        ? (sample.tp9.deltaRelative + sample.af7.deltaRelative + sample.af8.deltaRelative + sample.tp10.deltaRelative) / 4
        : (sample.tp9.deltaAbsolute + sample.af7.deltaAbsolute + sample.af8.deltaAbsolute + sample.tp10.deltaAbsolute) / 4);

    final theta = safeValue(widget.showRelative
        ? (sample.tp9.thetaRelative + sample.af7.thetaRelative + sample.af8.thetaRelative + sample.tp10.thetaRelative) / 4
        : (sample.tp9.thetaAbsolute + sample.af7.thetaAbsolute + sample.af8.thetaAbsolute + sample.tp10.thetaAbsolute) / 4);

    final alpha = safeValue(widget.showRelative
        ? (sample.tp9.alphaRelative + sample.af7.alphaRelative + sample.af8.alphaRelative + sample.tp10.alphaRelative) / 4
        : (sample.tp9.alphaAbsolute + sample.af7.alphaAbsolute + sample.af8.alphaAbsolute + sample.tp10.alphaAbsolute) / 4);

    final beta = safeValue(widget.showRelative
        ? (sample.tp9.betaRelative + sample.af7.betaRelative + sample.af8.betaRelative + sample.tp10.betaRelative) / 4
        : (sample.tp9.betaAbsolute + sample.af7.betaAbsolute + sample.af8.betaAbsolute + sample.tp10.betaAbsolute) / 4);

    final gamma = safeValue(widget.showRelative
        ? (sample.tp9.gammaRelative + sample.af7.gammaRelative + sample.af8.gammaRelative + sample.tp10.gammaRelative) / 4
        : (sample.tp9.gammaAbsolute + sample.af7.gammaAbsolute + sample.af8.gammaAbsolute + sample.tp10.gammaAbsolute) / 4);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          barGroups: [
            _buildBar(0, delta, Colors.red),
            _buildBar(1, theta, Colors.orange),
            _buildBar(2, alpha, Colors.green),
            _buildBar(3, beta, Colors.blue),
            _buildBar(4, gamma, Colors.purple),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const labels = ['Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'];
                  final index = value.toInt();
                  if (index >= 0 && index < labels.length) {
                    return Text(labels[index], style: const TextStyle(fontSize: 10));
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          gridData: const FlGridData(show: false),
        ),
      ),
    );
  }

  BarChartGroupData _buildBar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 25,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
