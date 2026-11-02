import 'dart:typed_data';

/// B9X 散热器的 BLE 协议编解码。
///
/// 全部帧定义与状态位域来自官方 App 逆向结果，详见 `docs/B9X-PROTOCOL.md`。
/// 这里只做纯字节运算，不依赖任何平台 API，方便单元测试。
class B9xProtocol {
  B9xProtocol._();

  // ---------------------------------------------------------------- GATT 常量

  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String writeCharUuid = '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const String notifyCharUuid = '0000ffe4-0000-1000-8000-00805f9b34fb';

  /// 扫描时用于过滤的广播名（B9X 本体）。
  static const String deviceName = 'Flydigi B9X';

  static const List<String> supportedNames = <String>[
    'Flydigi B9X',
    'Flydigi B8X',
    'Flydigi B7X',
    'Flydigi B7',
    'Flydigi B6X',
    'Flydigi B6',
    'Flydigi B5X',
    'Flydigi B5Pro',
    'Flydigi B5',
    'Flydigi Waspwing2 Pro',
  ];

  // ---------------------------------------------------------------- 运行模式

  static const int modeSmart = 0;
  static const int modeManual = 1;
  static const int modeOverclock = 2;
  static const int modeExperimentalSmart = 3;
  static const int modeCustom = 4;

  // ------------------------------------------------------------ 档位（电压）

  /// 可选档位值（0 表示关闭）。
  static const List<int> levels = <int>[0, 19, 38, 57, 77, 95, 115, 134];

  /// 档位值对应电压：`((level - 19) * 0.5 / 19) + 1.5`。
  static double voltsOf(int level) {
    if (level <= 0) return 0;
    return ((level - 19) * 0.5 / 19) + 1.5;
  }

  static String voltsLabel(int level) {
    if (level <= 0) return '--';
    return '${voltsOf(level).toStringAsFixed(1)}V';
  }

