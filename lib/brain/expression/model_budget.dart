/// Per-user daily ceilings for Tier 3 (required) and optional Tier 4 model
/// calls. Real, testable infrastructure kept ready for the day a real
/// model provider is connected — [TemplateOnlyExpressionService] never
/// actually needs to consult this today (it never calls a model at all),
/// but the guard must exist and be provably correct *before* any real
/// provider is wired in, not bolted on afterward.
class ModelBudgetGuard {
  ModelBudgetGuard({this.dailyTier3Ceiling = 50, this.dailyTier4Ceiling = 5});

  final int dailyTier3Ceiling;
  final int dailyTier4Ceiling;

  final Map<String, int> _tier3CountByUserDay = {};
  final Map<String, int> _tier4CountByUserDay = {};

  String _key(String userId, DateTime now) =>
      '$userId|${now.year}-${now.month}-${now.day}';

  bool canCallTier3(String userId, DateTime now) =>
      (_tier3CountByUserDay[_key(userId, now)] ?? 0) < dailyTier3Ceiling;

  void recordTier3Call(String userId, DateTime now) {
    final key = _key(userId, now);
    _tier3CountByUserDay[key] = (_tier3CountByUserDay[key] ?? 0) + 1;
  }

  bool canCallTier4(String userId, DateTime now) =>
      (_tier4CountByUserDay[_key(userId, now)] ?? 0) < dailyTier4Ceiling;

  void recordTier4Call(String userId, DateTime now) {
    final key = _key(userId, now);
    _tier4CountByUserDay[key] = (_tier4CountByUserDay[key] ?? 0) + 1;
  }
}
