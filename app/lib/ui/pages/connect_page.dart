import 'package:flutter/material.dart';

import '../../core/ble/ble_bridge.dart';
import '../../core/controller/cooler_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

/// 扫描 / 连接页。
class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.controller, required this.onConnected});

  final CoolerController controller;
  final VoidCallback onConnected;

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[c, _pulse]),
      builder: (context, _) {
        final scanning = c.connection == BleConnectionState.scanning;
        final connecting = c.connection == BleConnectionState.connecting;
        return GlowBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const _BrandMark(),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'B9X',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: AppTheme.textPrimary,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '磁吸散热器 · 控制中心',
                            style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.4,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: Center(
                      child: _PulseDevice(
                        pulse: _pulse,
                        scanning: scanning,
                        connecting: connecting,
                      ),
                    ),
                  ),
                  if (c.error != null) ...<Widget>[
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      radius: 18,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.error_outline_rounded,
                              color: AppTheme.rose, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.error!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: c.clearError,
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (c.devices.isNotEmpty) ...<Widget>[
                    SectionTitle('发现 ${c.devices.length} 台设备'),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        itemCount: c.devices.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final d = c.devices[i];
                          return GlassPanel(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14),
                            radius: 20,
                            onTap: connecting
                                ? null
                                : () async {
                                    await c.connect(d);
                                    if (c.isConnected) widget.onConnected();
                                  },
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: AppTheme.coldGradient,
                                  ),
                                  child: const Icon(Icons.ac_unit_rounded,
                                      size: 20, color: Color(0xFF04121A)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        d.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        d.id,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textTertiary,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _SignalBars(rssi: d.rssi),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  GlowButton(
                    label: connecting
                        ? '正在连接…'
                        : scanning
                            ? '停止扫描'
                            : '扫描附近的散热器',
                    icon: connecting
                        ? null
                        : scanning
                            ? Icons.stop_rounded
                            : Icons.bluetooth_searching_rounded,
                    expand: true,
                    height: 58,
                    onPressed: connecting
                        ? null
                        : () async {
                            if (scanning) {
                              await c.stopScan();
                            } else {
                              await c.scan();
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        c.enterDemo();
                        widget.onConnected();
                      },
                      child: Text(
                        '没有设备？预览界面 ›',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.ice.withValues(alpha: 0.85),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '请先打开散热器电源，并让它靠近手机',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppTheme.coldGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.ice.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.ac_unit_rounded, color: Color(0xFF04121A), size: 24),
    );
  }
}

class _PulseDevice extends StatelessWidget {
  const _PulseDevice({
    required this.pulse,
    required this.scanning,
    required this.connecting,
  });

  final AnimationController pulse;
  final bool scanning;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final t = pulse.value;
    final active = scanning || connecting;
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (var i = 0; i < 3; i++)
            Transform.scale(
              scale: active ? 0.7 + ((t + i / 3) % 1) * 0.9 : 0.85,
              child: Opacity(
                opacity: active ? (1 - ((t + i / 3) % 1)) * 0.4 : 0.12,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.ice, width: 1.2),
                  ),
                ),
              ),
            ),
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  AppTheme.ice.withValues(alpha: 0.22),
                  AppTheme.violet.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(
              connecting
                  ? Icons.sync_rounded
                  : scanning
                      ? Icons.wifi_tethering_rounded
                      : Icons.bluetooth_rounded,
              size: 42,
              color: active ? AppTheme.ice : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final strength = rssi >= -55 ? 4 : rssi >= -70 ? 3 : rssi >= -80 ? 2 : 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List<Widget>.generate(4, (i) {
        final on = i < strength;
        return Container(
          margin: const EdgeInsets.only(left: 3),
          width: 3,
          height: 6.0 + i * 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: on ? AppTheme.ice : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }
}
