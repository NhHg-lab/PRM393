import 'package:flutter/material.dart';

import '../app.dart';
import '../config/app_theme.dart';
import '../config/asset_paths.dart';
import '../widgets/balance_chip.dart';
import '../widgets/media_backdrop.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final player = game.player;
    return Scaffold(
      body: MediaBackdrop(
        assetPath: AssetPaths.statisticsBackground,
        colors: const [Color(0xFF061B2C), Color(0xFF164A41)],
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 14,
              ),
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.insights_rounded,
                          size: 76,
                          color: AppTheme.accent,
                        ),
                        const Text(
                          'GAME SUMMARY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          player.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        BalanceChip(balance: player.balance),
                        if (player.lastWinner.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Last winner: ${player.lastWinner}'),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            game.playClick();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('BACK'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 7,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          childAspectRatio: 2.25,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          children: [
                            _Stat(
                              label: 'Total races',
                              value: '${player.totalRaces}',
                            ),
                            _Stat(
                              label: 'Win rate',
                              value: '${player.winRate.toStringAsFixed(1)}%',
                            ),
                            _Stat(
                              label: 'Wins',
                              value: '${player.wins}',
                              color: Colors.greenAccent,
                            ),
                            _Stat(
                              label: 'Losses',
                              value: '${player.losses}',
                              color: Colors.redAccent,
                            ),
                            _Stat(
                              label: 'Break even',
                              value: '${player.draws}',
                              color: AppTheme.cyan,
                            ),
                            _Stat(
                              label: 'Total bet',
                              value: '\$${player.totalBet}',
                            ),
                            _Stat(
                              label: 'Total payout',
                              value: '\$${player.totalPayout}',
                            ),
                            _Stat(
                              label: 'Biggest profit',
                              value: '\$${player.biggestWin}',
                            ),
                            _Stat(
                              label: 'Net result',
                              value:
                                  '${player.netProfit >= 0 ? '+' : ''}\$${player.netProfit}',
                              color: player.netProfit >= 0
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
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
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
