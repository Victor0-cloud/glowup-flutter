import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recommendations/typed_action.dart';
import 'circuit_breaker.dart';
import 'cost_metrics.dart';
import 'explanation_cache.dart';
import 'explanation_templates.dart';
import 'model_budget.dart';

enum ExplanationSource { cache, template, model, fallback }

class ExplanationResult {
  const ExplanationResult({required this.text, required this.source});
  final String text;
  final ExplanationSource source;
}

/// Tier 3 — the only tier allowed to call an AI provider, and only to turn
/// an already-selected Tier 2 [TypedActionType] + reason codes into 1-2
/// natural sentences. This interface never receives raw events, unbounded
/// history, journal content or another user's data — only the small,
/// already-validated slots in [explain]'s parameters.
abstract class GenerativeExpressionService {
  Future<ExplanationResult> explain({
    required TypedActionType action,
    required List<String> reasonCodes,
    String tone,
    String locale,
  });
}

/// The only implementation today — mirrors `UnconnectedCoachBrainService`'s
/// honesty: no AI provider is connected, so every call is served by a
/// deterministic template (or, failing that, a grounded generic fallback
/// naming only the action itself). This is not a workaround for "provider
/// unavailable" — per the amendment, an unavailable/failed provider must
/// always fall back to a template, so this is the correct, fully
/// functional steady state until a real provider exists. [budget] and
/// [circuitBreaker] are real, tested guards wired in and ready — see their
/// own docs for why they exist even though nothing here ever needs them to
/// actually gate a call.
class TemplateOnlyExpressionService implements GenerativeExpressionService {
  TemplateOnlyExpressionService({
    ExplanationCache? cache,
    ModelBudgetGuard? budget,
    CircuitBreaker? circuitBreaker,
    CostMetricsLog? costLog,
  }) : cache = cache ?? ExplanationCache(),
       budget = budget ?? ModelBudgetGuard(),
       circuitBreaker = circuitBreaker ?? CircuitBreaker(),
       costLog = costLog ?? CostMetricsLog();

  final ExplanationCache cache;
  final ModelBudgetGuard budget;
  final CircuitBreaker circuitBreaker;
  final CostMetricsLog costLog;

  @override
  Future<ExplanationResult> explain({
    required TypedActionType action,
    required List<String> reasonCodes,
    String tone = 'supportive',
    String locale = 'en',
  }) async {
    final now = DateTime.now();
    final key = ExplanationCacheKey(
      action: action,
      reasonCodes: reasonCodes,
      tone: tone,
      locale: locale,
    );
    final cached = cache.get(key);
    if (cached != null) {
      costLog.record(
        CostMetricRecord(
          tier: 3,
          cacheHit: true,
          templateFallbackUsed: false,
          circuitBreakerState: circuitBreaker.stateAt(now),
          budgetLimited: false,
          timestamp: now,
        ),
      );
      return ExplanationResult(text: cached, source: ExplanationSource.cache);
    }

    final template = templateFor(action, reasonCodes);
    final text = template ?? genericFallback(action);
    cache.put(key, text);
    costLog.record(
      CostMetricRecord(
        tier: 3,
        cacheHit: false,
        templateFallbackUsed: true,
        circuitBreakerState: circuitBreaker.stateAt(now),
        budgetLimited: false,
        timestamp: now,
      ),
    );
    return ExplanationResult(
      text: text,
      source: template != null
          ? ExplanationSource.template
          : ExplanationSource.fallback,
    );
  }
}

final generativeExpressionServiceProvider =
    Provider<GenerativeExpressionService>(
      (ref) => TemplateOnlyExpressionService(),
    );
