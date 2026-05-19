import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../app/app_support_paths.dart';
import '../domain/saved_query_models.dart';

abstract class SavedQueryLibraryStore {
  Future<SavedQueryLibrary> load(String databasePath);

  Future<void> save(String databasePath, SavedQueryLibrary library);

  Future<SavedQueryLibrary> loadFromPath(String path);

  Future<void> saveToPath(String path, SavedQueryLibrary library);

  String describeLocation(String databasePath);
}

class FileSavedQueryLibraryStore implements SavedQueryLibraryStore {
  FileSavedQueryLibraryStore({Directory? rootOverride})
    : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  @override
  Future<SavedQueryLibrary> load(String databasePath) async {
    final file = _resolveFile(databasePath);
    if (!await file.exists()) {
      return SavedQueryLibrary.empty;
    }
    return SavedQueryLibrary.fromToml(await file.readAsString());
  }

  @override
  Future<void> save(String databasePath, SavedQueryLibrary library) async {
    await saveToPath(_resolveFile(databasePath).path, library);
  }

  @override
  Future<SavedQueryLibrary> loadFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return SavedQueryLibrary.empty;
    }
    return SavedQueryLibrary.fromToml(await file.readAsString());
  }

  @override
  Future<void> saveToPath(String path, SavedQueryLibrary library) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(library.toToml());
  }

  @override
  String describeLocation(String databasePath) =>
      _resolveFile(databasePath).path;

  File _resolveFile(String databasePath) {
    final root = _rootOverride ?? _defaultRootDirectory();
    final encoded = base64Url
        .encode(utf8.encode(databasePath))
        .replaceAll('=', '');
    return File(p.join(root.path, '$encoded-queries.toml'));
  }

  Directory _defaultRootDirectory() {
    return Directory(AppSupportPaths.resolveWorkspaceStateDirectoryPath());
  }
}
