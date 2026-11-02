#ifndef RUNNER_BLE_BRIDGE_H_
#define RUNNER_BLE_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <vector>

#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>

// Custom window message used to marshal BLE callbacks onto the UI thread.
#define WM_BLE_EVENT (WM_APP + 0x51)

// Bridges the Flutter side (MethodChannel / EventChannel) to the WinRT BLE API.
//
// Channels mirror the Android implementation so the Dart layer is identical:
//   com.reaflydig.b9x/ble     -> ensureReady / startScan / stopScan /
//                                connect / disconnect / write
//   com.reaflydig.b9x/events  -> scanResult / connection / data / error
class BleBridge {
 public:
  BleBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~BleBridge();

  // Runs queued callbacks that WinRT produced on background threads.
  // Must be called on the UI thread (from the window procedure).
  void FlushEvents();

 private:
  void Post(std::function<void()> fn);
  void Emit(flutter::EncodableMap event);

  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartScan(const std::vector<std::string>& names);
  void StopScan();
  void Connect(uint64_t address);
  void Disconnect();
  void Write(const std::vector<uint8_t>& bytes);
  void Subscribe();
  void Unsubscribe();

  void EmitConnection(const std::string& state, const std::string& id = {},
                      const std::string& name = {});
  void EmitError(const std::string& message);

  HWND window_;
  std::mutex mutex_;
  std::queue<std::function<void()>> queue_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;

  winrt::Windows::Devices::Bluetooth::Advertisement::BluetoothLEAdvertisementWatcher watcher_{nullptr};
  winrt::Windows::Devices::Bluetooth::BluetoothLEDevice device_{nullptr};
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::GattDeviceService service_{nullptr};
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::GattCharacteristic write_char_{nullptr};
  winrt::Windows::Devices::Bluetooth::GenericAttributeProfile::GattCharacteristic notify_char_{nullptr};
  winrt::event_token notify_token_{};
  winrt::event_token watcher_token_{};
  std::vector<std::string> wanted_names_;
};

#endif  // RUNNER_BLE_BRIDGE_H_
