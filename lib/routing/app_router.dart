import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/screens/au01_welcome_screen.dart';
import '../auth/screens/au02_sign_in_method_screen.dart';
import '../auth/screens/au03_email_sign_up_screen.dart';
import '../auth/screens/au04_verify_email_screen.dart';
import '../auth/screens/au05_profile_setup_screen.dart';
import '../auth/screens/au06_auth_success_screen.dart';
import '../auth/screens/auth_gate_screen.dart';
import '../auth/screens/email_sign_in_screen.dart';
import '../auth/screens/forgot_password_screen.dart';
import '../auth/screens/reset_password_screen.dart';
import '../auth/state/auth_controller.dart';
import '../profile/models/profile_models.dart';
import '../profile/state/profile_controller.dart';
import '../subscription/analytics/subscription_analytics.dart';
import '../subscription/data/subscription_repository.dart';
import '../subscription/models/subscription_models.dart';
import '../subscription/screens/pw01_paywall_entry_screen.dart';
import '../subscription/screens/pw02_choose_plan_screen.dart';
import '../subscription/screens/pw03_premium_benefits_screen.dart';
import '../subscription/screens/pw04_restore_terms_screen.dart';
import '../subscription/screens/pw05_success_screen.dart';
import '../subscription/screens/pw06_features_overview_screen.dart';
import '../subscription/screens/pw07_plan_comparison_screen.dart';
import '../subscription/state/subscription_controller.dart';
import '../subscription/widgets/feature_gate.dart';
import '../coach/screens/coach_chat_screen.dart';
import '../coach/screens/coach_hub_screen.dart';
import '../coach/screens/coach_plan_screen.dart';
import '../coach/screens/coach_settings_screen.dart';
import '../coach/screens/mood_history_screen.dart';
import '../core/tod/tod_period.dart';
import '../core/widgets/placeholder_screen.dart';
import '../cycle/models/cycle_models.dart';
import '../cycle/screens/cycle_calendar_screen.dart';
import '../cycle/screens/cycle_entry_screen.dart';
import '../cycle/screens/cycle_insights_screen.dart';
import '../cycle/screens/cycle_privacy_screen.dart';
import '../cycle/screens/cycle_setup_screen.dart';
import '../cycle/screens/daily_checkin_screen.dart';
import '../cycle/screens/daily_notebook_screen.dart';
import '../cycle/screens/log_period_screen.dart';
import '../journal/screens/journal_screen.dart';
import '../mood/screens/mood_checkin_screen.dart';
import '../profile/screens/ai_personalization_screen.dart';
import '../profile/screens/connected_apps_screen.dart';
import '../profile/screens/edit_profile_screen.dart';
import '../profile/screens/goals_preferences_screen.dart';
import '../profile/screens/health_wellness_screen.dart';
import '../profile/screens/help_support_screen.dart';
import '../profile/screens/manage_data_screen.dart';
import '../profile/screens/notifications_screen.dart';
import '../profile/screens/privacy_data_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../profile/screens/settings_screen.dart';
import '../profile/screens/subscription_screen.dart';
import '../shop/screens/shop_list_screen.dart';
import '../shop/screens/shop_scan_screen.dart';
import '../facial_scan/screens/facial_scan_history_screen.dart';
import '../facial_scan/screens/facial_scan_screen.dart';
import '../food_scan/screens/food_scan_history_screen.dart';
import '../food_scan/screens/food_scan_screen.dart';
import '../onboarding/screens/benefits_screen.dart';
import '../onboarding/screens/create_account_screen.dart';
import '../onboarding/screens/finish_setup_screen.dart';
import '../onboarding/screens/fitness_level_screen.dart';
import '../onboarding/screens/goals_screen.dart';
import '../onboarding/screens/health_connections_screen.dart';
import '../onboarding/screens/key_features_screen.dart';
import '../onboarding/screens/notifications_screen.dart';
import '../onboarding/screens/personal_info_screen.dart';
import '../onboarding/screens/personalization_screen.dart';
import '../onboarding/screens/schedule_screen.dart';
import '../onboarding/screens/splash_screen.dart';
import '../onboarding/screens/welcome_screen.dart';
import '../onboarding/screens/what_is_glow_up_screen.dart';
import '../routine_player/data/routine_player_registry.dart';
import '../routine_player/models/exercise_definition.dart';
import '../routine_player/models/pose_definition.dart';
import '../routine_player/screens/routine_player_screen.dart';
import '../routine_player/state/routine_player_controller.dart';
import '../routines/screens/create_routine_screen.dart';
import '../routines/screens/routine_calendar_screen.dart';
import '../routines/screens/routine_detail_screen.dart';
import '../routines/screens/routines_hub_screen.dart';
import '../routines/state/routines_controller.dart';
import '../today/screens/today_screen.dart';
import '../walking/models/walking_models.dart';
import '../walking/screens/walk_session_screen.dart';
import '../walking/screens/walking_home_screen.dart';
import '../water/screens/water_history_screen.dart';
import '../water/screens/water_tracker_screen.dart';
import '../workout/data/exercise_catalog.dart';
import '../workout/data/workout_catalog.dart';
import '../workout/models/exercise_models.dart';
import '../workout/models/workout_models.dart';
import '../workout/screens/workout_category_screen.dart';
import '../workout/screens/workout_detail_screen.dart';
import '../workout/screens/workout_hub_screen.dart';
import '../workout/screens/workout_session_screen.dart';
import '../workout/state/workout_controller.dart';

