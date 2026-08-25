/// Auth provider chosen on 05_create_account.
enum AuthProvider { google, apple, email }

/// The restored 07-13 onboarding sequence (Option C) — the screen a
/// returning, authenticated-but-onboarding-incomplete user should resume
/// at. Advances forward only when the corresponding screen's primary
/// button is pressed (see each screen's `onNext`/`onComplete`); popping
/// back via `OnboardingBackButton` never changes this, so backing up and
/// changing an earlier answer never loses/resets progress.
enum OnboardingStep {
  goals,
  fitnessLevel,
  schedule,
  notifications,
  healthConnections,
  personalization,
  finishSetup,
}

/// The 8 goal chips actually rendered on 07_goals. Figma's own dev-mode
/// annotation on that frame lists a 9-item set (adds "Boost Energy",
/// "Build Confidence", "Improve Skin") that does not match what is drawn
/// on the approved screen — the approved screen wins per the build brief,
/// so only these 8 exist.
enum Goal {
  loseWeight,
  buildMuscle,
  getFlexible,
  sleepBetter,
  eatHealthier,
  reduceStress,
  buildHabits,
  feelConfident,
}

extension GoalLabel on Goal {
  String get label => switch (this) {
    Goal.loseWeight => 'Lose Weight',
    Goal.buildMuscle => 'Build Muscle',
    Goal.getFlexible => 'Get Flexible',
    Goal.sleepBetter => 'Sleep Better',
    Goal.eatHealthier => 'Eat Healthier',
    Goal.reduceStress => 'Reduce Stress',
    Goal.buildHabits => 'Build Habits',
    Goal.feelConfident => 'Feel Confident',
  };

  String get icon => switch (this) {
    Goal.loseWeight => 'flame',
    Goal.buildMuscle => 'dumbbell',
    Goal.getFlexible => 'circle-x',
    Goal.sleepBetter => 'moon',
    Goal.eatHealthier => 'apple-fruit',
    Goal.reduceStress => 'wind',
    Goal.buildHabits => 'calendar-sync',
    Goal.feelConfident => 'diamond-percent',
  };
}

/// 08_fitness_level — 4 cards, exact order/copy from the approved screen.
enum FitnessLevel { beginner, intermediate, advanced, athlete }

extension FitnessLevelLabel on FitnessLevel {
  String get label => switch (this) {
    FitnessLevel.beginner => 'Beginner',
    FitnessLevel.intermediate => 'Intermediate',
    FitnessLevel.advanced => 'Advanced',
    FitnessLevel.athlete => 'Athlete',
  };

  String get description => switch (this) {
    FitnessLevel.beginner => 'Just starting out on my journey',
    FitnessLevel.intermediate => 'Some experience, active 2-3x / week',
    FitnessLevel.advanced => 'Regular training and high discipline',
    FitnessLevel.athlete => 'Competitive level & peak performance',
  };

  String get icon => switch (this) {
    FitnessLevel.beginner => 'footprints',
    FitnessLevel.intermediate => 'activity',
    FitnessLevel.advanced => 'zap',
    FitnessLevel.athlete => 'award',
  };
}

/// 09_schedule — the 4 time-of-day windows; this choice also seeds which
/// TOD variant the Brain should default to on Today/Routines/Coach/etc.
enum ScheduleWindow { morning, afternoon, evening, night }

extension ScheduleWindowLabel on ScheduleWindow {
  String get label => switch (this) {
    ScheduleWindow.morning => 'Morning',
    ScheduleWindow.afternoon => 'Afternoon',
    ScheduleWindow.evening => 'Evening',
    ScheduleWindow.night => 'Night',
  };

  String get timeRange => switch (this) {
    ScheduleWindow.morning => '6am - 12pm',
    ScheduleWindow.afternoon => '12pm - 5pm',
    ScheduleWindow.evening => '5pm - 9pm',
    ScheduleWindow.night => '9pm - 12am',
  };

