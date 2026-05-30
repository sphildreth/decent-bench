import 'dart:io';

import 'package:decent_bench/features/workspace/infrastructure/decentdb_lua_extension_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds official extension validate command by default', () async {
    String? capturedExecutable;
    List<String>? capturedArguments;

    final service = DecentDbLuaExtensionValidationService(
      cliPathResolver: () async => '/tmp/decentdb',
      commandRunner: (executable, arguments) async {
        capturedExecutable = executable;
        capturedArguments = arguments;
        return ProcessResult(1, 0, '{"valid":true}', '');
      },
    );

    final result = await service.validatePackage(
      packageDirectoryPath: '/tmp/text_tools',
    );

    expect(capturedExecutable, '/tmp/decentdb');
    expect(capturedArguments, <String>[
      'extension',
      'validate',
      '/tmp/text_tools',
      '--format=json',
    ]);
    expect(result.exitCode, 0);
    expect(result.jsonOutput, isA<Map<String, Object?>>());
    expect((result.jsonOutput as Map<String, Object?>)['valid'], isTrue);
  });

  test(
    'adds trust entries and optional unsigned override only when requested',
    () {
      final arguments =
          DecentDbLuaExtensionValidationService.buildValidateArguments(
            packageDirectoryPath: '/tmp/text_tools',
            trustEntries: const <String>[
              'text_tools@sha256:abc',
              'text_extra@sha256:def@release@base64:XYZ',
            ],
            allowUnsigned: true,
          );

      expect(arguments, <String>[
        'extension',
        'validate',
        '/tmp/text_tools',
        '--format=json',
        '--trust-extension=text_tools@sha256:abc',
        '--trust-extension=text_extra@sha256:def@release@base64:XYZ',
        '--allow-unsigned',
      ]);
    },
  );

  test('surfaces command failures with stdout and stderr details', () async {
    final service = DecentDbLuaExtensionValidationService(
      cliPathResolver: () async => '/tmp/decentdb',
      commandRunner: (_, _) async {
        return ProcessResult(1, 2, '{"valid":false}', 'signature missing');
      },
    );

    await expectLater(
      service.validatePackage(packageDirectoryPath: '/tmp/text_tools'),
      throwsA(
        isA<DecentDbLuaExtensionValidationFailure>()
            .having((error) => error.exitCode, 'exitCode', 2)
            .having(
              (error) => error.stderrText,
              'stderrText',
              contains('signature missing'),
            ),
      ),
    );
  });
}