/// Linear 00 -> 13 -> /today flow. Every screen `push`es forward so the OS
/// back gesture / hardware back button naturally pops to the previous step
/// (Figma has no explicit back-chevron on these frames); onboarding data
/// itself lives in [onboardingControllerProvider], not on the route stack,
/// so popping back never loses what was entered. 13 -> /today uses `go`
/// (not push) to replace the whole onboarding stack on completion.
///
/// Everything past /today (workout/water/mood/journal/progress/coach/
/// routines/profile) is a named placeholder route — Build Pass 2 only
/// implements Today itself; these keep the navigation graph valid for
/// when each real module is built.
class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const authGate = '/auth';
  static const authWelcome = '/auth/welcome';
  static const authMethod = '/auth/method';
  static const authEmailSignUp = '/auth/sign-up';
  static const authEmailSignIn = '/auth/sign-in';
  static const authVerifyEmail = '/auth/verify-email';
  static const authForgotPassword = '/auth/forgot-password';
  static const authResetPassword = '/auth/reset-password';
  static const authProfileSetup = '/auth/profile-setup';
  static const authSuccess = '/auth/success';
  static const welcome = '/welcome';
  static const whatIsGlowUp = '/what-is-glow-up';
  static const keyFeatures = '/key-features';
  static const benefits = '/benefits';
  static const createAccount = '/create-account';
  static const personalInfo = '/personal-info';
  static const goals = '/goals';
  static const fitnessLevel = '/fitness-level';
  static const schedule = '/schedule';
  static const notifications = '/notifications';
  static const healthConnections = '/health-connections';
  static const personalization = '/personalization';
  static const finishSetup = '/finish-setup';
  static const today = '/today';
  static const workout = '/workout';
  static String workoutCategory(String categoryName) =>
      '/workout/category/$categoryName';
  static String workoutDetail(String id) => '/workout/$id';
  static const workoutSession = '/workout/session';
  static const routinePlayerSession = '/workout/routine-player-session';
  static const routinePlayerQa = '/dev/routine-player-qa';
  static const water = '/water';
  static const waterHistory = '/water/history';
  static const walking = '/walking';
  static const walkSession = '/walking/session';
  static const foodScan = '/food-scan';
  static const foodScanHistory = '/food-scan/history';
  static const facialScan = '/facial-scan';
  static const facialScanHistory = '/facial-scan/history';
  static const cycle = '/cycle';
  static const cycleSetup = '/cycle/setup';
  static const cycleLogPeriod = '/cycle/log-period';
  static const cycleCheckIn = '/cycle/check-in';
  static const cycleCalendar = '/cycle/calendar';
  static const cycleNotebook = '/cycle/notebook';
  static const cycleInsights = '/cycle/insights';
  static const cyclePrivacy = '/cycle/privacy';
  static const shopScan = '/shop/scan';
  static const shopList = '/shop/list';
  static const mood = '/mood';
  static const journal = '/journal';
  static const progress = '/progress';
  static const coach = '/coach';
  static const coachChat = '/coach/chat';
  static const coachPlan = '/coach/plan';
  static const coachMoodHistory = '/coach/mood-history';
  static const coachSettings = '/coach/settings';
  static const routines = '/routines';
  static const routineCreate = '/routines/create';
  static const routineCalendar = '/routines/calendar';
  static String routineDetail(String id) => '/routines/$id';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const profileGoals = '/profile/goals';
  static const profileHealth = '/profile/health';
  static const profileAiPersonalization = '/profile/ai-personalization';
  static const profileConnectedApps = '/profile/connected-apps';
  static const profileNotifications = '/profile/notifications';
  static const profilePrivacy = '/profile/privacy';
  static const profileManageData = '/profile/privacy/manage-data';
  static const profileSubscription = '/profile/subscription';
  static const profileSettings = '/profile/settings';
  static const profileHelp = '/profile/help';

  static const paywallEntry = '/paywall';
  static const paywallChoosePlan = '/paywall/choose-plan';
  static const paywallBenefits = '/paywall/benefits';
  static const paywallRestoreTerms = '/paywall/restore-terms';
  static const paywallSuccess = '/paywall/success';
  static const paywallFeaturesOverview = '/paywall/features-overview';
  static const paywallPlanComparison = '/paywall/plan-comparison';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.authGate,
  routes: [
    GoRoute(
      path: AppRoutes.authGate,
      builder: (context, state) => AuthGateScreen(
        onResolved: (destination) {
          switch (destination) {
            case 'welcome':
              appRouter.go(AppRoutes.authWelcome);
            case 'profileSetup':
              appRouter.go(AppRoutes.authProfileSetup);
            case 'today':
              appRouter.go(AppRoutes.today);
            case 'goals':
              appRouter.go(AppRoutes.goals);
            case 'fitnessLevel':
              appRouter.go(AppRoutes.fitnessLevel);
            case 'schedule':
              appRouter.go(AppRoutes.schedule);
            case 'notifications':
              appRouter.go(AppRoutes.notifications);
            case 'healthConnections':
              appRouter.go(AppRoutes.healthConnections);
            case 'personalization':
              appRouter.go(AppRoutes.personalization);
            case 'finishSetup':
              appRouter.go(AppRoutes.finishSetup);
            default:
              appRouter.go(AppRoutes.today);
          }
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.authWelcome,
      builder: (context, state) => AuthWelcomeScreen(
        onGetStarted: () => context.push(AppRoutes.authMethod),
        onSignIn: () => context.push(AppRoutes.authMethod),
      ),
    ),
    GoRoute(
      path: AppRoutes.authMethod,
      builder: (context, state) => const _AuthMethodPage(),
    ),
    GoRoute(
      path: AppRoutes.authEmailSignUp,
      builder: (context, state) => const _EmailSignUpPage(),
    ),
    GoRoute(
      path: AppRoutes.authEmailSignIn,
      builder: (context, state) => const _EmailSignInPage(),
    ),
    GoRoute(
      path: AppRoutes.authVerifyEmail,
      builder: (context, state) =>
          _VerifyEmailPage(email: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: AppRoutes.authForgotPassword,
      builder: (context, state) => const _ForgotPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.authResetPassword,
      builder: (context, state) => const _ResetPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.authProfileSetup,
      builder: (context, state) => const _ProfileSetupPage(),
    ),
    GoRoute(
      path: AppRoutes.authSuccess,
      // AU06 never marks onboarding complete and never goes straight to
      // Today — per the approved canonical flow it leads into the
      // restored 07-13 sequence, starting at 07_goals. `push` (not `go`)
      // so 07's back button can return here. Only 13_finish_setup is
      // allowed to route to Today.
      builder: (context, state) => AuthSuccessScreen(
        onGoToDashboard: () => context.push(AppRoutes.goals),
      ),
    ),
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) =>
          SplashScreen(onGetStarted: () => context.push(AppRoutes.welcome)),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) =>
          WelcomeScreen(onNext: () => context.push(AppRoutes.whatIsGlowUp)),
    ),
    GoRoute(
      path: AppRoutes.whatIsGlowUp,
      builder: (context, state) =>
          WhatIsGlowUpScreen(onNext: () => context.push(AppRoutes.keyFeatures)),
    ),
    GoRoute(
      path: AppRoutes.keyFeatures,
      builder: (context, state) =>
          KeyFeaturesScreen(onNext: () => context.push(AppRoutes.benefits)),
    ),
    GoRoute(
      path: AppRoutes.benefits,
      builder: (context, state) =>
          BenefitsScreen(onNext: () => context.push(AppRoutes.createAccount)),
    ),
    GoRoute(
      path: AppRoutes.createAccount,
      builder: (context, state) => CreateAccountScreen(
        onNext: () => context.push(AppRoutes.personalInfo),
      ),
    ),
    GoRoute(
      path: AppRoutes.personalInfo,
      builder: (context, state) =>
          PersonalInfoScreen(onNext: () => context.push(AppRoutes.goals)),
    ),
    GoRoute(
      path: AppRoutes.goals,
      builder: (context, state) =>
          GoalsScreen(onNext: () => context.push(AppRoutes.fitnessLevel)),
    ),
    GoRoute(
      path: AppRoutes.fitnessLevel,
      builder: (context, state) =>
          FitnessLevelScreen(onNext: () => context.push(AppRoutes.schedule)),
    ),
    GoRoute(
      path: AppRoutes.schedule,
      builder: (context, state) =>
          ScheduleScreen(onNext: () => context.push(AppRoutes.notifications)),
    ),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (context, state) => NotificationsScreen(
        onNext: () => context.push(AppRoutes.healthConnections),
      ),
    ),
    GoRoute(
      path: AppRoutes.healthConnections,
      builder: (context, state) => HealthConnectionsScreen(
        onNext: () => context.push(AppRoutes.personalization),
      ),
    ),
    GoRoute(
      path: AppRoutes.personalization,
      builder: (context, state) => PersonalizationScreen(
        onComplete: () => context.push(AppRoutes.finishSetup),
      ),
    ),
    GoRoute(
      path: AppRoutes.finishSetup,
      // Onboarding finish leads into the once-only soft Premium offer
      // (PW01), never straight to Today and never a substitute for
      // onboarding itself — Bluebook's own sequence is already complete
      // by the time this fires.
      builder: (context, state) => FinishSetupScreen(
        onStart: () => context.go(
          AppRoutes.paywallEntry,
          extra: const PaywallLaunchContext(origin: PaywallOrigin.onboarding),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.today,
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => TodayScreen(
          onWorkout: () => context.push(AppRoutes.workout),
          onWater: () => context.push(AppRoutes.water),
          onMood: () => context.push(AppRoutes.mood),
          onJournal: () => context.push(AppRoutes.journal),
          onGlowScore: () => context.push(AppRoutes.progress),
          onCoach: () => context.push(AppRoutes.coach),
          onUpNext: () {
            final period = ref.read(currentTodPeriodProvider);
            final featured = ref
                .read(routinesControllerProvider.notifier)
                .featuredFor(period);
            if (featured != null) {
              context.push(AppRoutes.routineDetail(featured.id));
            } else {
              context.push(AppRoutes.routines);
            }
          },
          onRoutines: () => context.push(AppRoutes.routines),
          onProfile: () => context.push(AppRoutes.profile),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.workout,
      builder: (context, state) => WorkoutHubScreen(
        onOpenCategory: (category) =>
            context.push(AppRoutes.workoutCategory(category.name)),
        onBack: () => context.pop(),
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.push(AppRoutes.routines),
        onCoach: () => context.push(AppRoutes.coach),
        onProfile: () => context.push(AppRoutes.profile),
      ),
    ),
    GoRoute(
      path: '/workout/category/:categoryName',
      builder: (context, state) {
        final category = ExerciseCategory.values.firstWhere(
          (c) => c.name == state.pathParameters['categoryName'],
          orElse: () => ExerciseCategory.core,
        );
        return WorkoutCategoryScreen(
          category: category,
          onOpenWorkout: (id) => context.push(AppRoutes.workoutDetail(id)),
          onBack: () => context.pop(),
          onToday: () => context.go(AppRoutes.today),
          onRoutines: () => context.push(AppRoutes.routines),
          onCoach: () => context.push(AppRoutes.coach),
          onProfile: () => context.push(AppRoutes.profile),
        );
      },
    ),
    // Must be registered BEFORE '/workout/:id' — GoRoute matches in list
    // order, and the parameterized route below would otherwise shadow this
    // literal path (matching "session" as the :id).
    GoRoute(
      path: AppRoutes.workoutSession,
      builder: (context, state) => WorkoutSessionScreen(
        onExitToHub: () => context.go(AppRoutes.workout),
        onExitToToday: () => context.go(AppRoutes.today),
      ),
    ),
    // Production entry into the real RoutinePlayer engine for a workout
    // whose full exercise list resolves through the canonical registry
    // (see `_routinePlayerRoutineFor` below) — Core Crusher today. Reuses
    // [RoutinePlayerQaEntry], the same widget the dev QA route uses, with
    // its own real routine passed via `extra` instead of a second player.
    GoRoute(
      path: AppRoutes.routinePlayerSession,
      builder: (context, state) {
        final args = state.extra as RoutinePlayerLaunchArgs?;
        return Consumer(
          builder: (context, ref, _) => RoutinePlayerQaEntry(
            routine: args?.routine,
            sourceWorkout: args?.sourceWorkout,
            onExit: () {
              ref.read(routinePlayerControllerProvider.notifier).endSession();
              context.go(AppRoutes.workout);
            },
          ),
        );
      },
    ),
    // Dev-only entry point for the RoutinePlayer Phase 1 engine QA routine —
    // not linked from any production nav, reached only via a direct route.
    // Optional `?exercise=<id>` (e.g. `?exercise=EX012`) jumps straight to
    // that exercise instead of the full routine, for fast manual QA.
    GoRoute(
      path: AppRoutes.routinePlayerQa,
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => RoutinePlayerQaEntry(
          startExerciseId: state.uri.queryParameters['exercise'],
          onExit: () {
            ref.read(routinePlayerControllerProvider.notifier).endSession();
            context.go(AppRoutes.workout);
          },
        ),
      ),
    ),
    GoRoute(
      path: '/workout/:id',
      builder: (context, state) => Consumer(
        builder: (context, ref, _) {
          final workout = workoutById(state.pathParameters['id']!);
          if (workout == null) {
            return const PlaceholderScreen(
              title: 'Workout not found',
              figmaFamily: '32 Workout Detail',
            );
          }
          return WorkoutDetailScreen(
            workout: workout,
            onBack: () => context.pop(),
            onStart: () {
              // Strength, Flexibility, Mobility, and Cardio: per-exercise
              // resolution (Phase 1 Strength asset cleanup, step 2; extended
              // to Flexibility so EX025 Hamstring Stretch opens its real
              // RoutinePlayer even while EX026-EX031 remain pending; extended
              // to Mobility so EX070 Shoulder Rolls/EX071 Arm Circles open
              // real RoutinePlayer while Wrist/Hip/Thoracic/Knee Circles
              // remain pending; extended again to Cardio so EX076 March In
              // Place opens real RoutinePlayer right after EX009 Jumping
              // Jacks while High Knees/Butt Kicks/Step Jacks/Skaters/Shadow
              // Boxing/Side Steps remain pending, unapproved assets) — never
              // falls back to a legacy image for the whole workout, see
              // `_perExerciseRoutineFor`. Originally guarded on *every*
              // exercise having a catalogId; relaxed to *any* for EX055 Sun
              // Salutation (Morning Yoga Flow, also Flexibility) — the one
              // workout whose other five exercises are hardcoded outside
              // the 52-exercise catalog with no catalogId at all.
              // `_perExerciseRoutineFor`/`_pendingApprovalStandIn` build
              // their pending stand-in straight from each `WorkoutExercise`
              // (title/durationSeconds), so a null catalogId no longer
              // needs to force-unwrap or look anything up in the legacy
              // catalog — it degrades to the same generic "not approved
              // yet" placeholder every other pending exercise already uses.
              //
              // Cardio-specific note: this gate is per-*category*, not
              // per-workout, so it also applies to Full Body Burn (the
              // other Cardio routine) — its five real exercises (Jumping
              // Jacks/Squat/Lunges/Push-Ups/Glute Bridge) are already real
              // Tier 1 definitions and are completely unaffected; its sixth
              // slot (Full Body Stretch, still pointing at the legacy EX002
              // placeholder) now shows the same generic pending stand-in
              // instead of a blank legacy image — a disclosed side effect,
              // not a fix: EX002 -> EX061 remapping is explicitly out of
              // scope for this pass.
              final canUsePerExerciseResolution =
                  (workout.category == ExerciseCategory.strength ||
                      workout.category == ExerciseCategory.flexibility ||
                      workout.category == ExerciseCategory.mobility ||
                      workout.category == ExerciseCategory.cardio) &&
                  workout.exercises.any((e) => e.catalogId != null);
              if (canUsePerExerciseResolution) {
                context.push(
                  AppRoutes.routinePlayerSession,
                  extra: RoutinePlayerLaunchArgs(
                    routine: _perExerciseRoutineFor(workout),
                    sourceWorkout: workout,
                  ),
                );
                return;
              }
              final routinePlayerRoutine = _routinePlayerRoutineFor(workout);
              if (routinePlayerRoutine != null) {
                context.push(
                  AppRoutes.routinePlayerSession,
                  extra: RoutinePlayerLaunchArgs(
                    routine: routinePlayerRoutine,
                    sourceWorkout: workout,
                  ),
                );
              } else {
                // Not every exercise in this workout has a RoutinePlayer
                // definition yet (see `routinePlayerExerciseById`) — falls
                // back to the legacy session flow rather than dropping
                // exercises or crashing on an unresolved id.
                ref
                    .read(workoutSessionControllerProvider.notifier)
                    .startSession(workout);
                context.push(AppRoutes.workoutSession);
              }
            },
          );
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.water,
      builder: (context, state) => WaterTrackerScreen(
        onBack: () => context.pop(),
        onViewHistory: () => context.push(AppRoutes.waterHistory),
      ),
    ),
    GoRoute(
      path: AppRoutes.waterHistory,
      builder: (context, state) =>
          WaterHistoryScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.walking,
      builder: (context, state) => WalkingHomeScreen(
        onBack: () => context.pop(),
        onStartWalk: (routine) =>
            context.push(AppRoutes.walkSession, extra: routine),
      ),
    ),
    GoRoute(
      path: AppRoutes.walkSession,
      builder: (context, state) => WalkSessionScreen(
        routine: state.extra as WalkRoutine?,
        onDone: () => context.pop(),
      ),
    ),
    GoRoute(
      path: AppRoutes.foodScan,
      builder: (context, state) => FoodScanScreen(
        onBack: () => context.pop(),
        onViewHistory: () => context.push(AppRoutes.foodScanHistory),
      ),
    ),
    GoRoute(
      path: AppRoutes.foodScanHistory,
      builder: (context, state) =>
          FoodScanHistoryScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.facialScan,
      builder: (context, state) => FacialScanScreen(
        onBack: () => context.pop(),
        onViewHistory: () => context.push(AppRoutes.facialScanHistory),
      ),
    ),
    GoRoute(
      path: AppRoutes.facialScanHistory,
      builder: (context, state) =>
          FacialScanHistoryScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.cycle,
      builder: (context, state) => CycleEntryScreen(
        onBack: () => context.pop(),
        onSetUp: () => context.push(AppRoutes.cycleSetup),
        onSettings: () => context.push(AppRoutes.cyclePrivacy),
        onLogPeriod: () => context.push(AppRoutes.cycleLogPeriod),
        onDailyCheckIn: () => context.push(AppRoutes.cycleCheckIn),
        onCalendar: () => context.push(AppRoutes.cycleCalendar),
        onInsights: () => context.push(AppRoutes.cycleInsights),
      ),
    ),
    GoRoute(
      path: AppRoutes.cycleSetup,
      builder: (context, state) => CycleSetupScreen(
        onBack: () => context.pop(),
        onSaved: () => context.pop(),
      ),
    ),
    GoRoute(
      path: AppRoutes.cycleLogPeriod,
      builder: (context, state) => LogPeriodScreen(
        onBack: () => context.pop(),
        onSaved: () => context.pop(),
      ),
    ),
    GoRoute(
      path: AppRoutes.cycleCheckIn,
      builder: (context, state) => DailyCheckInScreen(
        onBack: () => context.pop(),
        onSaved: () => context.pop(),
        onMenstrualPainNote: () => context.push(
          AppRoutes.cycleNotebook,
          extra: CycleNotebookLaunchArgs(
            date: DateTime.now(),
            initialFeeling: Feeling.menstrualPain,
          ),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.cycleCalendar,
      builder: (context, state) => CycleCalendarScreen(
        onBack: () => context.pop(),
        onOpenNotebook: (date) => context.push(
          AppRoutes.cycleNotebook,
          extra: CycleNotebookLaunchArgs(date: date),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.cycleNotebook,
      builder: (context, state) {
        final args = state.extra as CycleNotebookLaunchArgs?;
        return DailyNotebookScreen(
          date: args?.date ?? DateTime.now(),
          initialFeeling: args?.initialFeeling,
          onBack: () => context.pop(),
          onSaved: () => context.pop(),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.cycleInsights,
      builder: (context, state) =>
          CycleInsightsScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.cyclePrivacy,
      builder: (context, state) => CyclePrivacyScreen(
        onBack: () => context.pop(),
        onEditBasics: () => context.push(AppRoutes.cycleSetup),
      ),
    ),
    GoRoute(
      path: AppRoutes.shopScan,
      builder: (context, state) => ShopScanScreen(
        onBack: () => context.pop(),
        onViewList: () => context.push(AppRoutes.shopList),
      ),
    ),
    GoRoute(
      path: AppRoutes.shopList,
      builder: (context, state) => ShopListScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.mood,
      builder: (context, state) => MoodCheckInScreen(
        onBack: () => context.pop(),
        onSaved: () => context.pop(),
        onViewHistory: () => context.push(AppRoutes.coachMoodHistory),
      ),
    ),
    GoRoute(
      path: AppRoutes.journal,
      builder: (context, state) => JournalScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.progress,
      builder: (context, state) => const PlaceholderScreen(
        title: 'Progress',
        figmaFamily: '70-71 Progress',
      ),
    ),
    GoRoute(
      path: AppRoutes.coach,
      builder: (context, state) => CoachHubScreen(
        onChat: () => context.push(AppRoutes.coachChat),
        onOpenThread: (threadId) =>
            context.push(AppRoutes.coachChat, extra: threadId),
        onPlan: () => context.push(AppRoutes.coachPlan),
        onMood: () => context.push(AppRoutes.coachMoodHistory),
        onSettings: () => context.push(AppRoutes.coachSettings),
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.push(AppRoutes.routines),
        onProfile: () => context.push(AppRoutes.profile),
      ),
    ),
    GoRoute(
      path: AppRoutes.coachChat,
      builder: (context, state) => CoachChatScreen(
        onBack: () => context.pop(),
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.push(AppRoutes.routines),
        onProfile: () => context.push(AppRoutes.profile),
        initialThreadId: state.extra as String?,
      ),
    ),
    GoRoute(
      path: AppRoutes.coachPlan,
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => CoachPlanScreen(
          onBack: () => context.pop(),
          onToday: () => context.go(AppRoutes.today),
          onRoutines: () => context.push(AppRoutes.routines),
          onProfile: () => context.push(AppRoutes.profile),
          onHydrationTap: () => context.push(AppRoutes.water),
          onNutritionTap: () => context.push(AppRoutes.foodScan),
          // Skin & Acne Scan is Premium — Free users are routed to the
          // contextual paywall instead of the real feature; Premium users
          // open it directly. See FeatureGate's doc comment.
          onWellnessCheckInTap: () => openGatedFeature(
            context,
            ref,
            feature: FeatureEntitlement.skinAcneScan,
            featureName: 'Skin & Acne Scan',
            onOpen: () => context.push(AppRoutes.facialScan),
            returnRoute: AppRoutes.facialScan,
          ),
          onCycleTap: () => context.push(AppRoutes.cycle),
          onShopScanTap: () => context.push(AppRoutes.shopScan),
          onWalkingTap: () => context.push(AppRoutes.walking),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.coachMoodHistory,
      builder: (context, state) => MoodHistoryScreen(
        onBack: () => context.pop(),
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.push(AppRoutes.routines),
        onProfile: () => context.push(AppRoutes.profile),
      ),
    ),
    GoRoute(
      path: AppRoutes.coachSettings,
      builder: (context, state) => CoachSettingsScreen(
        onBack: () => context.pop(),
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.push(AppRoutes.routines),
        onProfile: () => context.push(AppRoutes.profile),
      ),
    ),
    GoRoute(
      path: AppRoutes.routines,
      builder: (context, state) => RoutinesHubScreen(
        onOpenRoutine: (id) => context.push(AppRoutes.routineDetail(id)),
        onCreateRoutine: () => context.push(AppRoutes.routineCreate),
        onOpenCalendar: () => context.push(AppRoutes.routineCalendar),
        onToday: () => context.go(AppRoutes.today),
        onCoach: () => context.push(AppRoutes.coach),
        onProfile: () => context.push(AppRoutes.profile),
      ),
    ),
    GoRoute(
      path: AppRoutes.routineCreate,
      builder: (context, state) => Consumer(
        builder: (context, ref, _) => CreateRoutineScreen(
          period: ref.read(currentTodPeriodProvider),
          onSaved: () => context.pop(),
          onBack: () => context.pop(),
          onToday: () => context.go(AppRoutes.today),
          onRoutines: () => context.pop(),
          onCoach: () => context.push(AppRoutes.coach),
          onProfile: () => context.push(AppRoutes.profile),
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.routineCalendar,
      builder: (context, state) => RoutineCalendarScreen(
        onBack: () => context.pop(),
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.pop(),
        onCoach: () => context.push(AppRoutes.coach),
        onProfile: () => context.push(AppRoutes.profile),
      ),
    ),
    GoRoute(
      path: '/routines/:id',
      builder: (context, state) => RoutineDetailScreen(
        routineId: state.pathParameters['id']!,
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.pop(),
        onCoach: () => context.push(AppRoutes.coach),
        onProfile: () => context.push(AppRoutes.profile),
      ),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => ProfileScreen(
        onToday: () => context.go(AppRoutes.today),
        onRoutines: () => context.push(AppRoutes.routines),
        onCoach: () => context.push(AppRoutes.coach),
        onSettings: () => context.push(AppRoutes.profileSettings),
        onEditProfile: () => context.push(AppRoutes.profileEdit),
        onGoals: () => context.push(AppRoutes.profileGoals),
        onHealth: () => context.push(AppRoutes.profileHealth),
        onAiPersonalization: () =>
            context.push(AppRoutes.profileAiPersonalization),
        onConnectedApps: () => context.push(AppRoutes.profileConnectedApps),
        onNotifications: () => context.push(AppRoutes.profileNotifications),
        onPrivacy: () => context.push(AppRoutes.profilePrivacy),
        onSubscription: () => context.push(AppRoutes.profileSubscription),
        onManageData: () => context.push(AppRoutes.profileManageData),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileEdit,
      builder: (context, state) => EditProfileScreen(
        onBack: () => context.pop(),
        onSaved: () => context.pop(),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileGoals,
      builder: (context, state) =>
          GoalsPreferencesScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.profileHealth,
      builder: (context, state) => HealthWellnessScreen(
        onBack: () => context.pop(),
        onEditProfile: () => context.push(AppRoutes.profileEdit),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileAiPersonalization,
      builder: (context, state) =>
          AiPersonalizationScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.profileConnectedApps,
      builder: (context, state) =>
          ConnectedAppsScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.profileNotifications,
      builder: (context, state) =>
          ProfileNotificationsScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.profilePrivacy,
      builder: (context, state) => PrivacyDataScreen(
        onBack: () => context.pop(),
        onManageData: () => context.push(AppRoutes.profileManageData),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileManageData,
      builder: (context, state) =>
          ManageDataScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.profileSubscription,
      builder: (context, state) => SubscriptionScreen(
        onBack: () => context.pop(),
        onViewPlans: () => context.push(
          AppRoutes.paywallEntry,
          extra: const PaywallLaunchContext(origin: PaywallOrigin.profile),
        ),
        onRestorePurchases: () => context.push(
          AppRoutes.paywallRestoreTerms,
          extra: const PaywallLaunchContext(origin: PaywallOrigin.profile),
        ),
        onViewBenefits: () => context.push(AppRoutes.paywallFeaturesOverview),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileSettings,
      builder: (context, state) => ProfileSettingsScreen(
        onBack: () => context.pop(),
        onHelp: () => context.push(AppRoutes.profileHelp),
      ),
    ),
    GoRoute(
      path: AppRoutes.profileHelp,
      builder: (context, state) => HelpSupportScreen(
        onBack: () => context.pop(),
        onLoggedOut: () => context.go(AppRoutes.authGate),
      ),
    ),
    GoRoute(
      path: AppRoutes.paywallEntry,
      builder: (context, state) {
        final launch =
            state.extra as PaywallLaunchContext? ??
            const PaywallLaunchContext(origin: PaywallOrigin.profile);
        return _PaywallEntryPage(launch: launch);
      },
    ),
    GoRoute(
      path: AppRoutes.paywallChoosePlan,
      builder: (context, state) {
        final launch =
            state.extra as PaywallLaunchContext? ??
            const PaywallLaunchContext(origin: PaywallOrigin.profile);
        return _ChoosePlanPage(launch: launch);
      },
    ),
    GoRoute(
      path: AppRoutes.paywallBenefits,
      builder: (context, state) =>
          _PremiumBenefitsPage(selection: state.extra as PlanSelectionContext),
    ),
    GoRoute(
      path: AppRoutes.paywallRestoreTerms,
      builder: (context, state) =>
          _RestoreTermsPage(launch: state.extra as PaywallLaunchContext?),
    ),
    GoRoute(
      path: AppRoutes.paywallSuccess,
      builder: (context, state) {
        final payload =
            state.extra as PaywallSuccessLaunch? ??
            const PaywallSuccessLaunch();
        return _PaywallSuccessPage(
          launch:
              payload.launch ??
              const PaywallLaunchContext(origin: PaywallOrigin.profile),
          isPreview: payload.isPreview,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.paywallFeaturesOverview,
      builder: (context, state) =>
          FeaturesOverviewScreen(onBack: () => context.pop()),
    ),
    GoRoute(
      path: AppRoutes.paywallPlanComparison,
      builder: (context, state) =>
          _PlanComparisonPage(launch: state.extra as PaywallLaunchContext?),
    ),
  ],
);

/// [AppRoutes.routinePlayerSession]'s `extra` payload — bundles the
/// resolved exercise sequence together with the originating [Workout] so
/// [RoutinePlayerController.startRoutine] can carry the real routine
/// name/id/calories through to the completion summary and durable history
/// save. Previously `extra` was just the bare exercise list, with no way
/// for the completion screen to know which workout had actually been
/// started.
class RoutinePlayerLaunchArgs {
  const RoutinePlayerLaunchArgs({required this.routine, this.sourceWorkout});
  final List<ExerciseDefinition>? routine;
  final Workout? sourceWorkout;
}

/// Launch args for [AppRoutes.cycleNotebook] — which calendar date's Daily
/// Notebook entry (PC07) to open, and an optional pre-set [Feeling] (used
/// when arriving from Daily Check-In's "Menstrual pain" card).
class CycleNotebookLaunchArgs {
  const CycleNotebookLaunchArgs({required this.date, this.initialFeeling});
  final DateTime date;
  final Feeling? initialFeeling;
}

/// The workout system has two deliberate tiers, not a bug to be papered
/// over: Tier 1 (RoutinePlayer, [routinePlayerExerciseById]) holds
/// exercises with approved, individually-verified production animation
/// assets; Tier 2 (the legacy `lib/workout` module, [exerciseById]) holds
/// every exercise from the original Exercise Sequence Library, using
/// real-but-not-yet-V2-approved images. A [Workout] only reaches Tier 1 if
/// every one of its exercises has a Tier 1 definition — never a partial
/// mix within one workout, and never a silent per-exercise substitution.
///
/// This resolves [workout]'s real exercise sequence through the canonical
/// RoutinePlayer registry, preserving order, or returns null if any
/// exercise doesn't have a RoutinePlayer definition yet — callers must
/// fall back to the legacy workout session rather than silently dropping
/// exercises or crashing on an unresolved id. The resulting list is never
/// a duplicate/second definition of an exercise: it's exactly the same
/// [ExerciseDefinition] instances RoutinePlayer's dev QA routine also
/// resolves to.
///
/// The tier-2 fallback itself is intentional and stays in place (most of
/// the catalog has no approved Tier 1 assets yet) — but it is never
/// silent: every fallback logs exactly which exercise forced it, in debug
/// builds only (see [_routinePlayerScreenLog]).
List<ExerciseDefinition>? _routinePlayerRoutineFor(Workout workout) {
  final routine = <ExerciseDefinition>[];
  for (final exercise in workout.exercises) {
    final catalogId = exercise.catalogId;
    if (catalogId == null) {
      _routinePlayerScreenLog(
        '"${workout.title}" (${workout.id}) stays on Tier 2 (legacy): "${exercise.title}" has no catalogId at all.',
      );
      return null;
    }
    final definition = routinePlayerExerciseById(catalogId);
    if (definition == null) {
      _routinePlayerScreenLog(
        '"${workout.title}" (${workout.id}) stays on Tier 2 (legacy): $catalogId ("${exercise.title}") has no Tier 1 RoutinePlayer definition yet.',
      );
      return null;
    }
    // See `Workout.useCatalogDurations` — opt-in per routine, so this
    // never changes a shared exercise's duration for any other routine
    // that doesn't set it (e.g. Recovery Flow's EX049-EX052).
    routine.add(
      workout.useCatalogDurations
          ? definition.copyWith(durationSeconds: exercise.durationSeconds)
          : definition,
    );
  }
  return routine;
}

void _routinePlayerScreenLog(String message) {
  if (kDebugMode) debugPrint('[WorkoutTier] $message');
}

/// Per-exercise resolution for categories whose workouts can mix approved
/// and not-yet-approved exercises (currently Strength and Flexibility —
/// see the `onStart` callback above) — unlike [_routinePlayerRoutineFor],
/// this never falls back to the legacy `WorkoutSessionScreen`/legacy
/// images for the whole workout just because one exercise in it isn't
/// ready yet. Each exercise resolves independently: an approved one uses
/// its real Tier 1 [ExerciseDefinition]; anything else gets
/// [_pendingApprovalStandIn] — a generic "no approved animation yet"
/// state (the exact same template for every pending exercise, never
/// per-exercise invented content or artwork) so the whole session still
/// runs through the one shared RoutinePlayer, with working
/// Skip/Previous/Pause/Resume. Originally Strength-only (`_strengthRoutineFor`,
/// Phase 1 Strength asset cleanup, step 2); generalized when Flexibility
/// needed the identical mixed-completion behavior for EX025 Hamstring
/// Stretch while EX026-EX031 stay pending — reused as-is, not
/// reinvented, since the underlying mechanism (does
/// [routinePlayerExerciseById] resolve this id or not?) was never actually
/// Strength-specific. `exercise.catalogId` may now also be null (Morning
/// Yoga Flow's five still-unimplemented exercises) — that's treated
/// identically to "has a catalogId but no Tier 1 definition yet".
List<ExerciseDefinition> _perExerciseRoutineFor(Workout workout) {
  return [
    for (final exercise in workout.exercises)
      (exercise.catalogId != null
              ? routinePlayerExerciseById(exercise.catalogId!)
              : null) ??
          _pendingApprovalStandIn(exercise, workout.category.label),
  ];
}

/// A generic, non-exercise-specific stand-in for an exercise with no
/// approved Tier 1 asset yet, in a category using per-exercise resolution.
/// [PoseDefinition.approvedAsset] is null, which [MovementDisplay] already
/// renders as its existing "UNVERIFIED EXERCISE ASSET" state — here
/// relabeled to "ASSET_PENDING_APPROVAL" — no new UI, no fabricated pose
/// sequence, no bespoke per-exercise coaching copy. Name/duration are read
/// straight off the [WorkoutExercise] itself (real data, not invented) —
/// never from the legacy catalog, so this works whether or not `exercise`
/// even has a catalogId (Morning Yoga Flow's still-pending exercises have
/// none at all); every other field uses the identical generic message
/// regardless of which exercise or category this is.
ExerciseDefinition _pendingApprovalStandIn(
  WorkoutExercise exercise,
  String categoryLabel,
) {
  final id = exercise.catalogId ?? exercise.id;
  const pendingMessage =
      "This exercise doesn't have an approved animation yet.";
  return ExerciseDefinition(
    id: id,
    displayName: exercise.title,
    category: categoryLabel,
    playbackType: 'PENDING',
    bodyAreas: const [],
    benefitShort: 'Approved animation coming soon.',
    durationSeconds: exercise.durationSeconds,
    poses: [
      PoseDefinition(
        poseId: '${id}_pending',
        order: 1,
        label: 'ASSET_PENDING_APPROVAL',
        instruction: pendingMessage,
        approvedAsset: null,
        purpose: PosePurpose.active,
      ),
    ],
    loopMode: LoopMode.continuousLoop,
    voiceScript: VoiceScript(
      intro: 'Next: ${exercise.title}.',
      benefit: 'Approved animation coming soon.',
      setupInstruction: pendingMessage,
      finishCue: 'Done.',
    ),
  );
}

/// --- Auth flow page wrappers ---
/// Each holds the transient loading/error UI state for one auth screen
/// and calls the real [authControllerProvider] — kept local to this
/// screen's own lifetime, same convention as e.g. `CycleSetupScreen`'s
/// own `_saving` field, never a shared/global loading flag.

class _AuthMethodPage extends ConsumerStatefulWidget {
  const _AuthMethodPage();

  @override
  ConsumerState<_AuthMethodPage> createState() => _AuthMethodPageState();
}

class _AuthMethodPageState extends ConsumerState<_AuthMethodPage> {
  bool _googleLoading = false;
  String? _error;

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    switch (result) {
      case AuthSuccess():
        break; // authControllerProvider's own state stream drives AuthGateScreen.
      case AuthCancelled():
        break;
      case AuthFailure(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthMethodScreen(
      onBack: () => context.pop(),
      onGoogle: _google,
      onEmailSignIn: () => context.push(AppRoutes.authEmailSignIn),
      onCreateAccount: () => context.push(AppRoutes.authEmailSignUp),
      googleLoading: _googleLoading,
      errorText: _error,
    );
  }
}

class _EmailSignUpPage extends ConsumerStatefulWidget {
  const _EmailSignUpPage();

  @override
  ConsumerState<_EmailSignUpPage> createState() => _EmailSignUpPageState();
}

class _EmailSignUpPageState extends ConsumerState<_EmailSignUpPage> {
  bool _loading = false;
  String? _error;

  Future<void> _signUp(String name, String email, String password) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmail(email: email, password: password, displayName: name);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case AuthSuccess():
        context.push(AppRoutes.authVerifyEmail, extra: email);
      case AuthCancelled():
        break;
      case AuthFailure(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmailSignUpScreen(
      onBack: () => context.pop(),
      onSignUp: (name, email, password) => _signUp(name, email, password),
      onSignIn: () => context.pushReplacement(AppRoutes.authEmailSignIn),
      loading: _loading,
      errorText: _error,
    );
  }
}

class _EmailSignInPage extends ConsumerStatefulWidget {
  const _EmailSignInPage();

  @override
  ConsumerState<_EmailSignInPage> createState() => _EmailSignInPageState();
}

class _EmailSignInPageState extends ConsumerState<_EmailSignInPage> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn(String email, String password) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: email, password: password);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case AuthSuccess():
        break; // authControllerProvider's stream drives AuthGateScreen.
      case AuthCancelled():
        break;
      case AuthFailure(:final message):
        setState(
          () => _error = message.toLowerCase().contains('email not confirmed')
              ? 'Please verify your email before signing in.'
              : message,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmailSignInScreen(
      onBack: () => context.pop(),
      onSignIn: (email, password) => _signIn(email, password),
      onForgotPassword: () => context.push(AppRoutes.authForgotPassword),
      onCreateAccount: () => context.pushReplacement(AppRoutes.authEmailSignUp),
      loading: _loading,
      errorText: _error,
    );
  }
}

class _VerifyEmailPage extends ConsumerStatefulWidget {
  const _VerifyEmailPage({required this.email});
  final String email;

  @override
  ConsumerState<_VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<_VerifyEmailPage> {
  bool _resending = false;
  bool _checking = false;
  bool _notYetVerified = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    await ref
        .read(authControllerProvider.notifier)
        .resendVerificationEmail(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);
  }

  Future<void> _checkVerified() async {
    setState(() {
      _checking = true;
      _notYetVerified = false;
    });
    await ref.read(authControllerProvider.notifier).refreshSession();
    if (!mounted) return;
    final verified = ref.read(authControllerProvider.notifier).isEmailVerified;
    setState(() {
      _checking = false;
      _notYetVerified = !verified;
    });
    if (verified) {
      context.go(AppRoutes.authGate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VerifyEmailScreen(
      onBack: () => context.pop(),
      email: widget.email,
      onResend: _resend,
      onIveVerified: _checkVerified,
      resending: _resending,
      checking: _checking,
      notYetVerified: _notYetVerified,
    );
  }
}

class _ForgotPasswordPage extends ConsumerStatefulWidget {
  const _ForgotPasswordPage();

  @override
  ConsumerState<_ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<_ForgotPasswordPage> {
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _send(String email) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      switch (result) {
        case AuthSuccess():
          _sent = true;
        case AuthCancelled():
          break;
        case AuthFailure():
          // Never reveal whether the email is registered — same honest
          // "sent if it exists" message shown on success.
          _sent = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ForgotPasswordScreen(
      onBack: () => context.pop(),
      onSend: _send,
      loading: _loading,
      errorText: _error,
      sent: _sent,
    );
  }
}

class _ResetPasswordPage extends ConsumerStatefulWidget {
  const _ResetPasswordPage();

  @override
  ConsumerState<_ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<_ResetPasswordPage> {
  bool _loading = false;
  String? _error;

  Future<void> _reset(String newPassword) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(newPassword);
    if (!mounted) return;
    setState(() => _loading = false);
    switch (result) {
      case AuthSuccess():
        context.go(AppRoutes.authGate);
      case AuthCancelled():
        break;
      case AuthFailure(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResetPasswordScreen(
      onBack: () => context.pop(),
      onReset: _reset,
      loading: _loading,
      errorText: _error,
    );
  }
}

class _ProfileSetupPage extends ConsumerStatefulWidget {
  const _ProfileSetupPage();

  @override
  ConsumerState<_ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<_ProfileSetupPage> {
  bool _saving = false;
  String? _error;

  Future<void> _continue(ProfileDetails details) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileControllerProvider.notifier).updateDetails(details);
      if (!mounted) return;
      // Never marks setup complete unless the save above actually
      // succeeded (no exception) — only then does this navigate on.
      context.go(AppRoutes.authSuccess);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save your profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileControllerProvider);
    return profileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) =>
          const Scaffold(body: Center(child: Text('Could not load profile'))),
      data: (profileState) => ProfileSetupScreen(
        initialDetails: profileState.details,
        units: profileState.settings.units,
        onContinue: _continue,
        saving: _saving,
        errorText: _error,
      ),
    );
  }
}

class _PaywallEntryPage extends ConsumerStatefulWidget {
  const _PaywallEntryPage({required this.launch});
  final PaywallLaunchContext launch;

  @override
  ConsumerState<_PaywallEntryPage> createState() => _PaywallEntryPageState();
}

class _PaywallEntryPageState extends ConsumerState<_PaywallEntryPage> {
  @override
  void initState() {
    super.initState();
    SubscriptionAnalytics.instance.log(
      PaywallViewedEvent(screen: 'PW01', origin: widget.launch.origin.name),
    );
  }

  void _dismiss() {
    if (widget.launch.origin == PaywallOrigin.onboarding) {
      // Shown once as a soft offer — "Maybe later" is remembered so it is
      // never reopened automatically on a later launch.
      ref
          .read(subscriptionControllerProvider.notifier)
          .markOnboardingOfferSeen();
      appRouter.go(AppRoutes.today);
      return;
    }
    if (mounted) {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(AppRoutes.today);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PaywallEntryScreen(
      onClose: widget.launch.origin == PaywallOrigin.onboarding
          ? null
          : _dismiss,
      onUnlockPremium: () =>
          context.push(AppRoutes.paywallChoosePlan, extra: widget.launch),
      onMaybeLater: _dismiss,
    );
  }
}

class _ChoosePlanPage extends ConsumerStatefulWidget {
  const _ChoosePlanPage({required this.launch});
  final PaywallLaunchContext launch;

  @override
  ConsumerState<_ChoosePlanPage> createState() => _ChoosePlanPageState();
}

class _ChoosePlanPageState extends ConsumerState<_ChoosePlanPage> {
  List<SubscriptionProduct> _products = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await ref
        .read(subscriptionControllerProvider.notifier)
        .availableProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChoosePlanScreen(
      products: _products,
      onBack: () => context.pop(),
      onContinue: (planId) {
        SubscriptionAnalytics.instance.log(
          PlanSelectedEvent(planId: planId.name),
        );
        context.push(
          AppRoutes.paywallBenefits,
          extra: PlanSelectionContext(launch: widget.launch, planId: planId),
        );
      },
      onRestorePurchases: () =>
          context.push(AppRoutes.paywallRestoreTerms, extra: widget.launch),
      onComparePlans: () =>
          context.push(AppRoutes.paywallPlanComparison, extra: widget.launch),
      onSeeWhatsIncluded: () => context.push(AppRoutes.paywallFeaturesOverview),
    );
  }
}

class _PremiumBenefitsPage extends ConsumerStatefulWidget {
  const _PremiumBenefitsPage({required this.selection});
  final PlanSelectionContext selection;

  @override
  ConsumerState<_PremiumBenefitsPage> createState() =>
      _PremiumBenefitsPageState();
}

class _PremiumBenefitsPageState extends ConsumerState<_PremiumBenefitsPage> {
  bool _purchasing = false;
  String? _error;

  Future<void> _purchase() async {
    if (_error != null) {
      // Windows has no purchasing platform connected (see
      // SubscriptionRepository's doc comment), so a billing-unavailable/
      // failed result is the honest, permanent outcome here — it must
      // never trap the owner on PW03. A second tap moves forward to PW04
      // (a real screen, not a shortcut) so the rest of the approved
      // paywall stays reachable: "Windows billing unavailable != paywall
      // navigation unavailable."
      context.push(
        AppRoutes.paywallRestoreTerms,
        extra: widget.selection.launch,
      );
      return;
    }
    setState(() {
      _purchasing = true;
      _error = null;
    });
    final result = await ref
        .read(subscriptionControllerProvider.notifier)
        .purchase(widget.selection.planId);
    if (!mounted) return;
    setState(() => _purchasing = false);
    switch (result) {
      case SubscriptionSuccess():
        // Real entitlement state is already refreshed by the controller —
        // no app restart needed for PW05/Today to reflect it.
        context.go(
          AppRoutes.paywallSuccess,
          extra: PaywallSuccessLaunch(launch: widget.selection.launch),
        );
      case SubscriptionBillingUnavailable(:final message):
        setState(() => _error = message);
      case SubscriptionFailure(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBenefitsScreen(
      onBack: () => context.pop(),
      onContinue: _purchase,
      loading: _purchasing,
      errorText: _error,
    );
  }
}

class _RestoreTermsPage extends ConsumerStatefulWidget {
  const _RestoreTermsPage({this.launch});
  final PaywallLaunchContext? launch;

  @override
  ConsumerState<_RestoreTermsPage> createState() => _RestoreTermsPageState();
}

class _RestoreTermsPageState extends ConsumerState<_RestoreTermsPage> {
  bool _restoring = false;
  String? _status;

  Future<void> _restore() async {
    setState(() {
      _restoring = true;
      _status = null;
    });
    final result = await ref
        .read(subscriptionControllerProvider.notifier)
        .restorePurchases();
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _status = switch (result) {
        SubscriptionSuccess() => 'Your purchase has been restored.',
        SubscriptionBillingUnavailable(:final message) => message,
        SubscriptionFailure(:final message) => message,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return RestoreTermsScreen(
      onBack: () => context.pop(),
      onRestorePurchases: _restore,
      restoring: _restoring,
      statusText: _status,
      onContinue: () {
        final launch = widget.launch;
        if (launch != null) {
          context.push(AppRoutes.paywallChoosePlan, extra: launch);
        } else {
          context.pop();
        }
      },
      onPreviewSuccess: () => context.push(
        AppRoutes.paywallSuccess,
        extra: PaywallSuccessLaunch(launch: widget.launch, isPreview: true),
      ),
    );
  }
}

class _PaywallSuccessPage extends StatelessWidget {
  const _PaywallSuccessPage({required this.launch, this.isPreview = false});
  final PaywallLaunchContext launch;
  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    return PaywallSuccessScreen(
      isPreview: isPreview,
      onStartExploring: () {
        if (launch.origin == PaywallOrigin.feature &&
            launch.returnRoute != null) {
          context.go(launch.returnRoute!);
        } else {
          context.go(AppRoutes.today);
        }
      },
    );
  }
}

class _PlanComparisonPage extends ConsumerStatefulWidget {
  const _PlanComparisonPage({this.launch});
  final PaywallLaunchContext? launch;

  @override
  ConsumerState<_PlanComparisonPage> createState() =>
      _PlanComparisonPageState();
}

class _PlanComparisonPageState extends ConsumerState<_PlanComparisonPage> {
  List<SubscriptionProduct> _products = const [];

  @override
  void initState() {
    super.initState();
    ref.read(subscriptionControllerProvider.notifier).availableProducts().then((
      p,
    ) {
      if (mounted) setState(() => _products = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlanComparisonScreen(
      products: _products,
      onBack: () => context.pop(),
      onContinue: widget.launch == null
          ? null
          : () =>
                context.push(AppRoutes.paywallChoosePlan, extra: widget.launch),
    );
  }
}
