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
  });

  /// Performance profile. One of [kDatabaseProfiles]. Selecting a profile
  /// resets the entire engine `DbConfig`; other open options applied after
  /// `profile=` override any conflicting values. Defaults to `'default'`.
  final String profile;

  /// Whether the query plan cache is enabled. Defaults to `true`.
  final bool planCacheEnabled;

  /// Optional cap on plan cache memory. `null` means use the engine default.
  final int? planCacheMaxBytes;

  factory DatabaseOpenSettings.defaults() => const DatabaseOpenSettings();

  DatabaseOpenSettings copyWith({
    String? profile,
    bool? planCacheEnabled,
    Object? planCacheMaxBytes = _unset,
  }) {
    return DatabaseOpenSettings(
      profile: profile ?? this.profile,
      planCacheEnabled: planCacheEnabled ?? this.planCacheEnabled,
      planCacheMaxBytes: planCacheMaxBytes == _unset
          ? this.planCacheMaxBytes
          : planCacheMaxBytes as int?,
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
        other.planCacheMaxBytes == planCacheMaxBytes;
  }

  @override
  int get hashCode => Object.hash(profile, planCacheEnabled, planCacheMaxBytes);

  @override
  String toString() =>
      'DatabaseOpenSettings(profile: $profile, planCacheEnabled: '
      '$planCacheEnabled, planCacheMaxBytes: $planCacheMaxBytes)';
}

const Object _unset = Object();
