import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ble/ble_bridge.dart';
import '../model/cooler_state.dart';
import '../protocol/b9x_protocol.dart';

class _Outgoing {
  _Outgoing(this.bytes, this.key);

  final Uint8List bytes;
  final String? key;
}

/// 业务控制器：把 BLE 字节流翻译成 UI 可用的状态与命令。
///
/// 所有下行命令都经过一个串行队列：
///  - 同类命令（同一 [key]）会被合并，只发最新值——拖滑杆时不会把 GATT 塞满；
///  - 每条命令之间留出 [commandGap]，给设备固件留出处理时间；
///  - 队列本身是唯一的发送者，避免并发写导致 `writeCharacteristic` 返回 false。
class CoolerController extends ChangeNotifier {
  CoolerController({BleBridge? ble}) : _ble = ble ?? BleBridge.instance;

  final BleBridge _ble;

  static const Duration commandGap = Duration(milliseconds: 45);

  CoolerState state = const CoolerState();
  BleConnectionState connection = BleConnectionState.idle;
  List<BleDeviceInfo> devices = const <BleDeviceInfo>[];
  String? error;

  StreamSubscription<BleEvent>? _sub;
  Timer? _pollTimer;
  bool _ready = false;

  final List<_Outgoing> _queue = <_Outgoing>[];
  bool _pumping = false;

  bool get isConnected => connection == BleConnectionState.connected;
  bool get isBusy =>
      connection == BleConnectionState.connecting ||
      connection == BleConnectionState.disconnecting;

  /// 演示模式：没有硬件时预览完整界面。
  bool demoMode = false;

  void enterDemo() {
    demoMode = true;
    connection = BleConnectionState.connected;
    state = const CoolerState(
      connected: true,
      deviceName: 'Flydigi B9X',
      temperature: -3,
      temperatureDecimal: 2,
      hotSurfaceTemperature: 38,
      targetTemperature: 16,
      coldLevel: 115,
      windLevel: 77,
      coldLevelOverclock: 134,
      windLevelOverclock: 77,
      speed: 2860,
      runMode: B9xProtocol.modeSmart,
      overclockUsableLevel: 2,
      ledType: 3,
      lightOn: true,
      coldProtectionEnabled: true,
      hotProtectionEnabled: true,
      firmwareVersion: '1.2.9',
      mac: 'A4:C1:38:00:00:01',
      customLevels: <int>[40, 60, 80, 100, 120, 140, 155, 170, 175],
      ledColors: <int>[0xFF6EE7FF, 0xFF5B8CFF, 0xFFA78BFA, 0xFFFF5D8F],
      ledPeriod: 40,
      ledLight: 200,
    );
    notifyListeners();
  }

  void bootstrap() {
    _sub ??= _ble.events.listen(_onEvent, onError: (Object e) {
      error = '$e';
      notifyListeners();
    });
  }

  Future<void> ensureReady() async {
    if (_ready) return;
    _ready = await _ble.ensureReady();
    notifyListeners();
  }

  Future<void> scan() async {
    error = null;
    devices = const <BleDeviceInfo>[];
    connection = BleConnectionState.scanning;
    notifyListeners();
    await ensureReady();
    await _ble.startScan(names: B9xProtocol.supportedNames);
  }

  Future<void> stopScan() async {
    await _ble.stopScan();
    if (connection == BleConnectionState.scanning) {
      connection = BleConnectionState.idle;
      notifyListeners();
    }
  }

  Future<void> connect(BleDeviceInfo device) async {
    error = null;
    connection = BleConnectionState.connecting;
    notifyListeners();
    await _ble.stopScan();
    await _ble.connect(device.id);
  }

  Future<void> disconnect() async {
    connection = BleConnectionState.disconnecting;
    _pollTimer?.cancel();
    _queue.clear();
    notifyListeners();
    await _ble.disconnect();
    state = const CoolerState();
    connection = BleConnectionState.idle;
    notifyListeners();
  }

  // ------------------------------------------------------------- 事件处理

  void _onEvent(BleEvent event) {
    switch (event.type) {
      case 'scanResult':
        final device = event.device;
        if (device == null) return;
        final list = [...devices];
        final index = list.indexWhere((d) => d.id == device.id);
        if (index >= 0) {
          list[index] = device;
        } else {
          list.add(device);
        }
        list.sort((a, b) => b.rssi.compareTo(a.rssi));
        devices = list;
        notifyListeners();
      case 'connection':
        _onConnection(event.state ?? '');
      case 'data':
        final bytes = event.bytes;
        if (bytes != null) _onData(bytes);
      case 'error':
        error = event.message;
        notifyListeners();
    }
  }

