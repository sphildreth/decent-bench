import 'dart:convert';

import 'package:path/path.dart' as p;

import 'workspace_models.dart';

class SavedQuery {
  const SavedQuery({
    required this.id,
    required this.name,
    required this.sql,
    this.parameterJson = '',
    this.description = '',
    this.folder = '',
    this.tags = const <String>[],
    required this.createdAt,
    required this.updatedAt,
    this.schemaFingerprint,
    this.schemaFingerprintAlgorithm,
    this.queryContract,
  });

  final String id;
  final String name;
  final String sql;
  final String parameterJson;
  final String description;
  final String folder;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? schemaFingerprint;
  final String? schemaFingerprintAlgorithm;
  final QueryContract? queryContract;

  bool hasSchemaDrift(ToolingMetadata? metadata) {
    final saved = schemaFingerprint?.trim();
    if (saved == null || saved.isEmpty) {
      return false;
    }
    final current = metadata?.schemaFingerprint.trim();
    return current != null && current.isNotEmpty && current != saved;
  }

  SavedQuery copyWith({
    String? id,
    String? name,
    String? sql,
    String? parameterJson,
    String? description,
    String? folder,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? schemaFingerprint = _unset,
    Object? schemaFingerprintAlgorithm = _unset,
    Object? queryContract = _unset,
  }) {
    return SavedQuery(
      id: id ?? this.id,
      name: name ?? this.name,
      sql: sql ?? this.sql,
      parameterJson: parameterJson ?? this.parameterJson,
      description: description ?? this.description,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaFingerprint: schemaFingerprint == _unset
          ? this.schemaFingerprint
          : schemaFingerprint as String?,
      schemaFingerprintAlgorithm: schemaFingerprintAlgorithm == _unset
          ? this.schemaFingerprintAlgorithm
          : schemaFingerprintAlgorithm as String?,
      queryContract: queryContract == _unset
          ? this.queryContract
          : queryContract as QueryContract?,
    );
  }

  static const Object _unset = Object();
}

class SavedQueryLibrary {
  const SavedQueryLibrary({this.configVersion = 1, this.queries = const []});

  final int configVersion;
  final List<SavedQuery> queries;

  static const SavedQueryLibrary empty = SavedQueryLibrary();

  SavedQuery? queryById(String id) {
    for (final query in queries) {
      if (query.id == id) {
        return query;
      }
    }
    return null;
  }

  SavedQueryLibrary upsert(SavedQuery query) {
    final updated = <SavedQuery>[];
    var replaced = false;
    for (final existing in queries) {
      if (existing.id == query.id) {
        updated.add(query);
        replaced = true;
      } else {
        updated.add(existing);
      }
    }
    if (!replaced) {
      updated.add(query);
    }
    updated.sort((left, right) {
      final byFolder = left.folder.compareTo(right.folder);
      return byFolder != 0 ? byFolder : left.name.compareTo(right.name);
    });
    return SavedQueryLibrary(configVersion: configVersion, queries: updated);
  }

  SavedQueryLibrary remove(String id) {
    return SavedQueryLibrary(
      configVersion: configVersion,
      queries: queries.where((query) => query.id != id).toList(),
    );
  }

