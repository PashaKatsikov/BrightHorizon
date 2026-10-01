// Dev harness: prints the relay endpoint and a sealed envelope for a
// fixed nonce + body, so the output can be diffed against the Python
// reference packer and POSTed to the live relay as an acceptance test.
//
//   cargo +stable-x86_64-pc-windows-gnu run --example vector
//
// Carries no secret of its own — it exercises the same obfuscated bytes
// the shipped library uses.
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use skyward_seal::{skyward_edge, skyward_free, skyward_pack};

fn take(p: *mut c_char) -> String {
    let s = unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
    unsafe { skyward_free(p) };
    s
}

fn main() {
    let body = "{\"bundle_id\":\"com.sunward.brighthorizon\",\"os\":\"Android\",\"af_status\":\"Non-organic\"}";
    let nonce_hex = "000102030405060708090a0b0c0d0e0f";
    let body_c = CString::new(body).unwrap();
    let nonce_c = CString::new(nonce_hex).unwrap();
    let env = take(unsafe { skyward_pack(body_c.as_ptr(), nonce_c.as_ptr()) });
    let edge = take(unsafe { skyward_edge() });
    println!("EDGE {edge}");
    println!("BODY {body}");
    println!("NONCE {nonce_hex}");
    println!("ENV {env}");
}
