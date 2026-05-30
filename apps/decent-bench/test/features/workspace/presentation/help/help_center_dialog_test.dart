import 'package:decent_bench/features/workspace/presentation/help/help_center_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (tester.any(finder)) {
      return;
    }
  }
}

void main() {
  testWidgets('help center loads bundled articles and searches them', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: HelpCenterDialog(key: ValueKey<String>('help-search')),
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Decent Bench Help Center'));

    expect(find.text('Decent Bench Help Center'), findsOneWidget);
    expect(find.text('Getting Started'), findsWidgets);
    expect(find.textContaining('Open a DecentDB file'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey<String>('help_center.search_field')),
      'parquet',
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.text('Exporting Results'));

    expect(find.text('Exporting Results'), findsWidgets);

    await tester.tap(find.text('Exporting Results').first);
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(
        const ValueKey<String>('help_center.article.exporting-results'),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('help_center.article.exporting-results'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Parquet is planned'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