  /// 最接近给定电压的档位值。
  static int nearestLevel(double volts) {
    var best = levels.first;
    var bestDiff = double.infinity;
    for (final level in levels) {
      final diff = (voltsOf(level) - volts).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = level;
      }
    }
    return best;
  }

  // -------------------------------------------------------------- 灯效枚举

  static const Map<int, String> ledTypes = <int, String>{
    0: '关闭',
    1: '启动光',
    2: '关机光',
    3: '彩虹流动',
    4: '光环',
    5: '呼吸',
    6: '渐变',
    7: '闪烁',
    8: '双色启动',
    9: '双色关机',
    10: '纯黑',
    11: '长亮',
    12: '智能彩虹',
    16: '多色旋转',
    17: '心跳',
    19: '音乐律动',
    20: '赛博朋克',
    21: '碰撞',
    22: '主题',
  };

  // ---------------------------------------------------------------- 命令帧

  static Uint8List setColdLevel(int level) =>
      Uint8List.fromList(<int>[0x12, level & 0xFF]);

  static Uint8List setSpeedLevel(int level) =>
      Uint8List.fromList(<int>[0x11, level & 0xFF]);

  static Uint8List lightOn() => Uint8List.fromList(<int>[0x10, 0xFF]);

  static Uint8List lightOff() => Uint8List.fromList(<int>[0x10, 0x00]);

  /// 设置运行模式。
  static Uint8List setRunMode({
    required int mode,
    int targetTemperature = 0,
    int windLevel = 0,
    int coldLevel = 0,
    int windLevelOverclock = 0,
    int coldLevelOverclock = 0,
    List<int>? customLevels,
  }) {
    if (mode == modeCustom) {
      final frame = Uint8List(11);
      frame[0] = 0x20;
      frame[1] = mode;
      final levels = customLevels ?? const <int>[];
      for (var i = 0; i < 9 && i < levels.length; i++) {
        frame[2 + i] = levels[i] & 0xFF;
      }
      return frame;
    }
    return Uint8List.fromList(<int>[
      0x20,
      mode & 0xFF,
      coldLevelOverclock & 0xFF,
      (windLevelOverclock ~/ 100) & 0xFF,
      (windLevelOverclock % 100) & 0xFF,
      targetTemperature & 0xFF,
      coldLevel & 0xFF,
      (windLevel ~/ 100) & 0xFF,
      (windLevel % 100) & 0xFF,
    ]);
  }

  static Uint8List requestRunModeParams(int mode) =>
      Uint8List.fromList(<int>[0x22, mode & 0xFF]);

  static Uint8List requestTempHistory() =>
      Uint8List.fromList(<int>[0x40, 0x00]);

  static Uint8List requestMacAddress() =>
      Uint8List.fromList(<int>[0x24, 0x00]);

  static Uint8List resetFlash() => Uint8List.fromList(<int>[0xFF, 0x0A]);

  static Uint8List handshake() =>
      Uint8List.fromList(<int>[0xA5, 0xA0, 0x00, 0x00]);

  static Uint8List setQuickSwitchRunMode(int mode) =>
      Uint8List.fromList(<int>[0x57, mode & 0xFF]);

  static Uint8List setExperimentalRunMode({
    required bool enabled,
    int level = 0,
    int targetTemperature = 0,
  }) =>
      Uint8List.fromList(<int>[
        0x52,
        0x01,
        enabled ? level & 0xFF : 0,
        enabled ? (targetTemperature ~/ 100) & 0xFF : 0,
      ]);

  static Uint8List getExperimentalRunMode() =>
      Uint8List.fromList(<int>[0x52, 0x00]);

  static Uint8List setMaxColdLevel({
    int a = 0,
    int b = 0,
    int c = 0,
    int d = 0,
    int e = 0,
    int f = 0,
  }) =>
      Uint8List.fromList(<int>[0x33, a, b, c, d, e, f]);

  static Uint8List setCustomCurve(List<int> values) {
    final frame = Uint8List(values.length + 2);
    frame[0] = 0x34;
    frame[1] = 0;
    for (var i = 0; i < values.length; i++) {
      frame[i + 2] = values[i] & 0xFF;
    }
    return frame;
  }

  /// 定时关机。[seconds] 为总秒数。
  static Uint8List setTimedShutdown({
    required bool once,
    required int mode,
    required int seconds,
  }) {
    final total = seconds.clamp(0, 0xFFFF);
    return Uint8List.fromList(<int>[
      0x60,
      mode & 0xFF,
      once ? 1 : 0,
      (total >> 8) & 0xFF,
      total & 0xFF,
    ]);
  }

  static Uint8List readTimedShutdown() =>
      Uint8List.fromList(<int>[0x61, 0x00]);

  /// 冻结模式：官方 `ctrlFreezeMode` → `26 01/00 00 00`。
  static Uint8List setFreezeMode(bool enabled) =>
      Uint8List.fromList(<int>[0x26, enabled ? 1 : 0, 0, 0]);

  /// 温度保护：官方 `offTempProtect` → `32 idx value`，idx 0=低温 1=高温。
  static Uint8List setTempProtect({required bool low, required bool enabled}) =>
      Uint8List.fromList(<int>[0x32, low ? 0 : 1, enabled ? 1 : 0]);

  /// 设置灯效（20 字节分包 + 触发帧）。
  static List<Uint8List> setLedColor({
    required int type,
    int period = 0,
    List<int> colors = const <int>[],
    int light = 0,
    bool colorful = false,
  }) {
    final packets = <Uint8List>[];
    final total = colors.length;
    final chunkCount = total > 4 ? 2 : 1;
    for (var chunk = 0; chunk < chunkCount; chunk++) {
      final frame = Uint8List(20);
      frame[0] = 0x50;
      frame[1] = type & 0xFF;
      frame[2] = period & 0xFF;
      frame[3] = total & 0xFF;
      frame[4] = chunk + 1;
      final start = chunk * 4;
      final end = (start + 4).clamp(0, total);
      for (var i = start; i < end; i++) {
        final rgb = colors[i];
        final offset = 5 + (i - start) * 3;
        frame[offset] = (rgb >> 16) & 0xFF;
        frame[offset + 1] = (rgb >> 8) & 0xFF;
        frame[offset + 2] = rgb & 0xFF;
      }
      frame[17] = light & 0xFF;
      frame[18] = (type == 19 && colorful) ? 2 : 0;
      packets.add(frame);
    }
    packets.add(Uint8List.fromList(<int>[0x51, type & 0xFF]));
    return packets;
  }

  // ---------------------------------------------------------------- 状态解析

  static B9xEvent? parse(Uint8List value) {
    if (value.isEmpty) return null;
    final cmd = value[0];
    switch (cmd) {
      case 0x13:
        return _parseState(value);
      case 0x22:
        if (value.length >= 11 && value[1] == 0x04) {
          return CustomLevelsEvent(
            levels: List<int>.generate(9, (i) => value[2 + i] & 0xFF),
          );
        }
        return null;
      case 0x24:
        if (value.length >= 7) {
          final mac = <int>[
            value[6],
            value[5],
            value[4],
            value[3],
            value[2],
            value[1],
          ].map((b) => b & 0xFF).toList();
          return MacAddressEvent(
            mac.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase(),
          );
        }
        return null;
      case 0x40:
      case 0x41:
        return TempHistoryChunkEvent(Uint8List.fromList(value.sublist(1)));
      case 0x42:
        return const TempHistoryDoneEvent();
      case 0x51:
        return _parseLed(value);
      case 0x52:
        if (value.length >= 4) {
          return ExperimentalModeEvent(
            on: (value[2] & 0xFF) == 0xE6 && (value[3] & 0xFF) == 0x39,
            value: value[2] & 0xFF,
          );
        }
        return null;
      case 0x61:
        if (value.length >= 5) {
          return TimedShutdownEvent(
            mode: value[1] & 0xFF,
            running: (value[2] & 0xFF) == 1,
            seconds: ((value[3] & 0xFF) << 8) + (value[4] & 0xFF),
          );
        }
        return null;
      default:
        if (value.length > 5 && cmd >= 0x30 && cmd < 0x80) {
          return FirmwareEvent(_ascii(value));
        }
        return null;
    }
  }

  static String _ascii(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      if (b >= 0x20 && b < 0x7F) buffer.writeCharCode(b);
    }
    return buffer.toString();
  }

  static B9xEvent? _parseLed(Uint8List value) {
    if (value.length < 19) return null;
    final colors = <int>[];
    final total = value[3] & 0xFF;
    final count = value[4] == 1
        ? (total > 4 ? 4 : total)
        : (total - 4).clamp(0, 4);
    for (var i = 0; i < count; i++) {
      final o = 5 + i * 3;
      if (o + 2 >= value.length) break;
      colors.add(
        (value[o] & 0xFF) << 16 |
            (value[o + 1] & 0xFF) << 8 |
            (value[o + 2] & 0xFF),
      );
    }
    return LedStateEvent(
      type: value[1] & 0xFF,
      period: value[2] & 0xFF,
      colors: colors,
      light: value[17] & 0xFF,
      colorful: (value[18] & 0xFF) == 2,
    );
  }

  /// 0x13 状态帧。B9X/B8X 为 20 字节布局，老型号为紧凑布局。
  static B9xEvent? _parseState(Uint8List v) {
    if (v.length < 10) return null;

    if (v.length >= 20) {
      final flags = v[17] & 0xFF;
      return StateEvent(
        ipType: v[1] & 0xFF,
        runMode: (v[2] & 0xFF) >> 4,
        overclockUsableLevel: v[2] & 0x0F,
        coldLevel: v[3] & 0xFF,
        windLevel: _signed(v[4]) * 100 + (v[5] & 0xFF),
        targetTemperature: v[6] & 0xFF,
        temperature: _signed(v[7]),
        temperatureDecimal: v[8] & 0xFF,
        hotSurfaceTemperature: _signed(v[9]),
        coldRunLevel: v[10] & 0xFF,
        windRunLevel: v[11] & 0xFF,
        speed: _signed(v[12]) * 100 + (v[13] & 0xFF),
        lightOn: (v[14] & 0xFF) == 0xFF,
        ledType: v[15] & 0xFF,
        quickSwitchRunMode: v[16] & 0xFF,
        coldProtection: (flags & 0x01) != 0,
        runningInMaxLevel: (flags & 0x02) != 0,
        timedShutdownMode: (flags >> 2) & 0x01,
        timedShutdownRunning: (flags & 0x08) != 0,
        hotProtectionEnabled: ((flags >> 4) & 0x01) != 0 || (flags >> 4) == 2,
        coldProtectionEnabled: ((flags >> 5) & 0x01) != 0,
        timedCountdownInMinute: ((flags >> 6) & 0x01) != 0,
        freezeModeEnabled: ((flags >> 7) & 0x01) != 0,
        timeCountdown: ((v[18] & 0xFF) << 8) + (v[19] & 0xFF),
      );
    }

    final wind = v.length > 18
        ? (v[6] & 0xFF) * 100 + (v[18] & 0xFF)
        : v[6] & 0xFF;
    final speed = v.length > 11 ? (v[11] & 0xFF) * 100 + (v[10] & 0xFF) : 0;
    return StateEvent(
      ipType: v[1] & 0xFF,
      runMode: v[4] & 0xFF,
      overclockUsableLevel: 0,
      coldLevel: v[7] & 0xFF,
      windLevel: wind,
      targetTemperature: v[9] & 0xFF,
      temperature: v[1] == 0 ? -(v[2] & 0xFF) : (v[2] & 0xFF),
      temperatureDecimal: v[3] & 0xFF,
      hotSurfaceTemperature: v.length > 16 ? _signed(v[16]) : 0,
      coldRunLevel: v.length > 15 ? v[15] & 0xFF : 0,
      windRunLevel: v.length > 14 ? v[14] & 0xFF : 0,
      speed: speed,
      lightOn: (v[8] & 0xFF) == 0xFF,
      ledType: 0,
      quickSwitchRunMode: 0,
      coldProtection: (v[17] & 0x0F) == 1,
      runningInMaxLevel: false,
      timedShutdownMode: 0,
      timedShutdownRunning: false,
      hotProtectionEnabled: ((v[17] >> 4) & 0x01) != 0,
      coldProtectionEnabled: false,
      timedCountdownInMinute: false,
      freezeModeEnabled: false,
      timeCountdown: 0,
    );
  }

  static int _signed(int b) => b > 127 ? b - 256 : b;
}

