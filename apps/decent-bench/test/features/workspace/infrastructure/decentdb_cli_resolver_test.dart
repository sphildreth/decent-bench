import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/decentdb_cli_resolver.dart';
import 'package:decent_bench/features/workspace/infrastructure/decentdb_native_release_asset.dart';
import 'package:decent_bench/features/workspace/infrastructure/native_library_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String _currentPinnedTag() {
  return DecentDbNativeReleaseAsset.parsePinnedTagFromPubspecLock(
    File('pubspec.lock').readAsStringSync(),
  )!;
}

void main() {
  test(
    'runtime resolution checks configured and bundled locations first',
    () async {
      final resolver = DecentDbCliResolver(
        currentDirectoryPath: '/workspace/apps/decent-bench',
        scriptDirectoryPath: '/workspace/apps/decent-bench/tool',
        resolvedExecutablePath: '/bundle/decent_bench',
        platform: NativeLibraryPlatform.linux,
        environment: const <String, String>{
          'DECENTDB_CLI_PATH': '/custom/tools/decentdb',
        },
        fileExists: (path) => path == '/custom/tools/decentdb',
      );

      final result = await resolver.resolveDetailed();

      expect(result.resolvedPath, '/custom/tools/decentdb');
      expect(result.checkedPaths.first, '/custom/tools/decentdb');
    },
  );

  test(
    'packaging resolution prefers the cached pinned release asset',
    () async {
      final appDir = Directory.current.path;
      final pinnedTag = _currentPinnedTag();
      final cachedCliPath = p.join(
        appDir,
        '.dart_tool',
        'decentdb',
        'native',
        pinnedTag,
        'Linux-x64',
        'decentdb',
      );
      final resolver = DecentDbCliResolver(
        currentDirectoryPath: appDir,
        scriptDirectoryPath: p.join(appDir, 'tool'),
        resolvedExecutablePath: '/bundle/decent_bench',
        platform: NativeLibraryPlatform.linux,
        fileExists: (path) => path == cachedCliPath,
        environment: const <String, String>{},
      );

      final result = await resolver.resolveDetailed(
        mode: DecentDbCliResolutionMode.packagingSource,
      );

      expect(result.resolvedPath, cachedCliPath);
    },
  );

  test('failure includes checked candidates', () async {
    final appDir = Directory.current.path;
    final pinnedTag = _currentPinnedTag();
    final resolver = DecentDbCliResolver(
      currentDirectoryPath: appDir,
      scriptDirectoryPath: p.join(appDir, 'tool'),
      resolvedExecutablePath: '/bundle/decent_bench',
      platform: NativeLibraryPlatform.linux,
      fileExists: (_) => false,
      environment: const <String, String>{},
    );

    await expectLater(
      resolver.resolve(),
      throwsA(
        isA<DecentDbCliResolutionFailure>().having(
          (error) => error.toString(),
          'message',
          allOf(
            contains('/bundle/decentdb'),
            contains(
              p.join(
                appDir,
                '.dart_tool',
                'decentdb',
                'native',
                pinnedTag,
                'Linux-x64',
                'decentdb',
              ),
            ),
            contains('Install DecentDB system-wide'),
          ),
        ),
      ),
    );
  });
}
