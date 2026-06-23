# docker-ex

[![Docker](https://img.shields.io/badge/docker-ghcr.io%2Fspur27%2Fdocker--ex-blue?logo=docker&logoColor=white)](https://github.com/spur27/docker-ex/pkgs/container/docker-ex)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.md)

A personal Rust utility suite — 60 feature-gated modules covering error handling,
networking, databases, authentication, cryptography, serialisation, GUI, game engines,
audio, terminal UI, machine learning, and cross-platform system utilities.

The docker container targets as many platforms as possible with std support: Linux (GNU and musl, 14+ arches), Android (4 ABIs), FreeBSD, NetBSD, OpenBSD, Windows (MSVC only — not MinGW), macOS, iOS, and WASM.

## Table of contents

- [Feature flags](#feature-flags)
- [Adding as a dependency](#adding-as-a-dependency)
- [Quick start](#quick-start)
- [Cross-compilation (Docker)](#cross-compilation-docker)
  - [Available targets](#available-targets)
- [Cross-compilation targets](#cross-compilation-targets)
  - [Android](#android)
  - [BSD — FreeBSD](#bsd--freebsd)
  - [BSD — NetBSD](#bsd--netbsd)
  - [BSD — OpenBSD](#bsd--openbsd)
  - [iOS](#ios)
  - [Mac Catalyst](#mac-catalyst)
  - [Linux — GNU](#linux--gnu)
  - [Linux — musl](#linux--musl-static-linking)
  - [macOS](#macos)
  - [WASM](#wasm)
  - [Windows](#windows)
- [Docker image](#docker-cross-compilation-image)
  - [What the image includes](#what-the-image-includes)
  - [Feature sets](#feature-set-variables-justfile)
- [License](#license)

---

## Feature flags

Every module is opt-in. Enable only what a given project needs.

| Feature | What it provides | Key crate(s) |
|---------|-----------------|--------------|
| `auth` | Argon2id password hashing, JWT encode/decode | `argon2`, `jsonwebtoken` |
| `binary` | Compact binary serialisation (save files, IPC payloads) | `bincode`, `serde` |
| `bson` | BSON encode/decode for document-oriented data | `bson` |
| `cache` | In-process cache with TTL and capacity eviction | `moka` |
| `cassandra` | Async Cassandra/ScyllaDB client | `scylla` |
| `cli` | Argument parsing with derive macros | `clap` |
| `compress` | Gzip and Zstandard compression | `flate2`, `zstd` |
| `config` | File + environment config loading | `config` (config-rs) |
| `crypto` | AES-256-GCM encryption, SHA-2, CSPRNG | `aes-gcm`, `sha2`, `rand` |
| `csv` | Fast CSV reading and writing with serde integration | `csv` |
| `datetime` | Dates, times, durations, RFC 3339 parsing | `chrono` |
| `db` | Async SQLite via connection pool | `sqlx` |
| `derive_more` | Common derives: `From`, `Into`, `Display`, `Error`, `Add`, etc. | `derive_more` |
| `dialog` | Native OS file-picker and message dialogs | `rfd` |
| `docker` | Async Docker Engine API client | `bollard` |
| `dynlib` | Runtime shared-library loading (`dlopen` / `LoadLibrary`) | `libloading` |
| `engine_2d` | 2D game engine with pre-configured app builder | `bevy` |
| `engine_3d` | 3D game engine with pre-configured app builder | `bevy` |
| `env` | `.env` file loading, env var helpers | `dotenvy` |
| `error` | `Result`, `Error`, `bail!`, `ensure!`, typed error derives | `anyhow`, `thiserror` |
| `fs` | Atomic file writes, temp files, path helpers | `tempfile` |
| `gui` | Immediate-mode GUI | `egui`, `eframe` |
| `http_client` | Async HTTP client with JSON and rustls TLS | `reqwest` |
| `image` | Image decoding/encoding (PNG, JPEG, WebP, BMP, GIF, TIFF, ICO) | `image` |
| `imgui` | Dear ImGui immediate-mode GUI via Rust bindings + winit integration | `imgui`, `imgui-winit-support` |
| `ipc` | Unix domain sockets / Windows named pipes | `interprocess` |
| `itertools` | Extended iterator adapters and combinators | `itertools` |
| `json` | Lightweight JSON encode/decode (without full `serial` bundle) | `serde`, `serde_json` |
| `k8s` | Kubernetes typed client with runtime watch support | `kube`, `k8s-openapi` |
| `logger` *(default)* | `env_logger` backend; `init()` / `init_with_level()`; re-exports full `log` facade | `log`, `env_logger` |
| `math` | Linear algebra — vectors, matrices, transforms, quaternions | `nalgebra` |
| `menu` | Native OS context menus and menu bars (Win32 / NSMenu / GTK) | `muda` |
| `metrics` | Prometheus-compatible counters/gauges/histograms | `metrics`, `metrics-exporter-prometheus` |
| `ml` | Classical machine learning (k-means, SVM, linear regression) | `linfa` |
| `mongodb` | Async MongoDB client | `mongodb`, `bson` |
| `ndarray` | N-dimensional arrays for numerical computing | `ndarray` |
| `net` | TCP/UDP helpers | `tokio` |
| `noise` | Procedural noise generation (Perlin, Simplex, Worley) | `noise` |
| `nom` | Byte and string parser combinator framework | `nom` |
| `open` | Open files and URLs with the OS default handler (`xdg-open`, `open`, `start`) | `open` |
| `parallel` | Parallel iterators and thread pools | `rayon` |
| `process` | Subprocess spawning and management | std only |
| `regex` | Regular expression compilation and matching | `regex` |
| `serial` | JSON and TOML serialisation helpers | `serde`, `serde_json`, `toml` |
| `sound` | Cross-platform audio playback (ALSA / CoreAudio / WASAPI) | `rodio` |
| `strum` | Enum ↔ string conversions and iteration via derive macros | `strum` |
| `system` | CPU, memory, disk, and process information | `sysinfo` |
| `task` | Async background task utilities | `tokio` |
| `tracing` | Structured async-aware diagnostics with OpenTelemetry OTLP export | `tracing`, `tracing-subscriber`, `opentelemetry-otlp` |
| `tray` | System tray icon with optional tray menu | `tray-icon`, `muda` |
| `tui` | Terminal UI — widgets, layout, and crossterm backend | `ratatui`, `crossterm` |
| `uuid` | UUID v4 generation and parsing | `uuid` |
| `watch` | Filesystem change notifications | `notify` |
| `web_server` | Async HTTP server with routing and middleware | `axum`, `tokio` |
| `webview` | Embedded OS browser engine | `wry` |
| `window` | Cross-platform windowing and event loop (winit 0.30 trait-based) | `winit` |
| `window_tao` | Closure-based event loop (Tauri/muda fork of winit) | `tao` |
| `xml` | XML serialise/deserialise via serde | `quick-xml`, `serde` |
| `yaml` | YAML serialise/deserialise via serde | `serde_yml`, `serde` |
| `zip` | Read and write ZIP archives | `zip` |

The `full` feature enables everything.

---

## Adding as a dependency

This crate is not published to crates.io. Add it as a git dependency:

```toml
[dependencies]
docker-ex = { git = "https://github.com/spur27/docker-ex", features = ["error", "serial", "http_client"] }
```

Or as a path dependency when working in a local workspace:

```toml
[dependencies]
docker-ex = { path = "../docker-ex", features = ["error", "serial", "db"] }
```

---

## Quick start

```rust
use docker_ex::prelude::*;   // Result, bail!, Serialize/Deserialize, DateTime, Uuid, par_iter
use docker_ex::{logger, auth, http_client};

#[tokio::main]
async fn main() -> Result<()> {
    logger::init();

    let hash = auth::hash_password("hunter2")?;
    log::info!("password hash: {hash}");

    let body = http_client::get("https://httpbin.org/get").await?;
    log::info!("response: {body}");

    Ok(())
}
```

---

## Cross-compilation (Docker)

The `docker-ex` image bundles every required toolchain, sysroot, and SDK — no local installation needed.

Install [just](https://github.com/casey/just) (`cargo install just`), then:

```sh
just docker-pull       # pull the pre-built image from GHCR
just docker-cross-all  # tries to build for all targets 
just docker-run cargo build --target aarch64-unknown-linux-gnu \
    --no-default-features --features "logger,net,crypto,..."
```

Feature flag combinations per target group are documented in [`examples/comprehensive_usage.rs`](examples/comprehensive_usage.rs).

### Available targets
**NOTE**: macOS, iOS, and Mac Catalyst targets require a native macOS host with Xcode and are not available in the Docker image.

**Linux GNU**
```
x86_64-unknown-linux-gnu
aarch64-unknown-linux-gnu
armv7-unknown-linux-gnueabihf
arm-unknown-linux-gnueabihf
thumbv7neon-unknown-linux-gnueabihf 
i686-unknown-linux-gnu
loongarch64-unknown-linux-gnu
powerpc64-unknown-linux-gnu
powerpc64le-unknown-linux-gnu
powerpc-unknown-linux-gnu
riscv64gc-unknown-linux-gnu
s390x-unknown-linux-gnu
sparc64-unknown-linux-gnu
```

**Linux musl**
```
x86_64-unknown-linux-musl
aarch64-unknown-linux-musl
```

**Android**
```
aarch64-linux-android
armv7-linux-androideabi
i686-linux-android
x86_64-linux-android
```

**BSD** (stable)
```
x86_64-unknown-freebsd
x86_64-unknown-netbsd
```

**BSD** (requires `cargo +nightly -Z build-std`)
```
aarch64-unknown-freebsd
aarch64-unknown-netbsd
i686-unknown-netbsd
powerpc-unknown-netbsd
x86_64-unknown-openbsd
aarch64-unknown-openbsd
i686-unknown-openbsd
riscv64gc-unknown-openbsd
```

**Windows** (via `cargo-xwin`)
```
x86_64-pc-windows-msvc
aarch64-pc-windows-msvc
i686-pc-windows-msvc
```

**macOS** (native only)
```
aarch64-apple-darwin
x86_64-apple-darwin
universal-apple-darwin
```

**iOS** (native only)
```
aarch64-apple-ios
aarch64-apple-ios-sim
x86_64-apple-ios-sim
```

**Mac Catalyst** (native only)
```
aarch64-apple-ios-macabi
x86_64-apple-ios-macabi
```

**WASM**
```
wasm32-unknown-unknown
wasm32-wasip1
wasm32-wasip2
```


---

## Cross-compilation targets

> **Legend:** ✅ Fully supported · ⚠️ Supported with caveats · ❌ Not supported  
> **Headless** — all non-GUI features: auth, crypto, net, db, serial, task, parallel, …  
> **GUI** — window, egui, Bevy, ImGui, dialog, menu  
> **WebView** — embedded browser (webkit2gtk / WebView2 / WKWebView)  
> **Tray** — system tray icon  
> ⚠️ on a tier-3 or nightly-only target means `cargo +nightly -Z build-std` is required.  
> ⚠️ on a feature column means the feature works but with platform-specific caveats (see notes).

### Android

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-linux-android` | 2 | ✅ | ⚠️ | ✅ | ❌ | NDK r27d · API 21+ · no imgui/menu · dialog returns None/Cancel (no NDK picker API) · binary needs `android_main!` |
| `armv7-linux-androideabi` | 2 | ✅ | ⚠️ | ✅ | ❌ | NDK r27d · API 21+ · see above |
| `i686-linux-android` | 2 | ✅ | ⚠️ | ✅ | ❌ | NDK r27d · API 21+ · see above |
| `x86_64-linux-android` | 2 | ✅ | ⚠️ | ✅ | ❌ | NDK r27d · API 21+ · see above |

Bevy on Android requires the `patches/android-activity` patch (removes the `compile_error!`
that fires when `eframe` and `bevy_winit` are both in the graph). `imgui` is excluded
(`winit::platform::modifier_supplement` is absent on Android). `menu`/`tray`
require GTK which is not in the NDK. `dialog` compiles via a no-op stub patch — all
dialogs return None/Cancel immediately (no NDK file-picker API available). wry uses
`android.webkit.WebView` (Java/JNI).

### BSD — FreeBSD

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-unknown-freebsd` | 3 | ⚠️ | ⚠️ | ⚠️ | ❌ | nightly · `-Z build-std` · clang/LLD · WebKitGTK 2.46.6 (API 4.1) binary packages |
| `x86_64-unknown-freebsd` | 2 | ✅ | ✅ | ✅ | ❌ | clang/LLD · WebKitGTK 2.46.6 (API 4.1) binary packages |

### BSD — NetBSD

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-unknown-netbsd` | 3 | ⚠️ | ⚠️ | ❌ | ❌ | nightly · `-Z build-std` · clang/LLD · WebKitGTK 2.36.8 (API 4.0 only) · `-stdlib=libstdc++` |
| `i686-unknown-netbsd` | 3 | ⚠️ | ⚠️ | ❌ | ❌ | nightly · `-Z build-std` · clang/LLD · WebKitGTK 2.36.8 (API 4.0 only) · `-stdlib=libstdc++` |
| `powerpc-unknown-netbsd` | 3 | ⚠️ | ⚠️ | ❌ | ❌ | nightly · `-Z build-std` · clang/LLD · macppc (Apple PowerPC) · WebKitGTK 2.36.8 (API 4.0) · `-stdlib=libstdc++` |
| `x86_64-unknown-netbsd` | 2 | ✅ | ✅ | ❌ | ❌ | clang/LLD · WebKitGTK 2.36.8 (API 4.0 only) · `-stdlib=libstdc++` |

NetBSD linker wrappers pass `-stdlib=libstdc++`: NetBSD 10.x defaults to `libc++` but
the base sysroot only ships `libstdc++.so`.
WebView is unavailable on all NetBSD targets — pkgsrc ships only WebKitGTK 2.36.8 (API 4.0)
and `wry` requires API 4.1. GUI (window/egui/Bevy/ImGui/dialog/menu) works fully.

### BSD — OpenBSD

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-unknown-openbsd` | 3 | ⚠️ | ⚠️ | ⚠️ | ❌ | nightly · `-Z build-std` · OpenBSD 7.7 · WebKitGTK 2.48.1 (API 4.1) binary packages |
| `i686-unknown-openbsd` | 3 | ⚠️ | ⚠️ | ⚠️ | ❌ | nightly · `-Z build-std` · OpenBSD 7.7 · WebKitGTK 2.48.1 (API 4.1) binary packages |
| `riscv64gc-unknown-openbsd` | 3 | ⚠️ | ⚠️ | ⚠️ | ❌ | nightly · `-Z build-std` · OpenBSD 7.7 · WebKitGTK 2.48.1 (API 4.1) binary packages |
| `x86_64-unknown-openbsd` | 3 | ⚠️ | ⚠️ | ⚠️ | ❌ | nightly · `-Z build-std` · OpenBSD 7.7 · WebKitGTK 2.48.1 (API 4.1) binary packages |

Tray is unavailable on all BSD targets — no `libayatana-appindicator3` port exists.
BSD builds require four `[patch.crates-io]` patches: `cpal`, `gilrs-core`, `mio`, `inotify`.
All BSD library packages are fetched from official BSD binary package repos at build time.

### iOS

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-apple-ios` | 2 | ✅ | ✅ | ⚠️ | ❌ | macOS host + Xcode · WKWebView |
| `aarch64-apple-ios-sim` | 2 | ✅ | ✅ | ⚠️ | ❌ | macOS host + Xcode · iOS Simulator · Apple Silicon |
| `x86_64-apple-ios-sim` | 2 | ✅ | ✅ | ⚠️ | ❌ | macOS host + Xcode · iOS Simulator · Intel Mac |

### Mac Catalyst

Mac Catalyst runs iOS apps on macOS with the full macOS API surface. Both targets use `FEATURES_FULL` — unlike standard iOS targets, there is no `tray` restriction, and `web_server` / background TCP is fully available.

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-apple-ios-macabi` | 2 | ✅ | ✅ | ✅ | ✅ | macOS host + Xcode · Apple Silicon Mac |
| `x86_64-apple-ios-macabi` | 2 | ✅ | ✅ | ✅ | ✅ | macOS host + Xcode · Intel Mac |

### Linux — GNU

Most targets receive a bundled sysroot with **WebKitGTK 2.50.1** (GTK3, Wayland, XKB,
ALSA, EGL/GLES, eudev, tray stack) plus **Mesa 24.2.8** softpipe (EGL/GLES2/GBM, no
LLVM), **PipeWire 1.2.7**, and audio codec libraries (FLAC 1.4.3, libsndfile 1.2.2,
libsamplerate 0.2.2, libvpx 1.14.1, libdav1d 1.4.3, libopus 1.5.2, libogg 1.3.5) when
`just bundle-sysroots` is run before `just docker-build`. Without a bundle, only headless
features are available for that target.
**Lavapipe** (Mesa software Vulkan ICD) is additionally installed in 9 of the 14
cross-sysroots where pre-built binary packages are available — aarch64, armhf, loongarch64,
ppc64le, riscv64, s390x, i386, mipsel, mips64el — run `just install-lavapipe` before
`just bundle-sysroots`.

`arm-unknown-linux-gnueabihf` shares the `arm-linux-gnueabihf` sysroot (built for ARMv7);
the GUI/WebView/Tray stack compiles successfully but the resulting binaries target ARMv7
and will not run on true ARMv6 hardware (Raspberry Pi Zero / Pi 1).
`loongarch64-unknown-linux-gnu` and `powerpc64le-unknown-linux-gnu` sysroots are
bootstrapped from Debian sid (Ubuntu ports lacks these or only ships older WebKit);
both have **WebKitGTK 2.52.4**, Mesa 26.1.2, LLVM 21, and lavapipe — the full feature
stack matches all other GNU targets. Sysroot bundles not yet included in the Docker image
— run `just bundle-sysroots` and rebuild.
`i686-unknown-linux-gnu` has a complete sysroot with GTK3, tray stack, and WebKitGTK 2.50.4
(Ubuntu i386 package — newer than the 2.50.1 source build used for other targets).

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-unknown-linux-gnu` | 1 | ✅ | ✅ | ✅ | ✅ | aarch64-linux-gnu-gcc · WebKitGTK 2.50.1 sysroot |
| `arm-unknown-linux-gnueabihf` | 2 | ✅ | ⚠️ | ⚠️ | ⚠️ | arm-linux-gnueabihf-gcc · ARMv6 · Raspberry Pi Zero/1 · ARMv7 sysroot (compiles, ARMv7 runtime only) |
| `armv7-unknown-linux-gnueabihf` | 2 | ✅ | ✅ | ✅ | ✅ | arm-linux-gnueabihf-gcc · WebKitGTK 2.50.1 sysroot |
| `i686-unknown-linux-gnu` | 1 | ✅ | ✅ | ✅ | ✅ | i686-linux-gnu-gcc · WebKitGTK 2.50.4 sysroot (Ubuntu i386 package) |
| `loongarch64-unknown-linux-gnu` | 2 | ✅ | ✅ | ✅ | ✅ | loongarch64-linux-gnu-gcc · Loongson · Debian sid sysroot · WebKitGTK 2.52.4 |
| `mips-unknown-linux-gnu` | 3 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | mips-linux-gnu-gcc · nightly · `-Z build-std` · big-endian |
| `mips64-unknown-linux-gnuabi64` | 3 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | mips64-linux-gnuabi64-gcc · nightly · `-Z build-std` |
| `mips64el-unknown-linux-gnuabi64` | 3 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | mips64el-linux-gnuabi64-gcc · nightly · `-Z build-std` |
| `mipsel-unknown-linux-gnu` | 3 | ⚠️ | ⚠️ | ⚠️ | ⚠️ | mipsel-linux-gnu-gcc · nightly · `-Z build-std` |
| `powerpc-unknown-linux-gnu` | 2 | ⚠️ | ✅ | ✅ | ✅ | powerpc-linux-gnu-gcc · WebKitGTK 2.50.1 sysroot · no `tracing` (32-bit: `opentelemetry_sdk` requires 64-bit atomics) |
| `powerpc64-unknown-linux-gnu` | 2 | ✅ | ✅ | ✅ | ✅ | powerpc64-linux-gnu-gcc · WebKitGTK 2.50.1 sysroot · big-endian |
| `powerpc64le-unknown-linux-gnu` | 1 | ✅ | ✅ | ✅ | ✅ | powerpc64le-linux-gnu-gcc · WebKitGTK 2.52.4 · Debian sid sysroot · IBM POWER8+ little-endian |
| `riscv64gc-unknown-linux-gnu` | 2 | ✅ | ✅ | ✅ | ✅ | riscv64-linux-gnu-gcc · WebKitGTK 2.50.1 sysroot |
| `s390x-unknown-linux-gnu` | 2 | ✅ | ✅ | ✅ | ✅ | s390x-linux-gnu-gcc · WebKitGTK 2.50.1 sysroot · IBM Z |
| `sparc64-unknown-linux-gnu` | 2 | ✅ | ✅ | ✅ | ✅ | sparc64-linux-gnu-gcc · WebKitGTK 2.50.1 sysroot |
| `thumbv7neon-unknown-linux-gnueabihf` | 2 | ✅ | ✅ | ✅ | ✅ | arm-linux-gnueabihf-gcc · ARMv7+NEON · shares armv7 sysroot · WebKitGTK 2.50.1 |
| `x86_64-unknown-linux-gnu` | 1 | ✅ | ✅ | ✅ | ✅ | native in Docker · apt-installed WebKitGTK 4.1 |

### Linux — musl (static linking)

musl targets link the C standard library statically, producing self-contained binaries
suitable for Alpine Linux, minimal containers, and embedded deployments.
GTK/WebKitGTK are dynamically-loaded system libraries and are unavailable with musl.
ALSA (`sound`) is also unavailable — `libasound` is a glibc-only dynamic library with no
musl-compatible static build, so the `sound` feature must be excluded on musl targets.

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-unknown-linux-musl` | 2 | ⚠️ | ❌ | ❌ | ❌ | aarch64-linux-musl-gcc (musl.cc) · static · no GTK · no `sound` |
| `x86_64-unknown-linux-musl` | 2 | ⚠️ | ❌ | ❌ | ❌ | musl-gcc (musl-tools) · static · no GTK · no `sound` |

### macOS

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-apple-darwin` | 1 | ✅ | ✅ | ✅ | ✅ | macOS host + Xcode · Apple Silicon |
| `x86_64-apple-darwin` | 1 | ✅ | ✅ | ✅ | ✅ | macOS host + Xcode · Intel |
| `universal-apple-darwin` | — | ✅ | ✅ | ✅ | ✅ | fat binary via `lipo` from aarch64 + x86_64 darwin builds · not a direct cargo target |

### WASM

WASM targets use a restricted subset — no tokio (no threading in WASI preview1), no rayon, no dynlib, no audio, no GUI.

The Docker image includes **WASI SDK 33** which provides `wasm32-wasip1-clang` / `wasm32-wasip2-clang` and the WASI sysroot (wasi-libc headers). This enables C-dependent crates such as `zstd-sys` (`compress`) to compile for WASI targets.

`FEATURES_WASM` / `FEATURES_WASM_WASI` = `logger,cli,serial,json,bson,xml,yaml,binary,auth,crypto,compress,regex,error,datetime,uuid,env,noise,image,zip,csv,nom,math,itertools,strum,derive_more,ndarray,ml`

Both sets are identical; for WASI targets `compress` uses `zstd-sys` via the WASI SDK clang, while `wasm32-unknown-unknown` uses the pure-Rust compression path. `tui` is omitted from both — crossterm 0.28.1 does not implement `sys::position` or `sys::supports_keyboard_enhancement` for any `wasm32` target.

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `wasm32-unknown-unknown` | 2 | ⚠️ | ❌ | ❌ | ❌ | `FEATURES_WASM` · browser / embedded |
| `wasm32-wasip1` | 2 | ⚠️ | ❌ | ❌ | ❌ | `FEATURES_WASM_WASI` · `wasmtime run --` runner in Docker |
| `wasm32-wasip2` | 2 | ⚠️ | ❌ | ❌ | ❌ | `FEATURES_WASM_WASI` · WASI Component Model · `wasmtime run --` runner in Docker |

### Windows

MinGW is intentionally excluded — MSVC ABI only. `cargo-xwin` downloads MSVC CRT and
Windows SDK from Microsoft NuGet on first use; no Windows license required.
wry on Windows uses **WebView2** (Edge Chromium embedded engine).

| Target | Tier | Headless | GUI | WebView | Tray | Notes |
|--------|------|:--------:|:---:|:-------:|:----:|-------|
| `aarch64-pc-windows-msvc` | 2 | ✅ | ✅ | ✅ | ✅ | cargo-xwin · WebView2 · Surface Pro X, Snapdragon |
| `i686-pc-windows-msvc` | 2 | ✅ | ✅ | ✅ | ✅ | cargo-xwin · WebView2 · 32-bit Windows |
| `x86_64-pc-windows-msvc` | 1 | ✅ | ✅ | ✅ | ✅ | cargo-xwin · WebView2 |

---

## Docker cross-compilation image

The image at `docker/Dockerfile` provides a single reproducible environment for
building all targets that don't require a native macOS host.

### What the image includes

- Ubuntu 24.04 base
- GCC and G++ cross-compilers for all Linux GNU targets including PowerPC64LE (Tier 1), LoongArch64, and MIPS (Tier 3) — G++ required by `imgui-sys` and other crates that compile C++ via `cc-rs`
- `musl-tools` for `x86_64-unknown-linux-musl` + `aarch64-linux-musl-gcc` (musl.cc toolchain) for `aarch64-unknown-linux-musl` static builds
- Clang/LLD for BSD cross-compilation
- Android NDK r27d
- All 10 BSD sysroots (FreeBSD 14.3, NetBSD 10.1, OpenBSD 7.7 — x64, aarch64, i386/powerpc where available)
  with clang/LLD linker and CC wrappers for all 10; any target without a bundle
  auto-downloads a headless base at image-build time
  — library packages installed from official BSD binary repos:
  FreeBSD (177 packages): **WebKitGTK 2.46.6** (API 4.1), Vulkan loader, lavapipe, PipeWire, libopus, libogg, libvpx, speex, libtheora, libass, wavpack;
  NetBSD (94 packages): **WebKitGTK 2.36.8** (API 4.0 — no 4.1 in pkgsrc), vulkan-headers, libopus, libogg, FLAC, libsndfile, libsamplerate, dav1d, libvpx, libvorbis, speex, libtheora, libaom, libass, wavpack, libepoxy, avahi, mpg123;
  OpenBSD (120 packages): **WebKitGTK 2.48.1** (API 4.1), Vulkan loader, PipeWire, libopus, libogg, libsamplerate
- Linux GNU sysroots: **WebKitGTK 2.50.1** for 11 targets; i686 has WebKitGTK 2.50.4 (Ubuntu i386); loongarch64 and ppc64le have WebKitGTK 2.52.4 + Mesa 26.1.2 + LLVM 21 (Debian sid) — bundles pending `just bundle-sysroots`; x86_64 is native (apt packages); all 14 cross-targets include Mesa softpipe, PipeWire 1.2.7, OpenXR, Vulkan loader, and audio codec libraries (FLAC, libsndfile, libsamplerate, libvpx, libdav1d, libopus, libogg); lavapipe (Mesa software Vulkan ICD) on 9 of 14 cross-arches (aarch64, armhf, loongarch64, ppc64le, riscv64, s390x, i386, mipsel, mips64el)
- `cargo-xwin` for Windows MSVC cross-compilation — x64, x86, and ARM64 targets pre-installed
- Native WebKitGTK 4.1 for `x86_64-unknown-linux-gnu` builds inside Docker
- **WASI SDK 33** at `/opt/wasi-sdk` — `wasm32-wasip1-clang` / `wasm32-wasip2-clang` compilers + WASI sysroot; enables C-dependent crates (`zstd-sys`, etc.) to compile for WASI
- `wasmtime` for running WASI programs and `cargo test --target wasm32-wasip1/wasip2`
- `wasm-pack` for building and bundling WASM + JS bindings
- `wasm-opt` (binaryen) for WASM size and performance optimisation
- `just` task runner
- Rust stable + nightly with all configured cross-targets

### Feature set variables (docker/build-all.sh)

These are the pre-defined feature combinations used by `docker/build-all.sh` and the `just ci-*` recipes:

| Variable | Used for | Key omissions |
|----------|----------|---------------|
| `FEATURES_FULL` | Native x64, Windows MSVC, macOS | — |
| `FEATURES_FULL_NO_ATOMIC64` | `powerpc-unknown-linux-gnu` (full) | no `tracing`, `engine_2d`, `engine_3d`, `cassandra` (32-bit atomics) |
| `FEATURES_HEADLESS` | Linux GNU cross-targets, BSD stable | no GUI stack |
| `FEATURES_HEADLESS_NO_ATOMIC64` | `powerpc-unknown-linux-gnu`, `powerpc-unknown-netbsd` | no GUI, no `tracing` (32-bit atomics) |
| `FEATURES_MUSL` | `x86_64/aarch64-unknown-linux-musl` | no GUI, no `sound` (ALSA unavailable for musl) |
| `FEATURES_BSD_GUI` | `x86_64-unknown-freebsd` GUI CI | Headless + winit, egui, Bevy, ImGui, webview, dialog, menu |
| `FEATURES_GUI_NO_WEBVIEW` | `x86_64-unknown-netbsd` GUI CI | Same as `FEATURES_BSD_GUI` but without `webview` — NetBSD pkgsrc ships WebKitGTK 4.0 only; `wry` requires API 4.1 |
| `FEATURES_BSD_NIGHTLY` | BSD nightly (`-Z build-std`) Tier 3 | no GUI, no `tracing` (tower-0.4/indexmap-1.9 autocfg fails under build-std) |
| `FEATURES_MOBILE` | All 4 Android ABIs + iOS targets | no `imgui`, `menu`, `tray` (no platform backend on Android/iOS) |
| `FEATURES_WASM` | `wasm32-unknown-unknown` | Same features as `FEATURES_WASM_WASI`; `compress` uses pure-Rust path (no C deps) |
| `FEATURES_WASM_WASI` | `wasm32-wasip1`, `wasm32-wasip2` | no `tui` (crossterm unimplemented for wasm32); WASI SDK enables `zstd-sys` C compilation |

---

## License

MIT — see [LICENSE.md](LICENSE.md).
