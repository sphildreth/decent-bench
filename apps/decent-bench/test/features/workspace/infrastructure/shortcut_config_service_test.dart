import 'dart:io' as dart_io;

import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/infrastructure/shortcut_config_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShortcutConfigService', () {
    const service = ShortcutConfigService();

    test('tryParseActivator parses Ctrl+Enter', () {
      final activator = service.tryParseActivator('Ctrl+Enter');
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.enter);
      expect(activator.control, isTrue);
      expect(activator.shift, isFalse);
      expect(activator.alt, isFalse);
    });

    test('tryParseActivator parses Shift+Ctrl+F5', () {
      final activator = service.tryParseActivator('Shift+Ctrl+F5');
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.f5);
      expect(activator.control, isTrue);
      expect(activator.shift, isTrue);
    });

    test('tryParseActivator parses single key T', () {
      final activator = service.tryParseActivator('T');
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.keyT);
    });

    test('tryParseActivator parses Esc', () {
      final activator = service.tryParseActivator('Esc');
      expect(activator, isNotNull);
      expect(activator!.trigger, LogicalKeyboardKey.escape);
    });

    test('tryParseActivator returns null for empty string', () {
      expect(service.tryParseActivator(''), isNull);
    });

    test('tryParseActivator returns null for modifiers only', () {
      expect(service.tryParseActivator('Ctrl+Shift'), isNull);
    });

    test('tryParseActivator returns null for unknown key', () {
      expect(service.tryParseActivator('Ctrl+UnknownKey'), isNull);
    });

    test('displayLabel formats Ctrl+Enter', () {
      final label = service.displayLabel('Ctrl+Enter');
      if (dart_io.Platform.isMacOS) {
        expect(label, contains('Cmd'));
      } else {
        expect(label, contains('Ctrl'));
      }
      expect(label, contains('Enter'));
    });

    test('displayLabel formats Alt+Delete', () {
      final label = service.displayLabel('Alt+Delete');
      if (dart_io.Platform.isMacOS) {
        expect(label, contains('Option'));
      } else {
        expect(label, contains('Alt'));
      }
    });

    test('load builds bindings from config defaults', () {
      final config = AppConfig.defaults();
      final bindings = service.load(config);

      expect(bindings, isNotEmpty);
      for (final binding in bindings.values) {
        expect(binding.commandId, isNotEmpty);
        expect(binding.activator, isNotNull);
        expect(binding.displayLabel, isNotEmpty);
        expect(binding.rawValue, isNotEmpty);
      }
    });

    test('load falls back to default when custom binding is invalid', () {
      final config = AppConfig.defaults().copyWith(
        shortcutBindings: <String, String>{
          ...AppConfig.defaultShortcutBindings(),
          'tools_run_query': 'NotARealKey+ZZZZZ',
        },
      );
      final bindings = service.load(config);

      final runQuery = bindings['tools_run_query'];
      expect(runQuery, isNotNull);
      expect(runQuery!.activator, isNotNull);
      expect(
        runQuery.rawValue,
        AppConfig.defaultShortcutBindings()['tools_run_query'],
      );
    });

    test('load parses valid custom binding', () {
      final config = AppConfig.defaults().copyWith(
        shortcutBindings: <String, String>{
          ...AppConfig.defaultShortcutBindings(),
          'tools_run_query': 'Ctrl+Shift+Enter',
        },
      );
      final bindings = service.load(config);

      final runQuery = bindings['tools_run_query'];
      expect(runQuery, isNotNull);
      expect(runQuery!.rawValue, 'Ctrl+Shift+Enter');
      expect(runQuery.activator.control, isTrue);
      expect(runQuery.activator.shift, isTrue);
      expect(runQuery.activator.trigger, LogicalKeyboardKey.enter);
    });

    test('tryParseActivator parses F1-F12', () {
      for (var i = 1; i <= 12; i++) {
        final activator = service.tryParseActivator('F$i');
        expect(activator, isNotNull, reason: 'Failed to parse F$i');
      }
    });

    test('tryParseActivator parses digit keys', () {
      for (var i = 0; i <= 9; i++) {
        final activator = service.tryParseActivator('$i');
        expect(activator, isNotNull, reason: 'Failed to parse digit $i');
      }
    });

    test('tryParseActivator parses Tab', () {
      expect(service.tryParseActivator('Tab')!.trigger, LogicalKeyboardKey.tab);
    });

    test('tryParseActivator parses Space', () {
      expect(
        service.tryParseActivator('Space')!.trigger,
        LogicalKeyboardKey.space,
      );
    });

    test('tryParseActivator parses Backspace', () {
      expect(
        service.tryParseActivator('Backspace')!.trigger,
        LogicalKeyboardKey.backspace,
      );
    });
  });
}
