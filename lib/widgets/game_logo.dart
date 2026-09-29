import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class GameLogo extends StatefulWidget {
  const GameLogo({super.key, this.compact = false, this.runnerAsset});

  final bool compact;
  final String? runnerAsset;

  @override
  State<GameLogo> createState() => _GameLogoState();
}

class _GameLogoState extends State<GameLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runnerSize = widget.compact ? 56.0 : 88.0;
    return ScaleTransition(
      scale: _scale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.runnerAsset case final runnerAsset?)
            Image.asset(
              runnerAsset,
              width: runnerSize,
              height: runnerSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.directions_run_rounded,
                color: AppTheme.accent,
                size: widget.compact ? 48 : 72,
              ),
            )
          else
            Icon(
              Icons.directions_run_rounded,
              color: AppTheme.accent,
              size: widget.compact ? 48 : 72,
            ),
          Text(
            'RUN BET',
            style: TextStyle(
              fontSize: widget.compact ? 30 : 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const Text(
            'HUMAN RACING GAME',
            style: TextStyle(color: AppTheme.cyan, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}
