import '../protocol/b9x_protocol.dart';

/// 设备的实时状态快照（不可变）。
class CoolerState {
  const CoolerState({
    this.connected = false,
    this.deviceName = 'Flydigi B9X',
    this.temperature = 0,
    this.temperatureDecimal = 0,
    this.hotSurfaceTemperature = 0,
    this.targetTemperature = 0,
    this.coldLevel = 0,
    this.windLevel = 0,
    this.coldLevelOverclock = 0,
    this.windLevelOverclock = 0,
    this.speed = 0,
    this.runMode = B9xProtocol.modeSmart,
    this.overclockUsableLevel = 0,
    this.ledType = 0,
    this.lightOn = false,
    this.coldProtection = false,
    this.coldProtectionEnabled = false,
    this.hotProtectionEnabled = false,
    this.runningInMaxLevel = false,
    this.freezeModeEnabled = false,
    this.timedShutdownRunning = false,
    this.timedShutdownMode = 0,
    this.timedCountdownInMinute = false,
    this.timeCountdown = 0,
    this.quickSwitchRunMode = 0,
    this.firmwareVersion = '',
    this.mac = '',
    this.experimentalModeOn = false,
    this.customLevels = const <int>[0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.ledColors = const <int>[],
    this.ledPeriod = 0,
    this.ledLight = 0,
    this.ledColorful = false,
    this.tempHistory = const <int>[],
  });

  final bool connected;
  final String deviceName;
  final int temperature;
  final int temperatureDecimal;
  final int hotSurfaceTemperature;
  final int targetTemperature;
  final int coldLevel;
  final int windLevel;
  final int coldLevelOverclock;
  final int windLevelOverclock;
  final int speed;
  final int runMode;
  final int overclockUsableLevel;
  final int ledType;
  final bool lightOn;
  final bool coldProtection;
  final bool coldProtectionEnabled;
  final bool hotProtectionEnabled;
  final bool runningInMaxLevel;
  final bool freezeModeEnabled;
  final bool timedShutdownRunning;
  final int timedShutdownMode;
  final bool timedCountdownInMinute;
  final int timeCountdown;
  final int quickSwitchRunMode;
  final String firmwareVersion;
  final String mac;
  final bool experimentalModeOn;
  final List<int> customLevels;
  final List<int> ledColors;
  final int ledPeriod;
  final int ledLight;
  final bool ledColorful;
  final List<int> tempHistory;

  double get temperatureValue => temperature + temperatureDecimal / 10.0;

  /// 智能模式下设备实际使用超频组合值。
  bool get usingOverclock =>
      runMode == B9xProtocol.modeSmart && overclockUsableLevel > 0;

  int get effectiveColdLevel => usingOverclock ? coldLevelOverclock : coldLevel;

  int get effectiveWindLevel => usingOverclock ? windLevelOverclock : windLevel;

  String get runModeName {
    switch (runMode) {
      case B9xProtocol.modeSmart:
        return '智能温控';
      case B9xProtocol.modeManual:
        return '手动';
      case B9xProtocol.modeOverclock:
        return '超频';
      case B9xProtocol.modeExperimentalSmart:
        return '实验智能';
      case B9xProtocol.modeCustom:
        return '自定义曲线';
      default:
        return '未知';
    }
  }

  CoolerState copyWith({
    bool? connected,
    String? deviceName,
    int? temperature,
    int? temperatureDecimal,
    int? hotSurfaceTemperature,
    int? targetTemperature,
    int? coldLevel,
    int? windLevel,
    int? coldLevelOverclock,
    int? windLevelOverclock,
    int? speed,
    int? runMode,
    int? overclockUsableLevel,
    int? ledType,
    bool? lightOn,
    bool? coldProtection,
    bool? coldProtectionEnabled,
    bool? hotProtectionEnabled,
    bool? runningInMaxLevel,
    bool? freezeModeEnabled,
    bool? timedShutdownRunning,
    int? timedShutdownMode,
    bool? timedCountdownInMinute,
    int? timeCountdown,
    int? quickSwitchRunMode,
    String? firmwareVersion,
    String? mac,
    bool? experimentalModeOn,
    List<int>? customLevels,
    List<int>? ledColors,
    int? ledPeriod,
    int? ledLight,
    bool? ledColorful,
    List<int>? tempHistory,
  }) {
    return CoolerState(
      connected: connected ?? this.connected,
      deviceName: deviceName ?? this.deviceName,
      temperature: temperature ?? this.temperature,
      temperatureDecimal: temperatureDecimal ?? this.temperatureDecimal,
      hotSurfaceTemperature: hotSurfaceTemperature ?? this.hotSurfaceTemperature,
      targetTemperature: targetTemperature ?? this.targetTemperature,
      coldLevel: coldLevel ?? this.coldLevel,
      windLevel: windLevel ?? this.windLevel,
      coldLevelOverclock: coldLevelOverclock ?? this.coldLevelOverclock,
      windLevelOverclock: windLevelOverclock ?? this.windLevelOverclock,
      speed: speed ?? this.speed,
      runMode: runMode ?? this.runMode,
      overclockUsableLevel: overclockUsableLevel ?? this.overclockUsableLevel,
      ledType: ledType ?? this.ledType,
      lightOn: lightOn ?? this.lightOn,
      coldProtection: coldProtection ?? this.coldProtection,
      coldProtectionEnabled:
          coldProtectionEnabled ?? this.coldProtectionEnabled,
      hotProtectionEnabled: hotProtectionEnabled ?? this.hotProtectionEnabled,
      runningInMaxLevel: runningInMaxLevel ?? this.runningInMaxLevel,
      freezeModeEnabled: freezeModeEnabled ?? this.freezeModeEnabled,
      timedShutdownRunning: timedShutdownRunning ?? this.timedShutdownRunning,
      timedShutdownMode: timedShutdownMode ?? this.timedShutdownMode,
      timedCountdownInMinute:
          timedCountdownInMinute ?? this.timedCountdownInMinute,
      timeCountdown: timeCountdown ?? this.timeCountdown,
      quickSwitchRunMode: quickSwitchRunMode ?? this.quickSwitchRunMode,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      mac: mac ?? this.mac,
      experimentalModeOn: experimentalModeOn ?? this.experimentalModeOn,
      customLevels: customLevels ?? this.customLevels,
      ledColors: ledColors ?? this.ledColors,
      ledPeriod: ledPeriod ?? this.ledPeriod,
      ledLight: ledLight ?? this.ledLight,
      ledColorful: ledColorful ?? this.ledColorful,
      tempHistory: tempHistory ?? this.tempHistory,
    );
  }

  CoolerState applyStateEvent(StateEvent e) {
    return copyWith(
      temperature: e.temperature,
      temperatureDecimal: e.temperatureDecimal,
      hotSurfaceTemperature: e.hotSurfaceTemperature,
      targetTemperature: e.targetTemperature,
      coldLevel: e.coldLevel,
      windLevel: e.windLevel,
      coldLevelOverclock:
          coldLevelOverclock == 0 ? e.coldLevel : coldLevelOverclock,
      windLevelOverclock:
          windLevelOverclock == 0 ? e.windLevel : windLevelOverclock,
      speed: e.speed,
      runMode: e.runMode,
      overclockUsableLevel: e.overclockUsableLevel,
      ledType: e.ledType,
      lightOn: e.lightOn,
      coldProtection: e.coldProtection,
      coldProtectionEnabled: e.coldProtectionEnabled,
      hotProtectionEnabled: e.hotProtectionEnabled,
      runningInMaxLevel: e.runningInMaxLevel,
      freezeModeEnabled: e.freezeModeEnabled,
      timedShutdownRunning: e.timedShutdownRunning,
      timedShutdownMode: e.timedShutdownMode,
      timedCountdownInMinute: e.timedCountdownInMinute,
      timeCountdown: e.timeCountdown,
      quickSwitchRunMode: e.quickSwitchRunMode,
    );
  }
}
