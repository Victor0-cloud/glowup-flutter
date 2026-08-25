import 'circuit_breaker.dart';

/// One cost/telemetry record for a single Tier 3 or Tier 4 processing
/// step. Attached to the recommendation-expression call (Tier 3) or the
/// batch-run record (Tier 4) per the amendment. Never carries private user
/// content — only structural metadata.
class CostMetricRecord {
  const CostMetricRecord({
    required this.tier,
    this.modelProvider,
    this.modelId,
    this.inputTokens,
    this.outputTokens,
    this.estimatedCost,
    required this.cacheHit,
    required this.templateFallbackUsed,
    required this.circuitBreakerState,
    required this.budgetLimited,
    this.ruleVersion,
    this.modelVersion,
    required this.timestamp,
  });

  final int tier;
  final String? modelProvider;
  final String? modelId;
  final int? inputTokens;
  final int? outputTokens;
  final double? estimatedCost;
  final bool cacheHit;
  final bool templateFallbackUsed;
  final CircuitState circuitBreakerState;
  final bool budgetLimited;
  final int? ruleVersion;
  final String? modelVersion;
  final DateTime timestamp;
}

/// In-memory log of [CostMetricRecord]s for the current app session — real
/// structural telemetry, not persisted durably in this first slice (no
/// real spend has ever occurred to make durability load-bearing yet, since
/// no model provider is connected). Kept as its own small service so it's
/// trivial to redirect to durable storage or a real metrics sink later
/// without touching Tier 3/4 call sites.
class CostMetricsLog {
  final List<CostMetricRecord> _records = [];

  void record(CostMetricRecord record) => _records.add(record);

  List<CostMetricRecord> get all => List.unmodifiable(_records);

  List<CostMetricRecord> forTier(int tier) =>
      _records.where((r) => r.tier == tier).toList();
}
