// Runtime QA pass for the AI Coach (23-series), run against the REAL
// GlowUpApp + real appRouter at both the true mobile frame size (402x874)
// and a short desktop-debug height (402x640) — mirrors the manual QA
// script exactly: open Coach, chat send/receive, Plan, Mood, state
// persistence across navigation, and the Coach<->Today/Routines/Profile
// round trips.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/mood/models/mood_models.dart';
import 'package:glow_up/mood/state/mood_controller.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/routing/app_router.dart';

const _message = 'I need motivation for my workout today';

Future<ProviderContainer> _boot(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  container.read(onboardingControllerProvider.notifier).completeOnboarding();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  appRouter.go(AppRoutes.today);
  await tester.pumpAndSettle();
  return container;
}

void _runFullQaScript(Size size, String sizeLabel) {
  testWidgets('AI Coach full QA script at $sizeLabel', (tester) async {
    final container = await _boot(tester, size);
    addTearDown(container.dispose);

    // TEST 1 — Open Coach from the bottom nav.
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 1: no overflow/exception opening Coach',
    );
    expect(
      find.text('RECENT CHATS'),
      findsOneWidget,
      reason: 'TEST 1: real Coach hub, not a placeholder',
    );
    final coachTabStyle = tester.widget<Text>(find.text('Coach').last).style!;
    expect(
      coachTabStyle.fontWeight,
      FontWeight.w700,
      reason: 'TEST 1: Coach tab must render as the selected/highlighted tab',
    );

    // TEST 2 — Chat: type exact message, send, verify it appears verbatim.
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), _message);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 2: no overflow/exception in chat',
    );
    expect(
      find.text(_message),
      findsOneWidget,
      reason: 'TEST 2: message must appear verbatim',
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.controller!.text,
      isEmpty,
      reason: 'TEST 2: input clears after send',
    );
    expect(
      find.textContaining('not connected yet'),
      findsOneWidget,
      reason:
          'TEST 2: no fabricated live-AI response — only the honest not-connected notice',
    );

    // Back to hub.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('RECENT CHATS'), findsOneWidget);

    // TEST 3 — Plan.
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 3: no overflow/exception on Plan',
    );
    expect(find.text('Your AI Plan'), findsOneWidget);
    expect(find.text('Fitness'), findsOneWidget);
    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('Mindfulness'), findsOneWidget);
    expect(find.text('Hydration'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 3: Plan scrolls without overflow',
    );
    await tester.tap(find.text('Adjust Plan'));
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 3: Adjust Plan control responds without crashing',
    );
    await tester.ensureVisible(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(
      find.text('RECENT CHATS'),
      findsOneWidget,
      reason: 'TEST 3: Back returns to the Coach hub',
    );

    // TEST 4 — Mood. Seed one real check-in first so the honest,
    // real-data history view (not its empty state) is what this QA script
    // exercises — Mood History shows no fabricated content when there's
    // nothing logged yet, matching the same real-vs-empty split every
    // other module in this app follows.
    final moodController = container.read(moodControllerProvider.notifier);
    await moodController.ready;
    await moodController.logCheckIn(level: MoodLevel.good);
    await tester.tap(find.text('Mood'));
    // Mood History now reads real persisted data (moodControllerProvider),
    // so it has a brief AsyncLoading phase with an indeterminate
    // CircularProgressIndicator — pumpAndSettle would time out waiting for
    // that animation to stop, so this pumps a fixed number of frames
    // instead (matching the other async-controller test patterns in this
    // codebase, e.g. water_tod_and_accessibility_test.dart's `_bootWith`).
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 4: no overflow/exception on Mood',
    );
    expect(find.text('Mood History'), findsOneWidget);
    expect(
      find.text('MOOD TREND'),
      findsOneWidget,
      reason: 'TEST 4: Mood Trend renders',
    );
    expect(
      find.text('DAILY EMOTIONS'),
      findsOneWidget,
      reason: 'TEST 4: Daily Emotions renders',
    );
    expect(
      find.text('BEST DAY'),
      findsOneWidget,
      reason: 'TEST 4: Best Day stat renders',
    );
    expect(
      find.text('COMMON'),
      findsOneWidget,
      reason: 'TEST 4: Common emotion stat renders',
    );
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 4: Week/Month/Year controls respond without error',
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'TEST 4: Mood screen scrolls without overflow',
    );
    await tester.ensureVisible(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('RECENT CHATS'), findsOneWidget);

    // TEST 5 — Return to Chat, confirm the message survived navigating
    // away to Plan and Mood and back.
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(
      find.text(_message),
      findsOneWidget,
      reason: 'TEST 5: chat state must persist across navigation',
    );
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    // TEST 6 — Coach <-> Today / Routines / Profile round trips.
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(find.text('RECENT CHATS'), findsNothing);
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(
      find.text('RECENT CHATS'),
      findsOneWidget,
      reason: 'TEST 6: Coach -> Today -> Coach',
    );

    await tester.tap(find.text('Routines').last);
    await tester.pumpAndSettle();
    expect(find.text('RECENT CHATS'), findsNothing);
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(
      find.text('RECENT CHATS'),
      findsOneWidget,
      reason: 'TEST 6: Coach -> Routines -> Coach',
    );

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('RECENT CHATS'), findsNothing);
    // Profile is now the real screen with its own 4-tab BottomNavBar (no
    // more placeholder-only Back button) — return to Coach the same way
    // every other tab does, via its own Coach tab.
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();
    expect(
      find.text('RECENT CHATS'),
      findsOneWidget,
      reason:
          'TEST 6: Coach -> Profile -> Coach, via Profile\'s real bottom navigation',
    );

    // Chat state must still be intact after all that navigation.
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(
      find.text(_message),
      findsOneWidget,
      reason: 'chat state survives the full Test 6 navigation sweep',
    );

    expect(tester.takeException(), isNull);
  });
}

void main() {
  // TEST 4 (Mood) below is the first flow in this file backed by real
  // SharedPreferences-persisted state (moodControllerProvider) — every
  // other step here has no persistence dependency, so this mock was never
  // needed until now.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  _runFullQaScript(const Size(402, 874), '402x874');
  _runFullQaScript(const Size(402, 640), '402x640');
}
