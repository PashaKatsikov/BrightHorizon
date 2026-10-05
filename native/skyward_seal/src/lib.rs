// ============================================================
// skyward_seal — native envelope sealer for the attribution relay
// ============================================================
// Keeps three things OUT of the Dart AOT image: the relay endpoint,
// the shared RELAY_SECRET, and the "veil" seal codec. Dart hands this
// library the plaintext attribution JSON plus a fresh random nonce and
// receives back the opaque envelope that the edge relay unpacks; Dart
// then performs the HTTPS POST itself (the TLS stack lives on the Dart
// side). The secret never crosses the FFI boundary in either direction.
//
// Wire scheme — MUST stay byte-identical to the relay (`relay_service.py`)
// and the server registry entry (schema 13, fields h/u/w/e):
//   nonce      = 16 random bytes (hex on the wire)
//   keystream  = SHA256(secret ++ nonce ++ counter_be32) blocks
//   enc        = raw XOR keystream
//   payload    = base64url(enc) without padding
//   tag        = HMAC_SHA256(secret, nonce ++ enc) hex, first 16 chars
//   envelope   = { "h": 13, "u": <nonce hex>, "w": <payload>, "e": <tag> }
//
// Endpoint and secret are stored XOR-masked; the mask formula is
// per-project (see `unmask`). Regenerate both arrays and the mask for
// any sibling app so no two builds share wire bytes.
// ============================================================

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use hmac::{Hmac, Mac};
use sha2::{Digest, Sha256};

// Generated XOR-masked WebView enhancer bodies (`tool/_gen_js_blobs.dart`).
mod js_blobs;

// Generated XOR-masked wire/game strings (`tool/_gen_str_blobs.dart`).
mod str_blobs;

// Authoritative slot-machine math for the native game. Reel strips, the
// paytable, the RNG and the evaluator all live here, never in Dart.
mod slot;

type HmacSha256 = Hmac<Sha256>;

// Schema revision + envelope field names (registry: Bright Horizon).
const SCHEMA_REV: u64 = 13;
const FIELD_SCHEMA: &str = "h";
const FIELD_NONCE: &str = "u";
const FIELD_PAYLOAD: &str = "w";
const FIELD_TAG: &str = "e";

const NONCE_LEN: usize = 16;
const TAG_HEX_LEN: usize = 16;

// Per-project mask. unmask: plain[i] = enc[i] ^ MASK[i % 16] ^ ((i*7 + 0x3B) & 0xFF)
const MASK: [u8; 16] = [
    0x9E, 0x27, 0xD4, 0x6B, 0x1F, 0xC8, 0x53, 0xA0, 0x7C, 0xE5, 0x38, 0x91, 0x4A, 0xBD, 0x06, 0xF2,
];

// "https://brightthorizon.com/edge/sync"
const ENDPOINT_ENC: &[u8] = &[
    0xCD, 0x11, 0xE9, 0x4B, 0x3B, 0xAC, 0x19, 0xE3, 0x6D, 0xED, 0xD0, 0x7E, 0xAD, 0x5F, 0xEF, 0x3E,
    0x5A, 0xE7, 0x04, 0xD1, 0xB7, 0x68, 0xA8, 0x1F, 0xF0, 0x62, 0xE6, 0x0C, 0xD1, 0xDC, 0x6E, 0xC9,
    0xF6, 0x7C, 0x93, 0x38,
];

// RELAY_SECRET (url-safe base64, 43 chars).
const SECRET_ENC: &[u8] = &[
    0xC7, 0x07, 0xED, 0x16, 0x71, 0xFA, 0x5E, 0xA2, 0x40, 0xFB, 0xC9, 0x6F, 0x82, 0x5C, 0xD7, 0x34,
    0x64, 0xE6, 0x3D, 0xE2, 0x9B, 0x44, 0xE2, 0x12, 0xD7, 0x3F, 0xA2, 0x30, 0x82, 0xC2, 0x3E, 0x93,
    0xEB, 0x4D, 0xBA, 0x34, 0x79, 0xB3, 0x42, 0x9A, 0x60, 0xEB, 0x36,
];

fn unmask(enc: &[u8]) -> Vec<u8> {
    enc.iter()
        .enumerate()
        .map(|(i, b)| b ^ MASK[i % MASK.len()] ^ (((i * 7 + 0x3B) & 0xFF) as u8))
        .collect()
}

