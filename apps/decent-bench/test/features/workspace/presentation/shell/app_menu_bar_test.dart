import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/application/menu_command_registry.dart';
import 'package:decent_bench/features/workspace/presentation/shell/app_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tools menu includes View Log', (tester) async {
    final registry = MenuCommandRegistry(
      commands: <MenuCommand>[
        MenuCommand(
          id: 'tools_view_log',
          label: 'View Log',
          icon: Icons.receipt_long_outlined,
          onInvoke: () async {},
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: AppMenuBar(
            registry: registry,
            recentFiles: const <String>[],
            onOpenRecent: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tools'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.widgetWithText(MenuItemButton, 'View Log'), findsOneWidget);
  });
}
