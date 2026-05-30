import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

enum DecentDbNativeAssetPlatform { linux, macos, windows }

class DecentDbNativeReleaseAsset {
  const DecentDbNativeReleaseAsset._({
    required this.projectDirectoryPath,
    required this.tag,
    required this.platform,
    required this.releaseSuffix,
    required this.archiveExtension,
    required this.libraryFileName,
  });

  final String projectDirectoryPath;
  final String tag;
  final DecentDbNativeAssetPlatform platform;
  final String releaseSuffix;
  final String archiveExtension;
  final String libraryFileName;

  String get cacheDirectoryPath => p.join(
    projectDirectoryPath,
    '.dart_tool',
    'decentdb',
    'native',
    tag,
    releaseSuffix,
  );

  String get libraryPath => p.join(cacheDirectoryPath, libraryFileName);

  String get migrationToolFileName =>
      platform == DecentDbNativeAssetPlatform.windows
      ? 'decentdb-migrate.exe'
      : 'decentdb-migrate';

  String get migrationToolPath =>
      p.join(cacheDirectoryPath, migrationToolFileName);

  String get cliToolFileName => platform == DecentDbNativeAssetPlatform.windows
      ? 'decentdb.exe'
      : 'decentdb';

  String get cliToolPath => p.join(cacheDirectoryPath, cliToolFileName);

  static Future<String> ensureAvailableForCurrentProject({
    String? startPath,
  }) async {
    final asset = locate(startPath: startPath);
    return asset.ensureAvailable();
  }

  static DecentDbNativeReleaseAsset locate({
    String? startPath,
    DecentDbNativeAssetPlatform? platform,
  }) {
    final projectDirectoryPath = _findProjectDirectory(
      startPath ?? Directory.current.path,
    );
    if (projectDirectoryPath == null) {
      throw StateError(
        'Unable to locate pubspec.lock while resolving the pinned DecentDB release asset.',
      );
    }
    final lockFile = File(p.join(projectDirectoryPath, 'pubspec.lock'));
    final tag = parsePinnedTagFromPubspecLock(lockFile.readAsStringSync());
    if (tag == null) {
      throw StateError(
        'Unable to determine the pinned DecentDB tag from ${lockFile.path}.',
      );
    }
    return _fromResolvedTag(
      projectDirectoryPath: projectDirectoryPath,
      tag: tag,
      platform: platform ?? _detectCurrentPlatform(),
    );
  }

