import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as image;

import 'schema_relationship_graph.dart';
import 'schema_relationship_layout.dart';
import 'workspace_models.dart';

enum SchemaRelationshipImageFormat { png, jpeg }

enum SchemaRelationshipExportScope { fullDiagram, viewport }

class SchemaRelationshipExportOptions {
  const SchemaRelationshipExportOptions({
    this.format = SchemaRelationshipImageFormat.png,
    this.scope = SchemaRelationshipExportScope.fullDiagram,
    this.requestedScale = 2,
    this.transparentPng = false,
    this.jpegQuality = 92,
  });

  final SchemaRelationshipImageFormat format;
  final SchemaRelationshipExportScope scope;
  final double requestedScale;
  final bool transparentPng;
  final int jpegQuality;

  String get extension {
    return switch (format) {
      SchemaRelationshipImageFormat.png => 'png',
      SchemaRelationshipImageFormat.jpeg => 'jpg',
    };
  }
}

class SchemaRelationshipExportLimits {
  const SchemaRelationshipExportLimits({
    this.maxAxisPixels = 8192,
    this.maxMegapixels = 64,
  });

  final int maxAxisPixels;
  final int maxMegapixels;
}

class SchemaRelationshipExportPlan {
  const SchemaRelationshipExportPlan({
    required this.requestedScale,
    required this.effectiveScale,
    required this.outputWidth,
    required this.outputHeight,
    required this.downscaled,
    required this.rejected,
    this.message,
  });

  final double requestedScale;
  final double effectiveScale;
  final int outputWidth;
  final int outputHeight;
  final bool downscaled;
  final bool rejected;
  final String? message;

  int get outputPixels => outputWidth * outputHeight;
}

String schemaRelationshipExportTitle({
  required String databaseLabel,
  required int tableCount,
  required int relationshipCount,
}) {
  final tableLabel = tableCount == 1 ? 'table' : 'tables';
  final relationshipLabel = relationshipCount == 1
      ? 'relationship'
      : 'relationships';
  return '$databaseLabel - ERD - $tableCount $tableLabel, '
      '$relationshipCount $relationshipLabel';
}

class SchemaRelationshipExportPlanner {
  const SchemaRelationshipExportPlanner({
    this.limits = const SchemaRelationshipExportLimits(),
  });

  final SchemaRelationshipExportLimits limits;

  SchemaRelationshipExportPlan plan({
    required SchemaRelationshipRect logicalBounds,
    required double requestedScale,
  }) {
    final width = math.max(1.0, logicalBounds.width);
    final height = math.max(1.0, logicalBounds.height);
    final safeByAxis = math.min(
      limits.maxAxisPixels / width,
      limits.maxAxisPixels / height,
    );
    final safeByPixels = math.sqrt(
      limits.maxMegapixels * 1000000 / (width * height),
    );
    final safeScale = math.min(safeByAxis, safeByPixels);
    if (safeScale < 1) {
      return SchemaRelationshipExportPlan(
        requestedScale: requestedScale,
        effectiveScale: 0,
        outputWidth: width.ceil(),
        outputHeight: height.ceil(),
        downscaled: false,
        rejected: true,
        message:
            'The diagram exceeds safe image export limits at 1x. Export the current viewport instead.',
      );
    }
    final effectiveScale = requestedScale.clamp(1.0, safeScale).toDouble();
    return SchemaRelationshipExportPlan(
      requestedScale: requestedScale,
      effectiveScale: effectiveScale,
      outputWidth: (width * effectiveScale).ceil(),
      outputHeight: (height * effectiveScale).ceil(),
      downscaled: effectiveScale < requestedScale,
      rejected: false,
      message: effectiveScale < requestedScale
          ? 'Export scale was reduced to ${effectiveScale.toStringAsFixed(2)}x to stay within safe image limits.'
          : null,
    );
  }
}

class SchemaRelationshipExportRenderer {
  const SchemaRelationshipExportRenderer({
    this.planner = const SchemaRelationshipExportPlanner(),
  });

  static const double _titleHeight = 52;

  final SchemaRelationshipExportPlanner planner;