  String toToml() {
    final buffer = StringBuffer()
      ..writeln('config_version = $configVersion')
      ..writeln();
    for (final query in queries) {
      buffer
        ..writeln('[[queries]]')
        ..writeln('id = ${jsonEncode(query.id)}')
        ..writeln('name = ${jsonEncode(query.name)}')
        ..writeln('description = ${jsonEncode(query.description)}')
        ..writeln('sql = ${jsonEncode(query.sql)}')
        ..writeln('parameter_json = ${jsonEncode(query.parameterJson)}')
        ..writeln('folder = ${jsonEncode(query.folder)}')
        ..writeln('tags = ${jsonEncode(query.tags)}')
        ..writeln(
          'created_at = ${jsonEncode(query.createdAt.toUtc().toIso8601String())}',
        )
        ..writeln(
          'updated_at = ${jsonEncode(query.updatedAt.toUtc().toIso8601String())}',
        );
      final fingerprint = query.schemaFingerprint;
      if (fingerprint != null && fingerprint.trim().isNotEmpty) {
        buffer.writeln('schema_fingerprint = ${jsonEncode(fingerprint)}');
      }
      final algorithm = query.schemaFingerprintAlgorithm;
      if (algorithm != null && algorithm.trim().isNotEmpty) {
        buffer.writeln(
          'schema_fingerprint_algorithm = ${jsonEncode(algorithm)}',
        );
      }
      final contract = query.queryContract;
      if (contract != null) {
        _writeQueryContract(buffer, contract);
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  static SavedQueryLibrary fromToml(String source) {
    var configVersion = 1;
    final builders = <_SavedQueryBuilder>[];
    _SavedQueryBuilder? current;
    String section = 'root';
    Map<String, Object?>? currentNestedMap;

    for (final rawLine in const LineSplitter().convert(source)) {
      final line = _stripTomlComment(rawLine).trim();
      if (line.isEmpty) {
        continue;
      }
      if (line == '[[queries]]') {
        current = _SavedQueryBuilder();
        builders.add(current);
        section = 'query';
        currentNestedMap = null;
        continue;
      }
      if (line == '[queries.contract]') {
        _requireCurrentQuery(current, line);
        section = 'contract';
        currentNestedMap = current!.contract;
        continue;
      }
      if (line == '[[queries.contract.parameters]]') {
        _requireCurrentQuery(current, line);
        final map = <String, Object?>{};
        current!.parameters.add(map);
        section = 'parameter';
        currentNestedMap = map;
        continue;
      }
      if (line == '[[queries.contract.result_columns]]') {
        _requireCurrentQuery(current, line);
        final map = <String, Object?>{};
        current!.resultColumns.add(map);
        section = 'result_column';
        currentNestedMap = map;
        continue;
      }

      final separator = line.indexOf('=');
      if (separator < 0) {
        throw FormatException('Invalid saved query TOML line: $line');
      }
      final key = line.substring(0, separator).trim();
      final value = _parseTomlValue(line.substring(separator + 1).trim());
      if (section == 'root') {
        if (key == 'config_version') {
          configVersion = _asInt(value) ?? configVersion;
        }
        continue;
      }
      _requireCurrentQuery(current, line);
      if (section == 'query') {
        current!.fields[key] = value;
      } else {
        currentNestedMap![key] = value;
      }
    }

    return SavedQueryLibrary(
      configVersion: configVersion,
      queries: builders.map((builder) => builder.build()).toList(),
    );
  }
}

class WorkspaceProjectFile {
  const WorkspaceProjectFile({
    this.configVersion = 1,
    required this.databasePath,
    this.openOnLoad = true,
    this.queryLibraryPath,
    this.autoOpenQueryIds = const <String>[],
    this.importPlanPaths = const <String>[],
    this.exportFormat = 'csv',
    this.exportDirectory = 'exports/',
    this.exportIncludeHeaders = true,
    this.exportDelimiter = ',',
    this.preferredBranch = 'main',
    this.runRiskyQueriesOnBranch = false,
  });

  final int configVersion;
  final String databasePath;
  final bool openOnLoad;
  final String? queryLibraryPath;
  final List<String> autoOpenQueryIds;
  final List<String> importPlanPaths;
  final String exportFormat;
  final String exportDirectory;
  final bool exportIncludeHeaders;
  final String exportDelimiter;
  final String preferredBranch;
  final bool runRiskyQueriesOnBranch;

  String resolveDatabasePath(String projectFilePath) {
    if (p.isAbsolute(databasePath)) {
      return databasePath;
    }
    return p.normalize(p.join(p.dirname(projectFilePath), databasePath));
  }

  String? resolveQueryLibraryPath(String projectFilePath) {
    final path = queryLibraryPath;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    if (p.isAbsolute(path)) {
      return path;
    }
    return p.normalize(p.join(p.dirname(projectFilePath), path));
  }

  String toToml() {
    final buffer = StringBuffer()
      ..writeln('config_version = $configVersion')
      ..writeln()
      ..writeln('[database]')
      ..writeln('path = ${jsonEncode(databasePath)}')
      ..writeln('open_on_load = $openOnLoad')
      ..writeln()
      ..writeln('[imports]')
      ..writeln('plan_files = ${jsonEncode(importPlanPaths)}')
      ..writeln()
      ..writeln('[query_library]')
      ..writeln('path = ${jsonEncode(queryLibraryPath ?? 'queries.toml')}')
      ..writeln()
      ..writeln('[auto_open]')
      ..writeln('queries = ${jsonEncode(autoOpenQueryIds)}')
      ..writeln()
      ..writeln('[export_defaults]')
      ..writeln('format = ${jsonEncode(exportFormat)}')
      ..writeln('output_dir = ${jsonEncode(exportDirectory)}')
      ..writeln('include_headers = $exportIncludeHeaders')
      ..writeln('delimiter = ${jsonEncode(exportDelimiter)}')
      ..writeln()
      ..writeln('[branch_safety]')
      ..writeln('preferred_branch = ${jsonEncode(preferredBranch)}')
      ..writeln('run_risky_queries_on_branch = $runRiskyQueriesOnBranch');
    return buffer.toString();
  }

  static WorkspaceProjectFile fromToml(String source) {
    var configVersion = 1;
    final sections = <String, Map<String, Object?>>{'root': {}};
    var section = 'root';
    for (final rawLine in const LineSplitter().convert(source)) {
      final line = _stripTomlComment(rawLine).trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).trim();
        sections.putIfAbsent(section, () => <String, Object?>{});
        continue;
      }
      final separator = line.indexOf('=');
      if (separator < 0) {
        throw FormatException('Invalid project TOML line: $line');
      }
      final key = line.substring(0, separator).trim();
      final value = _parseTomlValue(line.substring(separator + 1).trim());
      sections[section]![key] = value;
    }

    configVersion = _asInt(sections['root']?['config_version']) ?? 1;
    final database = sections['database'] ?? const <String, Object?>{};
    final imports = sections['imports'] ?? const <String, Object?>{};
    final queryLibrary = sections['query_library'] ?? const <String, Object?>{};
    final autoOpen = sections['auto_open'] ?? const <String, Object?>{};
    final exports = sections['export_defaults'] ?? const <String, Object?>{};
    final branch = sections['branch_safety'] ?? const <String, Object?>{};
    final dbPath = database['path'] as String? ?? '';
    if (dbPath.trim().isEmpty) {
      throw const FormatException('Project file is missing [database].path.');
    }

    return WorkspaceProjectFile(
      configVersion: configVersion,
      databasePath: dbPath,
      openOnLoad: database['open_on_load'] as bool? ?? true,
      queryLibraryPath: queryLibrary['path'] as String?,
      autoOpenQueryIds: _asStringList(autoOpen['queries']),
      importPlanPaths: _asStringList(imports['plan_files']),
      exportFormat: exports['format'] as String? ?? 'csv',
      exportDirectory: exports['output_dir'] as String? ?? 'exports/',
      exportIncludeHeaders: exports['include_headers'] as bool? ?? true,
      exportDelimiter: exports['delimiter'] as String? ?? ',',
      preferredBranch: branch['preferred_branch'] as String? ?? 'main',
      runRiskyQueriesOnBranch:
          branch['run_risky_queries_on_branch'] as bool? ?? false,
    );
  }
}

void _writeQueryContract(StringBuffer buffer, QueryContract contract) {
  buffer
    ..writeln()
    ..writeln('[queries.contract]')
    ..writeln('contract_version = ${contract.contractVersion}')
    ..writeln('sql = ${jsonEncode(contract.sql)}')
    ..writeln('statement_kind = ${jsonEncode(contract.statementKind)}')
    ..writeln('read_only = ${contract.readOnly}')
    ..writeln('schema_cookie = ${contract.schemaCookie}')
    ..writeln('temp_schema_cookie = ${contract.tempSchemaCookie}')
    ..writeln('schema_fingerprint = ${jsonEncode(contract.schemaFingerprint)}')
    ..writeln('diagnostics = ${jsonEncode(contract.diagnostics)}');
  for (final parameter in contract.parameters) {
    buffer
      ..writeln()
      ..writeln('[[queries.contract.parameters]]')
      ..writeln('position = ${parameter.position}')
      ..writeln('name = ${jsonEncode(parameter.name)}');
    _writeOptionalString(buffer, 'type_name', parameter.typeName);
    _writeOptionalBool(buffer, 'nullable', parameter.nullable);
    buffer.writeln('source = ${jsonEncode(parameter.source)}');
    _writeOptionalString(buffer, 'source_table', parameter.sourceTable);
    _writeOptionalString(buffer, 'source_column', parameter.sourceColumn);
    buffer.writeln('diagnostics = ${jsonEncode(parameter.diagnostics)}');
  }
  for (final column in contract.resultColumns) {
    buffer
      ..writeln()
      ..writeln('[[queries.contract.result_columns]]')
      ..writeln('ordinal = ${column.ordinal}')
      ..writeln('name = ${jsonEncode(column.name)}');
    _writeOptionalString(buffer, 'type_name', column.typeName);
    _writeOptionalBool(buffer, 'nullable', column.nullable);
    buffer.writeln('source = ${jsonEncode(column.source)}');
    _writeOptionalString(buffer, 'source_table', column.sourceTable);
    _writeOptionalString(buffer, 'source_column', column.sourceColumn);
    _writeOptionalString(buffer, 'expression_sql', column.expressionSql);
    buffer.writeln('diagnostics = ${jsonEncode(column.diagnostics)}');
  }
}

void _writeOptionalString(StringBuffer buffer, String key, String? value) {
  if (value == null) {
    return;
  }
  buffer.writeln('$key = ${jsonEncode(value)}');
}

void _writeOptionalBool(StringBuffer buffer, String key, bool? value) {
  if (value == null) {
    return;
  }
  buffer.writeln('$key = $value');
}

void _requireCurrentQuery(_SavedQueryBuilder? current, String line) {
  if (current == null) {
    throw FormatException('Saved query TOML section before [[queries]]: $line');
  }
}

class _SavedQueryBuilder {
  final Map<String, Object?> fields = <String, Object?>{};
  final Map<String, Object?> contract = <String, Object?>{};
  final List<Map<String, Object?>> parameters = <Map<String, Object?>>[];
  final List<Map<String, Object?>> resultColumns = <Map<String, Object?>>[];

