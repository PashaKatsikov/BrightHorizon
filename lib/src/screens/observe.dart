import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio.dart';
import '../catalog.dart';
import '../observation.dart';
import '../profile.dart';
import '../scene.dart';
import '../sheets.dart';
import '../widgets.dart';
import 'rare.dart';
import 'result.dart';

class ObservePage extends StatefulWidget {
  const ObservePage({super.key, required this.roomId});

  final String roomId;

  @override
  State<ObservePage> createState() => _ObservePageState();
}

class _ObservePageState extends State<ObservePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Observation _game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _ready = false;
  bool _allowPop = false;
  bool _busy = false;
  bool _showCoach = false;
  bool _asleep = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final profile = ProfileScope.read(context);
    _game = Observation(room: roomById(widget.roomId), profile: profile);
    _showCoach = !profile.coachSeen;
    _ticker = createTicker(_onTick);
    _prepare();
  }

  Future<void> _prepare() async {
    final room = _game.room;
    await SheetStore.instance.warm(
      {room.background},
      fullRes: {room.background},
    );
    if (!mounted) return;
    _game.profile.noteVisit(room.id);
    setState(() {});
    await SheetStore.instance.warm(sheetsFor(room));
    if (!mounted) return;
    setState(() => _ready = true);
    Sfx.instance.play(Sfx.menuOpen);
    if (!_showCoach) _resumeTicker();
  }

  void _playCues() {
    if (_game.cueRare) {
      _game.cueRare = false;
      Sfx.instance.play(Sfx.rareOn);
      Sfx.instance.play(Sfx.rareAlert);
    }
    if (_game.cueStream) {
      _game.cueStream = false;
      Sfx.instance.play(Sfx.stream);
    }
    if (_game.cueR) {
      _game.cueR = false;
      Sfx.instance.play(Sfx.rOn);
    }
    if (_game.cueSpawn > 0) {
      _game.cueSpawn = 0;
      Sfx.instance.play(Sfx.spawn);
    }
    if (_game.cueMiss > 0) {
      _game.cueMiss = 0;
      Sfx.instance.play(Sfx.disappear);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_asleep || _game.finished) return;
      _asleep = true;
      _ticker.stop();
      _game.profile.addWatch(_game.flushWatch());
      _game.profile.save();
      return;
    }
    if (state == AppLifecycleState.resumed && _asleep) {
      _asleep = false;
      _resumeTicker();
    }
  }

  void _resumeTicker() {
    if (!mounted || _asleep || _game.finished || _game.paused || _busy || _showCoach || !_ready) {
      return;
    }
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _busy || _asleep) return;
    var dt = (elapsed - _last).inMicroseconds / 1000000;
    _last = elapsed;
    if (dt < 0 || dt > 0.05) dt = 0.016;
    _game.tick(dt);
    _playCues();
    final capture = _game.capture;
    if (capture != null) {
      _game.capture = null;
      _present(capture);
      return;
    }
    setState(() {});
  }

  Future<void> _present(Capture capture) async {
    _busy = true;
    _ticker.stop();
    _game.paused = true;
    Sfx.instance.play(Sfx.reward);
    await Navigator.push(
      context,
      horizonRoute(RarePage(eventId: capture.eventId, bonus: capture.bonus)),
    );
    if (!mounted) return;
    _game.paused = false;
    _busy = false;
    _resumeTicker();
  }

  void _setPaused(bool value) {
    _game.paused = value;
    if (value) {
      _ticker.stop();
    } else if (_ready) {
      _resumeTicker();
    }
    setState(() {});
  }

  void _finish() {
    if (_game.finished) return;
    _ticker.stop();
    final report = _game.finish();
    Sfx.instance.play(report.events > 0 ? Sfx.levelDone : Sfx.done);
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        horizonRoute(ResultPage(report: report)),
      );
    });
  }

  void _tap(Offset local, Size size) {
    if (!_ready || _game.paused || _showCoach) return;
    final actor = _game.hit(local, size);
    if (actor != null) {
      final result = _game.collect(actor);
      if (result.paid <= 0) return;
      switch (result.item.kind) {
        case Kind.coin:
          Sfx.instance.play(Sfx.coin);
        case Kind.fruit:
          Sfx.instance.play(Sfx.fruit);
        case Kind.star:
          Sfx.instance.play(Sfx.star);
        case Kind.seven:
          Sfx.instance.play(Sfx.seven);
          HapticFeedback.mediumImpact();
      }
      if (result.first) Sfx.instance.play(Sfx.unlockItem);
      setState(() {});
      return;
    }
    if (_game.hitR(local, size)) {
      if (_game.attune()) {
        Sfx.instance.play(Sfx.rOn);
      } else {
        Sfx.instance.play(Sfx.click);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _allowPop) return;
        if (_game.paused) {
          _finish();
        } else {
          _setPaused(true);
        }
      },
      child: Scaffold(
        backgroundColor: ink,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _tap(details.localPosition, size),
                  child: CustomPaint(
                    painter: ScenePainter(
                      game: _game,
                      store: SheetStore.instance,
                    ),
                    size: size,
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _HudButton(
                              icon: Icons.pause_rounded,
                              onTap: () => _setPaused(true),
                            ),
                            const Spacer(),
                            _HudPill('${_game.sessionGleam} gleam'),
                            const SizedBox(width: 8),
                            _HudPill('${profile.foundKinds}/${items.length}'),
                          ],
                        ),
                        const Spacer(),
                        if (_game.motionHint != null)
                          _EventBar(
                            label: _game.motionHint!,
                            left: _game.liveEvent == null
                                ? null
                                : _game.eventLeft,
                            total: _game.liveEvent == null
                                ? null
                                : _game.eventSpan,
                          ),
                        if (!_ready)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Opening the room',
                              style: TextStyle(color: cream, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_showCoach) _Coach(onDone: _dismissCoach),
                if (_game.paused && !_busy)
                  _Pause(onResume: () => _setPaused(false), onFinish: _finish),
              ],
            );
          },
        ),
      ),
    );
  }

  void _dismissCoach() {
    ProfileScope.read(context).markCoach();
    setState(() => _showCoach = false);
    _resumeTicker();
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        Sfx.instance.play(Sfx.click);
        onTap();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: horizonCard,
        child: Icon(icon, color: gold),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: horizonCard,
      child: Text(
        text,
        style: const TextStyle(color: gold, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EventBar extends StatelessWidget {
  const _EventBar({required this.label, this.left, this.total});

  final String label;
  final double? left;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final span = total;
    final remain = left;
    final timed = span != null && remain != null && span > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: horizonCard,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: cream, fontWeight: FontWeight.w700),
          ),
          if (timed) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (remain / span).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: const Color(0x44FFFFFF),
                color: violet,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Coach extends StatelessWidget {
  const _Coach({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99080614),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: horizonCard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to watch',
                  style: TextStyle(
                    color: gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tap coins, fruit, stars and sevens while they are still in the room.',
                  style: TextStyle(color: cream, height: 1.35),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The letter R pulls things in. Tap it when you want a closer look.',
                  style: TextStyle(color: cream, height: 1.35),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Leave whenever you like. What you have already found stays found.',
                  style: TextStyle(color: cream, height: 1.35),
                ),
                const SizedBox(height: 14),
                GoldButton(label: 'I am watching', expand: true, onTap: onDone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pause extends StatelessWidget {
  const _Pause({required this.onResume, required this.onFinish});

  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xBB080614),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: horizonCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paused',
                style: TextStyle(
                  color: cream,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text('The room will wait.', style: TextStyle(color: muted)),
              const SizedBox(height: 14),
              GoldButton(label: 'Keep watching', expand: true, onTap: onResume),
              const SizedBox(height: 8),
              GhostButton(label: 'Finish', onTap: onFinish),
            ],
          ),
        ),
      ),
    );
  }
}