  void _onConnection(String value) {
    switch (value) {
      case 'scanning':
        connection = BleConnectionState.scanning;
      case 'connecting':
        connection = BleConnectionState.connecting;
      case 'connected':
        connection = BleConnectionState.connected;
        state = state.copyWith(connected: true);
        _afterConnected();
      case 'disconnected':
        connection = BleConnectionState.idle;
        state = state.copyWith(connected: false);
        _pollTimer?.cancel();
        _queue.clear();
      case 'idle':
        if (connection == BleConnectionState.scanning) {
          connection = BleConnectionState.idle;
        }
    }
    notifyListeners();
  }

  void _afterConnected() {
    _pollTimer?.cancel();
    // 握手 + 首次状态拉取。这些请求本身也会换回 0x13 状态帧。
    unawaited(_requestInitialState());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (connection == BleConnectionState.connected) {
        _enqueue(B9xProtocol.getExperimentalRunMode(), key: 'poll');
      }
    });
  }

  Future<void> _requestInitialState() async {
    _enqueue(B9xProtocol.handshake(), key: 'init');
    _enqueue(B9xProtocol.requestMacAddress(), key: 'mac');
    _enqueue(B9xProtocol.readTimedShutdown(), key: 'timer');
    _enqueue(B9xProtocol.requestRunModeParams(4), key: 'curve');
  }

  void _onData(Uint8List bytes) {
    final event = B9xProtocol.parse(bytes);
    if (event == null) return;
    switch (event) {
      case StateEvent():
        state = state.applyStateEvent(event);
      case LedStateEvent():
        state = state.copyWith(
          ledType: event.type,
          ledColors: event.colors,
          ledPeriod: event.period,
          ledLight: event.light,
          ledColorful: event.colorful,
        );
      case CustomLevelsEvent():
        state = state.copyWith(customLevels: event.levels);
      case MacAddressEvent():
        state = state.copyWith(mac: event.mac);
      case FirmwareEvent():
        final v = event.version;
        if (v.length >= 3) {
          state = state.copyWith(
            firmwareVersion: v.substring(0, v.length > 5 ? 5 : v.length),
          );
        }
      case ExperimentalModeEvent():
        state = state.copyWith(experimentalModeOn: event.on);
      case TimedShutdownEvent():
        state = state.copyWith(
          timedShutdownRunning: event.running,
          timedShutdownMode: event.mode,
          timeCountdown: event.seconds,
        );
      case TempHistoryChunkEvent():
        state = state.copyWith(
          tempHistory: [...state.tempHistory, ...event.bytes],
        );
      case TempHistoryDoneEvent():
        break;
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- 下行队列

  void _enqueue(Uint8List bytes, {String? key}) {
    if (demoMode) return;
    if (connection != BleConnectionState.connected) return;
    if (key != null) {
      final index = _queue.indexWhere((item) => item.key == key);
      if (index >= 0) {
        _queue[index] = _Outgoing(bytes, key);
        return;
      }
    }
    _queue.add(_Outgoing(bytes, key));
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        try {
          await _ble.write(item.bytes);
        } catch (_) {
          // 单条失败不应中断后续命令，设备会在下一帧状态里纠正。
        }
        await Future<void>.delayed(commandGap);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _sendMany(List<Uint8List> packets) async {
    for (final packet in packets) {
      _enqueue(packet);
    }
  }

  // ------------------------------------------------------------- 命令

  Future<void> setColdLevel(int level) async {
    state = state.copyWith(coldLevel: level);
    notifyListeners();
    _enqueue(B9xProtocol.setColdLevel(level), key: 'cold');
  }

  Future<void> setWindLevel(int level) async {
    state = state.copyWith(windLevel: level);
    notifyListeners();
    _enqueue(B9xProtocol.setSpeedLevel(level), key: 'wind');
  }

  Future<void> setRunMode({
    required int mode,
    int targetTemperature = 0,
    int windLevel = 0,
    int coldLevel = 0,
    int windLevelOverclock = 0,
    int coldLevelOverclock = 0,
    List<int>? customLevels,
  }) async {
    state = state.copyWith(
      runMode: mode,
      targetTemperature: targetTemperature == 0
          ? state.targetTemperature
          : targetTemperature,
      coldLevel: coldLevel == 0 ? state.coldLevel : coldLevel,
      windLevel: windLevel == 0 ? state.windLevel : windLevel,
      coldLevelOverclock: coldLevelOverclock == 0
          ? state.coldLevelOverclock
          : coldLevelOverclock,
      windLevelOverclock: windLevelOverclock == 0
          ? state.windLevelOverclock
          : windLevelOverclock,
      customLevels: customLevels ?? state.customLevels,
    );
    notifyListeners();
    _enqueue(
      B9xProtocol.setRunMode(
        mode: mode,
        targetTemperature: targetTemperature,
        windLevel: windLevel,
        coldLevel: coldLevel,
        windLevelOverclock: windLevelOverclock,
        coldLevelOverclock: coldLevelOverclock,
        customLevels: customLevels,
      ),
      key: mode == B9xProtocol.modeCustom ? 'mode' : 'mode',
    );
  }

  /// 智能温控三档（设备内置组合：安静 / 均衡 / 强劲）。
  Future<void> setSmartLevel(int index) async {
    const presets = <List<int>>[
      <int>[18, 77, 115, 77, 134],
      <int>[16, 95, 115, 95, 153],
      <int>[16, 115, 115, 134, 173],
    ];
    final p = presets[index.clamp(0, presets.length - 1)];
    await setRunMode(
      mode: B9xProtocol.modeSmart,
      targetTemperature: p[0],
      windLevel: p[1],
      coldLevel: p[2],
      windLevelOverclock: p[3],
      coldLevelOverclock: p[4],
    );
  }

  Future<void> setManual({int coldLevel = 0, int windLevel = 0}) =>
      setRunMode(
        mode: B9xProtocol.modeManual,
        coldLevel: coldLevel == 0 ? state.coldLevel : coldLevel,
        windLevel: windLevel == 0 ? state.windLevel : windLevel,
      );

  Future<void> setOverclock({int coldLevel = 134, int windLevel = 77}) =>
      setRunMode(
        mode: B9xProtocol.modeOverclock,
        coldLevelOverclock: coldLevel,
        windLevelOverclock: windLevel,
      );

  Future<void> setCustomCurve(List<int> values) async {
    state = state.copyWith(customLevels: values);
    notifyListeners();
    _enqueue(
      B9xProtocol.setRunMode(
        mode: B9xProtocol.modeCustom,
        customLevels: values,
      ),
      key: 'curve_set',
    );
  }

  Future<void> setQuickSwitchRunMode(int mode) async {
    state = state.copyWith(quickSwitchRunMode: mode);
    notifyListeners();
    _enqueue(B9xProtocol.setQuickSwitchRunMode(mode), key: 'quick');
  }

  Future<void> setExperimentalMode({
    required bool enabled,
    int level = 0,
    int targetTemperature = 0,
  }) async {
    _enqueue(
      B9xProtocol.setExperimentalRunMode(
        enabled: enabled,
        level: level,
        targetTemperature: targetTemperature,
      ),
      key: 'exp',
    );
  }

  Future<void> setLightEnabled(bool on) async {
    state = state.copyWith(lightOn: on);
    notifyListeners();
    _enqueue(on ? B9xProtocol.lightOn() : B9xProtocol.lightOff(), key: 'light');
  }

  Future<void> applyLed({
    required int type,
    int period = 0,
    List<int> colors = const <int>[],
    int light = 0,
    bool colorful = false,
  }) async {
    state = state.copyWith(
      ledType: type,
      ledPeriod: period,
      ledColors: colors,
      ledLight: light,
      ledColorful: colorful,
      lightOn: type != 0,
    );
    notifyListeners();
    await _sendMany(B9xProtocol.setLedColor(
      type: type,
      period: period,
      colors: colors,
      light: light,
      colorful: colorful,
    ));
  }

  Future<void> setTimedShutdown({
    required bool once,
    required int mode,
    required int seconds,
  }) async {
    state = state.copyWith(
      timedShutdownRunning: seconds > 0,
      timedShutdownMode: mode,
      timeCountdown: seconds,
    );
    notifyListeners();
    _enqueue(
      B9xProtocol.setTimedShutdown(
        once: once,
        mode: mode,
        seconds: seconds,
      ),
      key: 'shutdown',
    );
  }

  Future<void> readTimedShutdown() async {
    _enqueue(B9xProtocol.readTimedShutdown(), key: 'timer');
  }

  Future<void> requestTempHistory() async {
    state = state.copyWith(tempHistory: const <int>[]);
    notifyListeners();
    _enqueue(B9xProtocol.requestTempHistory(), key: 'history');
  }

  /// 冻结模式：设备端结霜保护开关。
  Future<void> setFreezeMode(bool enabled) async {
    state = state.copyWith(freezeModeEnabled: enabled);
    notifyListeners();
    _enqueue(B9xProtocol.setFreezeMode(enabled), key: 'freeze');
  }

  /// 低温/高温保护开关（设备侧自动降档）。
  Future<void> offProtection({bool? low, bool? high}) async {
    if (low != null) {
      state = state.copyWith(coldProtectionEnabled: low);
      notifyListeners();
      _enqueue(
        B9xProtocol.setTempProtect(low: true, enabled: low),
        key: 'protect_low',
      );
    }
    if (high != null) {
      state = state.copyWith(hotProtectionEnabled: high);
      notifyListeners();
      _enqueue(
        B9xProtocol.setTempProtect(low: false, enabled: high),
        key: 'protect_high',
      );
    }
  }

  Future<void> resetFactory() async {
    _enqueue(B9xProtocol.resetFlash(), key: 'reset');
  }

  Future<void> handshake() async {
    _enqueue(B9xProtocol.handshake(), key: 'init');
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sub?.cancel();
    _queue.clear();
    super.dispose();
  }
}
