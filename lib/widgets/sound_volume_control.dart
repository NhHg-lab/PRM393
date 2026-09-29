import 'package:flutter/material.dart';

import '../app.dart';
import '../config/app_theme.dart';

class SoundVolumeControl extends StatelessWidget {
  const SoundVolumeControl({
    super.key,
    this.decorated = false,
    this.sliderWidth = 132,
  });

  final bool decorated;
  final double sliderWidth;

  @override
  Widget build(BuildContext context) {
    final game = GameScope.of(context);
    final soundIcon = !game.soundEnabled || game.soundVolume == 0
        ? Icons.volume_off_rounded
        : game.soundVolume < 0.5
        ? Icons.volume_down_rounded
        : Icons.volume_up_rounded;

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: game.soundEnabled ? 'Tắt âm thanh' : 'Bật âm thanh',
          onPressed: game.toggleSound,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              soundIcon,
              key: ValueKey('${game.soundEnabled}-${game.soundVolume}'),
            ),
          ),
        ),
        SizedBox(
          width: sliderWidth,
          child: Slider(
            key: const ValueKey('sound-volume-slider'),
            value: game.soundVolume,
            min: 0,
            max: 1,
            divisions: 10,
            label: '${(game.soundVolume * 100).round()}%',
            onChanged: (value) {
              game.setSoundVolume(value);
            },
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            game.soundEnabled
                ? '${(game.soundVolume * 100).round()}%'
                : 'OFF',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );

    if (!decorated) return controls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.navy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: controls,
    );
  }
}
