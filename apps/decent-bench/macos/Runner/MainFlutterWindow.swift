import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowPlacementChannel: WindowPlacementChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    windowPlacementChannel = WindowPlacementChannel(
      window: self,
      messenger: flutterViewController.engine.binaryMessenger
    )

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

private final class WindowPlacementChannel {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private var observers: [NSObjectProtocol] = []
  private var lastNormalFrame: NSRect?

  init(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    self.lastNormalFrame = window.frame
    self.channel = FlutterMethodChannel(
      name: "decent_bench/window_placement",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    observeWindow(window)
  }

  deinit {
    let center = NotificationCenter.default
    for observer in observers {
      center.removeObserver(observer)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(true)
    case "getPlacement":
      result(capturePlacement())
    case "restorePlacement":
      restorePlacement(call.arguments)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func observeWindow(_ window: NSWindow) {
    let center = NotificationCenter.default
    let notifications: [Notification.Name] = [
      NSWindow.didMoveNotification,
      NSWindow.didResizeNotification,
      NSWindow.didExitFullScreenNotification,
    ]
    for notification in notifications {
      observers.append(
        center.addObserver(
          forName: notification,
          object: window,
          queue: .main
        ) { [weak self] _ in
          self?.rememberNormalFrame()
        }
      )
    }
  }

  private func capturePlacement() -> [String: Any]? {
    guard let window else {
      return nil
    }
    rememberNormalFrame()
    let frame = lastNormalFrame ?? window.frame
    let screen = window.screen ?? screen(containing: frame)

    var payload: [String: Any] = [
      "state": window.styleMask.contains(.fullScreen)
        ? "fullscreen"
        : (window.isZoomed ? "maximized" : "normal"),
      "x": Int(frame.origin.x.rounded()),
      "y": Int(frame.origin.y.rounded()),
      "width": Int(frame.width.rounded()),
      "height": Int(frame.height.rounded()),
    ]

    if let screen {
      payload["displayId"] = screenId(screen)
      let visibleFrame = screen.visibleFrame
      payload["displayX"] = Int(visibleFrame.origin.x.rounded())
      payload["displayY"] = Int(visibleFrame.origin.y.rounded())
      payload["displayWidth"] = Int(visibleFrame.width.rounded())
      payload["displayHeight"] = Int(visibleFrame.height.rounded())
    }
    return payload
  }

  private func restorePlacement(_ arguments: Any?) {
    guard
      let window,
      let payload = arguments as? [String: Any],
      let x = intValue(payload["x"]),
      let y = intValue(payload["y"]),
      let width = intValue(payload["width"]),
      let height = intValue(payload["height"])
    else {
      return
    }

    let displayId = payload["displayId"] as? String
    let state = payload["state"] as? String ?? "normal"
    let targetFrame = NSRect(x: x, y: y, width: width, height: height)
    let targetScreen =
      displayId.flatMap { screen(matching: $0) } ?? screen(containing: targetFrame)
    let clampedFrame = clamp(frame: targetFrame, to: targetScreen?.visibleFrame)

    if window.styleMask.contains(.fullScreen) {
      window.toggleFullScreen(nil)
    }
    if window.isZoomed {
      window.zoom(nil)
    }

    window.setFrame(clampedFrame, display: false)
    lastNormalFrame = clampedFrame

    if state == "fullscreen" {
      window.toggleFullScreen(nil)
    } else if state == "maximized", !window.isZoomed {
      window.zoom(nil)
    }
  }

  private func rememberNormalFrame() {
    guard let window else {
      return
    }
    if window.isZoomed || window.styleMask.contains(.fullScreen) {
      return
    }
    let frame = window.frame
    if frame.width >= 640 && frame.height >= 480 {
      lastNormalFrame = frame
    }
  }

  private func screen(matching displayId: String) -> NSScreen? {
    NSScreen.screens.first { screenId($0) == displayId }
  }

  private func screen(containing frame: NSRect) -> NSScreen? {
    let center = NSPoint(x: frame.midX, y: frame.midY)
    if let containing = NSScreen.screens.first(where: { NSMouseInRect(center, $0.frame, false) }) {
      return containing
    }
    return NSScreen.screens.min { left, right in
      distanceSquared(from: center, to: left.frame) <
        distanceSquared(from: center, to: right.frame)
    }
  }

  private func screenId(_ screen: NSScreen) -> String {
    if let screenNumber = screen.deviceDescription[
      NSDeviceDescriptionKey("NSScreenNumber")
    ] as? NSNumber {
      return screenNumber.stringValue
    }
    return screen.localizedName
  }

  private func clamp(frame: NSRect, to visibleFrame: NSRect?) -> NSRect {
    guard let area = visibleFrame, area.width > 0, area.height > 0 else {
      return frame
    }
    var result = frame
    result.size.width = min(max(result.width, 640), area.width)
    result.size.height = min(max(result.height, 480), area.height)
    result.origin.x = min(max(result.origin.x, area.minX), area.maxX - result.width)
    result.origin.y = min(max(result.origin.y, area.minY), area.maxY - result.height)
    return result
  }

  private func distanceSquared(from point: NSPoint, to rect: NSRect) -> CGFloat {
    let clampedX = min(max(point.x, rect.minX), rect.maxX)
    let clampedY = min(max(point.y, rect.minY), rect.maxY)
    let dx = point.x - clampedX
    let dy = point.y - clampedY
    return dx * dx + dy * dy
  }

  private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    return nil
  }
}
