import 'package:flutter/material.dart';

import '../catalog.dart';
import '../observation.dart';
import '../profile.dart';
import '../widgets.dart';
import 'observe.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.report});

  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    final upcoming = nextLocked(profile.unlocked);
    final room = roomById(report.roomId);
    return HallPage(
      title: 'Session',
      background: room.background,
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          report.roomName,
                          style: const TextStyle(color: muted, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${report.gleam} gleam',
                          style: const TextStyle(
                            color: gold,
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Watched for ${clock(report.seconds)}',
                          style: const TextStyle(color: cream),
                        ),
                        if (report.eventNames.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            report.eventNames.join('  ·  '),
                            style: const TextStyle(color: violet, height: 1.3),
                          ),
                        ],
                        if (upcoming != null &&
                            profile.gleam >= upcoming.cost) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${upcoming.name} can be opened.',
                            style: const TextStyle(
                              color: cream,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: horizonCard,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Line('Coins', report.coins),
                  _Line('Fruit', report.fruits),
                  _Line('Stars', report.stars),
                  _Line('Sevens', report.sevens),
                  _Line('Rare motions', report.events),
                  const SizedBox(height: 12),
                  GoldButton(
                    label: 'Watch again',
                    expand: true,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        horizonRoute(ObservePage(roomId: report.roomId)),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  GhostButton(
                    label: 'Back to the hall',
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: muted)),
          const Spacer(),
          Text(
            '$value',
            style: const TextStyle(color: cream, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
