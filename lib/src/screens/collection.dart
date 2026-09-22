import 'package:flutter/material.dart';

import '../catalog.dart';
import '../frames.dart';
import '../profile.dart';
import '../scene.dart';
import '../sheets.dart';
import '../widgets.dart';
import 'item.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  Kind? _filter;

  @override
  void initState() {
    super.initState();
    SheetStore.instance.warm(items.map((item) => item.frame.asset));
    SheetStore.instance.warm({pedestalFrame.asset});
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final shown = items
        .where((item) => _filter == null || item.kind == _filter)
        .toList();
    return HallPage(
      title: 'Collection',
      background: bgViolet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 54,
                height: 54,
                child: FrameView(frame: pedestalFrame),
              ),
              const SizedBox(width: 10),
              Text(
                '${profile.foundKinds} of ${items.length} found',
                style: const TextStyle(
                  color: cream,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _Filter(
                label: 'All',
                on: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              _Filter(
                label: 'Coins',
                on: _filter == Kind.coin,
                onTap: () => setState(() => _filter = Kind.coin),
              ),
              _Filter(
                label: 'Fruit',
                on: _filter == Kind.fruit,
                onTap: () => setState(() => _filter = Kind.fruit),
              ),
              _Filter(
                label: 'Stars',
                on: _filter == Kind.star,
                onTap: () => setState(() => _filter = Kind.star),
              ),
              _Filter(
                label: 'Sevens',
                on: _filter == Kind.seven,
                onTap: () => setState(() => _filter = Kind.seven),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 700 ? 6 : 4;
                final cellW = (constraints.maxWidth - 10 * (cols - 1)) / cols;
                final cellH = (constraints.maxHeight - 10) / 2;
                final ratio = cellH <= 0
                    ? 0.9
                    : (cellW / cellH).clamp(0.9, 1.4).toDouble();
                return GridView.builder(
                  itemCount: shown.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (context, index) {
                    final item = shown[index];
                    final known = profile.foundCount(item.id) > 0;
                    return Pressable(
                      onTap: known
                          ? () => Navigator.push(
                              context,
                              horizonRoute(ItemPage(itemId: item.id)),
                            )
                          : null,
                      child: Container(
                        decoration: horizonCard,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Expanded(
                              child: FrameView(frame: item.frame, dim: !known),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              known ? item.name : 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: known ? cream : muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              known ? item.rarity.label : '—',
                              style: const TextStyle(color: gold, fontSize: 10),
                            ),
                          ],
                        ),
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

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? const Color(0xFFE0A432) : const Color(0x6616102C),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: on ? const Color(0xFF3A2508) : cream,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
