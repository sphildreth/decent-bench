import 'dart:io';

import 'package:decent_bench/features/workspace/domain/saved_query_models.dart';
import 'package:decent_bench/features/workspace/infrastructure/saved_query_library_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file saved query store writes and reads per-database TOML', () async {
    final root = await Directory.systemTemp.createTemp('saved-query-store-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final store = FileSavedQueryLibraryStore(rootOverride: root);
    final library = SavedQueryLibrary(
      queries: <SavedQuery>[
        SavedQuery(
          id: 'query-1',
          name: 'Tasks',
          sql: 'SELECT * FROM tasks',
          createdAt: DateTime.utc(2026, 5, 19),
          updatedAt: DateTime.utc(2026, 5, 19),
        ),
      ],
    );

    await store.save('/tmp/tasks.ddb', library);
    final loaded = await store.load('/tmp/tasks.ddb');

    expect(loaded.queries.single.name, 'Tasks');
    expect(await File(store.describeLocation('/tmp/tasks.ddb')).exists(), true);
  });
}
