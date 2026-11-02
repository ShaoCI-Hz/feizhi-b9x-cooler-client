import 'package:flutter/material.dart';

import '../../core/controller/cooler_controller.dart';
import '../../core/model/cooler_state.dart';
import '../../core/protocol/b9x_protocol.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/temperature_ring.dart';

/// 主控台：温度 + 模式 + 档位。
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.onOpenLed,
    required this.onOpenSettings,
  });

  final CoolerController controller;
  final VoidCallback onOpenLed;
  final VoidCallback onOpenSettings;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _modeTab = 0;

  @override
  void initState() {
    super.initState();
    _modeTab = _tabForMode(widget.controller.state.runMode);
  }

  int _tabForMode(int mode) {
    switch (mode) {
      case B9xProtocol.modeSmart:
        return 0;
      case B9xProtocol.modeManual:
        return 1;
      case B9xProtocol.modeOverclock:
        return 2;
      default:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final s = c.state;
        final tab = _tabForMode(s.runMode);
        if (tab != _modeTab && !c.isBusy) {
          _modeTab = tab;
        }
        return GlowBackground(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                _Header(
                  state: s,
                  onSettings: widget.onOpenSettings,
                  onDisconnect: c.disconnect,
                ),
                const SizedBox(height: 10),
                TemperatureRing(
                  temperature: s.temperatureValue,
                  targetTemperature: s.targetTemperature,
                  speed: s.speed,
                  coldVolts: B9xProtocol.voltsOf(s.effectiveColdLevel),
                  windVolts: B9xProtocol.voltsOf(s.effectiveWindLevel),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    _StatPill(
                      icon: Icons.device_thermostat_rounded,
                      label: '热面',
                      value: '${s.hotSurfaceTemperature}°',
                      accent: AppTheme.ember,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: Icons.bolt_rounded,
                      label: '制冷',
                      value: B9xProtocol.voltsLabel(s.effectiveColdLevel),
                      accent: AppTheme.ice,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: Icons.air_rounded,
                      label: '风量',
                      value: B9xProtocol.voltsLabel(s.effectiveWindLevel),
                      accent: AppTheme.violet,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                SectionTitle('运行模式', trailing: _ModeBadge(state: s)),
                GlassSegmented(
                  items: const <String>['智能', '手动', '超频', '曲线'],
                  index: _modeTab,
                  onChanged: (i) async {
                    setState(() => _modeTab = i);
                    switch (i) {
                      case 0:
                        await c.setSmartLevel(1);
                      case 1:
                        await c.setManual(
                          coldLevel: s.coldLevel == 0 ? 115 : s.coldLevel,
                          windLevel: s.windLevel == 0 ? 77 : s.windLevel,
                        );
                      case 2:
                        await c.setOverclock(
                          coldLevel: s.coldLevelOverclock == 0
                              ? 134
                              : s.coldLevelOverclock,
                          windLevel: s.windLevelOverclock == 0
                              ? 77
                              : s.windLevelOverclock,
                        );
                      case 3:
                        await c.setCustomCurve(s.customLevels);
                    }
                  },
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: AppTheme.normal,
                  switchInCurve: AppTheme.spring,
                  switchOutCurve: Curves.easeOut,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_modeTab),
                    child: _ModePanel(
                      controller: c,
                      state: s,
                      tab: _modeTab,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _LedShortcut(state: s, onTap: widget.onOpenLed, controller: c),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.onSettings,
    required this.onDisconnect,
  });

  final CoolerState state;
  final VoidCallback onSettings;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: state.connected ? AppTheme.aurora : AppTheme.rose,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: (state.connected ? AppTheme.aurora : AppTheme.rose)
                            .withValues(alpha: 0.7),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  state.connected ? '已连接' : '未连接',
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              state.deviceName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const Spacer(),
        _IconGlass(icon: Icons.palette_outlined, onTap: onSettings),
        const SizedBox(width: 10),
        _IconGlass(
          icon: Icons.bluetooth_disabled_rounded,
          onTap: onDisconnect,
        ),
      ],
    );
  }
}

class _IconGlass extends StatelessWidget {
  const _IconGlass({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      radius: 16,
      blur: 16,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 19, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        radius: 18,
        blur: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.state});

  final CoolerState state;

  @override
  Widget build(BuildContext context) {
    final label = state.overclockUsableLevel == 2
        ? '超频 30W'
        : state.overclockUsableLevel == 1
            ? '超频 10W'
            : '标准';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.ice.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.ice.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          color: AppTheme.ice,
        ),
      ),
    );
  }
}

class _ModePanel extends StatelessWidget {
  const _ModePanel({
    required this.controller,
    required this.state,
    required this.tab,
  });

  final CoolerController controller;
  final CoolerState state;
  final int tab;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 0:
        return _SmartPanel(controller: controller, state: state);
      case 1:
        return _ManualPanel(controller: controller, state: state);
      case 2:
        return _OverclockPanel(controller: controller, state: state);
      default:
        return _CurvePanel(controller: controller, state: state);
    }
  }
}

class _SmartPanel extends StatelessWidget {
  const _SmartPanel({required this.controller, required this.state});

  final CoolerController controller;
  final CoolerState state;

