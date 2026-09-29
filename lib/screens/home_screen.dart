import 'package:flutter/material.dart';

import '../app.dart';
import '../config/app_theme.dart';
import '../config/asset_paths.dart';
import '../config/game_config.dart';
import '../widgets/balance_chip.dart';
import '../widgets/game_logo.dart';
import '../widgets/media_backdrop.dart';
import '../widgets/sound_volume_control.dart';
import 'betting_screen.dart';
import 'login_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _musicStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_musicStarted) return;
    _musicStarted = true;
    GameScope.of(context, listen: false).ensureMenuMusic();
  }

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    return Scaffold(
      body: MediaBackdrop(
        assetPath: AssetPaths.homeBackground,
        colors: const [Color(0xFF061B2C), Color(0xFF164A41)],
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF03111F).withValues(alpha: 0.18),
                        const Color(0xFF03111F).withValues(alpha: 0.38),
                        const Color(0xFF020A12).withValues(alpha: 0.54),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: _panelDecoration(radius: 24),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: AppTheme.navy,
                            child: Icon(Icons.person_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hello, ${game.player.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                          ),
                          BalanceChip(balance: game.player.balance),
                          const SizedBox(width: 4),
                          const SoundVolumeControl(),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 12, 28, 18),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 30,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1080,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 30,
                                    vertical: 22,
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        flex: 5,
                                        child: Center(
                                          child: GameLogo(
                                            runnerAsset: AssetPaths.homeRunner,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 150,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 30,
                                        ),
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 6,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'CHOOSE YOUR ACTION',
                                                style: TextStyle(
                                                  color: AppTheme.cyan,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.8,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _MenuButton(
                                                    icon: Icons
                                                        .sports_score_rounded,
                                                    label: 'START GAME',
                                                    primary: true,
                                                    onTap:
                                                        game.player.balance > 0
                                                        ? () {
                                                            game
                                                                .prepareNextRound();
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (_) =>
                                                                    const BettingScreen(),
                                                              ),
                                                            );
                                                          }
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _MenuButton(
                                                    icon: Icons
                                                        .bar_chart_rounded,
                                                    label: 'STATISTICS',
                                                    onTap: () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            const StatisticsScreen(),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _MenuButton(
                                                    icon: Icons
                                                        .help_outline_rounded,
                                                    label: 'HOW TO PLAY',
                                                    onTap: () =>
                                                        _showHowToPlay(context),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _MenuButton(
                                                    icon: Icons.logout_rounded,
                                                    label: 'LOGOUT',
                                                    onTap: () {
                                                      game.logout();
                                                      Navigator.of(context)
                                                          .pushAndRemoveUntil(
                                                            MaterialPageRoute(
                                                              builder: (_) =>
                                                                  const LoginScreen(),
                                                            ),
                                                            (_) => false,
                                                          );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (game.player.balance == 0)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  'Hết tiền — nhận \$${GameConfig.bailoutAmount} sau ${game.bailoutCountdownLabel}',
                                                  style: const TextStyle(
                                                    color: Colors.orangeAccent,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to play'),
        content: const Text(
          '1. Chọn một hoặc nhiều vận động viên.\n'
          '2. Nhập tiền cược riêng cho từng runner đã chọn.\n'
          '3. Nhấn Start Race và theo dõi cuộc đua.\n'
          '4. Nhân vật tự chạy, nhảy rào và có thể bị té.\n'
          '5. Tiền cược vào runner vô địch được trả 4×. Kết quả Win/Lose/Hòa vốn được tính theo payout trừ tổng tiền cược.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              GameScope.of(context, listen: false).playClick();
              Navigator.pop(context);
            },
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _panelDecoration({
  required double radius,
  bool accentBorder = false,
}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xEE071A2E), Color(0xF00B2439)],
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: accentBorder
          ? AppTheme.accent.withValues(alpha: 0.52)
          : Colors.white.withValues(alpha: 0.16),
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x99000000),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    void handleTap() {
      GameScope.of(context, listen: false).playClick();
      onTap?.call();
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onTap == null ? null : handleTap,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: primary ? AppTheme.accent : const Color(0xFF173B57),
          foregroundColor: primary ? AppTheme.navy : Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
          elevation: primary ? 6 : 2,
          shadowColor: primary
              ? AppTheme.accent.withValues(alpha: 0.45)
              : Colors.black,
          side: BorderSide(
            color: primary
                ? const Color(0xFFFFDE8B)
                : Colors.white.withValues(alpha: 0.22),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
