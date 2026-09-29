import 'package:flutter/material.dart';

import 'config/app_theme.dart';
import 'controllers/game_controller.dart';
import 'screens/login_screen.dart';

class RunBetApp extends StatelessWidget {
  const RunBetApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return GameScope(
      controller: controller,
      child: MaterialApp(
        title: 'RUN BET',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }
}

class GameScope extends InheritedNotifier<GameController> {
  const GameScope({
    super.key,
    required GameController controller,
    required super.child,
  }) : super(notifier: controller);

  static GameController of(BuildContext context, {bool listen = true}) {
    if (!listen) {
      final element = context
          .getElementForInheritedWidgetOfExactType<GameScope>();
      final scope = element?.widget as GameScope?;
      assert(scope != null, 'No GameScope found in context');
      return scope!.notifier!;
    }
    final scope = context.dependOnInheritedWidgetOfExactType<GameScope>();
    assert(scope != null, 'No GameScope found in context');
    return scope!.notifier!;
  }
}
