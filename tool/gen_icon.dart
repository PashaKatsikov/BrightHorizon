// ============================================================
// gen_icon.dart — builds the launcher icon layers
// ============================================================
// Produces the three PNGs that `flutter_launcher_icons` consumes, from
// the single piece of source artwork:
//
//   assets/generated/app_icon.png             legacy icon (API < 26)
//   assets/generated/app_icon_background.png  adaptive background layer
//   assets/generated/app_icon_foreground.png  adaptive foreground layer
//
// Run it before the icon tool:
//   dart run tool/gen_icon.dart
//   dart run flutter_launcher_icons
//
// ─────────────────────────────────────────────────────────────
// WHERE THE 74 dp COMES FROM
// ─────────────────────────────────────────────────────────────
// An adaptive icon is a 108 dp canvas of which the launcher may mask away
// everything outside the central 66 dp circle, and animations can crop to
// roughly 72 dp. Sizing the artwork is therefore the whole game
// (`gray_part_pitfalls.md` §16).
//
// The scaling is NOT done here. `flutter_launcher_icons` wraps the
// foreground in an `<inset>` inside
// `res/mipmap-anydpi-v26/ic_launcher.xml`, so whatever this tool emits
// gets shrunk once more by the launcher XML. Pre-scaling the PNG as well
// would compound the two and land the medallion near 50 dp.
//
// So the foreground PNG here is FULL-BLEED — the medallion fills the
// canvas edge to edge — and the XML inset is the single place the size is
// decided. It is set to 18.5 %, which leaves 108 × (1 − 0.37) ≈ 68 dp of
// artwork: comfortably inside every launcher mask, with a little more
// margin than the earlier 74 dp sizing.
//
// ⚠️ Re-running `flutter_launcher_icons` REWRITES that XML and resets the
// inset to its 16 % default (≈ 73.4 dp). Restore `android:inset="18.5%"`
// afterwards; the XML carries a comment saying so.
//
// The background is a radial gradient whose colours are SAMPLED from the
// source rather than hard-coded, so the two layers always agree. That
// matters because the layers move independently: launchers parallax the
// foreground over the background, and a mismatched seam is instantly
// visible.
// ============================================================

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Source artwork.
const String kSource =
    'assets/Bright_Horizon_additional_assets/icon2_brighthorizon.jpg';

const String kOutDir = 'assets/generated';

/// Emitted at 4x the 108 dp grid — enough for xxxhdpi downsampling.
const int kCanvasPx = 1024;

// Medallion geometry, measured off the source artwork as fractions of its
// width/height. The radius is deliberately a little wider than the gold
// rim so the bloom around it survives the circular cut-out instead of
// ending in a hard edge.
const double kDiscCenterX = 0.496;
const double kDiscCenterY = 0.479;
const double kDiscRadius = 0.455;

/// Width of the alpha ramp at the cut-out edge, as a fraction of the
/// radius. Without it the mask aliases into a visibly jagged circle.
const double kFeather = 0.02;

void main() {
  final File src = File(kSource);
  if (!src.existsSync()) {
    stderr.writeln('source artwork not found: $kSource');
    exit(66);
  }
  final img.Image? source = img.decodeImage(src.readAsBytesSync());
  if (source == null) {
    stderr.writeln('could not decode: $kSource');
    exit(65);
  }
  Directory(kOutDir).createSync(recursive: true);

  _write('app_icon.png', _legacyIcon(source));
  _write('app_icon_background.png', _background(source));
  _write('app_icon_foreground.png', _foreground(source));
}

/// Legacy launcher icon: full-bleed square, no mask to respect.
img.Image _legacyIcon(img.Image source) => img.copyResize(
      source,
      width: kCanvasPx,
      height: kCanvasPx,
      interpolation: img.Interpolation.cubic,
    );

