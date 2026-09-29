import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  if (arguments.length != 2) {
    throw ArgumentError('Usage: contact_sheet.dart <input.gif> <output.png>');
  }
  final animation = img.decodeGif(File(arguments[0]).readAsBytesSync());
  if (animation == null) throw StateError('Unable to decode ${arguments[0]}');

  const columns = 8;
  const step = 4;
  const cell = 144;
  const imageSize = 120;
  final sampled = <int>[
    for (var index = 0; index < animation.numFrames; index += step) index,
  ];
  final rows = (sampled.length / columns).ceil();
  final sheet = img.Image(width: columns * cell, height: rows * cell)
    ..clear(img.ColorRgb8(8, 29, 48));

  for (var sample = 0; sample < sampled.length; sample++) {
    final frameIndex = sampled[sample];
    final frame = img.copyResize(
      animation.frames[frameIndex],
      width: imageSize,
      height: imageSize,
    );
    final x = (sample % columns) * cell + 12;
    final y = (sample ~/ columns) * cell + 20;
    img.compositeImage(sheet, frame, dstX: x, dstY: y);
    img.drawString(
      sheet,
      '$frameIndex',
      font: img.arial14,
      x: x,
      y: y - 16,
      color: img.ColorRgb8(255, 215, 64),
    );
  }
  File(arguments[1]).writeAsBytesSync(img.encodePng(sheet));
}
