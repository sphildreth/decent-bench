import 'package:decent_bench/app/window_placement/window_placement_service.dart';
import 'package:decent_bench/features/workspace/domain/app_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/window_placement');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final service = WindowPlacementService.withChannel(channel);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('capture parses native placement payload', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getPlacement');
      return <String, Object?>{
        'state': 'maximized',
        'x': -1600,
        'y': 100,
        'width': 1400,
        'height': 900,
        'displayId': r'\\.\DISPLAY2',
        'displayX': -1920,
        'displayY': 0,
        'displayWidth': 1920,
        'displayHeight': 1080,
      };
    });

    final placement = await service.capture();

    expect(
      placement,
      const WindowPlacement(
        state: WindowPlacementState.maximized,
        x: -1600,
        y: 100,
        width: 1400,
        height: 900,
        displayId: r'\\.\DISPLAY2',
        displayX: -1920,
        displayY: 0,
        displayWidth: 1920,
        displayHeight: 1080,
      ),
    );
  });

  test('restore sends normalized placement payload', () async {
    MethodCall? sentCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sentCall = call;
      return null;
    });

    await service.restore(
      const WindowPlacement(
        state: WindowPlacementState.normal,
        x: 40,
        y: 50,
        width: 120,
        height: 100,
      ),
    );

    expect(sentCall?.method, 'restorePlacement');
    expect(sentCall?.arguments, <String, Object?>{
      'state': 'normal',
      'x': 40,
      'y': 50,
      'width': WindowPlacement.minimumWidth,
      'height': WindowPlacement.minimumHeight,
    });
  });

  test('capture returns null when native channel is unavailable', () async {
    final placement = await service.capture();

    expect(placement, isNull);
  });
}
