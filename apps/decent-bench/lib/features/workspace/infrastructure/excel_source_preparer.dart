import 'dart:convert';
import 'dart:io';

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
  return _prepareConvertedWorkbookSource(
    rawSourcePath.trim(),
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

String _convertLegacyWorkbookToXlsx(String sourcePath, String outputDirectory) {
  final args = <String>[
    '--headless',
    '--convert-to',
    'xlsx',
    '--outdir',
    outputDirectory,
    sourcePath,
  ];
  final failures = <String>[];

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

  throw BridgeFailure(
    'Legacy `.xls` workbooks require LibreOffice/soffice for temporary conversion before import. '
    'Tried ${_libreOfficeExecutables().join(", ")}. ${failures.join(" ")}',
  );
}

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