  Future<SchemaRelationshipRenderedImage> render({
    required SchemaRelationshipGraph graph,
    required SchemaRelationshipLayout layout,
    required SchemaRelationshipExportOptions options,
    required String title,
    SchemaRelationshipRect? viewportBounds,
    ui.Color backgroundColor = const ui.Color(0xffffffff),
  }) async {
    final sceneBounds =
        options.scope == SchemaRelationshipExportScope.viewport &&
            viewportBounds != null
        ? viewportBounds
        : layout.canvasBounds;
    final logicalBounds = SchemaRelationshipRect(
      left: 0,
      top: 0,
      width: sceneBounds.width,
      height: sceneBounds.height + _titleHeight,
    );
    final plan = planner.plan(
      logicalBounds: logicalBounds,
      requestedScale: options.requestedScale,
    );
    if (plan.rejected) {
      throw SchemaRelationshipExportException(plan.message!);
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(plan.effectiveScale);
    final shouldFillBackground =
        options.format == SchemaRelationshipImageFormat.jpeg ||
        !options.transparentPng;
    if (shouldFillBackground) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, logicalBounds.width, logicalBounds.height),
        ui.Paint()..color = backgroundColor,
      );
    }
    _drawTitle(canvas, title, logicalBounds.width);
    canvas.save();
    canvas.translate(-sceneBounds.left, _titleHeight - sceneBounds.top);
    _drawEdges(canvas, graph, layout);
    _drawNodes(canvas, graph, layout);
    canvas.restore();

    final picture = recorder.endRecording();
    final raster = await picture.toImage(plan.outputWidth, plan.outputHeight);
    picture.dispose();
    try {
      final bytes = switch (options.format) {
        SchemaRelationshipImageFormat.png => await _encodePng(raster),
        SchemaRelationshipImageFormat.jpeg => await _encodeJpeg(
          raster,
          quality: options.jpegQuality,
        ),
      };
      return SchemaRelationshipRenderedImage(bytes: bytes, plan: plan);
    } finally {
      raster.dispose();
    }
  }

  Future<Uint8List> _encodePng(ui.Image raster) async {
    final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw const SchemaRelationshipExportException('PNG encoding failed.');
    }
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  }

  Future<Uint8List> _encodeJpeg(ui.Image raster, {required int quality}) async {
    final bytes = await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) {
      throw const SchemaRelationshipExportException('JPEG encoding failed.');
    }
    final rawBytes = Uint8List.fromList(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final width = raster.width;
    final height = raster.height;
    return Isolate.run(() {
      final bitmap = image.Image.fromBytes(
        width: width,
        height: height,
        bytes: rawBytes.buffer,
        order: image.ChannelOrder.rgba,
      );
      return image.encodeJpg(bitmap, quality: quality);
    });
  }

  void _drawTitle(ui.Canvas canvas, String title, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: ui.Color(0xff1f2937),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: math.max(1, width - 28));
    painter.paint(canvas, const ui.Offset(14, 16));
  }

  void _drawEdges(
    ui.Canvas canvas,
    SchemaRelationshipGraph graph,
    SchemaRelationshipLayout layout,
  ) {
    final edgeById = <String, SchemaRelationshipEdge>{
      for (final edge in graph.edges) edge.id: edge,
    };
    for (final route in layout.edges) {
      final edge = edgeById[route.edgeId];
      if (edge == null || route.points.length < 2) {
        continue;
      }
      final color = edge.hasMissingParent
          ? const ui.Color(0xffb45309)
          : const ui.Color(0xff64748b);
      final paint = ui.Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = ui.PaintingStyle.stroke;
      for (var i = 0; i < route.points.length - 1; i++) {
        final start = _offset(route.points[i]);
        final end = _offset(route.points[i + 1]);
        if (edge.hasMissingParent) {
          _drawDashedLine(canvas, start, end, paint);
        } else {
          canvas.drawLine(start, end, paint);
        }
      }
      _drawArrowhead(canvas, route.points, color);
      _drawEdgeLabel(canvas, edge, route.points);
    }
  }

  void _drawNodes(
    ui.Canvas canvas,
    SchemaRelationshipGraph graph,
    SchemaRelationshipLayout layout,
  ) {
    final nodeByName = <String, SchemaRelationshipNode>{
      for (final node in graph.nodes) node.tableName: node,
    };
    for (final nodeLayout in layout.nodes) {
      final node = nodeByName[nodeLayout.tableName];
      if (node == null) {
        continue;
      }
      final rect = _rect(nodeLayout.bounds);
      final fill = node.isPlaceholder
          ? const ui.Color(0xfffffbeb)
          : const ui.Color(0xffffffff);
      final border = node.isPlaceholder
          ? const ui.Color(0xffb45309)
          : const ui.Color(0xff94a3b8);
      final rrect = ui.RRect.fromRectAndRadius(
        rect,
        const ui.Radius.circular(8),
      );
      canvas.drawRRect(rrect, ui.Paint()..color = fill);
      final borderPaint = ui.Paint()
        ..color = border
        ..strokeWidth = 1.4
        ..style = ui.PaintingStyle.stroke;
      if (node.isPlaceholder) {
        _drawDashedRRect(canvas, rrect, borderPaint);
      } else {
        canvas.drawRRect(rrect, borderPaint);
      }
      _paintText(
        canvas,
        node.tableName,
        ui.Offset(rect.left + 12, rect.top + 10),
        maxWidth: rect.width - 24,
        style: const TextStyle(
          color: ui.Color(0xff111827),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      );
      final columns = node.columns.take(6).toList();
      for (var index = 0; index < columns.length; index++) {
        final column = columns[index];
        final label = _columnLabel(column);
        _paintText(
          canvas,
          label,
          ui.Offset(rect.left + 12, rect.top + 36 + index * 15),
          maxWidth: rect.width - 24,
          style: TextStyle(
            color: column.hasForeignKey
                ? const ui.Color(0xff075985)
                : const ui.Color(0xff475569),
            fontSize: 11,
          ),
        );
      }
      if (node.columns.length > columns.length) {
        _paintText(
          canvas,
          '+${node.columns.length - columns.length} more',
          ui.Offset(rect.left + 12, rect.bottom - 20),
          maxWidth: rect.width - 24,
          style: const TextStyle(color: ui.Color(0xff64748b), fontSize: 11),
        );
      }
    }
  }

  void _drawEdgeLabel(
    ui.Canvas canvas,
    SchemaRelationshipEdge edge,
    List<SchemaRelationshipPoint> points,
  ) {
    final middle = points[points.length ~/ 2];
    final label = edge.columnPairs
        .map((pair) => '${pair.childColumn} -> ${pair.parentColumn}')
        .join(', ');
    _paintText(
      canvas,
      label,
      ui.Offset(middle.x + 6, middle.y - 16),
      maxWidth: 180,
      style: const TextStyle(color: ui.Color(0xff334155), fontSize: 10),
    );
  }

  void _drawArrowhead(
    ui.Canvas canvas,
    List<SchemaRelationshipPoint> points,
    ui.Color color,
  ) {
    if (points.length < 2) {
      return;
    }
    final end = points.last;
    final previous = points[points.length - 2];
    final angle = math.atan2(end.y - previous.y, end.x - previous.x);
    const size = 7.0;
    final path = ui.Path()
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
    canvas.drawPath(path, ui.Paint()..color = color);
  }
}

