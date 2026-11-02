import 'dart:typed_data';

import 'package:b9x_cooler/core/protocol/b9x_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('档位电压换算', () {
    expect(B9xProtocol.voltsOf(19), closeTo(1.5, 0.01));
    expect(B9xProtocol.voltsOf(134), closeTo(4.53, 0.01));
    expect(B9xProtocol.voltsLabel(115), '4.0V');
    expect(B9xProtocol.voltsLabel(134), '4.5V');
    expect(B9xProtocol.nearestLevel(4.03), 115);
    expect(B9xProtocol.voltsLabel(0), '--');
  });

  test('制冷/风量命令帧', () {
    expect(B9xProtocol.setColdLevel(115), <int>[0x12, 115]);
    expect(B9xProtocol.setSpeedLevel(77), <int>[0x11, 77]);
    expect(B9xProtocol.lightOn(), <int>[0x10, 0xFF]);
    expect(B9xProtocol.lightOff(), <int>[0x10, 0x00]);
  });

  test('智能模式帧', () {
    final frame = B9xProtocol.setRunMode(
      mode: B9xProtocol.modeSmart,
      targetTemperature: 18,
      windLevel: 77,
      coldLevel: 115,
      windLevelOverclock: 77,
      coldLevelOverclock: 134,
    );
    expect(frame, <int>[0x20, 0, 134, 0, 77, 18, 115, 0, 77]);
    // 风速低字节必须保留：77 -> 0x00, 0x4D
    expect(frame[7], 0);
    expect(frame[8], 77);
  });

  test('自定义曲线帧', () {
    final frame = B9xProtocol.setRunMode(
      mode: B9xProtocol.modeCustom,
      customLevels: const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9],
    );
    expect(frame.length, 11);
    expect(frame[0], 0x20);
    expect(frame[1], 4);
    expect(frame[10], 9);
  });

  test('状态帧解析（B9X 20 字节布局）', () {
    final data = Uint8List.fromList(<int>[
      0x13, 0, 0x12, 115, 0, 77, 18, 0xF6, 5, 0x0A, 0, 0, 0x0C, 0x1C,
      0xFF, 3, 0, 0x08, 0x00, 0x3C,
    ]);
    final event = B9xProtocol.parse(data) as StateEvent;
    expect(event.runMode, 1);
    expect(event.overclockUsableLevel, 2);
    expect(event.coldLevel, 115);
    expect(event.windLevel, 77);
    expect(event.temperature, -10);
    expect(event.temperatureDecimal, 5);
    expect(event.speed, 1228);
    expect(event.lightOn, true);
    expect(event.timedShutdownRunning, true);
    expect(event.timeCountdown, 60);
  });

  test('灯效分包与触发帧', () {
    final packets = B9xProtocol.setLedColor(
      type: 3,
      period: 40,
      colors: const <int>[0x112233, 0x445566],
      light: 200,
    );
    expect(packets.length, 2);
    expect(packets.first[0], 0x50);
    expect(packets.first[1], 3);
    expect(packets.first[3], 2);
    expect(packets.first[5], 0x11);
    expect(packets.first[6], 0x22);
    expect(packets.first[7], 0x33);
    expect(packets.last, <int>[0x51, 3]);
  });

  test('定时关机帧', () {
    final frame = B9xProtocol.setTimedShutdown(
      once: true,
      mode: 0,
      seconds: 1800,
    );
    expect(frame, <int>[0x60, 0, 1, 0x07, 0x08]);
  });
}
