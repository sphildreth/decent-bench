import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_manager.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:decent_bench/features/workspace/presentation/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workspace screen defers controller sync until after build', (
    tester,
  ) async {
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
      workspaceStateStore: InMemoryWorkspaceStateStore(),
      savedQueryLibraryStore: InMemorySavedQueryLibraryStore(),
    );
    final themeManager = ThemeManager();

    addTearDown(() {
      controller.dispose();
      themeManager.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);

    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: WorkspaceScreen(
          controller: controller,
          themeManager: themeManager,
          appLifecycleService: FakeAppLifecycleService(),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(WorkspaceScreen), findsOneWidget);
  });

  testWidgets('ERD shows loading during workspace startup initialization', (
    tester,
  ) async {
    final themeManager = ThemeManager();
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
      workspaceStateStore: InMemoryWorkspaceStateStore(),
      savedQueryLibraryStore: InMemorySavedQueryLibraryStore(),
    );

    addTearDown(() async {
      controller.dispose();
      themeManager.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: WorkspaceScreen(
          controller: controller,
          themeManager: themeManager,
          appLifecycleService: FakeAppLifecycleService(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('ERD'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('No tables'), findsNothing);
  });
}
