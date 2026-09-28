import 'package:flutter/material.dart';

import 'relay_theme.dart';

// ============================================================
// RELAY BUTTONS — shared actions for the gray surfaces
// ============================================================
// Two hard rules from `.cursor/rules/gray_part_pitfalls.md`:
//
// §12  The secondary action ("Not now") is a REAL gradient button, not
//      a faded text link. Accept outranks it through SIZE and POSITION,
//      never through opacity — a Skip the user cannot find burns the one
//      notification prompt Android allows.
//
// §13  Labels pin `height: 1.0` and `CrossAxisAlignment.center` so the
//      text sits on the pill's geometric centre in BOTH orientations.
//      Without it the label visibly drifts once the button width
//      changes on rotation.
// ============================================================

/// Minimum tap target Google requires. Never render a gray-surface
/// button shorter than this.
const double kRelayMinTapHeight = 44;

class RelayPillButton extends StatefulWidget {
  const RelayPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.height = 52,
    this.secondary = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final double height;

  /// Muted plum variant used for the declining action. Same geometry as
  /// the primary button — only the fill differs.
  final bool secondary;
  final IconData? icon;

  @override
  State<RelayPillButton> createState() => _RelayPillButtonState();
}

class _RelayPillButtonState extends State<RelayPillButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool secondary = widget.secondary;
    final List<Color> fill = secondary
        ? const <Color>[RelayPalette.plum, RelayPalette.plumDeep]
        : const <Color>[RelayPalette.goldLight, RelayPalette.goldDeep];
    final Color label =
        secondary ? RelayPalette.cream : RelayPalette.goldInk;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: widget.height < kRelayMinTapHeight
              ? kRelayMinTapHeight
              : widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: fill,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: secondary
                  ? const Color(0x99E2B657)
                  : const Color(0x66FFFFFF),
              width: 1.6,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x73000000),
                offset: Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(widget.icon, size: 20, color: label),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: label,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
