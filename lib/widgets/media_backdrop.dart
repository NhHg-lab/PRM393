import 'package:flutter/material.dart';

class MediaBackdrop extends StatelessWidget {
  const MediaBackdrop({
    super.key,
    required this.assetPath,
    required this.child,
    this.colors = const [Color(0xFF081426), Color(0xFF173B57)],
  });

  final String assetPath;
  final Widget child;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (assetPath.isNotEmpty)
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
