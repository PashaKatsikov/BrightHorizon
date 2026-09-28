import 'package:flutter/material.dart';

import '../../app/relay_buttons.dart';
import '../../app/relay_theme.dart';

// ============================================================
// OFFLINE STAGE — "no connection" surface
// ============================================================
// Shown whenever the relay pipeline concludes "no network", and also by
// `portal_stage.dart` when a live connectivity drop survives the
// `reachDropDebounceMs` debounce.
//
// Retry rebuilds the caller-supplied route through `pushReplacement`.
// The pipeline is idempotent by design — the coordinator's in-flight
// cache clears on completion — so Retry runs the full boot flow fresh
// (attribution → probe → verdict).
//
// LAYOUT
// The backdrop is the SAME `RelayBackdrop` gradient the push invite uses
// (no artwork). The message card is identical in both orientations — one
// stacked column (icon, headline, sub-line) — and the whole thing lives
// in a centred `SingleChildScrollView` so it fits a short landscape phone
// without clipping. Horizontal SafeArea is OFF so the notch inset does
// not shove the centred card sideways in landscape.
// ============================================================

class OfflineStage extends StatefulWidget {
  const OfflineStage({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage> {
  bool _spinning = false;

  Future<void> _retry() async {
    if (_spinning) return;
    setState(() => _spinning = true);
    // A beat of feedback: an instant route swap on a still-dead network
    // reads as "the button did nothing".
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final double cardWidth = landscape
        ? (mq.size.width * 0.6).clamp(320.0, 520.0)
        : (mq.size.width * 0.84).clamp(260.0, 420.0);
    final double retryWidth = landscape
        ? (mq.size.width * 0.34).clamp(200.0, 320.0)
        : (mq.size.width * 0.72).clamp(220.0, 380.0);

    return Scaffold(
      backgroundColor: RelayPalette.ink,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const RelayBackdrop(),
          SafeArea(
            left: false,
            right: false,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: landscape ? 16 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _MessageCard(maxWidth: cardWidth),
                    SizedBox(height: landscape ? 20 : 28),
                    SizedBox(
                      height: 54,
                      child: _spinning
                          ? const Center(
                              child: SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      RelayPalette.gold),
                                ),
                              ),
                            )
                          : RelayPillButton(
                              label: 'Retry',
                              width: retryWidth,
                              height: 54,
                              icon: Icons.refresh_rounded,
                              onTap: _retry,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The same card in both orientations, per the design: a violet wifi-off
/// disc, the required headline and the sub-line, stacked and centred.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: RelayTheme.card,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: <Color>[Color(0x66C77DFF), Color(0x333A2560)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: RelayPalette.gold,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NO INTERNET CONNECTION',
              textAlign: TextAlign.center,
              style: RelayTheme.headline(size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              textAlign: TextAlign.center,
              style: RelayTheme.subline(size: 15),
            ),
          ],
        ),
      ),
    );
  }
}
