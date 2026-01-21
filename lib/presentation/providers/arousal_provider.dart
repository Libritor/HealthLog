import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../data/arousal/arousal_service.dart';
import '../../data/arousal/model_state_loader.dart';
import '../../domain/models/arousal_sample.dart';
import '../../domain/models/eeg_sample.dart';
import '../../domain/models/band_power_sample.dart';
import 'device_provider.dart';

/// Provider for ArousalAnalysisService instance
final arousalAnalysisServiceProvider = Provider<ArousalService>((ref) {
  return ArousalService();
});

/// Provider for ModelStateLoader instance
final modelStateLoaderProvider = Provider<ModelStateLoader>((ref) {
  return ModelStateLoader();
});

/// Provider for loaded GMM model state
final arousalModelStateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final loader = ref.watch(modelStateLoaderProvider);
  return await loader.getModelState();
});

/// Helper function to create arousal stream from EEG stream
Stream<ArousalSample> _createArousalStream(
  Stream<EegSample> eegStream,
  ArousalService service,
) async* {
  final buffer = <EegSample>[];
  final targetBufferSize = (AppConstants.eegSampleRate * 2).round(); // 512 samples
  
  await for (final eegSample in eegStream) {
    buffer.add(eegSample);
    
    // When buffer reaches 2 seconds, analyze and emit result
    if (buffer.length >= targetBufferSize) {
      try {
        // Make a copy of the buffer for analysis
        final windowSamples = List<EegSample>.from(buffer);
        
        // Analyze the window
        final result = await service.analyzeEegWindow(windowSamples);
        
        // Clear buffer for next window (keep last 256 samples for overlap if needed)
        // For now, clear entirely for 2-second windows
        buffer.clear();
        
        // Yield result
        yield result;
      } catch (e) {
        print('Error analyzing arousal window: $e');
        buffer.clear(); // Clear buffer on error
        // Optionally yield an error sample or skip
      }
    }
  }
}

/// Helper function to extract average band power from a sample
double _avgChannelBand(BandPowerSample s, String band) {
  double sum = 0;
  switch (band) {
    case 'alpha':
      sum = s.tp9.alphaAbsolute + s.af7.alphaAbsolute + 
            s.af8.alphaAbsolute + s.tp10.alphaAbsolute;
      break;
    case 'beta':
      sum = s.tp9.betaAbsolute + s.af7.betaAbsolute + 
            s.af8.betaAbsolute + s.tp10.betaAbsolute;
      break;
    case 'theta':
      sum = s.tp9.thetaAbsolute + s.af7.thetaAbsolute + 
            s.af8.thetaAbsolute + s.tp10.thetaAbsolute;
      break;
    case 'gamma':
      sum = s.tp9.gammaAbsolute + s.af7.gammaAbsolute + 
            s.af8.gammaAbsolute + s.tp10.gammaAbsolute;
      break;
    case 'delta':
      sum = s.tp9.deltaAbsolute + s.af7.deltaAbsolute + 
            s.af8.deltaAbsolute + s.tp10.deltaAbsolute;
      break;
  }
  return sum / 4.0;
}

/// Helper function to create arousal stream from band power stream
/// This uses pre-computed band powers which is more efficient
Stream<ArousalSample> _createArousalStreamFromBandPowers(
  Stream<BandPowerSample> bandPowerStream,
) async* {
  final buffer = <BandPowerSample>[];
  final targetBufferSize = 8; // ~2 seconds at 4Hz band power rate
  
  await for (final sample in bandPowerStream) {
    buffer.add(sample);
    
    // When buffer reaches target size, compute arousal
    if (buffer.length >= targetBufferSize) {
      try {
        // Compute average band powers across buffer
        double avgAlpha = 0, avgBeta = 0, avgTheta = 0, avgGamma = 0;
        for (final s in buffer) {
          avgAlpha += _avgChannelBand(s, 'alpha');
          avgBeta += _avgChannelBand(s, 'beta');
          avgTheta += _avgChannelBand(s, 'theta');
          avgGamma += _avgChannelBand(s, 'gamma');
        }
        avgAlpha /= buffer.length;
        avgBeta /= buffer.length;
        avgTheta /= buffer.length;
        avgGamma /= buffer.length;
        
        // Compute arousal index: (beta + gamma) / (alpha + theta)
        final arousalIndex = ((avgBeta + avgGamma) / (avgAlpha + avgTheta + 1e-6))
            .clamp(0.0, 2.0) / 2.0; // Normalize to 0-1
        
        // Determine label
        String label;
        if (arousalIndex < 0.33) {
          label = 'low';
        } else if (arousalIndex < 0.67) {
          label = 'medium';
        } else {
          label = 'high';
        }
        
        // Simple probability model based on distance from thresholds
        final lowProb = arousalIndex < 0.5 ? (1 - arousalIndex * 2) : 0.0;
        final highProb = arousalIndex > 0.5 ? ((arousalIndex - 0.5) * 2) : 0.0;
        final mediumProb = 1.0 - lowProb - highProb;
        
        buffer.clear();
        
        yield ArousalSample(
          timestamp: DateTime.now(),
          arousalIndex: arousalIndex,
          arousalLabel: label,
          confidence: 0.7, // Moderate confidence for band-power-based estimate
          confidenceMargin: (arousalIndex - 0.5).abs() * 2,
          clusterProbs: {
            'low': lowProb.clamp(0.0, 1.0),
            'medium': mediumProb.clamp(0.0, 1.0),
            'high': highProb.clamp(0.0, 1.0),
          },
        );
      } catch (e) {
        print('Error computing arousal from band powers: $e');
        buffer.clear();
      }
    }
  }
}

/// Stream provider for arousal analysis results
/// Uses band powers for more reliable real-time analysis
final arousalStreamProvider = StreamProvider.family<ArousalSample, String>((ref, deviceId) {
  // Use band power stream which is more reliable than raw EEG
  final bandPowerStream = ref.read(bandPowerStreamProvider(deviceId).stream);
  
  // Create arousal stream from band powers
  return _createArousalStreamFromBandPowers(bandPowerStream);
});

