import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../audio.dart';
import '../frames.dart';
import '../profile.dart';
import '../widgets.dart';
import 'menu.dart';

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

class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> with SingleTickerProviderStateMixin {
  late final AnimationController _bar;

  @override
  void initState() {
    super.initState();
    _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final started = DateTime.now();
    await Future.wait([
      precacheImage(const AssetImage(loadingLandscape), context),
      precacheImage(const AssetImage(loadingPortrait), context),
      precacheImage(const AssetImage(logoAsset), context),
    ]);
    final left = 1700 - DateTime.now().difference(started).inMilliseconds;
    if (left > 0) await Future.delayed(Duration(milliseconds: left));
    if (!mounted) return;
    final profile = ProfileScope.read(context);
    final next = profile.notifPrompted ? const MenuPage() : const NoticePage();
    if (profile.notifPrompted) await lockLandscape();
    if (!mounted) return;
    Navigator.pushReplacement(context, horizonRoute(next));
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(portrait ? loadingPortrait : loadingLandscape, fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 22),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 4,
                    child: AnimatedBuilder(
                      animation: _bar,
                      builder: (context, _) {
                        return LinearProgressIndicator(
                          value: _bar.value,
                          backgroundColor: const Color(0x55FFFFFF),
                          color: gold,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoticePage extends StatelessWidget {
  const NoticePage({super.key});

  Future<void> _enter(BuildContext context) async {
    final profile = ProfileScope.read(context);
    profile.markNotified();
    await lockLandscape();
    if (!context.mounted) return;
    Navigator.pushReplacement(context, horizonRoute(const MenuPage()));
  }

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    return Scaffold(
      backgroundColor: ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(portrait ? noticePortrait : noticeLandscape, fit: BoxFit.cover),
          if (portrait)
            Align(
              alignment: const Alignment(0, -0.18),
              child: FractionallySizedBox(
                widthFactor: 0.78,
                heightFactor: 0.38,
                child: _Allow(onTap: () => _allow(context)),
              ),
            )
          else
            Align(
              alignment: Alignment.center,
              child: FractionallySizedBox(
                widthFactor: 0.46,
                heightFactor: 0.46,
                child: _Allow(onTap: () => _allow(context)),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton(
                  onPressed: () {
                    Sfx.instance.play(Sfx.click);
                    _enter(context);
                  },
                  child: const Text(
                    'Not now',
                    style: TextStyle(color: cream, fontSize: 16, fontWeight: FontWeight.w700, shadows: [
                      Shadow(color: Color(0xCC120818), blurRadius: 8),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _allow(BuildContext context) async {
    Sfx.instance.play(Sfx.click);
    try {
      await Permission.notification.request();
    } catch (_) {}
    if (!context.mounted) return;
    await _enter(context);
  }
}

class _Allow extends StatelessWidget {
  const _Allow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap);
  }
}
