#include "ble_bridge.h"

#include <algorithm>
#include <chrono>
#include <thread>

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

constexpr char16_t kServiceUuid[] = u"0000ffe0-0000-1000-8000-00805f9b34fb";
constexpr char16_t kWriteUuid[] = u"0000ffe1-0000-1000-8000-00805f9b34fb";
constexpr char16_t kNotifyUuid[] = u"0000ffe4-0000-1000-8000-00805f9b34fb";

std::string ToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                   static_cast<int>(wide.size()), nullptr, 0,
                                   nullptr, nullptr);
  std::string out(static_cast<size_t>(size), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                        out.data(), size, nullptr, nullptr);
  return out;
}

std::string Lower(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return value;
}

// "AA:BB:CC:DD:EE:FF" -> Bluetooth address (48-bit, little-endian bytes).
bool ParseAddress(const std::string& text, uint64_t* out) {
  unsigned int parts[6] = {0};
  if (::sscanf_s(text.c_str(), "%2x:%2x:%2x:%2x:%2x:%2x", &parts[0], &parts[1],
                 &parts[2], &parts[3], &parts[4], &parts[5]) != 6) {
    return false;
  }
  uint64_t value = 0;
  for (int i = 5; i >= 0; --i) {
    value = (value << 8) | (parts[i] & 0xFF);
  }
  *out = value;
  return true;
}

std::string FormatAddress(uint64_t address) {
  char buffer[32];
  ::sprintf_s(buffer, "%02X:%02X:%02X:%02X:%02X:%02X",
              static_cast<unsigned>((address >> 40) & 0xFF),
              static_cast<unsigned>((address >> 32) & 0xFF),
              static_cast<unsigned>((address >> 24) & 0xFF),
              static_cast<unsigned>((address >> 16) & 0xFF),
              static_cast<unsigned>((address >> 8) & 0xFF),
              static_cast<unsigned>(address & 0xFF));
  return std::string(buffer);
}

}  // namespace

BleBridge::BleBridge(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window) {
  method_channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "com.reaflydig.b9x/ble",
      &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "com.reaflydig.b9x/events",
      &flutter::StandardMethodCodec::GetInstance());
  event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
          [this](const EncodableValue* arguments,
                 std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            sink_ = std::move(events);
            return nullptr;
          },
          [this](const EncodableValue* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> {
            sink_.reset();
            return nullptr;
          }));
}

BleBridge::~BleBridge() {
  StopScan();
  Disconnect();
}

void BleBridge::Post(std::function<void()> fn) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    queue_.push(std::move(fn));
  }
  if (window_ != nullptr) {
    ::PostMessage(window_, WM_BLE_EVENT, 0, 0);
  }
}

void BleBridge::FlushEvents() {
  std::queue<std::function<void()>> pending;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    std::swap(pending, queue_);
  }
  while (!pending.empty()) {
    pending.front()();
    pending.pop();
  }
}

void BleBridge::Emit(EncodableMap event) {
  if (sink_) {
    sink_->Success(EncodableValue(event));
  }
}

void BleBridge::EmitConnection(const std::string& state, const std::string& id,
                               const std::string& name) {
  EncodableMap map;
  map[EncodableValue("type")] = EncodableValue("connection");
  map[EncodableValue("state")] = EncodableValue(state);
  if (!id.empty() || !name.empty()) {
    EncodableMap device;
    device[EncodableValue("id")] = EncodableValue(id);
    device[EncodableValue("name")] = EncodableValue(name);
    map[EncodableValue("device")] = EncodableValue(device);
  }
  Post([this, map]() { Emit(map); });
}

void BleBridge::EmitError(const std::string& message) {
  EncodableMap map;
  map[EncodableValue("type")] = EncodableValue("error");
  map[EncodableValue("message")] = EncodableValue(message);
  Post([this, map]() { Emit(map); });
}

