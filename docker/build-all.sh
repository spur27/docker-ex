#!/usr/bin/env bash
# Build comprehensive_usage across every cross-compilation target.
# Continues on failure and prints a pass/fail summary at the end.
# Linux/Android/BSD/Windows/WASM: run inside the docker-ex container.
# macOS/iOS: detected automatically and run natively (requires Xcode + rustup targets).
set -uo pipefail

# ── Feature sets ──────────────────────────────────────────────────────────────
# Full desktop build: every feature including GUI, engines, web view, and tray.
FEATURES_FULL="logger,cli,web_server,engine_2d,engine_3d,webview,window,gui,process,config,db,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,dialog,watch,compress,regex,system,mongodb,cassandra,xml,yaml,binary,dynlib,menu,tray,imgui,noise,tracing,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# powerpc-unknown-linux-gnu is the ONLY 32-bit target lacking AtomicI64/AtomicU64.
# i686 has cmpxchg8b; armv7/arm/thumbv7neon get 64-bit atomics via LDREXD or Linux kernel
# helpers — all confirmed via `rustc --target <triple> --print cfg | grep atomic`.
# Drops tracing (opentelemetry_sdk uses AtomicU64), engines (Bevy uses AtomicU64 internally),
# and cassandra (scylla 0.15.1 uses AtomicU64 directly in src/transport/metrics.rs).
FEATURES_FULL_NO_ATOMIC64="logger,cli,web_server,webview,window,gui,process,config,db,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,dialog,watch,compress,regex,system,mongodb,xml,yaml,binary,dynlib,menu,tray,imgui,noise,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# Headless: server/embedded targets — no display server, GTK3, WebKitGTK, or engine sysroot
# required. Roughly FEATURES_FULL minus engine_2d/3d, webview, window, gui, dialog, menu,
# tray, imgui (all of which need a native GUI toolkit or display server to link against).
FEATURES_HEADLESS="logger,cli,web_server,process,config,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,watch,compress,regex,system,xml,yaml,binary,dynlib,noise,tracing,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# powerpc-32bit headless: same no-atomic64 restriction; drops tracing and cassandra.
FEATURES_HEADLESS_NO_ATOMIC64="logger,cli,web_server,process,config,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,watch,compress,regex,system,xml,yaml,binary,dynlib,noise,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# musl targets cannot statically link libasound (ALSA); drop sound.
FEATURES_MUSL="logger,cli,web_server,process,config,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,watch,compress,regex,system,xml,yaml,binary,dynlib,noise,tracing,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# BSD nightly (-Z build-std, Tier 3): drop tracing to avoid the tower 0.4.13 → indexmap 1.9.3
# autocfg probe failure under build-std (indexmap's has_std check fails, breaking IndexMap use).
# Both tower 0.4 and 0.5 are present in the lockfile; until tower 0.4 is fully dropped, this
# restriction stays. Otherwise identical to FEATURES_HEADLESS.
FEATURES_BSD_NIGHTLY="logger,cli,web_server,process,config,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,watch,compress,regex,system,xml,yaml,binary,dynlib,noise,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# BSD GUI (stable Tier 2 x86_64 targets with bundled sysroots): full feature set except tray.
# tray is omitted because most BSD desktops lack a system tray D-Bus implementation.
FEATURES_BSD_GUI="logger,cli,web_server,engine_2d,engine_3d,webview,window,gui,process,config,db,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,dialog,watch,compress,regex,system,mongodb,cassandra,xml,yaml,binary,dynlib,menu,imgui,noise,tracing,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# BSD GUI without webview — for targets whose sysroots lack webkit2gtk-4.1.
# NetBSD pkgsrc ships webkit2gtk 4.0 (2.36.8), not 4.1; the cross sysroot does not
# include webkit2gtk at all, so wry cannot be cross-compiled for NetBSD.
FEATURES_GUI_NO_WEBVIEW="logger,cli,web_server,engine_2d,engine_3d,window,gui,process,config,db,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,dialog,watch,compress,regex,system,mongodb,cassandra,xml,yaml,binary,dynlib,menu,imgui,noise,tracing,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# Mobile (Android NDK r27d + iOS): Bevy engines, wry webview, winit window, egui gui,
# cpal+oboe sound, rfd dialog. Unified because compilation requirements are identical.
# menu/tray omitted: muda 0.19.2 platform_impl has no Android or iOS backend (Windows/macOS/
# Linux/BSD only) — adding them would cause a compile error on both platforms.
# imgui omitted: imgui-winit-support imports winit::platform::modifier_supplement which is a
# desktop-only platform extension (X11/Wayland/Win32/macOS) — not present on Android or iOS.
# web_server included: tokio TCP stack compiles for both; iOS App Store sandbox is a runtime
# deployment constraint, not a compilation one.
FEATURES_MOBILE="logger,cli,web_server,engine_2d,engine_3d,webview,window,gui,process,config,db,ipc,auth,crypto,cache,task,fs,serial,json,bson,net,metrics,error,http_client,parallel,datetime,uuid,env,dialog,watch,compress,regex,system,mongodb,cassandra,xml,yaml,binary,dynlib,noise,tracing,sound,open,tui,math,itertools,strum,derive_more,nom,image,zip,csv,docker,k8s,ndarray,ml"