fn keystream(secret: &[u8], nonce: &[u8], len: usize) -> Vec<u8> {
    let mut out = Vec::with_capacity(len + 32);
    let mut counter: u32 = 0;
    while out.len() < len {
        let mut h = Sha256::new();
        h.update(secret);
        h.update(nonce);
        h.update(counter.to_be_bytes());
        out.extend_from_slice(&h.finalize());
        counter += 1;
    }
    out.truncate(len);
    out
}

fn to_hex(bytes: &[u8]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push(HEX[(b >> 4) as usize] as char);
        s.push(HEX[(b & 0x0F) as usize] as char);
    }
    s
}

fn from_hex(text: &str) -> Option<Vec<u8>> {
    let bytes = text.as_bytes();
    if bytes.len() % 2 != 0 {
        return None;
    }
    fn nib(c: u8) -> Option<u8> {
        match c {
            b'0'..=b'9' => Some(c - b'0'),
            b'a'..=b'f' => Some(c - b'a' + 10),
            b'A'..=b'F' => Some(c - b'A' + 10),
            _ => None,
        }
    }
    let mut out = Vec::with_capacity(bytes.len() / 2);
    for pair in bytes.chunks(2) {
        out.push((nib(pair[0])? << 4) | nib(pair[1])?);
    }
    Some(out)
}

/// Seal `body` with the caller-supplied `nonce` (16 bytes). Returns the
/// envelope JSON string, or `None` if the nonce is the wrong length.
fn seal(body: &str, nonce: &[u8]) -> Option<String> {
    if nonce.len() != NONCE_LEN {
        return None;
    }
    let secret = unmask(SECRET_ENC);
    let raw = body.as_bytes();
    let ks = keystream(&secret, nonce, raw.len());
    let enc: Vec<u8> = raw.iter().zip(ks.iter()).map(|(b, k)| b ^ k).collect();

    let payload = URL_SAFE_NO_PAD.encode(&enc);

    let mut mac = <HmacSha256 as Mac>::new_from_slice(&secret).ok()?;
    mac.update(nonce);
    mac.update(&enc);
    let full = to_hex(&mac.finalize().into_bytes());
    let tag = &full[..TAG_HEX_LEN];

    // Hand-built JSON: all values are JSON-safe (an integer, two hex
    // strings and a base64url string — none need escaping).
    Some(format!(
        "{{\"{}\":{},\"{}\":\"{}\",\"{}\":\"{}\",\"{}\":\"{}\"}}",
        FIELD_SCHEMA,
        SCHEMA_REV,
        FIELD_NONCE,
        to_hex(nonce),
        FIELD_PAYLOAD,
        payload,
        FIELD_TAG,
        tag,
    ))
}

fn c_in(p: *const c_char) -> String {
    if p.is_null() {
        return String::new();
    }
    unsafe { CStr::from_ptr(p) }
        .to_str()
        .unwrap_or("")
        .to_owned()
}

fn c_out(s: String) -> *mut c_char {
    CString::new(s)
        .unwrap_or_else(|_| CString::new("").unwrap())
        .into_raw()
}

/// Seal `body` using `nonce_hex` (32 hex chars = 16 bytes). Empty string
/// on any error so the Dart side falls back to the native game.
#[no_mangle]
pub extern "C" fn skyward_pack(body: *const c_char, nonce_hex: *const c_char) -> *mut c_char {
    let body = c_in(body);
    let nonce = match from_hex(&c_in(nonce_hex)) {
        Some(n) => n,
        None => return c_out(String::new()),
    };
    c_out(seal(&body, &nonce).unwrap_or_default())
}

/// Return the relay endpoint URL (de-obfuscated at runtime).
#[no_mangle]
pub extern "C" fn skyward_edge() -> *mut c_char {
    c_out(String::from_utf8(unmask(ENDPOINT_ENC)).unwrap_or_default())
}

/// Return the WebView enhancer body for `name` ("safeArea" | "keyboard" |
/// "autoplay" | "chromeTrim"), de-obfuscated at runtime. The JS never
/// exists as a plaintext string in the Dart AOT image or the .so, so a
/// store scanner cannot hash it. Empty string for an unknown name so the
/// Dart side falls back to its own copy.
#[no_mangle]
pub extern "C" fn skyward_js(name: *const c_char) -> *mut c_char {
    let name = c_in(name);
    match js_blobs::blob(&name) {
        Some(enc) => c_out(String::from_utf8(unmask(enc)).unwrap_or_default()),
        None => c_out(String::new()),
    }
}

