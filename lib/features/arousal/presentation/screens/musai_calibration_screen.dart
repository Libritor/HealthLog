import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/models/calibration_result.dart';
import '../../data/gmm_calibration_service.dart';
import '../widgets/pca_scatter_plot.dart';
import '../../../../data/arousal/model_state_loader.dart';
import '../../../../presentation/providers/arousal_provider.dart';
import '../../../../presentation/providers/device_provider.dart';
import 'arousal_live_session_screen.dart';

enum CalibrationPhase {
  idle,
  loading,
  cleaning,
  featureExtraction,
  pca,
  gmmTraining,
  completed,
  error,
}

class CalibrationPhaseNotifier extends StateNotifier<CalibrationPhase> {
  CalibrationPhaseNotifier() : super(CalibrationPhase.idle);

  void setPhase(CalibrationPhase phase) => state = phase;
  void reset() => state = CalibrationPhase.idle;
}

final calibrationPhaseProvider =
    StateNotifierProvider<CalibrationPhaseNotifier, CalibrationPhase>((ref) {
  return CalibrationPhaseNotifier();
});

final calibrationResultProvider =
    StateProvider<CalibrationResult?>((ref) => null);

final calibrationErrorProvider = StateProvider<String?>((ref) => null);

/// MuseAI Calibration Screen
/// Handles CSV upload and GMM training with progress indicators
class MuseAICalibrationScreen extends ConsumerStatefulWidget {
  const MuseAICalibrationScreen({super.key});

  @override
  ConsumerState<MuseAICalibrationScreen> createState() =>
      _MuseAICalibrationScreenState();
}

