enum SectionPhase { idle, loading, ready, refreshing, failed }

class AsyncSection<T> {
  const AsyncSection({
    this.phase = SectionPhase.idle,
    this.value,
    this.error,
    this.lastSuccessfulFetch,
    this.sourceSampleAt,
  });

  final SectionPhase phase;
  final T? value;
  final Object? error;
  final DateTime? lastSuccessfulFetch;
  final DateTime? sourceSampleAt;

  bool get hasValue => value != null;
  bool get isBusy =>
      phase == SectionPhase.loading || phase == SectionPhase.refreshing;
  bool get isStale => error != null && value != null;

  AsyncSection<T> begin() {
    return AsyncSection<T>(
      phase: value == null ? SectionPhase.loading : SectionPhase.refreshing,
      value: value,
      lastSuccessfulFetch: lastSuccessfulFetch,
      sourceSampleAt: sourceSampleAt,
    );
  }

  AsyncSection<T> succeed(T next, {DateTime? sourceSampleAt}) {
    return AsyncSection<T>(
      phase: SectionPhase.ready,
      value: next,
      lastSuccessfulFetch: DateTime.now().toUtc(),
      sourceSampleAt: sourceSampleAt,
    );
  }

  AsyncSection<T> fail(Object nextError) {
    return AsyncSection<T>(
      phase: SectionPhase.failed,
      value: value,
      error: nextError,
      lastSuccessfulFetch: lastSuccessfulFetch,
      sourceSampleAt: sourceSampleAt,
    );
  }
}