  String get icon => switch (this) {
    ScheduleWindow.morning => 'sun-mascot',
    ScheduleWindow.afternoon => 'cloud-sun',
    ScheduleWindow.evening => 'sunset',
    ScheduleWindow.night => 'moon-star',
  };
}

/// 10_notifications — the 4 toggles exactly as labeled on the approved
/// screen. Defaults match the on/off switch artwork shown in Figma
/// (Hydration Nudges ships off, the other three ship on).
class NotificationPrefs {
  const NotificationPrefs({
    this.dailyReminders = true,
    this.workoutAlerts = true,
    this.hydrationNudges = false,
    this.weeklySummary = true,
  });

  final bool dailyReminders;
  final bool workoutAlerts;
  final bool hydrationNudges;
  final bool weeklySummary;

  NotificationPrefs copyWith({
    bool? dailyReminders,
    bool? workoutAlerts,
    bool? hydrationNudges,
    bool? weeklySummary,
  }) {
    return NotificationPrefs(
      dailyReminders: dailyReminders ?? this.dailyReminders,
      workoutAlerts: workoutAlerts ?? this.workoutAlerts,
      hydrationNudges: hydrationNudges ?? this.hydrationNudges,
      weeklySummary: weeklySummary ?? this.weeklySummary,
    );
  }

  Map<String, dynamic> toJson() => {
    'dailyReminders': dailyReminders,
    'workoutAlerts': workoutAlerts,
    'hydrationNudges': hydrationNudges,
    'weeklySummary': weeklySummary,
  };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(
        dailyReminders: j['dailyReminders'] as bool? ?? true,
        workoutAlerts: j['workoutAlerts'] as bool? ?? true,
        hydrationNudges: j['hydrationNudges'] as bool? ?? false,
        weeklySummary: j['weeklySummary'] as bool? ?? true,
      );
}

/// 11_health_connections — Apple Health ships pre-linked on the approved
/// screen ("Linked" pill, already green), Google Fit / Fitbit ship
/// unconnected ("Connect").
class HealthConnections {
  const HealthConnections({
    this.appleHealthLinked = true,
    this.googleFitConnected = false,
    this.fitbitConnected = false,
  });

  final bool appleHealthLinked;
  final bool googleFitConnected;
  final bool fitbitConnected;

  HealthConnections copyWith({
    bool? appleHealthLinked,
    bool? googleFitConnected,
    bool? fitbitConnected,
  }) {
    return HealthConnections(
      appleHealthLinked: appleHealthLinked ?? this.appleHealthLinked,
      googleFitConnected: googleFitConnected ?? this.googleFitConnected,
      fitbitConnected: fitbitConnected ?? this.fitbitConnected,
    );
  }

  Map<String, dynamic> toJson() => {
    'appleHealthLinked': appleHealthLinked,
    'googleFitConnected': googleFitConnected,
    'fitbitConnected': fitbitConnected,
  };

  factory HealthConnections.fromJson(Map<String, dynamic> j) =>
      HealthConnections(
        appleHealthLinked: j['appleHealthLinked'] as bool? ?? true,
        googleFitConnected: j['googleFitConnected'] as bool? ?? false,
        fitbitConnected: j['fitbitConnected'] as bool? ?? false,
      );
}

/// Everything collected during 00-13. This is the data contract the Glow
/// Up Brain consumes ([BrainContext]) — every field here is traceable to a
/// specific Figma "AI Brain Connection" annotation on the screen that
/// collects it. [currentStep]/[onboardingComplete] are the real, separate
/// onboarding-progress state — never conflated with [ProfileDetails]'s
/// separate "basic profile" completeness (dateOfBirth/gender/heightCm),
/// which the auth flow (AU05) owns.
class OnboardingProfile {
  const OnboardingProfile({
    this.authProvider,
    this.accountCreatedAt,
    this.firstName,
    this.dateOfBirth,
    this.goals = const {},
    this.fitnessLevel,
    this.scheduleWindow,
    this.notifications = const NotificationPrefs(),
    this.healthConnections = const HealthConnections(),
    this.currentStep = OnboardingStep.goals,
    this.onboardingComplete = false,
    this.completedAt,
  });

