import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muse_headband_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(
      child: MuseHeadbandApp(),
    ));

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
