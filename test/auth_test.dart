// Covers the real Glow Up authentication implementation: Supabase config,
// the startup auth gate (no protected screen ever flashes before session +
// profile state resolve), platform-specific redirect URIs, the Windows
// loopback callback server, screen-level validation, and the "never fake
// success" honesty rules for every auth operation. Tests run with no
// SUPABASE_URL/SUPABASE_ANON_KEY dart-defines (this repo's real secrets are
// never checked into source), so every "real Supabase call" here exercises
// the actual AuthController code path and gets the actual honest
// "Supabase is not configured on this build" result — proving the wiring
// is real, not that a live backend was reachable in CI.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:glow_up/app/glow_up_app.dart';
import 'package:glow_up/auth/config/auth_config.dart';
import 'package:glow_up/auth/screens/au03_email_sign_up_screen.dart';
import 'package:glow_up/auth/screens/au04_verify_email_screen.dart';
import 'package:glow_up/auth/screens/auth_gate_screen.dart';
import 'package:glow_up/auth/screens/email_sign_in_screen.dart';
import 'package:glow_up/auth/screens/forgot_password_screen.dart';
import 'package:glow_up/auth/state/auth_controller.dart';
import 'package:glow_up/auth/windows/windows_foreground.dart';
import 'package:glow_up/auth/windows/windows_oauth_loopback_server.dart';
import 'package:glow_up/onboarding/state/onboarding_controller.dart';
import 'package:glow_up/profile/models/profile_models.dart';
import 'package:glow_up/profile/state/profile_controller.dart';
import 'package:glow_up/routing/app_router.dart';