  @override
  Widget build(BuildContext context) {
    final idx = _smartIndex(state);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '设备根据热面温度自动调节功率，越冷越安静。',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Row(
              children: <Widget>[
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => controller.setSmartLevel(i),
                      child: AnimatedContainer(
                        duration: AppTheme.normal,
                        curve: AppTheme.spring,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: i == idx ? AppTheme.coldGradient : null,
                          color: i == idx ? null : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: i == idx ? 0.0 : 0.12),
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            Text(
                              <String>['安静', '均衡', '强劲'][i],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: i == idx ? const Color(0xFF04121A) : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              <String>['18°C', '16°C', '16°C'][i],
                              style: TextStyle(
                                fontSize: 11,
                                color: i == idx
                                    ? const Color(0xCC04121A)
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _smartIndex(CoolerState s) {
    if (s.targetTemperature == 18) return 0;
    if (s.windLevel >= 115) return 2;
    return 1;
  }
}

class _ManualPanel extends StatelessWidget {
  const _ManualPanel({required this.controller, required this.state});

  final CoolerController controller;
  final CoolerState state;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LevelRow(
            label: '制冷强度',
            value: B9xProtocol.voltsLabel(state.coldLevel),
            accent: AppTheme.ice,
            index: _LevelRow.nearestIndex(state.coldLevel),
            onChanged: (i) => controller.setColdLevel(B9xProtocol.levels[i]),
          ),
          const SizedBox(height: 8),
          _LevelRow(
            label: '风量',
            value: B9xProtocol.voltsLabel(state.windLevel),
            accent: AppTheme.violet,
            index: _LevelRow.nearestIndex(state.windLevel),
            onChanged: (i) => controller.setWindLevel(B9xProtocol.levels[i]),
          ),
        ],
      ),
    );
  }
}

class _OverclockPanel extends StatelessWidget {
  const _OverclockPanel({required this.controller, required this.state});

  final CoolerController controller;
  final CoolerState state;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.ember),
              const SizedBox(width: 6),
              Text(
                state.overclockUsableLevel == 0
                    ? '当前档位不支持超频'
                    : state.overclockUsableLevel == 2
                        ? '30W 超频可用'
                        : '10W 超频可用',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LevelRow(
            label: '制冷强度',
            value: B9xProtocol.voltsLabel(state.coldLevelOverclock),
            accent: AppTheme.ember,
            index: _LevelRow.nearestIndex(state.coldLevelOverclock),
            onChanged: (i) => controller.setOverclock(
              coldLevel: B9xProtocol.levels[i],
              windLevel: state.windLevelOverclock == 0 ? 77 : state.windLevelOverclock,
            ),
          ),
          const SizedBox(height: 8),
          _LevelRow(
            label: '风量',
            value: B9xProtocol.voltsLabel(state.windLevelOverclock),
            accent: AppTheme.violet,
            index: _LevelRow.nearestIndex(state.windLevelOverclock),
            onChanged: (i) => controller.setOverclock(
              coldLevel: state.coldLevelOverclock == 0 ? 134 : state.coldLevelOverclock,
              windLevel: B9xProtocol.levels[i],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvePanel extends StatelessWidget {
  const _CurvePanel({required this.controller, required this.state});

  final CoolerController controller;
  final CoolerState state;

  @override
  Widget build(BuildContext context) {
    final levels = state.customLevels.length == 9
        ? state.customLevels
        : List<int>.filled(9, 77);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '按 9 段温度区间分配功率，拖动即时下发。',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (var i = 0; i < 9; i++)
                  Expanded(
                    child: _CurveBar(
                      index: i,
                      value: levels[i],
                      onChanged: (v) {
                        final next = [...levels];
                        next[i] = v;
                        controller.setCustomCurve(next);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurveBar extends StatelessWidget {
  const _CurveBar({
    required this.index,
    required this.value,
    required this.onChanged,
  });

  final int index;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final fraction = (value / 175).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) {
              final f = 1 - (d.localPosition.dy / constraints.maxHeight);
              final next = (f.clamp(0.0, 1.0) * 175).round();
              onChanged(next);
            },
            onTapDown: (d) {
              final f = 1 - (d.localPosition.dy / constraints.maxHeight);
              onChanged((f.clamp(0.0, 1.0) * 175).round());
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: AppTheme.fast,
                      width: double.infinity,
                      height: constraints.maxHeight * fraction,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: AppTheme.coldGradient,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppTheme.ice.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 9, color: AppTheme.textTertiary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.index,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Color accent;
  final int index;
  final ValueChanged<int> onChanged;

  /// 设备可能回报非预设档位（如超频 153/173），此时取最接近的一档，
  /// 避免滑块跳到最左端。
  static int nearestIndex(int level) {
    var best = 0;
    var bestDiff = 1 << 30;
    for (var i = 0; i < B9xProtocol.levels.length; i++) {
      final diff = (B9xProtocol.levels[i] - level).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: accent,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        GlassSlider(
          value: index,
          steps: B9xProtocol.levels.length - 1,
          activeColor: accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _LedShortcut extends StatelessWidget {
  const _LedShortcut({
    required this.state,
    required this.onTap,
    required this.controller,
  });

  final CoolerState state;
  final VoidCallback onTap;
  final CoolerController controller;

  @override
  Widget build(BuildContext context) {
    final colors = state.ledColors.isEmpty
        ? <int>[0xFF6EE7FF]
        : state.ledColors;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: colors
                    .map((c) => Color(c))
                    .followedBy(<Color>[Color(colors.first)])
                    .toList(),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(colors.first).withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '灯效工作室',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  B9xProtocol.ledTypes[state.ledType] ?? '自定义',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
        ],
      ),
    );
  }
}
