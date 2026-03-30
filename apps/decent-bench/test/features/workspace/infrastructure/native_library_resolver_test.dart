import 'package:decent_bench/features/workspace/infrastructure/native_library_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers DECENTDB_NATIVE_LIB when it exists', () async {
    final resolver = NativeLibraryResolver(
      environment: const <String, String>{
        'DECENTDB_NATIVE_LIB': '/custom/libdecentdb.so',
      },
      currentDirectoryPath: '/workspace/apps/decent-bench',
      scriptDirectoryPath: '/workspace/apps/decent-bench/tool',
      resolvedExecutablePath: '/workspace/apps/decent-bench/decent_bench',
      platform: NativeLibraryPlatform.linux,
      fileExists: (path) => path == '/custom/libdecentdb.so',
    );

    expect(await resolver.resolve(), '/custom/libdecentdb.so');
  });

  test(
    'runtime resolution checks bundled library locations before repo search',
    () async {
      final resolver = NativeLibraryResolver(
        environment: const <String, String>{},
        currentDirectoryPath: '/workspace/apps/decent-bench',
        scriptDirectoryPath: '/workspace/apps/decent-bench/tool',
        resolvedExecutablePath: '/bundle/decent_bench',
        platform: NativeLibraryPlatform.linux,
        fileExists: (path) => path == '/bundle/lib/libdecentdb.so',
      );

      final result = await resolver.resolveDetailed();

      expect(result.resolvedPath, '/bundle/lib/libdecentdb.so');
      expect(result.checkedPaths.first, '/bundle/lib/libdecentdb.so');
    },
  );

  test(
    'packaging resolution skips bundled paths and finds sibling decentdb build',
    () async {
      final resolver = NativeLibraryResolver(
        environment: const <String, String>{},
        currentDirectoryPath: '/workspace/apps/decent-bench',
        scriptDirectoryPath: '/workspace/apps/decent-bench/tool',
        resolvedExecutablePath: '/bundle/decent_bench',
        platform: NativeLibraryPlatform.linux,
        fileExists: (path) =>
            path == '/workspace/decentdb/target/debug/libdecentdb.so',
      );

      final result = await resolver.resolveDetailed(
        mode: NativeLibraryResolutionMode.packagingSource,
      );

      expect(
        result.resolvedPath,
        '/workspace/decentdb/target/debug/libdecentdb.so',
      );
      expect(
        result.checkedPaths.any((path) => path == '/bundle/lib/libdecentdb.so'),
        isFalse,
      );
    },
  );

  test('bundle relative install path matches platform conventions', () {
    final linux = NativeLibraryResolver(
      environment: const <String, String>{},
      currentDirectoryPath: '/tmp',
      scriptDirectoryPath: '/tmp',
      resolvedExecutablePath: '/tmp/decent_bench',
      platform: NativeLibraryPlatform.linux,
      fileExists: (_) => false,
    );
    final macos = NativeLibraryResolver(
      environment: const <String, String>{},
      currentDirectoryPath: '/tmp',
      scriptDirectoryPath: '/tmp',
      resolvedExecutablePath: '/tmp/decent_bench',
      platform: NativeLibraryPlatform.macos,
      fileExists: (_) => false,
    );
    final windows = NativeLibraryResolver(
      environment: const <String, String>{},
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
  });

  test(
    'failure includes the invalid env path and checked candidates',
    () async {
      final resolver = NativeLibraryResolver(
        environment: const <String, String>{
          'DECENTDB_NATIVE_LIB': '/missing/libdecentdb.so',
        },
        currentDirectoryPath: '/workspace/apps/decent-bench',
        scriptDirectoryPath: '/workspace/apps/decent-bench/tool',
        resolvedExecutablePath: '/bundle/decent_bench',
        platform: NativeLibraryPlatform.linux,
        fileExists: (_) => false,
      );

      await expectLater(
        resolver.resolve(),
        throwsA(
          isA<NativeLibraryResolutionFailure>()
              .having(
                (error) => error.requestedEnvPath,
                'requestedEnvPath',
                '/missing/libdecentdb.so',
              )
              .having(
                (error) => error.toString(),
                'message',
                allOf(
                  contains('/missing/libdecentdb.so'),
                  contains('/bundle/lib/libdecentdb.so'),
                  contains('Set DECENTDB_NATIVE_LIB'),
                ),
              ),
        ),
      );
    },
  );
}
