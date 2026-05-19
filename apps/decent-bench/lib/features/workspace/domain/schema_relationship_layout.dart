import 'dart:math' as math;

import 'schema_relationship_graph.dart';

enum SchemaRelationshipLayoutMode { allTables, selectedTableNeighborhood }

class SchemaRelationshipLayoutOptions {
  const SchemaRelationshipLayoutOptions({
    this.mode = SchemaRelationshipLayoutMode.allTables,
    this.selectedTableName,
    this.includedTableNames,
    this.showIsolatedTables = true,
    this.nodeWidth = 240,
    this.nodeHeight = 138,
    this.padding = 32,
    this.rankSpacing = 120,
    this.nodeSpacing = 56,
    this.componentSpacing = 96,
  });

  final SchemaRelationshipLayoutMode mode;
  final String? selectedTableName;
  final Set<String>? includedTableNames;
  final bool showIsolatedTables;
  final double nodeWidth;
  final double nodeHeight;
  final double padding;
  final double rankSpacing;
  final double nodeSpacing;
  final double componentSpacing;
}

class SchemaRelationshipLayout {
  const SchemaRelationshipLayout({
    required this.nodes,
    required this.edges,
    required this.canvasBounds,
  });

  final List<SchemaRelationshipNodeLayout> nodes;
  final List<SchemaRelationshipEdgeRoute> edges;
  final SchemaRelationshipRect canvasBounds;

  Set<String> get visibleTableNames => <String>{
    for (final node in nodes) node.tableName,
  };

  SchemaRelationshipNodeLayout? nodeLayoutForTable(String tableName) {
    for (final node in nodes) {
      if (node.tableName == tableName) {
        return node;
      }
    }
    return null;
  }

  SchemaRelationshipEdgeRoute? routeForEdge(String edgeId) {
    for (final edge in edges) {
      if (edge.edgeId == edgeId) {
        return edge;
      }
    }
    return null;
  }

  static SchemaRelationshipLayout compute(
    SchemaRelationshipGraph graph, {
    SchemaRelationshipLayoutOptions options =
        const SchemaRelationshipLayoutOptions(),
  }) {
    final visibleTables = _visibleTableNames(graph, options);
    final visibleNodes =
        graph.nodes
            .where((node) => visibleTables.contains(node.tableName))
            .toList()
          ..sort((left, right) => left.tableName.compareTo(right.tableName));
    final visibleEdges =
        graph.edges
            .where(
              (edge) =>
                  visibleTables.contains(edge.childTable) &&
                  visibleTables.contains(edge.parentTable),
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));

    if (visibleNodes.isEmpty) {
      final size = options.padding * 2;
      return SchemaRelationshipLayout(
        nodes: const <SchemaRelationshipNodeLayout>[],
        edges: const <SchemaRelationshipEdgeRoute>[],
        canvasBounds: SchemaRelationshipRect(
          left: 0,
          top: 0,
          width: size,
          height: size,
        ),
      );
    }

    final components = _connectedComponents(visibleNodes, visibleEdges);
    final isolatedComponents = <List<String>>[];
    final relatedComponents = <List<String>>[];
    for (final component in components) {
      final hasVisibleEdge = visibleEdges.any(
        (edge) =>
            component.contains(edge.childTable) ||
            component.contains(edge.parentTable),
      );
      if (hasVisibleEdge) {
        relatedComponents.add(component);
      } else {
        isolatedComponents.add(component);
      }
    }

    final layouts = <String, SchemaRelationshipNodeLayout>{};
    var y = options.padding;
    var maxRight = options.padding;

    for (final component in relatedComponents) {
      final bounds = _layoutConnectedComponent(
        component: component,
        edges: visibleEdges
            .where(
              (edge) =>
                  component.contains(edge.childTable) &&
                  component.contains(edge.parentTable),
            )
            .toList(),
        originX: options.padding,
        originY: y,
        options: options,
        layouts: layouts,
      );
      y = bounds.bottom + options.componentSpacing;
      maxRight = math.max(maxRight, bounds.right);
    }

