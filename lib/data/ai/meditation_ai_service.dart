import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';

/// Meditation goal types
enum MeditationGoal {
  focus, // Increase arousal index
  calm,  // Decrease arousal index
}

extension MeditationGoalExtension on MeditationGoal {
  String get displayName {
    switch (this) {
      case MeditationGoal.focus:
        return 'Focus';
      case MeditationGoal.calm:
        return 'Calm Down';
    }
  }

  String get description {
    switch (this) {
      case MeditationGoal.focus:
        return 'Increase your arousal index to enhance alertness and concentration';
      case MeditationGoal.calm:
        return 'Decrease your arousal index to relax and find inner peace';
    }
  }

  String get targetDirection {
    switch (this) {
      case MeditationGoal.focus:
        return 'increase';
      case MeditationGoal.calm:
        return 'decrease';
    }
  }
}

/// AI-powered meditation guidance service
class MeditationAIService {
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;
  bool _isSpeaking = false;
  
  // OpenAI API configuration
  // You can set this via environment or config
  String? _apiKey;
  static const String _defaultApiEndpoint = 'https://api.openai.com/v1/chat/completions';
  
  // Feedback history for context
  final List<Map<String, dynamic>> _feedbackHistory = [];
  
  // Last feedback time to avoid too frequent feedback
  DateTime? _lastFeedbackTime;
  static const Duration _minFeedbackInterval = Duration(seconds: 8);

  MeditationAIService({String? apiKey}) : _apiKey = apiKey;

