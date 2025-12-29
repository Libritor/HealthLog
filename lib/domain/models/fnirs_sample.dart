// fNIRS readings at 730nm/850nm/Red/Ambient wavelengths (Athena only).
class FnirsSample {
  final DateTime timestamp;

  // 730nm wavelength readings
  final double nm730LeftOuter;
  final double nm730RightOuter;
  final double nm730LeftInner;
  final double nm730RightInner;

  // 850nm wavelength readings
  final double nm850LeftOuter;
  final double nm850RightOuter;
  final double nm850LeftInner;
  final double nm850RightInner;

  // Red wavelength readings
  final double redLeftOuter;
  final double redRightOuter;
  final double redLeftInner;
  final double redRightInner;

  // Ambient light readings
  final double ambientLeftOuter;
  final double ambientRightOuter;
  final double ambientLeftInner;
  final double ambientRightInner;

  const FnirsSample({
    required this.timestamp,
    required this.nm730LeftOuter,
    required this.nm730RightOuter,
    required this.nm730LeftInner,
    required this.nm730RightInner,
    required this.nm850LeftOuter,
    required this.nm850RightOuter,
    required this.nm850LeftInner,
    required this.nm850RightInner,
    required this.redLeftOuter,
    required this.redRightOuter,
    required this.redLeftInner,
    required this.redRightInner,
    required this.ambientLeftOuter,
    required this.ambientRightOuter,
    required this.ambientLeftInner,
    required this.ambientRightInner,
  });

  // 850nm/730nm ratio = rough oxygenation proxy.
  double getOxygenationRatio(String location) {
    switch (location) {
      case 'LEFT_OUTER':
        return nm850LeftOuter / (nm730LeftOuter + 0.0001);
      case 'RIGHT_OUTER':
        return nm850RightOuter / (nm730RightOuter + 0.0001);
      case 'LEFT_INNER':
        return nm850LeftInner / (nm730LeftInner + 0.0001);
      case 'RIGHT_INNER':
        return nm850RightInner / (nm730RightInner + 0.0001);
      default:
        return 0.0;
    }
  }

  Map<String, String> toCsvValues() {
    return {
      '730nm_LEFT_OUTER': nm730LeftOuter.toStringAsFixed(6),
      '730nm_RIGHT_OUTER': nm730RightOuter.toStringAsFixed(6),
      '850nm_LEFT_OUTER': nm850LeftOuter.toStringAsFixed(6),
      '850nm_RIGHT_OUTER': nm850RightOuter.toStringAsFixed(6),
      '730nm_LEFT_INNER': nm730LeftInner.toStringAsFixed(6),
      '730nm_RIGHT_INNER': nm730RightInner.toStringAsFixed(6),
      '850nm_LEFT_INNER': nm850LeftInner.toStringAsFixed(6),
      '850nm_RIGHT_INNER': nm850RightInner.toStringAsFixed(6),
      'RED_LEFT_OUTER': redLeftOuter.toStringAsFixed(6),
      'RED_RIGHT_OUTER': redRightOuter.toStringAsFixed(6),
      'AMBIENT_LEFT_OUTER': ambientLeftOuter.toStringAsFixed(6),
      'AMBIENT_RIGHT_OUTER': ambientRightOuter.toStringAsFixed(6),
      'RED_LEFT_INNER': redLeftInner.toStringAsFixed(6),
      'RED_RIGHT_INNER': redRightInner.toStringAsFixed(6),
      'AMBIENT_LEFT_INNER': ambientLeftInner.toStringAsFixed(6),
      'AMBIENT_RIGHT_INNER': ambientRightInner.toStringAsFixed(6),
    };
  }
}
