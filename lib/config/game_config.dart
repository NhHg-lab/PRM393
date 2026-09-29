import 'package:flutter/material.dart';

import '../models/obstacle.dart';

abstract final class GameConfig {
  static const int initialBalance = 5000;
  static const int testingBalance = 10000;
  static const int testingBalanceGrantVersion = 2;
  static const int bailoutAmount = 50;
  static const Duration bailoutDelay = Duration(minutes: 5);
  static const int winnerPayoutMultiplier = 4;
  static const double defaultSoundVolume = 0.9;
  static const double menuMusicVolume = 0.90;
  static const double raceMusicVolume = 0.90;
  static const double countdownVolume = 1.0;
  static const double clickVolume = 0.85;
  static const double jumpVolume = 1.0;
  static const double fallVolume = 1.0;
  static const double resultVolume = 1.0;
  static const double raceLength = 1000;
  static const double minSpeed = 85;
  static const double maxSpeed = 140;
  static const double speedResponse = 2.7;
  // The combined 3-2-1-GO clip contains about 0.5s of leading silence.
  // Start from this offset so its four cues align with the visual countdown.
  static const Duration countdownAudioStartOffset = Duration(
    milliseconds: 500,
  );
  // Let the GO voice finish before replacing the countdown clip with race
  // music. This keeps the two tracks mutually exclusive without cutting GO.
  static const Duration countdownGoTail = Duration(milliseconds: 850);
  static const double jumpDuration = 0.78;
  static const double maxJumpHeight = 78;
  // Matches runner3_fall.webp after its frame delays are accelerated 2x.
  static const double fallDuration = 1.335;
  static const double recoverDuration = 1.50;
  // The fall WebP animates the pose only. Move its widget across the hurdle
  // during the airborne/falling frames, then keep it still while lying down.
  static const double fallTravelDistance = 75;
  static const double fallTravelDurationRatio = 0.75;
  // A fresh probability is generated inside these fair ranges every time a
  // runner reaches a hurdle. No runner owns a permanently better probability.
  static const double minStumbleChance = 0.12;
  static const double maxStumbleChance = 0.28;
  static const double minFallChance = 0.08;
  static const double maxFallChance = 0.25;
  static const double obstacleTriggerDistance = 30;

  static const List<RunnerProfile> runnerProfiles = [
    RunnerProfile(1, 'Red Rocket', Color(0xFFFF5252)),
    RunnerProfile(2, 'Blue Flash', Color(0xFF40C4FF)),
    RunnerProfile(3, 'Golden Storm', Color(0xFFFFD740)),
    RunnerProfile(4, 'Purple Thunder', Color(0xFFE040FB)),
  ];

  static const List<Obstacle> obstacles = [
    Obstacle(id: 1, distance: 250),
    Obstacle(id: 2, distance: 500),
    Obstacle(id: 3, distance: 750),
  ];
}

class RunnerProfile {
  const RunnerProfile(this.id, this.name, this.color);

  final int id;
  final String name;
  final Color color;
}
