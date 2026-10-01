import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../frames.dart';
import '../profile.dart';
import '../slot/cheat.dart';
import '../slot/engine.dart';
import '../slot/marks.dart';
import '../widgets.dart';

class CabinetPage extends StatefulWidget {
  const CabinetPage({super.key});

  @override
  State<CabinetPage> createState() => _CabinetPageState();
}

class _CabinetPageState extends State<CabinetPage> with SingleTickerProviderStateMixin {
  final SlotEngine _engine = SlotEngine();
  late final AnimationController _spin;

  List<List<Mark>> _grid = openingGrid.map((reel) => List<Mark>.of(reel)).toList();
  List<List<Mark>> _strips = const [];
  Set<Cell> _hits = const {};
  SpinOutcome? _outcome;
  bool _spinning = false;
  bool _settled = true;
  bool _wasFree = false;
  int _stakeUsed = stakes.first;
  int _freeLeft = 0;
  int _lastWin = 0;
  String? _bannerTitle;
  String? _bannerDetail;
  bool _cheatOpen = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _settle();
      });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _start({Cheat? cheat}) {
    if (_spinning) return;
    final profile = ProfileScope.read(context);
    final free = _freeLeft > 0 && cheat == null;
    if (!free) {
      if (profile.credits < profile.stake) {
        if (cheat != null && cheat != Cheat.refill) {
          profile.grant(profile.stake - profile.credits);
        } else {
          return;
        }
      }
      if (!profile.spend(profile.stake)) return;
    } else {
      _freeLeft -= 1;
    }

    final outcome = _engine.spin(
      stake: profile.stake,
      cheat: cheat == Cheat.refill ? null : cheat,
    );
    setState(() {
      _spinning = true;
      _settled = false;
      _wasFree = free;
      _stakeUsed = profile.stake;
      _outcome = outcome;
      _strips = _visualStrips(outcome.grid);
      _hits = const {};
      _bannerTitle = null;
      _bannerDetail = null;
      _cheatOpen = false;
    });
    HapticFeedback.lightImpact().ignore();
    _spin.forward(from: 0);
  }

  List<List<Mark>> _visualStrips(List<List<Mark>> grid) {
    final random = math.Random();
    return List.generate(5, (reel) {
      final strip = reelStrips[reel];
      final head = List<Mark>.generate(16, (_) => strip[random.nextInt(strip.length)]);
      return [...head, grid[reel][0], grid[reel][1], grid[reel][2]];
    });
  }

  void _settle() {
    if (!mounted || _settled) return;
    final outcome = _outcome;
    if (outcome == null) return;
    _settled = true;
    final paid = outcome.payout * (_wasFree ? 2 : 1);
    final tier = tierFor(paid, _stakeUsed);
    ProfileScope.read(context).award(paid);
    final title = switch (tier) {
      Tier.jackpot => 'JACKPOT',
      Tier.mega => 'MEGA WIN',
      Tier.big => 'BIG WIN',
      Tier.none => outcome.freeSpins > 0 ? 'FREE SPINS' : null,
    };
    setState(() {
      _spinning = false;
      _grid = outcome.grid;
      _hits = outcome.hits;
      _lastWin = paid;
      _freeLeft = math.min(100, _freeLeft + outcome.freeSpins);
      _bannerTitle = title;
      _bannerDetail = _detail(title, outcome.freeSpins, paid);
    });
    HapticFeedback.mediumImpact().ignore();
    if (title == null) _queueFree();
  }

  String? _detail(String? title, int freeSpins, int paid) {
    if (title == null) return null;
    final credits = paid > 0 ? '${grouped(paid)} credits' : null;
    if (freeSpins > 0 && title != 'FREE SPINS') {
      final spins = '$freeSpins free spins';
      return credits == null ? spins : '$credits   ·   $spins';
    }
    if (title == 'FREE SPINS') {
      return credits == null ? '$freeSpins spins' : '$freeSpins spins   ·   $credits';
    }
    return credits;
  }

  void _queueFree() {
    if (_freeLeft <= 0) return;
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || _spinning || _bannerTitle != null) return;
      _start();
    });
  }

  void _dismissBanner() {
    setState(() {
      _bannerTitle = null;
      _bannerDetail = null;
    });
    _queueFree();
  }

  void _applyCheat(Cheat cheat) {
    setState(() => _cheatOpen = false);
    if (cheat == Cheat.refill) {
      ProfileScope.read(context).grant(10000);
      return;
    }
    _start(cheat: cheat);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final short = profile.credits < profile.stake && _freeLeft == 0;
    return PopScope(
      canPop: !_spinning,
      child: Scaffold(
        backgroundColor: ink,
        body: Backdrop(
          asset: cabinetBackdrop,
          dim: false,
          child: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                  child: Column(
                    children: [
                      _Header(credits: profile.credits, freeLeft: _freeLeft, spinning: _spinning),
                      const SizedBox(height: 6),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            var width = constraints.maxWidth;
                            var height = width / frameAspect;
                            if (height > constraints.maxHeight) {
                              height = constraints.maxHeight;
                              width = height * frameAspect;
                            }
                            return Center(
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: AnimatedBuilder(
                                  animation: _spin,
                                  builder: (context, _) {
                                    return _Machine(
                                      grid: _grid,
                                      strips: _strips,
                                      progress: _spinning ? _spin.value : 1,
                                      spinning: _spinning,
                                      hits: _hits,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        height: 22,
                        child: Text(
                          _bannerTitle != null
                              ? ''
                              : _spinning
                                  ? (_wasFree ? 'FREE SPIN' : 'GOOD LUCK')
                                  : _lastWin > 0
                                      ? 'WIN  ${grouped(_lastWin)}'
                                      : _freeLeft > 0
                                          ? '$_freeLeft FREE SPINS'
                                          : '',
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 64,
                        child: Row(
                          children: [
                            for (var i = 0; i < stakes.length; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Expanded(
                                child: _Stake(
                                  value: stakes[i],
                                  selected: profile.stake == stakes[i],
                                  enabled: !_spinning && _freeLeft == 0,
                                  onTap: () => profile.setStake(stakes[i]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Pressable(
                        key: const Key('play-button'),
                        onTap: _spinning || _freeLeft > 0 || short ? null : () => _start(),
                        child: Opacity(
                          opacity: _spinning || _freeLeft > 0 || short ? 0.55 : 1,
                          child: Image.asset(playAsset, height: 64, fit: BoxFit.contain),
                        ),
                      ),
                      SizedBox(
                        height: 32,
                        child: short
                            ? TextButton(
                                onPressed: profile.giftReady && !_spinning ? () => profile.claimGift() : null,
                                child: Text(
                                  profile.giftReady
                                      ? 'Collect ${grouped(Profile.giftCredits)} credits'
                                      : _giftWait(profile.giftAt),
                                  style: TextStyle(
                                    color: profile.giftReady ? neon : muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                if (cheatMenuEnabled)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        key: const Key('cheat-entry'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _spinning
                            ? null
                            : () => setState(() => _cheatOpen = true),
                        child: const SizedBox(width: 148, height: 36),
                      ),
                    ),
                  ),
                if (_bannerTitle != null)
                  Positioned.fill(
                    child: GestureDetector(
                      key: const Key('win-banner'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismissBanner,
                      child: _Banner(title: _bannerTitle!, detail: _bannerDetail),
                    ),
                  ),
                if (_cheatOpen) _CheatSheet(onPick: _applyCheat, onClose: () => setState(() => _cheatOpen = false)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _giftWait(DateTime at) {
  final left = at.difference(DateTime.now());
  if (left.isNegative) return 'Collect bonus';
  final hours = left.inHours;
  final minutes = left.inMinutes.remainder(60).toString().padLeft(2, '0');
  return 'Bonus in ${hours}h ${minutes}m';
}

class _Header extends StatelessWidget {
  const _Header({required this.credits, required this.freeLeft, required this.spinning});

  final int credits;
  final int freeLeft;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Pressable(
          onTap: spinning ? null : () => Navigator.maybePop(context),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x665CE1FF)),
            ),
            child: Icon(Icons.arrow_back_rounded, color: spinning ? muted : neon, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xC4070418),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x665CE1FF)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                freeLeft > 0 ? '${grouped(credits)}   ·   $freeLeft FREE' : '${grouped(credits)} CREDITS',
                style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Stake extends StatelessWidget {
  const _Stake({required this.value, required this.selected, required this.enabled, required this.onTap});

  final int value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.45,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(selected ? stakeOnAsset : stakeOffAsset, fit: BoxFit.contain),
            Center(
              child: Text(
                '$value',
                style: TextStyle(
                  color: selected ? cream : const Color(0xFFD5D8E6),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Machine extends StatelessWidget {
  const _Machine({
    required this.grid,
    required this.strips,
    required this.progress,
    required this.spinning,
    required this.hits,
  });

  final List<List<Mark>> grid;
  final List<List<Mark>> strips;
  final double progress;
  final bool spinning;
  final Set<Cell> hits;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final pitch = (rowCenterY[2] - rowCenterY[0]) / 2 * size.height;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(reelFrameAsset, fit: BoxFit.fill),
            ClipPath(
              clipper: const _WindowClipper(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!spinning || strips.length != 5)
                    for (var reel = 0; reel < 5; reel++)
                      for (var row = 0; row < 3; row++)
                        _PlacedSymbol(reel: reel, row: row, mark: grid[reel][row])
                  else
                    for (var reel = 0; reel < 5; reel++)
                      ..._spinSymbols(size, reel, strips[reel], pitch),
                ],
              ),
            ),
            if (!spinning && hits.isNotEmpty)
              for (final cell in hits) _HitGlow(reel: cell.reel, row: cell.row),
          ],
        );
      },
    );
  }

  List<Widget> _spinSymbols(Size size, int reel, List<Mark> strip, double pitch) {
    final end = 0.40 + reel * 0.12;
    final u = (progress / end).clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - u, 3).toDouble();
    final shift = eased * (strip.length - 3);
    final cell = _cellRect(size, reel, 0);
    final originY = rowCenterY[0] * size.height;
    final first = math.max(0, shift.floor() - 1);
    final last = math.min(strip.length - 1, shift.floor() + 4);
    return [
      for (var i = first; i <= last; i++)
        Positioned(
          left: cell.left,
          width: cell.width,
          top: originY + (i - shift) * pitch - cell.height / 2,
          height: cell.height,
          child: Image.asset(strip[i].asset, fit: BoxFit.contain),
        ),
    ];
  }
}

class _PlacedSymbol extends StatelessWidget {
  const _PlacedSymbol({required this.reel, required this.row, required this.mark});

  final int reel;
  final int row;
  final Mark mark;

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _CellDelegate(reel, row),
      child: Image.asset(mark.asset, fit: BoxFit.contain),
    );
  }
}

class _HitGlow extends StatelessWidget {
  const _HitGlow({required this.reel, required this.row});

  final int reel;
  final int row;

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: _CellDelegate(reel, row, inset: 0.08),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFE08A), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x88FFE08A), blurRadius: 12)],
        ),
      ),
    );
  }
}

class _CellDelegate extends SingleChildLayoutDelegate {
  const _CellDelegate(this.reel, this.row, {this.inset = 0});

  final int reel;
  final int row;
  final double inset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = Size(constraints.biggest.width, constraints.biggest.height);
    final rect = _cellRect(size, reel, row);
    return BoxConstraints.tight(Size(rect.width * (1 - inset), rect.height * (1 - inset)));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rect = _cellRect(size, reel, row);
    return Offset(rect.center.dx - childSize.width / 2, rect.center.dy - childSize.height / 2);
  }

  @override
  bool shouldRelayout(covariant _CellDelegate oldDelegate) =>
      oldDelegate.reel != reel || oldDelegate.row != row || oldDelegate.inset != inset;
}

Rect _cellRect(Size size, int reel, int row) {
  return Rect.fromCenter(
    center: Offset(reelCenterX[reel] * size.width, rowCenterY[row] * size.height),
    width: cellWidthFactor * size.width,
    height: cellHeightFactor * size.height,
  );
}

class _WindowClipper extends CustomClipper<Path> {
  const _WindowClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    for (var reel = 0; reel < 5; reel++) {
      for (var row = 0; row < 3; row++) {
        path.addRRect(RRect.fromRectAndRadius(_cellRect(size, reel, row), const Radius.circular(6)));
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0x59070418)),
      child: Align(
        alignment: const Alignment(0, 0.46),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    colors: [Color(0xFF7AF0FF), Color(0xFFFFE7A3), Color(0xFFE7A0FF)],
                  ).createShader(rect);
                },
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: cream, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 14),
              const Text('Tap to continue', style: TextStyle(color: muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheatOption extends StatelessWidget {
  const _CheatOption({required this.label, required this.onTap});

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
        decoration: BoxDecoration(
          color: const Color(0xFF24143A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x665CE1FF)),
        ),
        child: Text(label, style: const TextStyle(color: cream, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}

class _CheatSheet extends StatelessWidget {
  const _CheatSheet({required this.onPick, required this.onClose});

  final ValueChanged<Cheat> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const options = <(Cheat, String)>[
      (Cheat.bigWin, 'Big Win'),
      (Cheat.megaWin, 'Mega Win'),
      (Cheat.jackpot, 'Jackpot'),
      (Cheat.freeSpins, 'Free Spins'),
      (Cheat.smallWin, 'Small Win'),
      (Cheat.deadSpin, 'Dead Spin'),
      (Cheat.refill, 'Add 10,000 Credits'),
    ];
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onClose,
            child: const ColoredBox(color: Color(0xCC070418)),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF12081F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x885CE1FF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final option in options) ...[
                        _CheatOption(label: option.$2, onTap: () => onPick(option.$1)),
                        const SizedBox(height: 8),
                      ],
                    ],
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