# WASI (P1 + P2 share one set): WASI SDK sysroot enables C-compiled crates (zstd-sys).
# Blocked: tokio multi-thread runtimes (web_server/net/task/db), rayon (parallel), audio, GUI.
# tui omitted: crossterm 0.28.1 sys::position and sys::supports_keyboard_enhancement are not
# implemented for any wasm32 target — both modules hit compile_error! on wasm32-wasip1/p2.
# compress works via zstd-sys + WASI SDK clang.
FEATURES_WASM_WASI="logger,cli,serial,json,bson,xml,yaml,binary,auth,crypto,compress,regex,error,datetime,uuid,env,noise,image,zip,csv,nom,math,itertools,strum,derive_more,ndarray,ml"

# wasm32-unknown-unknown: identical pure-Rust feature set to WASI — none of these crates require
# OS syscalls. tui omitted: crossterm 0.28.1 sys::position and sys::supports_keyboard_enhancement
# are not implemented for wasm32-unknown-unknown either (only wasm32 with target_os = "wasi" gets
# the WASI backend; -unknown-unknown has no OS backend at all). compress uses the pure-Rust path
# (not zstd-sys, which needs a WASI sysroot). Omitted: parallel (no threads), net/fs/process.
FEATURES_WASM="logger,cli,serial,json,bson,xml,yaml,binary,auth,crypto,compress,regex,error,datetime,uuid,env,noise,image,zip,csv,nom,math,itertools,strum,derive_more,ndarray,ml"

PASS=()
FAIL=()

EX=(cargo build --example comprehensive_usage --no-default-features)
EX_N=(cargo +nightly build -Z build-std --example comprehensive_usage --no-default-features)

run() {
    local label="$1"; shift
    printf '\n\033[1;34m─── %s ───\033[0m\n' "$label"
    if "$@"; then
        PASS+=("$label")
        printf '\033[1;32m✓ PASS\033[0m\n'
    else
        FAIL+=("$label")
        printf '\033[1;31m✗ FAIL\033[0m\n'
    fi
}

# ── Linux GNU headless ────────────────────────────────────────────────────────
run "aarch64-unknown-linux-gnu (headless)"             "${EX[@]}" --target aarch64-unknown-linux-gnu             --features "$FEATURES_HEADLESS"
run "armv7-unknown-linux-gnueabihf (headless)"         "${EX[@]}" --target armv7-unknown-linux-gnueabihf         --features "$FEATURES_HEADLESS"
run "arm-unknown-linux-gnueabihf (headless)"           "${EX[@]}" --target arm-unknown-linux-gnueabihf           --features "$FEATURES_HEADLESS"
run "thumbv7neon-unknown-linux-gnueabihf (headless)"   "${EX[@]}" --target thumbv7neon-unknown-linux-gnueabihf   --features "$FEATURES_HEADLESS"
run "i686-unknown-linux-gnu (headless)"                "${EX[@]}" --target i686-unknown-linux-gnu                --features "$FEATURES_HEADLESS"
run "powerpc64-unknown-linux-gnu (headless)"           "${EX[@]}" --target powerpc64-unknown-linux-gnu           --features "$FEATURES_HEADLESS"
run "powerpc64le-unknown-linux-gnu (headless)"         "${EX[@]}" --target powerpc64le-unknown-linux-gnu         --features "$FEATURES_HEADLESS"
run "powerpc-unknown-linux-gnu (headless no-atomic64)" "${EX[@]}" --target powerpc-unknown-linux-gnu             --features "$FEATURES_HEADLESS_NO_ATOMIC64"
run "riscv64gc-unknown-linux-gnu (headless)"           "${EX[@]}" --target riscv64gc-unknown-linux-gnu           --features "$FEATURES_HEADLESS"
run "s390x-unknown-linux-gnu (headless)"               "${EX[@]}" --target s390x-unknown-linux-gnu               --features "$FEATURES_HEADLESS"
run "sparc64-unknown-linux-gnu (headless)"             "${EX[@]}" --target sparc64-unknown-linux-gnu             --features "$FEATURES_HEADLESS"
run "loongarch64-unknown-linux-gnu (headless)"         "${EX[@]}" --target loongarch64-unknown-linux-gnu         --features "$FEATURES_HEADLESS"
run "x86_64-unknown-linux-musl (musl)"                 "${EX[@]}" --target x86_64-unknown-linux-musl             --features "$FEATURES_MUSL"
run "aarch64-unknown-linux-musl (musl)"                "${EX[@]}" --target aarch64-unknown-linux-musl            --features "$FEATURES_MUSL"

