import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/schema_relationship_export.dart';
import '../../domain/schema_relationship_graph.dart';
import '../../domain/schema_relationship_layout.dart';
import '../../domain/workspace_models.dart';
import 'shell_pane_frame.dart';

class SchemaRelationshipDiagram extends StatefulWidget {
  const SchemaRelationshipDiagram({
    super.key,
    required this.schema,
    required this.databaseLabel,
    required this.selectedTableName,
    required this.onSelectTable,
    required this.onOpenTable,
    required this.isLoading,
  });

  final SchemaSnapshot schema;
  final String databaseLabel;
  final String? selectedTableName;
  final ValueChanged<String> onSelectTable;
  final Future<void> Function(String tableName) onOpenTable;
  final bool isLoading;

  @override
  State<SchemaRelationshipDiagram> createState() =>
      SchemaRelationshipDiagramState();
}

class SchemaRelationshipDiagramState extends State<SchemaRelationshipDiagram> {
  static const XTypeGroup _pngTypeGroup = XTypeGroup(
    label: 'PNG',
    extensions: <String>['png'],
  );
  static const XTypeGroup _jpegTypeGroup = XTypeGroup(
    label: 'JPEG',
    extensions: <String>['jpg', 'jpeg'],
  );

  final TransformationController _transformationController =
      TransformationController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _viewerKey = GlobalKey();

  bool _showIsolatedTables = true;
  bool _neighborhoodMode = false;
  bool _exporting = false;
  String _search = '';
  SchemaRelationshipGraph? _lastGraph;
  SchemaRelationshipLayout? _lastLayout;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> exportImageFromCommand() async {
    await _showExportDialog();
  }

