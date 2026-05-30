class WriteQueueSettings {
  static const bool defaultEnabled = false;
  static const int defaultCapacity = 1024;
  static const int defaultDefaultTimeoutMs = 0;
  static const int defaultMaxBatch = 64;
  static const int defaultMaxGroupDelayUs = 0;

  const WriteQueueSettings({
    required this.enabled,
    required this.capacity,
    required this.defaultTimeoutMs,
    required this.maxBatch,
    required this.maxGroupDelayUs,
  });

  final bool enabled;
  final int capacity;
  final int defaultTimeoutMs;
  final int maxBatch;
  final int maxGroupDelayUs;

  factory WriteQueueSettings.defaults() {
    return const WriteQueueSettings(
      enabled: defaultEnabled,
      capacity: defaultCapacity,
      defaultTimeoutMs: defaultDefaultTimeoutMs,
      maxBatch: defaultMaxBatch,
      maxGroupDelayUs: defaultMaxGroupDelayUs,
    );
  }

  WriteQueueSettings copyWith({
    bool? enabled,
    int? capacity,
    int? defaultTimeoutMs,
    int? maxBatch,
    int? maxGroupDelayUs,
  }) {
    return WriteQueueSettings(
      enabled: enabled ?? this.enabled,
      capacity: capacity ?? this.capacity,
      defaultTimeoutMs: defaultTimeoutMs ?? this.defaultTimeoutMs,
      maxBatch: maxBatch ?? this.maxBatch,
      maxGroupDelayUs: maxGroupDelayUs ?? this.maxGroupDelayUs,
    );
  }

  String? toDecentDbOpenOptions() {
    if (!enabled) {
      return null;
    }
    return <String>[
      'write_queue_enabled=true',
      'write_queue_capacity=$capacity',
      'write_queue_default_timeout_ms=$defaultTimeoutMs',
      'write_queue_max_batch=$maxBatch',
      'write_queue_max_group_delay_us=$maxGroupDelayUs',
    ].join(';');
  }

  @override
  bool operator ==(Object other) {
    return other is WriteQueueSettings &&
        other.enabled == enabled &&
        other.capacity == capacity &&
        other.defaultTimeoutMs == defaultTimeoutMs &&
        other.maxBatch == maxBatch &&
        other.maxGroupDelayUs == maxGroupDelayUs;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    capacity,
    defaultTimeoutMs,
    maxBatch,
    maxGroupDelayUs,
  );
}
