import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../config/app_theme.dart';
import '../config/asset_paths.dart';
import '../config/game_config.dart';
import '../widgets/balance_chip.dart';
import '../widgets/media_backdrop.dart';
import '../widgets/runner_avatar.dart';
import 'race_screen.dart';

class BettingScreen extends StatefulWidget {
  const BettingScreen({super.key});

  @override
  State<BettingScreen> createState() => _BettingScreenState();
}

class _BettingScreenState extends State<BettingScreen> {
  late final Map<int, TextEditingController> _amountControllers = {
    for (final runner in GameConfig.runnerProfiles)
      runner.id: TextEditingController(),
  };
  final Set<int> _selectedRunnerIds = {};
  bool _submitting = false;

  int get _totalBet => _selectedRunnerIds.fold(
    0,
    (total, runnerId) =>
        total + (int.tryParse(_amountControllers[runnerId]!.text) ?? 0),
  );

  @override
  void dispose() {
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setAmount(int amount) {
    if (_selectedRunnerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn ít nhất một runner trước.')),
      );
      return;
    }
    for (final runnerId in _selectedRunnerIds) {
      _amountControllers[runnerId]!.text = amount.toString();
    }
    setState(() {});
  }

  void _allIn(int balance) {
    if (_selectedRunnerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn ít nhất một runner trước.')),
      );
      return;
    }
    final ids = _selectedRunnerIds.toList()..sort();
    final baseAmount = balance ~/ ids.length;
    var remainder = balance % ids.length;
    for (final runnerId in ids) {
      final extra = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder--;
      _amountControllers[runnerId]!.text = (baseAmount + extra).toString();
    }
    setState(() {});
  }

  void _startRace() {
    if (_submitting) return;
    final game = GameScope.of(context, listen: false);
    game.playClick();
    final stakes = <int, int>{};
    for (final runnerId in _selectedRunnerIds) {
      final amount = int.tryParse(_amountControllers[runnerId]!.text.trim());
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nhập tiền lớn hơn 0 cho mọi runner đã chọn.'),
          ),
        );
        return;
      }
      stakes[runnerId] = amount;
    }
    final error = game.placeBets(stakes);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _submitting = true);
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const RaceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return Scaffold(
      body: MediaBackdrop(
        assetPath: AssetPaths.bettingBackground,
        colors: const [Color(0xFF15112D), Color(0xFF3A2449)],
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 58,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        game.playClick();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'PLACE YOUR BET',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    BalanceChip(balance: game.player.balance),
                    const SizedBox(width: 18),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final betPanelWidth = (constraints.maxWidth * 0.34).clamp(
                      310.0,
                      390.0,
                    );
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'CHOOSE YOUR RUNNER',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 1.90,
                                          mainAxisSpacing: 10,
                                          crossAxisSpacing: 10,
                                        ),
                                    itemCount: GameConfig.runnerProfiles.length,
                                    itemBuilder: (context, index) {
                                      final runner =
                                          GameConfig.runnerProfiles[index];
                                      final selected = _selectedRunnerIds
                                          .contains(runner.id);
                                      return _RunnerChoice(
                                        id: runner.id,
                                        name: runner.name,
                                        color: runner.color,
                                        selected: selected,
                                        amountController:
                                            _amountControllers[runner.id]!,
                                        onAmountChanged: (_) => setState(() {}),
                                        onTap: () => setState(() {
                                          if (selected) {
                                            _selectedRunnerIds.remove(
                                              runner.id,
                                            );
                                          } else {
                                            _selectedRunnerIds.add(runner.id);
                                          }
                                        }),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: betPanelWidth,
                            child: Card(
                              margin: EdgeInsets.zero,
                              color: const Color(0xFA0A1D31),
                              elevation: 12,
                              shadowColor: Colors.black87,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                                side: BorderSide(
                                  color: AppTheme.accent.withValues(
                                    alpha: 0.34,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'YOUR BET',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${_selectedRunnerIds.length} runner selected',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'TOTAL: \$$_totalBet',
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        color: _totalBet > game.player.balance
                                            ? Colors.redAccent
                                            : Colors.amber,
                                      ),
                                    ),
                                    Text(
                                      'Payout runner vô địch: ${GameConfig.winnerPayoutMultiplier}×',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        for (final value in [50, 100, 200, 500])
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              child: _QuickBetButton(
                                                label: '\$$value',
                                                onPressed:
                                                    value <=
                                                        game.player.balance
                                                    ? () => _setAmount(value)
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        Expanded(
                                          child: _QuickBetButton(
                                            label: 'ALL',
                                            tooltip: 'All in',
                                            onPressed: game.player.balance > 0
                                                ? () => _allIn(
                                                    game.player.balance,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const Text(
                                      'Profit = payout - tổng tiền cược',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.icon(
                                      onPressed: _submitting
                                          ? null
                                          : _startRace,
                                      icon: const Icon(Icons.flag_rounded),
                                      label: const Text('START RACE'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickBetButton extends StatelessWidget {
  const _QuickBetButton({
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    void handlePressed() {
      GameScope.of(context, listen: false).playClick();
      onPressed?.call();
    }

    final button = SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed == null ? null : handlePressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _RunnerChoice extends StatelessWidget {
  const _RunnerChoice({
    required this.id,
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.amountController,
    required this.onAmountChanged,
  });

  final int id;
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final TextEditingController amountController;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    void handleTap() {
      GameScope.of(context, listen: false).playClick();
      onTap();
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  color.withValues(alpha: 0.22),
                  const Color(0xF20A1D31),
                )
              : const Color(0xEE0A1D31),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? color
                : Colors.white.withValues(alpha: 0.26),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                RunnerAvatar(runnerId: id, color: color, size: 38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline,
                  color: selected ? color : Colors.white38,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text(
                  'STAKE',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: amountController,
                    enabled: selected,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: onAmountChanged,
                    onTap: () {
                      if (!selected) handleTap();
                    },
                    decoration: InputDecoration(
                      hintText: '\$0',
                      isDense: true,
                      filled: true,
                      fillColor: selected
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.22),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
