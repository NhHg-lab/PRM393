import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/asset_paths.dart';
import '../config/game_config.dart';
import '../controllers/race_controller.dart';
import '../models/runner.dart';
import 'runner_avatar.dart';

class RaceTrack extends StatelessWidget {
  const RaceTrack({
    super.key,
    required this.controller,
    required this.selectedRunnerIds,
  });

  final RaceController controller;
  final Set<int> selectedRunnerIds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final geometry = _TrackGeometry(Size(width, height));
        // The supplied hurdle PNG has transparent padding around the artwork.
        // A lane-sized canvas makes the visible hurdle roughly 55% of a lane
        // tall, while this foot-based offset plants both posts on the track.
        final obstacleCanvasSize = geometry.laneSpacing.clamp(54.0, 76.0);

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: _TrackBackground(path: AssetPaths.raceBackground),
              ),
              for (var lane = 0; lane < controller.runners.length; lane++)
                for (final obstacle in GameConfig.obstacles)
                  Positioned(
                    left: geometry.xForProgress(
                      obstacle.distance / GameConfig.raceLength,
                      lane,
                    ) - obstacleCanvasSize * 0.47,
                    top:
                        geometry.laneCenter(lane) - obstacleCanvasSize * 0.66,
                    child: SizedBox.square(
                      dimension: obstacleCanvasSize,
                      child: Image.asset(
                        AssetPaths.hurdle,
                        key: ValueKey('hurdle-${lane + 1}-${obstacle.id}'),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.fence_rounded,
                          color: Colors.orange.shade300,
                          size: obstacleCanvasSize * 0.55,
                        ),
                      ),
                    ),
                  ),
              for (var lane = 0; lane < controller.runners.length; lane++)
                _runnerPosition(
                  controller.runners[lane],
                  lane,
                  geometry,
                ),
              if (controller.countdownLabel case final label?)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.accent, width: 2),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _runnerPosition(
    Runner runner,
    int lane,
    _TrackGeometry geometry,
  ) {
    const size = 100.0;
    final progress = (runner.distance / GameConfig.raceLength).clamp(0.0, 1.0);
    final isSelected = selectedRunnerIds.contains(runner.id);
    return Positioned(
      left: geometry.xForProgress(progress, lane) - size * 0.5,
      // The runner artwork's feet sit near the bottom of its square canvas.
      // Lift the canvas slightly so the feet rest inside the painted lane
      // instead of straddling its lower white line.
      top: geometry.laneCenter(lane) - size * 0.73,
      child: Transform.translate(
        // Show a clearly readable hurdle jump while keeping the runner close
        // enough to their own lane on compact landscape screens.
        offset: Offset(0, -runner.jumpHeight * 0.34),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isSelected)
                const Positioned(
                  top: -18,
                  child: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: AppTheme.accent,
                    size: 22,
                  ),
                ),
              RunnerAvatar(
                runnerId: runner.id,
                color: runner.color,
                state: runner.state,
                size: size,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackBackground extends StatelessWidget {
  const _TrackBackground({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final fallback = const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF356859), Color(0xFF6B3F2B)],
        ),
      ),
    );
    if (path.isEmpty) return fallback;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Converts coordinates from the supplied 1870×841 race artwork into the
/// actual BoxFit.cover rectangle. Keeping all game objects in this coordinate
/// system makes them stay on the painted lanes on every landscape device.
class _TrackGeometry {
  _TrackGeometry(Size viewport)
    : scale = math.max(
        viewport.width / sourceSize.width,
        viewport.height / sourceSize.height,
      ),
      offset = _coverOffset(viewport);

  static const sourceSize = Size(1870, 841);
  // The painted start line is diagonal. These are the measured X centers
  // where it crosses lanes 1–4 in race.png. Runners wait one body-width
  // behind it, inside the painted lane-number area, instead of covering it.
  static const List<double> sourceStartLineXs = [335, 315.5, 295.5, 275];
  static const double sourceStartingInset = 90;
  static const double sourceFinishX = 1580;
  static const List<double> sourceLaneCenters = [305, 435, 568, 710];

  final double scale;
  final Offset offset;

  static Offset _coverOffset(Size viewport) {
    final imageScale = math.max(
      viewport.width / sourceSize.width,
      viewport.height / sourceSize.height,
    );
    return Offset(
      (viewport.width - sourceSize.width * imageScale) / 2,
      (viewport.height - sourceSize.height * imageScale) / 2,
    );
  }

  double get laneSpacing {
    final gaps = <double>[
      for (var index = 1; index < sourceLaneCenters.length; index++)
        sourceLaneCenters[index] - sourceLaneCenters[index - 1],
    ];
    return gaps.reduce(math.min) * scale;
  }

  double laneCenter(int lane) =>
      offset.dy + sourceLaneCenters[lane] * scale;

  double xForProgress(double progress, int lane) {
    final startX = sourceStartLineXs[lane] - sourceStartingInset;
    final sourceX = startX +
        (sourceFinishX - startX) * progress.clamp(0.0, 1.0);
    return offset.dx + sourceX * scale;
  }
}
