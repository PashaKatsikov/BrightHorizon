import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'frames.dart';

class SheetStore extends ChangeNotifier {
  SheetStore._();

  static final instance = SheetStore._();

  final Map<String, Image> _images = {};
  final Map<String, Future<void>> _pending = {};

  Image? image(String asset) => _images[asset];

  Future<void> warm(Iterable<String> assets, {Set<String> fullRes = const {}}) async {
    final jobs = <Future<void>>[];
    for (final asset in assets) {
      if (_images.containsKey(asset)) continue;
      jobs.add(_pending[asset] ??= _decode(asset, full: fullRes.contains(asset)));
    }
    if (jobs.isEmpty) return;
    await Future.wait(jobs);
    notifyListeners();
  }

  Future<void> _decode(String asset, {required bool full}) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: full ? null : 792,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[asset] = frame.image;
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'sheets',
          context: ErrorDescription('While decoding $asset'),
        ),
      );
    } finally {
      _pending.remove(asset);
    }
  }
}

void drawFrame(
  Canvas canvas,
  Image image,
  Frame frame,
  Rect dst, {
  double opacity = 1,
  bool dim = false,
}) {
  if (opacity <= 0) return;
  final sx = image.width / Frame.sheetW;
  final sy = image.height / Frame.sheetH;
  final src = Rect.fromLTRB(
    frame.src.left * sx,
    frame.src.top * sy,
    frame.src.right * sx,
    frame.src.bottom * sy,
  );
  final paint = Paint()
    ..filterQuality = FilterQuality.medium
    ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1));
  if (dim) {
    paint.colorFilter = const ColorFilter.matrix(<double>[
      0.15, 0.15, 0.15, 0, 8,
      0.12, 0.12, 0.12, 0, 6,
      0.18, 0.18, 0.18, 0, 16,
      0, 0, 0, 0.55, 0,
    ]);
  }
  canvas.drawImageRect(image, src, dst, paint);
}

Rect place(
  Size size,
  double cx,
  double cy,
  double widthFrac,
  double aspect, {
  double maxH = 0.5,
}) {
  var w = size.width * widthFrac;
  var h = w / aspect;
  final limit = size.height * maxH;
  if (h > limit && limit > 0) {
    h = limit;
    w = h * aspect;
  }
  return Rect.fromCenter(
    center: Offset(size.width * cx, size.height * cy),
    width: w,
    height: h,
  );
}

Rect letterRect(Size size, {double pulse = 1}) {
  return place(size, 0.50, 0.50, 0.155 * pulse, letterFrame.aspect, maxH: 0.40);
}
