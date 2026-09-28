// ============================================================
// LEGAL URLs — public policy/support links (plaintext by design)
// ============================================================
// These URLs are visible from the native game's Settings screen
// (Privacy Policy / Support buttons). Encoding them would look
// suspicious to a reviewer — an arcade hiding its own privacy page
// URL is exactly the kind of anomaly a scanner flags. They ship as
// plain string constants.
//
// [FORGE] Rotate all three per project. Never ship two projects with
// the same three URLs — store review cross-references privacy URLs
// between listings to detect templated submissions.
// ============================================================

const String homeLink = 'https://blazebound.online'; // [FORGE]
const String privacyLink = 'https://blazebound.online/privacy-policy.html'; // [FORGE]
const String supportLink = 'https://blazebound.online/support.html'; // [FORGE]
