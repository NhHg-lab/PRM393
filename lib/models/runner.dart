import 'package:flutter/material.dart';

enum RunnerState {
  idle,
  running,
  jumping,
  stumbling,
  falling,
  recovering,
  finished,
}

enum ObstacleOutcome { success, stumble, fall }

class Runner {
  Runner({required this.id, required this.name, required this.color});

  final int id;
  final String name;
  final Color color;
  double distance = 0;
  double speed = 0;
  double targetSpeed = 0;
  double jumpHeight = 0;
  double stateElapsed = 0;
  double stateDuration = 0;
  double nextSpeedChangeIn = 0;
  RunnerState state = RunnerState.idle;
  ObstacleOutcome? pendingObstacleOutcome;
  final Set<int> handledObstacleIds = <int>{};
  int? rank;
  double? finishTime;

  bool get isFinished => state == RunnerState.finished;
}
