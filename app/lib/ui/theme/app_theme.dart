import 'package:flutter/material.dart';

/// 设计令牌：深空背景 + 冰蓝/电紫/极光绿，Liquid Glass 玻璃质感。
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF05060B);
  static const Color surface = Color(0xFF0C0F18);

  static const Color ice = Color(0xFF6EE7FF);
  static const Color violet = Color(0xFFA78BFA);
  static const Color aurora = Color(0xFF4ADE80);
  static const Color ember = Color(0xFFFF8A5C);
  static const Color rose = Color(0xFFFF5D8F);

  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textSecondary = Color(0x99F5F7FF);
  static const Color textTertiary = Color(0x66F5F7FF);

  static const LinearGradient coldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[ice, Color(0xFF5B8CFF), violet],
  );

  static const LinearGradient heatGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[ember, rose, violet],
  );

  static const Curve spring = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 720);

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: ice,
        secondary: violet,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _FadeThroughBuilder(),
          TargetPlatform.windows: _FadeThroughBuilder(),
        },
      ),
    );
  }
}

/// 轻微上浮 + 淡入的页面切换。
class _FadeThroughBuilder extends PageTransitionsBuilder {
  const _FadeThroughBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppTheme.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.035),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// 数字显示用的字形。
TextStyle numberStyle({
  double size = 64,
  FontWeight weight = FontWeight.w600,
  Color color = AppTheme.textPrimary,
  double letterSpacing = -2,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.0,
    fontFeatures: const <FontFeature>[
      FontFeature.tabularFigures(),
    ],
  );
}
