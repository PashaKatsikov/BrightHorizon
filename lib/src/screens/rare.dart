import 'package:flutter/material.dart';

import '../catalog.dart';
import '../frames.dart';
import '../scene.dart';
import '../sheets.dart';
import '../widgets.dart';

class RarePage extends StatefulWidget {
  const RarePage({super.key, required this.eventId, required this.bonus});

  final String eventId;
  final int bonus;

  @override
  State<RarePage> createState() => _RarePageState();
}

class _RarePageState extends State<RarePage> {
  @override
  void initState() {
    super.initState();
    final event = albumById(widget.eventId);
    SheetStore.instance.warm({event.frame.asset, rareFxFrame.asset});
  }

  @override
  Widget build(BuildContext context) {
    final event = albumById(widget.eventId);
    return Scaffold(
      backgroundColor: ink,
      body: Backdrop(
        asset: bgR,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: horizonCard,
                child: Row(
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FrameView(frame: rareFxFrame, opacity: 0.85),
                          Padding(
                            padding: const EdgeInsets.all(28),
                            child: FrameView(frame: event.frame),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rare motion', style: TextStyle(color: gold, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(event.name, style: const TextStyle(color: cream, fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(event.where, style: const TextStyle(color: violet, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text(event.detail, style: const TextStyle(color: cream, height: 1.35)),
                          const SizedBox(height: 8),
                          Text('+${widget.bonus} gleam', style: const TextStyle(color: gold, fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(height: 12),
                          GoldButton(label: 'Keep watching', expand: true, onTap: () => Navigator.pop(context)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
