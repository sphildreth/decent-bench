#ifndef RUNNER_WINDOW_PLACEMENT_PLUGIN_H_
#define RUNNER_WINDOW_PLACEMENT_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

class WindowPlacementPlugin {
 public:
  struct Bounds {
    int x;
    int y;
    int width;
    int height;
  };

  WindowPlacementPlugin(FlBinaryMessenger* messenger, GtkWindow* window);
  ~WindowPlacementPlugin();

 private:
  static void MethodCallHandler(FlMethodChannel* channel,
                                FlMethodCall* method_call,
                                gpointer user_data);
  static gboolean ConfigureEvent(GtkWidget* widget,
                                 GdkEventConfigure* event,
                                 gpointer user_data);
  static gboolean WindowStateEvent(GtkWidget* widget,
                                   GdkEventWindowState* event,
                                   gpointer user_data);

  FlMethodResponse* HandleMethodCall(FlMethodCall* method_call);
  FlValue* CapturePlacement();
  void RestorePlacement(FlValue* arguments);
  void RememberNormalBounds();
  bool IsMaximized() const;
  bool IsFullscreen() const;

  FlMethodChannel* channel_;
  GtkWindow* window_;
  Bounds last_normal_bounds_;
  bool has_last_normal_bounds_ = false;
  GdkWindowState window_state_ = static_cast<GdkWindowState>(0);
};

#endif  // RUNNER_WINDOW_PLACEMENT_PLUGIN_H_
