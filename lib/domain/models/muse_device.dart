// Contact quality indicator. 1 = good, 2 = ok, 4 = bad contact.
class HsiValue {
  final int value;
  final bool isArtifactFree;

  const HsiValue({
    required this.value,
    required this.isArtifactFree,
  });

  HsiValue copyWith({
    int? value,
    bool? isArtifactFree,
  }) {
    return HsiValue(
      value: value ?? this.value,
      isArtifactFree: isArtifactFree ?? this.isArtifactFree,
    );
  }
}

// Represents a connected Muse headband.
class MuseDevice {
  final String id; // From SDK (MAC, UUID, etc.)
  final String name;
  final bool isConnected;
  final int batteryPercent;

  // Contact quality per channel
  final HsiValue tp9Hsi;
  final HsiValue af7Hsi;
  final HsiValue af8Hsi;
  final HsiValue tp10Hsi;

  const MuseDevice({
    required this.id,
    required this.name,
    this.isConnected = false,
    this.batteryPercent = 0,
    this.tp9Hsi = const HsiValue(value: 4, isArtifactFree: false),
    this.af7Hsi = const HsiValue(value: 4, isArtifactFree: false),
    this.af8Hsi = const HsiValue(value: 4, isArtifactFree: false),
    this.tp10Hsi = const HsiValue(value: 4, isArtifactFree: false),
  });

  MuseDevice copyWith({
    String? id,
    String? name,
    bool? isConnected,
    int? batteryPercent,
    HsiValue? tp9Hsi,
    HsiValue? af7Hsi,
    HsiValue? af8Hsi,
    HsiValue? tp10Hsi,
  }) {
    return MuseDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      isConnected: isConnected ?? this.isConnected,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      tp9Hsi: tp9Hsi ?? this.tp9Hsi,
      af7Hsi: af7Hsi ?? this.af7Hsi,
      af8Hsi: af8Hsi ?? this.af8Hsi,
      tp10Hsi: tp10Hsi ?? this.tp10Hsi,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuseDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
