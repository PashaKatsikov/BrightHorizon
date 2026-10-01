// ============================================================
// skyward_seal — native slot math for the clean game
// ============================================================
// Every number the cabinet shows is computed HERE, never in the Dart
// AOT image: the reel strips, the paytable, the payline map, the
// scatter awards, the RNG that rolls a window and the evaluator that
// prices it. Dart (`lib/src/slot/slot_gate.dart`) only marshals a stake
// (plus an optional cheat preset and RNG seed) across FFI and renders
// the JSON that comes back.
//
// The crate name is kept aligned with the sibling relay build so the two
// branches share one `.so` name (`libskyward_seal.so`); this white build
// carries only the slot module and no relay/seal code.
// ============================================================

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

// Authoritative slot-machine math. Reel strips, the paytable, the RNG
// and the evaluator all live here, never in Dart.
mod slot;

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

/// Roll and price one spin. `stake` is the total bet; `cheat` selects a
/// preset window when `>= 0` (0 bigWin .. 5 deadSpin), otherwise `-1`
/// rolls randomly from `seed`. Returns the outcome JSON
/// (`{grid,payout,scatter,free,tier,hits}`).
#[no_mangle]
pub extern "C" fn skyward_slot_spin(stake: i64, cheat: i32, seed: u64) -> *mut c_char {
    let outcome = slot::spin(stake, cheat, seed);
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
