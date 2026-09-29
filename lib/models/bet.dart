class Bet {
  Bet({required Map<int, int> stakes, this.settled = false})
    : stakes = Map<int, int>.unmodifiable(stakes);

  final Map<int, int> stakes;
  bool settled;

  int get totalAmount =>
      stakes.values.fold(0, (total, amount) => total + amount);

  int amountFor(int runnerId) => stakes[runnerId] ?? 0;
}
