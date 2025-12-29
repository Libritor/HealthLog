class SessionConfig {
  final List<String> selectedDeviceIds;
  final Set<String> selectedColumns;
  final String sessionName;
  final String notes;
  final DateTime startTime;

  const SessionConfig({
    required this.selectedDeviceIds,
    required this.selectedColumns,
    required this.sessionName,
    this.notes = '',
    required this.startTime,
  });

  SessionConfig copyWith({
    List<String>? selectedDeviceIds,
    Set<String>? selectedColumns,
    String? sessionName,
    String? notes,
    DateTime? startTime,
  }) {
    return SessionConfig(
      selectedDeviceIds: selectedDeviceIds ?? this.selectedDeviceIds,
      selectedColumns: selectedColumns ?? this.selectedColumns,
      sessionName: sessionName ?? this.sessionName,
      notes: notes ?? this.notes,
      startTime: startTime ?? this.startTime,
    );
  }
}

enum RecordingState {
  idle,
  recording,
  paused,
  stopped,
}

// User-placed marker during recording.
class TriggerEvent {
  final DateTime timestamp;
  final int triggerCount;
  final String? note;

  const TriggerEvent({
    required this.timestamp,
    required this.triggerCount,
    this.note,
  });
}
