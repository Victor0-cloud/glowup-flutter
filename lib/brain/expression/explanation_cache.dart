import '../recommendations/typed_action.dart';

/// Cache key exactly matching the amendment's stated shape: (action_type,
/// reason_code_set, tone, locale) — never a user id, never any
/// user-specific value, so an entry is always safe to share across every
/// call for the same action/reason/tone/locale combination.
class ExplanationCacheKey {
  ExplanationCacheKey({
    required this.action,
    required List<String> reasonCodes,
    required this.tone,
    required this.locale,
  }) : reasonCodes = List.unmodifiable([...reasonCodes]..sort());

  final TypedActionType action;
  final List<String> reasonCodes;
  final String tone;
  final String locale;

  String get cacheKey =>
      '${action.name}|${reasonCodes.join(',')}|$tone|$locale';
}

/// In-memory, context-free explanation cache. A cache hit means Tier 3
/// never needs to consult a template *or* a model for that call — see
/// [TemplateOnlyExpressionService.explain].
class ExplanationCache {
  final Map<String, String> _store = {};

  String? get(ExplanationCacheKey key) => _store[key.cacheKey];

  void put(ExplanationCacheKey key, String value) =>
      _store[key.cacheKey] = value;

  void clear() => _store.clear();
}