    if (isolatedComponents.isNotEmpty) {
      final isolatedTables = <String>[
        for (final component in isolatedComponents) ...component,
      ]..sort();
      final bounds = _layoutGrid(
        tables: isolatedTables,
        originX: options.padding,
        originY: y,
        options: options,
        layouts: layouts,
      );
      y = bounds.bottom;
      maxRight = math.max(maxRight, bounds.right);
    }

    final edgeRoutes = <SchemaRelationshipEdgeRoute>[
      for (final edge in visibleEdges)
        _routeEdge(edge: edge, layouts: layouts, loopMargin: 42),
    ]..sort((left, right) => left.edgeId.compareTo(right.edgeId));

    final canvasBounds = _canvasBounds(
      nodeLayouts: layouts.values,
      edgeRoutes: edgeRoutes,
      padding: options.padding,
      fallbackRight: maxRight,
      fallbackBottom: y,
    );

    return SchemaRelationshipLayout(
      nodes: List<SchemaRelationshipNodeLayout>.unmodifiable(
        layouts.values.toList()
          ..sort((left, right) => left.tableName.compareTo(right.tableName)),
      ),
      edges: List<SchemaRelationshipEdgeRoute>.unmodifiable(edgeRoutes),
      canvasBounds: canvasBounds,
    );
  }
}

class SchemaRelationshipNodeLayout {
  const SchemaRelationshipNodeLayout({
    required this.tableName,
    required this.bounds,
  });

  final String tableName;
  final SchemaRelationshipRect bounds;
}

class SchemaRelationshipEdgeRoute {
  const SchemaRelationshipEdgeRoute({
    required this.edgeId,
    required this.childTable,
    required this.parentTable,
    required this.points,
    required this.isSelfReference,
    required this.hasMissingParent,
  });

  final String edgeId;
  final String childTable;
  final String parentTable;
  final List<SchemaRelationshipPoint> points;
  final bool isSelfReference;
  final bool hasMissingParent;
}

class SchemaRelationshipPoint {
  const SchemaRelationshipPoint(this.x, this.y);

  final double x;
  final double y;
}

class SchemaRelationshipRect {
  const SchemaRelationshipRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  SchemaRelationshipRect inflate(double delta) {
    return SchemaRelationshipRect(
      left: left - delta,
      top: top - delta,
      width: width + delta * 2,
      height: height + delta * 2,
    );
  }
}

Set<String> _visibleTableNames(
  SchemaRelationshipGraph graph,
  SchemaRelationshipLayoutOptions options,
) {
  var tables = <String>{for (final node in graph.nodes) node.tableName};
  if (options.mode == SchemaRelationshipLayoutMode.selectedTableNeighborhood &&
      options.selectedTableName != null &&
      graph.nodeByTable(options.selectedTableName!) != null) {
    tables = <String>{
      options.selectedTableName!,
      ...graph.directlyConnectedTables(options.selectedTableName!),
    };
  }
  final included = options.includedTableNames;
  if (included != null) {
    tables = tables.intersection(included);
  }
  if (!options.showIsolatedTables) {
    tables = tables
        .where(
          (tableName) =>
              graph.nodeByTable(tableName)?.isIsolated == false ||
              tableName == options.selectedTableName,
        )
        .toSet();
  }
  return tables;
}

List<List<String>> _connectedComponents(
  List<SchemaRelationshipNode> nodes,
  List<SchemaRelationshipEdge> edges,
) {
  final adjacency = <String, Set<String>>{
    for (final node in nodes) node.tableName: <String>{},
  };
  for (final edge in edges) {
    adjacency[edge.childTable]?.add(edge.parentTable);
    adjacency[edge.parentTable]?.add(edge.childTable);
  }

  final visited = <String>{};
  final components = <List<String>>[];
  for (final node in nodes) {
    if (!visited.add(node.tableName)) {
      continue;
    }
    final queue = <String>[node.tableName];
    final component = <String>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      component.add(current);
      final neighbors = adjacency[current]?.toList() ?? const <String>[];
      neighbors.sort();
      for (final neighbor in neighbors) {
        if (visited.add(neighbor)) {
          queue.add(neighbor);
        }
      }
    }
    component.sort();
    components.add(component);
  }
  components.sort((left, right) => left.first.compareTo(right.first));
  return components;
}

