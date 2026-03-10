import 'dart:convert';

class WorkspaceTabDraft {
  const WorkspaceTabDraft({
    required this.id,
    required this.title,
    required this.sql,
    required this.parameterJson,
    required this.exportPath,
  });

  final String id;
  final String title;
  final String sql;
  final String parameterJson;
  final String exportPath;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'sql': sql,
      'parameterJson': parameterJson,
      'exportPath': exportPath,
    };
  }

  factory WorkspaceTabDraft.fromJson(Map<String, Object?> map) {
    return WorkspaceTabDraft(
      id: map['id']! as String,
      title: map['title']! as String,
      sql: map['sql']! as String,
      parameterJson: map['parameterJson']! as String,
      exportPath: map['exportPath'] as String? ?? '',
    );
  }
}

class PersistedWorkspaceState {
  const PersistedWorkspaceState({
    required this.schemaVersion,
    required this.activeTabId,
    required this.tabs,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String? activeTabId;
  final List<WorkspaceTabDraft> tabs;

  factory PersistedWorkspaceState.empty() {
    return const PersistedWorkspaceState(
      schemaVersion: currentSchemaVersion,
      activeTabId: null,
      tabs: <WorkspaceTabDraft>[],
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'activeTabId': activeTabId,
      'tabs': <Map<String, Object?>>[for (final tab in tabs) tab.toJson()],
    };
  }

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory PersistedWorkspaceState.decode(String source) {
    final decoded = jsonDecode(source) as Map<String, Object?>;
    return PersistedWorkspaceState.fromJson(decoded);
  }

  factory PersistedWorkspaceState.fromJson(Map<String, Object?> map) {
    return PersistedWorkspaceState(
      schemaVersion: map['schemaVersion'] as int? ?? currentSchemaVersion,
      activeTabId: map['activeTabId'] as String?,
      tabs: ((map['tabs'] as List?) ?? const <Object?>[])
          .cast<Map<Object?, Object?>>()
          .map(
            (tab) => WorkspaceTabDraft.fromJson(
              tab.map((key, value) => MapEntry(key as String, value)),
            ),
          )
          .toList(),
    );
  }
}
