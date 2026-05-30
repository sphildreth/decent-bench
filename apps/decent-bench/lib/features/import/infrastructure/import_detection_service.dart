import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../domain/import_models.dart';
import 'fixed_width_import_support.dart';
import 'import_format_registry.dart';
import 'log_import_support.dart';
import 'spreadsheetml_import_support.dart';

const int _maxSingleXzCompressedBytes = 64 * 1024 * 1024;
const int _maxZipArchiveBytes = 256 * 1024 * 1024;

class ImportDetectionService {
  ImportDetectionService({ImportFormatRegistry? registry})
    : _registry = registry ?? ImportFormatRegistry.instance;

  final ImportFormatRegistry _registry;

  Future<ImportDetectionResult> detect(String sourcePath) async {
    final file = File(sourcePath);
    var format = _registry.detectByPath(sourcePath);
    final warnings = <String>[];
    final contentFormat = await _detectContentRoutedFormat(
      sourcePath: sourcePath,
      file: file,
      pathFormat: format,
    );
    if (contentFormat != null) {
      format = contentFormat;
    }
    if (format.key == ImportFormatKey.zipArchive) {
      final candidates = await _detectZipCandidates(sourcePath);
      if (candidates.isEmpty) {
        warnings.add(
          'The archive does not contain any recognized import sources yet.',
        );
      }
      return ImportDetectionResult(
        sourcePath: sourcePath,
        format: format,
        warnings: warnings,
        moduleId: _moduleIdFor(format),
        archiveCandidates: candidates,
      );
    }
    if (format.key == ImportFormatKey.gzipArchive) {
      final ext = p.extension(sourcePath).toLowerCase();
      final innerName = p.basenameWithoutExtension(sourcePath);
      if (ext == '.tgz' || _looksLikeTar(innerName)) {
        return _detectTarCandidates(
          sourcePath: sourcePath,
          format: format,
          innerName: innerName,
          listArgs: ['-tzf', sourcePath],
          extractFlag: '-xzf',
        );
      }
      final candidate = await _detectGzipCandidate(sourcePath);
      return ImportDetectionResult(
        sourcePath: sourcePath,
        format: format,
        warnings: candidate == null
            ? <String>[
                'The GZip filename does not indicate a supported inner source.',
              ]
            : warnings,
        archiveCandidates: candidate == null
            ? const <ImportArchiveCandidate>[]
            : <ImportArchiveCandidate>[candidate],
        moduleId: _moduleIdFor(format),
      );
    }
    if (format.key == ImportFormatKey.bzip2Archive) {
      final ext = p.extension(sourcePath).toLowerCase();
      final innerName = p.basenameWithoutExtension(sourcePath);
      if (ext == '.tbz2' || _looksLikeTar(innerName)) {
        return _detectTarCandidates(
          sourcePath: sourcePath,
          format: format,
          innerName: innerName,
          listArgs: ['-tjf', sourcePath],
          extractFlag: '-xjf',
        );
      }
      final candidate = await _detectBzip2SingleFileCandidate(sourcePath);
      return ImportDetectionResult(
        sourcePath: sourcePath,
        format: format,
        warnings: candidate == null
            ? <String>[
                'The BZip2 filename does not indicate a supported inner '
                    'source.',
              ]
            : warnings,
        archiveCandidates: candidate == null
            ? const <ImportArchiveCandidate>[]
            : <ImportArchiveCandidate>[candidate],
        moduleId: _moduleIdFor(format),
      );
    }
    if (format.key == ImportFormatKey.xzArchive) {
      final ext = p.extension(sourcePath).toLowerCase();
      final innerName = p.basenameWithoutExtension(sourcePath);
      if (ext == '.txz' || _looksLikeTar(innerName)) {
        return _detectTarCandidates(
          sourcePath: sourcePath,
          format: format,
          innerName: innerName,
          listArgs: ['-tJf', sourcePath],
          extractFlag: '-xJf',
        );
      }
      final candidate = await _detectXzSingleFileCandidate(sourcePath);
      return ImportDetectionResult(
        sourcePath: sourcePath,
        format: format,
        warnings: candidate == null
            ? <String>[
                'The XZ filename does not indicate a supported inner source.',
              ]
            : warnings,
        archiveCandidates: candidate == null
            ? const <ImportArchiveCandidate>[]
            : <ImportArchiveCandidate>[candidate],
        moduleId: _moduleIdFor(format),
      );
    }
    if (format.key == ImportFormatKey.sqlite && file.existsSync()) {
      final header = await file
          .openRead(0, 16)
          .fold<List<int>>(
            <int>[],
            (bytes, chunk) => <int>[...bytes, ...chunk],
          );
      final signature = String.fromCharCodes(header);
      if (!signature.startsWith('SQLite format 3')) {
        warnings.add(
          'The file uses a SQLite-like extension, but the header does not '
          'match the SQLite signature.',
        );
      }
    }
    return ImportDetectionResult(
      sourcePath: sourcePath,
      format: format,
      warnings: warnings,
      moduleId: _moduleIdFor(format),
    );
  }

