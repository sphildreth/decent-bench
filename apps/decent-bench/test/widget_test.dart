import 'package:decent_bench/app/app.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('renders the Phase 1 workspace shell', (
    WidgetTester tester,
  ) async {
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      controller.dispose();
    });

    await tester.pumpWidget(
      DecentBenchApp(controller: controller, autoInitialize: false),
    );
    await tester.pump();

    expect(find.text('Decent Bench'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Schema'), findsOneWidget);
    expect(find.text('Run SQL'), findsOneWidget);
  });
}
