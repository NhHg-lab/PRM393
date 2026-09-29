import 'runner.dart';

class RaceResult {
  const RaceResult({
    required this.ranking,
    required this.stakes,
    required this.totalBetAmount,
    required this.winningStake,
    required this.playerWon,
    required this.payout,
    required this.profit,
    required this.balanceAfter,
  });

  final List<Runner> ranking;
  final Map<int, int> stakes;
  final int totalBetAmount;
  final int winningStake;
  final bool playerWon;
  final int payout;
  final int profit;
  final int balanceAfter;

  Runner get winner => ranking.first;
  bool get playerLost => profit < 0;
  bool get brokeEven => profit == 0;
  int stakeFor(int runnerId) => stakes[runnerId] ?? 0;
}