  Future<ImportFormatDefinition?> _detectContentRoutedFormat({
    required String sourcePath,
    required File file,
    required ImportFormatDefinition pathFormat,
  }) async {
    if (!file.existsSync()) {
      return null;
    }
    final extension = p.extension(sourcePath).toLowerCase();
    if (extension != '.xml' &&
        extension != '.log' &&
        extension != '.jsonl' &&
        extension != '.ndjson' &&
        extension != '.txt' &&
        extension != '.dat') {
      return null;
    }
    final sample = await _readTextSample(file);
    if (sample.trim().isEmpty) {
      return null;
    }
    if (extension == '.xml' && isSpreadsheetMlText(sample)) {
      return _registry.forKey(ImportFormatKey.spreadsheetMl);
    }
    if ((extension == '.log' ||
            extension == '.jsonl' ||
            extension == '.ndjson' ||
            extension == '.txt') &&
        looksLikeJsonLogStream(sample)) {
      return _registry.forKey(ImportFormatKey.jsonLogStream);
    }
    if ((extension == '.log' || extension == '.txt') &&
        looksLikeSupportedLogTemplate(sample)) {
      return _registry.forKey(ImportFormatKey.delimitedLog);
    }
    if ((extension == '.txt' || extension == '.dat') &&
        pathFormat.key == ImportFormatKey.genericDelimited &&
        looksLikeFixedWidthText(sample)) {
      return _registry.forKey(ImportFormatKey.fixedWidth);
    }
    return null;
  }

  Future<String> _readTextSample(File file) async {
    const maxBytes = 64 * 1024;
    final opened = await file.open();
    try {
      final bytes = await opened.read(maxBytes);
      try {
        return utf8.decode(bytes);
      } on FormatException {
        return latin1.decode(bytes);
      }
    } finally {
      await opened.close();
    }
  }

  String _moduleIdFor(ImportFormatDefinition format) {
    return _registry.moduleForKey(format.key).id;
  }

  bool _looksLikeTar(String innerName) {
    return innerName.toLowerCase().endsWith('.tar');
  }

  Future<ImportDetectionResult> _detectTarCandidates({
    required String sourcePath,
    required ImportFormatDefinition format,
    required String innerName,
    required List<String> listArgs,
    required String extractFlag,
  }) async {
    final warnings = <String>[];
    final candidates = <ImportArchiveCandidate>[];

    try {
      final result = await Process.run(
        'tar',
        listArgs,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) {
        warnings.add(
          'Failed to list tar archive contents: '
          '${(result.stderr as String).trim()}',
        );
        return ImportDetectionResult(
          sourcePath: sourcePath,
          format: format,
          warnings: warnings,
          moduleId: _moduleIdFor(format),
          archiveCandidates: candidates,
        );
      }
      final lines = LineSplitter.split(
        result.stdout as String,
      ).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
      for (final entryPath in lines) {
        if (entryPath.endsWith('/')) {
          continue;
        }
        if (_isUnsafeArchiveEntry(entryPath)) {
          warnings.add(
            'Skipping unsafe archive entry path `$entryPath` during preview.',
          );
          continue;
        }
        final innerFormat = _registry.detectByPath(entryPath);
        if (innerFormat.key != ImportFormatKey.unknown) {
          candidates.add(
            ImportArchiveCandidate(
              entryPath: entryPath,
              displayName: entryPath,
              innerFormatKey: innerFormat.key,
              innerFormatLabel: innerFormat.label,
              supportState: innerFormat.supportState,
            ),
          );
          continue;
        }
        final inferred = _inferFormatForExtensionlessTarEntry(entryPath);
        candidates.add(
          ImportArchiveCandidate(
            entryPath: entryPath,
            displayName: entryPath,
            innerFormatKey: inferred.key,
            innerFormatLabel: inferred.label,
            supportState: inferred.supportState,
          ),
        );
      }
    } on ProcessException catch (error) {
      warnings.add(
        'tar command unavailable for archive listing: ${error.message}',
      );
    }

    if (candidates.isEmpty) {
      warnings.add('No importable files were found inside the tar archive.');
    }
    return ImportDetectionResult(
      sourcePath: sourcePath,
      format: format,
      warnings: warnings,
      moduleId: _moduleIdFor(format),
      archiveCandidates: candidates,
    );
  }