/// Radial gradient in the artwork's own violet, sampled from inside the
/// medallion ring and darkened outward.
///
/// The sample points sit on the violet field between the rim and the "R",
/// NOT on the source's corners: the corners are crossed by gold ribbons,
/// and averaging those turns the whole layer muddy brown. Sampling rather
/// than hard-coding still keeps the two layers in step if the artwork is
/// ever swapped — launchers parallax the foreground over the background,
/// so a mismatched seam shows immediately.
img.Image _background(img.Image source) {
  const double ring = 0.226; // ≈ 0.32 r at 45°, comfortably inside the rim
  final img.ColorRgb8 sampled = _averageAt(
    source,
    <List<double>>[
      <double>[kDiscCenterX - ring, kDiscCenterY - ring],
      <double>[kDiscCenterX + ring, kDiscCenterY - ring],
      <double>[kDiscCenterX - ring, kDiscCenterY + ring],
      <double>[kDiscCenterX + ring, kDiscCenterY + ring],
    ],
  );
  // The sampled violet is lit by the artwork's glow, which is too bright
  // to sit behind the medallion. Both stops are scaled down so the disc
  // stays the brightest thing in the tile.
  final img.ColorRgb8 inner = _scale(sampled, 0.72);
  final img.ColorRgb8 outer = _scale(sampled, 0.28);

  final img.Image out = img.Image(
    width: kCanvasPx,
    height: kCanvasPx,
    numChannels: 3,
  );
  final double half = kCanvasPx / 2;
  // Reach past the corners so the gradient does not band before the edge.
  final double maxDist = half * math.sqrt2;

  for (int y = 0; y < kCanvasPx; y++) {
    for (int x = 0; x < kCanvasPx; x++) {
      final double dx = (x + 0.5) - half;
      final double dy = (y + 0.5) - half;
      final double t = (math.sqrt(dx * dx + dy * dy) / maxDist).clamp(0.0, 1.0);
      // Eased so the centre stays open and the falloff happens outward,
      // which is where a launcher mask crops anyway.
      final double e = t * t;
      out.setPixelRgb(
        x,
        y,
        _lerp(inner.r, outer.r, e),
        _lerp(inner.g, outer.g, e),
        _lerp(inner.b, outer.b, e),
      );
    }
  }
  return out;
}

/// The medallion alone, cut out of the artwork onto transparency and
/// filling the canvas edge to edge. The launcher XML inset — not this
/// function — decides the final dp size; see the header.
img.Image _foreground(img.Image source) {
  final int shortest = math.min(source.width, source.height);
  final int radius = (shortest * kDiscRadius).round();
  final int cx = (source.width * kDiscCenterX).round();
  final int cy = (source.height * kDiscCenterY).round();
  final int side = radius * 2;

  // Crop first so the mask and the resize both work on the disc alone.
  final img.Image disc = img.copyCrop(
    source,
    x: cx - radius,
    y: cy - radius,
    width: side,
    height: side,
  );

  return img.copyResize(
    _circleMask(disc),
    width: kCanvasPx,
    height: kCanvasPx,
    interpolation: img.Interpolation.cubic,
  );
}

/// Applies a feathered circular alpha channel to [source] in place.
img.Image _circleMask(img.Image source) {
  final img.Image out = source.convert(numChannels: 4);
  final double half = out.width / 2;
  final double edge = half;
  final double soft = math.max(1.0, half * kFeather);

  for (int y = 0; y < out.height; y++) {
    for (int x = 0; x < out.width; x++) {
      final double dx = (x + 0.5) - half;
      final double dy = (y + 0.5) - half;
      final double dist = math.sqrt(dx * dx + dy * dy);
      final double alpha = ((edge - dist) / soft).clamp(0.0, 1.0);
      final img.Pixel p = out.getPixel(x, y);
      out.setPixelRgba(
        x,
        y,
        p.r.toInt(),
        p.g.toInt(),
        p.b.toInt(),
        (alpha * 255).round(),
      );
    }
  }
  return out;
}

img.ColorRgb8 _averageAt(img.Image source, List<List<double>> points) {
  int r = 0;
  int g = 0;
  int b = 0;
  for (final List<double> p in points) {
    final int x = (source.width * p[0]).round().clamp(0, source.width - 1);
    final int y = (source.height * p[1]).round().clamp(0, source.height - 1);
    final img.Pixel px = source.getPixel(x, y);
    r += px.r.toInt();
    g += px.g.toInt();
    b += px.b.toInt();
  }
  final int n = points.length;
  return img.ColorRgb8(r ~/ n, g ~/ n, b ~/ n);
}

img.ColorRgb8 _scale(img.ColorRgb8 c, double factor) => img.ColorRgb8(
      (c.r * factor).round().clamp(0, 255).toInt(),
      (c.g * factor).round().clamp(0, 255).toInt(),
      (c.b * factor).round().clamp(0, 255).toInt(),
    );

int _lerp(num a, num b, double t) =>
    (a + (b - a) * t).round().clamp(0, 255).toInt();

void _write(String name, img.Image image) {
  final String path = '$kOutDir/$name';
  File(path).writeAsBytesSync(img.encodePng(image));
  stdout.writeln('$path  ${image.width}x${image.height}');
}