SchemaRelationshipRect _layoutConnectedComponent({
  required List<String> component,
  required List<SchemaRelationshipEdge> edges,
  required double originX,
  required double originY,
  required SchemaRelationshipLayoutOptions options,
  required Map<String, SchemaRelationshipNodeLayout> layouts,
}) {
  if (_hasCycle(component, edges)) {
    return _layoutGrid(
      tables: component,
      originX: originX,
      originY: originY,
      options: options,
      layouts: layouts,
    );
  }

  final ranks = _rankDag(component, edges);
  final rankValues = ranks.values.toList()..sort();
  final maxRank = rankValues.isEmpty ? 0 : rankValues.last;
  final boundsByRank = <int, List<String>>{
    for (var rank = 0; rank <= maxRank; rank++)
      rank: component.where((table) => ranks[table] == rank).toList()..sort(),
  };

  var maxRows = 1;
  for (final tables in boundsByRank.values) {
    maxRows = math.max(maxRows, tables.length);
  }
  for (final entry in boundsByRank.entries) {
    final rank = entry.key;
    final tables = entry.value;
    for (var index = 0; index < tables.length; index++) {
      final x = originX + rank * (options.nodeWidth + options.rankSpacing);
      final y = originY + index * (options.nodeHeight + options.nodeSpacing);
      layouts[tables[index]] = SchemaRelationshipNodeLayout(
        tableName: tables[index],
        bounds: SchemaRelationshipRect(
          left: x,
          top: y,
          width: options.nodeWidth,
          height: options.nodeHeight,
        ),
      );
    }
  }

  return SchemaRelationshipRect(
    left: originX,
    top: originY,
    width: (maxRank + 1) * options.nodeWidth + maxRank * options.rankSpacing,
    height: maxRows * options.nodeHeight + (maxRows - 1) * options.nodeSpacing,
  );
}

SchemaRelationshipRect _layoutGrid({
  required List<String> tables,
  required double originX,
  required double originY,
  required SchemaRelationshipLayoutOptions options,
  required Map<String, SchemaRelationshipNodeLayout> layouts,
}) {
  final sortedTables = tables.toList()..sort();
  final columns = math.max(
    1,
    math.min(3, math.sqrt(sortedTables.length).ceil()),
  );
  final rows = (sortedTables.length / columns).ceil();
  for (var index = 0; index < sortedTables.length; index++) {
    final column = index % columns;
    final row = index ~/ columns;
    final x = originX + column * (options.nodeWidth + options.rankSpacing);
    final y = originY + row * (options.nodeHeight + options.nodeSpacing);
    layouts[sortedTables[index]] = SchemaRelationshipNodeLayout(
      tableName: sortedTables[index],
      bounds: SchemaRelationshipRect(
        left: x,
        top: y,
        width: options.nodeWidth,
        height: options.nodeHeight,
      ),
    );
  }
  return SchemaRelationshipRect(
    left: originX,
    top: originY,
    width: columns * options.nodeWidth + (columns - 1) * options.rankSpacing,
    height: rows * options.nodeHeight + (rows - 1) * options.nodeSpacing,
  );
}

Map<String, int> _rankDag(
  List<String> component,
  List<SchemaRelationshipEdge> edges,
) {
  final ranks = <String, int>{for (final table in component) table: 0};
  final childrenByParent = <String, List<String>>{
    for (final table in component) table: <String>[],
  };
  final indegree = <String, int>{for (final table in component) table: 0};
  for (final edge in edges) {
    childrenByParent[edge.parentTable]?.add(edge.childTable);
    indegree[edge.childTable] = (indegree[edge.childTable] ?? 0) + 1;
  }
  for (final children in childrenByParent.values) {
    children.sort();
  }

  final queue = component.where((table) => indegree[table] == 0).toList()
    ..sort();
  while (queue.isNotEmpty) {
    final parent = queue.removeAt(0);
    for (final child in childrenByParent[parent] ?? const <String>[]) {
      ranks[child] = math.max(ranks[child] ?? 0, (ranks[parent] ?? 0) + 1);
      indegree[child] = (indegree[child] ?? 1) - 1;
      if (indegree[child] == 0) {
        queue.add(child);
        queue.sort();
      }
    }
  }
  return ranks;
}

