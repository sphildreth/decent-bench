const List<String> kDatabaseProfiles = <String>[
  'default',
  'low_memory',
  'balanced',
  'embedded_fast',
  'tuned_durable',
];

const Map<String, String> kDatabaseProfileLabels = <String, String>{
  'default': 'Default',
  'low_memory': 'Low memory',
  'balanced': 'Balanced',
  'embedded_fast': 'Embedded (fast)',
  'tuned_durable': 'Tuned (durable)',
};

class DatabaseOpenSettings {
  const DatabaseOpenSettings({
    this.profile = 'default',
    this.planCacheEnabled = true,
    this.planCacheMaxBytes,
    this.processCoordinationTimeoutMs,
    this.openBridgeTimeoutMs,
  });

  /// Performance profile. One of [kDatabaseProfiles]. Selecting a profile
  /// resets the entire engine `DbConfig`; other open options applied after
  /// `profile=` override any conflicting values. Defaults to `'default'`.
  final String profile;

  /// Whether the query plan cache is enabled. Defaults to `true`.
  final bool planCacheEnabled;

  /// Optional cap on plan cache memory. `null` means use the engine default.
  final int? planCacheMaxBytes;

  /// Optional override for the engine's process-coordination writer-lock
  /// wait, in milliseconds. `null` means use the engine default (30s).
  /// Raise this if the engine returns `DDB_ERR_TIMEOUT` on open when
  /// another process holds the writer lock, when opening a database with
  /// a large WAL on a slow filesystem, or when a stale `.coord` file is
  /// present.
  final int? processCoordinationTimeoutMs;

  /// Optional override for the **bridge** open timeout, in milliseconds.
  /// This is the Dart-side request timeout (default 5 minutes) that wraps
  /// the engine's own coordination timeout. The bridge timeout must be
  /// greater than `processCoordinationTimeoutMs`, otherwise the bridge
  /// will outrace the engine and surface a misleading bridge-level
  /// timeout instead of the engine's actual response. `null` means use
  /// the bridge default (5 minutes) — or the value of
  /// `DECENT_BENCH_OPEN_TIMEOUT_MS` if set in the environment.
  final int? openBridgeTimeoutMs;

  factory DatabaseOpenSettings.defaults() => const DatabaseOpenSettings();

  DatabaseOpenSettings copyWith({
    String? profile,
    bool? planCacheEnabled,
    Object? planCacheMaxBytes = _unset,
    Object? processCoordinationTimeoutMs = _unset,
    Object? openBridgeTimeoutMs = _unset,
  }) {
    return DatabaseOpenSettings(
      profile: profile ?? this.profile,
      planCacheEnabled: planCacheEnabled ?? this.planCacheEnabled,
      planCacheMaxBytes: planCacheMaxBytes == _unset
          ? this.planCacheMaxBytes
          : planCacheMaxBytes as int?,
      processCoordinationTimeoutMs: processCoordinationTimeoutMs == _unset
          ? this.processCoordinationTimeoutMs
          : processCoordinationTimeoutMs as int?,
      openBridgeTimeoutMs: openBridgeTimeoutMs == _unset
          ? this.openBridgeTimeoutMs
          : openBridgeTimeoutMs as int?,
    );
  }

  /// Renders the settings as a `key=value` open-options string fragment,
  /// ready to be appended to the existing `_writeQueueOpenOptionsFromPayload`
  /// output. Always emits `profile=` first because selecting a profile
  /// resets the entire engine config.
  String toOpenOptionsFragment() {
    final parts = <String>[];
    parts.add('profile=$profile');
    parts.add('plan_cache_enabled=$planCacheEnabled');
    if (planCacheMaxBytes != null) {
      parts.add('plan_cache_max_bytes=$planCacheMaxBytes');
    }
    if (processCoordinationTimeoutMs != null) {
      parts.add('process_coordination_timeout_ms=$processCoordinationTimeoutMs');
    }
    return parts.join(',');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DatabaseOpenSettings &&
        other.profile == profile &&
        other.planCacheEnabled == planCacheEnabled &&
        other.planCacheMaxBytes == planCacheMaxBytes &&
        other.processCoordinationTimeoutMs == processCoordinationTimeoutMs &&
        other.openBridgeTimeoutMs == openBridgeTimeoutMs;
  }

  @override
  int get hashCode => Object.hash(
        profile,
        planCacheEnabled,
        planCacheMaxBytes,
        processCoordinationTimeoutMs,
        openBridgeTimeoutMs,
      );

  @override
  String toString() =>
      'DatabaseOpenSettings(profile: $profile, planCacheEnabled: '
      '$planCacheEnabled, planCacheMaxBytes: $planCacheMaxBytes, '
      'processCoordinationTimeoutMs: $processCoordinationTimeoutMs, '
      'openBridgeTimeoutMs: $openBridgeTimeoutMs)';
}

const Object _unset = Object();
