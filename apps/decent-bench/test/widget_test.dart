import 'package:decent_bench/app/app.dart';
import 'package:decent_bench/features/workspace/application/workspace_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
    description: 'TextField labeled $label',
  );
}

void main() {
  testWidgets('renders the Phase 3 workspace shell and editor tools', (
    tester,
  ) async {
    final controller = WorkspaceController(
      gateway: FakeWorkspaceGateway(),
      configStore: InMemoryConfigStore(),
      workspaceStateStore: InMemoryWorkspaceStateStore(),
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
    expect(find.text('Schema'), findsOneWidget);
    expect(find.text('SQL Workspace'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('New Tab'), findsOneWidget);
    expect(find.text('Format SQL'), findsOneWidget);
    expect(find.text('Insert Snippet'), findsOneWidget);
    expect(find.text('Manage Snippets'), findsOneWidget);

    await tester.enterText(_fieldWithLabel('SQL'), 'SELECT cou');
    await tester.pumpAndSettle();

    expect(find.text('Autocomplete'), findsOneWidget);
    expect(find.text('COUNT'), findsOneWidget);

    final manageSnippetsButton = find.widgetWithText(
      OutlinedButton,
      'Manage Snippets',
    );
    await tester.ensureVisible(manageSnippetsButton);
    await tester.tap(manageSnippetsButton);
    await tester.pumpAndSettle();

    expect(find.text('SQL Snippets'), findsOneWidget);
    expect(find.text('Recursive CTE'), findsOneWidget);
  });
}
