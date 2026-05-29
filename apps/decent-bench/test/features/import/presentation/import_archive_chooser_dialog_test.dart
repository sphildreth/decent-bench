import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/import/domain/import_models.dart';
import 'package:decent_bench/features/import/presentation/import_archive_chooser_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ImportArchiveCandidate buildCandidate({
    String entryPath = 'data/table1.csv',
    String displayName = 'table1.csv',
    ImportFormatKey innerFormatKey = ImportFormatKey.csv,
    String innerFormatLabel = 'CSV',
    ImportSupportState supportState = ImportSupportState.complete,
  }) {
    return ImportArchiveCandidate(
      entryPath: entryPath,
      displayName: displayName,
      innerFormatKey: innerFormatKey,
      innerFormatLabel: innerFormatLabel,
      supportState: supportState,
    );
  }

  Widget buildDialogUnderTest({
    required List<ImportArchiveCandidate> candidates,
    String archivePath = 'archive.zip',
    String wrapperLabel = 'ZIP',
  }) {
    return MaterialApp(
      theme: buildDecentBenchTheme(buildEmergencyTheme()),
      home: Scaffold(
        body: ImportArchiveChooserDialog(
          archivePath: archivePath,
          wrapperLabel: wrapperLabel,
          candidates: candidates,
        ),
      ),
    );
  }

  testWidgets('shows empty state when candidates list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildDialogUnderTest(candidates: const []));
    await tester.pumpAndSettle();

    expect(find.text('ZIP Contents'), findsOneWidget);
    expect(
      find.text(
        'No recognized importable files were found in this archive.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('displays candidates as selectable radio list tiles', (
    tester,
  ) async {
    final candidates = [
      buildCandidate(entryPath: 'a.csv', displayName: 'Alpha CSV'),
      buildCandidate(
        entryPath: 'b.xlsx',
        displayName: 'Beta Excel',
        innerFormatKey: ImportFormatKey.xlsx,
        innerFormatLabel: 'Excel',
      ),
    ];

    await tester.pumpWidget(buildDialogUnderTest(candidates: candidates));
    await tester.pumpAndSettle();

    expect(find.text('ZIP Contents'), findsOneWidget);
    expect(find.text('Alpha CSV'), findsOneWidget);
    expect(find.text('Beta Excel'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('first candidate is selected by default', (tester) async {
    final candidates = [
      buildCandidate(entryPath: 'a.csv', displayName: 'Alpha'),
      buildCandidate(entryPath: 'b.csv', displayName: 'Beta'),
    ];

    await tester.pumpWidget(buildDialogUnderTest(candidates: candidates));
    await tester.pumpAndSettle();

    final alphaTile = find.widgetWithText(ListTile, 'Alpha');
    final betaTile = find.widgetWithText(ListTile, 'Beta');

    expect(
      tester.widget<ListTile>(alphaTile).selected,
      isTrue,
    );
    expect(
      tester.widget<ListTile>(betaTile).selected,
      isFalse,
    );
  });

  testWidgets('tapping a candidate selects it', (tester) async {
    final candidates = [
      buildCandidate(entryPath: 'a.csv', displayName: 'Alpha'),
      buildCandidate(entryPath: 'b.csv', displayName: 'Beta'),
    ];

    await tester.pumpWidget(buildDialogUnderTest(candidates: candidates));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Beta'));
    await tester.pumpAndSettle();

    final alphaTile = find.widgetWithText(ListTile, 'Alpha');
    final betaTile = find.widgetWithText(ListTile, 'Beta');

    expect(
      tester.widget<ListTile>(alphaTile).selected,
      isFalse,
    );
    expect(
      tester.widget<ListTile>(betaTile).selected,
      isTrue,
    );
  });

  testWidgets('cancel pops dialog with null result', (tester) async {
    ImportArchiveCandidate? dialogResult;

    final candidates = [
      buildCandidate(entryPath: 'a.csv', displayName: 'Alpha'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showDialog<ImportArchiveCandidate>(
                  context: context,
                  builder: (_) => ImportArchiveChooserDialog(
                    archivePath: 'archive.zip',
                    wrapperLabel: 'ZIP',
                    candidates: candidates,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportArchiveChooserDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(dialogResult, isNull);
  });

  testWidgets('continue pops dialog with selected candidate', (tester) async {
    ImportArchiveCandidate? dialogResult;

    final candidates = [
      buildCandidate(entryPath: 'a.csv', displayName: 'Alpha'),
      buildCandidate(entryPath: 'b.csv', displayName: 'Beta'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showDialog<ImportArchiveCandidate>(
                  context: context,
                  builder: (_) => ImportArchiveChooserDialog(
                    archivePath: 'archive.zip',
                    wrapperLabel: 'ZIP',
                    candidates: candidates,
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, 'Beta'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(dialogResult, isNotNull);
    expect(dialogResult!.entryPath, 'b.csv');
    expect(dialogResult!.displayName, 'Beta');
  });
}