  final AuthProvider? authProvider;
  final DateTime? accountCreatedAt;
  final String? firstName;
  final DateTime? dateOfBirth;
  final Set<Goal> goals;
  final FitnessLevel? fitnessLevel;
  final ScheduleWindow? scheduleWindow;
  final NotificationPrefs notifications;
  final HealthConnections healthConnections;

  /// The next 07-13 screen to resume at. Only ever consulted by the router
  /// once [onboardingComplete] is false — see `resolveAuthenticatedDestination`.
  final OnboardingStep currentStep;

  /// Set true ONLY by 13_finish_setup (`OnboardingController.
  /// completeOnboarding`) — AU06 must never set this.
  final bool onboardingComplete;
  final DateTime? completedAt;

  OnboardingProfile copyWith({
    AuthProvider? authProvider,
    DateTime? accountCreatedAt,
    String? firstName,
    DateTime? dateOfBirth,
    Set<Goal>? goals,
    FitnessLevel? fitnessLevel,
    ScheduleWindow? scheduleWindow,
    NotificationPrefs? notifications,
    HealthConnections? healthConnections,
    OnboardingStep? currentStep,
    bool? onboardingComplete,
    DateTime? completedAt,
  }) {
    return OnboardingProfile(
      authProvider: authProvider ?? this.authProvider,
      accountCreatedAt: accountCreatedAt ?? this.accountCreatedAt,
      firstName: firstName ?? this.firstName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      goals: goals ?? this.goals,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      scheduleWindow: scheduleWindow ?? this.scheduleWindow,
      notifications: notifications ?? this.notifications,
      healthConnections: healthConnections ?? this.healthConnections,
      currentStep: currentStep ?? this.currentStep,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    if (authProvider != null) 'authProvider': authProvider!.name,
    if (accountCreatedAt != null)
      'accountCreatedAt': accountCreatedAt!.toIso8601String(),
    if (firstName != null) 'firstName': firstName,
    if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
    'goals': goals.map((g) => g.name).toList(),
    if (fitnessLevel != null) 'fitnessLevel': fitnessLevel!.name,
    if (scheduleWindow != null) 'scheduleWindow': scheduleWindow!.name,
    'notifications': notifications.toJson(),
    'healthConnections': healthConnections.toJson(),
    'currentStep': currentStep.name,
    'onboardingComplete': onboardingComplete,
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  factory OnboardingProfile.fromJson(Map<String, dynamic> j) =>
      OnboardingProfile(
        authProvider: j['authProvider'] == null
            ? null
            : AuthProvider.values.byName(j['authProvider'] as String),
        accountCreatedAt: j['accountCreatedAt'] == null
            ? null
            : DateTime.parse(j['accountCreatedAt'] as String),
        firstName: j['firstName'] as String?,
        dateOfBirth: j['dateOfBirth'] == null
            ? null
            : DateTime.parse(j['dateOfBirth'] as String),
        goals:
            (j['goals'] as List<dynamic>?)
                ?.map((g) => Goal.values.byName(g as String))
                .toSet() ??
            const {},
        fitnessLevel: j['fitnessLevel'] == null
            ? null
            : FitnessLevel.values.byName(j['fitnessLevel'] as String),
        scheduleWindow: j['scheduleWindow'] == null
            ? null
            : ScheduleWindow.values.byName(j['scheduleWindow'] as String),
        notifications: j['notifications'] == null
            ? const NotificationPrefs()
            : NotificationPrefs.fromJson(
                j['notifications'] as Map<String, dynamic>,
              ),
        healthConnections: j['healthConnections'] == null
            ? const HealthConnections()
            : HealthConnections.fromJson(
                j['healthConnections'] as Map<String, dynamic>,
              ),
        currentStep: j['currentStep'] == null
            ? OnboardingStep.goals
            : OnboardingStep.values.byName(j['currentStep'] as String),
        onboardingComplete: j['onboardingComplete'] as bool? ?? false,
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt'] as String),
      );
}
