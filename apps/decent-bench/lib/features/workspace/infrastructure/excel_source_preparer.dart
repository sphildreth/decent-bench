import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../domain/workspace_models.dart';

PreparedExcelWorkbookSource prepareExcelWorkbookSource(String rawSourcePath) {
  final sourcePath = rawSourcePath.trim();
  final extension = p.extension(sourcePath).toLowerCase();
  if (extension != '.xls') {
    return PreparedExcelWorkbookSource(
      resolvedPath: sourcePath,
      warnings: const <String>[],
      dispose: () {},
    );
  }

  return _prepareConvertedWorkbookSource(
    sourcePath,
    warning:
        'Legacy `.xls` workbook was converted to temporary `.xlsx` before import.',
  );
}

PreparedExcelWorkbookSource normalizeExcelWorkbookSource(String rawSourcePath) {
  final sourcePath = rawSourcePath.trim();
  final extension = p.extension(sourcePath).toLowerCase();
  if (extension == '.xlsx') {
    return _prepareNormalizedXlsxSource(
      sourcePath,
      warning:
          'Workbook was normalized through temporary `.xlsx` rewrite because the direct parser rejected the original file.',
    );
  }

  return _prepareConvertedWorkbookSource(
    sourcePath,
    warning:
        'Workbook was normalized through temporary `.xlsx` conversion because the direct parser rejected the original file.',
  );
}

PreparedExcelWorkbookSource _prepareConvertedWorkbookSource(
  String sourcePath, {
  required String warning,
}) {
  final scratchDir = Directory.systemTemp.createTempSync(
    'decent-bench-xls-conversion-',
  );
  try {
    final convertedPath = _convertLegacyWorkbookToXlsx(
      sourcePath,
      scratchDir.path,
    );
    return PreparedExcelWorkbookSource(
      resolvedPath: convertedPath,
      warnings: <String>[warning],
      dispose: () {
        if (scratchDir.existsSync()) {
          scratchDir.deleteSync(recursive: true);
        }
      },
    );
  } catch (_) {
    if (scratchDir.existsSync()) {
      scratchDir.deleteSync(recursive: true);
    }
    rethrow;
  }
}

class PreparedExcelWorkbookSource {
  const PreparedExcelWorkbookSource({
    required this.resolvedPath,
    required this.warnings,
    required void Function() dispose,
  }) : _dispose = dispose;

  final String resolvedPath;
  final List<String> warnings;
  final void Function() _dispose;

  void dispose() => _dispose();
}

PreparedExcelWorkbookSource _prepareNormalizedXlsxSource(
  String sourcePath, {
  required String warning,
}) {
  final scratchDir = Directory.systemTemp.createTempSync(
    'decent-bench-xlsx-normalization-',
  );
  try {
    final normalizedPath = _rewriteXlsxForExcelPackage(
      sourcePath,
      scratchDir.path,
    );
    return PreparedExcelWorkbookSource(
      resolvedPath: normalizedPath,
      warnings: <String>[warning],
      dispose: () {
        if (scratchDir.existsSync()) {
          scratchDir.deleteSync(recursive: true);
        }
      },
    );
  } catch (_) {
    if (scratchDir.existsSync()) {
      scratchDir.deleteSync(recursive: true);
    }
    rethrow;
  }
}

