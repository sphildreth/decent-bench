import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/native_library_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('runtime resolution checks bundled library locations first', () async {
    final resolver = NativeLibraryResolver(
      currentDirectoryPath: '/workspace/apps/decent-bench',
      scriptDirectoryPath: '/workspace/apps/decent-bench/tool',
      resolvedExecutablePath: '/bundle/decent_bench',
      platform: NativeLibraryPlatform.linux,
      fileExists: (path) => path == '/bundle/lib/libdecentdb.so',
    );

    final result = await resolver.resolveDetailed();

    expect(result.resolvedPath, '/bundle/lib/libdecentdb.so');
    expect(result.checkedPaths.first, '/bundle/lib/libdecentdb.so');
  });

  test(
    'packaging resolution prefers the cached pinned release asset',
    () async {
      final appDir = Directory.current.path;
      final cachedLibraryPath = p.join(
        appDir,
        '.dart_tool',
        'decentdb',
        'native',
        'v2.5.1',
        'Linux-x64',
        'libdecentdb.so',
      );
      final resolver = NativeLibraryResolver(
        currentDirectoryPath: appDir,
        scriptDirectoryPath: p.join(appDir, 'tool'),
        resolvedExecutablePath: '/bundle/decent_bench',
        platform: NativeLibraryPlatform.linux,
        fileExists: (path) =>
            path == cachedLibraryPath ||
            path == '/workspace/decentdb/target/debug/libdecentdb.so',
      );

      final result = await resolver.resolveDetailed(
        mode: NativeLibraryResolutionMode.packagingSource,
      );

      expect(result.resolvedPath, cachedLibraryPath);
    },
  );

  test('packaging resolution falls back to repo search paths', () async {
    final appDir = Directory.current.path;
    final repoFallbackPath = p.join(appDir, 'build', 'libdecentdb.so');
    final resolver = NativeLibraryResolver(
      currentDirectoryPath: appDir,
      scriptDirectoryPath: p.join(appDir, 'tool'),
      resolvedExecutablePath: '/bundle/decent_bench',
      platform: NativeLibraryPlatform.linux,
      fileExists: (path) => path == repoFallbackPath,
    );

    final result = await resolver.resolveDetailed(
      mode: NativeLibraryResolutionMode.packagingSource,
    );

    expect(result.resolvedPath, repoFallbackPath);
    expect(
      result.checkedPaths.any((path) => path == '/bundle/lib/libdecentdb.so'),
      isFalse,
    );
  });

  test('bundle relative install path matches platform conventions', () {
    final linux = NativeLibraryResolver(
      currentDirectoryPath: '/tmp',
      scriptDirectoryPath: '/tmp',
      resolvedExecutablePath: '/tmp/decent_bench',
      platform: NativeLibraryPlatform.linux,
      fileExists: (_) => false,
    );
    final macos = NativeLibraryResolver(
      currentDirectoryPath: '/tmp',
      scriptDirectoryPath: '/tmp',
      resolvedExecutablePath: '/tmp/decent_bench',
      platform: NativeLibraryPlatform.macos,
      fileExists: (_) => false,
    );
    final windows = NativeLibraryResolver(
      currentDirectoryPath: r'C:\tmp',
      scriptDirectoryPath: r'C:\tmp',
      resolvedExecutablePath: r'C:\tmp\decent_bench.exe',
      platform: NativeLibraryPlatform.windows,
      fileExists: (_) => false,
    );

    expect(linux.bundleRelativeInstallPath, 'lib/libdecentdb.so');
    expect(
      macos.bundleRelativeInstallPath,
      'Contents/Frameworks/libdecentdb.dylib',
    );
    expect(windows.bundleRelativeInstallPath, 'decentdb.dll');
    expect(
      linux.migrationToolBundleRelativeInstallPath,
      'bin/decentdb-migrate',
    );
    expect(
      macos.migrationToolBundleRelativeInstallPath,
      'Contents/MacOS/decentdb-migrate',
    );
    expect(
      windows.migrationToolBundleRelativeInstallPath,
      'decentdb-migrate.exe',
    );
  });

  test('failure includes checked candidates', () async {
    final appDir = Directory.current.path;
    final resolver = NativeLibraryResolver(
      currentDirectoryPath: appDir,
      scriptDirectoryPath: p.join(appDir, 'tool'),
      resolvedExecutablePath: '/bundle/decent_bench',
      platform: NativeLibraryPlatform.linux,
      fileExists: (_) => false,
    );

    await expectLater(
      resolver.resolve(),
      throwsA(
        isA<NativeLibraryResolutionFailure>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('/bundle/lib/libdecentdb.so'),
            contains(
              p.join(
                appDir,
                '.dart_tool',
                'decentdb',
                'native',
                'v2.5.1',
                'Linux-x64',
                'libdecentdb.so',
              ),
            ),
            contains('Install DecentDB system-wide'),
          ),
        ),
      ),
    );
  });
}
