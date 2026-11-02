import 'package:flutter/material.dart';

import '../../core/controller/cooler_controller.dart';
import '../../core/model/cooler_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

/// 设置：定时关机、冻结、保护、设备信息、温度历史。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final CoolerController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const List<int> presets = <int>[0, 15, 30, 60, 90, 120];
  int _minutes = 30;
  bool _once = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return GlowBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: c,
          builder: (context, _) {
            final s = c.state;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                const Text(
                  '设置',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 22),
                const SectionTitle('定时关机'),
                GlassPanel(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _statusText(s),
                          const Spacer(),
                          GlassSwitch(
                            value: s.timedShutdownRunning,
                            onChanged: (v) {
                              if (v) {
                                c.setTimedShutdown(
                                  once: _once,
                                  mode: 0,
                                  seconds: _minutes * 60,
                                );
                              } else {
                                c.setTimedShutdown(
                                  once: _once,
                                  mode: 0,
                                  seconds: 0,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final m in presets)
                            _Chip(
                              label: m == 0 ? '关闭' : '$m 分钟',
                              selected: _minutes == m,
                              onTap: () {
                                setState(() => _minutes = m);
                                c.setTimedShutdown(
                                  once: _once,
                                  mode: 0,
                                  seconds: m * 60,
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          const Text(
                            '每次开机都生效',
                            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          ),
                          const Spacer(),
                          GlassSwitch(
                            value: !_once,
                            activeColor: AppTheme.violet,
                            onChanged: (v) {
                              setState(() => _once = !v);
                              c.setTimedShutdown(
                                once: _once,
                                mode: 0,
                                seconds: _minutes * 60,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionTitle('保护与智能'),
                GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Column(
                    children: <Widget>[
                      _SwitchRow(
                        title: '冻结模式',
                        subtitle: '结霜时自动调节，防止冷凝水',
                        value: s.freezeModeEnabled,
                        onChanged: (v) => c.setFreezeMode(v),
                      ),
                      const _Divider(),
                      _SwitchRow(
                        title: '低温保护',
                        subtitle: '环境过冷时限制功率',
                        value: s.coldProtectionEnabled,
                        onChanged: (v) => c.offProtection(low: v),
                      ),
                      const _Divider(),
                      _SwitchRow(
                        title: '高温保护',
                        subtitle: '热面过热时自动降档',
                        value: s.hotProtectionEnabled,
                        onChanged: (v) => c.offProtection(high: v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionTitle('设备'),
                GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Column(
                    children: <Widget>[
                      _InfoRow(label: '设备名称', value: s.deviceName),
                      const _Divider(),
                      _InfoRow(label: 'MAC 地址', value: s.mac.isEmpty ? '—' : s.mac),
                      const _Divider(),
                      _InfoRow(
                        label: '固件版本',
                        value: s.firmwareVersion.isEmpty ? '—' : s.firmwareVersion,
                      ),
                      const _Divider(),
                      _InfoRow(
                        label: '超频能力',
                        value: s.overclockUsableLevel == 2
                            ? '30W'
                            : s.overclockUsableLevel == 1
                                ? '10W'
                                : '不支持',
                      ),
                      const _Divider(),
                      _ActionRow(
                        title: '刷新温度历史',
                        subtitle: '读取设备端温度记录',
                        onTap: c.requestTempHistory,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionTitle('固件'),
                GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Column(
                    children: <Widget>[
                      _InfoRow(
                        label: '当前版本',
                        value: s.firmwareVersion.isEmpty ? '读取中…' : s.firmwareVersion,
                      ),
                      const _Divider(),
                      _ActionRow(
                        title: '固件升级',
                        subtitle: 'Telink OTA · 需要官方固件包',
                        onTap: () => _showFirmwareSheet(context, c),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionTitle('温度历史'),
                _HistoryChart(values: s.tempHistory),
                const SizedBox(height: 22),
                const SectionTitle('危险操作'),
                GlassPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Column(
                    children: <Widget>[
                      _ActionRow(
                        title: '恢复出厂设置',
                        subtitle: '清除设备上的自定义灯效与曲线',
                        danger: true,
                        onTap: () => _confirmReset(context, c),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Rea B9X · 1.0.0\n逆向协议驱动，非官方客户端',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: AppTheme.textTertiary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusText(CoolerState s) {
    if (!s.timedShutdownRunning) {
      return const Text('未启用', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary));
    }
    final total = s.timeCountdown;
    final m = total ~/ 60;
    final sec = total % 60;
    return Text(
      '剩余 ${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.ice,
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  void _showFirmwareSheet(BuildContext context, CoolerController c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: GlassPanel(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.system_update_alt_rounded,
                      color: AppTheme.ice, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    '固件升级',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetContext),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppTheme.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '当前固件：${c.state.firmwareVersion.isEmpty ? '未知' : c.state.firmwareVersion}\n'
                '传输方式：Telink OTA（FFE1 透传）',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.7,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.ember.withValues(alpha: 0.10),
                  border: Border.all(
                    color: AppTheme.ember.withValues(alpha: 0.28),
                  ),
                ),
                child: const Text(
                  '为避免刷砖，升级只接受飞智官方发布的 B9X 固件包。'
                  '升级过程中请保持散热器供电，不要锁屏或离开。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: AppTheme.ember,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GlowButton(
                label: '选择固件包',
                icon: Icons.folder_open_rounded,
                expand: true,
                onPressed: () => Navigator.pop(sheetContext),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'OTA 传输模块将在下一版本开放',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, CoolerController c) async {    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('恢复出厂设置？'),
        content: const Text('设备上的灯效与自定义曲线会被清除，此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认', style: TextStyle(color: AppTheme.rose)),
          ),
        ],
      ),
    );
    if (ok == true) await c.resetFactory();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          GlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: danger ? AppTheme.rose : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: danger ? AppTheme.rose : AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.6, color: Colors.white.withValues(alpha: 0.08));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected ? AppTheme.coldGradient : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF04121A) : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 120,
        child: values.isEmpty
            ? const Center(
                child: Text(
                  '点击上方「刷新温度历史」读取设备记录',
                  style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              )
            : CustomPaint(
                size: Size.infinite,
                painter: _SparkPainter(values.take(120).toList()),
              ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).clamp(1, 200);
    final minV = values.reduce((a, b) => a < b ? a : b) - 4;
    final range = (maxV - minV).clamp(1, 400);
    final path = Path();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = AppTheme.coldGradient.createShader(Offset.zero & size);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          AppTheme.ice.withValues(alpha: 0.28),
          AppTheme.ice.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : size.width * i / (values.length - 1);
      final y = size.height * (1 - (values[i] - minV) / range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}
