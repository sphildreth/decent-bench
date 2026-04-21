import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/domain/workspace_shell_preferences.dart';
import 'package:decent_bench/features/workspace/infrastructure/layout_persistence_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load returns normalized shell preferences from config', () {
    final service = const LayoutPersistenceService();
    final config = AppConfig.defaults().copyWith(
      shellPreferences: const WorkspaceShellPreferences(
        leftColumnFraction: 0.10,
        leftTopFraction: 0.99,
        rightTopFraction: 0.55,
        showSchemaExplorer: true,
        showPropertiesPane: false,
        showResultsPane: true,
        showStatusBar: true,
        editorZoom: 2.0,
        activeResultsTab: ResultsPaneTab.messages,
      ),
    );

    final prefs = service.load(config);

    expect(prefs.leftColumnFraction, closeTo(0.18, 0.001));
    expect(prefs.leftTopFraction, closeTo(0.82, 0.001));
    expect(prefs.showPropertiesPane, isFalse);
    expect(prefs.activeResultsTab, ResultsPaneTab.messages);
    expect(prefs.editorZoom, closeTo(1.4, 0.001));
  });

  test('save updates config with normalized preferences', () {
    final service = const LayoutPersistenceService();
    final original = AppConfig.defaults();
    final prefs = const WorkspaceShellPreferences(
      leftColumnFraction: 0.50,
      leftTopFraction: 0.50,
      rightTopFraction: 0.50,
      showSchemaExplorer: false,
      showPropertiesPane: false,
      showResultsPane: false,
      showStatusBar: false,
      editorZoom: 1.0,
      activeResultsTab: ResultsPaneTab.executionPlan,
    );

    final updated = service.save(original, prefs);

    expect(updated.shellPreferences.showSchemaExplorer, isFalse);
    expect(
      updated.shellPreferences.activeResultsTab,
      ResultsPaneTab.executionPlan,
    );
    expect(updated.shellPreferences.leftColumnFraction, closeTo(0.50, 0.001));
    expect(updated.defaultPageSize, original.defaultPageSize);
  });

  test('round-trip preserves identity when values are in range', () {
    final service = const LayoutPersistenceService();
    final config = AppConfig.defaults();

    final loaded = service.load(config);
    final saved = service.save(config, loaded);

    expect(
      saved.shellPreferences.leftColumnFraction,
      closeTo(loaded.leftColumnFraction, 0.001),
    );
    expect(
      saved.shellPreferences.showSchemaExplorer,
      loaded.showSchemaExplorer,
    );
  });
}
