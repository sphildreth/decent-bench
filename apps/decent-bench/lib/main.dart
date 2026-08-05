import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/headless_import_runner.dart';
import 'app/headless_quality_runner.dart';
import 'app/startup_launch_options.dart';
import 'app/window_placement/window_placement_service.dart';
import 'features/workspace/infrastructure/app_config_store.dart';
import 'features/workspace/infrastructure/decentdb_bridge.dart';
import 'features/workspace/infrastructure/decentdb_native_release_asset.dart';

Future<void> main(List<String> args) async {
  final cliDecision = parseStartupCliDecision(args);
  switch (cliDecision.behavior) {
    case StartupCliBehavior.launchApp:
      WidgetsFlutterBinding.ensureInitialized();
      _installGlobalErrorBoundary();
      _installEngineVersionMismatchGuard();
      final configStore = AppConfigStore();
      final initialConfig = await configStore.load();
      await const WindowPlacementService().restore(
        initialConfig.windowPlacement,
      );
      runApp(
        DecentBenchApp(
          startupLaunchOptions: cliDecision.launchOptions,
          initialConfig: initialConfig,
        ),
      );
      return;
    case StartupCliBehavior.runHeadlessImport:
      _installEngineVersionMismatchGuard();
      exit(await runHeadlessImportCli(cliDecision.headlessImportOptions!));
    case StartupCliBehavior.runHeadlessQuality:
      _installEngineVersionMismatchGuard();
      exit(await runHeadlessQualityCli(cliDecision.headlessQualityOptions!));
    case StartupCliBehavior.printHelp:
    case StartupCliBehavior.printVersion:
      stdout.writeln(cliDecision.output ?? '');
      return;
    case StartupCliBehavior.printError:
      stderr.writeln(cliDecision.output ?? '');
      exitCode = cliDecision.exitCode;
      return;
  }
}

void _installEngineVersionMismatchGuard() {
  try {
    final lockFile = File('pubspec.lock');
    if (!lockFile.existsSync()) {
      return;
    }
    final pinned = DecentDbNativeReleaseAsset.parsePinnedTagFromPubspecLock(
      lockFile.readAsStringSync(),
    );
    DecentDbBridge.setPinnedDecentDbTag(pinned);
  } catch (error) {
    debugPrint('Failed to install DecentDB engine version guard: $error');
  }
}

void _installGlobalErrorBoundary() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    stderr.writeln(
      '[DecentBench] Unhandled Flutter error: ${details.exception}\n'
      '${details.stack ?? ''}',
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    stderr.writeln(
      '[DecentBench] Unhandled async error: $error\n$stack',
    );
    return true;
  };
}