bool _hasCycle(List<String> component, List<SchemaRelationshipEdge> edges) {
  if (edges.any((edge) => edge.isSelfReference)) {
    return true;
  }
  final adjacency = <String, List<String>>{
    for (final table in component) table: <String>[],
  };
  for (final edge in edges) {
    adjacency[edge.childTable]?.add(edge.parentTable);
  }

  final visiting = <String>{};
  final visited = <String>{};
  bool visit(String table) {
    if (visited.contains(table)) {
      return false;
    }
    if (!visiting.add(table)) {
      return true;
    }
    for (final next in adjacency[table] ?? const <String>[]) {
      if (visit(next)) {
        return true;
      }
    }
    visiting.remove(table);
    visited.add(table);
    return false;
  }

  for (final table in component) {
    if (visit(table)) {
      return true;
    }
  }
  return false;
}

SchemaRelationshipEdgeRoute _routeEdge({
  required SchemaRelationshipEdge edge,
  required Map<String, SchemaRelationshipNodeLayout> layouts,
  required double loopMargin,
}) {
  final child = layouts[edge.childTable]!.bounds;
  final parent = layouts[edge.parentTable]!.bounds;
  if (edge.isSelfReference) {
    final points = <SchemaRelationshipPoint>[
      SchemaRelationshipPoint(child.right, child.centerY),
      SchemaRelationshipPoint(child.right + loopMargin, child.centerY),
      SchemaRelationshipPoint(child.right + loopMargin, child.top - loopMargin),
      SchemaRelationshipPoint(child.centerX, child.top - loopMargin),
      SchemaRelationshipPoint(child.centerX, child.top),
    ];
    return SchemaRelationshipEdgeRoute(
      edgeId: edge.id,
      childTable: edge.childTable,
      parentTable: edge.parentTable,
      points: List<SchemaRelationshipPoint>.unmodifiable(points),
      isSelfReference: true,
      hasMissingParent: edge.hasMissingParent,
    );
  }

  final childIsRightOfParent = child.centerX >= parent.centerX;
  final start = childIsRightOfParent
      ? SchemaRelationshipPoint(child.left, child.centerY)
      : SchemaRelationshipPoint(child.right, child.centerY);
  final end = childIsRightOfParent
      ? SchemaRelationshipPoint(parent.right, parent.centerY)
      : SchemaRelationshipPoint(parent.left, parent.centerY);
  final points = <SchemaRelationshipPoint>[start];
  if ((start.x - end.x).abs() > 24 && (start.y - end.y).abs() > 1) {
    final midX = (start.x + end.x) / 2;
    points
      ..add(SchemaRelationshipPoint(midX, start.y))
      ..add(SchemaRelationshipPoint(midX, end.y));
  }
  points.add(end);
  return SchemaRelationshipEdgeRoute(
    edgeId: edge.id,
    childTable: edge.childTable,
    parentTable: edge.parentTable,
    points: List<SchemaRelationshipPoint>.unmodifiable(points),
    isSelfReference: false,
    hasMissingParent: edge.hasMissingParent,
  );
}

SchemaRelationshipRect _canvasBounds({
  required Iterable<SchemaRelationshipNodeLayout> nodeLayouts,
  required Iterable<SchemaRelationshipEdgeRoute> edgeRoutes,
  required double padding,
  required double fallbackRight,
  required double fallbackBottom,
}) {
  var left = padding;
  var top = padding;
  var right = fallbackRight;
  var bottom = fallbackBottom;
  for (final node in nodeLayouts) {
    left = math.min(left, node.bounds.left);
    top = math.min(top, node.bounds.top);
    right = math.max(right, node.bounds.right);
    bottom = math.max(bottom, node.bounds.bottom);
  }
  for (final route in edgeRoutes) {
    for (final point in route.points) {
      left = math.min(left, point.x);
      top = math.min(top, point.y);
      right = math.max(right, point.x);
      bottom = math.max(bottom, point.y);
    }
  }
  final inflatedLeft = math.max(0.0, left - padding);
  final inflatedTop = math.max(0.0, top - padding);
  return SchemaRelationshipRect(
    left: inflatedLeft,
    top: inflatedTop,
    width: right - inflatedLeft + padding,
    height: bottom - inflatedTop + padding,
  );
}