  void _handleSearchChanged() {
    final next = _searchController.text;
    if (next == _search) {
      return;
    }
    setState(() {
      _search = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final graph = SchemaRelationshipGraph.fromSnapshot(widget.schema);
    _lastGraph = graph;
    return ShellPaneFrame(
      title: 'ER Diagram',
      subtitle: widget.databaseLabel,
      leadingIcon: Icons.account_tree_outlined,
      padding: EdgeInsets.zero,
      actions: <Widget>[
        IconButton(
          tooltip: 'Zoom to fit',
          onPressed: _lastLayout == null ? null : _zoomToFit,
          icon: const Icon(Icons.fit_screen_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Export image',
          onPressed: _exporting ? null : _showExportDialog,
          icon: _exporting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined, size: 18),
        ),
      ],
      child: widget.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : graph.nodes.isEmpty
          ? const _DiagramStateMessage(
              icon: Icons.account_tree_outlined,
              title: 'No tables',
              message: 'Open a database with tables to view relationships.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final density = _densityForWidth(constraints.maxWidth);
                final includedTables = _includedTablesForSearch(graph, density);
                final layout = SchemaRelationshipLayout.compute(
                  graph,
                  options: SchemaRelationshipLayoutOptions(
                    mode: _neighborhoodMode
                        ? SchemaRelationshipLayoutMode.selectedTableNeighborhood
                        : SchemaRelationshipLayoutMode.allTables,
                    selectedTableName: widget.selectedTableName,
                    includedTableNames: includedTables,
                    showIsolatedTables: _showIsolatedTables,
                    nodeHeight: _nodeHeightForDensity(density),
                  ),
                );
                _lastLayout = layout;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _DiagramToolbar(
                      searchController: _searchController,
                      showIsolatedTables: _showIsolatedTables,
                      neighborhoodMode: _neighborhoodMode,
                      neighborhoodEnabled: widget.selectedTableName != null,
                      onShowIsolatedChanged: (value) {
                        setState(() => _showIsolatedTables = value);
                      },
                      onNeighborhoodChanged: widget.selectedTableName == null
                          ? null
                          : (value) {
                              setState(() => _neighborhoodMode = value);
                            },
                      onZoomToFit: _zoomToFit,
                    ),
                    if (graph.edges.isEmpty)
                      const _DiagramNotice(
                        message:
                            'No foreign-key relationships are exposed for this schema.',
                      ),
                    Expanded(
                      child: _buildInteractiveDiagram(
                        context: context,
                        graph: graph,
                        layout: layout,
                        density: density,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildInteractiveDiagram({
    required BuildContext context,
    required SchemaRelationshipGraph graph,
    required SchemaRelationshipLayout layout,
    required _DiagramDensity density,
  }) {
    if (layout.nodes.isEmpty) {
      return const _DiagramStateMessage(
        icon: Icons.search_off_outlined,
        title: 'No matching tables',
        message: 'Adjust search or diagram filters.',
      );
    }

    final nodeByName = <String, SchemaRelationshipNode>{
      for (final node in graph.nodes) node.tableName: node,
    };
    final canvasWidth = math.max(320.0, layout.canvasBounds.right);
    final canvasHeight = math.max(240.0, layout.canvasBounds.bottom);
    return ClipRect(
      child: InteractiveViewer(
        key: _viewerKey,
        transformationController: _transformationController,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(600),
        minScale: 0.2,
        maxScale: 2.5,
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _RelationshipEdgePainter(
                    graph: graph,
                    layout: layout,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              ),
              for (final nodeLayout in layout.nodes)
                Positioned(
                  left: nodeLayout.bounds.left,
                  top: nodeLayout.bounds.top,
                  width: nodeLayout.bounds.width,
                  height: nodeLayout.bounds.height,
                  child: _RelationshipNodeCard(
                    key: ValueKey<String>('erd.node.${nodeLayout.tableName}'),
                    node: nodeByName[nodeLayout.tableName]!,
                    visibleColumns: _visibleColumnsForNode(
                      nodeByName[nodeLayout.tableName]!,
                      density,
                    ),
                    selected: widget.selectedTableName == nodeLayout.tableName,
                    density: density,
                    onSelect: () {
                      widget.onSelectTable(nodeLayout.tableName);
                    },
                    onOpen: () {
                      widget.onOpenTable(nodeLayout.tableName);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Set<String>? _includedTablesForSearch(
    SchemaRelationshipGraph graph,
    _DiagramDensity density,
  ) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) {
      return null;
    }
    final matches = <String>{};
    for (final node in graph.nodes) {
      if (node.tableName.toLowerCase().contains(query)) {
        matches.add(node.tableName);
        continue;
      }
      final visibleColumns = _visibleColumnsForNode(node, density);
      if (visibleColumns.any(
        (column) => column.name.toLowerCase().contains(query),
      )) {
        matches.add(node.tableName);
      }
    }
    final withNeighbors = <String>{...matches};
    for (final table in matches) {
      withNeighbors.addAll(graph.directlyConnectedTables(table));
    }
    return withNeighbors;
  }

  List<SchemaColumn> _visibleColumnsForNode(
    SchemaRelationshipNode node,
    _DiagramDensity density,
  ) {
    if (density == _DiagramDensity.narrow || node.isPlaceholder) {
      return const <SchemaColumn>[];
    }
    if (density == _DiagramDensity.medium) {
      final keyColumns = node.columns
          .where((column) => column.primaryKey || column.hasForeignKey)
          .toList();
      return (keyColumns.isEmpty ? node.columns : keyColumns)
          .take(3)
          .toList(growable: false);
    }
    return node.columns.take(6).toList(growable: false);
  }

  _DiagramDensity _densityForWidth(double width) {
    if (width >= 520) {
      return _DiagramDensity.wide;
    }
    if (width >= 340) {
      return _DiagramDensity.medium;
    }
    return _DiagramDensity.narrow;
  }

  double _nodeHeightForDensity(_DiagramDensity density) {
    return switch (density) {
      _DiagramDensity.wide => 150,
      _DiagramDensity.medium => 112,
      _DiagramDensity.narrow => 64,
    };
  }

  void _zoomToFit() {
    final layout = _lastLayout;
    if (layout == null || !_viewerKey.currentContext!.mounted) {
      return;
    }
    final box = _viewerKey.currentContext!.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) {
      return;
    }
    final bounds = layout.canvasBounds;
    final scale = math
        .min(
          box.size.width / math.max(1, bounds.width),
          box.size.height / math.max(1, bounds.height),
        )
        .clamp(0.2, 2.5);
    final x = (box.size.width - bounds.width * scale) / 2 - bounds.left * scale;
    final y =
        (box.size.height - bounds.height * scale) / 2 - bounds.top * scale;
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  SchemaRelationshipRect? _viewportSceneBounds() {
    final context = _viewerKey.currentContext;
    if (context == null) {
      return null;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) {
      return null;
    }
    final topLeft = _transformationController.toScene(Offset.zero);
    final bottomRight = _transformationController.toScene(
      Offset(box.size.width, box.size.height),
    );
    final left = math.min(topLeft.dx, bottomRight.dx);
    final top = math.min(topLeft.dy, bottomRight.dy);
    return SchemaRelationshipRect(
      left: left,
      top: top,
      width: (bottomRight.dx - topLeft.dx).abs(),
      height: (bottomRight.dy - topLeft.dy).abs(),
    );
  }

  Future<void> _showExportDialog() async {
    final graph = _lastGraph;
    final layout = _lastLayout;
    if (graph == null || layout == null || _exporting) {
      return;
    }
    final options = await showDialog<SchemaRelationshipExportOptions>(
      context: context,
      builder: (context) => const _ExportImageDialog(),
    );
    if (options == null || !mounted) {
      return;
    }
    final saveLocation = await getSaveLocation(
      suggestedName: 'decent-bench-erd.${options.extension}',
      acceptedTypeGroups: options.format == SchemaRelationshipImageFormat.png
          ? const <XTypeGroup>[_pngTypeGroup]
          : const <XTypeGroup>[_jpegTypeGroup],
    );
    if (saveLocation == null || !mounted) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final title = schemaRelationshipExportTitle(
        databaseLabel: widget.databaseLabel,
        tableCount: graph.nodes.where((node) => !node.isPlaceholder).length,
        relationshipCount: graph.edges.length,
      );
      final rendered = await const SchemaRelationshipExportRenderer().render(
        graph: graph,
        layout: layout,
        options: options,
        title: title,
        viewportBounds: _viewportSceneBounds(),
        backgroundColor: Theme.of(context).colorScheme.surface,
      );
      await File(saveLocation.path).writeAsBytes(rendered.bytes);
      if (!mounted) {
        return;
      }
      final message = rendered.plan.message ?? 'ERD image exported.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on SchemaRelationshipExportException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }
}

enum _DiagramDensity { wide, medium, narrow }

class _DiagramToolbar extends StatelessWidget {
  const _DiagramToolbar({
    required this.searchController,
    required this.showIsolatedTables,
    required this.neighborhoodMode,
    required this.neighborhoodEnabled,
    required this.onShowIsolatedChanged,
    required this.onNeighborhoodChanged,
    required this.onZoomToFit,
  });

  final TextEditingController searchController;
  final bool showIsolatedTables;
  final bool neighborhoodMode;
  final bool neighborhoodEnabled;
  final ValueChanged<bool> onShowIsolatedChanged;
  final ValueChanged<bool>? onNeighborhoodChanged;
  final VoidCallback onZoomToFit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 220,
            child: TextField(
              key: const ValueKey<String>('erd.search'),
              controller: searchController,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                hintText: 'Search tables',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          Tooltip(
            message: 'Show isolated tables',
            child: FilterChip(
              selected: showIsolatedTables,
              avatar: const Icon(Icons.scatter_plot_outlined, size: 16),
              label: const Text('Isolated'),
              onSelected: onShowIsolatedChanged,
            ),
          ),
          Tooltip(
            message: 'Show selected table neighborhood',
            child: FilterChip(
              selected: neighborhoodMode,
              avatar: const Icon(Icons.hub_outlined, size: 16),
              label: const Text('Neighbors'),
              onSelected: neighborhoodEnabled ? onNeighborhoodChanged : null,
            ),
          ),
          IconButton(
            tooltip: 'Zoom to fit',
            onPressed: onZoomToFit,
            icon: const Icon(Icons.fit_screen_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RelationshipNodeCard extends StatefulWidget {
  const _RelationshipNodeCard({
    super.key,
    required this.node,
    required this.visibleColumns,
    required this.selected,
    required this.density,
    required this.onSelect,
    required this.onOpen,
  });

  final SchemaRelationshipNode node;
  final List<SchemaColumn> visibleColumns;
  final bool selected;
  final _DiagramDensity density;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  State<_RelationshipNodeCard> createState() => _RelationshipNodeCardState();
}

class _RelationshipNodeCardState extends State<_RelationshipNodeCard> {
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'erd-${widget.node.tableName}',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = widget.node.isPlaceholder
        ? colorScheme.error
        : widget.selected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (focusNode, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          widget.onOpen();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return Tooltip(
            message: widget.node.isPlaceholder
                ? 'Referenced table ${widget.node.tableName} is missing'
                : 'Open table preview for ${widget.node.tableName}',
            child: Material(
              color: widget.node.isPlaceholder
                  ? colorScheme.errorContainer.withValues(alpha: 0.24)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _focusNode.requestFocus();
                  widget.onSelect();
                },
                onDoubleTap: widget.onOpen,
                child: CustomPaint(
                  foregroundPainter: widget.node.isPlaceholder
                      ? _DashedBorderPainter(color: borderColor)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: widget.node.isPlaceholder
                          ? null
                          : Border.all(
                              color: focused
                                  ? colorScheme.primary
                                  : borderColor,
                              width: widget.selected || focused ? 2 : 1,
                            ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              widget.node.isPlaceholder
                                  ? Icons.warning_amber_outlined
                                  : Icons.table_rows_outlined,
                              size: 16,
                              color: widget.node.isPlaceholder
                                  ? colorScheme.error
                                  : colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.node.tableName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        if (widget.density !=
                            _DiagramDensity.narrow) ...<Widget>[
                          const SizedBox(height: 6),
                          for (final column in widget.visibleColumns)
                            Text(
                              _columnLabel(column),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: column.hasForeignKey
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          if (widget.node.columns.length >
                              widget.visibleColumns.length)
                            Text(
                              '+${widget.node.columns.length - widget.visibleColumns.length} more',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RelationshipEdgePainter extends CustomPainter {
  const _RelationshipEdgePainter({
    required this.graph,
    required this.layout,
    required this.colorScheme,
  });

  final SchemaRelationshipGraph graph;
  final SchemaRelationshipLayout layout;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final edgeById = <String, SchemaRelationshipEdge>{
      for (final edge in graph.edges) edge.id: edge,
    };
    for (final route in layout.edges) {
      final edge = edgeById[route.edgeId];
      if (edge == null || route.points.length < 2) {
        continue;
      }
      final color = edge.hasMissingParent
          ? colorScheme.error
          : colorScheme.outline;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke;
      for (var index = 0; index < route.points.length - 1; index++) {
        final start = _offset(route.points[index]);
        final end = _offset(route.points[index + 1]);
        if (edge.hasMissingParent) {
          _drawDashedLine(canvas, start, end, paint);
        } else {
          canvas.drawLine(start, end, paint);
        }
      }
      _drawArrowhead(canvas, route.points, color);
    }
  }

  @override
  bool shouldRepaint(covariant _RelationshipEdgePainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.layout != layout ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final rect = Offset.zero & size;
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DiagramNotice extends StatelessWidget {
  const _DiagramNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _DiagramStateMessage extends StatelessWidget {
  const _DiagramStateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportImageDialog extends StatefulWidget {
  const _ExportImageDialog();

  @override
  State<_ExportImageDialog> createState() => _ExportImageDialogState();
}

class _ExportImageDialogState extends State<_ExportImageDialog> {
  SchemaRelationshipImageFormat _format = SchemaRelationshipImageFormat.png;
  SchemaRelationshipExportScope _scope =
      SchemaRelationshipExportScope.fullDiagram;
  double _scale = 2;
  bool _transparentPng = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export ERD Image'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SegmentedButton<SchemaRelationshipImageFormat>(
              segments: const <ButtonSegment<SchemaRelationshipImageFormat>>[
                ButtonSegment(
                  value: SchemaRelationshipImageFormat.png,
                  icon: Icon(Icons.image_outlined),
                  label: Text('PNG'),
                ),
                ButtonSegment(
                  value: SchemaRelationshipImageFormat.jpeg,
                  icon: Icon(Icons.photo_outlined),
                  label: Text('JPG'),
                ),
              ],
              selected: <SchemaRelationshipImageFormat>{_format},
              onSelectionChanged: (value) {
                setState(() => _format = value.single);
              },
            ),
            const SizedBox(height: 14),
            SegmentedButton<SchemaRelationshipExportScope>(
              segments: const <ButtonSegment<SchemaRelationshipExportScope>>[
                ButtonSegment(
                  value: SchemaRelationshipExportScope.fullDiagram,
                  icon: Icon(Icons.account_tree_outlined),
                  label: Text('Full'),
                ),
                ButtonSegment(
                  value: SchemaRelationshipExportScope.viewport,
                  icon: Icon(Icons.crop_free_outlined),
                  label: Text('Viewport'),
                ),
              ],
              selected: <SchemaRelationshipExportScope>{_scope},
              onSelectionChanged: (value) {
                setState(() => _scope = value.single);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<double>(
              initialValue: _scale,
              decoration: const InputDecoration(labelText: 'Scale'),
              items: const <DropdownMenuItem<double>>[
                DropdownMenuItem<double>(value: 1, child: Text('1x')),
                DropdownMenuItem<double>(value: 2, child: Text('2x')),
                DropdownMenuItem<double>(value: 3, child: Text('3x')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _scale = value);
                }
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value:
                  _format == SchemaRelationshipImageFormat.png &&
                  _transparentPng,
              onChanged: _format == SchemaRelationshipImageFormat.png
                  ? (value) {
                      setState(() => _transparentPng = value ?? false);
                    }
                  : null,
              title: const Text('Transparent PNG background'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              SchemaRelationshipExportOptions(
                format: _format,
                scope: _scope,
                requestedScale: _scale,
                transparentPng:
                    _format == SchemaRelationshipImageFormat.png &&
                    _transparentPng,
              ),
            );
          },
          icon: const Icon(Icons.image_outlined),
          label: const Text('Export'),
        ),
      ],
    );
  }
}

String _columnLabel(SchemaColumn column) {
  final flags = <String>[
    if (column.primaryKey) 'PK',
    if (column.hasForeignKey) 'FK',
  ];
  return '${column.name}  ${column.type}${flags.isEmpty ? '' : ' ${flags.join('/')}'}';
}

void _drawArrowhead(
  Canvas canvas,
  List<SchemaRelationshipPoint> points,
  Color color,
) {
  if (points.length < 2) {
    return;
  }
  final end = points.last;
  final previous = points[points.length - 2];
  final angle = math.atan2(end.y - previous.y, end.x - previous.x);
  const size = 7.0;
  final path = Path()
    ..moveTo(end.x, end.y)
    ..lineTo(
      end.x - size * math.cos(angle - math.pi / 6),
      end.y - size * math.sin(angle - math.pi / 6),
    )
    ..lineTo(
      end.x - size * math.cos(angle + math.pi / 6),
      end.y - size * math.sin(angle + math.pi / 6),
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 7.0;
  const gap = 5.0;
  final delta = end - start;
  final distance = delta.distance;
  if (distance == 0) {
    return;
  }
  final direction = delta / distance;
  var current = 0.0;
  while (current < distance) {
    final segmentEnd = math.min(current + dash, distance);
    canvas.drawLine(
      start + direction * current,
      start + direction * segmentEnd,
      paint,
    );
    current += dash + gap;
  }
}

Offset _offset(SchemaRelationshipPoint point) {
  return Offset(point.x, point.y);
}
