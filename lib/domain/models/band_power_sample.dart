// Band power breakdown for one electrode.
class ChannelBandPower {
  final double deltaAbsolute;
  final double thetaAbsolute;
  final double alphaAbsolute;
  final double betaAbsolute;
  final double gammaAbsolute;
  final double deltaRelative;
  final double thetaRelative;
  final double alphaRelative;
  final double betaRelative;
  final double gammaRelative;

  const ChannelBandPower({
    required this.deltaAbsolute,
    required this.thetaAbsolute,
    required this.alphaAbsolute,
    required this.betaAbsolute,
    required this.gammaAbsolute,
    required this.deltaRelative,
    required this.thetaRelative,
    required this.alphaRelative,
    required this.betaRelative,
    required this.gammaRelative,
  });
}

// Band powers for all 4 channels.
class BandPowerSample {
  final DateTime timestamp;
  final ChannelBandPower tp9;
  final ChannelBandPower af7;
  final ChannelBandPower af8;
  final ChannelBandPower tp10;

  const BandPowerSample({
    required this.timestamp,
    required this.tp9,
    required this.af7,
    required this.af8,
    required this.tp10,
  });

  Map<String, String> toCsvValues() {
    return {
      // TP9
      'TP9_DELTA_ABSOLUTE': tp9.deltaAbsolute.toStringAsFixed(6),
      'TP9_THETA_ABSOLUTE': tp9.thetaAbsolute.toStringAsFixed(6),
      'TP9_ALPHA_ABSOLUTE': tp9.alphaAbsolute.toStringAsFixed(6),
      'TP9_BETA_ABSOLUTE': tp9.betaAbsolute.toStringAsFixed(6),
      'TP9_GAMMA_ABSOLUTE': tp9.gammaAbsolute.toStringAsFixed(6),
      'TP9_DELTA_RELATIVE': tp9.deltaRelative.toStringAsFixed(6),
      'TP9_THETA_RELATIVE': tp9.thetaRelative.toStringAsFixed(6),
      'TP9_ALPHA_RELATIVE': tp9.alphaRelative.toStringAsFixed(6),
      'TP9_BETA_RELATIVE': tp9.betaRelative.toStringAsFixed(6),
      'TP9_GAMMA_RELATIVE': tp9.gammaRelative.toStringAsFixed(6),
      // AF7
      'AF7_DELTA_ABSOLUTE': af7.deltaAbsolute.toStringAsFixed(6),
      'AF7_THETA_ABSOLUTE': af7.thetaAbsolute.toStringAsFixed(6),
      'AF7_ALPHA_ABSOLUTE': af7.alphaAbsolute.toStringAsFixed(6),
      'AF7_BETA_ABSOLUTE': af7.betaAbsolute.toStringAsFixed(6),
      'AF7_GAMMA_ABSOLUTE': af7.gammaAbsolute.toStringAsFixed(6),
      'AF7_DELTA_RELATIVE': af7.deltaRelative.toStringAsFixed(6),
      'AF7_THETA_RELATIVE': af7.thetaRelative.toStringAsFixed(6),
      'AF7_ALPHA_RELATIVE': af7.alphaRelative.toStringAsFixed(6),
      'AF7_BETA_RELATIVE': af7.betaRelative.toStringAsFixed(6),
      'AF7_GAMMA_RELATIVE': af7.gammaRelative.toStringAsFixed(6),
      // AF8
      'AF8_DELTA_ABSOLUTE': af8.deltaAbsolute.toStringAsFixed(6),
      'AF8_THETA_ABSOLUTE': af8.thetaAbsolute.toStringAsFixed(6),
      'AF8_ALPHA_ABSOLUTE': af8.alphaAbsolute.toStringAsFixed(6),
      'AF8_BETA_ABSOLUTE': af8.betaAbsolute.toStringAsFixed(6),
      'AF8_GAMMA_ABSOLUTE': af8.gammaAbsolute.toStringAsFixed(6),
      'AF8_DELTA_RELATIVE': af8.deltaRelative.toStringAsFixed(6),
      'AF8_THETA_RELATIVE': af8.thetaRelative.toStringAsFixed(6),
      'AF8_ALPHA_RELATIVE': af8.alphaRelative.toStringAsFixed(6),
      'AF8_BETA_RELATIVE': af8.betaRelative.toStringAsFixed(6),
      'AF8_GAMMA_RELATIVE': af8.gammaRelative.toStringAsFixed(6),
      // TP10
      'TP10_DELTA_ABSOLUTE': tp10.deltaAbsolute.toStringAsFixed(6),
      'TP10_THETA_ABSOLUTE': tp10.thetaAbsolute.toStringAsFixed(6),
      'TP10_ALPHA_ABSOLUTE': tp10.alphaAbsolute.toStringAsFixed(6),
      'TP10_BETA_ABSOLUTE': tp10.betaAbsolute.toStringAsFixed(6),
      'TP10_GAMMA_ABSOLUTE': tp10.gammaAbsolute.toStringAsFixed(6),
      'TP10_DELTA_RELATIVE': tp10.deltaRelative.toStringAsFixed(6),
      'TP10_THETA_RELATIVE': tp10.thetaRelative.toStringAsFixed(6),
      'TP10_ALPHA_RELATIVE': tp10.alphaRelative.toStringAsFixed(6),
      'TP10_BETA_RELATIVE': tp10.betaRelative.toStringAsFixed(6),
      'TP10_GAMMA_RELATIVE': tp10.gammaRelative.toStringAsFixed(6),
    };
  }
}
