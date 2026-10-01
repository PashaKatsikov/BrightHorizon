import 'package:flutter/material.dart';

import '../frames.dart';
import '../profile.dart';
import '../widgets.dart';
import 'cabinet.dart';
import 'paytable.dart';
import 'settings.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileScope.of(context);
    return Scaffold(
      backgroundColor: ink,
      body: Backdrop(
        asset: cabinetBackdrop,
        dim: false,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: (constraints.maxHeight * 0.22).clamp(88, 150),
                        width: (constraints.maxHeight * 0.22).clamp(88, 150) * 2.4,
                        child: Image.asset(logoAsset, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Social casino',
                        style: TextStyle(
                          color: neon,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xC4070418),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x665CE1FF)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'CREDITS',
                              style: TextStyle(
                                color: muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              grouped(profile.credits),
                              style: const TextStyle(
                                color: cream,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Pressable(
                        onTap: () => Navigator.push(context, horizonRoute(const CabinetPage())),
                        child: SizedBox(
                          width: constraints.maxWidth * 0.72,
                          child: AspectRatio(
                            aspectRatio: 729 / 283,
                            child: Image.asset(playAsset, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: GhostButton(
                              label: 'Paytable',
                              onTap: () => Navigator.push(context, horizonRoute(const PaytablePage())),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GhostButton(
                              label: 'Settings',
                              onTap: () => Navigator.push(context, horizonRoute(const SettingsPage())),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'For entertainment only. Credits have no cash value and cannot be exchanged for money or prizes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
