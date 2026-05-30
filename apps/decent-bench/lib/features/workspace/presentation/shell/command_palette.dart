import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/logging/app_logger.dart';
import '../../../../app/theme_system/decent_bench_theme.dart';
import '../../../../app/theme_system/decent_bench_theme_extension.dart';
import '../../application/menu_command_registry.dart';

class _PaletteDismissIntent extends Intent {
  const _PaletteDismissIntent();
}

class _PaletteSelectIntent extends Intent {
  const _PaletteSelectIntent();
}

class _PaletteMoveDownIntent extends Intent {
  const _PaletteMoveDownIntent();
}

class _PaletteMoveUpIntent extends Intent {
  const _PaletteMoveUpIntent();
}

class _PalettePageDownIntent extends Intent {
  const _PalettePageDownIntent();
}

class _PalettePageUpIntent extends Intent {
  const _PalettePageUpIntent();
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({
    super.key,
    required this.registry,
    required this.onDismiss,
    this.logger,
  });

  final MenuCommandRegistry registry;
  final VoidCallback onDismiss;
  final AppLogger? logger;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final AppLogger _logger;

  int _selectedIndex = 0;

  List<_PaletteEntry> get _filteredCommands {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.registry.commands
          .map((c) => _PaletteEntry(command: c, matches: const []))
          .toList();
    }
    return widget.registry.commands
        .map((c) => _PaletteEntry(
              command: c,
              matches: _fuzzyMatch(c.label, query),
            ))
        .where((e) => e.matches.isNotEmpty)
        .toList();
  }

  List<_MatchRange> _fuzzyMatch(String label, String query) {
    final lower = label.toLowerCase();
    final matches = <_MatchRange>[];
    var queryIndex = 0;
    for (var i = 0; i < lower.length && queryIndex < query.length; i++) {
      if (lower[i] == query[queryIndex]) {
        matches.add(_MatchRange(i, i + 1));
        queryIndex++;
      }
    }
    if (queryIndex < query.length) {
      return const [];
    }
    return matches;
  }

  @override
  void initState() {
    super.initState();
    _logger = widget.logger ?? const NoOpAppLogger();
    _logger.info(
      category: 'command_palette',
      operation: 'open',
      message: 'Command palette opened.',
      details: <String, Object?>{'command_count': widget.registry.commands.length},
    );
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _executeCommand(_PaletteEntry entry) {
    if (!entry.command.enabled) {
      _logger.debug(
        category: 'command_palette',
        operation: 'execute_blocked',
        message: 'Attempted to execute disabled command.',
        details: <String, Object?>{'command_id': entry.command.id},
      );
      return;
    }
    _logger.info(
      category: 'command_palette',
      operation: 'execute',
      message: 'Executed command from palette.',
      details: <String, Object?>{
        'command_id': entry.command.id,
        'command_label': entry.command.label,
      },
    );
    widget.registry.invoke(entry.command.id);
    widget.onDismiss();
  }

  void _executeSelected() {
    final commands = _filteredCommands;
    if (_selectedIndex >= 0 && _selectedIndex < commands.length) {
      _executeCommand(commands[_selectedIndex]);
    }
  }

  void _moveDown() {
    final commands = _filteredCommands;
    if (commands.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex + 1).clamp(0, commands.length - 1);
    });
    _scrollToSelected();
  }

  void _moveUp() {
    final commands = _filteredCommands;
    if (commands.isEmpty) return;
    setState(() {
      _selectedIndex = (_selectedIndex - 1).clamp(0, commands.length - 1);
    });
    _scrollToSelected();
  }

  void _pageDown() {
    final commands = _filteredCommands;
    if (commands.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + 10).clamp(0, commands.length - 1);
    });
    _scrollToSelected();
  }

  void _pageUp() {
    final commands = _filteredCommands;
    if (commands.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex - 10).clamp(0, commands.length - 1);
    });
    _scrollToSelected();
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final itemHeight = 42.0;
      final viewportHeight = _scrollController.position.viewportDimension;
      final targetOffset = _selectedIndex * itemHeight;
      final currentOffset = _scrollController.offset;
      if (targetOffset < currentOffset) {
        _scrollController.jumpTo(targetOffset);
      } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
        _scrollController.jumpTo(
          (targetOffset + itemHeight - viewportHeight).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.decentBenchTheme;
    final commands = _filteredCommands;

    _selectedIndex = commands.isEmpty
        ? 0
        : _selectedIndex.clamp(0, commands.length - 1);

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.translucent,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.arrowDown):
                    _PaletteMoveDownIntent(),
                SingleActivator(LogicalKeyboardKey.arrowUp):
                    _PaletteMoveUpIntent(),
                SingleActivator(LogicalKeyboardKey.enter):
                    _PaletteSelectIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter):
                    _PaletteSelectIntent(),
                SingleActivator(LogicalKeyboardKey.escape):
                    _PaletteDismissIntent(),
                SingleActivator(LogicalKeyboardKey.pageDown):
                    _PalettePageDownIntent(),
                SingleActivator(LogicalKeyboardKey.pageUp):
                    _PalettePageUpIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _PaletteDismissIntent: CallbackAction<_PaletteDismissIntent>(
                    onInvoke: (_) => widget.onDismiss(),
                  ),
                  _PaletteSelectIntent: CallbackAction<_PaletteSelectIntent>(
                    onInvoke: (_) => _executeSelected(),
                  ),
                  _PaletteMoveDownIntent:
                      CallbackAction<_PaletteMoveDownIntent>(
                    onInvoke: (_) => _moveDown(),
                  ),
                  _PaletteMoveUpIntent: CallbackAction<_PaletteMoveUpIntent>(
                    onInvoke: (_) => _moveUp(),
                  ),
                  _PalettePageDownIntent:
                      CallbackAction<_PalettePageDownIntent>(
                    onInvoke: (_) => _pageDown(),
                  ),
                  _PalettePageUpIntent: CallbackAction<_PalettePageUpIntent>(
                    onInvoke: (_) => _pageUp(),
                  ),
                },
                child: Container(
                  width: 600,
                  constraints: const BoxConstraints(maxHeight: 480),
                  decoration: BoxDecoration(
                    color: tokens.dialog.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.colors.borderStrong),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: SizedBox(
                          child: TextField(
                            focusNode: _searchFocusNode,
                            controller: _searchController,
                            onChanged: (_) =>
                                setState(() => _selectedIndex = 0),
                            style: TextStyle(
                              fontSize: tokens.fonts.uiSize + 2,
                              fontFamily: tokens.fonts.uiFamily,
                              color: tokens.dialog.titleText,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a command...',
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  right: 6,
                                ),
                                child: Icon(
                                  Icons.search,
                                  size: 18,
                                  color: tokens.colors.textMuted,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              filled: false,
                            ),
                            cursorColor: tokens.editor.cursor,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: tokens.colors.border),
                      Flexible(
                        child: commands.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _searchController.text.trim().isEmpty
                                      ? 'Type to search commands'
                                      : 'No matching commands',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.colors.textMuted,
                                    fontSize: tokens.fonts.uiSize,
                                  ),
                                ),
                              )
                            : Scrollbar(
                                controller: _scrollController,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  itemCount: commands.length,
                                  itemBuilder: (context, index) {
                                    return _CommandListItem(
                                      entry: commands[index],
                                      isSelected: index == _selectedIndex,
                                      tokens: tokens,
                                      onTap: () =>
                                          _executeCommand(commands[index]),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteEntry {
  const _PaletteEntry({required this.command, required this.matches});

  final MenuCommand command;
  final List<_MatchRange> matches;
}

class _MatchRange {
  const _MatchRange(this.start, this.end);

  final int start;
  final int end;
}

class _CommandListItem extends StatelessWidget {
  const _CommandListItem({
    required this.entry,
    required this.isSelected,
    required this.tokens,
    required this.onTap,
  });

  final _PaletteEntry entry;
  final bool isSelected;
  final DecentBenchTheme tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final command = entry.command;
    final backgroundColor = isSelected
        ? tokens.menu.itemActiveBackground
        : Colors.transparent;

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: command.enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 28,
                child: Icon(command.icon, size: 16, color: tokens.menu.icon),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  _buildHighlightedLabel(command.label, entry.matches),
                  style: TextStyle(
                    fontSize: tokens.fonts.uiSize,
                    color: command.enabled
                        ? tokens.menu.text
                        : tokens.colors.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (command.shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.menu.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tokens.colors.border),
                  ),
                  child: Text(
                    command.shortcut!.displayLabel,
                    style: TextStyle(
                      fontSize: tokens.fonts.uiSize - 2,
                      fontFamily: 'monospace',
                      color: tokens.menu.shortcut,
                    ),
                  ),
                ),
              if (!command.enabled) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'unavailable',
                    style: TextStyle(
                      fontSize: tokens.fonts.uiSize - 1,
                      color: tokens.colors.textDisabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InlineSpan _buildHighlightedLabel(
    String label,
    List<_MatchRange> matches,
  ) {
    if (matches.isEmpty) {
      return TextSpan(text: label);
    }
    final spans = <InlineSpan>[];
    var current = 0;
    for (final match in matches) {
      if (match.start > current) {
        spans.add(TextSpan(text: label.substring(current, match.start)));
      }
      spans.add(
        TextSpan(
          text: label.substring(match.start, match.end),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: tokens.colors.accent,
          ),
        ),
      );
      current = match.end;
    }
    if (current < label.length) {
      spans.add(TextSpan(text: label.substring(current)));
    }
    return TextSpan(children: spans);
  }
}
