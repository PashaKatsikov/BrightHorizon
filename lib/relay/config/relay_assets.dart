// ============================================================
// RELAY ASSETS — art consumed by the gray surfaces
// ============================================================
// The relay module is forensically isolated from the white game: it
// never imports `lib/src/**`, so it carries its own asset table even
// though the loading plate paths overlap with `lib/src/frames.dart`.
// These are plain string paths, not imports — the isolation rule is
// about Dart dependencies, not about which `.webp` the raw loader opens.
//
// Which stage consumes what (see `.cursor/rules/custom_screens.md`):
//   • boot screen        → loadingPortrait / loadingLandscape
//   • permission stage   → gradient backdrop (`RelayBackdrop`), no art
//   • offline stage      → gradient backdrop (`RelayBackdrop`), no art
//
// The dedicated `Bright_Horizon_additional_assets` plates were retired;
// the gray boot screen now shares the game's own loading art under
// `assets/loading`, so the APK carries a single set of loading plates.
// ============================================================

abstract final class RelayAssets {
  static const String loadingPortrait = 'assets/loading/portrait.webp';
  static const String loadingLandscape = 'assets/loading/landscape.webp';

  /// Everything a gray surface warms before it can be shown. The push
  /// invite and the offline screen paint a gradient (`RelayBackdrop`) with
  /// no artwork, so only the two loading plates are precached.
  static const List<String> warmup = <String>[
    loadingPortrait,
    loadingLandscape,
  ];
}
