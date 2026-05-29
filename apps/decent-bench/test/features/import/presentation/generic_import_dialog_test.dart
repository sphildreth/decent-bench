import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/presentation/generic_import_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testFormat = ImportFormatDefinition(
    key: ImportFormatKey.csv,
    label: 'CSV',
    family: ImportFamily.delimitedText,
    supportState: ImportSupportState.complete,
    extensions: ['csv'],
    implementationKind: ImportImplementationKind.genericWizard,
    description: 'Comma-separated values',
  );

  Widget buildDialog({String sourcePath = '/tmp/test.csv'}) {
    return MaterialApp(
      theme: buildDecentBenchTheme(buildEmergencyTheme()),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (_) => const GenericImportDialog(
                  initialSourcePath: '/tmp/test.csv',
                  initialFormat: testFormat,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  testWidgets('shows wizard title with format label', (tester) async {
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('CSV Import Wizard'), findsOneWidget);
  });

  testWidgets('shows all step chips in header', (tester) async {
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Transforms'), findsOneWidget);
    expect(find.text('Execute'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
  });

  testWidgets('starts on Source step with source description', (tester) async {
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Confirm the source file and review the detected import family before loading a preview.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows source path in text field', (tester) async {
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    expect(textField, findsOneWidget);

    final field = tester.widget<TextField>(textField);
    expect(field.controller?.text, '/tmp/test.csv');
  });

  testWidgets('shows format card on source step', (tester) async {
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('CSV'), findsWidgets);
    expect(find.text('Comma-separated values'), findsOneWidget);
  });

  testWidgets('shows phase chip in header', (tester) async {
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsWidgets);
  });
}