  static String? parsePinnedTagFromPubspecLock(String contents) {
    var insideDecentDb = false;
    String? version;
    for (final line in const LineSplitter().convert(contents)) {
      if (line.startsWith('  decentdb:')) {
        insideDecentDb = true;
        continue;
      }
      if (insideDecentDb && line.startsWith('  ') && !line.startsWith('    ')) {
        break;
      }
      if (!insideDecentDb) {
        continue;
      }
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('ref: ')) {
        final ref = _unquote(trimmed.substring(5).trim());
        if (ref.isNotEmpty) {
          return ref;
        }
      }
      if (trimmed.startsWith('version: ')) {
        version = _unquote(trimmed.substring(9).trim());
      }
    }
    if (version == null || version.isEmpty) {
      return null;
    }
    return version.startsWith('v') ? version : 'v$version';
  }

  static Iterable<String> cachedLibraryCandidates({
    required Iterable<String> searchRoots,
    required DecentDbNativeAssetPlatform platform,
  }) sync* {
    yield* _cachedFileCandidates(
      searchRoots: searchRoots,
      platform: platform,
      pathForAsset: (asset) => asset.libraryPath,
    );
  }

  static Iterable<String> cachedMigrationToolCandidates({
    required Iterable<String> searchRoots,
    required DecentDbNativeAssetPlatform platform,
  }) sync* {
    yield* _cachedFileCandidates(
      searchRoots: searchRoots,
      platform: platform,
      pathForAsset: (asset) => asset.migrationToolPath,
    );
  }

  static Iterable<String> cachedCliToolCandidates({
    required Iterable<String> searchRoots,
    required DecentDbNativeAssetPlatform platform,
  }) sync* {
    yield* _cachedFileCandidates(
      searchRoots: searchRoots,
      platform: platform,
      pathForAsset: (asset) => asset.cliToolPath,
    );
  }

  static Iterable<String> _cachedFileCandidates({
    required Iterable<String> searchRoots,
    required DecentDbNativeAssetPlatform platform,
    required String Function(DecentDbNativeReleaseAsset asset) pathForAsset,
  }) sync* {
    final seen = <String>{};
    for (final root in searchRoots) {
      final projectDirectoryPath = _findProjectDirectory(root);
      if (projectDirectoryPath == null) {
        continue;
      }
      final lockFile = File(p.join(projectDirectoryPath, 'pubspec.lock'));
      if (!lockFile.existsSync()) {
        continue;
      }
      final tag = parsePinnedTagFromPubspecLock(lockFile.readAsStringSync());
      if (tag == null) {
        continue;
      }
      final asset = _fromResolvedTag(
        projectDirectoryPath: projectDirectoryPath,
        tag: tag,
        platform: platform,
      );
      final candidate = pathForAsset(asset);
      if (seen.add(candidate)) {
        yield candidate;
      }
    }
  }

  Future<String> ensureAvailable() async {
    return _ensureCachedFile(
      fileName: libraryFileName,
      destinationPath: libraryPath,
      executable: false,
      includeDartNativeDownload: true,
      preferDartNativeDownload: true,
    );
  }

  Future<String> ensureMigrationToolAvailable() async {
    return _ensureCachedFile(
      fileName: migrationToolFileName,
      destinationPath: migrationToolPath,
      executable: true,
      includeDartNativeDownload: false,
      preferDartNativeDownload: false,
    );
  }

  Future<String> ensureCliToolAvailable() async {
    return _ensureCachedFile(
      fileName: cliToolFileName,
      destinationPath: cliToolPath,
      executable: true,
      includeDartNativeDownload: false,
      preferDartNativeDownload: false,
    );
  }

  Future<String> _ensureCachedFile({
    required String fileName,
    required String destinationPath,
    required bool executable,
    required bool includeDartNativeDownload,
    required bool preferDartNativeDownload,
  }) async {
    final destinationFile = File(destinationPath);
    if (destinationFile.existsSync()) {
      return destinationFile.path;
    }

    await Directory(cacheDirectoryPath).create(recursive: true);
    final lockFile = File('$destinationPath.lock');
    final lockHandle = await _waitForLock(lockFile, destinationFile);
    if (lockHandle == null) {
      return destinationFile.path;
    }
    try {
      if (destinationFile.existsSync()) {
        return destinationFile.path;
      }

      final download = await _resolveDownload(
        includeDartNative: includeDartNativeDownload,
        preferDartNative: preferDartNativeDownload,
      );
      final archiveBytes = await _downloadArchive(download.downloadUri);
      final fileBytes = _extractFileBytes(archiveBytes, fileName);
      final tempPath = '$destinationPath.download';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(fileBytes, flush: true);
      if (destinationFile.existsSync()) {
        await destinationFile.delete();
      }
      final renamedFile = await tempFile.rename(destinationFile.path);
      if (executable && !Platform.isWindows) {
        await Process.run('chmod', <String>['755', renamedFile.path]);
      }
      return renamedFile.path;
    } finally {
      await lockHandle.unlock();
      await lockHandle.close();
    }
  }

  static Future<RandomAccessFile?> _waitForLock(
    File lockFile,
    File libraryFile,
  ) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      RandomAccessFile? handle;
      try {
        handle = await lockFile.open(mode: FileMode.write);
        await handle.lock();
        return handle;
      } on FileSystemException {
        await handle?.close();
        if (libraryFile.existsSync()) {
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    throw StateError(
      'Timed out while waiting for the DecentDB native asset lock at ${lockFile.path}.',
    );
  }

  Uint8List _extractFileBytes(Uint8List archiveBytes, String fileName) {
    final archive = switch (archiveExtension) {
      'tar.gz' => TarDecoder().decodeBytes(
        GZipDecoder().decodeBytes(archiveBytes),
      ),
      'zip' => ZipDecoder().decodeBytes(archiveBytes),
      _ => throw UnsupportedError(
        'Unsupported archive extension: $archiveExtension',
      ),
    };

    for (final file in archive.files) {
      if (!file.isFile || p.basename(file.name) != fileName) {
        continue;
      }
      final content = file.content;
      if (content is Uint8List) {
        return content;
      }
      if (content is List<int>) {
        return Uint8List.fromList(content);
      }
      throw StateError(
        'Unexpected archive content type for ${file.name}: ${content.runtimeType}',
      );
    }

    throw StateError(
      'Downloaded a DecentDB release asset for $tag but did not find $fileName in the archive.',
    );
  }

  Future<DecentDbNativeReleaseDownload> _resolveDownload({
    required bool includeDartNative,
    required bool preferDartNative,
  }) async {
    final metadata = await _fetchReleaseMetadata(tag);
    return selectDownload(
      metadata: metadata,
      tag: tag,
      releaseSuffix: releaseSuffix,
      archiveExtension: archiveExtension,
      includeDartNative: includeDartNative,
      preferDartNative: preferDartNative,
    );
  }

  static DecentDbNativeReleaseDownload selectDownload({
    required Map<String, Object?> metadata,
    required String tag,
    required String releaseSuffix,
    required String archiveExtension,
    bool includeDartNative = true,
    bool preferDartNative = true,
  }) {
    final rawAssets = metadata['assets'];
    if (rawAssets is! List) {
      throw StateError(
        'Release metadata for $tag did not include an asset list.',
      );
    }
    final suffix = '-$releaseSuffix.$archiveExtension';
    final matches =
        rawAssets
            .whereType<Map<String, Object?>>()
            .map(DecentDbNativeReleaseDownload.fromJson)
            .where(
              (asset) =>
                  asset.name.endsWith(suffix) &&
                  asset.name.startsWith('decentdb-') &&
                  (includeDartNative || !asset.name.contains('dart-native')) &&
                  !asset.name.startsWith('decentdb-jdbc-') &&
                  !asset.name.startsWith('decentdb-dbeaver-'),
            )
            .toList()
          ..sort((left, right) {
            final leftPriority = left.name.contains('dart-native')
                ? (preferDartNative ? 0 : 1)
                : (preferDartNative ? 1 : 0);
            final rightPriority = right.name.contains('dart-native')
                ? (preferDartNative ? 0 : 1)
                : (preferDartNative ? 1 : 0);
            final priorityCompare = leftPriority.compareTo(rightPriority);
            if (priorityCompare != 0) {
              return priorityCompare;
            }
            return left.name.compareTo(right.name);
          });

    if (matches.isEmpty) {
      final assetNames =
          rawAssets
              .whereType<Map<String, Object?>>()
              .map((asset) => asset['name'])
              .whereType<String>()
              .toList()
            ..sort();
      throw StateError(
        'No DecentDB release asset matched $tag / $releaseSuffix.$archiveExtension. '
        'Available assets: ${assetNames.join(', ')}',
      );
    }

    return matches.first;
  }

  static Future<Map<String, Object?>> _fetchReleaseMetadata(String tag) async {
    final responseBytes = await _downloadArchive(
      Uri.parse(
        'https://api.github.com/repos/sphildreth/decentdb/releases/tags/$tag',
      ),
      requestJson: true,
    );
    final decoded = jsonDecode(utf8.decode(responseBytes));
    if (decoded is! Map<String, Object?>) {
      throw StateError('Unexpected GitHub release metadata payload for $tag.');
    }
    return decoded;
  }

  static Future<Uint8List> _downloadArchive(
    Uri uri, {
    bool requestJson = false,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      if (requestJson) {
        request.headers.set(
          HttpHeaders.acceptHeader,
          'application/vnd.github+json',
        );
        final token = Platform.environment['GITHUB_TOKEN'];
        if (token != null && token.isNotEmpty) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }
      }
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'decent-bench-native-asset',
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Failed to download $uri (HTTP ${response.statusCode})',
          uri: uri,
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytes.add(chunk);
      }
      return bytes.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  static DecentDbNativeReleaseAsset _fromResolvedTag({
    required String projectDirectoryPath,
    required String tag,
    required DecentDbNativeAssetPlatform platform,
  }) {
    final abi = Abi.current();
    switch (platform) {
      case DecentDbNativeAssetPlatform.linux:
        return DecentDbNativeReleaseAsset._(
          projectDirectoryPath: projectDirectoryPath,
          tag: tag,
          platform: platform,
          releaseSuffix: switch (abi) {
            Abi.linuxArm64 => 'Linux-arm64',
            _ => 'Linux-x64',
          },
          archiveExtension: 'tar.gz',
          libraryFileName: 'libdecentdb.so',
        );
      case DecentDbNativeAssetPlatform.macos:
        return DecentDbNativeReleaseAsset._(
          projectDirectoryPath: projectDirectoryPath,
          tag: tag,
          platform: platform,
          releaseSuffix: switch (abi) {
            Abi.macosX64 => 'macOS-x64',
            _ => 'macOS-arm64',
          },
          archiveExtension: 'tar.gz',
          libraryFileName: 'libdecentdb.dylib',
        );
      case DecentDbNativeAssetPlatform.windows:
        return DecentDbNativeReleaseAsset._(
          projectDirectoryPath: projectDirectoryPath,
          tag: tag,
          platform: platform,
          releaseSuffix: switch (abi) {
            Abi.windowsArm64 => 'Windows-arm64',
            _ => 'Windows-x64',
          },
          archiveExtension: 'zip',
          libraryFileName: 'decentdb.dll',
        );
    }
  }

  static DecentDbNativeAssetPlatform _detectCurrentPlatform() {
    final abi = Abi.current();
    return switch (abi) {
      Abi.linuxX64 || Abi.linuxArm64 => DecentDbNativeAssetPlatform.linux,
      Abi.macosX64 || Abi.macosArm64 => DecentDbNativeAssetPlatform.macos,
      Abi.windowsX64 || Abi.windowsArm64 => DecentDbNativeAssetPlatform.windows,
      _ => throw UnsupportedError('Unsupported ABI for DecentDB assets: $abi'),
    };
  }

  static String? _findProjectDirectory(String startPath) {
    var current = Directory(startPath).absolute;
    while (true) {
      final lockFile = File(p.join(current.path, 'pubspec.lock'));
      if (lockFile.existsSync()) {
        return current.path;
      }
      final parent = current.parent;
      if (parent.path == current.path) {
        return null;
      }
      current = parent;
    }
  }

  static String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}

class DecentDbNativeReleaseDownload {
  const DecentDbNativeReleaseDownload({
    required this.name,
    required this.downloadUri,
  });

  final String name;
  final Uri downloadUri;

  factory DecentDbNativeReleaseDownload.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final downloadUrl = json['browser_download_url'];
    if (name is! String || downloadUrl is! String) {
      throw StateError('Release asset metadata is missing required fields.');
    }
    return DecentDbNativeReleaseDownload(
      name: name,
      downloadUri: Uri.parse(downloadUrl),
    );
  }
}
