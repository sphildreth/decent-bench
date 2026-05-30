import 'package:flutter/material.dart';

import '../../../../app/theme_system/decent_bench_theme_extension.dart';
import '../../application/menu_command_registry.dart';

class CommandToolbar extends StatelessWidget {
  const CommandToolbar({super.key, required this.registry});

  final MenuCommandRegistry registry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: tokens.toolbar.background,
        border: Border(bottom: BorderSide(color: tokens.colors.border)),
      ),
      child: Row(
        children: <Widget>[
          _toolbarButton(context, 'file_new'),
          _toolbarButton(context, 'file_open'),
          _toolbarImportMenu(context),
          _divider(context),
          _toolbarButton(
            context,
            'view_command_palette',
            labelOverride: 'Commands',
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.decentBenchTheme.colors.border,
    );
  }

  Widget _toolbarButton(
    BuildContext context,
    String commandId, {
    String? labelOverride,
  }) {
    final command = registry[commandId];
    if (command == null) {
      return const SizedBox.shrink();
    }
    final label = labelOverride ?? command.label;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        key: ValueKey<String>('command_toolbar.$commandId'),
        onPressed: command.enabled
            ? () {
                registry.invoke(commandId);
              }
            : null,
        style: _toolbarButtonStyle(context),
        icon: Icon(command.icon, size: 16),
        label: Text(label),
      ),
    );
  }

  Widget _toolbarImportMenu(BuildContext context) {
    const importCommands = <String>[
      'import_excel',
      'import_sqlite',
      'import_sql_dump',
      'import_open_wizard',
    ];
    final availableCommands = importCommands
        .map((commandId) => registry[commandId])
        .whereType<MenuCommand>()
        .toList(growable: false);
    if (availableCommands.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: PopupMenuButton<String>(
        key: const ValueKey<String>('command_toolbar.import_menu'),
        tooltip: 'Import',
        onSelected: (commandId) {
          registry.invoke(commandId);
        },
        itemBuilder: (context) {
          return <PopupMenuEntry<String>>[
            for (final command in availableCommands)
              PopupMenuItem<String>(
                value: command.id,
                enabled: command.enabled,
                child: SizedBox(
                  width: 220,
                  child: Row(
                    children: <Widget>[
                      Icon(command.icon, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          command.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ];
        },
        child: _ToolbarMenuButton(
          style: _toolbarButtonStyle(context),
          icon: Icons.file_upload_outlined,
          label: 'Import...',
        ),
      ),
    );
  }

  ButtonStyle _toolbarButtonStyle(BuildContext context) {
    final tokens = context.decentBenchTheme;
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 30)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return tokens.colors.textDisabled;
        }
        return tokens.toolbar.buttonText;
      }),
      iconColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return tokens.colors.textDisabled;
        }
        return tokens.toolbar.buttonIcon;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (states.contains(WidgetState.pressed)) {
          return tokens.toolbar.buttonActiveBackground;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return tokens.toolbar.buttonHoverBackground;
        }
        return tokens.toolbar.buttonBackground;
      }),
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    );
  }
}

class _ToolbarMenuButton extends StatelessWidget {
  const _ToolbarMenuButton({
    required this.style,
    required this.icon,
    required this.label,
  });

  final ButtonStyle style;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TextButton.icon(
        onPressed: () {},
        style: style,
        icon: Icon(icon, size: 16),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
