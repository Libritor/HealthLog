import 'dart:math' as math;
import '../../core/constants.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/arousal_sample.dart';
import '../../features/arousal/data/preprocessing_dart.dart';
import 'model_state_loader.dart';

/// Service for on-device live arousal index analysis
/// Uses Dart GMM implementation for mobile-first, offline-capable analysis
class ArousalService {
  final ModelStateLoader _modelStateLoader = ModelStateLoader();
  Map<String, dynamic>? _cachedModelState;
  
  // Cached model parameters for efficient inference
  List<double>? _gmmWeights;
  List<List<double>>? _gmmMeans;
  List<List<List<double>>>? _gmmCovariances;
  List<List<double>>? _pcaMean;
  List<List<double>>? _pcaComponents;
  List<int>? _clusterOrder; // Order of clusters by arousal level (low, medium, high)

  /// Get model state (loads from cache or file)
  Future<Map<String, dynamic>?> getModelState() async {
    if (_cachedModelState != null) {
      return _cachedModelState;
    }

    _cachedModelState = await _modelStateLoader.getModelState();
    if (_cachedModelState != null) {
      _parseModelState(_cachedModelState!);
    }
    return _cachedModelState;
  }

  /// Parse model state into usable parameters
  void _parseModelState(Map<String, dynamic> state) {
    try {
      // Parse GMM parameters
      if (state.containsKey('gmm_weights')) {
        _gmmWeights = (state['gmm_weights'] as List).cast<double>();
      }
      
      if (state.containsKey('gmm_means')) {
        _gmmMeans = (state['gmm_means'] as List)
            .map((m) => (m as List).cast<double>())
            .toList();
      }
      
      if (state.containsKey('gmm_covariances')) {
        _gmmCovariances = (state['gmm_covariances'] as List)
            .map((c) => (c as List)
                .map((row) => (row as List).cast<double>())
                .toList())
            .toList();
      }
      
      // Parse PCA parameters
      if (state.containsKey('pca_mean')) {
        final mean = state['pca_mean'];
        if (mean is List) {
          _pcaMean = [mean.cast<double>()];
        }
      }
      
      if (state.containsKey('pca_components')) {
        _pcaComponents = (state['pca_components'] as List)
            .map((c) => (c as List).cast<double>())
            .toList();
      }
      
      // Parse cluster order (ordering by arousal level)
      if (state.containsKey('cluster_order')) {
        _clusterOrder = (state['cluster_order'] as List).cast<int>();
      } else {
        // Default ordering: assume clusters 0, 1, 2 correspond to low, medium, high
        _clusterOrder = [0, 1, 2];
      }
    } catch (e) {
      print('Error parsing model state: $e');
    }
  }

  /// Analyze a 2-second window of EEG samples using on-device processing
  Future<ArousalSample> analyzeEegWindow(List<EegSample> samples) async {
    if (samples.isEmpty) {
      throw Exception('No EEG samples provided for analysis');
    }

    // Get model state
    final modelState = await getModelState();
    if (modelState == null) {
      throw Exception('Model state not available. Please calibrate first.');
    }

    try {
      // Convert EEG samples to channel-wise arrays (4 channels: TP9, AF7, AF8, TP10)
      final channelData = _extractChannelData(samples);
      
      // Extract features using preprocessing utilities
      final features = PreprocessingUtils.extractWindowFeatures(
        channelData,
        AppConstants.eegSampleRate.toDouble(),
      );
      
      // Create feature vector for GMM prediction
      final featureVector = _createFeatureVector(features);
      
      // Apply PCA transformation if available
      final transformedFeatures = _applyPCA(featureVector);
      
      // Predict cluster probabilities using GMM
      final clusterProbs = _predictGMMProbabilities(transformedFeatures);
      
      // Determine arousal label and index
      final result = _computeArousalFromProbs(clusterProbs, features);
      
      return result;
    } catch (e) {
      print('Error in on-device arousal analysis: $e');
      // Return a default sample on error
      return ArousalSample(
        timestamp: DateTime.now(),
        arousalIndex: 0.5,
        arousalLabel: 'unknown',
        confidence: 0.0,
        confidenceMargin: 0.0,
        clusterProbs: {'low': 0.33, 'medium': 0.34, 'high': 0.33},
      );
    }
  }

  /// Extract channel data from EEG samples
  List<List<double>> _extractChannelData(List<EegSample> samples) {
    // 4 channels: TP9, AF7, AF8, TP10
    final tp9 = <double>[];
    final af7 = <double>[];
    final af8 = <double>[];
    final tp10 = <double>[];
    
    for (final sample in samples) {
      tp9.add(sample.tp9);
      af7.add(sample.af7);
      af8.add(sample.af8);
      tp10.add(sample.tp10);
    }
    
    return [tp9, af7, af8, tp10];
  }

  /// Create feature vector for GMM from extracted features
  List<double> _createFeatureVector(Map<String, double> features) {
    // Match the feature order used during calibration
    // Standard features: band powers (abs + rel) + hjorth params
    return [
      features['delta_abs'] ?? 0.0,
      features['theta_abs'] ?? 0.0,
      features['alpha_abs'] ?? 0.0,
      features['beta_abs'] ?? 0.0,
      features['gamma_abs'] ?? 0.0,
      features['delta_rel'] ?? 0.0,
      features['theta_rel'] ?? 0.0,
      features['alpha_rel'] ?? 0.0,
      features['beta_rel'] ?? 0.0,
      features['gamma_rel'] ?? 0.0,
      features['hjorth_mobility'] ?? 0.0,
      features['hjorth_complexity'] ?? 0.0,
    ];
  }