// ------------------------------------------------------------------ 事件类型

sealed class B9xEvent {
  const B9xEvent();
}

class StateEvent extends B9xEvent {
  const StateEvent({
    required this.ipType,
    required this.runMode,
    required this.overclockUsableLevel,
    required this.coldLevel,
    required this.windLevel,
    required this.targetTemperature,
    required this.temperature,
    required this.temperatureDecimal,
    required this.hotSurfaceTemperature,
    required this.coldRunLevel,
    required this.windRunLevel,
    required this.speed,
    required this.lightOn,
    required this.ledType,
    required this.quickSwitchRunMode,
    required this.coldProtection,
    required this.runningInMaxLevel,
    required this.timedShutdownMode,
    required this.timedShutdownRunning,
    required this.hotProtectionEnabled,
    required this.coldProtectionEnabled,
    required this.timedCountdownInMinute,
    required this.freezeModeEnabled,
    required this.timeCountdown,
  });

  final int ipType;
  final int runMode;
  final int overclockUsableLevel;
  final int coldLevel;
  final int windLevel;
  final int targetTemperature;
  final int temperature;
  final int temperatureDecimal;
  final int hotSurfaceTemperature;
  final int coldRunLevel;
  final int windRunLevel;
  final int speed;
  final bool lightOn;
  final int ledType;
  final int quickSwitchRunMode;
  final bool coldProtection;
  final bool runningInMaxLevel;
  final int timedShutdownMode;
  final bool timedShutdownRunning;
  final bool hotProtectionEnabled;
  final bool coldProtectionEnabled;
  final bool timedCountdownInMinute;
  final bool freezeModeEnabled;
  final int timeCountdown;
}

class LedStateEvent extends B9xEvent {
  const LedStateEvent({
    required this.type,
    required this.period,
    required this.colors,
    required this.light,
    required this.colorful,
  });

  final int type;
  final int period;
  final List<int> colors;
  final int light;
  final bool colorful;
}

class CustomLevelsEvent extends B9xEvent {
  const CustomLevelsEvent({required this.levels});
  final List<int> levels;
}

class MacAddressEvent extends B9xEvent {
  const MacAddressEvent(this.mac);
  final String mac;
}

class TempHistoryChunkEvent extends B9xEvent {
  const TempHistoryChunkEvent(this.bytes);
  final Uint8List bytes;
}

class TempHistoryDoneEvent extends B9xEvent {
  const TempHistoryDoneEvent();
}

class ExperimentalModeEvent extends B9xEvent {
  const ExperimentalModeEvent({required this.on, required this.value});
  final bool on;
  final int value;
}

class TimedShutdownEvent extends B9xEvent {
  const TimedShutdownEvent({
    required this.mode,
    required this.running,
    required this.seconds,
  });

  final int mode;
  final bool running;
  final int seconds;
}

class FirmwareEvent extends B9xEvent {
  const FirmwareEvent(this.version);
  final String version;
}
