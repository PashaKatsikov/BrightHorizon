import 'package:flutter/material.dart';

import '../frames.dart';
import '../slot/marks.dart';
import '../widgets.dart';

class PaytablePage extends StatelessWidget {
  const PaytablePage({super.key});

  @override
  Widget build(BuildContext context) {
    const order = <Mark>[
      Mark.cherry,
      Mark.orange,
      Mark.grape,
      Mark.bell,
      Mark.bar,
      Mark.ring,
      Mark.star,
      Mark.crown,
      Mark.diamond,
      Mark.seven,
      Mark.wild,
      Mark.scatter,
    ];
    return HallPage(
      title: 'Paytable',
      background: cabinetBackdrop,
      child: ListView(
        children: [
          const Text(
            '20 paylines. Combinations pay left to right. The stake is split evenly across the lines, and the numbers below are multipliers of that line stake.',
            style: TextStyle(color: cream, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 14),
          for (final mark in order) ...[
            _Row(mark: mark),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          const Text(
            'Three or more Scatters anywhere award free spins. Free spins cost nothing, and every win during free spins is doubled. Wild stands in for any symbol except Scatter.',
            style: TextStyle(color: muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.mark});

  final Mark mark;

  @override
  Widget build(BuildContext context) {
    final detail = switch (mark) {
      Mark.wild => 'Stands in for paying symbols',
      Mark.scatter => '3 anywhere: ×2 stake, 8 spins\n4: ×10 stake, 12 spins\n5: ×50 stake, 20 spins',
      _ => '3 ×${linePays[mark]![0]}    4 ×${linePays[mark]![1]}    5 ×${linePays[mark]![2]}',
    };
    return Container(
      decoration: horizonCard,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Image.asset(mark.asset, width: 52, height: 52, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mark.label, style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(color: muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
