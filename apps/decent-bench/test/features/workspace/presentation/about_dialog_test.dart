import 'package:decent_bench/app/app_metadata.dart';
import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/presentation/about_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('about dialog shows branding and actions', (tester) async {
    var viewedLicenses = false;
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDecentBenchTheme(buildEmergencyTheme()),
        home: Scaffold(
          body: DecentBenchAboutDialog(
            onViewLicenses: () {
              viewedLicenses = true;
            },
            onClose: () {
              closed = true;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(kDecentBenchDisplayName), findsOneWidget);
    expect(find.text('Version $kDecentBenchVersion'), findsOneWidget);
    expect(find.bySemanticsLabel('Decent Bench logo'), findsOneWidget);
    expect(find.text('View licenses'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.text('View licenses'));
    expect(viewedLicenses, isTrue);

    await tester.tap(find.text('Close'));
    expect(closed, isTrue);
  });
}
