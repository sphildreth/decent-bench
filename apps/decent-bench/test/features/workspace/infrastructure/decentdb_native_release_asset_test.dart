import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/decentdb_native_release_asset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('parses the pinned DecentDB tag from pubspec.lock', () {
    final contents = '''
packages:
  decentdb:
    dependency: "direct main"
    description:
      path: "bindings/dart/dart"
      ref: "v2.5.1"
      resolved-ref: "abc123"
      url: "https://github.com/sphildreth/decentdb"
    source: git
    version: "2.5.1"
''';

    expect(
      DecentDbNativeReleaseAsset.parsePinnedTagFromPubspecLock(contents),
      'v2.5.1',
    );
  });

  test(
    'discovers cached library candidates from the nearest project lockfile',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'decentdb-native-asset-test-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final projectDir = Directory(p.join(tempDir.path, 'apps', 'decent-bench'))
        ..createSync(recursive: true);
      await File(p.join(projectDir.path, 'pubspec.lock')).writeAsString('''
packages:
  decentdb:
    dependency: "direct main"
    description:
      ref: "v2.5.1"
      url: "https://github.com/sphildreth/decentdb"
    source: git
    version: "2.5.1"
''');

      final candidates = DecentDbNativeReleaseAsset.cachedLibraryCandidates(
        searchRoots: [p.join(projectDir.path, 'test')],
        platform: DecentDbNativeAssetPlatform.linux,
      ).toList();

      expect(
        candidates,
        contains(
          p.join(
            projectDir.path,
            '.dart_tool',
            'decentdb',
            'native',
            'v2.5.1',
            'Linux-x64',
            'libdecentdb.so',
          ),
        ),
      );
    },
  );

  test(
    'selects the generic release bundle when dart-native assets are unavailable',
    () {
      final download = DecentDbNativeReleaseAsset.selectDownload(
        metadata: {
          'assets': [
            {
              'name': 'decentdb-jdbc-v2.5.1-Linux.jar',
              'browser_download_url': 'https://example.invalid/jdbc',
            },
            {
              'name': 'decentdb-v2.5.1-Linux-x64.tar.gz',
              'browser_download_url': 'https://example.invalid/linux-x64',
            },
          ],
        },
        tag: 'v2.5.1',
        releaseSuffix: 'Linux-x64',
        archiveExtension: 'tar.gz',
      );

      expect(download.name, 'decentdb-v2.5.1-Linux-x64.tar.gz');
      expect(
        download.downloadUri.toString(),
        'https://example.invalid/linux-x64',
      );
    },
  );

  test('prefers the dart-native release bundle when it exists', () {
    final download = DecentDbNativeReleaseAsset.selectDownload(
      metadata: {
        'assets': [
          {
            'name': 'decentdb-v2.5.1-Linux-x64.tar.gz',
            'browser_download_url': 'https://example.invalid/generic',
          },
          {
            'name': 'decentdb-dart-native-v2.5.1-Linux-x64.tar.gz',
            'browser_download_url': 'https://example.invalid/dart-native',
          },
        ],
      },
      tag: 'v2.5.1',
      releaseSuffix: 'Linux-x64',
      archiveExtension: 'tar.gz',
    );

    expect(download.name, 'decentdb-dart-native-v2.5.1-Linux-x64.tar.gz');
    expect(
      download.downloadUri.toString(),
      'https://example.invalid/dart-native',
    );
  });
}
