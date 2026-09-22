import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'catalog.dart';
import 'frames.dart';
import 'observation.dart';
import 'sheets.dart';

class ScenePainter extends CustomPainter {
  ScenePainter({required this.game, required this.store});

  final Observation game;
  final SheetStore store;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = store.image(game.room.background);
    if (bg != null) {
      final src = ui.Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble());
      final scale = math.max(size.width / src.width, size.height / src.height);
      final dst = ui.Rect.fromLTWH(
        (size.width - src.width * scale) / 2,
        (size.height - src.height * scale) / 2,
        src.width * scale,
        src.height * scale,
      );
      canvas.drawImageRect(bg, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
    } else {
      canvas.drawRect(Offset.zero & size, ui.Paint()..color = const Color(0xFF140C28));
    }

    for (final piece in game.room.dressing) {
      if (!piece.floor) continue;
      _piece(canvas, size, piece, 1);
    }

    final draws = <_Stamp>[];
    for (final piece in game.room.dressing) {
      if (piece.floor) continue;
      final rect = place(size, piece.x, piece.y, piece.width, piece.frame.aspect, maxH: 0.46);
      draws.add(_Stamp(piece.frame, rect, piece.y + rect.height / size.height * 0.5, 1));
    }

    final orbX = 0.5 + math.sin(game.elapsed * 0.33) * 0.26;
    final orbY = 0.20 + math.cos(game.elapsed * 0.27) * 0.04;
    final orb = place(size, orbX, orbY, 0.09, orbFrame.aspect);
    draws.add(_Stamp(orbFrame, orb, orbY, 0.8));

    final pulse = 1 + math.sin(game.elapsed * 2.4) * 0.03 + game.rFlash * 0.07;
    final letter = letterRect(size, pulse: pulse);
    draws.add(_Stamp(letterFrame, letter, 0.50, 1));

    for (final actor in game.actors) {
      final rect = actorRectOf(actor, size);
      var opacity = 1.0;
      if (actor.age < 0.18) opacity = actor.age / 0.18;
      if (actor.life < 0.8) {
        opacity *= 0.45 + 0.55 * (0.5 + 0.5 * math.sin(actor.age * 14));
      }
      final sort = actor.y + (actor.behind ? -0.16 : 0);
      draws.add(_Stamp(actor.item.frame, rect, sort, opacity.clamp(0.15, 1), kind: actor.item.kind, rare: actor.key));
    }

    draws.sort((a, b) => a.sort.compareTo(b.sort));
    for (final stamp in draws) {
      if (stamp.rare) {
        canvas.drawCircle(
          stamp.rect.center,
          stamp.rect.shortestSide * 0.62,
          ui.Paint()
            ..color = const Color(0x66C77DFF)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12),
        );
      } else if (stamp.kind == Kind.star || stamp.kind == Kind.seven) {
        canvas.drawCircle(
          stamp.rect.center,
          stamp.rect.shortestSide * 0.48,
          ui.Paint()
            ..color = const Color(0x44E6D2FF)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8),
        );
      }
      final image = store.image(stamp.frame.asset);
      if (image == null) continue;
      if (stamp.kind != null) {
        final shadow = ui.Rect.fromCenter(
          center: stamp.rect.bottomCenter.translate(0, -stamp.rect.height * 0.06),
          width: stamp.rect.width * 0.62,
          height: stamp.rect.height * 0.16,
        );
        canvas.drawOval(shadow, ui.Paint()..color = const Color(0x66000000));
      }
      drawFrame(canvas, image, stamp.frame, stamp.rect, opacity: stamp.opacity);
    }

    for (final burst in game.bursts) {
      final image = store.image(burst.frame.asset);
      if (image == null) continue;
      final t = (burst.age / burst.life).clamp(0.0, 1.0);
      final rect = place(size, burst.x, burst.y, burst.width * (0.85 + t * 0.35), burst.frame.aspect);
      drawFrame(canvas, image, burst.frame, rect, opacity: (1 - t) * 0.95);
    }

    for (final floater in game.floaters) {
      final tp = TextPainter(
        text: TextSpan(
          text: floater.text,
          style: TextStyle(
            color: floater.color.withValues(alpha: (1 - floater.age).clamp(0, 1)),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Color(0xCC120818), blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(size.width * floater.x - tp.width / 2, size.height * floater.y - 28 - floater.age * 42),
      );
    }

    final shade = ui.Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x99100818), Color(0x00000000), Color(0x00000000), Color(0x66100818)],
        stops: [0, 0.10, 0.86, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, shade);
  }

  void _piece(Canvas canvas, Size size, Dressing piece, double opacity) {
    final image = store.image(piece.frame.asset);
    if (image == null) return;
    final rect = place(size, piece.x, piece.y, piece.width, piece.frame.aspect, maxH: piece.floor ? 0.24 : 0.46);
    drawFrame(canvas, image, piece.frame, rect, opacity: opacity);
  }

  @override
  bool shouldRepaint(ScenePainter oldDelegate) => true;
}

class _Stamp {
  _Stamp(this.frame, this.rect, this.sort, this.opacity, {this.kind, this.rare = false});

  final Frame frame;
  final ui.Rect rect;
  final double sort;
  final double opacity;
  final Kind? kind;
  final bool rare;
}

class FrameView extends StatelessWidget {
  const FrameView({super.key, required this.frame, this.dim = false, this.opacity = 1});

  final Frame frame;
  final bool dim;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SheetStore.instance,
      builder: (context, _) {
        return CustomPaint(
          painter: _FramePainter(frame, SheetStore.instance.image(frame.asset), dim: dim, opacity: opacity),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.frame, this.image, {required this.dim, required this.opacity});

  final Frame frame;
  final ui.Image? image;
  final bool dim;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final current = image;
    if (current == null || size.isEmpty) return;
    final aspect = frame.aspect;
    final fitted = applyBoxFit(BoxFit.contain, Size(aspect, 1), size);
    final dest = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    drawFrame(canvas, current, frame, dest, opacity: opacity, dim: dim);
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.dim != dim || oldDelegate.opacity != opacity || oldDelegate.frame != frame;
  }
}
