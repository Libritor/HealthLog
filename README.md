# MuseLog

Flutter app for recording EEG data from Muse S and Muse S Athena headbands. Connects over Bluetooth, shows live visualizations, and saves everything to CSV.

## What it does

- Connects to 2-4 Muse headbands at once
- Records raw EEG (256 Hz), band powers, fNIRS (Athena only), and motion data
- Shows live charts for everything
- Saves to CSV with timestamps, trigger markers, and all the sensor data you'd want

## Quick start

```bash
flutter pub get
flutter run
```

This runs in **demo mode** with fake devices and simulated data - useful for testing the UI without real hardware.

## Project layout

```
lib/
├── main.dart                              # App entry, theme setup
├── core/
│   └── constants.dart                     # CSV columns, sample rates, HSI colors
├── domain/
│   └── models/
│       ├── muse_device.dart               # Device + HSI value classes
│       ├── eeg_sample.dart                # Raw EEG (6 channels)
│       ├── band_power_sample.dart         # Delta/Theta/Alpha/Beta/Gamma
│       ├── fnirs_sample.dart              # 16-channel fNIRS (Athena)
│       ├── imu_sample.dart                # Gyro + accelerometer
│       └── session_config.dart            # Recording config + state
├── data/
│   ├── muse/
│   │   ├── muse_service.dart              # Abstract interface
│   │   ├── muse_repository.dart           # Mock data generator
│   │   ├── muse_platform_repository.dart  # Real SDK bridge
│   │   ├── muse_platform_channel.dart     # Platform channel definitions
│   │   └── osc_service.dart               # OSC streaming to VR
│   └── storage/
│       ├── csv_writer.dart                # Streaming CSV writer
│       └── file_storage_helper.dart       # File paths per platform
└── presentation/
    ├── providers/
    │   ├── device_provider.dart           # Scan/connect/stream providers
    │   ├── recording_provider.dart        # CSV recording state
    │   └── osc_streaming_provider.dart    # OSC output config
    ├── screens/
    │   ├── device_selection_screen.dart   # Pick headbands
    │   ├── recording_config_screen.dart   # Choose columns
    │   ├── live_session_screen.dart       # Recording + charts
    │   └── post_session_screen.dart       # Share/view files
    └── widgets/
        ├── hsi_indicator.dart             # Horseshoe contact quality
        ├── eeg_chart.dart                 # Scrolling EEG trace
        ├── band_power_chart.dart          # Bar chart
        ├── fnirs_chart.dart               # Oxygenation chart
        └── imu_chart.dart                 # Motion data
```

## Connecting real hardware

The app is set up to swap in the real Muse SDK without touching most of the codebase. You'll need to:

1. Get the LibMuse SDK from Interaxon (it's not public)
2. Drop the framework/aar into `ios/Runner/` or `android/app/libs/`
3. Hook up the platform channels in `MuseManager.swift` (iOS) or `MainActivity.kt` (Android)

The Dart side already has the interfaces ready - check `lib/data/muse/muse_service.dart`.

### iOS setup

Add `Muse.framework` to the Xcode project, then wire up the method/event channels. The app sends commands like `scan`, `connect`, `disconnect` and expects EEG/band power/etc streams back.

### Android setup

Add `libmuse_android.jar` to `android/app/libs/`, then do the same channel wiring in Kotlin.

There's example code in `lib/data/muse/muse_platform_channel.dart` showing exactly what data format the Dart side expects.

## CSV output

Files end up in:
- **Android**: `/storage/emulated/0/Android/data/com.example.muse_headband_app/files/muse_sessions/`
- **iOS**: App Documents folder

Named like `muse_session_20241228_143022_Muse1.csv`

Columns include timestamps, raw EEG, all the band powers (absolute and relative), HSI quality values, IMU, fNIRS, and battery. About 80 columns total - you can pick which ones to record.

## Architecture notes

Uses clean-ish architecture:
- **Domain**: Just data classes, no Flutter dependencies
- **Data**: SDK abstraction + file I/O
- **Presentation**: Riverpod providers + UI

The mock data generator in `muse_repository.dart` shows exactly how the real SDK data should flow.

## Running on devices

### iOS
1. Open in Xcode, set up signing
2. Add Bluetooth permission to Info.plist
3. `flutter run`

### Android
1. Bluetooth permissions are already in the manifest
2. `flutter run`

## Tests

```bash
flutter test
```

Mostly covers the data models and CSV formatting.

## Known issues

- In demo mode, you'll always see 2 fake devices appear
- Some tests are flaky (need real integration tests)
- fNIRS charts only show on Athena models

## Customization

Sample rates and display settings are in `lib/core/constants.dart`. Chart window sizes, decimation factors, etc.

To add new data columns:
1. Add the column name to `AppConstants.csvColumns`
2. Add the value to the relevant model's `toCsvValues()` method
3. Update `columnGroups` so users can toggle it in the UI

## License

MIT for the app code. The Muse SDK itself is proprietary - you need to get a license from Interaxon.

---

`flutter run` to try it out. Check `lib/data/muse/` for the SDK integration points.
