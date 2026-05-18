import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/application/menu_command_registry.dart';
import 'package:decent_bench/features/workspace/presentation/shell/command_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

MenuCommandRegistry _buildRegistry({
  List<String> invokeLog = const [],
}) {
  return MenuCommandRegistry(
    commands: <MenuCommand>[
      MenuCommand(
        id: 'file_open',
        label: 'Open...',
        icon: Icons.folder_open_outlined,
        onInvoke: () async => invokeLog.add('file_open'),
      ),
      MenuCommand(
        id: 'file_save',
        label: 'Save',
        icon: Icons.save_outlined,
        onInvoke: () async => invokeLog.add('file_save'),
      ),
      MenuCommand(
        id: 'export_results_csv',
        label: 'Export Results as CSV...',
        icon: Icons.file_download_outlined,
        onInvoke: () async => invokeLog.add('export_results_csv'),
      ),
      MenuCommand(
        id: 'export_results_json',
        label: 'Export Results as JSON...',
        icon: Icons.data_object_outlined,
        enabled: false,
        onInvoke: () async => invokeLog.add('export_results_json'),
      ),
      MenuCommand(
        id: 'tools_run_query',
        label: 'Run Query',
        icon: Icons.play_arrow_outlined,
        onInvoke: () async => invokeLog.add('tools_run_query'),
      ),
      MenuCommand(
        id: 'view_zoom_in',
        label: 'Zoom In',
        icon: Icons.zoom_in_outlined,
        onInvoke: () async => invokeLog.add('view_zoom_in'),
      ),
    ],
  );
}

extension on WidgetTester {
  Future<void> sendKeyDownUp(LogicalKeyboardKey key) async {
    await sendKeyDownEvent(key);
    await pump();
    await sendKeyUpEvent(key);
    await pump();
  }
}

void main() {
  group('CommandPalette', () {
    late List<String> invokeLog;

    setUp(() {
      invokeLog = <String>[];
    });

    Widget buildPalette(
      MenuCommandRegistry registry, {
      VoidCallback? onDismiss,
    }) {
      return MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: CommandPalette(
            registry: registry,
            onDismiss: onDismiss ?? () {},
          ),
        ),
      );
    }

    testWidgets('shows all commands when search is empty', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      expect(find.text('Open...'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Export Results as CSV...'), findsOneWidget);
      expect(find.text('Export Results as JSON...'), findsOneWidget);
      expect(find.text('Run Query'), findsOneWidget);
      expect(find.text('Zoom In'), findsOneWidget);
    });

    testWidgets('fuzzy search filters commands', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'exp');
      await tester.pump();

      expect(find.text('Export Results as CSV...'), findsOneWidget);
      expect(find.text('Export Results as JSON...'), findsOneWidget);
      expect(find.text('Open...'), findsNothing);
      expect(find.text('Run Query'), findsNothing);
    });

    testWidgets('fuzzy search with mixed case', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'ExPo');
      await tester.pump();

      expect(find.text('Export Results as CSV...'), findsOneWidget);
      expect(find.text('Export Results as JSON...'), findsOneWidget);
    });

    testWidgets('shows no matching commands message', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pump();

      expect(find.text('No matching commands'), findsOneWidget);
    });

    testWidgets('arrow down and enter executes command', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.sendKeyDownUp(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownUp(LogicalKeyboardKey.enter);

      expect(invokeLog, contains('file_save'));
    });

    testWidgets('arrow down twice selects third command', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.sendKeyDownUp(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownUp(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownUp(LogicalKeyboardKey.enter);

      expect(invokeLog, contains('export_results_csv'));
    });

    testWidgets('escape dismisses palette', (tester) async {
      var dismissed = false;
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(
        buildPalette(registry, onDismiss: () => dismissed = true),
      );
      await tester.pump();

      await tester.sendKeyDownUp(LogicalKeyboardKey.escape);

      expect(dismissed, isTrue);
    });

    testWidgets('disabled command shows unavailable text', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'json');
      await tester.pump();

      expect(find.text('Export Results as JSON...'), findsOneWidget);
      expect(find.text('unavailable'), findsOneWidget);
    });

    testWidgets('clicking outside palette dismisses', (tester) async {
      var dismissed = false;
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(
        buildPalette(registry, onDismiss: () => dismissed = true),
      );
      await tester.pump();

      final paletteFinder = find.byType(CommandPalette);
      await tester.tapAt(
        tester.getCenter(paletteFinder) - const Offset(0, 300),
      );
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('entering search resets selection to first item', (
      tester,
    ) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.sendKeyDownUp(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownUp(LogicalKeyboardKey.arrowDown);

      await tester.enterText(find.byType(TextField), 'exp');
      await tester.pump();
      await tester.sendKeyDownUp(LogicalKeyboardKey.enter);

      expect(invokeLog, contains('export_results_csv'));
    });

    testWidgets('page down skips by 10', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      await tester.sendKeyDownUp(LogicalKeyboardKey.pageDown);
      await tester.sendKeyDownUp(LogicalKeyboardKey.enter);

      expect(invokeLog, isNotEmpty);
    });

    testWidgets('clicking command executes and dismisses', (tester) async {
      var dismissed = false;
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(
        buildPalette(registry, onDismiss: () => dismissed = true),
      );
      await tester.pump();

      await tester.tap(find.text('Open...'));
      await tester.pump();

      expect(invokeLog, contains('file_open'));
      expect(dismissed, isTrue);
    });

    testWidgets('search text field has focus on open', (tester) async {
      final registry = _buildRegistry(invokeLog: invokeLog);
      await tester.pumpWidget(buildPalette(registry));
      await tester.pump();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.focusNode?.hasPrimaryFocus, isTrue);
    });
  });
}
