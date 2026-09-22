import 'package:flutter/material.dart';

import '../catalog.dart';
import '../frames.dart';
import '../profile.dart';
import '../scene.dart';
import '../widgets.dart';

class ItemPage extends StatelessWidget {
  const ItemPage({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final item = itemById(itemId);
    final profile = ProfileScope.of(context);
    final count = profile.foundCount(item.id);
    return HallPage(
      title: item.name,
      background: bgViolet,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: FrameView(frame: item.frame),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.rarity.label, style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                Text(item.detail, style: const TextStyle(color: cream, fontSize: 16, height: 1.4)),
                const SizedBox(height: 16),
                Text('Worth ${item.value} gleam before upgrades.', style: const TextStyle(color: muted)),
                const SizedBox(height: 6),
                Text(
                  count == 1 ? 'Found once.' : 'Found $count times.',
                  style: const TextStyle(color: cream, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
