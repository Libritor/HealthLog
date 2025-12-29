// Raw EEG values from all electrodes.
class EegSample {
  final DateTime timestamp;
  final double tp9;
  final double af7;
  final double af8;
  final double tp10;
  final double drl; // Drive Right Leg reference
  final double ref; // Reference electrode

  const EegSample({
    required this.timestamp,
    required this.tp9,
    required this.af7,
    required this.af8,
    required this.tp10,
    required this.drl,
    required this.ref,
  });

  Map<String, String> toCsvValues() {
    return {
      'TP9_RAW': tp9.toStringAsFixed(6),
      'AF7_RAW': af7.toStringAsFixed(6),
      'AF8_RAW': af8.toStringAsFixed(6),
      'TP10_RAW': tp10.toStringAsFixed(6),
      'DRL': drl.toStringAsFixed(6),
      'REF': ref.toStringAsFixed(6),
    };
  }
}
