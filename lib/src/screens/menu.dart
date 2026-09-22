import 'package:flutter/material.dart';

import '../frames.dart';
import '../profile.dart';
import '../widgets.dart';
import 'album.dart';
import 'collection.dart';
import 'observe.dart';
import 'rooms.dart';
import 'settings.dart';
import 'stats.dart';
import 'upgrades.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.height > size.width) {
      return const Scaffold(backgroundColor: ink);
    }
    final profile = ProfileScope.of(context);
    return Scaffold(
      backgroundColor: ink,
      body: Backdrop(
        asset: bgHorizon,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Image.asset(logoAsset, height: (size.height * 0.36).clamp(92, 168), fit: BoxFit.contain),
                      const SizedBox(height: 8),
                      const Text(
                        'Watch the rooms. Take what appears.',
                        style: TextStyle(color: cream, fontSize: 16, height: 1.3),
                      ),
                      const SizedBox(height: 14),
                      _GleamChip(gleam: profile.gleam),
                      const Spacer(),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      const Spacer(),
                      GoldButton(
                        label: 'Observe',
                        expand: true,
                        onTap: () {
                          final id = profile.owns(profile.lastRoom) ? profile.lastRoom : 'horizon';
                          Navigator.push(context, horizonRoute(ObservePage(roomId: id)));
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: GhostButton(label: 'Rooms', onTap: () => _open(context, const RoomsPage()))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GhostButton(label: 'Collection', onTap: () => _open(context, const CollectionPage())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: GhostButton(label: 'Album', onTap: () => _open(context, const AlbumPage()))),
                          const SizedBox(width: 10),
                          Expanded(child: GhostButton(label: 'Upgrades', onTap: () => _open(context, const UpgradesPage()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: GhostButton(label: 'Statistics', onTap: () => _open(context, const StatsPage()))),
                          const SizedBox(width: 10),
                          Expanded(child: GhostButton(label: 'Settings', onTap: () => _open(context, const SettingsPage()))),
                        ],
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, horizonRoute(page));
  }
}

class _GleamChip extends StatelessWidget {
  const _GleamChip({required this.gleam});

  final int gleam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: horizonCard,
      child: Text(
        '$gleam gleam',
        style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }
}
