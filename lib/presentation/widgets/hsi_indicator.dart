import 'package:flutter/material.dart';
import '../../domain/models/muse_device.dart';
import '../../core/constants.dart';

/// HSI (Horseshoe Signal Indicator) widget
/// Displays contact quality for all 4 EEG electrodes in a horseshoe layout
class HsiIndicator extends StatelessWidget {
  final HsiValue tp9;
  final HsiValue af7;
  final HsiValue af8;
  final HsiValue tp10;
  final double size;

  const HsiIndicator({
    super.key,
    required this.tp9,
    required this.af7,
    required this.af8,
    required this.tp10,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.6,
      child: Stack(
        children: [
          // Horseshoe arc background
          Positioned.fill(
            child: CustomPaint(
              painter: HorseshoePainter(),
            ),
          ),
          // TP9 (left)
          Positioned(
            left: 0,
            top: size * 0.25,
            child: _buildElectrode('TP9', tp9),
          ),
          // AF7 (left front)
          Positioned(
            left: size * 0.2,
            top: 0,
            child: _buildElectrode('AF7', af7),
          ),
          // AF8 (right front)
          Positioned(
            right: size * 0.2,
            top: 0,
            child: _buildElectrode('AF8', af8),
          ),
          // TP10 (right)
          Positioned(
            right: 0,
            top: size * 0.25,
            child: _buildElectrode('TP10', tp10),
          ),
        ],
      ),
    );
  }

  Widget _buildElectrode(String name, HsiValue hsi) {
    final innerColor = AppConstants.getHsiColor(hsi.value);
    final outerColor = hsi.isArtifactFree ? Colors.green : Colors.red;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring (Artifact Status)
            Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: outerColor,
                  width: size * 0.02, // Thick border for visibility
                ),
              ),
            ),
            // Inner Circle (Signal Quality)
            Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: BoxDecoration(
                color: innerColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: innerColor.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: size * 0.06,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for horseshoe arc background
class HorseshoePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromLTWH(
      size.width * 0.1,
      0,
      size.width * 0.8,
      size.height * 1.5,
    );

    // Draw horseshoe arc (180 degrees)
    canvas.drawArc(
      rect,
      3.14159, // pi (180 degrees)
      3.14159, // pi (180 degrees sweep)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
