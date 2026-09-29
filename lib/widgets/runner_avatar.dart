import 'package:flutter/material.dart';

import '../config/asset_paths.dart';
import '../models/runner.dart';

class RunnerAvatar extends StatelessWidget {
  const RunnerAvatar({
    super.key,
    required this.runnerId,
    required this.color,
    this.state = RunnerState.running,
    this.size = 54,
  });

  final int runnerId;
  final Color color;
  final RunnerState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final index = runnerId - 1;
    final path = index >= 0 && index < AssetPaths.runners.length
        ? AssetPaths.runners[index].forState(state)
        : '';
    final fallback = _fallback();
    if (path.isEmpty) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }

  Widget _fallback() {
    final icon = switch (state) {
      RunnerState.falling => Icons.personal_injury_rounded,
      RunnerState.recovering => Icons.accessibility_new_rounded,
      RunnerState.finished => Icons.emoji_events_rounded,
      _ => Icons.directions_run_rounded,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.62),
    );
  }
}
