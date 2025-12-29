# Contributing

Hey, thanks for wanting to help out!

## Setup

1. Clone and run `flutter pub get`
2. For Android release builds, copy `android/key.properties.example` to `android/key.properties` and fill in your keystore info

## Before you commit

- Run `flutter analyze` 
- Run `flutter test`
- Make sure stuff actually works on a device if you changed UI

## Code style

Nothing crazy - just follow the [Dart style guide](https://dart.dev/guides/language/effective-dart). Keep comments short. Use `// TODO:` if something's unfinished.

## PRs

1. Branch off `main`
2. Do your thing
3. Make sure analyze/test pass
4. Open a merge request with a decent description of what you changed

## Working on SDK stuff

The native Muse SDK talks to Flutter via platform channels:
- **iOS**: `ios/Runner/MuseManager.swift`
- **Android**: `android/app/src/main/kotlin/`
- **macOS**: `macos/Runner/MuseManager.swift`

If you're adding new sensor types or whatever:
1. Update the native code on both platforms
2. Add a model in `lib/domain/models/`
3. Update `lib/data/muse/muse_service.dart`

## Questions?

Just open an issue. Happy to help with architecture questions or anything that's confusing.
