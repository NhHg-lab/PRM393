import 'dart:io';

import 'package:image/image.dart' as img;

const _runnerIds = [1, 2, 4];
const _fallFrameCount = 80;
// Both output animations must remain on their terminal pose slightly longer
// than the corresponding game state. Otherwise Flutter loops the GIF back to
// frame zero before RaceController advances to the next state.
const _fallLastFrameCentiseconds = 17;
const _recoverLastFrameCentiseconds = 32;

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run bin/build_fall_animations.dart '
      '<source-directory> <output-directory>',
    );
    exitCode = 64;
    return;
  }

  final sourceDirectory = Directory(arguments[0]);
  final outputDirectory = Directory(arguments[1])..createSync(recursive: true);

  for (final runnerId in _runnerIds) {
    final source = File('${sourceDirectory.path}/runner$runnerId.gif');
    final animation = img.decodeGif(source.readAsBytesSync());
    if (animation == null || animation.numFrames <= _fallFrameCount) {
      throw StateError(
        '${source.path} must contain more than $_fallFrameCount frames.',
      );
    }

    final fallEncoder = img.GifEncoder(samplingFactor: 1);
    for (var index = 0; index < _fallFrameCount; index++) {
      // GIF stores delays in centiseconds. Alternating 10/20ms preserves the
      // same 15ms average used by runner3_fall.webp (80 frames / 1.2s).
      fallEncoder.addFrame(
        img.Image.from(animation.frames[index], noAnimation: true),
        duration: index == _fallFrameCount - 1
            ? _fallLastFrameCentiseconds
            : (index.isEven ? 1 : 2),
      );
    }

    final recoverEncoder = img.GifEncoder(samplingFactor: 1);
    for (var index = _fallFrameCount;
        index < animation.numFrames;
        index++) {
      recoverEncoder.addFrame(
        img.Image.from(animation.frames[index], noAnimation: true),
        duration: index == animation.numFrames - 1
            ? _recoverLastFrameCentiseconds
            : 3,
      );
    }

    final fallFile = File(
      '${outputDirectory.path}/runner${runnerId}_fall.gif',
    )..writeAsBytesSync(fallEncoder.finish()!);
    final recoverFile = File(
      '${outputDirectory.path}/runner${runnerId}_recover.gif',
    )..writeAsBytesSync(recoverEncoder.finish()!);

    stdout.writeln(
      'runner$runnerId: '
      '$_fallFrameCount fall frames -> ${fallFile.path}; '
      '${animation.numFrames - _fallFrameCount} recover frames -> '
      '${recoverFile.path}',
    );
  }
}