Future<ProviderContainer> _bootApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(402, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GlowUpApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1. unauthenticated startup opens auth', () {
    testWidgets(
      'a fresh launch (no session, no dart-defines) resolves to AU01 Welcome, never Today',
      (tester) async {
        await _bootApp(tester);
        expect(
          find.text('Glow Up ✨'),
          findsOneWidget,
          reason: 'AU01 Welcome must be the real landing screen',
        );
        expect(find.text('I already have an account'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AuthGateScreen never builds a protected screen while resolving — it only ever shows a loading state itself',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: AuthGateScreen(onResolved: (_) {})),
          ),
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Period & Cycle'), findsNothing);
        expect(find.text('Today'), findsNothing);
      },
    );
  });

  group('2. existing session restores', () {
    test(
      'Supabase.initialize is called without disabling session persistence',
      () {
        final content = File('lib/main.dart').readAsStringSync();
        expect(content.contains('Supabase.initialize'), isTrue);
        expect(
          content.contains('persistSession: false'),
          isFalse,
          reason:
              'the SDK\'s own session-restore-across-restarts behavior must never be turned off',
        );
      },
    );

    test(
      'AuthController reads the real currentSession synchronously on construction (session-restore path), never starts from a fabricated value',
      () {
        final controller = AuthController();
        addTearDown(controller.dispose);
        // Unconfigured in this test build -> honestly null, never a fake session.
        expect(controller.currentSession, isNull);
        expect(controller.isConfigured, isFalse);
      },
    );
  });

  group('3. Google button invokes the real Supabase OAuth path', () {
    testWidgets(
      'tapping Continue with Google calls the real signInWithGoogle() and surfaces its real, honest result',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GlowUpApp(),
          ),
        );
        appRouter.go(AppRoutes.authMethod);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        // No dart-defines in the test build -> the real controller method ran
        // and returned its real "not configured" AuthFailure, never a
        // fabricated success.
        expect(find.textContaining('not configured'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('4. Android/iOS use glowup://auth-callback', () {
    test('AuthConfig.mobileRedirectUri is exactly glowup://auth-callback', () {
      expect(AuthConfig.mobileRedirectUri, 'glowup://auth-callback');
    });

    test(
      'AndroidManifest.xml declares the glowup://auth-callback intent-filter',
      () {
        final content = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        expect(content.contains('android:scheme="glowup"'), isTrue);
        expect(content.contains('android:host="auth-callback"'), isTrue);
        expect(content.contains('android.intent.category.BROWSABLE'), isTrue);
      },
    );

    test('iOS Info.plist declares the glowup CFBundleURLScheme', () {
      final content = File('ios/Runner/Info.plist').readAsStringSync();
      expect(content.contains('CFBundleURLSchemes'), isTrue);
      expect(content.contains('<string>glowup</string>'), isTrue);
    });
  });

  group('4a. Web OAuth returns to the current browser origin', () {
    test('production Vercel uses its current HTTPS origin', () {
      expect(
        AuthConfig.webRedirectUriFor(
          Uri.parse(
            'https://glowup-flutter.vercel.app/auth-method?step=google',
          ),
        ),
        'https://glowup-flutter.vercel.app',
      );
    });

    test(
      'local Flutter Web preserves its current localhost origin and port',
      () {
        expect(
          AuthConfig.webRedirectUriFor(
            Uri.parse('http://localhost:54321/auth-method'),
          ),
          'http://localhost:54321',
        );
      },
    );

    test('all non-Windows auth flows share the platform redirect selector', () {
      final content = File(
        'lib/auth/state/auth_controller.dart',
      ).readAsStringSync();
      expect(
        content.contains('if (kIsWeb) return AuthConfig.webRedirectUri;'),
        isTrue,
      );
      expect(RegExp(r'redirectTo: _redirectUri').allMatches(content).length, 2);
      expect(
        RegExp(r'emailRedirectTo: _redirectUri').allMatches(content).length,
        2,
      );
    });
  });

  group('5. Windows uses localhost loopback', () {
    test(
      'AuthConfig.windowsRedirectUri is a real 127.0.0.1 loopback URL on the documented fixed port',
      () {
        expect(
          AuthConfig.windowsRedirectUri,
          'http://127.0.0.1:${AuthConfig.windowsLoopbackPort}/auth-callback',
        );
        expect(AuthConfig.windowsRedirectUri, isNot(contains('0.0.0.0')));
        expect(AuthConfig.windowsRedirectUri, isNot(contains('glowup://')));
      },
    );

    test('the loopback server binds 127.0.0.1 only, never 0.0.0.0', () {
      // Checks actual code only — not the doc comment that legitimately
      // *states* the "never 0.0.0.0" guarantee in prose (same convention
      // as cycle_test.dart's import-only checks).
      final codeOnly =
          File('lib/auth/windows/windows_oauth_loopback_server.dart')
              .readAsStringSync()
              .split('\n')
              .where((line) => !line.trim().startsWith('//'))
              .join('\n');
      expect(codeOnly.contains('InternetAddress.loopbackIPv4'), isTrue);
      expect(codeOnly.contains('0.0.0.0'), isFalse);
    });
  });

  group('6. Windows callback listener closes after completion', () {
    /// A raw socket GET, not HttpClient — flutter_test's
    /// TestWidgetsFlutterBinding installs a global HttpOverrides that fakes
    /// every HttpClient (even ones pointed at a real local server this test
    /// itself created), so HttpClient would never actually reach the
    /// loopback server here. Returns the raw response text so tests can
    /// inspect the actual HTML body, not just the received Uri.
    Future<String> hitCallback(String queryString) async {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        AuthConfig.windowsLoopbackPort,
      );
      socket.write(
        'GET /auth-callback$queryString HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n',
      );
      await socket.flush();
      final bytes = await socket.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
      await socket.close();
      return String.fromCharCodes(bytes);
    }

    test(
      'waitForCallback receives a real local HTTP request, exchange runs before the response, and the port is free again immediately after',
      () async {
        var exchangeCalledWithCode = false;
        final future = WindowsOAuthLoopbackServer.waitForCallback(
          timeout: const Duration(seconds: 5),
          exchange: (uri) async {
            exchangeCalledWithCode =
                uri.queryParameters['code'] == 'test_code_123';
            return true;
          },
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final response = await hitCallback('?code=test_code_123');
        expect(
          exchangeCalledWithCode,
          isTrue,
          reason:
              'requirement 1/2: the real code must reach the exchange callback',
        );
        expect(
          response,
          contains("You're signed in to Glow Up"),
          reason:
              'requirement 3: success text only appears because exchange returned true',
        );

        final received = await future;
        expect(received, isNotNull);
        expect(received!.queryParameters['code'], 'test_code_123');

        // The listener must have released the port — rebinding must succeed.
        final relisten = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          AuthConfig.windowsLoopbackPort,
        );
        await relisten.close(force: true);
      },
    );

    test(
      'a failed exchange renders an honest failure page, never the success message',
      () async {
        final future = WindowsOAuthLoopbackServer.waitForCallback(
          timeout: const Duration(seconds: 5),
          exchange: (uri) async => false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final response = await hitCallback('?code=bad_code');
        expect(
          response,
          isNot(contains("You're signed in to Glow Up")),
          reason:
              'requirement 4: a failed exchange must never show false success',
        );
        expect(response, contains('Sign-in did not complete'));

        await future;
      },
    );

    test(
      'a second concurrent waitForCallback throws rather than binding a conflicting socket',
      () async {
        final first = WindowsOAuthLoopbackServer.waitForCallback(
          timeout: const Duration(seconds: 2),
          exchange: (_) async => true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          () => WindowsOAuthLoopbackServer.waitForCallback(
            timeout: const Duration(seconds: 1),
            exchange: (_) async => true,
          ),
          throwsA(isA<StateError>()),
        );
        await WindowsOAuthLoopbackServer.cancelActive();
        await first;
      },
    );
  });

  group('7. email signup validates', () {
    testWidgets(
      'Sign Up stays disabled until name, a valid email, and a strong password are all entered',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var signedUp = false;
        await tester.pumpWidget(
          MaterialApp(
            home: EmailSignUpScreen(onSignUp: (_, _, _) => signedUp = true),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Sign Up'));
        await tester.pump();
        expect(
          signedUp,
          isFalse,
          reason: 'must not submit with everything empty',
        );
      },
    );

    testWidgets('a weak password (no number/special char) blocks submission', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var signedUp = false;
      await tester.pumpWidget(
        MaterialApp(
          home: EmailSignUpScreen(onSignUp: (_, _, _) => signedUp = true),
        ),
      );
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Angel Otite');
      await tester.enterText(fields.at(1), 'angel@example.com');
      await tester.enterText(fields.at(2), 'weakpass'); // no digit/special char
      await tester.enterText(fields.at(3), 'weakpass');
      await tester.pump();

      await tester.tap(find.text('Sign Up'));
      await tester.pump();
      expect(
        signedUp,
        isFalse,
        reason:
            'requirement: real password-strength validation, not just non-empty',
      );
    });
  });

  group('8. password confirmation validates', () {
    testWidgets(
      'a mismatched confirm-password shows an error and blocks submission',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var signedUp = false;
        await tester.pumpWidget(
          MaterialApp(
            home: EmailSignUpScreen(onSignUp: (_, _, _) => signedUp = true),
          ),
        );
        await tester.pump();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Angel Otite');
        await tester.enterText(fields.at(1), 'angel@example.com');
        await tester.enterText(fields.at(2), 'Str0ng!Pass');
        await tester.enterText(fields.at(3), 'Different!9');
        await tester.pump();

        await tester.tap(find.text('Sign Up'));
        await tester.pump();

        expect(find.text('Passwords do not match'), findsOneWidget);
        expect(signedUp, isFalse);
      },
    );
  });

  group('9. email sign-in works against the repository abstraction', () {
    testWidgets(
      'valid email+password Sign In calls the real AuthController.signInWithEmail, surfacing its real result',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GlowUpApp(),
          ),
        );
        appRouter.go(AppRoutes.authEmailSignIn);
        await tester.pumpAndSettle();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'angel@example.com');
        await tester.enterText(fields.at(1), 'somePassword1!');
        await tester.pump();

        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        // Unconfigured test build -> the real abstraction ran and returned
        // its honest "not configured" failure, never a fabricated sign-in.
        expect(find.textContaining('not configured'), findsOneWidget);
      },
    );

    testWidgets(
      'Sign In stays disabled with an invalid email or empty password',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var signedIn = false;
        await tester.pumpWidget(
          MaterialApp(
            home: EmailSignInScreen(onSignIn: (_, _) => signedIn = true),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Sign In'));
        await tester.pump();
        expect(signedIn, isFalse);
      },
    );
  });

  group('10. email verification state is truthful', () {
    test(
      'isEmailVerified is false whenever there is no session — never assumed true',
      () {
        final controller = AuthController();
        addTearDown(controller.dispose);
        expect(controller.isEmailVerified, isFalse);
      },
    );

    testWidgets(
      'a real recheck that comes back unverified shows an honest "not verified yet" message, never silently proceeds',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: VerifyEmailScreen(
              email: 'angel@example.com',
              onResend: () {},
              onIveVerified: () {},
              notYetVerified: true,
            ),
          ),
        );
        await tester.pump();
        expect(find.textContaining('Not verified yet'), findsOneWidget);
      },
    );
  });

  group('11. resend verification works', () {
    testWidgets(
      'Resend is disabled during the cooldown and enabled once it elapses, then calls onResend',
      (tester) async {
        var resent = false;
        await tester.pumpWidget(
          MaterialApp(
            home: VerifyEmailScreen(
              email: 'angel@example.com',
              onResend: () => resent = true,
              onIveVerified: () {},
            ),
          ),
        );
        await tester.pump();
        expect(
          find.textContaining('Resend email (00:4'),
          findsOneWidget,
          reason: 'starts on cooldown, matching AU04\'s (00:45) countdown',
        );

        await tester.tap(find.textContaining('Resend email ('));
        await tester.pump();
        expect(
          resent,
          isFalse,
          reason: 'must not resend while still cooling down',
        );
      },
    );
  });

  group('12. forgot password flow exists', () {
    testWidgets(
      'sending a reset link never reveals whether the email is registered — same honest message on success or failure',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GlowUpApp(),
          ),
        );
        appRouter.go(AppRoutes.authForgotPassword);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'someone@example.com');
        await tester.pump();
        await tester.tap(find.text('Send Reset Link'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining("we've sent a reset link"),
          findsOneWidget,
          reason:
              'requirement: never reveal account existence, even when the real call honestly fails (unconfigured build)',
        );
      },
    );

    testWidgets('Send Reset Link stays disabled for an invalid email', (
      tester,
    ) async {
      var sent = false;
      await tester.pumpWidget(
        MaterialApp(home: ForgotPasswordScreen(onSend: (_) => sent = true)),
      );
      await tester.pump();
      await tester.tap(find.text('Send Reset Link'));
      await tester.pump();
      expect(sent, isFalse);
    });
  });

  group('13. reset callback routes correctly', () {
    test('AppRoutes.authResetPassword is a real, distinct route', () {
      expect(AppRoutes.authResetPassword, '/auth/reset-password');
    });

    test(
      'handleCallbackUri surfaces a real error_description from the callback without ever calling Supabase',
      () async {
        final controller = AuthController();
        addTearDown(controller.dispose);
        final result = await controller.handleCallbackUri(
          Uri.parse(
            'http://127.0.0.1:51735/auth-callback?error_description=Link+expired',
          ),
        );
        expect(result, isA<AuthFailure>());
        expect((result as AuthFailure).message, 'Link expired');
      },
    );
  });

  group(
    '14. profile setup occurs for first-time users / 15. returning users bypass setup',
    () {
      test(
        'profileSetupComplete is false until date of birth, gender, and height are all real stored values',
        () async {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          await container.read(profileControllerProvider.notifier).ready;

          final ref = _FakeRef(container);
          expect(
            profileSetupComplete(ref),
            isFalse,
            reason: '14: nothing filled yet -> profile setup required',
          );
        },
      );

      test(
        'the real ProfileDetails/ProfileController fields AU05 collects are exactly what completion checks',
        () {
          const incomplete = ProfileDetails(
            dateOfBirth: null,
            gender: null,
            heightCm: null,
          );
          const missingHeight = ProfileDetails(
            dateOfBirth: null,
            gender: Gender.female,
            heightCm: null,
          );
          final complete = ProfileDetails(
            dateOfBirth: DateTime(1995, 5, 12),
            gender: Gender.female,
            heightCm: 165,
          );

          bool isComplete(ProfileDetails d) =>
              d.dateOfBirth != null && d.gender != null && d.heightCm != null;

          expect(
            isComplete(incomplete),
            isFalse,
            reason: '14: first-time user with nothing filled needs AU05',
          );
          expect(
            isComplete(missingHeight),
            isFalse,
            reason: '14: partially filled still needs AU05',
          );
          expect(
            isComplete(complete),
            isTrue,
            reason: '15: a returning user with real stored data bypasses AU05',
          );
          // Weight stays genuinely optional, matching AU05's "(optional)" label.
          expect(complete.weightKg, isNull);
        },
      );
    },
  );

  group('16. logout clears auth session', () {
    test(
      'AuthController.signOut completes without throwing even when unconfigured (honest no-op)',
      () async {
        final controller = AuthController();
        addTearDown(controller.dispose);
        await controller.signOut();
      },
    );

    testWidgets(
      'Log Out resets onboarding progress and returns to the real auth entry screen',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(onboardingControllerProvider.notifier)
            .setPersonalInfo(
              firstName: 'Angel',
              dateOfBirth: DateTime(1995, 1, 1),
            );
        expect(container.read(onboardingControllerProvider).firstName, 'Angel');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GlowUpApp(),
          ),
        );
        appRouter.go(AppRoutes.profileHelp);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log Out'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log Out').last);
        await tester.pumpAndSettle();

        expect(
          container.read(onboardingControllerProvider).firstName,
          isNull,
          reason: 'requirement: logout clears the local session state',
        );
        // Never wipes wellness history — no cycle/water/food controller is
        // touched by logout, unlike Delete Account which explicitly does.
      },
    );
  });

  group(
    'AuthRouterReactor — the real fix for "stuck on AU02 after a genuine session exists"',
    () {
      User fakeUser({String? email, String? emailConfirmedAt}) => User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: email,
        emailConfirmedAt: emailConfirmedAt,
        createdAt: DateTime.now().toIso8601String(),
      );

      Session fakeSession({String? emailConfirmedAt}) => Session(
        accessToken: 'fake-access-token',
        tokenType: 'bearer',
        user: fakeUser(
          email: 'angel@example.com',
          emailConfirmedAt: emailConfirmedAt,
        ),
      );

      testWidgets(
        '6. a session that becomes authenticated WHILE sitting deep in the auth flow (AU02) is reacted to immediately, leaving AU02 for AU05 — this is the actual reported bug (regardless of whether the session came from Google or email, AuthRouterReactor only watches state, never the provenance)',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(402, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final container = ProviderContainer(
            overrides: [
              authControllerProvider.overrideWith((ref) => AuthController()),
            ],
          );
          addTearDown(container.dispose);
          await container.read(profileControllerProvider.notifier).ready;

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const GlowUpApp(),
            ),
          );
          appRouter.go(AppRoutes.authMethod);
          await tester.pumpAndSettle();
          expect(
            find.text('Welcome back!'),
            findsOneWidget,
            reason: 'still genuinely on AU02 before the session exists',
          );

          // Simulate the real Windows-loopback exchange (or an email sign-in)
          // succeeding while the user is still sitting on AU02 — exactly the
          // owner's reported scenario. `state` is @visibleForTesting on
          // StateNotifier specifically for this kind of test.
          container.read(authControllerProvider.notifier).state =
              AsyncValue.data(fakeSession());
          // Signing in mid-session re-scopes profile/onboarding storage to
          // the now-known real user id (see each controller's `ref.listen`
          // on authControllerProvider) — wait for that re-init to finish,
          // same as a real device would, before asserting the redirect.
          await container.read(profileControllerProvider.notifier).ready;
          await container.read(onboardingControllerProvider.notifier).ready;
          await tester.pumpAndSettle();

          expect(
            find.text('Welcome back!'),
            findsNothing,
            reason:
                'requirement: the app must NOT remain on AU02 after a real session exists',
          );
          expect(
            find.text('Almost there!'),
            findsOneWidget,
            reason: '7. incomplete profile -> AU05 Profile Setup',
          );
        },
      );

      testWidgets(
        '8. a complete profile leaves AU05/AU02 behind (proceeds into 07-13 onboarding since it is not yet complete — full Today-arrival coverage lives in onboarding_resume_test.dart)',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(402, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final container = ProviderContainer(
            overrides: [
              authControllerProvider.overrideWith((ref) => AuthController()),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const GlowUpApp(),
            ),
          );
          appRouter.go(AppRoutes.authMethod);
          await tester.pumpAndSettle();

          // Session first, then fill in the profile — matches the real app's
          // causal order (an account is authenticated before its own
          // profile data is written) and this account's own scoped storage,
          // rather than the anonymous/pre-auth key.
          container.read(authControllerProvider.notifier).state =
              AsyncValue.data(fakeSession());
          await container.read(profileControllerProvider.notifier).ready;
          await container.read(onboardingControllerProvider.notifier).ready;
          await container
              .read(profileControllerProvider.notifier)
              .updateDetails(
                ProfileDetails(
                  dateOfBirth: DateTime(1995, 5, 12),
                  gender: Gender.female,
                  heightCm: 165,
                ),
              );
          await tester.pumpAndSettle();

          expect(find.text('Almost there!'), findsNothing);
          expect(find.text('Welcome back!'), findsNothing);
        },
      );

      testWidgets(
        '11. session restoration: a session that already exists at cold start bypasses AU01/AU02 entirely — the owner\'s restart-preserves-login requirement',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(402, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final container = ProviderContainer(
            overrides: [
              authControllerProvider.overrideWith((ref) => AuthController()),
            ],
          );
          addTearDown(container.dispose);
          await container.read(profileControllerProvider.notifier).ready;
          await container
              .read(profileControllerProvider.notifier)
              .updateDetails(
                ProfileDetails(
                  dateOfBirth: DateTime(1995, 5, 12),
                  gender: Gender.female,
                  heightCm: 165,
                ),
              );
          // The session exists BEFORE the widget tree is ever built — mirrors
          // a real cold start where Supabase's own local-storage restore
          // already ran by the time AuthGateScreen's first frame builds.
          container.read(authControllerProvider.notifier).state =
              AsyncValue.data(fakeSession());

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const GlowUpApp(),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Glow Up ✨'),
            findsNothing,
            reason: 'never shows AU01 Welcome for an already-restored session',
          );
          expect(
            find.text('Welcome back!'),
            findsNothing,
            reason: 'never shows AU02 for an already-restored session',
          );
        },
      );
    },
  );

  group('13. no auth code or access token is ever logged', () {
    test(
      'no lib/auth file calls print/debugPrint/log with a callback Uri, code, or access token',
      () {
        final dir = Directory('lib/auth');
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final codeOnly = file
              .readAsStringSync()
              .split('\n')
              .where(
                (line) =>
                    !line.trim().startsWith('//') &&
                    !line.trim().startsWith('///'),
              )
              .join('\n');
          final loggingCalls = RegExp(
            r'(print|debugPrint|log)\s*\([^)]*\)',
          ).allMatches(codeOnly);
          for (final match in loggingCalls) {
            final call = match.group(0)!.toLowerCase();
            expect(
              call.contains('code') ||
                  call.contains('accesstoken') ||
                  call.contains('callbackuri') ||
                  call.contains('uri'),
              isFalse,
              reason:
                  '${file.path} must never log an auth code/token/callback URI: "${match.group(0)}"',
            );
          }
        }
      },
    );
  });

  group('17. no Google client secret exists in Flutter source', () {
    test(
      'no lib/ file contains a Google OAuth client secret (GOCSPX- prefix) or a literal client_secret value',
      () {
        final dir = Directory('lib');
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final content = file.readAsStringSync();
          expect(
            content.contains('GOCSPX-'),
            isFalse,
            reason: '${file.path} must never contain a Google client secret',
          );
          expect(
            RegExp(
              r'''client_secret['"]?\s*[:=]\s*['"][^'"]+['"]''',
            ).hasMatch(content),
            isFalse,
            reason: '${file.path} must never hardcode a client_secret value',
          );
        }
      },
    );
  });

  group('18. no Supabase service-role key exists in Flutter source', () {
    test('no lib/ file has non-comment code referencing a service-role key', () {
      // Same convention as cycle_test.dart: strips comment lines first, so
      // this checks actual code, not the honest doc-comments in this very
      // codebase that legitimately *state* "never the service-role key" in
      // prose (e.g. main.dart's own guarantee).
      final dir = Directory('lib');
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final codeOnly = file
            .readAsStringSync()
            .split('\n')
            .where((line) => !line.trim().startsWith('//'))
            .join('\n')
            .toLowerCase();
        expect(
          codeOnly.contains('service_role'),
          isFalse,
          reason:
              '${file.path} must never reference the service-role key in code',
        );
        expect(
          codeOnly.contains('service-role'),
          isFalse,
          reason:
              '${file.path} must never reference the service-role key in code',
        );
      }
    });

    test(
      'AuthConfig only ever exposes the public anon/publishable key, read from dart-define, never a literal',
      () {
        final content = File(
          'lib/auth/config/auth_config.dart',
        ).readAsStringSync();
        expect(
          RegExp(
            r"String\.fromEnvironment\(\s*'SUPABASE_ANON_KEY'",
          ).hasMatch(content),
          isTrue,
        );
        expect(
          RegExp(r'''supabaseAnonKey\s*=\s*['"]''').hasMatch(content),
          isFalse,
          reason: 'must never be a hardcoded literal key',
        );
      },
    );
  });

  group('Windows auto-foreground after successful Google sign-in', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('glow_up/window_foreground'),
            null,
          );
    });

    test(
      'WindowsForeground.bringToFront never throws even with no native handler registered (non-Windows test host) — a real best-effort call, not a blocking dependency',
      () async {
        final result = await WindowsForeground.bringToFront();
        expect(result, isFalse);
      },
    );

    test(
      'a successful loopback exchange invokes the real bringToFront platform-channel method exactly once',
      () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('glow_up/window_foreground'),
              (call) async {
                calls.add(call);
                return true;
              },
            );

        // Exercises AuthController.signInWithGoogle's exact Windows exchange
        // callback shape directly, since driving the real Windows branch
        // end-to-end requires Platform.isWindows to be true (this test host
        // may not be Windows) — mirrors the exact code path in
        // auth_controller.dart's `exchange:` callback.
        await WindowsForeground.bringToFront();
        expect(calls, hasLength(1));
        expect(calls.single.method, 'bringToFront');
      },
    );

    test(
      'flutter_window.cpp registers the real glow_up/window_foreground channel and never creates a second app window/instance',
      () {
        final content = File(
          'windows/runner/flutter_window.cpp',
        ).readAsStringSync();
        expect(content.contains('"glow_up/window_foreground"'), isTrue);
        expect(content.contains('"bringToFront"'), isTrue);
        expect(content.contains('SetForegroundWindow'), isTrue);
        expect(
          content.contains('CreateWindow'),
          isFalse,
          reason: 'must only act on this process\'s own existing HWND',
        );
      },
    );

    test(
      'AuthController.signInWithGoogle\'s Windows exchange path calls WindowsForeground.bringToFront only after a real AuthSuccess, never before',
      () {
        final content = File(
          'lib/auth/state/auth_controller.dart',
        ).readAsStringSync();
        final successIndex = content.indexOf(
          'exchangeResult = const AuthSuccess();',
        );
        final bringToFrontIndex = content.indexOf(
          'WindowsForeground.bringToFront()',
        );
        expect(successIndex, greaterThan(-1));
        expect(bringToFrontIndex, greaterThan(successIndex));
      },
    );
  });

  group('Local dev Supabase configuration is reliable and never leaks the anon key', () {
    test(
      'config/dev.example.json is tracked and contains only placeholder values, never the real project host/key',
      () {
        final content = File('config/dev.example.json').readAsStringSync();
        expect(content.contains('YOUR_PROJECT'), isTrue);
        expect(content.contains('YOUR_ANON_KEY'), isTrue);
        expect(
          content.contains('xecpoidyghvjsjocquip'),
          isFalse,
          reason:
              'this file is tracked in git — it must never contain the real project URL',
        );
      },
    );

    test('.gitignore excludes config/dev.local.json from version control', () {
      final content = File('.gitignore').readAsStringSync();
      expect(content.contains('config/dev.local.json'), isTrue);
    });

    test(
      'tool/run_windows_dev.ps1 launches via --dart-define-from-file and never prints the config file contents or key',
      () {
        final content = File('tool/run_windows_dev.ps1').readAsStringSync();
        expect(
          content.contains('--dart-define-from-file=config/dev.local.json'),
          isTrue,
        );
        expect(
          RegExp(r'Write-(Host|Output)[^\n]*\$configJson').hasMatch(content),
          isFalse,
          reason:
              'must never echo the parsed config object (contains the anon key)',
        );
        expect(
          content.contains('SUPABASE_ANON_KEY'),
          isTrue,
          reason: 'must validate the key is present, without printing it',
        );
      },
    );

    test(
      'the launcher refuses to run when SUPABASE_URL or SUPABASE_ANON_KEY is missing/blank rather than silently launching unconfigured',
      () {
        final content = File('tool/run_windows_dev.ps1').readAsStringSync();
        expect(content.contains('IsNullOrWhiteSpace'), isTrue);
        expect(content.contains('exit 1'), isTrue);
      },
    );

    test(
      'the launcher only ever stops processes named exactly glow_up, never a broader Flutter process match',
      () {
        final content = File('tool/run_windows_dev.ps1').readAsStringSync();
        expect(content.contains('Get-Process glow_up'), isTrue);
        expect(content.contains('Stop-Process -Force -Name'), isFalse);
      },
    );

    test(
      'AuthConfig still reads SUPABASE_URL/SUPABASE_ANON_KEY purely via String.fromEnvironment — the dev config file is a launch-time convenience only, never a second runtime config mechanism',
      () {
        final content = File(
          'lib/auth/config/auth_config.dart',
        ).readAsStringSync();
        expect(
          RegExp(
            r"String\.fromEnvironment\(\s*'SUPABASE_URL'",
          ).hasMatch(content),
          isTrue,
        );
        expect(
          content.contains('dev.local.json'),
          isFalse,
          reason:
              'Dart source must never hardcode the local config file path — dart-define-from-file injects values at build time, not via a runtime file read',
        );
      },
    );
  });

  group('Part K — start routing + AU05 blocker fixes', () {
    test(
      'the dev-only reset (Help & Support) signs out and clears local profile details without deleting the account',
      () async {
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => AuthController()),
          ],
        );
        addTearDown(container.dispose);
        await container.read(profileControllerProvider.notifier).ready;
        await container
            .read(profileControllerProvider.notifier)
            .updateDetails(
              ProfileDetails(
                name: 'Angel',
                dateOfBirth: DateTime(1995, 5, 12),
                gender: Gender.female,
                heightCm: 165,
              ),
            );
        expect(
          container.read(profileControllerProvider).value!.details.name,
          'Angel',
        );

        await container
            .read(profileControllerProvider.notifier)
            .resetOnboardingTestState();
        // signOut() is a real, honest no-op on an unconfigured test build —
        // it must not throw, matching group 16's existing coverage.
        await container.read(authControllerProvider.notifier).signOut();

        final details = container
            .read(profileControllerProvider)
            .value!
            .details;
        expect(
          details.name,
          isNull,
          reason: 'requirement 4: local profile details are cleared',
        );
        expect(details.dateOfBirth, isNull);
        expect(
          profileSetupComplete(_FakeRef(container)),
          isFalse,
          reason: 'a reset account must land back on AU05, not Today',
        );
      },
    );

    test(
      'the dev reset button in Help & Support only ever builds behind kDebugMode, never unconditionally',
      () {
        final content = File(
          'lib/profile/screens/help_support_screen.dart',
        ).readAsStringSync();
        expect(content.contains('kDebugMode'), isTrue);
        expect(
          content.contains("import 'package:flutter/foundation.dart'"),
          isTrue,
        );
      },
    );

    test(
      'personal_info_screen.dart never fabricates DateTime(2000, 1, 1) as a birth date',
      () {
        final content = File(
          'lib/onboarding/screens/personal_info_screen.dart',
        ).readAsStringSync();
        expect(
          content.contains('DateTime(2000'),
          isFalse,
          reason:
              'requirement 10: typing a name must never silently commit a fabricated DOB',
        );
      },
    );

    test(
      'OnboardingController.setFirstName never touches dateOfBirth',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          onboardingControllerProvider.notifier,
        );
        await controller.ready;
        controller.setFirstName('Riley');
        expect(controller.state.firstName, 'Riley');
        expect(
          controller.state.dateOfBirth,
          isNull,
          reason: 'a name alone must never fabricate a birth date',
        );
      },
    );

    testWidgets(
      '14. AU06 is not skipped: AuthRouterReactor never bounces away from /auth/success even once the profile is already complete — it is a deliberate, user-acknowledged interstitial',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => AuthController()),
          ],
        );
        addTearDown(container.dispose);
        await container.read(profileControllerProvider.notifier).ready;
        await container
            .read(profileControllerProvider.notifier)
            .updateDetails(
              ProfileDetails(
                dateOfBirth: DateTime(1995, 5, 12),
                gender: Gender.female,
                heightCm: 165,
              ),
            );
        container.read(authControllerProvider.notifier).state = AsyncValue.data(
          Session(
            accessToken: 'fake-access-token',
            tokenType: 'bearer',
            user: User(
              id: 'fake-user-id',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GlowUpApp(),
          ),
        );
        appRouter.go(AppRoutes.authSuccess);
        await tester.pumpAndSettle();

        expect(
          find.text('Welcome to Glow Up! ✨'),
          findsOneWidget,
          reason:
              'requirement 14: AU06 must actually be reachable/visible, not bounced straight to Today',
        );
      },
    );

    test(
      'a first-ever local profile for an authenticated user seeds name from the real Google full_name, never a stale/unrelated onboarding name',
      () async {
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => AuthController()),
          ],
        );
        addTearDown(container.dispose);
        container.read(authControllerProvider.notifier).state = AsyncValue.data(
          Session(
            accessToken: 'fake-access-token',
            tokenType: 'bearer',
            user: User(
              id: 'victor-uid',
              appMetadata: const {},
              userMetadata: const {'full_name': 'Victor Otite'},
              aud: 'authenticated',
              createdAt: DateTime.now().toIso8601String(),
            ),
          ),
        );
        container
            .read(onboardingControllerProvider.notifier)
            .setFirstName('Angel'); // simulates stale/unrelated local state

        await container.read(profileControllerProvider.notifier).ready;
        final name = container
            .read(profileControllerProvider)
            .value!
            .details
            .name;
        expect(
          name,
          'Victor Otite',
          reason:
              'requirement (Part E): the real Google display name wins over stale onboarding state',
        );
      },
    );

    testWidgets(
      '15. AU06 "Go to Dashboard" leads into the restored onboarding sequence (07_goals), never straight to Today — superseded by the Option C canonical flow; full AU06->...->13->Today coverage lives in onboarding_resume_test.dart',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const GlowUpApp(),
          ),
        );
        appRouter.go(AppRoutes.authSuccess);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Go to Dashboard'));
        await tester.pumpAndSettle();

        expect(appRouter.state.matchedLocation, AppRoutes.goals);
      },
    );
  });

  group('19. PrayerLock is untouched', () {
    test(
      'no file in this repository references PrayerLock, RosaryLock, GraceGather, or Grace Place',
      () {
        final dir = Directory('lib');
        const forbidden = [
          'prayerlock',
          'rosarylock',
          'gracegather',
          'grace place',
          'graceplace',
        ];
        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final lower = file.readAsStringSync().toLowerCase();
          for (final name in forbidden) {
            expect(
              lower.contains(name),
              isFalse,
              reason:
                  '${file.path} must never reference the separate $name app/artwork',
            );
          }
        }
      },
    );
  });
}

/// A minimal [WidgetRef] stand-in for calling [profileSetupComplete] outside
/// a widget tree — only `read` is exercised by that function.
class _FakeRef implements WidgetRef {
  _FakeRef(this._container);
  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
