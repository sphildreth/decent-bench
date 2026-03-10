import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/workspace_state.dart';

abstract class WorkspaceStateStore {
  Future<PersistedWorkspaceState?> load(String databasePath);

  Future<void> save(String databasePath, PersistedWorkspaceState state);

  Future<void> clear(String databasePath);
}

class FileWorkspaceStateStore implements WorkspaceStateStore {
  FileWorkspaceStateStore({Directory? rootOverride})
    : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  @override
  Future<PersistedWorkspaceState?> load(String databasePath) async {
    final file = _resolveFile(databasePath);
    if (!await file.exists()) {
      return null;
    }
    return PersistedWorkspaceState.decode(await file.readAsString());
  }

  @override
  Future<void> save(String databasePath, PersistedWorkspaceState state) async {
    final file = _resolveFile(databasePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(state.encode());
  }

  @override
  Future<void> clear(String databasePath) async {
    final file = _resolveFile(databasePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  File _resolveFile(String databasePath) {
    final root = _rootOverride ?? _defaultRootDirectory();
    final encoded = base64Url
        .encode(utf8.encode(databasePath))
        .replaceAll('=', '');
    return File(p.join(root.path, '$encoded.json'));
  }

  Directory _defaultRootDirectory() {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    if (Platform.isLinux) {
      return Directory(
        p.join(
          Platform.environment['XDG_CONFIG_HOME'] ?? p.join(home, '.config'),
          'decent-bench',
          'workspaces',
        ),
      );
    }
    if (Platform.isMacOS) {
      return Directory(
        p.join(
          home,
          'Library',
          'Application Support',
          'Decent Bench',
          'workspaces',
        ),
      );
    }
    if (Platform.isWindows) {
      return Directory(
        p.join(
          Platform.environment['APPDATA'] ?? p.join(home, 'AppData', 'Roaming'),
          'Decent Bench',
          'workspaces',
        ),
      );
    }
    return Directory(p.join(home, '.decent-bench', 'workspaces'));
  }
}
