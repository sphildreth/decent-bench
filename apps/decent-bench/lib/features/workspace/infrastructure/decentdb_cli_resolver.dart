import 'dart:io';

import 'package:path/path.dart' as p;

import 'decentdb_native_release_asset.dart';
import 'native_library_resolver.dart';

typedef DecentDbCliPathResolver = Future<String> Function();

enum DecentDbCliResolutionMode { runtime, packagingSource }

class DecentDbCliResolution {
  const DecentDbCliResolution({
    required this.cliToolFileName,
    required this.resolvedPath,
    required this.checkedPaths,
    required this.mode,
  });

  final String cliToolFileName;
  final String resolvedPath;
  final List<String> checkedPaths;
  final DecentDbCliResolutionMode mode;
}

class DecentDbCliResolutionFailure implements Exception {
  const DecentDbCliResolutionFailure({
    required this.cliToolFileName,
    required this.checkedPaths,
    required this.mode,
  });

  final String cliToolFileName;
  final List<String> checkedPaths;
  final DecentDbCliResolutionMode mode;

  String toDisplayMessage() {
    final buffer = StringBuffer()
      ..writeln(
        'Unable to resolve the DecentDB CLI executable ($cliToolFileName).',
      );
    if (checkedPaths.isNotEmpty) {
      buffer
        ..writeln('Checked candidate paths:')
        ..writeln(checkedPaths.map((path) => '- $path').join('\n'));
    }
    buffer.writeln(
      mode == DecentDbCliResolutionMode.runtime
          ? 'Install DecentDB system-wide (e.g., brew install decentdb) or bundle it with the app.'
          : 'Bundle DecentDB CLI before packaging.',
    );
    return buffer.toString().trimRight();
  }

  @override
  String toString() => toDisplayMessage();
}

class DecentDbCliResolver {
  DecentDbCliResolver({
    String? currentDirectoryPath,
    String? scriptDirectoryPath,
    String? resolvedExecutablePath,
    bool Function(String path)? fileExists,
    NativeLibraryPlatform? platform,
    Map<String, String>? environment,
  }) : _currentDirectoryPath = currentDirectoryPath ?? Directory.current.path,
       _scriptDirectoryPath =
           scriptDirectoryPath ??
           File(Platform.script.toFilePath()).parent.path,
       _resolvedExecutablePath =
           resolvedExecutablePath ?? Platform.resolvedExecutable,
       _fileExists = fileExists ?? ((path) => File(path).existsSync()),
       _platform = platform ?? _detectCurrentPlatform(),
       _environment = environment ?? Platform.environment;

  final String _currentDirectoryPath;
  final String _scriptDirectoryPath;
  final String _resolvedExecutablePath;
  final bool Function(String path) _fileExists;
  final NativeLibraryPlatform _platform;
  final Map<String, String> _environment;

  Future<String> resolve() async {
    return (await resolveDetailed()).resolvedPath;
  }

  Future<String> resolvePackagingSource() async {
    return (await resolveDetailed(
      mode: DecentDbCliResolutionMode.packagingSource,
    )).resolvedPath;
  }

  Future<DecentDbCliResolution> resolveDetailed({
    DecentDbCliResolutionMode mode = DecentDbCliResolutionMode.runtime,
  }) async {
    final checkedPaths = <String>[];

    for (final candidate in candidatePaths(mode: mode)) {
      checkedPaths.add(candidate);
      if (_fileExists(candidate)) {
        return DecentDbCliResolution(
          cliToolFileName: cliToolFileName,
          resolvedPath: candidate,
          checkedPaths: checkedPaths,
          mode: mode,
        );
      }
    }

    throw DecentDbCliResolutionFailure(
      cliToolFileName: cliToolFileName,
      checkedPaths: checkedPaths,
      mode: mode,
    );
  }

  String get cliToolFileName {
    switch (_platform) {
      case NativeLibraryPlatform.linux:
      case NativeLibraryPlatform.macos:
        return 'decentdb';
      case NativeLibraryPlatform.windows:
        return 'decentdb.exe';
    }
  }

  List<String> candidatePaths({
    DecentDbCliResolutionMode mode = DecentDbCliResolutionMode.runtime,
  }) {
    final candidates = <String>[];
    candidates.addAll(_configuredCandidates());
    if (mode == DecentDbCliResolutionMode.runtime) {
      candidates.addAll(_bundleCandidates());
    }
    candidates.addAll(_cachedAssetCandidates());
    candidates.addAll(_searchFrom(_currentDirectoryPath));
    candidates.addAll(_searchFrom(_scriptDirectoryPath));
    candidates.addAll(_pathCandidates());
    candidates.addAll(_systemCandidates());
    return _dedupePaths(candidates);
  }