  SavedQuery build() {
    final id = fields['id'] as String? ?? '';
    final name = fields['name'] as String? ?? '';
    final sql = fields['sql'] as String? ?? '';
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw const FormatException('Saved query requires id and name.');
    }
    final contractMap = contract.isEmpty
        ? null
        : <String, Object?>{
            ...contract,
            'parameters': parameters,
            'result_columns': resultColumns,
          };
    return SavedQuery(
      id: id,
      name: name,
      sql: sql,
      parameterJson: fields['parameter_json'] as String? ?? '',
      description: fields['description'] as String? ?? '',
      folder: fields['folder'] as String? ?? '',
      tags: _asStringList(fields['tags']),
      createdAt:
          DateTime.tryParse(fields['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse(fields['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      schemaFingerprint: fields['schema_fingerprint'] as String?,
      schemaFingerprintAlgorithm:
          fields['schema_fingerprint_algorithm'] as String?,
      queryContract: contractMap == null
          ? null
          : QueryContract.fromMap(contractMap),
    );
  }
}

Object? _parseTomlValue(String rawValue) {
  final value = rawValue.trim();
  if (value == 'true') {
    return true;
  }
  if (value == 'false') {
    return false;
  }
  if (value.startsWith('"') || value.startsWith('[')) {
    return jsonDecode(value);
  }
  return int.tryParse(value) ?? value;
}

String _stripTomlComment(String rawLine) {
  var inString = false;
  var escaped = false;
  for (var i = 0; i < rawLine.length; i++) {
    final char = rawLine[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (char == '#' && !inString) {
      return rawLine.substring(0, i);
    }
  }
  return rawLine;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value.map((item) => '$item').toList();
  }
  return const <String>[];
}
