import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app.dart';
import '../config/asset_paths.dart';
import '../config/game_config.dart';
import '../controllers/game_controller.dart';
import '../controllers/race_controller.dart';
import '../models/runner.dart';
import '../widgets/race_track.dart';
import 'result_screen.dart';

class RaceScreen extends StatefulWidget {
  const RaceScreen({super.key});

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen>
    with SingleTickerProviderStateMixin {
  late final RaceController _race;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _started = false;
  bool _finishing = false;
  final Map<int, RunnerState> _lastRunnerStates = {};

  @override
  void initState() {
    super.initState();
    _race = RaceController();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final game = GameScope.of(context, listen: false);
    _beginRace(game);
  }

  Future<void> _beginRace(GameController game) async {
    // Use the music player for both countdown and race audio. A single player
    // makes overlap impossible and avoids Android dropping the pooled MP3.
    await game.audio.stopEffects();
    await game.audio.stopMusic();
    await game.audio.playMusic(
      AssetPaths.countdownSound,
      volume: GameConfig.countdownVolume,
      loop: false,
      startPosition: GameConfig.countdownAudioStartOffset,
    );
    if (!mounted) return;
    _race.start();
    for (final runner in _race.runners) {
      _lastRunnerStates[runner.id] = runner.state;
    }
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final delta = _lastElapsed == Duration.zero
        ? 0.0
        : (elapsed - _lastElapsed).inMicroseconds / 1000000;
    _lastElapsed = elapsed;
    final phaseBefore = _race.phase;
    _race.update(delta);
    final game = GameScope.of(context, listen: false);
    if (phaseBefore == RacePhase.countdown &&
        _race.phase == RacePhase.running) {
      _startRaceMusic(game);
    }
    for (final runner in _race.runners) {
      final previous = _lastRunnerStates[runner.id];
      if (previous != runner.state) {
        if (runner.state == RunnerState.jumping) {
          game.audio.playEffect(
            AssetPaths.jumpSound,
            volume: GameConfig.jumpVolume,
          );
        } else if (runner.state == RunnerState.falling) {
          game.audio.playEffect(
            AssetPaths.fallSound,
            volume: GameConfig.fallVolume,
          );
        }
        _lastRunnerStates[runner.id] = runner.state;
      }
    }
    if (_race.phase == RacePhase.complete && !_finishing) {
      _finishing = true;
      _finishRace();
    }
  }

  Future<void> _startRaceMusic(GameController game) async {
    await Future<void>.delayed(GameConfig.countdownGoTail);
    if (!mounted || _race.phase != RacePhase.running) return;
    await game.audio.stopMusic();
    if (!mounted || _race.phase != RacePhase.running) return;
    await game.playRaceMusic();
  }

  Future<void> _finishRace() async {
    _ticker.stop();
    final game = GameScope.of(context, listen: false);
    await game.audio.stopMusic();
    await game.settleRace(_race.ranking);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const ResultScreen()));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _race.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context, listen: false);
    final bet = game.currentBet!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF10261F),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _race,
            builder: (context, _) {
              return Column(
                children: [
                  Container(
                    height: 58,
                    color: Colors.black.withValues(alpha: 0.35),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showBet = constraints.maxWidth >= 650;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sports_score_rounded,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'HUMAN RACE',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (showBet) ...[
                                Text(
                                  'Bets: ${bet.stakes.length} runners  •  \$${bet.totalAmount}',
                                ),
                                const SizedBox(width: 20),
                              ],
                              Text(
                                '${_race.ranking.length}/4 FINISHED',
                                maxLines: 1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: RaceTrack(
                      controller: _race,
                      selectedRunnerIds: bet.stakes.keys.toSet(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