  ImportFormatDefinition _inferFormatForExtensionlessTarEntry(
    String entryPath,
  ) {
    final baseName = p.basename(entryPath);
    if (baseName.contains('.')) {
      return _registry.detectByPath(baseName);
    }
    return _registry.forKey(ImportFormatKey.tsv);
  }

  Future<List<ImportArchiveCandidate>> _detectZipCandidates(
    String sourcePath,
  ) async {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      return const <ImportArchiveCandidate>[];
    }
    final fileLength = await file.length();
    if (fileLength > _maxZipArchiveBytes) {
      throw StateError(
        'ZIP archive exceeds the ${_maxZipArchiveBytes ~/ (1024 * 1024)} MiB '
        'size limit for in-memory processing. Please extract the archive '
        'and import the contents directly.',
      );
    }
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final candidates = <ImportArchiveCandidate>[];
    for (final entry in archive) {
      if (!entry.isFile) {
        continue;
      }
      if (_isUnsafeArchiveEntry(entry.name)) {
        continue;
      }
      final innerFormat = _registry.detectByPath(entry.name);
      if (innerFormat.key == ImportFormatKey.unknown) {
        continue;
      }
      candidates.add(
        ImportArchiveCandidate(
          entryPath: entry.name,
          displayName: entry.name,
          innerFormatKey: innerFormat.key,
          innerFormatLabel: innerFormat.label,
          supportState: innerFormat.supportState,
        ),
      );
    }
    return candidates;
  }

  Future<ImportArchiveCandidate?> _detectGzipCandidate(
    String sourcePath,
  ) async {
    final innerName = p.basenameWithoutExtension(sourcePath);
    final innerFormat = _registry.detectByPath(innerName);
    if (innerFormat.key == ImportFormatKey.unknown) {
      return null;
    }
    return ImportArchiveCandidate(
      entryPath: innerName,
      displayName: innerName,
      innerFormatKey: innerFormat.key,
      innerFormatLabel: innerFormat.label,
      supportState: innerFormat.supportState,
    );
  }

  Future<ImportArchiveCandidate?> _detectBzip2SingleFileCandidate(
    String sourcePath,
  ) async {
    final innerName = p.basenameWithoutExtension(sourcePath);
    final innerFormat = _registry.detectByPath(innerName);
    if (innerFormat.key == ImportFormatKey.unknown) {
      return null;
    }
    return ImportArchiveCandidate(
      entryPath: innerName,
      displayName: innerName,
      innerFormatKey: innerFormat.key,
      innerFormatLabel: innerFormat.label,
      supportState: innerFormat.supportState,
    );
  }

  Future<ImportArchiveCandidate?> _detectXzSingleFileCandidate(
    String sourcePath,
  ) async {
    final innerName = p.basenameWithoutExtension(sourcePath);
    final innerFormat = _registry.detectByPath(innerName);
    if (innerFormat.key == ImportFormatKey.unknown) {
      return null;
    }
    return ImportArchiveCandidate(
      entryPath: innerName,
      displayName: innerName,
      innerFormatKey: innerFormat.key,
      innerFormatLabel: innerFormat.label,
      supportState: innerFormat.supportState,
    );
  }

  Future<String> extractArchiveCandidate({
    required String archivePath,
    required ImportFormatKey wrapperKey,
    required ImportArchiveCandidate candidate,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'decent-bench-import-',
    );
    final entryBaseName = p.basename(candidate.entryPath);

    if (wrapperKey == ImportFormatKey.zipArchive) {
      final outputPath = p.join(tempDir.path, entryBaseName);
      final archiveFile = File(archivePath);
      final fileLength = await archiveFile.length();
      if (fileLength > _maxZipArchiveBytes) {
        throw StateError(
          'ZIP archive exceeds the ${_maxZipArchiveBytes ~/ (1024 * 1024)} MiB '
          'size limit for in-memory processing. Please extract the archive '
          'and import the contents directly.',
        );
      }
      final archive = ZipDecoder().decodeBytes(
        await archiveFile.readAsBytes(),
      );
      for (final entry in archive) {
        if (entry.isFile && entry.name == candidate.entryPath) {
          final bytes = entry.content as List<int>;
          final output = File(outputPath);
          output.parent.createSync(recursive: true);
          output.writeAsBytesSync(bytes, flush: true);
          return output.path;
        }
      }
      throw StateError(
        'Archive entry `${candidate.entryPath}` was not found in '
        '$archivePath.',
      );
    }

    if (wrapperKey == ImportFormatKey.gzipArchive) {
      final ext = p.extension(archivePath).toLowerCase();
      final innerName = p.basenameWithoutExtension(archivePath);
      if (ext == '.tgz' || _looksLikeTar(innerName)) {
        return await _extractTarEntry(
          archivePath: archivePath,
          tempDir: tempDir,
          entryPath: candidate.entryPath,
          extractFlag: '-xzf',
        );
      }
      final outputPath = p.join(tempDir.path, entryBaseName);
      final decoded = GZipDecoder().decodeBytes(
        await File(archivePath).readAsBytes(),
      );
      final output = File(outputPath);
      output.parent.createSync(recursive: true);
      output.writeAsBytesSync(decoded, flush: true);
      return output.path;
    }

    if (wrapperKey == ImportFormatKey.bzip2Archive) {
      final ext = p.extension(archivePath).toLowerCase();
      final innerName = p.basenameWithoutExtension(archivePath);
      if (ext == '.tbz2' || _looksLikeTar(innerName)) {
        return await _extractTarEntry(
          archivePath: archivePath,
          tempDir: tempDir,
          entryPath: candidate.entryPath,
          extractFlag: '-xjf',
        );
      }
      final outputPath = p.join(tempDir.path, entryBaseName);
      final decoded = BZip2Decoder().decodeBytes(
        await File(archivePath).readAsBytes(),
      );
      final output = File(outputPath);
      output.parent.createSync(recursive: true);
      output.writeAsBytesSync(decoded, flush: true);
      return output.path;
    }

    if (wrapperKey == ImportFormatKey.xzArchive) {
      final ext = p.extension(archivePath).toLowerCase();
      final innerName = p.basenameWithoutExtension(archivePath);
      if (ext == '.txz' || _looksLikeTar(innerName)) {
        return await _extractTarEntry(
          archivePath: archivePath,
          tempDir: tempDir,
          entryPath: candidate.entryPath,
          extractFlag: '-xJf',
        );
      }
      final input = File(archivePath);
      final compressedBytes = input.lengthSync();
      if (compressedBytes > _maxSingleXzCompressedBytes) {
        throw StateError(
          'Single-file XZ import is limited to '
          '${_maxSingleXzCompressedBytes ~/ (1024 * 1024)} MiB compressed '
          'input until a streaming XZ decoder is available.',
        );
      }
      final outputPath = p.join(tempDir.path, entryBaseName);
      final decoded = XZDecoder().decodeBytes(await input.readAsBytes());
      final output = File(outputPath);
      output.parent.createSync(recursive: true);
      output.writeAsBytesSync(decoded, flush: true);
      return output.path;
    }

    throw StateError('Unsupported wrapper extraction for ${wrapperKey.name}.');
  }

  Future<String> _extractTarEntry({
    required String archivePath,
    required Directory tempDir,
    required String entryPath,
    required String extractFlag,
  }) async {
    if (_isUnsafeArchiveEntry(entryPath)) {
      throw StateError(
        'Refusing to extract unsafe archive entry `$entryPath`.',
      );
    }
    final baseName = p.basename(entryPath);
    final inferredFormat = _inferFormatForExtensionlessTarEntry(entryPath);
    final extension = inferredFormat.extensions.isNotEmpty
        ? inferredFormat.extensions.first
        : '';

    // Extract by the exact archive-relative path to avoid GNU tar-specific
    // --no-anchored semantics and basename collisions across subdirectories.
    final result = await Process.run(
      'tar',
      [extractFlag, archivePath, '-C', tempDir.path, entryPath],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'Failed to extract `$entryPath` from tar archive: '
        '${(result.stderr as String).trim()}',
      );
    }

    final extractedPath = p.join(tempDir.path, entryPath);
    final extractedFile = File(extractedPath);
    if (!extractedFile.existsSync()) {
      throw StateError(
        'Extracted entry not found at expected path `$extractedPath`.',
      );
    }

    if (extension.isNotEmpty && !baseName.toLowerCase().endsWith(extension)) {
      final renamed = '$extractedPath$extension';
      extractedFile.renameSync(renamed);
      return renamed;
    }
    return extractedPath;
  }

  bool _isUnsafeArchiveEntry(String entryPath) {
    final normalized = p.posix.normalize(entryPath.replaceAll('\\', '/'));
    return normalized.startsWith('/') ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        RegExp(r'^[A-Za-z]:').hasMatch(entryPath);
  }
}
