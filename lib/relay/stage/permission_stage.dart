import 'package:flutter/material.dart';

import '../../app/relay_buttons.dart';
import '../../app/relay_theme.dart';
import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import '../wire/veiled_strings.dart';
import 'portal_stage.dart';

// ============================================================
// PERMISSION STAGE — push opt-in promo
// ============================================================
// One-shot invite shown before the portal, and only when
// `keystore.shouldInvitePermission` is true (first entry into gray mode,
// or after the snooze window expired). Three outcomes are persisted:
//   • granted        → never shown again
//   • declined here  → snoozed for `permissionSnoozeSeconds`
//   • denied by the OS → never shown again (Android permanently
//     suppresses the prompt after one hard denial on API 33+)
//
// This surface paints its OWN copy on a gradient backdrop rather than
// leaning on a pre-rendered plate: `RelayBackdrop` (the same violet→ink
// gradient the offline screen uses), a bell medallion, the required
// headline / sub-line, and the two actions.
//
// Layout is orientation-aware but overflow-proof: the whole block sits in
// a centred `SingleChildScrollView`, so it can never clip on a short
// landscape phone. Horizontal SafeArea is intentionally OFF — the notch
// inset would shove the centred column sideways in landscape. The decline
// action is a real gradient button (never a faded text link).
// ============================================================

class PermissionStage extends StatefulWidget {
  const PermissionStage({
    super.key,
    required this.keystore,
    required this.alerts,
    required this.destinationUrl,
  });

  final BeaconKeystore keystore;
  final AlertChannel alerts;
  final String destinationUrl;

  @override
  State<PermissionStage> createState() => _PermissionStageState();
}

class _PermissionStageState extends State<PermissionStage> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    // `askPermission` already persists the granted / OS-denied flags. The
    // snooze here only covers the third outcome: the user swiped the
    // system sheet away without answering, which leaves the permission
    // undetermined and would otherwise re-prompt on the very next launch.
    final bool granted = await widget.alerts.askPermission();
    if (!granted) {
      await widget.keystore.writePermissionSnoozeUntil(_snoozeTarget());
    }
    if (mounted) _forward();
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.keystore.writePermissionSnoozeUntil(_snoozeTarget());
    if (mounted) _forward();
  }

  int _snoozeTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      RelayConfig.permissionSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PortalStage(
          url: widget.destinationUrl,
          keystore: widget.keystore,
          alerts: widget.alerts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final double maxContent = landscape
        ? (mq.size.width * 0.7).clamp(360.0, 620.0)
        : (mq.size.width * 0.86).clamp(280.0, 460.0);

    return Scaffold(
      backgroundColor: RelayPalette.ink,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const RelayBackdrop(),
          // Horizontal safe area off on purpose (see header). Vertical
          // padding keeps the block off the status bar / gesture area.
          SafeArea(
            left: false,
            right: false,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: landscape ? 16 : 28,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContent),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const _BellMedallion(),
                      SizedBox(height: landscape ? 16 : 26),
                      Text(
                        VeiledStrings.get('g_notif'),
                        textAlign: TextAlign.center,
                        style: RelayTheme.headline(size: landscape ? 21 : 25),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Stay tuned for special offers and rewards',
                        textAlign: TextAlign.center,
                        style: RelayTheme.subline(size: landscape ? 14 : 16),
                      ),
                      SizedBox(height: landscape ? 22 : 34),
                      _Actions(
                        landscape: landscape,
                        width: maxContent,
                        onAccept: _accept,
                        onDecline: _decline,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gold bell in a glowing violet disc — the visual anchor for the invite.
class _BellMedallion extends StatelessWidget {
  const _BellMedallion();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[Color(0x80C77DFF), Color(0x1A3A2560)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Color(0x66C79BFF), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: const Icon(
        Icons.notifications_active_rounded,
        color: RelayPalette.gold,
        size: 48,
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.landscape,
    required this.width,
    required this.onAccept,
    required this.onDecline,
  });

  final bool landscape;
  final double width;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final Widget allow = RelayPillButton(
      label: 'Allow',
      width: landscape ? (width * 0.42).clamp(180.0, 300.0) : null,
      height: 54,
      icon: Icons.notifications_active_rounded,
      onTap: onAccept,
    );
    final Widget notNow = RelayPillButton(
      label: 'Not now',
      width: landscape ? (width * 0.34).clamp(150.0, 240.0) : null,
      height: 48,
      secondary: true,
      onTap: onDecline,
    );

    if (landscape) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[allow, const SizedBox(width: 14), notNow],
      );
    }
    // Portrait: full-width stacked buttons.
    return Column(
      children: <Widget>[
        SizedBox(width: double.infinity, child: allow),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: notNow),
      ],
    );
  }
}
