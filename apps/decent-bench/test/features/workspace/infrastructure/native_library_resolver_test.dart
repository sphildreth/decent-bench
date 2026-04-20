import 'package:decent_bench/features/workspace/infrastructure/native_library_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runtime resolution checks bundled library locations first',
    () async {
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
    },
  );

  test(
    'packaging resolution checks repo search paths',
    () async {
      final resolver = NativeLibraryResolver(
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
  });

  test(
    'failure includes checked candidates',
    () async {
      final resolver = NativeLibraryResolver(
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
                (error) => error.toString(),
                'message',
                allOf(
                  contains('/bundle/lib/libdecentdb.so'),
                  contains('Install DecentDB system-wide'),
                ),
              ),
        ),
      );
    },
  );
}
