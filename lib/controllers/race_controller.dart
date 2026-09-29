import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/game_config.dart';
import '../models/runner.dart';

enum RacePhase { ready, countdown, running, complete }

class RaceController extends ChangeNotifier {
  RaceController({Random? random}) : _random = random ?? Random() {
    _createRunners();
  }

  final Random _random;
  final List<Runner> runners = [];
  final List<Runner> ranking = [];
  RacePhase phase = RacePhase.ready;
  double countdownRemaining = 3;
  double goLabelRemaining = 0;
  double raceElapsed = 0;

  String? get countdownLabel {
    if (phase == RacePhase.countdown) {
      return countdownRemaining.ceil().clamp(1, 3).toString();
    }
    if (goLabelRemaining > 0) return 'GO!';
    return null;
  }

  void _createRunners() {
    runners
      ..clear()
      ..addAll(
        GameConfig.runnerProfiles.map(
          (profile) =>
              Runner(id: profile.id, name: profile.name, color: profile.color),
        ),
      );
  }

  void start() {
    if (phase != RacePhase.ready) return;
    ranking.clear();
    raceElapsed = 0;
    countdownRemaining = 3;
    goLabelRemaining = 0;
    for (final runner in runners) {
      runner.speed = _randomSpeed();
      runner.targetSpeed = _randomSpeed();
      runner.nextSpeedChangeIn = _nextSpeedInterval();
      runner.state = RunnerState.idle;
    }
    phase = RacePhase.countdown;
    notifyListeners();
  }

  void update(double rawDeltaSeconds) {
    if (phase == RacePhase.ready || phase == RacePhase.complete) return;
    final delta = rawDeltaSeconds.clamp(0.0, 0.05);
    if (phase == RacePhase.countdown) {
      countdownRemaining -= delta;
      if (countdownRemaining <= 0) {
        countdownRemaining = 0;
        phase = RacePhase.running;
        goLabelRemaining = 0.65;
        for (final runner in runners) {
          runner.state = RunnerState.running;
        }
      }
      notifyListeners();
      return;
    }

    raceElapsed += delta;
    goLabelRemaining = max(0, goLabelRemaining - delta);
    final finishers = <_FinishRecord>[];
    for (final runner in runners) {
      if (runner.isFinished) continue;
      final previousDistance = runner.distance;
      _updateRunner(runner, delta);
      if (runner.distance >= GameConfig.raceLength) {
        final travelled = runner.distance - previousDistance;
        final fraction = travelled <= 0
            ? 1.0
            : ((GameConfig.raceLength - previousDistance) / travelled).clamp(
                0.0,
                1.0,
              );
        finishers.add(
          _FinishRecord(runner, raceElapsed - delta + delta * fraction),
        );
      }
    }

    finishers.sort((a, b) => a.time.compareTo(b.time));
    for (final record in finishers) {
      final runner = record.runner;
      runner.distance = GameConfig.raceLength;
      runner.speed = 0;
      runner.targetSpeed = 0;
      runner.jumpHeight = 0;
      runner.state = RunnerState.finished;
      runner.finishTime = record.time;
      runner.rank = ranking.length + 1;
      ranking.add(runner);
    }

    if (ranking.length == runners.length) phase = RacePhase.complete;
    notifyListeners();
  }

  void _updateRunner(Runner runner, double delta) {
    _updateTargetSpeed(runner, delta);
    switch (runner.state) {
      case RunnerState.running:
        runner.speed +=
            (runner.targetSpeed - runner.speed) *
            GameConfig.speedResponse *
            delta;
        runner.distance += runner.speed * delta;
        _tryStartObstacle(runner);
      case RunnerState.jumping:
        runner.stateElapsed += delta;
        final progress = (runner.stateElapsed / runner.stateDuration).clamp(
          0.0,
          1.0,
        );
        runner.jumpHeight =
            4 * GameConfig.maxJumpHeight * progress * (1 - progress);
        runner.distance += runner.speed * 0.90 * delta;
        if (progress >= 1) _completeJump(runner);
      case RunnerState.stumbling:
        runner.stateElapsed += delta;
        runner.distance += runner.speed * 0.35 * delta;
        if (runner.stateElapsed >= runner.stateDuration) {
          _setState(runner, RunnerState.running);
          runner.speed = max(GameConfig.minSpeed, runner.speed * 0.8);
        }
      case RunnerState.falling:
        final previousProgress = _fallTravelProgress(runner);
        runner.stateElapsed += delta;
        final currentProgress = _fallTravelProgress(runner);
        runner.distance +=
            GameConfig.fallTravelDistance *
            (currentProgress - previousProgress);
        runner.speed = max(0, runner.speed - 350 * delta);
        if (runner.stateElapsed >= runner.stateDuration) {
          _setState(
            runner,
            RunnerState.recovering,
            duration: GameConfig.recoverDuration,
          );
          runner.speed = 0;
        }
      case RunnerState.recovering:
        runner.stateElapsed += delta;
        if (runner.stateElapsed >= runner.stateDuration) {
          _setState(runner, RunnerState.running);
          runner.speed = GameConfig.minSpeed * 0.75;
          runner.targetSpeed = _randomSpeed();
        }
      case RunnerState.idle:
      case RunnerState.finished:
        break;
    }
    runner.distance = runner.distance.clamp(0, GameConfig.raceLength + 1);
  }

