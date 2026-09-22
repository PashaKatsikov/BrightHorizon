import 'package:flutter/material.dart';

import '../catalog.dart';
import '../frames.dart';
import '../profile.dart';
import '../scene.dart';
import '../sheets.dart';
import '../widgets.dart';

class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  @override
  void initState() {
    super.initState();
    SheetStore.instance.warm(album.map((event) => event.frame.asset));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final seen = album.where((event) => (profile.albumCounts[event.id] ?? 0) > 0).length;
    return HallPage(
      title: 'Album',
      background: bgGarden,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$seen of ${album.length} motions recorded', style: const TextStyle(color: cream, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 680 ? 2 : 1;
                return GridView.builder(
                  itemCount: album.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    mainAxisExtent: cols == 2 ? 108 : 96,
                  ),
                  itemBuilder: (context, index) {
                    final event = album[index];
                    final count = profile.albumCounts[event.id] ?? 0;
                    final known = count > 0;
                    final where = known
                        ? (count == 1 ? '${event.where} · once' : '${event.where} · $count times')
                        : 'Keep watching.';
                    return Container(
                      decoration: horizonCard,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: FrameView(frame: event.frame, dim: !known),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  known ? event.name : 'Not yet seen',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  where,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: gold, fontSize: 12),
                                ),
                                if (known) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    event.detail,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: muted, height: 1.25, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
