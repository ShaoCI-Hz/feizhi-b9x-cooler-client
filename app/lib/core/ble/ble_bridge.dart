import 'dart:async';

import 'package:flutter/services.dart';

/// 扫描到的设备。
class BleDeviceInfo {
  const BleDeviceInfo({
    required this.id,
    required this.name,
    this.rssi = 0,
  });

  final String id;
  final String name;
  final int rssi;

  factory BleDeviceInfo.fromMap(Map<Object?, Object?> map) => BleDeviceInfo(
        id: (map['id'] as String?) ?? '',
        name: (map['name'] as String?) ?? '',
        rssi: (map['rssi'] as num?)?.toInt() ?? 0,
      );
}

enum BleConnectionState { idle, scanning, connecting, connected, disconnecting }

class BleEvent {
  const BleEvent({
    required this.type,
    this.device,
    this.state,
    this.bytes,
    this.message,
  });

  final String type;
  final BleDeviceInfo? device;
  final String? state;
  final Uint8List? bytes;
  final String? message;
}

/// 平台 BLE 通道。
///
/// Android 侧是 Kotlin 的 `android.bluetooth`，Windows 侧是 C++/WinRT 的
/// `Windows.Devices.Bluetooth`，两端实现同一套协议：
///  - `startScan` / `stopScan`
///  - `connect(id)` / `disconnect()`
///  - `write(bytes)` → FFE1（Write Without Response）
///  - 事件流：scanResult / connection / data / error
class BleBridge {
  BleBridge._();

  static final BleBridge instance = BleBridge._();

  static const MethodChannel _methods =
      MethodChannel('com.reaflydig.b9x/ble');
  static const EventChannel _events = EventChannel('com.reaflydig.b9x/events');

  Stream<BleEvent>? _stream;

  Stream<BleEvent> get events {
    return _stream ??= _events.receiveBroadcastStream().map((dynamic raw) {
      final map = (raw as Map<Object?, Object?>);
      final type = (map['type'] as String?) ?? 'unknown';
      final rawBytes = map['bytes'] as List<Object?>?;
      return BleEvent(
        type: type,
        device: map['device'] == null
            ? null
            : BleDeviceInfo.fromMap(map['device'] as Map<Object?, Object?>),
        state: map['state'] as String?,
        bytes: rawBytes == null
            ? null
            : Uint8List.fromList(
                rawBytes.map((e) => (e as num).toInt()).toList(),
              ),
        message: map['message'] as String?,
      );
    });
  }

  Future<bool> ensureReady() async {
    try {
      return await _methods.invokeMethod<bool>('ensureReady') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> startScan({List<String> names = const <String>[]}) =>
      _methods.invokeMethod<void>('startScan', <String, Object>{
        'names': names,
      });

  Future<void> stopScan() => _methods.invokeMethod<void>('stopScan');

  Future<void> connect(String id) =>
      _methods.invokeMethod<void>('connect', <String, Object>{'id': id});

  Future<void> disconnect() => _methods.invokeMethod<void>('disconnect');

  Future<void> write(Uint8List data) =>
      _methods.invokeMethod<void>('write', <String, Object>{
        'bytes': data.toList(),
      });
}