# ── Linux GNU full-GUI (requires bundled sysroots) ────────────────────────────
# arm/thumbv7neon have 64-bit atomics via Linux kernel helpers (confirmed above); both share
# the arm-linux-gnueabihf sysroot which includes WebKitGTK + GTK3.
run "x86_64-unknown-linux-gnu (full)"                  "${EX[@]}"                                                --features "$FEATURES_FULL"
run "aarch64-unknown-linux-gnu (full)"                 "${EX[@]}" --target aarch64-unknown-linux-gnu             --features "$FEATURES_FULL"
run "armv7-unknown-linux-gnueabihf (full)"             "${EX[@]}" --target armv7-unknown-linux-gnueabihf         --features "$FEATURES_FULL"
run "arm-unknown-linux-gnueabihf (full)"               "${EX[@]}" --target arm-unknown-linux-gnueabihf           --features "$FEATURES_FULL"
run "thumbv7neon-unknown-linux-gnueabihf (full)"       "${EX[@]}" --target thumbv7neon-unknown-linux-gnueabihf   --features "$FEATURES_FULL"
run "i686-unknown-linux-gnu (full)"                    "${EX[@]}" --target i686-unknown-linux-gnu                --features "$FEATURES_FULL"
run "powerpc64-unknown-linux-gnu (full)"               "${EX[@]}" --target powerpc64-unknown-linux-gnu           --features "$FEATURES_FULL"
run "powerpc64le-unknown-linux-gnu (full)"             "${EX[@]}" --target powerpc64le-unknown-linux-gnu         --features "$FEATURES_FULL"
run "powerpc-unknown-linux-gnu (full no-atomic64)"     "${EX[@]}" --target powerpc-unknown-linux-gnu             --features "$FEATURES_FULL_NO_ATOMIC64"
run "riscv64gc-unknown-linux-gnu (full)"               "${EX[@]}" --target riscv64gc-unknown-linux-gnu           --features "$FEATURES_FULL"
run "s390x-unknown-linux-gnu (full)"                   "${EX[@]}" --target s390x-unknown-linux-gnu               --features "$FEATURES_FULL"
run "sparc64-unknown-linux-gnu (full)"                 "${EX[@]}" --target sparc64-unknown-linux-gnu             --features "$FEATURES_FULL"
run "loongarch64-unknown-linux-gnu (full)"             "${EX[@]}" --target loongarch64-unknown-linux-gnu         --features "$FEATURES_FULL"

# ── Android ───────────────────────────────────────────────────────────────────
run "aarch64-linux-android (mobile)"                   "${EX[@]}" --target aarch64-linux-android                 --features "$FEATURES_MOBILE"
run "armv7-linux-androideabi (mobile)"                 "${EX[@]}" --target armv7-linux-androideabi               --features "$FEATURES_MOBILE"
run "i686-linux-android (mobile)"                      "${EX[@]}" --target i686-linux-android                    --features "$FEATURES_MOBILE"
run "x86_64-linux-android (mobile)"                    "${EX[@]}" --target x86_64-linux-android                  --features "$FEATURES_MOBILE"

# ── BSD (stable) ──────────────────────────────────────────────────────────────
run "x86_64-unknown-freebsd (headless)"                "${EX[@]}" --target x86_64-unknown-freebsd                --features "$FEATURES_HEADLESS"
run "x86_64-unknown-freebsd (gui)"                     "${EX[@]}" --target x86_64-unknown-freebsd                --features "$FEATURES_BSD_GUI"
run "x86_64-unknown-netbsd (headless)"                 "${EX[@]}" --target x86_64-unknown-netbsd                 --features "$FEATURES_HEADLESS"
run "x86_64-unknown-netbsd (gui)"                      "${EX[@]}" --target x86_64-unknown-netbsd                 --features "$FEATURES_GUI_NO_WEBVIEW"

