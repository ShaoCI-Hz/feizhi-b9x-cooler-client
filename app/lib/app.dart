import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'core/controller/cooler_controller.dart';
import 'ui/pages/connect_page.dart';
import 'ui/pages/dashboard_page.dart';
import 'ui/pages/led_page.dart';
import 'ui/pages/settings_page.dart';
import 'ui/theme/app_theme.dart';

class B9xApp extends StatefulWidget {
  const B9xApp({super.key});

  @override
  State<B9xApp> createState() => _B9xAppState();
}

class _B9xAppState extends State<B9xApp> {
  final CoolerController _controller = CoolerController();

  @override
  void initState() {
    super.initState();
    _controller.bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B9X',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.isConnected) {
            return ConnectPage(
              controller: _controller,
              onConnected: () {},
            );
          }
          return _Shell(controller: _controller);
        },
      ),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.controller});

  final CoolerController controller;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(
        controller: widget.controller,
        onOpenLed: () => setState(() => _index = 1),
        onOpenSettings: () => setState(() => _index = 2),
      ),
      LedPage(controller: widget.controller),
      SettingsPage(controller: widget.controller),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: _GlassTabBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const List<(IconData, String)> items = <(IconData, String)>[
    (Icons.ac_unit_rounded, '控制'),
    (Icons.looks_rounded, '灯效'),
    (Icons.tune_rounded, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: SafeArea(
        top: false,
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(33),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(33),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Row(
                children: List<Widget>.generate(items.length, (i) {
                  final selected = i == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppTheme.normal,
                          curve: AppTheme.spring,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: selected ? AppTheme.coldGradient : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                items[i].$1,
                                size: 18,
                                color: selected
                                    ? const Color(0xFF04121A)
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                items[i].$2,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight:
                                      selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected
                                      ? const Color(0xFF04121A)
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
