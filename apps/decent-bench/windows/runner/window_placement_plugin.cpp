#include "window_placement_plugin.h"

#include <flutter/encodable_value.h>

#include <algorithm>
#include <optional>
#include <string>

#include "utils.h"

namespace {

constexpr char kChannelName[] = "decent_bench/window_placement";
constexpr char kIsSupportedMethod[] = "isSupported";
constexpr char kGetPlacementMethod[] = "getPlacement";
constexpr char kRestorePlacementMethod[] = "restorePlacement";
constexpr int kMinimumWidth = 640;
constexpr int kMinimumHeight = 480;

using flutter::EncodableMap;
using flutter::EncodableValue;

struct Bounds {
  int x;
  int y;
  int width;
  int height;
};

struct MonitorInfo {
  HMONITOR handle = nullptr;
  RECT work_area{};
  std::string id;
};

const EncodableValue* FindValue(const EncodableMap& map, const char* key) {
  const auto iterator = map.find(EncodableValue(std::string(key)));
  if (iterator == map.end()) {
    return nullptr;
  }
  return &iterator->second;
}

std::optional<int64_t> GetInt64(const EncodableMap& map, const char* key) {
  const EncodableValue* value = FindValue(map, key);
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* int32_value = std::get_if<int32_t>(value)) {
    return *int32_value;
  }
  if (const auto* int64_value = std::get_if<int64_t>(value)) {
    return *int64_value;
  }
  return std::nullopt;
}

std::optional<std::string> GetString(const EncodableMap& map,
                                     const char* key) {
  const EncodableValue* value = FindValue(map, key);
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* string_value = std::get_if<std::string>(value)) {
    return *string_value;
  }
  return std::nullopt;
}

std::wstring Utf8ToWide(const std::string& input) {
  if (input.empty()) {
    return std::wstring();
  }
  const int size_needed =
      MultiByteToWideChar(CP_UTF8, 0, input.c_str(), -1, nullptr, 0);
  if (size_needed <= 0) {
    return std::wstring();
  }
  std::wstring output(size_needed - 1, L'\0');
  if (!output.empty()) {
    MultiByteToWideChar(CP_UTF8, 0, input.c_str(), -1, output.data(),
                        size_needed);
  }
  return output;
}

int ClampInt(int value, int low, int high) {
  if (value < low) {
    return low;
  }
  if (value > high) {
    return high;
  }
  return value;
}

MonitorInfo GetMonitorInfoForHandle(HMONITOR monitor) {
  MonitorInfo result;
  if (monitor == nullptr) {
    return result;
  }
  MONITORINFOEXW info{};
  info.cbSize = sizeof(MONITORINFOEXW);
  if (!GetMonitorInfoW(monitor, reinterpret_cast<LPMONITORINFO>(&info))) {
    return result;
  }
  result.handle = monitor;
  result.work_area = info.rcWork;
  result.id = Utf8FromUtf16(info.szDevice);
  return result;
}

struct FindMonitorContext {
  std::wstring target_id;
  HMONITOR match = nullptr;
};

BOOL CALLBACK FindMonitorByIdCallback(HMONITOR monitor,
                                      HDC hdc,
                                      LPRECT rect,
                                      LPARAM data) {
  auto* context = reinterpret_cast<FindMonitorContext*>(data);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(MONITORINFOEXW);
  if (GetMonitorInfoW(monitor, reinterpret_cast<LPMONITORINFO>(&info)) &&
      context->target_id == info.szDevice) {
    context->match = monitor;
    return FALSE;
  }
  return TRUE;
}

HMONITOR FindMonitorById(const std::string& id) {
  if (id.empty()) {
    return nullptr;
  }
  FindMonitorContext context{Utf8ToWide(id), nullptr};
  EnumDisplayMonitors(nullptr, nullptr, FindMonitorByIdCallback,
                      reinterpret_cast<LPARAM>(&context));
  return context.match;
}

HMONITOR FindNearestMonitor(const Bounds& bounds) {
  RECT rect{static_cast<LONG>(bounds.x),
            static_cast<LONG>(bounds.y),
            static_cast<LONG>(bounds.x + bounds.width),
            static_cast<LONG>(bounds.y + bounds.height)};
  return MonitorFromRect(&rect, MONITOR_DEFAULTTONEAREST);
}

Bounds ClampBounds(Bounds bounds, const RECT& area) {
  bounds.width = std::max(kMinimumWidth, bounds.width);
  bounds.height = std::max(kMinimumHeight, bounds.height);
  const int area_width = static_cast<int>(area.right - area.left);
  const int area_height = static_cast<int>(area.bottom - area.top);
  if (area_width > 0) {
    bounds.width = std::min(bounds.width, area_width);
  }
  if (area_height > 0) {
    bounds.height = std::min(bounds.height, area_height);
  }
  if (area_width > 0 && area_height > 0) {
    const int max_x = static_cast<int>(area.right) - bounds.width;
    const int max_y = static_cast<int>(area.bottom) - bounds.height;
    bounds.x = ClampInt(bounds.x, static_cast<int>(area.left),
                        std::max(static_cast<int>(area.left), max_x));
    bounds.y = ClampInt(bounds.y, static_cast<int>(area.top),
                        std::max(static_cast<int>(area.top), max_y));
  }
  return bounds;
}