String _convertLegacyWorkbookToXlsx(String sourcePath, String outputDirectory) {
  final failures = <String>[];
  final profileDir = Directory.systemTemp.createTempSync(
    'decent-bench-libreoffice-profile-',
  );
  final args = <String>[
    '--headless',
    '--nologo',
    '--nodefault',
    '--nofirststartwizard',
    '--nolockcheck',
    '-env:UserInstallation=${profileDir.uri}',
    '--convert-to',
    'xlsx',
    '--outdir',
    outputDirectory,
    sourcePath,
  ];

  try {
    for (final executable in _libreOfficeExecutables()) {
      try {
        final result = Process.runSync(
          executable,
          args,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        final convertedPath = _findConvertedWorkbook(
          sourcePath: sourcePath,
          outputDirectory: outputDirectory,
        );
        if (result.exitCode == 0 && convertedPath != null) {
          return convertedPath;
        }

        failures.add(
          '$executable exited with ${result.exitCode}: ${_compactOutput(result.stdout, result.stderr)}',
        );
      } on ProcessException catch (error) {
        failures.add('$executable unavailable: ${error.message}');
      }
    }
  } finally {
    if (profileDir.existsSync()) {
      profileDir.deleteSync(recursive: true);
    }
  }

  throw BridgeFailure(
    'Legacy `.xls` workbooks require LibreOffice/soffice for temporary conversion before import. '
    'Tried ${_libreOfficeExecutables().join(", ")}. ${failures.join(" ")}',
  );
}

String _rewriteXlsxForExcelPackage(String sourcePath, String outputDirectory) {
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    throw BridgeFailure('Excel source file does not exist: $sourcePath');
  }

  final archive = ZipDecoder().decodeBytes(sourceFile.readAsBytesSync());
  final normalizedArchive = Archive();
  for (final entry in archive.files) {
    if (!entry.isFile) {
      continue;
    }

    final normalizedBytes = _normalizeXlsxArchiveEntry(entry);
    final normalizedEntry = ArchiveFile(
      entry.name,
      normalizedBytes.length,
      normalizedBytes,
    );
    normalizedEntry.mode = entry.mode;
    normalizedEntry.lastModTime = entry.lastModTime;
    normalizedEntry.comment = entry.comment;
    normalizedArchive.addFile(normalizedEntry);
  }

  final encoded = ZipEncoder().encode(normalizedArchive);
  if (encoded == null || encoded.isEmpty) {
    throw BridgeFailure('Failed to normalize workbook archive: $sourcePath');
  }

  final normalizedPath = p.join(outputDirectory, p.basename(sourcePath));
  File(normalizedPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(encoded, flush: true);
  return normalizedPath;
}

Uint8List _normalizeXlsxArchiveEntry(ArchiveFile entry) {
  final content = entry.content;
  final bytes = switch (content) {
    final Uint8List value => value,
    final List<int> value => Uint8List.fromList(value),
    _ => throw BridgeFailure(
      'Unsupported workbook archive entry type for `${entry.name}`.',
    ),
  };

  if (!_shouldNormalizeXlsxArchiveEntry(entry.name, bytes)) {
    return bytes;
  }

  final xml = utf8.decode(bytes, allowMalformed: true);
  final normalizedXml = _normalizeOfficeOpenXmlDocument(entry.name, xml);
  return Uint8List.fromList(utf8.encode(normalizedXml));
}

bool _shouldNormalizeXlsxArchiveEntry(String name, Uint8List bytes) {
  final lowerName = name.toLowerCase();
  if (!lowerName.endsWith('.xml') && !lowerName.endsWith('.rels')) {
    return false;
  }
  return true;
}

String _normalizeOfficeOpenXmlDocument(String name, String xml) {
  var normalized = _stripUtf8Bom(xml);
  normalized = _normalizeXmlElementPrefixes(normalized);
  if (name.toLowerCase().endsWith('.rels')) {
    normalized = _normalizeRelationshipTargets(normalized);
  }
  if (_looksLikeWorksheetPart(name)) {
    normalized = _normalizeEmptyInlineStringCells(normalized);
  }
  return normalized;
}

String _normalizeXmlElementPrefixes(String xml) {
  return xml.replaceAllMapped(_xmlElementPrefixPattern, (match) {
    final slash = match.group(1) ?? '';
    final localName = match.group(3) ?? '';
    return '<$slash$localName';
  });
}

String _normalizeRelationshipTargets(String xml) {
  return xml.replaceAllMapped(_relationshipTargetPattern, (match) {
    final prefix = match.group(1) ?? '';
    final quote = match.group(2) ?? '"';
    return '$prefix$quote';
  });
}

String _normalizeEmptyInlineStringCells(String xml) {
  final expanded = xml.replaceAllMapped(_emptyInlineStringCellPattern, (match) {
    final attributes = match.group(1) ?? '';
    return '<c$attributes><is><t></t></is></c>';
  });
  return expanded.replaceAllMapped(_selfClosingInlineStringCellPattern, (
    match,
  ) {
    final attributes = match.group(1) ?? '';
    return '<c$attributes><is><t></t></is></c>';
  });
}

bool _looksLikeWorksheetPart(String name) {
  final normalized = name.replaceAll('\\', '/').toLowerCase();
  return normalized.startsWith('xl/worksheets/') && normalized.endsWith('.xml');
}

String _stripUtf8Bom(String value) {
  if (value.isNotEmpty && value.codeUnitAt(0) == 0xfeff) {
    return value.substring(1);
  }
  return value;
}

final RegExp _xmlElementPrefixPattern = RegExp(
  r'<(/?)([A-Za-z_][\w.-]*):([A-Za-z_][\w.-]*)',
);

final RegExp _relationshipTargetPattern = RegExp(
  r"""(Target=)(["'])/xl/""",
);

final RegExp _emptyInlineStringCellPattern = RegExp(
  r'<c([^>]*\bt="inlineStr"[^>]*)>\s*</c>',
);

final RegExp _selfClosingInlineStringCellPattern = RegExp(
  r'<c([^>]*\bt="inlineStr"[^>]*)\s*/>',
);

Iterable<String> _libreOfficeExecutables() sync* {
  if (Platform.isWindows) {
    yield r'C:\Program Files\LibreOffice\program\soffice.exe';
    yield r'C:\Program Files (x86)\LibreOffice\program\soffice.exe';
    yield 'soffice.exe';
    yield 'soffice.com';
    yield 'libreoffice.exe';
    return;
  }

  if (Platform.isMacOS) {
    yield '/Applications/LibreOffice.app/Contents/MacOS/soffice';
  }

  yield 'soffice';
  yield 'libreoffice';
}

String? _findConvertedWorkbook({
  required String sourcePath,
  required String outputDirectory,
}) {
  final expectedPath = p.join(
    outputDirectory,
    '${p.basenameWithoutExtension(sourcePath)}.xlsx',
  );
  if (File(expectedPath).existsSync()) {
    return expectedPath;
  }

  final convertedFiles = Directory(outputDirectory)
      .listSync()
      .whereType<File>()
      .where((file) => p.extension(file.path).toLowerCase() == '.xlsx')
      .toList(growable: false);
  if (convertedFiles.length == 1) {
    return convertedFiles.single.path;
  }
  return null;
}

String _compactOutput(Object? stdout, Object? stderr) {
  final chunks = <String>[
    if ('$stdout'.trim().isNotEmpty) '$stdout'.trim(),
    if ('$stderr'.trim().isNotEmpty) '$stderr'.trim(),
  ];
  if (chunks.isEmpty) {
    return 'No process output.';
  }

  final combined = chunks.join(' ');
  return combined.length <= 240 ? combined : '${combined.substring(0, 237)}...';
}
