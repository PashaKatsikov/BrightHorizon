import 'package:flutter/material.dart';

import '../audio.dart';
import '../catalog.dart';
import '../frames.dart';
import '../profile.dart';
import '../widgets.dart';
import 'observe.dart';

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return HallPage(
      title: 'Rooms',
      background: bgAtrium,
      child: GridView.builder(
        itemCount: rooms.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
        ),
        itemBuilder: (context, index) {
          final room = rooms[index];
          final open = profile.owns(room.id);
          final previousOpen = index == 0 || profile.owns(rooms[index - 1].id);
          return _RoomCard(
            room: room,
            open: open,
            lockedBehind: !open && !previousOpen,
            gleam: profile.gleam,
            onTap: () => _tap(context, profile, room, open, previousOpen),
          );
        },
      ),
    );
  }

  void _tap(BuildContext context, Profile profile, Room room, bool open, bool previousOpen) {
    if (open) {
      Sfx.instance.play(Sfx.menuOpen);
      Navigator.push(context, horizonRoute(ObservePage(roomId: room.id)));
      return;
    }
    if (!previousOpen) {
      Sfx.instance.play(Sfx.click);
      return;
    }
    if (profile.buyRoom(room)) {
      Sfx.instance.play(Sfx.unlockRoom);
    } else {
      Sfx.instance.play(Sfx.click);
    }
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.open,
    required this.lockedBehind,
    required this.gleam,
    required this.onTap,
  });

  final Room room;
  final bool open;
  final bool lockedBehind;
  final int gleam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final short = gleam >= room.cost ? 'Open for ${room.cost}' : 'Need ${room.cost} gleam';
    final status = open
        ? 'Enter'
        : lockedBehind
        ? 'Later'
        : room.cost == 0
        ? 'Enter'
        : short;
    return Pressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(room.background, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    open ? const Color(0xCC100818) : const Color(0xE6100818),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!open)
                    const Icon(Icons.lock_rounded, color: gold, size: 18)
                  else
                    const SizedBox(height: 18),
                  const Spacer(),
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.blurb,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: cream, fontSize: 11, height: 1.25),
                  ),
                  const SizedBox(height: 4),
                  Text(status, style: const TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