  /// Initialize text-to-speech
  Future<void> initTts() async {
    if (_ttsInitialized) return;
    
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45); // Calm, slow speech
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _ttsInitialized = true;
  }

  /// Set API key for OpenAI
  void setApiKey(String key) {
    _apiKey = key;
  }

  /// Generate live feedback based on current arousal state and goal
  Future<String> generateLiveFeedback({
    required MeditationGoal goal,
    required double currentArousal,
    required String arousalLabel,
    double? previousArousal,
    Duration? sessionDuration,
  }) async {
    // Check if enough time has passed since last feedback
    if (_lastFeedbackTime != null) {
      final elapsed = DateTime.now().difference(_lastFeedbackTime!);
      if (elapsed < _minFeedbackInterval) {
        return ''; // Don't generate feedback too frequently
      }
    }

    final feedback = await _getAIFeedback(
      goal: goal,
      currentArousal: currentArousal,
      arousalLabel: arousalLabel,
      previousArousal: previousArousal,
      sessionDuration: sessionDuration,
      isLive: true,
    );

    _lastFeedbackTime = DateTime.now();
    
    // Store feedback for session summary
    _feedbackHistory.add({
      'timestamp': DateTime.now().toIso8601String(),
      'arousal': currentArousal,
      'label': arousalLabel,
      'feedback': feedback,
    });

    return feedback;
  }

  /// Generate session summary
  Future<String> generateSessionSummary({
    required MeditationGoal goal,
    required Duration sessionDuration,
    required List<double> arousalHistory,
    required double startingArousal,
    required double endingArousal,
  }) async {
    return await _getAIFeedback(
      goal: goal,
      currentArousal: endingArousal,
      arousalLabel: _getArousalLabel(endingArousal),
      previousArousal: startingArousal,
      sessionDuration: sessionDuration,
      isLive: false,
      arousalHistory: arousalHistory,
    );
  }

  String _getArousalLabel(double arousal) {
    if (arousal < 0.33) return 'low';
    if (arousal < 0.67) return 'medium';
    return 'high';
  }

  /// Core AI feedback generation
  Future<String> _getAIFeedback({
    required MeditationGoal goal,
    required double currentArousal,
    required String arousalLabel,
    double? previousArousal,
    Duration? sessionDuration,
    required bool isLive,
    List<double>? arousalHistory,
  }) async {
    // If no API key, use rule-based feedback
    if (_apiKey == null || _apiKey!.isEmpty) {
      return _generateRuleBasedFeedback(
        goal: goal,
        currentArousal: currentArousal,
        arousalLabel: arousalLabel,
        previousArousal: previousArousal,
        sessionDuration: sessionDuration,
        isLive: isLive,
        arousalHistory: arousalHistory,
      );
    }

    try {
      final prompt = _buildPrompt(
        goal: goal,
        currentArousal: currentArousal,
        arousalLabel: arousalLabel,
        previousArousal: previousArousal,
        sessionDuration: sessionDuration,
        isLive: isLive,
        arousalHistory: arousalHistory,
      );

      final response = await http.post(
        Uri.parse(_defaultApiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': _getSystemPrompt(isLive),
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'max_tokens': isLive ? 100 : 300,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      } else {
        // Fallback to rule-based on API error
        return _generateRuleBasedFeedback(
          goal: goal,
          currentArousal: currentArousal,
          arousalLabel: arousalLabel,
          previousArousal: previousArousal,
          sessionDuration: sessionDuration,
          isLive: isLive,
          arousalHistory: arousalHistory,
        );
      }
    } catch (e) {
      // Fallback to rule-based on exception
      return _generateRuleBasedFeedback(
        goal: goal,
        currentArousal: currentArousal,
        arousalLabel: arousalLabel,
        previousArousal: previousArousal,
        sessionDuration: sessionDuration,
        isLive: isLive,
        arousalHistory: arousalHistory,
      );
    }
  }

  String _getSystemPrompt(bool isLive) {
    if (isLive) {
      return '''You are a calm, supportive meditation guide helping users with EEG biofeedback. 
Give brief, encouraging guidance (1-2 sentences max) based on their current brain state. 
Use simple, calming language. Focus on actionable breathing or focus techniques.
Never use technical jargon. Be warm and encouraging.''';
    } else {
      return '''You are a meditation coach reviewing a biofeedback session. 
Write a supportive paragraph (4-6 sentences) summarizing how the session went.
Include what went well, areas for improvement, and encouragement for future practice.
Be warm, specific, and constructive.''';
    }
  }

  String _buildPrompt({
    required MeditationGoal goal,
    required double currentArousal,
    required String arousalLabel,
    double? previousArousal,
    Duration? sessionDuration,
    required bool isLive,
    List<double>? arousalHistory,
  }) {
    final goalStr = goal == MeditationGoal.focus ? 'increase focus/alertness' : 'calm down and relax';
    final arousalPercent = (currentArousal * 100).toStringAsFixed(0);
    
    if (isLive) {
      String trend = 'stable';
      if (previousArousal != null) {
        final diff = currentArousal - previousArousal;
        if (diff > 0.05) trend = 'increasing';
        else if (diff < -0.05) trend = 'decreasing';
      }
      
      final isOnTrack = (goal == MeditationGoal.focus && trend == 'increasing') ||
                        (goal == MeditationGoal.calm && trend == 'decreasing');
      
      return '''User goal: $goalStr
Current arousal: $arousalPercent% ($arousalLabel)
Trend: $trend
On track: ${isOnTrack ? 'yes' : 'needs adjustment'}
Give brief guidance.''';
    } else {
      // Session summary
      final durationMin = sessionDuration?.inMinutes ?? 0;
      final startPercent = previousArousal != null ? (previousArousal * 100).toStringAsFixed(0) : 'N/A';
      final endPercent = arousalPercent;
      
      String overallTrend = 'stable';
      if (arousalHistory != null && arousalHistory.length > 1) {
        final first = arousalHistory.take(5).reduce((a, b) => a + b) / 5;
        final last = arousalHistory.skip(arousalHistory.length - 5).take(5).reduce((a, b) => a + b) / 5;
        if (last > first + 0.1) overallTrend = 'increased';
        else if (last < first - 0.1) overallTrend = 'decreased';
      }
      
      final achieved = (goal == MeditationGoal.focus && overallTrend == 'increased') ||
                       (goal == MeditationGoal.calm && overallTrend == 'decreased');
      
      return '''Session Summary:
Goal: $goalStr
Duration: $durationMin minutes
Starting arousal: $startPercent%
Ending arousal: $endPercent%
Overall trend: $overallTrend
Goal achieved: ${achieved ? 'yes' : 'partially/no'}
Write a supportive summary paragraph.''';
    }
  }

  /// Rule-based feedback fallback when no API is available
  String _generateRuleBasedFeedback({
    required MeditationGoal goal,
    required double currentArousal,
    required String arousalLabel,
    double? previousArousal,
    Duration? sessionDuration,
    required bool isLive,
    List<double>? arousalHistory,
  }) {
    if (isLive) {
      return _generateLiveRuleBasedFeedback(goal, currentArousal, arousalLabel, previousArousal);
    } else {
      return _generateSummaryRuleBasedFeedback(goal, currentArousal, previousArousal, sessionDuration, arousalHistory);
    }
  }

  String _generateLiveRuleBasedFeedback(
    MeditationGoal goal,
    double currentArousal,
    String arousalLabel,
    double? previousArousal,
  ) {
    String trend = 'stable';
    if (previousArousal != null) {
      final diff = currentArousal - previousArousal;
      if (diff > 0.05) trend = 'increasing';
      else if (diff < -0.05) trend = 'decreasing';
    }

    if (goal == MeditationGoal.focus) {
      // Goal is to increase arousal
      if (trend == 'increasing') {
        return _randomPick([
          "Great progress! Your focus is sharpening. Keep that energy flowing.",
          "Excellent! Your alertness is rising. Stay engaged with your breath.",
          "You're doing wonderfully. Feel the clarity building.",
        ]);
      } else if (trend == 'decreasing') {
        return _randomPick([
          "Let's bring more energy in. Try taking a deeper, more energizing breath.",
          "Open your eyes slightly wider. Engage your attention on a single point.",
          "Sit up taller and take a sharp inhale. Feel the alertness return.",
        ]);
      } else {
        if (currentArousal < 0.5) {
          return _randomPick([
            "Let's activate your focus. Try quick, energizing breaths - in through the nose, out through the mouth.",
            "Engage your mind. Visualize bright, white light filling your awareness.",
            "Increase your breathing pace slightly. Feel the energy building.",
          ]);
        } else {
          return _randomPick([
            "Good steady state. Maintain this awareness.",
            "You're in a good zone. Keep your attention present.",
            "Nice balance. Stay engaged and attentive.",
          ]);
        }
      }
    } else {
      // Goal is to decrease arousal (calm down)
      if (trend == 'decreasing') {
        return _randomPick([
          "Beautiful. You're settling into calm. Let each breath be slower than the last.",
          "Wonderful relaxation. Feel the tension melting away.",
          "You're doing great. Each moment brings more peace.",
        ]);
      } else if (trend == 'increasing') {
        return _randomPick([
          "Let's slow down. Take a long, slow exhale. Release any tension.",
          "Soften your shoulders. Let your jaw relax. Breathe out slowly.",
          "Close your eyes gently. Imagine a wave of calm washing over you.",
        ]);
      } else {
        if (currentArousal > 0.5) {
          return _randomPick([
            "Let's deepen the relaxation. Breathe in for 4, hold for 4, out for 6.",
            "Scan your body for tension. Wherever you find it, breathe into it and let go.",
            "Imagine sinking into a soft, warm cloud. Let gravity take all your weight.",
          ]);
        } else {
          return _randomPick([
            "You're in a peaceful state. Simply observe your breath.",
            "Beautiful calm. Just be present in this moment.",
            "Rest here. You're doing wonderfully.",
          ]);
        }
      }
    }
  }

  String _generateSummaryRuleBasedFeedback(
    MeditationGoal goal,
    double endArousal,
    double? startArousal,
    Duration? duration,
    List<double>? history,
  ) {
    final durationMin = duration?.inMinutes ?? 0;
    final goalStr = goal == MeditationGoal.focus ? 'enhancing focus' : 'calming down';
    
    String overallTrend = 'stable';
    bool achieved = false;
    
    if (startArousal != null) {
      final diff = endArousal - startArousal;
      if (goal == MeditationGoal.focus) {
        achieved = diff > 0.05;
        overallTrend = diff > 0.05 ? 'increased' : (diff < -0.05 ? 'decreased' : 'stable');
      } else {
        achieved = diff < -0.05;
        overallTrend = diff < -0.05 ? 'decreased' : (diff > 0.05 ? 'increased' : 'stable');
      }
    }

    if (achieved) {
      return '''Congratulations on completing your $durationMin-minute meditation session! You set out with the goal of $goalStr, and your brain responded beautifully. Your arousal index $overallTrend over the course of the session, showing that your practice was effective. This demonstrates good mind-body awareness and the ability to shift your mental state intentionally. Keep up this excellent work - with consistent practice, you'll find it easier and easier to reach your desired mental state. Consider increasing your session duration next time to deepen your practice.''';
    } else {
      return '''Great job completing your $durationMin-minute meditation session! While your arousal index remained relatively $overallTrend during this session, remember that meditation is a practice, and every session builds your skills. The fact that you showed up and dedicated time to your mental wellness is what matters most. For your next session focused on $goalStr, try experimenting with different breathing patterns or visualization techniques. Some days our minds respond differently than others - this is completely normal. Keep practicing, and you'll notice improvements over time.''';
    }
  }

  String _randomPick(List<String> options) {
    return options[DateTime.now().millisecond % options.length];
  }

  /// Speak text using TTS
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    
    await initTts();
    
    // Don't interrupt if already speaking
    if (_isSpeaking) return;
    
    _isSpeaking = true;
    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Clear feedback history
  void clearHistory() {
    _feedbackHistory.clear();
    _lastFeedbackTime = null;
  }

  /// Get feedback history
  List<Map<String, dynamic>> get feedbackHistory => List.from(_feedbackHistory);

  /// Dispose resources
  void dispose() {
    _tts.stop();
  }
}
