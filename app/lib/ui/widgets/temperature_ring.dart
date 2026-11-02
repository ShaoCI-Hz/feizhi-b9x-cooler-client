import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 环形温度表：双弧 + 发光 + 平滑数值。
class TemperatureRing extends StatelessWidget {
  const TemperatureRing({
    super.key,
    required this.temperature,
    required this.targetTemperature,
    required this.speed,
    required this.coldVolts,
    required this.windVolts,
  });

  final double temperature;
  final int targetTemperature;
  final int speed;
  final double coldVolts;
  final double windVolts;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: temperature, end: temperature),
        duration: const Duration(milliseconds: 600),
        curve: AppTheme.spring,
        builder: (context, value, _) {
          final heat = ((value + 12) / 48).clamp(0.06, 1.0);
          final accent = Color.lerp(AppTheme.ice, AppTheme.ember, heat)!;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: Size.infinite,
                painter: _RingPainter(
                  value: value,
                  heat: heat,
                  accent: accent,
                  coldVolts: coldVolts,
                  windVolts: windVolts,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    value.toStringAsFixed(1),
                    style: numberStyle(size: 86, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.thermostat_rounded, size: 16, color: AppTheme.textTertiary),
                      Text(
                        ' $targetTemperature°',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Text(
                      '$speed RPM',
                      style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: AppTheme.textSecondary,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.heat,
    required this.accent,
    required this.coldVolts,
    required this.windVolts,
  });

  final double value;
  final double heat;
  final Color accent;
  final double coldVolts;
  final double windVolts;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 26;

    // 外圈底
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(center, radius, base);

    // 温度弧：从 -220° 扫到 40°
    const startAngle = -math.pi * 1.22;
    const sweepMax = math.pi * 1.44;
    final sweep = sweepMax * heat.clamp(0.02, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepMax,
        colors: <Color>[
          AppTheme.ice.withValues(alpha: 0.9),
          accent,
          AppTheme.rose,
        ],
        transform: const GradientRotation(0),
      ).createShader(rect);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.drawArc(rect, startAngle, sweep, false, glow);
    canvas.drawArc(rect, startAngle, sweep, false, arcPaint);

    // 冷/风 双弧（内圈）
    final innerRadius = radius - 30;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final coldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.ice.withValues(alpha: 0.75);
    final windPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.violet.withValues(alpha: 0.75);

    final coldF = ((coldVolts - 1.5) / 3.0).clamp(0.0, 1.0);
    final windF = ((windVolts - 1.5) / 3.0).clamp(0.0, 1.0);

    canvas.drawArc(
      innerRect,
      math.pi * 0.15,
      math.pi * 0.7 * coldF,
      false,
      coldPaint,
    );
    canvas.drawArc(
      innerRect,
      math.pi * 0.85,
      math.pi * 0.7 * windF,
      false,
      windPaint,
    );

    // 刻度点
    final tick = Paint()..color = Colors.white.withValues(alpha: 0.18);
    for (var i = 0; i <= 24; i++) {
      final a = startAngle + sweepMax * (i / 24);
      final p = Offset(
        center.dx + math.cos(a) * (radius + 16),
        center.dy + math.sin(a) * (radius + 16),
      );
      canvas.drawCircle(p, 1.4, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value ||
      old.coldVolts != coldVolts ||
      old.windVolts != windVolts ||
      old.accent != accent;
}
