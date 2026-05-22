import 'package:decent_bench/app/theme.dart';
import 'package:decent_bench/app/theme_system/theme_presets.dart';
import 'package:decent_bench/features/workspace/application/menu_command_registry.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:decent_bench/features/workspace/infrastructure/shortcut_config_service.dart';
import 'package:decent_bench/features/workspace/presentation/shell/app_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'menu_command_contract.dart';

Widget _buildHost({
  required bool native,
  required bool hasOpenDatabase,
  required List<String> invokeLog,
}) {
  final registry = buildAuditedMenuCommandRegistry(
    hasOpenDatabase: hasOpenDatabase,
    invokeLog: invokeLog,
  );
  final child = Scaffold(body: const SizedBox.shrink());
  final host = native
      ? NativeAppMenuHost(
          registry: registry,
          recentFiles: const <String>[],
          onOpenRecent: (_) {},
          child: child,
        )
      : Scaffold(
          body: AppMenuBar(
            registry: registry,
            recentFiles: const <String>[],
            onOpenRecent: (_) {},
          ),
        );
  return MaterialApp(
    theme: buildDecentBenchTheme(buildEmergencyTheme()),
    home: host,
  );
}

void _collectPlatformCommands(
  Object node,
  Map<String, PlatformMenuItem> collector,
) {
  if (node is PlatformMenu) {
    for (final item in node.menus) {
      _collectPlatformCommands(item, collector);
    }
    return;
  }
  if (node is PlatformMenuItemGroup) {
    for (final item in node.members) {
      _collectPlatformCommands(item, collector);
    }
    return;
  }
  if (node is PlatformMenuItem) {
    if (node.label.isEmpty) {
      return;
    }
    collector[node.label] = node;
    return;
  }
}

bool entryEnabledState(MenuContractEntry entry, bool hasOpenDatabase) {
  return entry.enabledForDatabaseState(hasOpenDatabase: hasOpenDatabase);
}

SubmenuButton _submenuForLabel(WidgetTester tester, String label) {
  return tester.widget<SubmenuButton>(
    find.byWidgetPredicate((Widget widget) {
      return widget is SubmenuButton &&
          widget.child is Text &&
          (widget.child as Text).data == label;
    }, description: 'SubmenuButton with label "$label"'),
  );
}

MenuItemButton? _menuItemFromSubmenu(SubmenuButton submenu, String label) {
  final menuItemButtons = submenu.menuChildren.whereType<MenuItemButton>();
  for (final item in menuItemButtons) {
    final widget = item.child;
    if (widget is Text && widget.data == label) {
      return item;
    }
  }
  return null;
}

