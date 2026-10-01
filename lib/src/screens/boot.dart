import 'package:flutter/material.dart';

import '../frames.dart';
import '../slot/marks.dart';
import '../widgets.dart';
import 'menu.dart';

class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> with TickerProviderStateMixin {
  late final AnimationController _bar;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final started = DateTime.now();
    if (!mounted) return;
    try {
      await Future.wait([
        for (final asset in [
          loadingPortrait,
          loadingLandscape,
          logoAsset,
          cabinetBackdrop,
          reelFrameAsset,
          playAsset,
          stakeOnAsset,
          stakeOffAsset,
          for (final mark in Mark.values) mark.asset,
        ])
          precacheImage(AssetImage(asset), context),
      ]);
    } catch (_) {}
    final left = 1600 - DateTime.now().difference(started).inMilliseconds;
    if (left > 0) await Future<void>.delayed(Duration(milliseconds: left));
    if (!mounted) return;
    await lockPortrait();
    if (!mounted) return;
    Navigator.pushReplacement(context, horizonRoute(const MenuPage()));
  }

  @override
  void dispose() {
    _bar.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    // The plates already center the wordmark. A horizontal safe inset would
    // slide that center toward the side without a cutout, so landscape gets
    // a fixed bottom inset and no SafeArea at all.
    final bottom = landscape ? 16.0 : 16.0 + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            landscape ? loadingLandscape : loadingPortrait,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: FractionallySizedBox(
                widthFactor: 0.42,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoadingCaption(animation: _dots),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 8,
                        child: AnimatedBuilder(
                          animation: _bar,
                          builder: (context, _) {
                            return LinearProgressIndicator(
                              value: _bar.value,
                              backgroundColor: const Color(0x55FFFFFF),
                              color: neon,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Loading" plus up to three dots. The unused dots stay in the line as
/// transparent glyphs so the label does not shift as the count changes.
class _LoadingCaption extends StatelessWidget {
  const _LoadingCaption({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final int shown = (animation.value * 4).floor() % 4;
        return Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Loading'),
              TextSpan(text: '.' * shown),
              TextSpan(
                text: '.' * (3 - shown),
                style: const TextStyle(color: Colors.transparent, shadows: <Shadow>[]),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: cream,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            height: 1.0,
            shadows: [
              Shadow(color: Color(0xE6070418), blurRadius: 8),
              Shadow(color: Color(0xCC070041), offset: Offset(0, 1)),
            ],
          ),
        );
      },
    );
  }
}