# ── BSD (nightly + -Z build-std) ─────────────────────────────────────────────
run "aarch64-unknown-freebsd (bsd nightly)"            "${EX_N[@]}" --target aarch64-unknown-freebsd             --features "$FEATURES_BSD_NIGHTLY"
run "aarch64-unknown-netbsd (bsd nightly)"             "${EX_N[@]}" --target aarch64-unknown-netbsd              --features "$FEATURES_BSD_NIGHTLY"
run "i686-unknown-netbsd (bsd nightly)"                "${EX_N[@]}" --target i686-unknown-netbsd                 --features "$FEATURES_BSD_NIGHTLY"
run "powerpc-unknown-netbsd (bsd nightly no-atomic64)" "${EX_N[@]}" --target powerpc-unknown-netbsd              --features "$FEATURES_HEADLESS_NO_ATOMIC64"
run "x86_64-unknown-openbsd (bsd nightly)"             "${EX_N[@]}" --target x86_64-unknown-openbsd              --features "$FEATURES_BSD_NIGHTLY"
run "aarch64-unknown-openbsd (bsd nightly)"            "${EX_N[@]}" --target aarch64-unknown-openbsd             --features "$FEATURES_BSD_NIGHTLY"
run "i686-unknown-openbsd (bsd nightly)"               "${EX_N[@]}" --target i686-unknown-openbsd                --features "$FEATURES_BSD_NIGHTLY"
run "riscv64gc-unknown-openbsd (bsd nightly)"          "${EX_N[@]}" --target riscv64gc-unknown-openbsd           --features "$FEATURES_BSD_NIGHTLY"

# ── Windows MSVC (via cargo-xwin) ────────────────────────────────────────────
EX_XWIN=(cargo xwin build --example comprehensive_usage --no-default-features)

run "x86_64-pc-windows-msvc (full)"                    "${EX_XWIN[@]}" --target x86_64-pc-windows-msvc           --features "$FEATURES_FULL"
run "aarch64-pc-windows-msvc (full)"                   "${EX_XWIN[@]}" --target aarch64-pc-windows-msvc          --features "$FEATURES_FULL"
run "i686-pc-windows-msvc (full)"                      "${EX_XWIN[@]}" --target i686-pc-windows-msvc             --features "$FEATURES_FULL"

# ── WASM ──────────────────────────────────────────────────────────────────────
run "wasm32-unknown-unknown (wasm)"                    "${EX[@]}"   --target wasm32-unknown-unknown              --features "$FEATURES_WASM"
run "wasm32-wasip1 (wasi)"                             "${EX[@]}"   --target wasm32-wasip1                       --features "$FEATURES_WASM_WASI"
run "wasm32-wasip2 (wasi)"                             "${EX[@]}"   --target wasm32-wasip2                       --features "$FEATURES_WASM_WASI"

# ── macOS / iOS (native macOS host only — skipped inside Docker) ──────────────
if [[ "$(uname)" == "Darwin" ]]; then
    run "aarch64-apple-darwin (full)"                  "${EX[@]}" --target aarch64-apple-darwin                  --features "$FEATURES_FULL"
    run "x86_64-apple-darwin (full)"                   "${EX[@]}" --target x86_64-apple-darwin                   --features "$FEATURES_FULL"
    run "aarch64-apple-ios (mobile)"                   "${EX[@]}" --target aarch64-apple-ios                     --features "$FEATURES_MOBILE"
    run "aarch64-apple-ios-sim (mobile)"               "${EX[@]}" --target aarch64-apple-ios-sim                 --features "$FEATURES_MOBILE"
    run "x86_64-apple-ios-sim (mobile)"                "${EX[@]}" --target x86_64-apple-ios-sim                  --features "$FEATURES_MOBILE"
    # Mac Catalyst: iOS app on macOS — full macOS API surface including background TCP + menus.
    run "aarch64-apple-ios-macabi (full)"              "${EX[@]}" --target aarch64-apple-ios-macabi              --features "$FEATURES_FULL"
    run "x86_64-apple-ios-macabi (full)"               "${EX[@]}" --target x86_64-apple-ios-macabi               --features "$FEATURES_FULL"
    # Universal macOS fat binary — lipo the two already-built darwin outputs above.
    run "universal-apple-darwin (full)" bash -c "
        mkdir -p target/universal-apple-darwin/debug/examples && \
        lipo -create \
            target/aarch64-apple-darwin/debug/examples/comprehensive_usage \
            target/x86_64-apple-darwin/debug/examples/comprehensive_usage \
            -output target/universal-apple-darwin/debug/examples/comprehensive_usage"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
total=$(( ${#PASS[@]} + ${#FAIL[@]} ))
echo ""
echo "════════════════════════════════════════════════════════════"
printf " Results: %d / %d targets passed\n" "${#PASS[@]}" "$total"
echo "════════════════════════════════════════════════════════════"
for t in "${PASS[@]}"; do printf '  \033[1;32m✓\033[0m  %s\n' "$t"; done
for t in "${FAIL[@]}"; do printf '  \033[1;31m✗\033[0m  %s\n' "$t"; done
echo "════════════════════════════════════════════════════════════"

[ "${#FAIL[@]}" -eq 0 ]