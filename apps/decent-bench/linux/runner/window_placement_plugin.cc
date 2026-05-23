#include "window_placement_plugin.h"

#include <algorithm>
#include <cstring>
#include <optional>
#include <string>

namespace {

constexpr char kChannelName[] = "decent_bench/window_placement";
constexpr char kIsSupportedMethod[] = "isSupported";
constexpr char kGetPlacementMethod[] = "getPlacement";
constexpr char kRestorePlacementMethod[] = "restorePlacement";
constexpr int kMinimumWidth = 640;
constexpr int kMinimumHeight = 480;

std::optional<gint64> GetInt(FlValue* map, const char* key) {
  FlValue* value = fl_value_lookup_string(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_INT) {
    return std::nullopt;
  }
  return fl_value_get_int(value);
}

const gchar* GetString(FlValue* map, const char* key) {
  FlValue* value = fl_value_lookup_string(map, key);
  if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_STRING) {
    return nullptr;
  }
  return fl_value_get_string(value);
}

void SetInt(FlValue* map, const char* key, int value) {
  fl_value_set_string_take(map, key, fl_value_new_int(value));
}

void SetString(FlValue* map, const char* key, const std::string& value) {
  fl_value_set_string_take(map, key, fl_value_new_string(value.c_str()));
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

std::string MonitorId(GdkDisplay* display, GdkMonitor* monitor) {
  if (display == nullptr || monitor == nullptr) {
    return std::string();
  }
  const int monitor_count = gdk_display_get_n_monitors(display);
  for (int index = 0; index < monitor_count; index++) {
    GdkMonitor* candidate = gdk_display_get_monitor(display, index);
    if (candidate != monitor) {
      continue;
    }
    std::string id = "monitor:";
    id += std::to_string(index);
    const char* model = gdk_monitor_get_model(candidate);
    if (model != nullptr && strlen(model) > 0) {
      id += ":";
      id += model;
    }
    return id;
  }
  return std::string();
}

GdkMonitor* FindMonitorById(GdkDisplay* display, const char* display_id) {
  if (display == nullptr || display_id == nullptr || strlen(display_id) == 0) {
    return nullptr;
  }
  const int monitor_count = gdk_display_get_n_monitors(display);
  for (int index = 0; index < monitor_count; index++) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, index);
    const std::string id = MonitorId(display, monitor);
    if (id == display_id) {
      return monitor;
    }
  }
  return nullptr;
}

GdkMonitor* FindNearestMonitor(GdkDisplay* display,
                               const WindowPlacementPlugin::Bounds& bounds) {
  if (display == nullptr) {
    return nullptr;
  }
  const int center_x = bounds.x + bounds.width / 2;
  const int center_y = bounds.y + bounds.height / 2;
  GdkMonitor* monitor =
      gdk_display_get_monitor_at_point(display, center_x, center_y);
  if (monitor != nullptr) {
    return monitor;
  }
  return gdk_display_get_primary_monitor(display);
}

GdkRectangle MonitorWorkArea(GdkMonitor* monitor) {
  GdkRectangle area{};
  if (monitor != nullptr) {
    gdk_monitor_get_workarea(monitor, &area);
    if (area.width <= 0 || area.height <= 0) {
      gdk_monitor_get_geometry(monitor, &area);
    }
  }
  return area;
}

WindowPlacementPlugin::Bounds ClampBounds(
    WindowPlacementPlugin::Bounds bounds,
    const GdkRectangle& area) {
  bounds.width = std::max(kMinimumWidth, bounds.width);
  bounds.height = std::max(kMinimumHeight, bounds.height);

  if (area.width > 0) {
    bounds.width = std::min(bounds.width, area.width);
  }
  if (area.height > 0) {
    bounds.height = std::min(bounds.height, area.height);
  }
  if (area.width > 0 && area.height > 0) {
    const int max_x = area.x + area.width - bounds.width;
    const int max_y = area.y + area.height - bounds.height;
    bounds.x = ClampInt(bounds.x, area.x, std::max(area.x, max_x));
    bounds.y = ClampInt(bounds.y, area.y, std::max(area.y, max_y));
  }
  return bounds;
}

}  // namespace

WindowPlacementPlugin::WindowPlacementPlugin(FlBinaryMessenger* messenger,
                                             GtkWindow* window)
    : window_(window) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel_ =
      fl_method_channel_new(messenger, kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel_, MethodCallHandler, this,
                                            nullptr);
  g_signal_connect(window_, "configure-event", G_CALLBACK(ConfigureEvent),
                   this);
  g_signal_connect(window_, "window-state-event", G_CALLBACK(WindowStateEvent),
                   this);
  RememberNormalBounds();
}

WindowPlacementPlugin::~WindowPlacementPlugin() {
  g_signal_handlers_disconnect_by_data(window_, this);
  g_object_unref(channel_);
}

void WindowPlacementPlugin::MethodCallHandler(FlMethodChannel* channel,
                                              FlMethodCall* method_call,
                                              gpointer user_data) {
  auto* self = static_cast<WindowPlacementPlugin*>(user_data);
  g_autoptr(FlMethodResponse) response = self->HandleMethodCall(method_call);
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send window placement response: %s", error->message);
  }
}

