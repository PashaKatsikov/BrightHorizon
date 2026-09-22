import 'package:flutter/material.dart';

import '../catalog.dart';
import '../frames.dart';
import '../profile.dart';
import '../widgets.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final rarest = profile.rarestId == null
        ? 'None yet'
        : itemById(profile.rarestId!).name;
    final rows = <(String, String)>[
      ('Objects found', '${profile.objects}'),
      ('Coins', '${profile.coins}'),
      ('Fruit', '${profile.fruits}'),
      ('Stars', '${profile.stars}'),
      ('Sevens', '${profile.sevens}'),
      ('Rare motions', '${profile.rareEvents}'),
      ('Rarest find', rarest),
      ('Time watching', clock(profile.watchSeconds)),
      ('Best session', '${profile.bestSession} gleam'),
      ('Rooms visited', '${profile.visited.length} of ${rooms.length}'),
      ('Collection', '${profile.foundKinds} of ${items.length}'),
      ('Album', '${profile.albumCounts.length} of ${album.length}'),
    ];
    return HallPage(
      title: 'Statistics',
      background: bgFruit,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth > 680 ? 4 : 2;
          final rowCount = (rows.length / cols).ceil();
          final gaps = 10.0 * (rowCount - 1);
          final cellW = (constraints.maxWidth - 10.0 * (cols - 1)) / cols;
          final cellH = ((constraints.maxHeight - gaps) / rowCount).clamp(
            68.0,
            120.0,
          );
          final fits = cellH * rowCount + gaps <= constraints.maxHeight + 1;
          return GridView.count(
            physics: fits
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: cellW / cellH,
            children: [
              for (final row in rows)
                Container(
                  decoration: horizonCard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: cream,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
