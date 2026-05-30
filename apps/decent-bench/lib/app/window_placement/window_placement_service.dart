import 'package:flutter/services.dart';

import '../../features/workspace/domain/app_config.dart';

class WindowPlacementService {
  static const String channelName = 'decent_bench/window_placement';

  const WindowPlacementService() : _channel = const MethodChannel(channelName);

  const WindowPlacementService.withChannel(MethodChannel channel)
    : _channel = channel;

  final MethodChannel _channel;

  Future<void> restore(WindowPlacement? placement) async {
    if (placement == null) {
      return;
    }
    try {
      await _channel.invokeMethod<void>(
        'restorePlacement',
        _toChannelMap(placement.normalized()),
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<WindowPlacement?> capture() async {
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'getPlacement',
      );
      return value == null ? null : _fromChannelMap(value);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> get isSupported async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Map<String, Object?> _toChannelMap(WindowPlacement placement) {
    return <String, Object?>{
      'state': placement.state.tomlValue,
      'x': placement.x,
      'y': placement.y,
      'width': placement.width,
      'height': placement.height,
      if (placement.displayId != null) 'displayId': placement.displayId,
      if (placement.displayX != null) 'displayX': placement.displayX,
      if (placement.displayY != null) 'displayY': placement.displayY,
      if (placement.displayWidth != null)
        'displayWidth': placement.displayWidth,
      if (placement.displayHeight != null)
        'displayHeight': placement.displayHeight,
    };
  }

  static WindowPlacement? _fromChannelMap(Map<Object?, Object?> value) {
    final x = _asInt(value['x']);
    final y = _asInt(value['y']);
    final width = _asInt(value['width']);
    final height = _asInt(value['height']);
    if (x == null ||
        y == null ||
        width == null ||
        height == null ||
        width < WindowPlacement.minimumWidth ||
        height < WindowPlacement.minimumHeight) {
      return null;
    }

    final state = value['state'] is String
        ? WindowPlacementState.parse(value['state']! as String)
        : WindowPlacementState.normal;
    final displayId = value['displayId'] is String
        ? (value['displayId']! as String).trim()
        : null;
    final displayWidth = _asInt(value['displayWidth']);
    final displayHeight = _asInt(value['displayHeight']);

    return WindowPlacement(
      x: x,
      y: y,
      width: width,
      height: height,
      state: state,
      displayId: displayId == null || displayId.isEmpty ? null : displayId,
      displayX: _asInt(value['displayX']),
      displayY: _asInt(value['displayY']),
      displayWidth: displayWidth != null && displayWidth > 0
          ? displayWidth
          : null,
      displayHeight: displayHeight != null && displayHeight > 0
          ? displayHeight
          : null,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return null;
  }
}