std::string PlacementState(const WINDOWPLACEMENT& placement, HWND window) {
  if (IsZoomed(window) || placement.showCmd == SW_SHOWMAXIMIZED) {
    return "maximized";
  }
  return "normal";
}

}  // namespace

WindowPlacementPlugin::WindowPlacementPlugin(flutter::BinaryMessenger* messenger,
                                             HWND window_handle)
    : window_handle_(window_handle),
      channel_(std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

WindowPlacementPlugin::~WindowPlacementPlugin() {
  channel_->SetMethodCallHandler(nullptr);
}

void WindowPlacementPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == kIsSupportedMethod) {
    result->Success(EncodableValue(true));
    return;
  }
  if (method == kGetPlacementMethod) {
    result->Success(CapturePlacement());
    return;
  }
  if (method == kRestorePlacementMethod) {
    RestorePlacement(call.arguments());
    result->Success();
    return;
  }
  result->NotImplemented();
}

EncodableValue WindowPlacementPlugin::CapturePlacement() {
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(WINDOWPLACEMENT);
  GetWindowPlacement(window_handle_, &placement);
  RECT normal_rect = placement.rcNormalPosition;
  if (normal_rect.right <= normal_rect.left || normal_rect.bottom <= normal_rect.top) {
    GetWindowRect(window_handle_, &normal_rect);
  }

  Bounds bounds{static_cast<int>(normal_rect.left),
                static_cast<int>(normal_rect.top),
                static_cast<int>(normal_rect.right - normal_rect.left),
                static_cast<int>(normal_rect.bottom - normal_rect.top)};
  const MonitorInfo monitor =
      GetMonitorInfoForHandle(FindNearestMonitor(bounds));

  EncodableMap map;
  map[EncodableValue("state")] =
      EncodableValue(PlacementState(placement, window_handle_));
  map[EncodableValue("x")] = EncodableValue(bounds.x);
  map[EncodableValue("y")] = EncodableValue(bounds.y);
  map[EncodableValue("width")] = EncodableValue(bounds.width);
  map[EncodableValue("height")] = EncodableValue(bounds.height);
  if (!monitor.id.empty()) {
    map[EncodableValue("displayId")] = EncodableValue(monitor.id);
  }
  if (monitor.work_area.right > monitor.work_area.left &&
      monitor.work_area.bottom > monitor.work_area.top) {
    map[EncodableValue("displayX")] =
        EncodableValue(static_cast<int>(monitor.work_area.left));
    map[EncodableValue("displayY")] =
        EncodableValue(static_cast<int>(monitor.work_area.top));
    map[EncodableValue("displayWidth")] = EncodableValue(
        static_cast<int>(monitor.work_area.right - monitor.work_area.left));
    map[EncodableValue("displayHeight")] = EncodableValue(
        static_cast<int>(monitor.work_area.bottom - monitor.work_area.top));
  }
  return EncodableValue(map);
}

void WindowPlacementPlugin::RestorePlacement(const EncodableValue* arguments) {
  if (arguments == nullptr) {
    return;
  }
  const auto* map = std::get_if<EncodableMap>(arguments);
  if (map == nullptr) {
    return;
  }
  const auto x = GetInt64(*map, "x");
  const auto y = GetInt64(*map, "y");
  const auto width = GetInt64(*map, "width");
  const auto height = GetInt64(*map, "height");
  if (!x.has_value() || !y.has_value() || !width.has_value() ||
      !height.has_value()) {
    return;
  }

  Bounds bounds{static_cast<int>(*x), static_cast<int>(*y),
                static_cast<int>(*width), static_cast<int>(*height)};
  HMONITOR monitor = nullptr;
  if (const auto display_id = GetString(*map, "displayId")) {
    monitor = FindMonitorById(*display_id);
  }
  if (monitor == nullptr) {
    monitor = FindNearestMonitor(bounds);
  }
  const MonitorInfo monitor_info = GetMonitorInfoForHandle(monitor);
  bounds = ClampBounds(bounds, monitor_info.work_area);

  WINDOWPLACEMENT placement{};
  placement.length = sizeof(WINDOWPLACEMENT);
  GetWindowPlacement(window_handle_, &placement);
  const auto state = GetString(*map, "state").value_or("normal");
  placement.flags = 0;
  placement.showCmd = state == "maximized" ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
  placement.rcNormalPosition = RECT{
      static_cast<LONG>(bounds.x),
      static_cast<LONG>(bounds.y),
      static_cast<LONG>(bounds.x + bounds.width),
      static_cast<LONG>(bounds.y + bounds.height),
  };
  SetWindowPlacement(window_handle_, &placement);
}
