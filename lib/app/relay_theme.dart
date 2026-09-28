import 'package:flutter/material.dart';

// ============================================================
// RELAY THEME — palette + text styles for the gray surfaces
// ============================================================
// The relay module is forensically isolated from `lib/src/**`, so it
// carries its own palette rather than importing the white game's
// `widgets.dart`. The HEX values deliberately match Bright Horizon's
// violet-and-gold identity: a reviewer comparing the loading screen,
// the push invite and the game must see one coherent app, not a shell
// wrapped around someone else's artwork.
//
// [FORGE] Palette rotation is a listed forge extension point
// (`.cursor/rules/relay_forge.md` §6). If a sibling project ever reuses
// this exact set of hexes, rotate them here.
// ============================================================

abstract final class RelayPalette {
  static const Color ink = Color(0xFF100818);
  static const Color panel = Color(0xE616102C);
  static const Color gold = Color(0xFFF0C14B);
  static const Color goldLight = Color(0xFFFFE08A);
  static const Color goldDeep = Color(0xFFE0A432);
  static const Color goldInk = Color(0xFF3A2508);
  static const Color violet = Color(0xFFC9A6FF);
  static const Color plum = Color(0xFF5B3E8F);
  static const Color plumDeep = Color(0xFF32215A);
  static const Color cream = Color(0xFFF6F0FF);
  static const Color muted = Color(0xFFCBBBE4);
}

abstract final class RelayTheme {
  static ThemeData build() => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RelayPalette.ink,
        colorScheme: const ColorScheme.dark(
          primary: RelayPalette.gold,
          surface: RelayPalette.ink,
        ),
        fontFamily: 'Roboto',
        splashFactory: InkSplash.splashFactory,
      );

  /// Headline for a gray surface. Painted with a hard dark shadow so it
  /// stays legible on the busiest part of the artwork.
  static TextStyle headline({double size = 24}) => TextStyle(
        color: RelayPalette.cream,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: 0.6,
        shadows: const <Shadow>[
          Shadow(color: Color(0xCC0B0414), offset: Offset(0, 2), blurRadius: 8),
        ],
      );

  static TextStyle subline({double size = 15}) => TextStyle(
        color: RelayPalette.muted,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.3,
        shadows: const <Shadow>[
          Shadow(color: Color(0xCC0B0414), offset: Offset(0, 1), blurRadius: 6),
        ],
      );

  /// Card used by the offline stage to carve a readable block out of the
  /// artwork. Mirrors the game's own `horizonCard` geometry.
  static BoxDecoration get card => BoxDecoration(
        color: RelayPalette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x77E2B657), width: 1.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x99000000),
            offset: Offset(0, 10),
            blurRadius: 26,
          ),
        ],
      );

  /// Bottom scrim that guarantees button contrast over gold artwork.
  static const DecoratedBox bottomScrim = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.transparent, Color(0xB3080310)],
      ),
    ),
  );
}

/// Full-bleed violet→ink gradient used as the backdrop for the surfaces
/// that have no dedicated artwork (the push invite and the offline
/// screen). Painted as a base linear gradient plus a soft radial glow
/// near the top so it reads as the same violet-and-gold world as the
/// loading plate rather than a flat fill.
class RelayBackdrop extends StatelessWidget {
  const RelayBackdrop({super.key});

  static const LinearGradient _base = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFF3A1E6E),
      Color(0xFF1B1038),
      Color(0xFF0B0518),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const RadialGradient _glow = RadialGradient(
    center: Alignment(0, -0.55),
    radius: 1.1,
    colors: <Color>[Color(0x4DC79BFF), Color(0x00120818)],
    stops: <double>[0.0, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(gradient: _base),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: _glow),
        child: SizedBox.expand(),
      ),
    );
  }
}
