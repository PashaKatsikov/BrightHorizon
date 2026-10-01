// ============================================================
// LANDING — verdict + routing outcome (sealed types)
// ============================================================
// The routing pipeline outputs ONE of three sealed subtypes. The boot
// screen destructures the result via a `switch` and only then decides
// which screen to push. Sealed dispatch means a new destination forces
// a new case label at every dispatch site — a branch cannot be
// silently forgotten.
// ============================================================

import '../wire/veiled_strings.dart';

/// Persisted routing memory across launches.
///
/// The wire values are stored in the keystore under a project-scoped
/// key. Do NOT rename the wire strings — legacy installs still hold
/// the old value.
enum RouteMemory {
  undecided,
  portal,
  native;

  String get wireValue => switch (this) {
        RouteMemory.undecided => VeiledStrings.get('rm_u'),
        RouteMemory.portal => VeiledStrings.get('rm_p'),
        RouteMemory.native => VeiledStrings.get('rm_n'),
      };

  static RouteMemory parse(String? raw) {
    if (raw == VeiledStrings.get('rm_p') || raw == VeiledStrings.get('rm_w')) {
      return RouteMemory.portal;
    }
    if (raw == VeiledStrings.get('rm_n') || raw == VeiledStrings.get('rm_g')) {
      return RouteMemory.native;
    }
    return RouteMemory.undecided;
  }
}

/// Parsed response from the verdict endpoint.
///
/// Wire keys are `{ok, url, expires, message}` — mapped verbatim, no
/// key renaming. The backend contract preserves those exact spellings.
class Verdict {
  const Verdict({
    required this.approved,
    this.url,
    this.expiresAt,
    this.note,
  });

  factory Verdict.fromJson(Map<String, dynamic> json) {
    final dynamic rawExpiry = json['expires'];
    return Verdict(
      approved: json['ok'] == true,
      url: json[VeiledStrings.get('k_url')] is String
          ? json[VeiledStrings.get('k_url')] as String
          : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      note: json['message']?.toString(),
    );
  }

  factory Verdict.rejected(String note) =>
      Verdict(approved: false, note: note);

  final bool approved;
  final String? url;
  final int? expiresAt;
  final String? note;

  bool get hasDestination => approved && url != null && url!.isNotEmpty;
}

/// Sealed outcome of the boot pipeline.
sealed class Landing {
  const Landing();
}

/// Show the native game.
final class GameLanding extends Landing {
  const GameLanding();
}

/// Show the WebView portal at [url].
///
/// [coldTap] is true only when the launch was triggered by a cold-boot
/// push notification tap — the URL comes from the intent payload, not
/// from the verdict cache, and the boot animation should be shortened.
final class PortalLanding extends Landing {
  const PortalLanding(this.url, {this.coldTap = false});

  final String url;
  final bool coldTap;
}

/// Show the no-connection screen. Retry rebuilds the boot pipeline.
///
/// [returnsToGame] is true when the user was previously in native mode
/// — the retry after Wi-Fi returns can immediately show the game rather
/// than rerunning the whole verdict pipeline.
final class OfflineLanding extends Landing {
  const OfflineLanding({required this.returnsToGame});

  final bool returnsToGame;
}
