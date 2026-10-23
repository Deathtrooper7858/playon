import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playon/theme.dart';

void main() {
  group('PlayOnTheme Tests', () {
    test('theme configuration adheres to dark nebula palette', () {
      final theme = PlayOnTheme.theme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, PlayOnTheme.bgDeep);
      expect(theme.colorScheme.primary, PlayOnTheme.purplePrimary);
      expect(theme.colorScheme.secondary, PlayOnTheme.pinkAccent);
      expect(theme.useMaterial3, isTrue);
    });

    test('glowShadow produces proper BoxShadow list', () {
      final shadows = PlayOnTheme.glowShadow(
        color: PlayOnTheme.cyanAccent,
        blur: 15,
        spread: 2,
      );
      expect(shadows, hasLength(1));
      expect(shadows.first.blurRadius, 15);
      expect(shadows.first.spreadRadius, 2);
    });

    testWidgets('App renders themed widget tree correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: PlayOnTheme.theme,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('PlayOn Test'),
            ),
            body: Center(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: PlayOnTheme.primaryGradient,
                ),
                child: const Text('Nebula Music'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('PlayOn Test'), findsOneWidget);
      expect(find.text('Nebula Music'), findsOneWidget);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, isNull); // Falls back to theme background
    });
  });
}