class _MuseAICalibrationScreenState
    extends ConsumerState<MuseAICalibrationScreen> {
  File? _selectedFile;
  double _progress = 0.0;
  String _progressLabel = '';

  Future<void> _pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }


  Future<void> _startCalibration() async {
    if (_selectedFile == null) return;

    final service = ref.read(gmmCalibrationServiceProvider);
    final phaseNotifier = ref.read(calibrationPhaseProvider.notifier);
    final resultNotifier = ref.read(calibrationResultProvider.notifier);
    final errorNotifier = ref.read(calibrationErrorProvider.notifier);

    // Reset state
    phaseNotifier.setPhase(CalibrationPhase.loading);
    errorNotifier.state = null;
    resultNotifier.state = null;
    setState(() {
      _progress = 0.0;
      _progressLabel = 'Initializing...';
    });

    try {
      // Start calibration in isolate
      await service.calibrateFromCsv(
        _selectedFile!,
        onProgress: (phase, progress, label) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _progressLabel = label;
            });
            phaseNotifier.setPhase(phase);
          }
        },
      );

      // Get result
      final result = service.getLastCalibrationResult();
      if (result != null && mounted) {
        // Auto-save model state to app storage
        await _saveModelState(result.modelState);
        
        resultNotifier.state = result;
        phaseNotifier.setPhase(CalibrationPhase.completed);
        setState(() {
          _progress = 1.0;
          _progressLabel = 'Calibration Complete!';
        });
      } else {
        throw Exception('Calibration completed but no result available');
      }
    } catch (e) {
      if (mounted) {
        phaseNotifier.setPhase(CalibrationPhase.error);
        errorNotifier.state = e.toString();
        setState(() {
          _progressLabel = 'Error: $e';
        });
      }
    }
  }

  /// Navigate to live arousal session screen
  Future<void> _navigateToLiveSession(BuildContext context) async {
    // Check if model state is available
    final modelState = await ref.read(arousalModelStateProvider.future);
    if (modelState == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Model state not available. Please complete calibration first.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Get connected devices
    final connectedDevices = ref.read(connectedDevicesProvider);
    if (connectedDevices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No device connected. Please connect a device first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Use the first connected device
    final deviceId = connectedDevices.keys.first;
    final device = connectedDevices[deviceId];
    
    if (device == null || !device.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Device not connected. Please connect a device first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Navigate to live session screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArousalLiveSessionScreen(
            deviceId: deviceId,
          ),
        ),
      );
    }
  }

  /// Save model state to app storage
  Future<void> _saveModelState(GmmModelState modelState) async {
    try {
      final loader = ModelStateLoader();
      final modelStateJson = modelState.toJson();
      final success = await loader.saveModelStateToFile(modelStateJson);
      
      if (success && mounted) {
        // Invalidate the model state provider to reload
        ref.invalidate(arousalModelStateProvider);
      }
    } catch (e) {
      print('Error saving model state: $e');
    }
  }

  /// Delete model state from app storage (clean state)
  Future<void> _deleteModelState() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/arousal_model_state.json');
      if (await file.exists()) {
        await file.delete();
        // Invalidate the model state provider
        ref.invalidate(arousalModelStateProvider);
      }
    } catch (e) {
      print('Error deleting model state: $e');
    }
  }

  @override
  void dispose() {
    // Auto-delete model state when calibration screen is closed/exited
    // This ensures clean state after each session
    _deleteModelState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(calibrationPhaseProvider);
    final result = ref.watch(calibrationResultProvider);
    final error = ref.watch(calibrationErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MuseAI Calibration'),
        elevation: 2,
      ),
      body: phase == CalibrationPhase.completed && result != null
          ? _buildCompletedView(result)
          : _buildCalibrationView(phase, error),
    );
  }

  Widget _buildCalibrationView(CalibrationPhase phase, String? error) {
    final isProcessing = phase != CalibrationPhase.idle &&
        phase != CalibrationPhase.error &&
        phase != CalibrationPhase.completed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload Calibration CSV',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a CSV file (≤150MB) generated from prior Muse sessions to train the GMM model.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // File picker
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_selectedFile != null) ...[
                    ListTile(
                      leading: const Icon(Icons.file_present),
                      title: Text(_selectedFile!.path.split('/').last),
                      subtitle: Text(
                        '${(_selectedFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isProcessing
                            ? null
                            : () {
                                setState(() {
                                  _selectedFile = null;
                                });
                              },
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: isProcessing ? null : _pickCsvFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Select CSV File'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Progress indicator
          if (isProcessing || phase == CalibrationPhase.completed) ...[
            _buildProgressIndicator(),
            const SizedBox(height: 24),
          ],

          // Error display
          if (error != null) ...[
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Calibration Error',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(error),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Start button
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: (_selectedFile != null && !isProcessing)
                  ? _startCalibration
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'Start Calibration',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Skip Calibration button
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: isProcessing ? null : () => _skipCalibration(context),
              icon: const Icon(Icons.skip_next),
              label: const Text(
                'Skip Calibration',
                style: TextStyle(fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          const Text(
            'Skip if you already have a calibrated profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Skip calibration and go directly to goal selection
  Future<void> _skipCalibration(BuildContext context) async {
    // Check if model state already exists
    final modelState = await ref.read(arousalModelStateProvider.future);
    
    if (modelState == null) {
      // No existing model - show warning
      if (mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Calibration Found'),
            content: const Text(
              'No existing calibration profile was found. '
              'The arousal analysis may be less accurate without calibration.\n\n'
              'Do you want to continue anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Continue Without Calibration'),
              ),
            ],
          ),
        );
        
        if (proceed != true) return;
      }
    }
    
    // Get connected devices
    final connectedDevices = ref.read(connectedDevicesProvider);
    if (connectedDevices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No device connected. Please connect a device first.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Navigate directly to goal selection
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MeditationGoalScreen(),
        ),
      );
    }
  }

  Widget _buildProgressIndicator() {
    final phase = ref.watch(calibrationPhaseProvider);
    final phases = [
      CalibrationPhase.loading,
      CalibrationPhase.cleaning,
      CalibrationPhase.featureExtraction,
      CalibrationPhase.pca,
      CalibrationPhase.gmmTraining,
    ];

    final phaseLabels = {
      CalibrationPhase.loading: 'Loading Data',
      CalibrationPhase.cleaning: 'Cleaning EEG',
      CalibrationPhase.featureExtraction: 'Extracting Features',
      CalibrationPhase.pca: 'Computing PCA',
      CalibrationPhase.gmmTraining: 'Fitting GMM Clusters',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _progressLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 24),
            ...phases.map((p) {
              final isActive = phase == p;
              final isComplete = phases.indexOf(phase) > phases.indexOf(p);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle
                          : isActive
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                      color: isComplete
                          ? Colors.green
                          : isActive
                              ? Colors.blue
                              : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      phaseLabels[p] ?? '',
                      style: TextStyle(
                        color: isComplete || isActive
                            ? Colors.black
                            : Colors.grey,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedView(CalibrationResult result) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Calibration Complete!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PCA Cluster Visualization',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PC1: ${(result.pcaVariance.pc1 * 100).toStringAsFixed(1)}% variance | '
                  'PC2: ${(result.pcaVariance.pc2 * 100).toStringAsFixed(1)}% variance',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 600,
                  child: PcaScatterPlot(
                    data: result.pcaData,
                    variance: result.pcaVariance,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToLiveSession(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'Start Livestream & AI Mentor',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