void BleBridge::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "ensureReady") {
    result->Success(EncodableValue(true));
    return;
  }

  if (method == "startScan") {
    std::vector<std::string> names;
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    if (args != nullptr) {
      auto it = args->find(EncodableValue("names"));
      if (it != args->end()) {
        if (const auto* list = std::get_if<EncodableList>(&it->second)) {
          for (const auto& item : *list) {
            if (const auto* text = std::get_if<std::string>(&item)) {
              names.push_back(*text);
            }
          }
        }
      }
    }
    StartScan(names);
    result->Success(EncodableValue(true));
    return;
  }

  if (method == "stopScan") {
    StopScan();
    result->Success();
    return;
  }

  if (method == "connect") {
    std::string id;
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    if (args != nullptr) {
      auto it = args->find(EncodableValue("id"));
      if (it != args->end()) {
        if (const auto* text = std::get_if<std::string>(&it->second)) {
          id = *text;
        }
      }
    }
    uint64_t address = 0;
    if (!ParseAddress(id, &address)) {
      result->Error("BAD_ARGS", "invalid address");
      return;
    }
    Connect(address);
    result->Success();
    return;
  }

  if (method == "disconnect") {
    Disconnect();
    result->Success();
    return;
  }

  if (method == "write") {
    std::vector<uint8_t> bytes;
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    if (args != nullptr) {
      auto it = args->find(EncodableValue("bytes"));
      if (it != args->end()) {
        if (const auto* list = std::get_if<EncodableList>(&it->second)) {
          for (const auto& item : *list) {
            if (const auto* number = std::get_if<int32_t>(&item)) {
              bytes.push_back(static_cast<uint8_t>(*number & 0xFF));
            }
          }
        }
      }
    }
    Write(bytes);
    result->Success(EncodableValue(true));
    return;
  }

  result->NotImplemented();
}

void BleBridge::StartScan(const std::vector<std::string>& names) {
  StopScan();
  wanted_names_.clear();
  for (const auto& name : names) {
    wanted_names_.push_back(Lower(name));
  }

  using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
  watcher_ = BluetoothLEAdvertisementWatcher();
  watcher_.ScanningMode(BluetoothLEScanningMode::Active);
  watcher_token_ = watcher_.Received(
      [this](const BluetoothLEAdvertisementWatcher&,
             const BluetoothLEAdvertisementReceivedEventArgs& args) {
        std::string name = ToUtf8(std::wstring(args.Advertisement().LocalName()));
        if (name.empty()) return;
        if (!wanted_names_.empty()) {
          const std::string lower = Lower(name);
          bool matched = false;
          for (const auto& wanted : wanted_names_) {
            if (lower.rfind(wanted, 0) == 0) {
              matched = true;
              break;
            }
          }
          if (!matched) return;
        }
        const std::string address = FormatAddress(args.BluetoothAddress());
        const int16_t rssi = args.RawSignalStrengthInDBm();

        EncodableMap device;
        device[EncodableValue("id")] = EncodableValue(address);
        device[EncodableValue("name")] = EncodableValue(name);
        device[EncodableValue("rssi")] = EncodableValue(static_cast<int32_t>(rssi));

        EncodableMap event;
        event[EncodableValue("type")] = EncodableValue("scanResult");
        event[EncodableValue("device")] = EncodableValue(device);
        Post([this, event]() { Emit(event); });
      });
  watcher_.Start();
  EmitConnection("scanning");
}

void BleBridge::StopScan() {
  if (watcher_ != nullptr) {
    try {
      watcher_.Stop();
      watcher_.Received(watcher_token_);
    } catch (...) {
    }
    watcher_ = nullptr;
  }
}

