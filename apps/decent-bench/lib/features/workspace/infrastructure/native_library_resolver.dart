import 'dart:io';

import 'package:path/path.dart' as p;

import 'decentdb_native_release_asset.dart';

enum NativeLibraryPlatform { linux, macos, windows }

enum NativeLibraryResolutionMode { runtime, packagingSource }

class NativeLibraryResolution {
  const NativeLibraryResolution({
    required this.libraryFileName,
    required this.resolvedPath,
    required this.checkedPaths,
    required this.mode,
  });

  final String libraryFileName;
  final String resolvedPath;
  final List<String> checkedPaths;
  final NativeLibraryResolutionMode mode;
}

class NativeLibraryResolutionFailure implements Exception {
  const NativeLibraryResolutionFailure({
    required this.libraryFileName,
    required this.checkedPaths,
    required this.mode,
  });

  final String libraryFileName;
  final List<String> checkedPaths;
  final NativeLibraryResolutionMode mode;

  String toDisplayMessage() {
    final buffer = StringBuffer()
      ..writeln(
        'Unable to resolve the DecentDB native library ($libraryFileName).',
      );
    if (checkedPaths.isNotEmpty) {
      buffer
        ..writeln('Checked candidate paths:')
        ..writeln(checkedPaths.map((path) => '- $path').join('\n'));
    }
    buffer.writeln(
      mode == NativeLibraryResolutionMode.runtime
          ? 'Install DecentDB system-wide (e.g., brew install decentdb) or bundle it with the app.'
          : 'Bundle DecentDB native library before packaging.',
    );
    return buffer.toString().trimRight();
  }

  @override
  String toString() => toDisplayMessage();
}

class NativeLibraryResolver {
  NativeLibraryResolver({
    String? currentDirectoryPath,
    String? scriptDirectoryPath,
    String? resolvedExecutablePath,
    bool Function(String path)? fileExists,
    NativeLibraryPlatform? platform,
  }) : _currentDirectoryPath = currentDirectoryPath ?? Directory.current.path,
       _scriptDirectoryPath =
           scriptDirectoryPath ??
           File(Platform.script.toFilePath()).parent.path,
       _resolvedExecutablePath =
           resolvedExecutablePath ?? Platform.resolvedExecutable,
       _fileExists = fileExists ?? ((path) => File(path).existsSync()),
       _platform = platform ?? _detectCurrentPlatform();

  final String _currentDirectoryPath;
  final String _scriptDirectoryPath;
  final String _resolvedExecutablePath;
  final bool Function(String path) _fileExists;
  final NativeLibraryPlatform _platform;

  Future<String> resolve() async {
    return (await resolveDetailed()).resolvedPath;
  }

  Future<String> resolvePackagingSource() async {
    return (await resolveDetailed(
      mode: NativeLibraryResolutionMode.packagingSource,
    )).resolvedPath;
  }

  Future<NativeLibraryResolution> resolveDetailed({
    NativeLibraryResolutionMode mode = NativeLibraryResolutionMode.runtime,
  }) async {
    final checkedPaths = <String>[];

    for (final candidate in candidatePaths(mode: mode)) {
      checkedPaths.add(candidate);
      if (_fileExists(candidate)) {
        return NativeLibraryResolution(
          libraryFileName: libraryFileName,
          resolvedPath: candidate,
          checkedPaths: checkedPaths,
          mode: mode,
        );
      }
    }

    throw NativeLibraryResolutionFailure(
      libraryFileName: libraryFileName,
      checkedPaths: checkedPaths,
      mode: mode,
    );
  }

  String get libraryFileName {
    switch (_platform) {
      case NativeLibraryPlatform.linux:
        return 'libdecentdb.so';
      case NativeLibraryPlatform.macos:
        return 'libdecentdb.dylib';
      case NativeLibraryPlatform.windows:
        return 'decentdb.dll';
    }
  }

  String get bundleRelativeInstallPath {
    switch (_platform) {
      case NativeLibraryPlatform.linux:
        return p.join('lib', libraryFileName);
      case NativeLibraryPlatform.macos:
        return p.join('Contents', 'Frameworks', libraryFileName);
      case NativeLibraryPlatform.windows:
        return libraryFileName;
    }
  }

  List<String> candidatePaths({
    NativeLibraryResolutionMode mode = NativeLibraryResolutionMode.runtime,
  }) {
    final candidates = <String>[];
    if (mode == NativeLibraryResolutionMode.runtime) {
      candidates.addAll(_bundleCandidates());
    }
    candidates.addAll(_cachedAssetCandidates());
    candidates.addAll(_searchFrom(_currentDirectoryPath));
    candidates.addAll(_searchFrom(_scriptDirectoryPath));
    return _dedupePaths(candidates);
  }

  Iterable<String> _bundleCandidates() sync* {
    final executableDir = p.dirname(_resolvedExecutablePath);
    switch (_platform) {
      case NativeLibraryPlatform.linux:
        yield p.join(executableDir, 'lib', libraryFileName);
      case NativeLibraryPlatform.macos:
        yield p.join(executableDir, '..', 'Frameworks', libraryFileName);
      case NativeLibraryPlatform.windows:
        yield p.join(executableDir, libraryFileName);
    }
  }

  Iterable<String> _cachedAssetCandidates() sync* {
    yield* DecentDbNativeReleaseAsset.cachedLibraryCandidates(
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
      yield p.join(current.path, 'native', libraryFileName);
      yield p.join(current.path, 'native', 'lib', libraryFileName);
      yield p.join(current.path, 'build', libraryFileName);
      yield p.join(current.path, 'target', 'debug', libraryFileName);
      yield p.join(current.path, 'target', 'release', libraryFileName);
      current = current.parent;
    }
    yield* _systemCandidates();
  }

  Iterable<String> _systemCandidates() sync* {
    final libName = libraryFileName;
    if (Platform.isLinux) {
      yield '/usr/local/lib/$libName';
      yield '/usr/lib/$libName';
      yield '/lib/$libName';
      final home = Platform.environment['HOME'];
      if (home != null) {
        yield '$home/.local/lib/$libName';
        yield '$home/lib/$libName';
      }
    } else if (Platform.isMacOS) {
      yield '/usr/local/lib/$libName';
      yield '/usr/lib/$libName';
      final home = Platform.environment['HOME'];
      if (home != null) {
        yield '$home/lib/$libName';
        yield '$home/.local/lib/$libName';
      }
    } else if (Platform.isWindows) {
      yield 'C:\\Users\\Public\\lib\\$libName';
      yield 'C:\\Program Files\\$libName';
    }
  }

  List<String> _dedupePaths(Iterable<String> candidates) {
    final seen = <String>{};
    final unique = <String>[];
    for (final candidate in candidates) {
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