  /// Apply PCA transformation to features
  List<double> _applyPCA(List<double> features) {
    if (_pcaMean == null || _pcaComponents == null) {
      // No PCA available, return original features (take first 2 for 2D)
      return features.length >= 2 ? [features[0], features[1]] : features;
    }
    
    try {
      // Center the features
      final centered = <double>[];
      for (int i = 0; i < features.length && i < _pcaMean![0].length; i++) {
        centered.add(features[i] - _pcaMean![0][i]);
      }
      
      // Project onto principal components (take first 2 components)
      final nComponents = math.min(2, _pcaComponents!.length);
      final transformed = <double>[];
      
      for (int c = 0; c < nComponents; c++) {
        double sum = 0.0;
        for (int i = 0; i < centered.length && i < _pcaComponents![c].length; i++) {
          sum += centered[i] * _pcaComponents![c][i];
        }
        transformed.add(sum);
      }
      
      return transformed;
    } catch (e) {
      print('Error applying PCA: $e');
      return features.length >= 2 ? [features[0], features[1]] : features;
    }
  }

  /// Predict GMM cluster probabilities
  Map<String, double> _predictGMMProbabilities(List<double> features) {
    if (_gmmWeights == null || _gmmMeans == null || _gmmCovariances == null) {
      // No GMM model, return uniform probabilities
      return {'low': 0.33, 'medium': 0.34, 'high': 0.33};
    }
    
    try {
      final nComponents = _gmmWeights!.length;
      final logResponsibilities = <double>[];
      
      for (int k = 0; k < nComponents; k++) {
        final logProb = _logGaussianProb(features, _gmmMeans![k], _gmmCovariances![k]);
        final logWeight = math.log(_gmmWeights![k] + 1e-10);
        logResponsibilities.add(logWeight + logProb);
      }
      
      // Log-sum-exp for numerical stability
      final maxLog = logResponsibilities.reduce((a, b) => a > b ? a : b);
      final expValues = logResponsibilities.map((lp) => math.exp(lp - maxLog)).toList();
      final sum = expValues.fold<double>(0.0, (a, b) => a + b);
      
      final probs = expValues.map((v) => v / (sum + 1e-10)).toList();
      
      // Map cluster indices to arousal levels based on cluster order
      final clusterOrder = _clusterOrder ?? [0, 1, 2];
      final lowIdx = clusterOrder.indexOf(0);
      final medIdx = clusterOrder.indexOf(1);
      final highIdx = clusterOrder.indexOf(2);
      
      return {
        'low': probs.length > lowIdx && lowIdx >= 0 ? probs[lowIdx] : 0.33,
        'medium': probs.length > medIdx && medIdx >= 0 ? probs[medIdx] : 0.34,
        'high': probs.length > highIdx && highIdx >= 0 ? probs[highIdx] : 0.33,
      };
    } catch (e) {
      print('Error predicting GMM probabilities: $e');
      return {'low': 0.33, 'medium': 0.34, 'high': 0.33};
    }
  }

  /// Compute log probability of point under Gaussian
  double _logGaussianProb(List<double> x, List<double> mean, List<List<double>> cov) {
    final nFeatures = x.length;
    
    // Compute diff
    final diff = <double>[];
    for (int i = 0; i < nFeatures && i < mean.length; i++) {
      diff.add(x[i] - mean[i]);
    }
    
    // Simple diagonal approximation for efficiency on mobile
    // (Full implementation would use Cholesky decomposition)
    double quadForm = 0.0;
    double logDet = 0.0;
    
    for (int i = 0; i < diff.length; i++) {
      final variance = (i < cov.length && i < cov[i].length) ? cov[i][i] : 1.0;
      final safeVariance = variance + 1e-6; // Regularization
      quadForm += diff[i] * diff[i] / safeVariance;
      logDet += math.log(safeVariance);
    }
    
    return -0.5 * (quadForm + logDet + nFeatures * math.log(2 * math.pi));
  }

  /// Compute arousal result from cluster probabilities
  ArousalSample _computeArousalFromProbs(
    Map<String, double> clusterProbs,
    Map<String, double> features,
  ) {
    final lowProb = clusterProbs['low'] ?? 0.33;
    final mediumProb = clusterProbs['medium'] ?? 0.34;
    final highProb = clusterProbs['high'] ?? 0.33;
    
    // Determine label based on highest probability
    String label;
    double maxProb = lowProb;
    label = 'low';
    
    if (mediumProb > maxProb) {
      maxProb = mediumProb;
      label = 'medium';
    }
    if (highProb > maxProb) {
      maxProb = highProb;
      label = 'high';
    }
    
    // Compute arousal index (0-1 scale)
    // Weighted sum: low=0, medium=0.5, high=1.0
    final arousalIndex = (lowProb * 0.0 + mediumProb * 0.5 + highProb * 1.0)
        .clamp(0.0, 1.0);
    
    // Decision margin: difference between top two probabilities
    final sortedProbs = [lowProb, mediumProb, highProb]..sort((a, b) => b.compareTo(a));
    final confidenceMargin = sortedProbs[0] - sortedProbs[1];
    
    return ArousalSample(
      timestamp: DateTime.now(),
      arousalIndex: arousalIndex,
      arousalLabel: label,
      confidence: maxProb,
      confidenceMargin: confidenceMargin.clamp(0.0, 1.0),
      clusterProbs: clusterProbs,
    );
  }
}
