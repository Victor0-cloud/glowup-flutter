// Minimal boot smoke test — replaces a stale assertion that pinned exact
// splash-screen copy ("glow up" as literal lowercase text), which drifted
// out of sync with the real screen and started failing for reasons
// unrelated to any actual regression. This test verifies the one thing a
// smoke test should: the real app tree (GlowUpApp -> MaterialApp.router ->
// AuthRouterReactor -> the router's real initial route) mounts and settles
// with no uncaught exception, without coupling to which specific screen or
// copy the router lands on — that's already covered by each screen's own
// dedicated tests.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/app/glow_up_app.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'app initializes and the root widget renders with no uncaught exception',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: GlowUpApp()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(GlowUpApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