void main() {
  test('default application shortcuts target menu-contract commands', () {
    final entriesById = <String, MenuContractEntry>{
      for (final entry in kMenuCommandContract) entry.commandId: entry,
    };
    final shortcuts = const ShortcutConfigService().load(AppConfig.defaults());
    final activators = <ShortcutActivator, String>{};

    expect(
      shortcuts.keys,
      unorderedEquals(AppConfig.defaultShortcutBindings().keys),
    );
    for (final binding in shortcuts.values) {
      final contractEntry = entriesById[binding.commandId];
      expect(
        contractEntry,
        isNotNull,
        reason:
            'Default shortcut "${binding.rawValue}" points at missing command "${binding.commandId}".',
      );
      expect(
        contractEntry!.isDeferred,
        isFalse,
        reason:
            'Deferred command "${binding.commandId}" must not advertise an active shortcut.',
      );
      expect(
        activators.putIfAbsent(binding.activator, () => binding.commandId),
        binding.commandId,
        reason:
            'Shortcut "${binding.displayLabel}" is assigned to both "${activators[binding.activator]}" and "${binding.commandId}".',
      );
    }
  });

  for (final hasOpenDatabase in <bool>[false, true]) {
    test(
      'default shortcuts invoke enabled commands (dbOpen=$hasOpenDatabase)',
      () async {
        final shortcuts = const ShortcutConfigService().load(
          AppConfig.defaults(),
        );
        final invokeLog = <String>[];
        final registry = buildAuditedMenuCommandRegistry(
          hasOpenDatabase: hasOpenDatabase,
          invokeLog: invokeLog,
          shortcuts: shortcuts,
        );
        final shortcutMap = registry.buildShortcutMap();

        for (final binding in shortcuts.values) {
          final contractEntry = kMenuCommandContract.firstWhere(
            (entry) => entry.commandId == binding.commandId,
          );
          final expectedEnabled = contractEntry.enabledForDatabaseState(
            hasOpenDatabase: hasOpenDatabase,
          );
          final intent = shortcutMap[binding.activator];
          if (!expectedEnabled) {
            expect(
              intent,
              isNull,
              reason:
                  'Disabled command "${binding.commandId}" must not be invokable through "${binding.displayLabel}".',
            );
            continue;
          }

          expect(
            intent,
            isA<MenuCommandIntent>(),
            reason:
                'Enabled command "${binding.commandId}" must be mapped from "${binding.displayLabel}".',
          );
          final menuIntent = intent! as MenuCommandIntent;
          expect(menuIntent.commandId, binding.commandId);

          final previousLength = invokeLog.length;
          await registry.invoke(menuIntent.commandId);
          expect(
            invokeLog.sublist(previousLength),
            <String>[binding.commandId],
            reason:
                'Shortcut "${binding.displayLabel}" must invoke "${binding.commandId}".',
          );
        }
      },
    );
  }

  for (final hasOpenDatabase in <bool>[false, true]) {
    group('AppMenuBar command audit (dbOpen=$hasOpenDatabase)', () {
      testWidgets('renders every contract command in the right menu', (
        tester,
      ) async {
        final invokeLog = <String>[];
        for (final menuLabel in kMenuTopLevelOrder) {
          await tester.pumpWidget(
            _buildHost(
              native: false,
              hasOpenDatabase: hasOpenDatabase,
              invokeLog: invokeLog,
            ),
          );

          final submenu = _submenuForLabel(tester, menuLabel);
          expect(
            _menuItemFromSubmenu(submenu, 'Missing'),
            isNull,
            reason:
                'AppMenuBar must not render fallback Missing entries in "$menuLabel".',
          );

          for (final command in commandEntriesForTopLevel(menuLabel)) {
            final button = _menuItemFromSubmenu(submenu, command.label);
            expect(button, isNotNull);
            expect(
              button!.onPressed != null,
              entryEnabledState(command, hasOpenDatabase),
              reason:
                  'AppMenuBar "${command.label}" should match enabled contract in "$menuLabel".',
            );
          }
        }
      });
    });

    group('NativeAppMenuHost command audit (dbOpen=$hasOpenDatabase)', () {
      testWidgets('renders every contract command in the right menu', (
        tester,
      ) async {
        final invokeLog = <String>[];
        await tester.pumpWidget(
          _buildHost(
            native: true,
            hasOpenDatabase: hasOpenDatabase,
            invokeLog: invokeLog,
          ),
        );

        final menuBar = tester.widget<PlatformMenuBar>(
          find.byType(PlatformMenuBar),
        );
        final menus = menuBar.menus.whereType<PlatformMenu>().toList();
        for (final section in kMenuTopLevelOrder) {
          final menu = menus.firstWhere(
            (PlatformMenu item) => item.label == section,
            orElse: () =>
                throw StateError('Missing top-level platform menu "$section".'),
          );
          final commands = <String, PlatformMenuItem>{};
          _collectPlatformCommands(menu, commands);
          expect(
            commands.containsKey('Missing'),
            isFalse,
            reason:
                'NativeAppMenuHost must not render fallback Missing entries in "$section".',
          );
          final commandEntries = commandEntriesForTopLevel(section).toList();
          final renderedByLabel = <String, PlatformMenuItem>{...commands};
          for (final contractEntry in commandEntries) {
            expect(
              renderedByLabel.containsKey(contractEntry.label),
              isTrue,
              reason:
                  'Missing native command "${contractEntry.label}" in section "$section".',
            );
            expect(
              renderedByLabel[contractEntry.label]!.onSelected != null,
              entryEnabledState(contractEntry, hasOpenDatabase),
              reason:
                  'Native command "${contractEntry.label}" should match enabled contract in "$section".',
            );
          }
        }
      });
    });
  }

  testWidgets('command palette and web console state is enforced by contract', (
    tester,
  ) async {
    for (final hasOpenDatabase in <bool>[false, true]) {
      final invokeLog = <String>[];
      await tester.pumpWidget(
        _buildHost(
          native: false,
          hasOpenDatabase: hasOpenDatabase,
          invokeLog: invokeLog,
        ),
      );

      final viewSubmenu = _submenuForLabel(tester, 'View');
      final commandPaletteItem = _menuItemFromSubmenu(
        viewSubmenu,
        'Command Palette...',
      );
      expect(commandPaletteItem, isNotNull);
      expect(
        commandPaletteItem!.onPressed,
        isNotNull,
        reason:
            'Command Palette must remain enabled when command registry is active.',
      );

      final toolsSubmenu = _submenuForLabel(tester, 'Tools');
      final webConsoleItem = _menuItemFromSubmenu(
        toolsSubmenu,
        'Open Web Console',
      );
      expect(webConsoleItem, isNotNull);
      if (hasOpenDatabase) {
        expect(webConsoleItem!.onPressed, isNotNull);
      } else {
        expect(webConsoleItem!.onPressed, isNull);
      }
    }
  });

  testWidgets('deferred commands stay explicitly marked as disabled', (
    tester,
  ) async {
    final openDbCases = <bool>[false, true];
    for (final hasOpenDatabase in openDbCases) {
      final invokeLog = <String>[];
      await tester.pumpWidget(
        _buildHost(
          native: false,
          hasOpenDatabase: hasOpenDatabase,
          invokeLog: invokeLog,
        ),
      );
      for (final section in kMenuTopLevelOrder) {
        final submenu = _submenuForLabel(tester, section);
        for (final command in commandEntriesForTopLevel(section)) {
          if (!command.isDeferred) {
            continue;
          }
          final menuItem = _menuItemFromSubmenu(submenu, command.label);
          expect(menuItem, isNotNull);
          expect(
            menuItem!.onPressed,
            isNull,
            reason:
                'Deferred command "${command.label}" must stay disabled until implemented.',
          );
        }
      }
    }
  });
}
