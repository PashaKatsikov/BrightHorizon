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
      background: bgHorizon,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                decoration: horizonCard,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Sound effects', style: TextStyle(color: cream, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Switch(
                      value: profile.sfxOn,
                      activeThumbColor: const Color(0xFF3A2508),
                      activeTrackColor: gold,
                      onChanged: profile.setSfx,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'Privacy Policy',
                onTap: () {
                  Navigator.push(
                    context,
                    horizonRoute(const LegalPage(title: 'Privacy Policy', url: privacyPolicyUrl, light: true)),
                  );
                },
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'Support',
                onTap: () {
                  Navigator.push(
                    context,
                    horizonRoute(const LegalPage(title: 'Support', url: supportUrl, light: false)),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text('Bright Horizon  1.0.0', style: TextStyle(color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}
