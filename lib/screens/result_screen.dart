import 'dart:math';

import 'package:flutter/material.dart';

import '../app.dart';
import '../config/app_theme.dart';
import '../config/asset_paths.dart';
import '../config/game_config.dart';
import '../models/race_result.dart';
import '../widgets/balance_chip.dart';
import '../widgets/media_backdrop.dart';
import '../widgets/runner_avatar.dart';
import 'betting_screen.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebration;
  bool _soundPlayed = false;

  @override
  void initState() {
    super.initState();
    _celebration = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_soundPlayed) return;
    _soundPlayed = true;
    final game = GameScope.of(context, listen: false);
    final result = game.currentResult;
    if (result != null) {
      final sound = result.playerWon
          ? AssetPaths.winSound
          : result.playerLost
          ? AssetPaths.loseSound
          : AssetPaths.breakEvenSound;
      game.audio.playEffect(sound, volume: GameConfig.resultVolume);
    }
  }

  @override
  void dispose() {
    _celebration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final result = game.currentResult;
    if (result == null) {
      return const Scaffold(
        body: Center(child: Text('Không tìm thấy kết quả.')),
      );
    }
    final title = result.playerWon
        ? 'YOU WIN!'
        : result.playerLost
        ? 'BETTER LUCK NEXT TIME!'
        : 'BREAK EVEN';
    final background = result.playerWon
        ? AssetPaths.winBackground
        : result.playerLost
        ? AssetPaths.loseBackground
        : AssetPaths.breakEvenBackground;
    final colors = result.playerWon
        ? const [Color(0xFF102A1F), Color(0xFF5A4312)]
        : result.playerLost
        ? const [Color(0xFF111A2B), Color(0xFF37233E)]
        : const [Color(0xFF102536), Color(0xFF3A3B22)];

    return Scaffold(
      body: MediaBackdrop(
        assetPath: background,
        colors: colors,
        child: SafeArea(
          child: Stack(
            children: [
              if (result.playerWon)
                CelebrationParticles(animation: _celebration),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: _OutcomePanel(
                            title: title,
                            result: result,
                            animation: _celebration,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 7,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ResultSummary(result: result),
                                  const SizedBox(height: 12),
                                  _RankingBoard(result: result),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        flex: 2,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: BalanceChip(
                                            balance: result.balanceAfter,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 14,
                                            ),
                                          ),
                                          onPressed: game.player.balance > 0
                                              ? () {
                                                  game.playClick();
                                                  game.prepareNextRound();
                                                  Navigator.of(
                                                    context,
                                                  ).pushReplacement(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          const BettingScreen(),
                                                    ),
                                                  );
                                                }
                                              : null,
                                          icon: const Icon(
                                            Icons.replay_rounded,
                                          ),
                                          label: const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('PLAY AGAIN'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 14,
                                            ),
                                          ),
                                          onPressed: () {
                                            game.playClick();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const StatisticsScreen(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.bar_chart_rounded,
                                          ),
                                          label: const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('SUMMARY'),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 14,
                                            ),
                                          ),
                                          onPressed: () {
                                            game.playClick();
                                            game.prepareNextRound();
                                            Navigator.of(context)
                                                .pushAndRemoveUntil(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const HomeScreen(),
                                                  ),
                                                  (_) => false,
                                                );
                                          },
                                          icon: const Icon(Icons.home_rounded),
                                          label: const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('HOME'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({
    required this.title,
    required this.result,
    required this.animation,
  });

  final String title;
  final RaceResult result;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final color = result.playerWon
        ? AppTheme.accent
        : result.playerLost
        ? Colors.blueGrey.shade200
        : AppTheme.cyan;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: Tween(begin: 0.90, end: 1.10).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          ),
          child: Icon(
            result.playerWon
                ? Icons.emoji_events_rounded
                : result.playerLost
                ? Icons.sports_score_rounded
                : Icons.balance_rounded,
            size: 90,
            color: color,
          ),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Winner: ${result.winner.name}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, color: AppTheme.cyan),
        ),
        const SizedBox(height: 10),
        Text(
          '${result.profit >= 0 ? '+' : ''}\$${result.profit}',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: result.profit > 0
                ? Colors.greenAccent
                : result.profit < 0
                ? Colors.redAccent
                : Colors.white,
          ),
        ),
        const Text('NET PROFIT', style: TextStyle(color: Colors.white60)),
      ],
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.result});

  final RaceResult result;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InfoTile(label: 'Selections', value: '${result.stakes.length}'),
        _InfoTile(label: 'Total bet', value: '\$${result.totalBetAmount}'),
        _InfoTile(label: 'Winning stake', value: '\$${result.winningStake}'),
        _InfoTile(label: 'Payout', value: '\$${result.payout}'),
        _InfoTile(
          label: 'Profit',
          value: '${result.profit >= 0 ? '+' : ''}\$${result.profit}',
          color: result.profit >= 0 ? Colors.greenAccent : Colors.redAccent,
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingBoard extends StatelessWidget {
  const _RankingBoard({required this.result});

  final RaceResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final runner in result.ranking)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '#${runner.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: runner.rank == 1 ? AppTheme.accent : Colors.white,
                    ),
                  ),
                  RunnerAvatar(
                    runnerId: runner.id,
                    color: runner.color,
                    state: runner.state,
                    size: 38,
                  ),
                  Text(
                    runner.name,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  Text(
                    result.stakeFor(runner.id) > 0
                        ? 'Bet \$${result.stakeFor(runner.id)}'
                        : 'No bet',
                    style: TextStyle(
                      fontSize: 10,
                      color: result.stakeFor(runner.id) > 0
                          ? Colors.amber
                          : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CelebrationParticles extends AnimatedWidget {
  const CelebrationParticles({super.key, required Animation<double> animation})
    : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(animation.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(17);
    const colors = [Colors.amber, Colors.cyan, Colors.pink, Colors.greenAccent];
    for (var i = 0; i < 42; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = (baseY + progress * 80) % size.height;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.75);
      canvas.drawCircle(Offset(x, y), 2 + random.nextDouble() * 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
