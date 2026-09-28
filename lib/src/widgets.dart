import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';

const ink = Color(0xFF100818);
const panel = Color(0xD916102C);
const gold = Color(0xFFF0C14B);
const goldDeep = Color(0xFFC48A22);
const violet = Color(0xFFC9A6FF);
const cream = Color(0xFFF6F0FF);
const muted = Color(0xFFCBBBE4);

/// Pins the device to landscape and waits until the platform view has
/// actually rotated.
///
/// Every arcade screen is drawn for a wide viewport, so entering the game
/// before the rotation lands produces one frame of squashed layout. The
/// poll is bounded (2 s) so a device that refuses to rotate still starts.
///
/// The boot screen treats the returned future as a progress checkpoint —
/// see `lib/boot/boot_screen.dart`.
Future<void> lockLandscape() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  for (var i = 0; i < 40; i++) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      final view = views.first;
      if (view.physicalSize.width > view.physicalSize.height + 8) return;
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
}

Route<T> horizonRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondary) => page,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.asset, required this.child});

  final String asset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xC4100818), Color(0x55100818), Color(0xD0100818)],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class HallPage extends StatelessWidget {
  const HallPage({super.key, required this.title, required this.background, required this.child});

  final String title;
  final String background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      body: Backdrop(
        asset: background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Back(),
                    const SizedBox(width: 12),
                    Text(title, style: const TextStyle(color: cream, fontSize: 26, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        Sfx.instance.play(Sfx.menuClose);
        Navigator.pop(context);
      },
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x66E2B657)),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: gold, size: 22),
      ),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  const GoldButton({super.key, required this.label, this.onTap, this.expand = false});

  final String label;
  final VoidCallback? onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = Pressable(
      onTap: onTap == null
          ? null
          : () {
              Sfx.instance.play(Sfx.click);
              onTap!();
            },
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: onTap == null
                ? const [Color(0xFF6A5A3A), Color(0xFF4A3E2C)]
                : const [Color(0xFFFFE08A), Color(0xFFE0A432)],
          ),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null ? const Color(0xFFD9D0C2) : const Color(0xFF3A2508),
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        Sfx.instance.play(Sfx.click);
        onTap();
      },
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x88E2B657)),
        ),
        child: Text(label, style: const TextStyle(color: cream, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}

BoxDecoration get horizonCard => BoxDecoration(
  color: panel,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: const Color(0x55E2B657)),
);

String clock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
