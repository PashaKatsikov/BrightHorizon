import 'package:flutter/material.dart';

import '../frames.dart';
import '../links.dart';
import '../profile.dart';
import '../widgets.dart';
import 'legal.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return HallPage(
      title: 'Settings',
      background: cabinetBackdrop,
      child: ListView(
        children: [
          Container(
            decoration: horizonCard,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                _Stat('Credits', grouped(profile.credits)),
                _Stat('Spins', grouped(profile.spins)),
                _Stat('Total won', grouped(profile.totalWon)),
                _Stat('Biggest win', grouped(profile.biggestWin)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Bright Horizon is a social casino. Credits are a game token for entertainment. They are not money, they cannot be withdrawn, and they cannot be exchanged for prizes.',
            style: TextStyle(color: cream, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          GhostButton(
            label: 'Privacy Policy',
            onTap: () {
              Navigator.push(
                context,
                horizonRoute(const LegalPage(title: 'Privacy Policy', url: privacyPolicyUrl)),
              );
            },
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'Support',
            onTap: () {
              Navigator.push(
                context,
                horizonRoute(const LegalPage(title: 'Support', url: supportUrl)),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text('Bright Horizon  1.0.0', textAlign: TextAlign.center, style: TextStyle(color: muted)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: muted, fontSize: 15))),
          Text(value, style: const TextStyle(color: cream, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
