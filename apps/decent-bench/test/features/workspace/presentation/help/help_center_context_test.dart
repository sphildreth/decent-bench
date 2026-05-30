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
  testWidgets('help center can open to a context topic', (tester) async {
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
            child: HelpCenterDialog(
              key: ValueKey<String>('help-context'),
              initialArticleId: 'writing-sql',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey<String>('help_center.article.writing-sql')),
    );

    expect(
      find.byKey(const ValueKey<String>('help_center.article.writing-sql')),
      findsOneWidget,
    );
    expect(find.textContaining('Run the current statement'), findsOneWidget);
  });
}
