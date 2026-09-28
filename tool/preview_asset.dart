// Dev-only helper: decodes a bundled asset into a PNG so it can be
// eyeballed outside the app (the repo ships .webp, which most viewers
// and diff tools cannot open inline).
//
//   dart run tool/preview_asset.dart <in.webp> <out.png> [maxWidth]
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> argv) {
  if (argv.length < 2) {
    stderr.writeln('usage: preview_asset.dart <in> <out.png> [maxWidth]');
    exit(64);
  }
  final File src = File(argv[0]);
  if (!src.existsSync()) {
    stderr.writeln('not found: ${argv[0]}');
    exit(66);
  }
  final img.Image? decoded = img.decodeImage(src.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('failed to decode: ${argv[0]}');
    exit(65);
  }
  final int maxWidth = argv.length > 2 ? int.parse(argv[2]) : decoded.width;
  final img.Image out = decoded.width > maxWidth
      ? img.copyResize(decoded, width: maxWidth,
          interpolation: img.Interpolation.average)
      : decoded;
  File(argv[1]).writeAsBytesSync(img.encodePng(out));
  stdout.writeln('${argv[1]}  ${out.width}x${out.height} '
      '(source ${decoded.width}x${decoded.height})');
}
