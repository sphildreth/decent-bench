import 'package:decent_bench/app/app.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the phase 1 workspace shell', (tester) async {
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
    await controller.initialize();

    await tester.pumpWidget(
      DecentBenchApp(controller: controller, autoInitialize: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Decent Bench'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('SQL Editor'), findsOneWidget);
    expect(find.text('Paged Results'), findsOneWidget);
    expect(find.text('Run SQL'), findsOneWidget);
    expect(find.text('Open Existing'), findsOneWidget);
  });
}
