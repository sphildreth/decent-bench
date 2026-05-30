#ifndef RUNNER_WINDOW_PLACEMENT_PLUGIN_H_
#define RUNNER_WINDOW_PLACEMENT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>

class WindowPlacementPlugin {
 public:
  WindowPlacementPlugin(flutter::BinaryMessenger* messenger,
                        HWND window_handle);
  ~WindowPlacementPlugin();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableValue CapturePlacement();
  void RestorePlacement(const flutter::EncodableValue* arguments);

  HWND window_handle_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_WINDOW_PLACEMENT_PLUGIN_H_