class SchemaRelationshipRenderedImage {
  const SchemaRelationshipRenderedImage({
    required this.bytes,
    required this.plan,
  });

  final Uint8List bytes;
  final SchemaRelationshipExportPlan plan;
}

class SchemaRelationshipExportException implements Exception {
  const SchemaRelationshipExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _columnLabel(SchemaColumn column) {
  final flags = <String>[
    if (column.primaryKey) 'PK',
    if (column.hasForeignKey) 'FK',
  ];
  final suffix = flags.isEmpty ? '' : ' ${flags.join('/')}';
  return '${column.name}  ${column.type}$suffix';
}

void _paintText(
  ui.Canvas canvas,
  String text,
  ui.Offset offset, {
  required double maxWidth,
  required TextStyle style,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: math.max(1, maxWidth));
  painter.paint(canvas, offset);
}

void _drawDashedLine(
  ui.Canvas canvas,
  ui.Offset start,
  ui.Offset end,
  ui.Paint paint,
) {
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

void _drawDashedRRect(ui.Canvas canvas, ui.RRect rect, ui.Paint paint) {
  final bounds = rect.outerRect;
  _drawDashedLine(canvas, bounds.topLeft, bounds.topRight, paint);
  _drawDashedLine(canvas, bounds.topRight, bounds.bottomRight, paint);
  _drawDashedLine(canvas, bounds.bottomRight, bounds.bottomLeft, paint);
  _drawDashedLine(canvas, bounds.bottomLeft, bounds.topLeft, paint);
}

ui.Offset _offset(SchemaRelationshipPoint point) {
  return ui.Offset(point.x, point.y);
}

ui.Rect _rect(SchemaRelationshipRect rect) {
  return ui.Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height);
}
