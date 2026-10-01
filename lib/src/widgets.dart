import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const ink = Color(0xFF070418);
const panel = Color(0xD9100824);
const gold = Color(0xFFE8C872);
const neon = Color(0xFF5CE1FF);
const violet = Color(0xFFC9A6FF);
const cream = Color(0xFFF4F7FF);
const muted = Color(0xFFB7C0DC);

/// The cabinet is portrait-only. [lockLandscape] keeps the old name because
/// the relay boot on android-gray-part calls it the moment the arcade opens.
Future<void> lockPortrait() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  for (var i = 0; i < 40; i++) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      final view = views.first;
      if (view.physicalSize.height > view.physicalSize.width + 8) return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<void> lockLandscape() => lockPortrait();

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
  const Backdrop({super.key, required this.asset, required this.child, this.dim = true});

  final String asset;
  final Widget child;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        if (dim)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99100824), Color(0x33100824), Color(0xCC100824)],
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
                    const _Back(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: cream, fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                    ),
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
  const _Back();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x665CE1FF)),
        ),
        child: const Icon(Icons.arrow_back_rounded, color: neon, size: 22),
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
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x885CE1FF)),
        ),
        child: Text(label, style: const TextStyle(color: cream, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}

BoxDecoration get horizonCard => BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x555CE1FF)),
    );

String grouped(int value) {
  final negative = value < 0;
  final text = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buf.write(',');
    buf.write(text[i]);
  }
  return negative ? '-$buf' : buf.toString();
}
