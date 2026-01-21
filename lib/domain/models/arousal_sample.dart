/// Arousal analysis result from live EEG data processing
class ArousalSample {
  final DateTime timestamp;
  final double arousalIndex; // 0.0-1.0
  final String arousalLabel; // "low", "medium", "high"
  final double confidence; // 0.0-1.0
  final double? confidenceMargin;
  final Map<String, double>? clusterProbs; // Cluster probabilities

  const ArousalSample({
    required this.timestamp,
    required this.arousalIndex,
    required this.arousalLabel,
    required this.confidence,
    this.confidenceMargin,
    this.clusterProbs,
  });

  factory ArousalSample.fromJson(Map<String, dynamic> json) {
    return ArousalSample(
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      arousalIndex: (json['arousal_index'] as num?)?.toDouble() ?? 0.0,
      arousalLabel: json['arousal_label'] as String? ?? 'medium',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      confidenceMargin: (json['confidence_margin'] as num?)?.toDouble(),
      clusterProbs: json['cluster_probs'] != null
          ? Map<String, double>.from(json['cluster_probs'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'arousal_index': arousalIndex,
      'arousal_label': arousalLabel,
      'confidence': confidence,
      if (confidenceMargin != null) 'confidence_margin': confidenceMargin,
      if (clusterProbs != null) 'cluster_probs': clusterProbs,
    };
  }

  Map<String, String> toCsvValues() {
    return {
      'AROUSAL_INDEX': arousalIndex.toStringAsFixed(4),
      'AROUSAL_LABEL': arousalLabel,
      'AROUSAL_CONFIDENCE': confidence.toStringAsFixed(4),
    };
  }
}

