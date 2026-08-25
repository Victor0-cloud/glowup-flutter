// Covers AU05 Profile Setup directly: unit-aware height/weight validation
// (the real root cause of "Continue does nothing" when a user types "5ft"
// into a field labeled "Height (cm)"), optional weight/photo never
// blocking Continue, a save error surfacing visibly rather than silently,
// and the pure metric<->imperial conversion helpers AU05 relies on.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/auth/screens/au05_profile_setup_screen.dart';
import 'package:glow_up/profile/models/profile_models.dart';
import 'package:glow_up/profile/utils/unit_conversion.dart';

Future<void> _setSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('metric height validation', () {
    testWidgets('a valid numeric height in cm is accepted and saved', (
      tester,
    ) async {
      await _setSurface(tester);
      ProfileDetails? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            initialDetails: const ProfileDetails(),
            units: AppUnits.metric,
            onContinue: (d) => saved = d,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<Gender>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '155');
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(saved, isNotNull, reason: 'requirement 5: valid cm height saves');
      expect(saved!.heightCm, 155);
    });

    testWidgets(
      'typing "5ft" into the metric height field shows a visible error and never silently blocks Continue',
      (tester) async {
        await _setSurface(tester);
        ProfileDetails? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileSetupScreen(
              initialDetails: const ProfileDetails(),
              units: AppUnits.metric,
              onContinue: (d) => saved = d,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Select date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButton<Gender>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Female').last);
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(1), '5ft');
        await tester.pump();

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(
          saved,
          isNull,
          reason: 'invalid height must never be silently saved',
        );
        expect(
          find.text('Enter height in centimeters'),
          findsOneWidget,
          reason: 'requirement 6: a real visible validation message appears',
        );
      },
    );
  });

  group('imperial mode', () {
    testWidgets('feet + inches height is accepted, converted, and saved', (
      tester,
    ) async {
      await _setSurface(tester);
      ProfileDetails? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            initialDetails: const ProfileDetails(),
            units: AppUnits.imperial,
            onContinue: (d) => saved = d,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Height (cm)'),
        findsNothing,
        reason: 'imperial mode must never show a cm-labeled field',
      );
      expect(find.text('Feet'), findsOneWidget);
      expect(find.text('Inches'), findsOneWidget);

      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<Gender>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '5');
      await tester.enterText(fields.at(2), '7');
      await tester.pump();

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(saved, isNotNull, reason: 'requirement 7: ft/in is accepted');
      expect(saved!.heightCm, closeTo(170.18, 0.5));
    });
  });

  group('weight and photo stay genuinely optional', () {
    testWidgets('Continue succeeds with height set and weight left blank', (
      tester,
    ) async {
      await _setSurface(tester);
      ProfileDetails? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            initialDetails: const ProfileDetails(),
            units: AppUnits.metric,
            onContinue: (d) => saved = d,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Select date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<Gender>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '160');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(
        saved,
        isNotNull,
        reason: 'requirement 8: blank weight never blocks Continue',
      );
      expect(saved!.weightKg, isNull);
    });

    testWidgets(
      'Continue succeeds with no profile photo chosen (photo stays optional)',
      (tester) async {
        await _setSurface(tester);
        ProfileDetails? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileSetupScreen(
              initialDetails: const ProfileDetails(),
              units: AppUnits.metric,
              onContinue: (d) => saved = d,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Select date'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<Gender>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Female').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(1), '160');
        await tester.pump();

        await tester.tap(find.text('Continue'));
        await tester.pump();

        expect(
          saved,
          isNotNull,
          reason: 'requirement 9: no photo never blocks Continue',
        );
        expect(saved!.photoPath, isNull);
      },
    );
  });

  group('save failure is shown visibly, never silent', () {
    testWidgets('a non-null errorText renders on screen', (tester) async {
      await _setSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            initialDetails: const ProfileDetails(),
            units: AppUnits.metric,
            errorText: 'Could not save your profile: disk full',
            onContinue: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(
        find.textContaining('Could not save your profile'),
        findsOneWidget,
        reason: 'requirement 12: a real failure is visible, never silent',
      );
    });
  });

  group('unit conversion helpers are correct', () {
    test('feetInchesToCm', () {
      expect(feetInchesToCm(5, 7), closeTo(170.18, 0.01));
      expect(feetInchesToCm(6, 0), closeTo(182.88, 0.01));
    });

    test('cmToFeetAndInches round-trips with feetInchesToCm', () {
      final (feet, inches) = cmToFeetAndInches(170.18);
      expect(feet, 5);
      expect(inches, closeTo(7, 0.1));
    });

    test('lbToKg / kgToLb are inverses', () {
      expect(lbToKg(154), closeTo(69.85, 0.1));
      expect(kgToLb(70), closeTo(154.32, 0.1));
    });
  });
}
