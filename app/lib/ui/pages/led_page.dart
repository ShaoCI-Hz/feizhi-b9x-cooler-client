import 'package:flutter/material.dart';

import '../../core/controller/cooler_controller.dart';
import '../../core/protocol/b9x_protocol.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

/// 灯效工作室。
class LedPage extends StatefulWidget {
  const LedPage({super.key, required this.controller});

  final CoolerController controller;

  @override
  State<LedPage> createState() => _LedPageState();
}

class _LedPageState extends State<LedPage> {
  static const List<int> palette = <int>[
    0xFF6EE7FF,
    0xFF5B8CFF,
    0xFFA78BFA,
    0xFFFF5D8F,
    0xFFFF8A5C,
    0xFFFFD166,
    0xFF4ADE80,
    0xFF2DD4BF,
    0xFFFFFFFF,
    0xFF101018,
  ];

  late List<int> _colors = <int>[0xFF6EE7FF];
  late int _type = 3;
  late int _period = 40;
  late int _brightness = 200;
  bool _colorful = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final s = widget.controller.state;
    _type = s.ledType == 0 ? 3 : s.ledType;
    _colors = s.ledColors.isEmpty ? <int>[0xFF6EE7FF] : [...s.ledColors];
    _period = s.ledPeriod == 0 ? 40 : s.ledPeriod;
    _brightness = s.ledLight == 0 ? 200 : s.ledLight;
    _colorful = s.ledColorful;
    _initialized = true;
  }

  Future<void> _apply() => widget.controller.applyLed(
        type: _type,
        period: _period,
        colors: _colors,
        light: _brightness,
        colorful: _colorful,
      );

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final s = widget.controller.state;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '灯效工作室',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '共 ${B9xProtocol.ledTypes.length} 种效果 · 当前 '
                          '${B9xProtocol.ledTypes[s.ledType] ?? '自定义'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GlassSwitch(
                      value: s.lightOn,
                      onChanged: (v) => widget.controller.setLightEnabled(v),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionTitle('灯效'),
                _TypeGrid(
                  selected: _type,
                  onSelected: (t) {
                    setState(() => _type = t);
                    _apply();
                  },
                ),
                const SizedBox(height: 24),
                SectionTitle(
                  '颜色',
                  trailing: Text(
                    '${_colors.length}/8',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final color in palette)
                      _ColorDot(
                        color: color,
                        selected: _colors.contains(color),
                        onTap: () {
                          setState(() {
                            if (_colors.contains(color)) {
                              if (_colors.length > 1) _colors.remove(color);
                            } else if (_colors.length < 8) {
                              _colors.add(color);
                            } else {
                              _colors[_colors.length - 1] = color;
                            }
                          });
                          _apply();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                GlassPanel(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Text('亮度',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppTheme.textSecondary)),
                          const Spacer(),
                          Text(
                            '${(_brightness / 255 * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.ice,
                            ),
                          ),
                        ],
                      ),
                      GlassSlider(
                        value: (_brightness / 255 * 10).round(),
                        steps: 10,
                        onChanged: (i) {
                          setState(
                              () => _brightness = (i / 10 * 255).round());
                          _apply();
                        },
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Text('流转速度',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppTheme.textSecondary)),
                          const Spacer(),
                          Text(
                            _period.toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.violet,
                            ),
                          ),
                        ],
                      ),
                      GlassSlider(
                        value: (_period / 10).round(),
                        steps: 10,
                        activeColor: AppTheme.violet,
                        onChanged: (i) {
                          setState(() => _period = (i * 10).clamp(0, 100));
                          _apply();
                        },
                      ),
                      if (_type == 19)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  '多彩律动',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      color: AppTheme.textSecondary),
                                ),
                              ),
                              GlassSwitch(
                                value: _colorful,
                                activeColor: AppTheme.violet,
                                onChanged: (v) {
                                  setState(() => _colorful = v);
                                  _apply();
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Preview(colors: _colors, type: _type),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = B9xProtocol.ledTypes.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, i) {
        final entry = entries[i];
        final active = entry.key == selected;
        return GestureDetector(
          onTap: () => onSelected(entry.key),
          child: AnimatedContainer(
            duration: AppTheme.normal,
            curve: AppTheme.spring,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: active ? AppTheme.coldGradient : null,
              color: active ? null : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.0)
                    : Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: active
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppTheme.ice.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  _iconFor(entry.key),
                  size: 20,
                  color:
                      active ? const Color(0xFF04121A) : AppTheme.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? const Color(0xFF04121A)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(int type) {
    switch (type) {
      case 0:
        return Icons.lightbulb_outline_rounded;
      case 1:
        return Icons.wb_sunny_rounded;
      case 2:
        return Icons.nightlight_round;
      case 3:
        return Icons.looks_rounded;
      case 4:
        return Icons.donut_large_rounded;
      case 5:
        return Icons.blur_on_rounded;
      case 6:
        return Icons.gradient_rounded;
      case 7:
        return Icons.flash_on_rounded;
      case 8:
        return Icons.brightness_high_rounded;
      case 9:
        return Icons.brightness_low_rounded;
      case 10:
        return Icons.dark_mode_rounded;
      case 11:
        return Icons.light_mode_rounded;
      case 12:
        return Icons.auto_awesome_rounded;
      case 16:
        return Icons.rotate_right_rounded;
      case 17:
        return Icons.favorite_rounded;
      case 19:
        return Icons.graphic_eq_rounded;
      case 20:
        return Icons.bolt_rounded;
      case 21:
        return Icons.blur_circular_rounded;
      case 22:
        return Icons.palette_rounded;
      default:
        return Icons.circle_rounded;
    }
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTheme.fast,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c,
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 2.4 : 1,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(color: c.withValues(alpha: 0.65), blurRadius: 20),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.black87)
            : null,
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.colors, required this.type});

  final List<int> colors;
  final int type;

  @override
  Widget build(BuildContext context) {
    final list = colors.map(Color.new).toList();
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            builder: (context, t, _) => Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: <Color>[...list, list.first],
                  transform: GradientRotation(t * 6.28),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: list.first.withValues(alpha: 0.5),
                    blurRadius: 26,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  B9xProtocol.ledTypes[type] ?? '自定义',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${colors.length} 种颜色 · 实时下发到设备',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