gboolean WindowPlacementPlugin::ConfigureEvent(GtkWidget* widget,
                                               GdkEventConfigure* event,
                                               gpointer user_data) {
  auto* self = static_cast<WindowPlacementPlugin*>(user_data);
  if (!self->IsMaximized() && !self->IsFullscreen()) {
    self->last_normal_bounds_ =
        Bounds{event->x, event->y, event->width, event->height};
    self->has_last_normal_bounds_ = true;
  }
  return FALSE;
}

gboolean WindowPlacementPlugin::WindowStateEvent(GtkWidget* widget,
                                                 GdkEventWindowState* event,
                                                 gpointer user_data) {
  auto* self = static_cast<WindowPlacementPlugin*>(user_data);
  self->window_state_ = event->new_window_state;
  if (!self->IsMaximized() && !self->IsFullscreen()) {
    self->RememberNormalBounds();
  }
  return FALSE;
}

FlMethodResponse* WindowPlacementPlugin::HandleMethodCall(
    FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  if (strcmp(method, kIsSupportedMethod) == 0) {
    g_autoptr(FlValue) value = fl_value_new_bool(TRUE);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  }
  if (strcmp(method, kGetPlacementMethod) == 0) {
    g_autoptr(FlValue) value = CapturePlacement();
    return FL_METHOD_RESPONSE(fl_method_success_response_new(value));
  }
  if (strcmp(method, kRestorePlacementMethod) == 0) {
    RestorePlacement(fl_method_call_get_args(method_call));
    return FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  }
  return FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
}

FlValue* WindowPlacementPlugin::CapturePlacement() {
  RememberNormalBounds();
  Bounds bounds = last_normal_bounds_;
  if (!has_last_normal_bounds_) {
    gtk_window_get_position(window_, &bounds.x, &bounds.y);
    gtk_window_get_size(window_, &bounds.width, &bounds.height);
  }

  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window_));
  GdkMonitor* monitor = nullptr;
  GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window_));
  if (display != nullptr && gdk_window != nullptr) {
    monitor = gdk_display_get_monitor_at_window(display, gdk_window);
  }
  if (monitor == nullptr) {
    monitor = FindNearestMonitor(display, bounds);
  }
  GdkRectangle display_area = MonitorWorkArea(monitor);

  FlValue* result = fl_value_new_map();
  SetString(result, "state", IsFullscreen() ? "fullscreen"
                                             : (IsMaximized() ? "maximized"
                                                              : "normal"));
  SetInt(result, "x", bounds.x);
  SetInt(result, "y", bounds.y);
  SetInt(result, "width", bounds.width);
  SetInt(result, "height", bounds.height);
  const std::string display_id = MonitorId(display, monitor);
  if (!display_id.empty()) {
    SetString(result, "displayId", display_id);
  }
  if (display_area.width > 0 && display_area.height > 0) {
    SetInt(result, "displayX", display_area.x);
    SetInt(result, "displayY", display_area.y);
    SetInt(result, "displayWidth", display_area.width);
    SetInt(result, "displayHeight", display_area.height);
  }
  return result;
}

void WindowPlacementPlugin::RestorePlacement(FlValue* arguments) {
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return;
  }
  const auto x = GetInt(arguments, "x");
  const auto y = GetInt(arguments, "y");
  const auto width = GetInt(arguments, "width");
  const auto height = GetInt(arguments, "height");
  if (!x.has_value() || !y.has_value() || !width.has_value() ||
      !height.has_value()) {
    return;
  }

  Bounds bounds{static_cast<int>(*x), static_cast<int>(*y),
                static_cast<int>(*width), static_cast<int>(*height)};
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window_));
  GdkMonitor* monitor = FindMonitorById(display, GetString(arguments, "displayId"));
  if (monitor == nullptr) {
    monitor = FindNearestMonitor(display, bounds);
  }
  bounds = ClampBounds(bounds, MonitorWorkArea(monitor));

  gtk_window_unfullscreen(window_);
  gtk_window_unmaximize(window_);
  gtk_window_move(window_, bounds.x, bounds.y);
  gtk_window_resize(window_, bounds.width, bounds.height);
  last_normal_bounds_ = bounds;
  has_last_normal_bounds_ = true;

  const char* state = GetString(arguments, "state");
  if (state != nullptr && strcmp(state, "fullscreen") == 0) {
    gtk_window_fullscreen(window_);
  } else if (state != nullptr && strcmp(state, "maximized") == 0) {
    gtk_window_maximize(window_);
  }
}

void WindowPlacementPlugin::RememberNormalBounds() {
  if (IsMaximized() || IsFullscreen()) {
    return;
  }
  Bounds bounds{};
  gtk_window_get_position(window_, &bounds.x, &bounds.y);
  gtk_window_get_size(window_, &bounds.width, &bounds.height);
  if (bounds.width >= kMinimumWidth && bounds.height >= kMinimumHeight) {
    last_normal_bounds_ = bounds;
    has_last_normal_bounds_ = true;
  }
}

bool WindowPlacementPlugin::IsMaximized() const {
  return gtk_window_is_maximized(window_) ||
         (window_state_ & GDK_WINDOW_STATE_MAXIMIZED) != 0;
}

bool WindowPlacementPlugin::IsFullscreen() const {
  return (window_state_ & GDK_WINDOW_STATE_FULLSCREEN) != 0;
}
