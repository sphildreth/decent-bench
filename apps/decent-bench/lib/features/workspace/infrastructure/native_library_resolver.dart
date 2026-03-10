import 'dart:io';

import 'package:path/path.dart' as p;

class NativeLibraryResolver {
  Future<String> resolve() async {
    final env = Platform.environment['DECENTDB_NATIVE_LIB'];
    if (env != null && env.isNotEmpty && await File(env).exists()) {
      return env;
    }

    final fileName = _defaultLibraryName();
    final candidates = <String>{
      ..._bundleCandidates(fileName),
      ..._searchFrom(Directory.current, fileName),
      ..._searchFrom(File(Platform.script.toFilePath()).parent, fileName),
    };

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    throw StateError(
      'Unable to resolve the DecentDB native library ($fileName). '
      'Set DECENTDB_NATIVE_LIB or build DecentDB under a sibling ../decentdb repo.',
    );
  }

  String _defaultLibraryName() {
    if (Platform.isLinux) {
      return 'libc_api.so';
    }
    if (Platform.isMacOS) {
      return 'libc_api.dylib';
    }
    if (Platform.isWindows) {
      return 'c_api.dll';
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  Iterable<String> _bundleCandidates(String fileName) sync* {
    final executableDir = p.dirname(Platform.resolvedExecutable);
    if (Platform.isLinux) {
      yield p.join(executableDir, 'lib', fileName);
    } else if (Platform.isMacOS) {
      yield p.join(executableDir, '..', 'Frameworks', fileName);
    } else if (Platform.isWindows) {
      yield p.join(executableDir, fileName);
    }
  }

  Iterable<String> _searchFrom(Directory start, String fileName) sync* {
    var current = start.absolute;
    for (var i = 0; i < 8; i++) {
      yield p.join(current.path, 'native', fileName);
      yield p.join(current.path, 'native', 'lib', fileName);
      yield p.join(current.path, 'build', fileName);
      yield p.join(current.path, '..', 'decentdb', 'build', fileName);
      current = current.parent;
    }
  }
}
