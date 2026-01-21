import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/arousal_provider.dart';
import '../../domain/models/arousal_sample.dart';

/// Compact arousal index widget for live monitoring screen
class ArousalIndexWidget extends ConsumerWidget {
  final String deviceId;

  const ArousalIndexWidget({
    super.key,
    required this.deviceId,
  });

  Color _getArousalColor(double arousal) {
    if (arousal < 0.33) return Colors.blue;
    if (arousal < 0.67) return Colors.orange;
    return Colors.red;
  }

  String _getArousalLabel(double arousal) {
    if (arousal < 0.33) return 'LOW';
    if (arousal < 0.67) return 'MEDIUM';
    return 'HIGH';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arousalAsync = ref.watch(arousalStreamProvider(deviceId));

    return arousalAsync.when(
      data: (sample) => _buildArousalDisplay(sample),
      loading: () => _buildLoadingState(),
      error: (err, stack) => _buildErrorState(),
    );
  }

  Widget _buildArousalDisplay(ArousalSample sample) {
    final arousalPercent = (sample.arousalIndex * 100).toStringAsFixed(0);
    final color = _getArousalColor(sample.arousalIndex);
    final label = _getArousalLabel(sample.arousalIndex);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology, color: color, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Arousal Index',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Value and progress bar
            Row(
              children: [
                Text(
                  '$arousalPercent%',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: sample.arousalIndex,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Calm',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[300],
                            ),
                          ),
                          Text(
                            'Alert',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red[300],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Confidence
            Row(
              children: [
                const Text(
                  'Confidence: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${(sample.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: sample.confidence > 0.7
                        ? Colors.green
                        : sample.confidence > 0.4
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.grey[400], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Arousal Index',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Analyzing brain activity...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.grey[400], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Arousal Index',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[400], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Waiting for EEG data...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
