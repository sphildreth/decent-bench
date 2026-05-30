class AppearanceSettings {
  static const String defaultActiveTheme = 'classic-dark';
  static const Object _unset = Object();

  const AppearanceSettings({required this.activeTheme, this.themesDir});

  final String activeTheme;
  final String? themesDir;

  factory AppearanceSettings.defaults() {
    return const AppearanceSettings(activeTheme: defaultActiveTheme);
  }

  AppearanceSettings copyWith({
    String? activeTheme,
    Object? themesDir = _unset,
  }) {
    return AppearanceSettings(
      activeTheme: activeTheme ?? this.activeTheme,
      themesDir: themesDir == _unset ? this.themesDir : themesDir as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppearanceSettings &&
        other.activeTheme == activeTheme &&
        other.themesDir == themesDir;
  }

  @override
  int get hashCode => Object.hash(activeTheme, themesDir);
}
