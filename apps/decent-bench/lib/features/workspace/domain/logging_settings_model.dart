enum LogVerbosity {
  debug(0, 'Debug'),
  information(1, 'Information'),
  warning(2, 'Warning'),
  error(3, 'Errors');

  const LogVerbosity(this.value, this.label);

  final int value;
  final String label;

  String get tomlValue => name;

  static LogVerbosity parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in LogVerbosity.values) {
      if (value.name == normalized || value.label.toLowerCase() == normalized) {
        return value;
      }
    }
    return LogVerbosity.warning;
  }
}

class LoggingSettings {
  const LoggingSettings({required this.verbosity});

  final LogVerbosity verbosity;

  factory LoggingSettings.defaults() {
    return const LoggingSettings(verbosity: LogVerbosity.warning);
  }

  LoggingSettings copyWith({LogVerbosity? verbosity}) {
    return LoggingSettings(verbosity: verbosity ?? this.verbosity);
  }
}
