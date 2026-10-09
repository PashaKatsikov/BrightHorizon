// ============================================================
// Build script — Android BoringSSL link ordering
// ============================================================
// `wreq` → `btls`/`btls-sys` builds BoringSSL into two archives, `libssl.a`
// and `libcrypto.a`, with circular references between them (libssl calls
// into libcrypto, and libcrypto's error strings reference libssl symbols).
// A single-pass linker resolves each archive only once, so whichever comes
// second drops the objects the first still needed — the final `.so` then
// loses symbols like `SSL_CTX_free` and fails to `dlopen` on device.
//
// Wrapping the two in `--start-group … --end-group` makes the linker scan
// them repeatedly until no undefined references remain, which is the fix
// for the "undefined SSL_/X509_/EVP_" and "cannot locate symbol" classes
// (gray_part_pitfalls.md §3, §2 of this task).
//
// IMPORTANT (btls-sys cross-build, §2 of this task):
//   • Do NOT set CC_<target> / CXX_<target>. btls-sys drives CMake with
//     android.toolchain.cmake, which already picks the right NDK clang.
//     A host CC_ makes the first BoringSSL pass compile `libssl.a` for the
//     HOST (COFF x86-64 on Windows); the linker silently discards those
//     objects and the `.so` ships without any SSL_* symbol.
//   • Put only the NDK `bin` on PATH. CFLAGS_<target>, CXXFLAGS_<target>
//     and BINDGEN_EXTRA_CLANG_ARGS_<target> are safe to keep — cc/bindgen
//     read them, btls ignores them.
//   • Use the newest CMake from the Android SDK with major version < 4
//     (CMake 4 is incompatible with android.toolchain.cmake) and the Ninja
//     generator.
//
// Verify after a build that both archives are ELF aarch64 (magic
// 7F 45 4C 46), never COFF (64 86).
// ============================================================

fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "android" {
        // btls-sys already emits the `-L` search path and `-lssl -lcrypto`;
        // these extra args re-list them inside a group so the circular refs
        // resolve. Order matters: start-group must precede the libs.
        println!("cargo:rustc-link-arg=-Wl,--start-group");
        println!("cargo:rustc-link-arg=-lssl");
        println!("cargo:rustc-link-arg=-lcrypto");
        println!("cargo:rustc-link-arg=-Wl,--end-group");
    }
}
