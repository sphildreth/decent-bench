import 'dart:convert';
import 'dart:io';

import 'decentdb_cli_resolver.dart';

typedef DecentDbCliCommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class DecentDbLuaExtensionValidationResult {
  const DecentDbLuaExtensionValidationResult({
    required this.cliPath,
    required this.arguments,
    required this.packageDirectoryPath,
    required this.allowUnsigned,
    required this.stdoutText,
    required this.stderrText,
    required this.exitCode,
    this.jsonOutput,
  });

  final String cliPath;
  final List<String> arguments;
  final String packageDirectoryPath;
  final bool allowUnsigned;
  final String stdoutText;
  final String stderrText;
  final int exitCode;
  final Object? jsonOutput;
}

class DecentDbLuaExtensionValidationFailure implements Exception {
  const DecentDbLuaExtensionValidationFailure({
    required this.message,
    required this.cliPath,
    required this.arguments,
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
  });

  final String message;
  final String cliPath;
  final List<String> arguments;
  final int exitCode;
  final String stdoutText;
  final String stderrText;

  String toDisplayMessage() {
    final parts = <String>[
      message,
      'Command: $cliPath ${arguments.join(' ')}',
      'Exit code: $exitCode',
      if (stdoutText.trim().isNotEmpty) 'Output:\n${stdoutText.trim()}',
      if (stderrText.trim().isNotEmpty) 'Error output:\n${stderrText.trim()}',
    ];
    return parts.join('\n\n');
  }

  @override
  String toString() => toDisplayMessage();
}

class DecentDbLuaExtensionValidationService {
  DecentDbLuaExtensionValidationService({
    DecentDbCliPathResolver? cliPathResolver,
    DecentDbCliCommandRunner? commandRunner,
  }) : _cliPathResolver = cliPathResolver,
       _commandRunner = commandRunner ?? _defaultCommandRunner;

  final DecentDbCliPathResolver? _cliPathResolver;
  final DecentDbCliCommandRunner _commandRunner;

  Future<DecentDbLuaExtensionValidationResult> validatePackage({
    required String packageDirectoryPath,
    bool allowUnsigned = false,
    List<String> trustEntries = const <String>[],
  }) async {
    final normalizedPath = packageDirectoryPath.trim();
    if (normalizedPath.isEmpty) {
      throw const DecentDbLuaExtensionValidationFailure(
        message: 'Choose a Lua extension package directory to validate.',
        cliPath: '',
        arguments: <String>[],
        exitCode: -1,
        stdoutText: '',
        stderrText: '',
      );
    }

    final cliPath = await (_cliPathResolver ?? DecentDbCliResolver().resolve)();
    final arguments = buildValidateArguments(
      packageDirectoryPath: normalizedPath,
      allowUnsigned: allowUnsigned,
      trustEntries: trustEntries,
    );

    final processResult = await _commandRunner(cliPath, arguments);
    final stdoutText = _processText(processResult.stdout);
    final stderrText = _processText(processResult.stderr);

    if (processResult.exitCode != 0) {
      throw DecentDbLuaExtensionValidationFailure(
        message: 'DecentDB extension validation failed.',
        cliPath: cliPath,
        arguments: arguments,
        exitCode: processResult.exitCode,
        stdoutText: stdoutText,
        stderrText: stderrText,
      );
    }

    Object? jsonOutput;
    final trimmedOutput = stdoutText.trim();
    if (trimmedOutput.isNotEmpty) {
      jsonOutput = jsonDecode(trimmedOutput);
    }

    return DecentDbLuaExtensionValidationResult(
      cliPath: cliPath,
      arguments: List<String>.unmodifiable(arguments),
      packageDirectoryPath: normalizedPath,
      allowUnsigned: allowUnsigned,
      stdoutText: stdoutText,
      stderrText: stderrText,
      exitCode: processResult.exitCode,
      jsonOutput: jsonOutput,
    );
  }

  static List<String> buildValidateArguments({
    required String packageDirectoryPath,
    bool allowUnsigned = false,
    List<String> trustEntries = const <String>[],
  }) {
    final arguments = <String>[
      'extension',
      'validate',
      packageDirectoryPath,
      '--format=json',
    ];

    for (final trustEntry in trustEntries) {
      final normalized = trustEntry.trim();
      if (normalized.isEmpty) {
        continue;
      }
      arguments.add('--trust-extension=$normalized');
    }

    if (allowUnsigned) {
      arguments.add('--allow-unsigned');
    }

    return arguments;
  }

  static Future<ProcessResult> _defaultCommandRunner(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments, runInShell: false);
  }

  static String _processText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is List<int>) {
      return utf8.decode(value, allowMalformed: true);
    }
    return value.toString();
  }
}