  void _updateTargetSpeed(Runner runner, double delta) {
    if (runner.state == RunnerState.falling ||
        runner.state == RunnerState.recovering) {
      return;
    }
    runner.nextSpeedChangeIn -= delta;
    if (runner.nextSpeedChangeIn <= 0) {
      runner.targetSpeed = _randomSpeed();
      runner.nextSpeedChangeIn = _nextSpeedInterval();
    }
  }

  void _tryStartObstacle(Runner runner) {
    for (final obstacle in GameConfig.obstacles) {
      if (runner.handledObstacleIds.contains(obstacle.id)) continue;
      if (runner.distance >=
          obstacle.distance - GameConfig.obstacleTriggerDistance) {
        runner.handledObstacleIds.add(obstacle.id);
        final fallChance = _randomBetween(
          GameConfig.minFallChance,
          GameConfig.maxFallChance,
        );
        final stumbleChance = _randomBetween(
          GameConfig.minStumbleChance,
          GameConfig.maxStumbleChance,
        );
        final roll = _random.nextDouble();
        final outcome = roll < fallChance
            ? ObstacleOutcome.fall
            : roll < fallChance + stumbleChance
            ? ObstacleOutcome.stumble
            : ObstacleOutcome.success;
        runner.pendingObstacleOutcome = outcome;

        // Fall media is authored as one continuous jump -> fall sequence.
        // Starting the procedural jump first would make that motion play
        // twice and create a visible snap when the fall asset begins.
        if (outcome == ObstacleOutcome.fall) {
          runner.pendingObstacleOutcome = null;
          runner.jumpHeight = 0;
          _setState(
            runner,
            RunnerState.falling,
            duration: GameConfig.fallDuration,
          );
          return;
        }
        _setState(
          runner,
          RunnerState.jumping,
          duration: GameConfig.jumpDuration,
        );
        return;
      }
    }
  }

  void _completeJump(Runner runner) {
    runner.jumpHeight = 0;
    final outcome = runner.pendingObstacleOutcome ?? ObstacleOutcome.success;
    runner.pendingObstacleOutcome = null;
    switch (outcome) {
      case ObstacleOutcome.success:
        _setState(runner, RunnerState.running);
      case ObstacleOutcome.stumble:
        _setState(runner, RunnerState.stumbling, duration: 0.52);
      case ObstacleOutcome.fall:
        _setState(
          runner,
          RunnerState.falling,
          duration: GameConfig.fallDuration,
        );
    }
  }

  void _setState(Runner runner, RunnerState state, {double duration = 0}) {
    runner.state = state;
    runner.stateElapsed = 0;
    runner.stateDuration = duration;
  }

  double _fallTravelProgress(Runner runner) {
    if (runner.stateDuration <= 0) return 1;
    final movingDuration =
        runner.stateDuration * GameConfig.fallTravelDurationRatio;
    final progress = (runner.stateElapsed / movingDuration).clamp(0.0, 1.0);
    // The runner already has forward momentum on the first frame of the GIF.
    // Ease-out starts the canvas moving immediately, then gently stops it as
    // the artwork reaches the lying-down frames.
    final remaining = 1 - progress;
    return 1 - remaining * remaining * remaining;
  }

  double _randomSpeed() =>
      GameConfig.minSpeed +
      _random.nextDouble() * (GameConfig.maxSpeed - GameConfig.minSpeed);

  double _randomBetween(double minimum, double maximum) =>
      minimum + _random.nextDouble() * (maximum - minimum);

  double _nextSpeedInterval() => 0.30 + _random.nextDouble() * 0.40;
}

class _FinishRecord {
  const _FinishRecord(this.runner, this.time);

  final Runner runner;
  final double time;
}
