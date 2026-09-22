import 'package:flutter/material.dart';

import '../audio.dart';
import '../catalog.dart';
import '../frames.dart';
import '../profile.dart';
import '../widgets.dart';

class UpgradesPage extends StatelessWidget {
  const UpgradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return HallPage(
      title: 'Upgrades',
      background: bgR,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${profile.gleam} gleam', style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: upgrades.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final upgrade = upgrades[index];
                final level = profile.levelOf(upgrade.id);
                final maxed = level >= upgrade.maxLevel;
                final cost = maxed ? 0 : upgrade.costs[level];
                final can = !maxed && profile.gleam >= cost;
                return Container(
                  decoration: horizonCard,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(upgrade.name, style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(upgrade.detail, style: const TextStyle(color: muted, fontSize: 13)),
                            const SizedBox(height: 6),
                            Row(
                              children: List.generate(upgrade.maxLevel, (pip) {
                                final filled = pip < level;
                                return Container(
                                  width: 18,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: filled ? gold : const Color(0x44FFFFFF),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 148,
                        child: GoldButton(
                          label: maxed ? 'Maxed' : 'Buy $cost',
                          onTap: can
                              ? () {
                                  if (profile.buyUpgrade(upgrade)) {
                                    Sfx.instance.play(Sfx.upgrade);
                                  }
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
