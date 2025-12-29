import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/device_selection_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MuseHeadbandApp(),
    ),
  );
}

class MuseHeadbandApp extends StatelessWidget {
  const MuseHeadbandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muse Headband Recorder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const DeviceSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
