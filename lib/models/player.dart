class Player {
  Player({
    required this.name,
    required this.balance,
    this.totalRaces = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.totalBet = 0,
    this.totalPayout = 0,
    this.biggestWin = 0,
    this.lastWinner = '',
  });

  String name;
  int balance;
  int totalRaces;
  int wins;
  int losses;
  int draws;
  int totalBet;
  int totalPayout;
  int biggestWin;
  String lastWinner;

  double get winRate => totalRaces == 0 ? 0 : wins * 100 / totalRaces;
  int get netProfit => totalPayout - totalBet;
}
