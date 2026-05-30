import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'app_metadata.dart';
import 'logging/app_logger.dart';
import 'startup_launch_options.dart';
import 'theme_system/theme_manager.dart';
import 'window_placement/window_placement_service.dart';
import '../features/workspace/application/workspace_controller.dart';
import '../features/workspace/domain/app_config.dart';
import '../features/workspace/infrastructure/app_lifecycle_service.dart';
import '../features/workspace/presentation/workspace_screen.dart';
import 'theme.dart';

class DecentBenchApp extends StatefulWidget {
  const DecentBenchApp({
    super.key,
    this.controller,
    this.appLifecycleService = const FlutterAppLifecycleService(),
    this.autoInitialize = true,
    this.startupLaunchOptions = const StartupLaunchOptions(),
    this.themeManager,
    this.logger,
    this.initialConfig,
    this.windowPlacementService = const WindowPlacementService(),
  });

  final WorkspaceController? controller;
  final AppLifecycleService appLifecycleService;
  final bool autoInitialize;
  final StartupLaunchOptions startupLaunchOptions;
  final ThemeManager? themeManager;
  final AppLogger? logger;
  final AppConfig? initialConfig;
  final WindowPlacementService windowPlacementService;

  @override
  State<DecentBenchApp> createState() => _DecentBenchAppState();
}

class _DecentBenchAppState extends State<DecentBenchApp> {
  late final AppLogger _logger = widget.logger ?? ClefAppLogger(
    logDirectory: widget.initialConfig?.logging.logDirectory,
  );
  late final WorkspaceController _controller =
      widget.controller ??
      WorkspaceController(logger: _logger, initialConfig: widget.initialConfig);
  late final ThemeManager _themeManager =
      widget.themeManager ?? ThemeManager(logger: _logger);

  static const Duration _windowPlacementPersistenceInterval = Duration(
    seconds: 2,
  );

  String? _lastThemeId;
  String? _lastThemesDir;
  LogVerbosity? _lastLogVerbosity;
  Timer? _windowPlacementTimer;
  AppLifecycleListener? _windowPlacementLifecycleListener;
  WindowPlacement? _lastPersistedWindowPlacement;
  bool _isPersistingWindowPlacement = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    unawaited(
      _logger.initialize(minimumLevel: _controller.config.logging.verbosity),
    );
    _syncLoggingFromConfig();
    _syncThemeFromConfig();
    _lastPersistedWindowPlacement = _controller.config.windowPlacement;
    _windowPlacementLifecycleListener = AppLifecycleListener(
      onHide: () => unawaited(_captureAndPersistWindowPlacement()),
      onInactive: () => unawaited(_captureAndPersistWindowPlacement()),
      onExitRequested: () async {
        await _captureAndPersistWindowPlacement();
        return AppExitResponse.exit;
      },
    );
    if (widget.autoInitialize) {
      unawaited(_controller.initialize());
    } else {
      _startWindowPlacementPersistence();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _windowPlacementTimer?.cancel();
    _windowPlacementLifecycleListener?.dispose();
    if (widget.themeManager == null) {
      _themeManager.dispose();
    }
    if (widget.logger == null) {
      unawaited(_logger.dispose());
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    _syncLoggingFromConfig();
    _syncThemeFromConfig();
    if (!_controller.isInitializing) {
      _startWindowPlacementPersistence();
    }
  }

  void _startWindowPlacementPersistence() {
    if (_windowPlacementTimer != null) {
      return;
    }
    _lastPersistedWindowPlacement = _controller.config.windowPlacement;
    _windowPlacementTimer = Timer.periodic(
      _windowPlacementPersistenceInterval,
      (_) => unawaited(_captureAndPersistWindowPlacement()),
    );
    unawaited(_captureAndPersistWindowPlacement());
  }

  Future<void> _captureAndPersistWindowPlacement() async {
    if (_isPersistingWindowPlacement || _controller.isInitializing) {
      return;
    }
    _isPersistingWindowPlacement = true;
    try {
      final captured = await widget.windowPlacementService.capture();
      if (captured == null) {
        return;
      }
      final normalized = captured.normalized();
      if (_lastPersistedWindowPlacement == normalized &&
          _controller.config.windowPlacement == normalized) {
        return;
      }
      _lastPersistedWindowPlacement = normalized;
      await _controller.updateWindowPlacement(normalized);
    } finally {
      _isPersistingWindowPlacement = false;
    }
  }

  void _syncLoggingFromConfig() {
    final verbosity = _controller.config.logging.verbosity;
    if (_lastLogVerbosity == verbosity) {
      return;
    }
    _lastLogVerbosity = verbosity;
    _logger.updateMinimumLevel(verbosity);
  }

  void _syncThemeFromConfig() {
    final appearance = _controller.config.appearance;
    if (_lastThemeId == appearance.activeTheme &&
        _lastThemesDir == appearance.themesDir) {
      return;
    }
    _lastThemeId = appearance.activeTheme;
    _lastThemesDir = appearance.themesDir;
    unawaited(_themeManager.loadFromConfig(appearance));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeManager,
      builder: (context, _) {
        return MaterialApp(
          title: kDecentBenchDisplayName,
          debugShowCheckedModeBanner: false,
          theme: buildDecentBenchTheme(_themeManager.currentTheme),
          home: WorkspaceScreen(
            controller: _controller,
            themeManager: _themeManager,
            appLifecycleService: widget.appLifecycleService,
            startupLaunchOptions: widget.startupLaunchOptions,
          ),
        );
      },
    );
  }
}