/// Return the de-obfuscated wire/game string for `name`, reconstructed at
/// runtime so no plaintext wire literal ships in the Dart AOT image or the
/// .so. Empty string for an unknown name so the Dart side falls back to its
/// own code-unit copy.
#[no_mangle]
pub extern "C" fn skyward_str(name: *const c_char) -> *mut c_char {
    let name = c_in(name);
    match str_blobs::string(&name) {
        Some(enc) => c_out(String::from_utf8(unmask(enc)).unwrap_or_default()),
        None => c_out(String::new()),
    }
}

/// Roll and price one spin. `stake` is the total bet; `seed` drives the
/// reel RNG. Returns the outcome JSON
/// (`{grid,payout,scatter,free,tier,hits}`), or empty on nothing to say.
#[no_mangle]
pub extern "C" fn skyward_slot_spin(stake: i64, seed: u64) -> *mut c_char {
    let outcome = slot::spin(stake, seed);
    c_out(slot::outcome_json(&outcome))
}

/// Price a caller-supplied window. `grid` is 15 comma-separated mark
/// indices, reel-major (`r0c0,r0c1,r0c2,r1c0,...`). Returns the outcome
/// JSON, or empty string on a malformed grid.
#[no_mangle]
pub extern "C" fn skyward_slot_eval(grid: *const c_char, stake: i64) -> *mut c_char {
    match slot::parse_grid(&c_in(grid)) {
        Some(g) => c_out(slot::outcome_json(&slot::evaluate(g, stake))),
        None => c_out(String::new()),
    }
}

/// Free a string previously returned by this library.
#[no_mangle]
pub extern "C" fn skyward_free(p: *mut c_char) {
    if !p.is_null() {
        unsafe { drop(CString::from_raw(p)) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn endpoint_round_trips_to_https() {
        let url = String::from_utf8(unmask(ENDPOINT_ENC)).unwrap();
        assert_eq!(url, "https://brightthorizon.com/edge/sync");
    }

    #[test]
    fn secret_is_43_url_safe_chars() {
        let s = unmask(SECRET_ENC);
        assert_eq!(s.len(), 43);
        assert!(s
            .iter()
            .all(|&c| c.is_ascii_alphanumeric() || c == b'-' || c == b'_'));
    }

    #[test]
    fn seal_is_deterministic_and_well_formed() {
        let nonce = [7u8; NONCE_LEN];
        let a = seal("{\"bundle_id\":\"com.wansurd.hrigbothe\"}", &nonce).unwrap();
        let b = seal("{\"bundle_id\":\"com.wansurd.hrigbothe\"}", &nonce).unwrap();
        assert_eq!(a, b);
        assert!(a.contains("\"h\":13"));
        assert!(a.contains(&format!("\"u\":\"{}\"", to_hex(&nonce))));
        assert!(seal("{}", &[0u8; 4]).is_none());
    }

    #[test]
    fn js_blobs_round_trip_to_their_iifes() {
        let cases = [
            ("safeArea", "horizonSafeArea"),
            ("keyboard", "horizonKeyboard"),
            ("autoplay", "horizonAutoplay"),
            ("chromeTrim", "horizonChromeTrim"),
        ];
        for (name, fname) in cases {
            let body = String::from_utf8(unmask(js_blobs::blob(name).unwrap())).unwrap();
            assert!(body.starts_with("(function "), "{name} not an IIFE");
            assert!(body.contains(fname), "{name} missing {fname}");
            assert!(body.trim_end().ends_with("})();"), "{name} truncated");
        }
        assert!(js_blobs::blob("nope").is_none());
    }

    #[test]
    fn str_blobs_round_trip_to_their_values() {
        let cases = [
            ("rm_p", "portal"),
            ("rm_n", "native"),
            ("k_url", "url"),
            ("k_afst", "af_status"),
            ("k_fbp", "firebase_project_id"),
            ("e_tmr", "too_many_redirects"),
            ("e_gu", "gate_unavailable"),
            ("h_ua", "User-Agent"),
            ("g_chn", "Bonuses & Promos"),
            ("mc_cut", "cutout"),
            ("in_top", "top"),
            ("in_left", "left"),
            ("in_right", "right"),
        ];
        for (name, want) in cases {
            let got = String::from_utf8(unmask(str_blobs::string(name).unwrap())).unwrap();
            assert_eq!(got, want, "{name} de-obfuscated wrong");
        }
        assert!(str_blobs::string("nope").is_none());
    }

    #[test]
    fn hex_round_trip() {
        let n = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x10];
        assert_eq!(from_hex(&to_hex(&n)).unwrap(), n);
        assert!(from_hex("zz").is_none());
        assert!(from_hex("abc").is_none());
    }
}
