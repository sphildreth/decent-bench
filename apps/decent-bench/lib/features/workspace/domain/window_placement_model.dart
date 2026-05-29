enum WindowPlacementState {
  normal,
  maximized,
  fullscreen;

  String get tomlValue => name;

  static WindowPlacementState parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final value in WindowPlacementState.values) {
      if (value.name == normalized) {
        return value;
      }
    }
    return WindowPlacementState.normal;
  }
}

class WindowPlacement {
  static const int minimumWidth = 640;
  static const int minimumHeight = 480;

  const WindowPlacement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.state,
    this.displayId,
    this.displayX,
    this.displayY,
    this.displayWidth,
    this.displayHeight,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final WindowPlacementState state;
  final String? displayId;
  final int? displayX;
  final int? displayY;
  final int? displayWidth;
  final int? displayHeight;

  WindowPlacement normalized() {
    return WindowPlacement(
      x: x,
      y: y,
      width: width < minimumWidth ? minimumWidth : width,
      height: height < minimumHeight ? minimumHeight : height,
      state: state,
      displayId: displayId == null || displayId!.trim().isEmpty
          ? null
          : displayId!.trim(),
      displayX: displayX,
      displayY: displayY,
      displayWidth: displayWidth != null && displayWidth! > 0
          ? displayWidth
          : null,
      displayHeight: displayHeight != null && displayHeight! > 0
          ? displayHeight
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WindowPlacement &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        other.state == state &&
        other.displayId == displayId &&
        other.displayX == displayX &&
        other.displayY == displayY &&
        other.displayWidth == displayWidth &&
        other.displayHeight == displayHeight;
  }

  @override
  int get hashCode => Object.hash(
    x,
    y,
    width,
    height,
    state,
    displayId,
    displayX,
    displayY,
    displayWidth,
    displayHeight,
  );
}
