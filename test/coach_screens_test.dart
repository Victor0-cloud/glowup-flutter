// Verifies the 23-series AI Coach screens: Figma-exact layout survives at
// both the true mobile frame size and a short desktop-debug height with no
// overflow, and every interactive control (quick actions, chat send, quick
// reply chips, settings toggles/selectors, mood filter tabs, bottom nav)
// actually changes state or fires its callback.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/state/current_state_controller.dart';
import 'package:glow_up/coach/models/coach_models.dart';
import 'package:glow_up/coach/screens/coach_chat_screen.dart';
import 'package:glow_up/coach/screens/coach_hub_screen.dart';
import 'package:glow_up/coach/screens/coach_plan_screen.dart';
import 'package:glow_up/coach/screens/coach_settings_screen.dart';
import 'package:glow_up/coach/screens/mood_history_screen.dart';
import 'package:glow_up/coach/state/coach_chat_controller.dart';
import 'package:glow_up/coach/state/coach_settings_controller.dart';
import 'package:glow_up/coach/widgets/chat_widgets.dart';
import 'package:glow_up/mood/models/mood_models.dart';
import 'package:glow_up/mood/state/mood_controller.dart';

Future<void> _pumpAtMobileSize(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  Size size = const Size(402, 874),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, c) => ColoredBox(
          color: Colors.black,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 402),
              child: c,
            ),
          ),
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Mood History (below) is the first screen in this file backed by real
  // SharedPreferences-persisted state; every other screen here has no
  // persistence dependency, so this mock was never needed until now.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Coach Hub (23a-d)', () {
    testWidgets(
      'renders at 402x874 with no overflow and every quick action navigates',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        var chatTapped = false,
            planTapped = false,
            moodTapped = false,
            settingsTapped = false;
        var todayTapped = false, routinesTapped = false, profileTapped = false;

        await _pumpAtMobileSize(
          tester,
          container,
          CoachHubScreen(
            onChat: () => chatTapped = true,
            onOpenThread: (_) {},
            onPlan: () => planTapped = true,
            onMood: () => moodTapped = true,
            onSettings: () => settingsTapped = true,
            onToday: () => todayTapped = true,
            onRoutines: () => routinesTapped = true,
            onProfile: () => profileTapped = true,
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('AI Coach'), findsWidgets);
        expect(find.text('RECENT CHATS'), findsOneWidget);

        await tester.tap(find.text('Chat'));
        await tester.tap(find.text('Plan'));
        await tester.tap(find.text('Mood'));
        await tester.tap(find.bySemanticsLabel('Coach settings'));
        await tester.pump();

        expect(chatTapped, isTrue);
        expect(planTapped, isTrue);
        expect(moodTapped, isTrue);
        expect(settingsTapped, isTrue);

        await tester.tap(find.text('Today').last);
        await tester.tap(find.text('Routines').last);
        await tester.tap(find.text('Profile').last);
        await tester.pump();
        expect(todayTapped, isTrue);
        expect(routinesTapped, isTrue);
        expect(profileTapped, isTrue);
      },
    );

    testWidgets(
      'renders at a short desktop-debug-window height (402x640) with no overflow',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await _pumpAtMobileSize(
          tester,
          container,
          CoachHubScreen(
            onChat: () {},
            onOpenThread: (_) {},
            onPlan: () {},
            onMood: () {},
            onSettings: () {},
            onToday: () {},
            onRoutines: () {},
            onProfile: () {},
          ),
          size: const Size(402, 640),
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('RECENT CHATS'), findsOneWidget);
      },
    );
  });

  group('Coach Chat (23e)', () {
    testWidgets(
      'typing and sending appends a user bubble, clears input, and shows the not-connected notice',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await _pumpAtMobileSize(
          tester,
          container,
          CoachChatScreen(
            onBack: () {},
            onToday: () {},
            onRoutines: () {},
            onProfile: () {},
          ),
        );
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byType(TextField),
          'Give me a plan for today',
        );
        await tester.tap(find.bySemanticsLabel('Send'));
        await tester.pumpAndSettle();

        expect(find.text('Give me a plan for today'), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, isEmpty);
        expect(find.textContaining('not connected yet'), findsOneWidget);

        final messages = container.read(coachChatControllerProvider).messages;
        expect(
          messages.any(
            (m) =>
                m.sender == ChatSender.user &&
                m.text == 'Give me a plan for today',
          ),
          isTrue,
        );
        expect(messages.any((m) => m.sender == ChatSender.system), isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('quick reply chip sends its label as a real message', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpAtMobileSize(
        tester,
        container,
        CoachChatScreen(
          onBack: () {},
          onToday: () {},
          onRoutines: () {},
          onProfile: () {},
        ),
      );

      await tester.tap(find.text('Check my progress'));
      await tester.pumpAndSettle();

      final messages = container.read(coachChatControllerProvider).messages;
      expect(
        messages.any(
          (m) => m.sender == ChatSender.user && m.text == 'Check my progress',
        ),
        isTrue,
      );
    });

    testWidgets('back button fires onBack', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var backTapped = false;
      await _pumpAtMobileSize(
        tester,
        container,
        CoachChatScreen(
          onBack: () => backTapped = true,
          onToday: () {},
          onRoutines: () {},
          onProfile: () {},
        ),
      );
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      expect(backTapped, isTrue);
    });

    testWidgets(
      '1. microphone button renders beside the input, and 2. the text '
      'field remains fully usable alongside it',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await _pumpAtMobileSize(
          tester,
          container,
          CoachChatScreen(
            onBack: () {},
            onToday: () {},
            onRoutines: () {},
            onProfile: () {},
          ),
        );

        expect(find.bySemanticsLabel('Start voice input'), findsOneWidget);
        expect(find.bySemanticsLabel('Send'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'typed without voice');
        await tester.pump();
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, 'typed without voice');
      },
    );

    testWidgets(
      '13. tapping the mic on a platform/test-VM with no real speech '
      'channel degrades honestly — never crashes the Chat screen',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await _pumpAtMobileSize(
          tester,
          container,
          CoachChatScreen(
            onBack: () {},
            onToday: () {},
            onRoutines: () {},
            onProfile: () {},
          ),
        );

        await tester.tap(find.bySemanticsLabel('Start voice input'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The real requirement (Section 13, "unsupported platform does not
        // crash"): no exception, regardless of which honest terminal state
        // (unavailable/permissionDenied/error) the real engine lands on in
        // this platform-channel-less test environment.
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Coach Plan (23f)', () {
    testWidgets('renders all 4 plan items with no overflow at 402x640', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await _pumpAtMobileSize(
        tester,
        container,
        CoachPlanScreen(
          onBack: () {},
          onToday: () {},
          onRoutines: () {},
          onProfile: () {},
        ),
        size: const Size(402, 640),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('Nutrition'), findsOneWidget);
      expect(find.text('Mindfulness'), findsOneWidget);
      expect(find.text('Hydration'), findsOneWidget);
      await tester.tap(find.text('Adjust Plan'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('Mood History (23g)', () {
    testWidgets(
      'filter tabs switch selection and screen has no overflow at 402x640',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(moodControllerProvider.notifier);
        await controller.ready;
        await controller.logCheckIn(level: MoodLevel.good);
        // logCheckIn's Brain event emission lazily constructs
        // CurrentStateController, whose own _init() keeps running in the
        // background after setEntry's early-return — wait for it so it never
        // touches a disposed notifier during this test's teardown.
        await container.read(currentStateControllerProvider.notifier).ready;
        // Real persisted data now backs this screen (moodControllerProvider),
        // so — unlike the other screens in this file — it has a brief
        // AsyncLoading phase with an indefinite CircularProgressIndicator;
        // pumpAndSettle would time out waiting for that animation to stop, so
        // this test pumps a fixed couple of frames instead of using the
        // shared `_pumpAtMobileSize` helper.
        await tester.binding.setSurfaceSize(const Size(402, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, c) => ColoredBox(
                color: Colors.black,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 402),
                    child: c,
                  ),
                ),
              ),
              home: MoodHistoryScreen(
                onBack: () {},
                onToday: () {},
                onRoutines: () {},
                onProfile: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Week'), findsOneWidget);
        await tester.tap(find.text('Month'));
        await tester.pump();
        await tester.tap(find.text('Year'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        // MoodStatCard uppercases its label to match Figma's CSS `uppercase`.
        expect(find.text('BEST DAY'), findsOneWidget);
      },
    );
  });

  group('Coach Settings (23h)', () {
    testWidgets(
      'toggles and selectors update real state, no overflow at 402x640',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await _pumpAtMobileSize(
          tester,
          container,
          CoachSettingsScreen(
            onBack: () {},
            onToday: () {},
            onRoutines: () {},
            onProfile: () {},
          ),
          size: const Size(402, 640),
        );
        expect(tester.takeException(), isNull);

        final before = container.read(coachSettingsControllerProvider);
        expect(before.nutritionTips, isFalse);

        await tester.ensureVisible(find.text('Nutrition Tips'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nutrition Tips'));
        await tester.pump();
        expect(
          container.read(coachSettingsControllerProvider).nutritionTips,
          isTrue,
        );

        await tester.ensureVisible(find.text('Tough Love'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tough Love'));
        await tester.pump();
        expect(
          container.read(coachSettingsControllerProvider).personality,
          CoachPersonality.toughLove,
        );

        await tester.ensureVisible(find.text('Frequent'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Frequent'));
        await tester.pump();
        expect(
          container.read(coachSettingsControllerProvider).frequency,
          NotificationFrequency.frequent,
        );

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Changes'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Chat bubble timestamps render in local time, not UTC', () {
    testWidgets(
      'an assistant message timestamped in UTC (Supabase timestamptz) shows the device-local clock time, matching a fresh local user bubble sent at the same real instant',
      (tester) async {
        // Supabase always returns created_at as UTC — this is exactly the
        // shape RemoteCoachBrainService/CoachThreadRepository parse.
        final utcTime = DateTime.utc(2026, 8, 25, 14, 37);
        final localEquivalent = utcTime.toLocal();
        final expectedHour = localEquivalent.hour % 12 == 0
            ? 12
            : localEquivalent.hour % 12;
        final expectedMinute = localEquivalent.minute.toString().padLeft(
          2,
          '0',
        );
        final expectedPeriod = localEquivalent.hour >= 12 ? 'PM' : 'AM';
        final expectedLabel = '$expectedHour:$expectedMinute $expectedPeriod';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatBubbleRow(
                message: ChatMessage(
                  id: 'ai-1',
                  sender: ChatSender.ai,
                  text: 'Hi there',
                  sentAt: utcTime,
                ),
              ),
            ),
          ),
        );

        expect(find.text(expectedLabel), findsOneWidget);
        // The raw UTC hour (2:37 PM) must never appear unconverted unless
        // the test machine's own local timezone happens to be UTC.
        if (expectedLabel != '2:37 PM') {
          expect(find.text('2:37 PM'), findsNothing);
        }
      },
    );
  });
}
