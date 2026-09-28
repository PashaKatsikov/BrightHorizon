// ============================================================
// RELAY ASSETS — art consumed by the gray surfaces
// ============================================================
// The relay module is forensically isolated from the white game: it
// never imports `lib/src/**`, so it carries its own asset table even
// though a couple of paths overlap with `lib/src/frames.dart`.
//
// Which stage consumes what (see `.cursor/rules/custom_screens.md`):
//   • boot screen        → loadingPortrait / loadingLandscape
//   • permission stage   → noticePortrait  / noticeLandscape
//   • offline stage      → offlinePortrait / offlineLandscape
//
// [FINGERPRINT] The addon folder segment appears verbatim in the APK,
// so two apps sharing it are a trivial cross-submission tell. This
// project's segment (`Bright_Horizon_additional_assets`) is already
// unique to Bright Horizon — do NOT rename it to a generic name, and
// do NOT copy it into a sibling project.
//
// NOTE ON THE OFFLINE ART: this project shipped without dedicated
// `*_Nowifi_Screen.webp` files. The offline stage therefore reuses the
// loading plates as its backdrop and paints its own headline, sub-line
// and Retry button on top. If the artist later delivers dedicated
// no-wifi plates, drop them into the addon folder and repoint the two
// `offline*` constants — nothing else has to change.
// ============================================================

abstract final class RelayAssets {
  static const String _extra = 'assets/Bright_Horizon_additional_assets';

  static const String logo = '$_extra/Game_Name.webp';

  static const String loadingPortrait = '$_extra/Vertical_Loading_Screen.webp';
  static const String loadingLandscape =
      '$_extra/Horizontal_Loading_Screen.webp';

  static const String noticePortrait =
      '$_extra/Vertical_Notifications_Screen.webp';
  static const String noticeLandscape =
      '$_extra/Horizontal_Notifications_Screen.webp';

  static const String offlinePortrait = loadingPortrait;
  static const String offlineLandscape = loadingLandscape;

  /// Everything a gray surface warms before it can be shown. The push
  /// invite and the offline screen paint a gradient (`RelayBackdrop`) with
  /// no artwork, so only the loading plates and the logo are precached.
  static const List<String> warmup = <String>[
    loadingPortrait,
    loadingLandscape,
    logo,
  ];
}
