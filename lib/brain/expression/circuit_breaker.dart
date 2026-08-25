enum CircuitState { closed, open, halfOpen }

/// Provider failure/latency circuit breaker — real, testable infrastructure
/// kept ready for a real Tier 3/4 model provider. While open, callers must
/// fall back to a template (Tier 3) or skip the optional model call (Tier
/// 4); nothing in this app currently needs it open, since no provider is
/// connected to fail in the first place, but the mechanism must exist and
/// be correct before that day, not be added reactively after an incident.
class CircuitBreaker {
  CircuitBreaker({
    this.failureThreshold = 3,
    this.recoveryTimeout = const Duration(minutes: 5),
  });

  final int failureThreshold;
  final Duration recoveryTimeout;

  int _consecutiveFailures = 0;
  CircuitState _state = CircuitState.closed;
  DateTime? _openedAt;

  /// Resolves `open` to `halfOpen` once [recoveryTimeout] has elapsed,
  /// without mutating state as a side effect of merely checking it.
  CircuitState stateAt(DateTime now) {
    if (_state == CircuitState.open &&
        _openedAt != null &&
        now.difference(_openedAt!) >= recoveryTimeout) {
      return CircuitState.halfOpen;
    }
    return _state;
  }

  bool allowCallAt(DateTime now) => stateAt(now) != CircuitState.open;

  void recordSuccess() {
    _consecutiveFailures = 0;
    _state = CircuitState.closed;
    _openedAt = null;
  }

  void recordFailure(DateTime now) {
    _consecutiveFailures++;
    if (_consecutiveFailures >= failureThreshold) {
      _state = CircuitState.open;
      _openedAt = now;
    }
  }
}
