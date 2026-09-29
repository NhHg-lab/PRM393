import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: dart run bin/inspect.dart <animation> [...]');
    exitCode = 64;
    return;
  }

  for (final path in arguments) {
    final animation = img.decodeImage(File(path).readAsBytesSync());
    if (animation == null) {
      stderr.writeln('Could not decode $path');
      exitCode = 1;
      continue;
    }
    final durations = animation.frames
        .map((frame) => frame.frameDuration)
        .toList(growable: false);
    final total = durations.fold<int>(0, (sum, duration) => sum + duration);
    stdout.writeln(
      '${File(path).uri.pathSegments.last}: '
      '${animation.width}x${animation.height}, '
      '${animation.numFrames} frames, ${total}ms, durations=$durations',
    );
  }
}