void BleBridge::Subscribe() {
  if (notify_char_ == nullptr) return;
  using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;

  notify_char_.WriteClientCharacteristicConfigurationDescriptorAsync(
      GattClientCharacteristicConfigurationDescriptorValue::Notify);

  notify_token_ = notify_char_.ValueChanged(
      [this](const GattCharacteristic&,
             const GattValueChangedEventArgs& args) {
        auto reader = winrt::Windows::Storage::Streams::DataReader::FromBuffer(args.CharacteristicValue());
        std::vector<uint8_t> bytes(reader.UnconsumedBufferLength());
        if (!bytes.empty()) {
          reader.ReadBytes(bytes);
        }
        EncodableList list;
        list.reserve(bytes.size());
        for (const auto byte : bytes) {
          list.push_back(EncodableValue(static_cast<int32_t>(byte)));
        }
        EncodableMap event;
        event[EncodableValue("type")] = EncodableValue("data");
        event[EncodableValue("bytes")] = EncodableValue(list);
        Post([this, event]() { Emit(event); });
      });
}

void BleBridge::Unsubscribe() {
  if (notify_char_ != nullptr) {
    try {
      notify_char_.ValueChanged(notify_token_);
    } catch (...) {
    }
  }
  notify_char_ = nullptr;
  write_char_ = nullptr;
}

void BleBridge::Connect(uint64_t address) {
  StopScan();
  Disconnect();
  EmitConnection("connecting");

  using namespace winrt::Windows::Devices::Bluetooth;
  using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;

  const std::string id = FormatAddress(address);

  BluetoothLEDevice::FromBluetoothAddressAsync(address)
      .Completed([this, id](const auto& async, auto status) {
        if (status != winrt::Windows::Foundation::AsyncStatus::Completed) {
          EmitError("连接失败");
          EmitConnection("disconnected");
          return;
        }
        auto device = async.GetResults();
        if (device == nullptr) {
          EmitError("找不到设备");
          EmitConnection("disconnected");
          return;
        }
        device_ = device;
        const std::string name = ToUtf8(std::wstring(device_.Name()));

        const winrt::guid service_guid(kServiceUuid);
        device_.GetGattServicesForUuidAsync(service_guid)
            .Completed([this, id, name](const auto& async, auto status) {
              if (status != winrt::Windows::Foundation::AsyncStatus::Completed) {
                EmitError("服务发现失败");
                EmitConnection("disconnected");
                return;
              }
              auto result = async.GetResults();
              if (result.Status() != GattCommunicationStatus::Success ||
                  result.Services().Size() == 0) {
                EmitError("设备未提供 FFE0 服务");
                EmitConnection("disconnected");
                return;
              }
              service_ = result.Services().GetAt(0);

              service_.GetCharacteristicsForUuidAsync(winrt::guid(kWriteUuid))
                  .Completed([this, id, name](const auto& w_async, auto w_status) {
                    if (w_status == winrt::Windows::Foundation::AsyncStatus::Completed) {
                      auto w_result = w_async.GetResults();
                      if (w_result.Characteristics().Size() > 0) {
                        write_char_ = w_result.Characteristics().GetAt(0);
                      }
                    }
                    service_.GetCharacteristicsForUuidAsync(winrt::guid(kNotifyUuid))
                        .Completed([this, id, name](const auto& n_async, auto n_status) {
                          if (n_status == winrt::Windows::Foundation::AsyncStatus::Completed) {
                            auto n_result = n_async.GetResults();
                            if (n_result.Characteristics().Size() > 0) {
                              notify_char_ = n_result.Characteristics().GetAt(0);
                            }
                          }
                          Subscribe();
                          EmitConnection("connected", id, name);
                        });
                  });
            });
      });
}

void BleBridge::Disconnect() {
  Unsubscribe();
  service_ = nullptr;
  device_ = nullptr;
}

void BleBridge::Write(const std::vector<uint8_t>& bytes) {
  if (write_char_ == nullptr || bytes.empty()) return;
  using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
  using namespace winrt::Windows::Storage::Streams;

  winrt::Windows::Storage::Streams::DataWriter writer;
  writer.WriteBytes(bytes);
  auto buffer = writer.DetachBuffer();
  write_char_.WriteValueWithResultAsync(buffer, GattWriteOption::WriteWithoutResponse)
      .Completed([](const auto& async, auto status) {
        (void)async;
        (void)status;
      });
}