  Iterable<String> _configuredCandidates() sync* {
    yield _environment['DECENTDB_CLI_PATH'] ?? '';
    yield _environment['DECENTDB_CLI'] ?? '';
  }

  Iterable<String> _bundleCandidates() sync* {
    final executableDir = p.dirname(_resolvedExecutablePath);
    yield p.join(executableDir, cliToolFileName);
    yield p.join(executableDir, 'bin', cliToolFileName);
    yield p.join(executableDir, 'libexec', cliToolFileName);

    if (_platform == NativeLibraryPlatform.macos) {
      yield p.join(executableDir, '..', 'MacOS', cliToolFileName);
      yield p.join(executableDir, '..', 'Resources', 'bin', cliToolFileName);
    }
  }

  Iterable<String> _cachedAssetCandidates() sync* {
    yield* DecentDbNativeReleaseAsset.cachedCliToolCandidates(
      searchRoots: [_currentDirectoryPath, _scriptDirectoryPath],
      platform: switch (_platform) {
        NativeLibraryPlatform.linux => DecentDbNativeAssetPlatform.linux,
        NativeLibraryPlatform.macos => DecentDbNativeAssetPlatform.macos,
        NativeLibraryPlatform.windows => DecentDbNativeAssetPlatform.windows,
      },
    );
  }

  Iterable<String> _searchFrom(String startPath) sync* {
    var current = Directory(startPath).absolute;
    for (var i = 0; i < 8; i++) {
      yield p.join(current.path, 'native', cliToolFileName);
      yield p.join(current.path, 'native', 'bin', cliToolFileName);
      yield p.join(current.path, 'build', cliToolFileName);
      yield p.join(current.path, 'target', 'debug', cliToolFileName);
      yield p.join(current.path, 'target', 'release', cliToolFileName);
      current = current.parent;
    }
  }

  Iterable<String> _pathCandidates() sync* {
    final pathValue = _environment['PATH'];
    if (pathValue == null || pathValue.trim().isEmpty) {
      return;
    }
    final separator = _platform == NativeLibraryPlatform.windows ? ';' : ':';
    for (final directory in pathValue.split(separator)) {
      if (directory.trim().isEmpty) {
        continue;
      }
      yield p.join(directory, cliToolFileName);
    }
  }

  Iterable<String> _systemCandidates() sync* {
    switch (_platform) {
      case NativeLibraryPlatform.linux:
        yield '/usr/local/bin/$cliToolFileName';
        yield '/usr/bin/$cliToolFileName';
        yield '/bin/$cliToolFileName';
        final home = _environment['HOME'];
        if (home != null && home.isNotEmpty) {
          yield '$home/.local/bin/$cliToolFileName';
          yield '$home/bin/$cliToolFileName';
        }
        break;
      case NativeLibraryPlatform.macos:
        yield '/opt/homebrew/bin/$cliToolFileName';
        yield '/usr/local/bin/$cliToolFileName';
        yield '/usr/bin/$cliToolFileName';
        final home = _environment['HOME'];
        if (home != null && home.isNotEmpty) {
          yield '$home/bin/$cliToolFileName';
          yield '$home/.local/bin/$cliToolFileName';
        }
        break;
      case NativeLibraryPlatform.windows:
        yield p.join('C:\\Program Files\\DecentDB', cliToolFileName);
        yield p.join('C:\\Program Files', cliToolFileName);
        break;
    }
  }

  List<String> _dedupePaths(Iterable<String> candidates) {
    final seen = <String>{};
    final unique = <String>[];
    for (final candidate in candidates) {
      if (candidate.trim().isEmpty) {
        continue;
      }
      final normalized = p.normalize(candidate);
      if (seen.add(normalized)) {
        unique.add(normalized);
      }
    }
    return unique;
  }

  static NativeLibraryPlatform _detectCurrentPlatform() {
    if (Platform.isLinux) {
      return NativeLibraryPlatform.linux;
    }
    if (Platform.isMacOS) {
      return NativeLibraryPlatform.macos;
    }
    if (Platform.isWindows) {
      return NativeLibraryPlatform.windows;
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }
}
