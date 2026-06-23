# Docker-EX cross-compilation image
#
# Covers:
#   Linux GNU   — x64, aarch64, armv7, arm-v6, thumbv7neon, i686, loongarch64,
#                 ppc64le (LE), ppc64 (BE), ppc, riscv64, s390x, sparc64, MIPS (4 variants, Tier 3)
#   Linux musl  — x86_64 (musl-tools), aarch64 (musl.cc cross-toolchain)
#   Android     — arm64, armv7, x86, x86_64 (API 21+)
#   FreeBSD 14.3 — x64 (Tier 2), aarch64 (Tier 3, nightly)
#   NetBSD  10.1 — x64 (Tier 2), aarch64/i386/powerpc (Tier 3, nightly)
#   OpenBSD 7.7  — x64/aarch64/i386/riscv64 (Tier 3, nightly)
#   WebAssembly — wasm32-unknown-unknown, wasm32-wasip1/wasip2 (WASI SDK + wasmtime runner)
#   Windows MSVC x64/arm64/x86 — via cargo-xwin (downloads MSVC headers from NuGet)
#
# All 10 BSD sysroots include library packages from official BSD binary repos
# (WebKitGTK, Vulkan loader, lavapipe, PipeWire, audio libs — see README for inventory).
#
# GUI / rendering support per target:
#
#   Linux GNU (14 cross-arches) — bundled sysroots; run before docker-build:
#       just install-lavapipe && just bundle-sysroots   # Linux
#       just bundle-sysroots-bsd                        # BSD
#     Each Linux sysroot contains:
#       WebKitGTK 2.50.1 (2.50.4 on i686, 2.52.4 on loongarch64 + ppc64le) · API 4.1
#       Vulkan loader 1.3.296 + GTK3 + GStreamer + ALSA + Wayland
#
#   x86_64-unknown-linux-gnu — native; libwebkit2gtk-4.1-dev + libvulkan-dev via apt
#
#   Android  — wry uses android.webkit.WebView (Java/JNI)
#   Windows  — wry uses WebView2 via cargo-xwin + Windows SDK
#   WASM     — wgpu uses WebGPU API; no Vulkan loader needed
#
# Not covered (needs a native host): macOS, iOS

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG RUST_TOOLCHAIN=stable
ARG NDK_VERSION=r27d
ARG NDK_API=21

# ── Enable multi-architecture support ─────────────────────────────────────────
RUN dpkg --add-architecture arm64 \
    && dpkg --add-architecture armhf \
    && dpkg --add-architecture s390x \
    && dpkg --add-architecture riscv64 \
    && dpkg --add-architecture i386

# archive.ubuntu.com only serves amd64; non-amd64 arches live on ports.ubuntu.com.
# Without this restriction, apt-get update 404s on the added architectures.
RUN if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then \
        if ! grep -q "^Architectures:" /etc/apt/sources.list.d/ubuntu.sources; then \
            sed -i 's/^Signed-By:/Architectures: amd64\nSigned-By:/g' \
                /etc/apt/sources.list.d/ubuntu.sources; \
        fi; \
    elif [ -f /etc/apt/sources.list ]; then \
        sed -i 's|^deb http|deb [arch=amd64] http|g' /etc/apt/sources.list; \
    fi

# Ubuntu Ports for all non-amd64 architectures (needed for cross-toolchain deps).
RUN printf 'Types: deb\nURIs: http://ports.ubuntu.com/ubuntu-ports\nSuites: noble noble-updates noble-backports\nComponents: main restricted universe multiverse\nArchitectures: arm64 armhf s390x riscv64\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\n' \
    > /etc/apt/sources.list.d/ubuntu-ports.sources

# ── System packages (native amd64) ────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git ca-certificates pkg-config \
    build-essential cmake ninja-build \
    unzip xz-utils \
    clang lld llvm \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu \
    gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf binutils-arm-linux-gnueabihf \
    gcc-i686-linux-gnu g++-i686-linux-gnu binutils-i686-linux-gnu \
    gcc-powerpc64-linux-gnu g++-powerpc64-linux-gnu binutils-powerpc64-linux-gnu \
    gcc-powerpc64le-linux-gnu g++-powerpc64le-linux-gnu binutils-powerpc64le-linux-gnu \
    gcc-powerpc-linux-gnu g++-powerpc-linux-gnu binutils-powerpc-linux-gnu \
    gcc-riscv64-linux-gnu g++-riscv64-linux-gnu binutils-riscv64-linux-gnu \
    gcc-s390x-linux-gnu g++-s390x-linux-gnu binutils-s390x-linux-gnu \
    gcc-sparc64-linux-gnu g++-sparc64-linux-gnu binutils-sparc64-linux-gnu \
    gcc-mips-linux-gnu binutils-mips-linux-gnu \
    gcc-mipsel-linux-gnu binutils-mipsel-linux-gnu \
    gcc-mips64-linux-gnuabi64 binutils-mips64-linux-gnuabi64 \
    gcc-mips64el-linux-gnuabi64 binutils-mips64el-linux-gnuabi64 \
    # LoongArch64: Ubuntu 24.04 only ships versioned packages; unversioned symlinks
    # are created below. libc6-loong64-cross is needed because gcc-14-loongarch64-linux-gnu
    # has --with-sysroot=/ and expects libc in the host multiarch path.
    gcc-14-loongarch64-linux-gnu g++-14-loongarch64-linux-gnu binutils-loongarch64-linux-gnu \
    libc6-loong64-cross libc6-dev-loong64-cross \
    musl-tools \
    libssl-dev \
    gperf m4 autoconf automake libtool xsltproc meson \
    # ── Native amd64 GUI libraries ───────────────────────────────────────────
    libgtk-3-dev \
    libwebkit2gtk-4.1-dev \
    libasound2-dev \
    libudev-dev \
    libvulkan-dev \
    libwayland-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev \
    libxdo-dev \
    libayatana-appindicator3-dev \
    binaryen \
    nasm \
    && rm -rf /var/lib/apt/lists/*

# ── i686 C library headers ────────────────────────────────────────────────────
# gcc-i686-linux-gnu uses --includedir=/usr/i686-linux-gnu/include but does not
# ship C library headers; libc6-dev-i386-cross populates that path without
# multiarch conflicts.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6-dev-i386-cross \
    && rm -rf /var/lib/apt/lists/*

# ── LLVM 20 ───────────────────────────────────────────────────────────────────
# clang-20 fixes LLVM 18 AArch64 ICEs (Post-RA pseudo instruction expansion pass)
# that crash at every optimisation level for aarch64-unknown-openbsd.
# clang-cl (from llvm-20) is needed by cargo-xwin for MSVC targets; the symlink
# at /usr/bin/clang-cl → /usr/lib/llvm-20/bin/clang-cl requires llvm-20 installed.
RUN apt-get update && apt-get install -y --no-install-recommends gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && wget -qO - https://apt.llvm.org/llvm-snapshot.gpg.key \
        | gpg --dearmor > /usr/share/keyrings/llvm-snapshot.gpg \
    && printf 'Types: deb\nURIs: https://apt.llvm.org/noble/\nSuites: llvm-toolchain-noble-20\nComponents: main\nSigned-By: /usr/share/keyrings/llvm-snapshot.gpg\n' \
        > /etc/apt/sources.list.d/llvm-20.sources \
    && apt-get update && apt-get install -y --no-install-recommends \
        clang-20 lld-20 \
    && rm -rf /var/lib/apt/lists/*

# ── loongarch64 GCC sysroot wrapper ───────────────────────────────────────────
# Ubuntu 24.04 only ships versioned binaries (gcc-14-loongarch64-linux-gnu); the
# unversioned name used by cargo-config.toml comes from these wrappers.
# --sysroot=/usr/loongarch64-linux-gnu is required: unlike every other cross-GCC
# (which has --with-sysroot=/usr/{triple}), this one was built with --with-sysroot=/,
# so its linker scripts resolve absolute paths on the host root rather than the sysroot.
RUN printf '#!/bin/sh\nexec /usr/bin/loongarch64-linux-gnu-gcc-14 --sysroot=/usr/loongarch64-linux-gnu "$@"\n' \
        > /usr/local/bin/loongarch64-linux-gnu-gcc \
    && printf '#!/bin/sh\nexec /usr/bin/loongarch64-linux-gnu-g++-14 --sysroot=/usr/loongarch64-linux-gnu "$@"\n' \
        > /usr/local/bin/loongarch64-linux-gnu-g++ \
    && chmod +x /usr/local/bin/loongarch64-linux-gnu-gcc \
                /usr/local/bin/loongarch64-linux-gnu-g++

# ── aarch64 musl cross-compiler ───────────────────────────────────────────────
# Pre-built musl.cc toolchain — provides aarch64-linux-musl-{gcc,g++,ar,ld,...}
# for aarch64-unknown-linux-musl static builds. No sysroot needed; musl libc is
# bundled inside the toolchain (unlike the glibc cross-compilers above).
RUN wget -qO- "https://musl.cc/aarch64-linux-musl-cross.tgz" \
    | tar -xz -C /opt

# ── Bundled sysroots ──────────────────────────────────────────────────────────
# Linux (14 targets): webkit2gtk 2.50.1–2.52.4 + GTK3 + GStreamer + ALSA + Wayland + Vulkan 1.3.296
# BSD   (10 targets): FreeBSD 14.3, NetBSD 10.1, OpenBSD 7.7
#
# Build bundles on host before docker-build:
#   just install-lavapipe && just bundle-sysroots   # Linux
#   just bundle-sysroots-bsd                        # BSD
#
# Archives: docker/sysroots/{triple}.tar.xz (gitignored). Missing archives are skipped.
# Linux layout: paths relative to /usr, extracted at -C /usr; symlinks at /opt/sysroots/{triple}.
# BSD layout: paths relative to sysroot root, extracted at -C /opt/sysroots/{triple}.
COPY docker/sysroots/ /tmp/sysroots/
RUN mkdir -p /opt/sysroots \
    && for f in /tmp/sysroots/aarch64-linux-gnu.tar.xz \
                /tmp/sysroots/arm-linux-gnueabihf.tar.xz \
                /tmp/sysroots/i686-linux-gnu.tar.xz \
                /tmp/sysroots/riscv64-linux-gnu.tar.xz \
                /tmp/sysroots/s390x-linux-gnu.tar.xz \
                /tmp/sysroots/powerpc64le-linux-gnu.tar.xz \
                /tmp/sysroots/powerpc64-linux-gnu.tar.xz \
                /tmp/sysroots/powerpc-linux-gnu.tar.xz \
                /tmp/sysroots/sparc64-linux-gnu.tar.xz \
                /tmp/sysroots/mips-linux-gnu.tar.xz \
                /tmp/sysroots/mipsel-linux-gnu.tar.xz \
                /tmp/sysroots/mips64-linux-gnuabi64.tar.xz \
                /tmp/sysroots/mips64el-linux-gnuabi64.tar.xz \
                /tmp/sysroots/loongarch64-linux-gnu.tar.xz; do \
        if [ -f "$f" ]; then \
            triple="$(basename $f .tar.xz)"; \
            echo "Installing Linux sysroot: ${triple}"; \
            tar --skip-old-files -xf "$f" -C /usr; \
            ln -s "/usr/${triple}" "/opt/sysroots/${triple}"; \
            rm "$f"; \
        fi; \
    done \
    && for bsd in x86_64-unknown-freebsd x86_64-unknown-netbsd \
                  x86_64-unknown-openbsd \
                  aarch64-unknown-freebsd aarch64-unknown-netbsd \
                  aarch64-unknown-openbsd \
                  i686-unknown-netbsd powerpc-unknown-netbsd \
                  i686-unknown-openbsd riscv64gc-unknown-openbsd; do \
        f="/tmp/sysroots/${bsd}.tar.xz"; \
        if [ -f "$f" ]; then \
            echo "Installing BSD sysroot: ${bsd}"; \
            mkdir -p "/opt/sysroots/${bsd}"; \
            tar -xf "$f" -C "/opt/sysroots/${bsd}/"; \
            rm "$f"; \
        fi; \
    done \
    && rm -rf /tmp/sysroots

# ── x86_64-unknown-netbsd: X11/XCB pkg-config stubs ──────────────────────────
# cairo.pc (pkgsrc) lists x11, xext, xrender, xcb, xcb-render, xcb-shm in
# Requires.private. pkg-config validates their existence even for dynamic linking.
# The sysroot has no base-X11 tree and pkgsrc did not include X11/xcb dev packages.
# Stubs with valid version numbers satisfy the validator; empty Libs/Cflags are
# never emitted (Requires.private is only included with --static).
RUN if [ -d /opt/sysroots/x86_64-unknown-netbsd ]; then \
        pcdir=/opt/sysroots/x86_64-unknown-netbsd/usr/pkg/lib/pkgconfig; \
        mkdir -p "$pcdir"; \
        printf 'Name: x11\nDescription: X11 client library (cross stub)\nVersion: 1.8.7\nLibs:\nCflags:\n'         > "$pcdir/x11.pc"; \
        printf 'Name: xext\nDescription: X Extension library (cross stub)\nVersion: 1.3.5\nLibs:\nCflags:\n'       > "$pcdir/xext.pc"; \
        printf 'Name: xrender\nDescription: X Render Extension (cross stub)\nVersion: 0.9.11\nLibs:\nCflags:\n'    > "$pcdir/xrender.pc"; \
        printf 'Name: xcb\nDescription: XCB (cross stub)\nVersion: 1.17.0\nLibs:\nCflags:\n'                       > "$pcdir/xcb.pc"; \
        printf 'Name: xcb-render\nDescription: XCB Render Extension (cross stub)\nVersion: 1.17.0\nLibs:\nCflags:\n' > "$pcdir/xcb-render.pc"; \
        printf 'Name: xcb-shm\nDescription: XCB SHM Extension (cross stub)\nVersion: 1.17.0\nLibs:\nCflags:\n'     > "$pcdir/xcb-shm.pc"; \
        printf 'Name: xproto\nDescription: X11 protocol headers (cross stub)\nVersion: 7.0.31\nLibs:\nCflags:\n'    > "$pcdir/xproto.pc"; \
        printf 'Name: xi\nDescription: Xi extension library (cross stub)\nVersion: 1.7.10\nLibs:\nCflags: -I/usr/X11R7/include\n'                  > "$pcdir/xi.pc"; \
        printf 'Name: xrandr\nDescription: X Resize and Rotate Extension (cross stub)\nVersion: 1.5.4\nLibs:\nCflags: -I/usr/X11R7/include\n'       > "$pcdir/xrandr.pc"; \
        printf 'Name: xcursor\nDescription: Xcursor cursor management (cross stub)\nVersion: 1.2.2\nLibs:\nCflags: -I/usr/X11R7/include\n'          > "$pcdir/xcursor.pc"; \
        printf 'Name: xfixes\nDescription: X Fixes Extension (cross stub)\nVersion: 6.0.1\nLibs:\nCflags: -I/usr/X11R7/include\n'                  > "$pcdir/xfixes.pc"; \
        printf 'Name: xcomposite\nDescription: X Composite Extension (cross stub)\nVersion: 0.4.5\nLibs:\nCflags: -I/usr/X11R7/include\n'          > "$pcdir/xcomposite.pc"; \
        printf 'Name: xdamage\nDescription: X Damage Extension (cross stub)\nVersion: 1.1.6\nLibs:\nCflags: -I/usr/X11R7/include\n'                > "$pcdir/xdamage.pc"; \
        printf 'Name: xinerama\nDescription: Xinerama Extension (cross stub)\nVersion: 1.1.4\nLibs:\nCflags: -I/usr/X11R7/include\n'               > "$pcdir/xinerama.pc"; \
        printf 'Name: egl\nDescription: EGL library and headers (cross stub)\nVersion: 1.5\nLibs:\nCflags: -I/usr/X11R7/include\n'                  > "$pcdir/egl.pc"; \
        printf 'Name: gl\nDescription: OpenGL library and headers (cross stub)\nVersion: 1.4\nLibs:\nCflags: -I/usr/X11R7/include\n'               > "$pcdir/gl.pc"; \
    fi

# ── pkg-config wrappers for cross-compilation ─────────────────────────────────
# Each wrapper sets PKG_CONFIG_PATH + PKG_CONFIG_SYSROOT_DIR so pkg-config finds
# the correct .pc files and rewrites absolute paths for the target sysroot.
# FreeBSD uses /usr/local/libdata/pkgconfig; NetBSD adds /usr/pkg/lib/pkgconfig.
ENV PKG_CONFIG_ALLOW_CROSS=1

RUN mkdir -p /opt/cross/bin \
    # ── arm64 (bundled sysroot at /usr/aarch64-linux-gnu/) ───────────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/aarch64-linux-gnu/usr/local/lib/pkgconfig:/usr/aarch64-linux-gnu/usr/local/lib64/pkgconfig:/usr/aarch64-linux-gnu/usr/local/share/pkgconfig:/usr/aarch64-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/aarch64-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/aarch64-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/aarch64-unknown-linux-gnu-pkg-config \
    # ── armhf (bundled sysroot at /usr/arm-linux-gnueabihf/) ─────────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/arm-linux-gnueabihf/usr/local/lib/pkgconfig:/usr/arm-linux-gnueabihf/usr/local/share/pkgconfig:/usr/arm-linux-gnueabihf/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/arm-linux-gnueabihf/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/arm-linux-gnueabihf \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/armv7-unknown-linux-gnueabihf-pkg-config \
    # ── s390x (bundled sysroot at /usr/s390x-linux-gnu/) ─────────────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/s390x-linux-gnu/usr/local/lib/pkgconfig:/usr/s390x-linux-gnu/usr/local/share/pkgconfig:/usr/s390x-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/s390x-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/s390x-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/s390x-unknown-linux-gnu-pkg-config \
    # ── riscv64 (bundled sysroot at /usr/riscv64-linux-gnu/) ─────────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/riscv64-linux-gnu/usr/local/lib/pkgconfig:/usr/riscv64-linux-gnu/usr/local/share/pkgconfig:/usr/riscv64-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/riscv64-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/riscv64-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/riscv64gc-unknown-linux-gnu-pkg-config \
    # ── i686 — Ubuntu-style layout: .pc files at usr/lib/i386-linux-gnu/pkgconfig/
    # Note: bzip2.pc (needed by freetype2 → gtk+) lives in usr/share/pkgconfig inside the sysroot,
    # so we must include /usr/i686-linux-gnu/usr/share/pkgconfig explicitly (Docker has no host bzip2-dev).
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/i686-linux-gnu/usr/local/lib/pkgconfig:/usr/i686-linux-gnu/usr/lib/i386-linux-gnu/pkgconfig:/usr/i686-linux-gnu/lib/pkgconfig:/usr/i686-linux-gnu/usr/lib/pkgconfig:/usr/i686-linux-gnu/usr/share/pkgconfig:/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/i686-linux-gnu/usr/local/lib/pkgconfig:/usr/i686-linux-gnu/usr/lib/i386-linux-gnu/pkgconfig:/usr/i686-linux-gnu/usr/lib/pkgconfig:/usr/i686-linux-gnu/usr/share/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/i686-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/i686-unknown-linux-gnu-pkg-config \
    # ── powerpc64le (bundled sysroot at /usr/powerpc64le-linux-gnu/) ────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/powerpc64le-linux-gnu/usr/local/lib/pkgconfig:/usr/powerpc64le-linux-gnu/usr/local/lib64/pkgconfig:/usr/powerpc64le-linux-gnu/usr/local/share/pkgconfig:/usr/powerpc64le-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/powerpc64le-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/powerpc64le-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/powerpc64le-unknown-linux-gnu-pkg-config \
    # ── powerpc64 (bundled sysroot at /usr/powerpc64-linux-gnu/) ─────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/powerpc64-linux-gnu/usr/local/lib/pkgconfig:/usr/powerpc64-linux-gnu/usr/local/lib64/pkgconfig:/usr/powerpc64-linux-gnu/usr/local/share/pkgconfig:/usr/powerpc64-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/powerpc64-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/powerpc64-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/powerpc64-unknown-linux-gnu-pkg-config \
    # ── powerpc32 (bundled sysroot at /usr/powerpc-linux-gnu/) ───────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/powerpc-linux-gnu/usr/local/lib/pkgconfig:/usr/powerpc-linux-gnu/usr/local/share/pkgconfig:/usr/powerpc-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/powerpc-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/powerpc-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/powerpc-unknown-linux-gnu-pkg-config \
    # ── sparc64 (bundled sysroot at /usr/sparc64-linux-gnu/) ─────────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/sparc64-linux-gnu/usr/local/lib/pkgconfig:/usr/sparc64-linux-gnu/usr/local/lib64/pkgconfig:/usr/sparc64-linux-gnu/usr/local/share/pkgconfig:/usr/sparc64-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/sparc64-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/sparc64-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/sparc64-unknown-linux-gnu-pkg-config \
    # ── mips32 BE (bundled sysroot at /usr/mips-linux-gnu/) ──────────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/mips-linux-gnu/usr/local/lib/pkgconfig:/usr/mips-linux-gnu/usr/local/share/pkgconfig:/usr/mips-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/mips-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/mips-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/mips-unknown-linux-gnu-pkg-config \
    # ── mips32 LE (bundled sysroot at /usr/mipsel-linux-gnu/) ────────────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/mipsel-linux-gnu/usr/local/lib/pkgconfig:/usr/mipsel-linux-gnu/usr/local/share/pkgconfig:/usr/mipsel-linux-gnu/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/mipsel-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/mipsel-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/mipsel-unknown-linux-gnu-pkg-config \
    # ── mips64 BE (bundled sysroot at /usr/mips64-linux-gnuabi64/) ───────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/mips64-linux-gnuabi64/usr/local/lib/pkgconfig:/usr/mips64-linux-gnuabi64/usr/local/lib64/pkgconfig:/usr/mips64-linux-gnuabi64/usr/local/share/pkgconfig:/usr/mips64-linux-gnuabi64/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/mips64-linux-gnuabi64/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/mips64-linux-gnuabi64 \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/mips64-unknown-linux-gnuabi64-pkg-config \
    # ── mips64 LE (bundled sysroot at /usr/mips64el-linux-gnuabi64/) ─────────
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/mips64el-linux-gnuabi64/usr/local/lib/pkgconfig:/usr/mips64el-linux-gnuabi64/usr/local/lib64/pkgconfig:/usr/mips64el-linux-gnuabi64/usr/local/share/pkgconfig:/usr/mips64el-linux-gnuabi64/usr/lib/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/mips64el-linux-gnuabi64/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/mips64el-linux-gnuabi64 \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/mips64el-unknown-linux-gnuabi64-pkg-config \
    # ── loongarch64 (bundled sysroot at /usr/loongarch64-linux-gnu/) ─────────
    # webkit2gtk lives at usr/lib/loongarch64-linux-gnu/pkgconfig/ (Debian multiarch layout)
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/usr/loongarch64-linux-gnu/usr/local/lib/pkgconfig:/usr/loongarch64-linux-gnu/usr/local/lib64/pkgconfig:/usr/loongarch64-linux-gnu/usr/local/share/pkgconfig:/usr/loongarch64-linux-gnu/usr/lib/loongarch64-linux-gnu/pkgconfig:/usr/loongarch64-linux-gnu/usr/lib/pkgconfig:/usr/loongarch64-linux-gnu/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/usr/loongarch64-linux-gnu/usr/lib/loongarch64-linux-gnu/pkgconfig:/usr/loongarch64-linux-gnu/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/usr/loongarch64-linux-gnu \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/loongarch64-unknown-linux-gnu-pkg-config \
    # ── FreeBSD x86_64
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/x86_64-unknown-freebsd/usr/local/lib/pkgconfig:/opt/sysroots/x86_64-unknown-freebsd/usr/local/libdata/pkgconfig:/opt/sysroots/x86_64-unknown-freebsd/usr/local/share/pkgconfig:/opt/sysroots/x86_64-unknown-freebsd/usr/lib/pkgconfig:/opt/sysroots/x86_64-unknown-freebsd/usr/libdata/pkgconfig:/opt/sysroots/x86_64-unknown-freebsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/x86_64-unknown-freebsd/usr/local/lib/pkgconfig:/opt/sysroots/x86_64-unknown-freebsd/usr/local/libdata/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/x86_64-unknown-freebsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/x86_64-unknown-freebsd-pkg-config \
    # ── NetBSD x86_64
    # usr/X11R7/lib/pkgconfig: NetBSD's X11 pkgconfig files (x11.pc, xcb.pc,
    # xrender.pc, xproto.pc, xext.pc, etc.) live here — missing from this path
    # caused all X11-dependent GUI packages to fail with "not found" errors.
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/x86_64-unknown-netbsd/usr/local/lib/pkgconfig:/opt/sysroots/x86_64-unknown-netbsd/usr/local/share/pkgconfig:/opt/sysroots/x86_64-unknown-netbsd/usr/lib/pkgconfig:/opt/sysroots/x86_64-unknown-netbsd/usr/pkg/lib/pkgconfig:/opt/sysroots/x86_64-unknown-netbsd/usr/pkg/share/pkgconfig:/opt/sysroots/x86_64-unknown-netbsd/usr/X11R7/lib/pkgconfig:/opt/sysroots/x86_64-unknown-netbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/x86_64-unknown-netbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/x86_64-unknown-netbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/x86_64-unknown-netbsd-pkg-config \
    # ── FreeBSD aarch64
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/aarch64-unknown-freebsd/usr/local/lib/pkgconfig:/opt/sysroots/aarch64-unknown-freebsd/usr/local/libdata/pkgconfig:/opt/sysroots/aarch64-unknown-freebsd/usr/local/share/pkgconfig:/opt/sysroots/aarch64-unknown-freebsd/usr/lib/pkgconfig:/opt/sysroots/aarch64-unknown-freebsd/usr/libdata/pkgconfig:/opt/sysroots/aarch64-unknown-freebsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/aarch64-unknown-freebsd/usr/local/lib/pkgconfig:/opt/sysroots/aarch64-unknown-freebsd/usr/local/libdata/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/aarch64-unknown-freebsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/aarch64-unknown-freebsd-pkg-config \
    # ── NetBSD aarch64
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/aarch64-unknown-netbsd/usr/local/lib/pkgconfig:/opt/sysroots/aarch64-unknown-netbsd/usr/local/share/pkgconfig:/opt/sysroots/aarch64-unknown-netbsd/usr/lib/pkgconfig:/opt/sysroots/aarch64-unknown-netbsd/usr/pkg/lib/pkgconfig:/opt/sysroots/aarch64-unknown-netbsd/usr/pkg/share/pkgconfig:/opt/sysroots/aarch64-unknown-netbsd/usr/X11R7/lib/pkgconfig:/opt/sysroots/aarch64-unknown-netbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/aarch64-unknown-netbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/aarch64-unknown-netbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/aarch64-unknown-netbsd-pkg-config \
    # ── OpenBSD x86_64
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/x86_64-unknown-openbsd/usr/local/lib/pkgconfig:/opt/sysroots/x86_64-unknown-openbsd/usr/local/share/pkgconfig:/opt/sysroots/x86_64-unknown-openbsd/usr/lib/pkgconfig:/opt/sysroots/x86_64-unknown-openbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/x86_64-unknown-openbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/x86_64-unknown-openbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/x86_64-unknown-openbsd-pkg-config \
    # ── OpenBSD aarch64
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/aarch64-unknown-openbsd/usr/local/lib/pkgconfig:/opt/sysroots/aarch64-unknown-openbsd/usr/local/share/pkgconfig:/opt/sysroots/aarch64-unknown-openbsd/usr/lib/pkgconfig:/opt/sysroots/aarch64-unknown-openbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/aarch64-unknown-openbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/aarch64-unknown-openbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/aarch64-unknown-openbsd-pkg-config \
    # ── NetBSD i386
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/i686-unknown-netbsd/usr/local/lib/pkgconfig:/opt/sysroots/i686-unknown-netbsd/usr/local/share/pkgconfig:/opt/sysroots/i686-unknown-netbsd/usr/lib/pkgconfig:/opt/sysroots/i686-unknown-netbsd/usr/pkg/lib/pkgconfig:/opt/sysroots/i686-unknown-netbsd/usr/pkg/share/pkgconfig:/opt/sysroots/i686-unknown-netbsd/usr/X11R7/lib/pkgconfig:/opt/sysroots/i686-unknown-netbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/i686-unknown-netbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/i686-unknown-netbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/i686-unknown-netbsd-pkg-config \
    # ── NetBSD powerpc
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/powerpc-unknown-netbsd/usr/local/lib/pkgconfig:/opt/sysroots/powerpc-unknown-netbsd/usr/local/share/pkgconfig:/opt/sysroots/powerpc-unknown-netbsd/usr/lib/pkgconfig:/opt/sysroots/powerpc-unknown-netbsd/usr/pkg/lib/pkgconfig:/opt/sysroots/powerpc-unknown-netbsd/usr/pkg/share/pkgconfig:/opt/sysroots/powerpc-unknown-netbsd/usr/X11R7/lib/pkgconfig:/opt/sysroots/powerpc-unknown-netbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/powerpc-unknown-netbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/powerpc-unknown-netbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/powerpc-unknown-netbsd-pkg-config \
    # ── OpenBSD i386
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/i686-unknown-openbsd/usr/local/lib/pkgconfig:/opt/sysroots/i686-unknown-openbsd/usr/local/share/pkgconfig:/opt/sysroots/i686-unknown-openbsd/usr/lib/pkgconfig:/opt/sysroots/i686-unknown-openbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/i686-unknown-openbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/i686-unknown-openbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/i686-unknown-openbsd-pkg-config \
    # ── OpenBSD riscv64
    && printf '#!/bin/sh\nexec env \\\n    PKG_CONFIG_PATH=/opt/sysroots/riscv64gc-unknown-openbsd/usr/local/lib/pkgconfig:/opt/sysroots/riscv64gc-unknown-openbsd/usr/local/share/pkgconfig:/opt/sysroots/riscv64gc-unknown-openbsd/usr/lib/pkgconfig:/opt/sysroots/riscv64gc-unknown-openbsd/usr/share/pkgconfig \\\n    PKG_CONFIG_LIBDIR=/opt/sysroots/riscv64gc-unknown-openbsd/usr/local/lib/pkgconfig \\\n    PKG_CONFIG_SYSROOT_DIR=/opt/sysroots/riscv64gc-unknown-openbsd \\\n    pkg-config "$@"\n' \
        > /opt/cross/bin/riscv64gc-unknown-openbsd-pkg-config \
    && chmod +x /opt/cross/bin/*-pkg-config

ENV PATH=/opt/cross/bin:/opt/aarch64-linux-musl-cross/bin:$PATH

# ── Cross-compile eudev + gdkx11 stub for Linux sysroots ─────────────────────
RUN --mount=type=bind,source=docker/build-sysroot-extras.sh,target=/tmp/build-sysroot-extras.sh \
    bash /tmp/build-sysroot-extras.sh

# ── Rust ───────────────────────────────────────────────────────────────────────
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain ${RUST_TOOLCHAIN} \
    && rustup component add rust-src

RUN rustup target add \
    aarch64-unknown-linux-gnu \
    arm-unknown-linux-gnueabihf \
    armv7-unknown-linux-gnueabihf \
    thumbv7neon-unknown-linux-gnueabihf \
    i686-unknown-linux-gnu \
    loongarch64-unknown-linux-gnu \
    powerpc64-unknown-linux-gnu \
    powerpc64le-unknown-linux-gnu \
    powerpc-unknown-linux-gnu \
    riscv64gc-unknown-linux-gnu \
    s390x-unknown-linux-gnu \
    sparc64-unknown-linux-gnu \
    x86_64-unknown-linux-musl \
    aarch64-unknown-linux-musl \
    aarch64-linux-android \
    armv7-linux-androideabi \
    i686-linux-android \
    x86_64-linux-android \
    x86_64-unknown-freebsd \
    x86_64-unknown-netbsd \
    wasm32-unknown-unknown \
    wasm32-wasip1 \
    wasm32-wasip2 \
    i686-pc-windows-msvc \
    x86_64-pc-windows-msvc \
    aarch64-pc-windows-msvc
# MIPS removed from stable Rust (1.72+); BSD Tier 3 targets require nightly + build-std.
RUN rustup toolchain install nightly --no-self-update \
    && rustup component add rust-src --toolchain nightly \
    && rustup +nightly target add \
        mips-unknown-linux-gnu \
        mipsel-unknown-linux-gnu \
        mips64-unknown-linux-gnuabi64 \
        mips64el-unknown-linux-gnuabi64 \
        aarch64-unknown-freebsd \
        aarch64-unknown-netbsd \
        i686-unknown-netbsd \
        powerpc-unknown-netbsd \
        x86_64-unknown-openbsd \
        aarch64-unknown-openbsd \
        i686-unknown-openbsd \
        riscv64gc-unknown-openbsd \
        2>/dev/null || echo "INFO: some targets may not be available on nightly; build-std will be used"

# ── Android NDK r27d ──────────────────────────────────────────────────────────
ENV ANDROID_NDK_HOME=/opt/android-ndk
ENV NDK_BIN=${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin

RUN wget -q "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip" \
        -O /tmp/android-ndk.zip \
    && unzip -q /tmp/android-ndk.zip -d /opt \
    && mv /opt/android-ndk-${NDK_VERSION} ${ANDROID_NDK_HOME} \
    && rm /tmp/android-ndk.zip

# Android NDK linker wrappers — clang-as-linker-driver requires ld-style flags
# to be prefixed with -Wl,; strip --fix-cortex-a53-843419 (NDK r27/lld 18
# rejects it before detecting arch) and convert bare --as-needed / --eh-frame-hdr
# / --gc-sections to their -Wl, equivalents that clang understands.
RUN NDK=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin \
    && for pair in \
        "aarch64-linux-android21-clang:aarch64-android21-clang-ld" \
        "armv7a-linux-androideabi21-clang:armv7a-android21-clang-ld" \
        "i686-linux-android21-clang:i686-android21-clang-ld" \
        "x86_64-linux-android21-clang:x86_64-android21-clang-ld"; do \
        src="${pair%%:*}" dst="${pair##*:}"; \
        printf '#!/bin/bash\ndeclare -a A=()\nfor a in "$@"; do\n  case "$a" in\n    --fix-cortex-a53-843419|-Wl,--fix-cortex-a53-843419) continue ;;\n    --as-needed|--eh-frame-hdr|--gc-sections) a="-Wl,$a" ;;\n  esac\n  A+=("$a")\ndone\nexec %s "${A[@]}"\n' \
            "${NDK}/${src}" > "/usr/local/bin/${dst}" \
        && chmod +x "/usr/local/bin/${dst}"; \
    done

# cargo-xwin and the ring wrapper both expect clang-cl at /usr/bin/clang-cl.
# Point it at /usr/bin/clang-20 directly — clang enters MSVC driver mode when
# argv[0] is "clang-cl", which this symlink preserves.
RUN ln -sf /usr/bin/clang-20 /usr/bin/clang-cl

# ring 0.17.x forces compiler("clang") for aarch64-pc-windows-msvc when the
# detected compiler is not is_like_clang() — but clang-cl is ToolFamily::Msvc,
# not ToolFamily::Clang, so is_like_clang() is always false for clang-cl.
# This wrapper sits at /usr/local/bin/clang (shadows /usr/bin/clang in PATH),
# passes through to /usr/bin/clang for all targets except Windows MSVC, where
# it forwards to clang-cl so that cargo-xwin's /imsvc CFLAGS are understood.
RUN printf '#!/bin/bash\nfor a in "$@"; do\n  case "$a" in\n    --target=*-pc-windows-msvc|/imsvc|/imsvc*)\n      exec /usr/bin/clang-cl "$@" ;;\n  esac\ndone\nexec /usr/bin/clang "$@"\n' \
    > /usr/local/bin/clang \
    && chmod +x /usr/local/bin/clang

# ── BSD sysroot fallback downloads ────────────────────────────────────────────
# If the pre-built bundle from docker/sysroots/ was not present, download the bare
# OS base instead — headless only (no GTK3/WebKitGTK/dialog/menu/tray).
ENV FREEBSD_SYSROOT=/opt/sysroots/x86_64-unknown-freebsd
ENV NETBSD_SYSROOT=/opt/sysroots/x86_64-unknown-netbsd
ENV FREEBSD_AARCH64_SYSROOT=/opt/sysroots/aarch64-unknown-freebsd
ENV NETBSD_AARCH64_SYSROOT=/opt/sysroots/aarch64-unknown-netbsd
ENV OPENBSD_SYSROOT=/opt/sysroots/x86_64-unknown-openbsd
ENV OPENBSD_AARCH64_SYSROOT=/opt/sysroots/aarch64-unknown-openbsd
ENV NETBSD_I386_SYSROOT=/opt/sysroots/i686-unknown-netbsd
ENV NETBSD_POWERPC_SYSROOT=/opt/sysroots/powerpc-unknown-netbsd
ENV OPENBSD_I386_SYSROOT=/opt/sysroots/i686-unknown-openbsd
ENV OPENBSD_RISCV64_SYSROOT=/opt/sysroots/riscv64gc-unknown-openbsd

RUN if [ ! -d "${FREEBSD_SYSROOT}/usr" ]; then \
        echo "FreeBSD GTK3 bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${FREEBSD_SYSROOT} \
        && wget -q "https://download.freebsd.org/releases/amd64/amd64/14.3-RELEASE/base.txz" \
                   -O /tmp/freebsd-base.txz \
        && tar -xf /tmp/freebsd-base.txz -C ${FREEBSD_SYSROOT} \
        && rm /tmp/freebsd-base.txz; \
    else \
        echo "FreeBSD sysroot: using GTK3 bundle (dialog/menu/tray enabled)"; \
    fi

RUN if [ ! -d "${NETBSD_SYSROOT}/usr" ]; then \
        echo "NetBSD GTK3 bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${NETBSD_SYSROOT} \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/amd64/binary/sets/base.tar.xz" \
                   -O /tmp/netbsd-base.tar.xz \
        && tar -xf /tmp/netbsd-base.tar.xz -C ${NETBSD_SYSROOT} \
        && rm /tmp/netbsd-base.tar.xz \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/amd64/binary/sets/comp.tar.xz" \
                   -O /tmp/netbsd-comp.tar.xz \
        && tar -xf /tmp/netbsd-comp.tar.xz -C ${NETBSD_SYSROOT} \
        && rm /tmp/netbsd-comp.tar.xz; \
    else \
        echo "NetBSD sysroot: using GTK3 bundle (dialog/menu/tray enabled)"; \
    fi

RUN if [ ! -d "${FREEBSD_AARCH64_SYSROOT}/usr" ]; then \
        echo "FreeBSD aarch64 bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${FREEBSD_AARCH64_SYSROOT} \
        && wget -q "https://download.freebsd.org/releases/arm64/aarch64/14.3-RELEASE/base.txz" \
                   -O /tmp/freebsd-aarch64-base.txz \
        && tar -xf /tmp/freebsd-aarch64-base.txz -C ${FREEBSD_AARCH64_SYSROOT} \
        && rm /tmp/freebsd-aarch64-base.txz; \
    else \
        echo "FreeBSD aarch64 sysroot: using GTK3 bundle"; \
    fi

RUN if [ ! -d "${NETBSD_AARCH64_SYSROOT}/usr" ]; then \
        echo "NetBSD aarch64 bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${NETBSD_AARCH64_SYSROOT} \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/evbarm-aarch64/binary/sets/base.tar.xz" \
                   -O /tmp/netbsd-aarch64-base.tar.xz \
        && tar -xf /tmp/netbsd-aarch64-base.tar.xz -C ${NETBSD_AARCH64_SYSROOT} \
        && rm /tmp/netbsd-aarch64-base.tar.xz \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/evbarm-aarch64/binary/sets/comp.tar.xz" \
                   -O /tmp/netbsd-aarch64-comp.tar.xz \
        && tar -xf /tmp/netbsd-aarch64-comp.tar.xz -C ${NETBSD_AARCH64_SYSROOT} \
        && rm /tmp/netbsd-aarch64-comp.tar.xz; \
    else \
        echo "NetBSD aarch64 sysroot: using GTK3 bundle"; \
    fi

RUN if [ ! -d "${NETBSD_I386_SYSROOT}/usr" ]; then \
        echo "NetBSD i386 bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${NETBSD_I386_SYSROOT} \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/i386/binary/sets/base.tgz" \
                   -O /tmp/netbsd-i386-base.tgz \
        && tar -xf /tmp/netbsd-i386-base.tgz -C ${NETBSD_I386_SYSROOT} \
        && rm /tmp/netbsd-i386-base.tgz \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/i386/binary/sets/comp.tgz" \
                   -O /tmp/netbsd-i386-comp.tgz \
        && tar -xf /tmp/netbsd-i386-comp.tgz -C ${NETBSD_I386_SYSROOT} \
        && rm /tmp/netbsd-i386-comp.tgz; \
    else \
        echo "NetBSD i386 sysroot: using bundle"; \
    fi

RUN if [ ! -d "${NETBSD_POWERPC_SYSROOT}/usr" ]; then \
        echo "NetBSD powerpc bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${NETBSD_POWERPC_SYSROOT} \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/macppc/binary/sets/base.tgz" \
                   -O /tmp/netbsd-powerpc-base.tgz \
        && tar -xf /tmp/netbsd-powerpc-base.tgz -C ${NETBSD_POWERPC_SYSROOT} \
        && rm /tmp/netbsd-powerpc-base.tgz \
        && wget -q "https://cdn.netbsd.org/pub/NetBSD/NetBSD-10.1/macppc/binary/sets/comp.tgz" \
                   -O /tmp/netbsd-powerpc-comp.tgz \
        && tar -xf /tmp/netbsd-powerpc-comp.tgz -C ${NETBSD_POWERPC_SYSROOT} \
        && rm /tmp/netbsd-powerpc-comp.tgz; \
    else \
        echo "NetBSD powerpc sysroot: using bundle"; \
    fi

RUN if [ ! -d "${OPENBSD_I386_SYSROOT}/usr" ]; then \
        echo "OpenBSD i386 bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${OPENBSD_I386_SYSROOT} \
        && wget -q "https://cdn.openbsd.org/pub/OpenBSD/7.7/i386/base77.tgz" \
                   -O /tmp/openbsd-i386-base.tgz \
        && tar -xzf /tmp/openbsd-i386-base.tgz -C ${OPENBSD_I386_SYSROOT} \
        && rm /tmp/openbsd-i386-base.tgz \
        && wget -q "https://cdn.openbsd.org/pub/OpenBSD/7.7/i386/comp77.tgz" \
                   -O /tmp/openbsd-i386-comp.tgz \
        && tar -xzf /tmp/openbsd-i386-comp.tgz -C ${OPENBSD_I386_SYSROOT} \
        && rm /tmp/openbsd-i386-comp.tgz \
        && find ${OPENBSD_I386_SYSROOT}/usr/lib -maxdepth 1 -name "*.so.*" ! -name "*_p.so.*" \
           | while read so; do base="${so%%.so.*}.so"; [ -e "$base" ] || ln -sfn "$(basename $so)" "$base"; done; \
    else \
        echo "OpenBSD i386 sysroot: using bundle"; \
    fi

RUN if [ ! -d "${OPENBSD_RISCV64_SYSROOT}/usr" ]; then \
        echo "OpenBSD riscv64 bundle not found — downloading bare base sysroot (headless only)"; \
        mkdir -p ${OPENBSD_RISCV64_SYSROOT} \
        && wget -q "https://cdn.openbsd.org/pub/OpenBSD/7.7/riscv64/base77.tgz" \
                   -O /tmp/openbsd-riscv64-base.tgz \
        && tar -xzf /tmp/openbsd-riscv64-base.tgz -C ${OPENBSD_RISCV64_SYSROOT} \
        && rm /tmp/openbsd-riscv64-base.tgz \
        && wget -q "https://cdn.openbsd.org/pub/OpenBSD/7.7/riscv64/comp77.tgz" \
                   -O /tmp/openbsd-riscv64-comp.tgz \
        && tar -xzf /tmp/openbsd-riscv64-comp.tgz -C ${OPENBSD_RISCV64_SYSROOT} \
        && rm /tmp/openbsd-riscv64-comp.tgz \
        && find ${OPENBSD_RISCV64_SYSROOT}/usr/lib -maxdepth 1 -name "*.so.*" ! -name "*_p.so.*" \
           | while read so; do base="${so%%.so.*}.so"; [ -e "$base" ] || ln -sfn "$(basename $so)" "$base"; done; \
    else \
        echo "OpenBSD riscv64 sysroot: using bundle"; \
    fi

# ── bfd-ppc-netbsd: elf32ppc_nbsd emulation fixup + _SDA_BASE_ fix ───────────
# lld defines _SDA_BASE_ as an absolute symbol; the NetBSD crt0.o contains
# R_PPC_REL16_HA/LO relocations against it, which lld rejects ("cannot refer to
# absolute symbol").  GNU ld (powerpc-linux-gnu-ld) defines _SDA_BASE_ correctly
# relative to .sdata and handles these relocations.
# Name does NOT contain "lld" so clang generates GNU ld-compatible link args.
# clang internally derives "-m elf32ppc_nbsd" from the target triple; this wrapper
# substitutes it to the portable "elf32ppc" emulation that GNU ld knows.
RUN printf '#!/bin/bash\nargs=()\nfor a in "$@"; do\n  args+=("${a//elf32ppc_nbsd/elf32ppc}")\ndone\nexec powerpc-linux-gnu-ld "${args[@]}"\n' \
    > /usr/local/bin/bfd-ppc-netbsd \
    && chmod +x /usr/local/bin/bfd-ppc-netbsd

# ── BSD linker + CC wrappers ──────────────────────────────────────────────────
RUN \
    printf '#!/bin/sh\nexec clang -target x86_64-unknown-freebsd14.0 --sysroot=%s -fuse-ld=lld "$@"\n' \
        "${FREEBSD_SYSROOT}" > /opt/cross/bin/x86_64-unknown-freebsd-link \
    && printf '#!/bin/sh\nexec clang -target x86_64--netbsd --sysroot=%s -fuse-ld=lld -stdlib=libstdc++ "$@"\n' \
        "${NETBSD_SYSROOT}" > /opt/cross/bin/x86_64-unknown-netbsd-link \
    && printf '#!/bin/sh\nexec clang -target x86_64-unknown-freebsd14.0 --sysroot=%s "$@"\n' \
        "${FREEBSD_SYSROOT}" > /opt/cross/bin/x86_64-unknown-freebsd-cc \
    && printf '#!/bin/sh\nexec clang -target x86_64--netbsd --sysroot=%s "$@"\n' \
        "${NETBSD_SYSROOT}" > /opt/cross/bin/x86_64-unknown-netbsd-cc \
    && printf '#!/bin/sh\nexec clang -target x86_64--netbsd --sysroot=%s -stdlib=libstdc++ "$@"\n' \
        "${NETBSD_SYSROOT}" > /opt/cross/bin/x86_64-unknown-netbsd-cxx \
    && printf '#!/bin/sh\nexec clang -target aarch64-unknown-freebsd14.0 --sysroot=%s -fuse-ld=lld "$@"\n' \
        "${FREEBSD_AARCH64_SYSROOT}" > /opt/cross/bin/aarch64-unknown-freebsd-link \
    && printf '#!/bin/sh\nexec clang -target aarch64--netbsd --sysroot=%s -fuse-ld=lld -stdlib=libstdc++ "$@"\n' \
        "${NETBSD_AARCH64_SYSROOT}" > /opt/cross/bin/aarch64-unknown-netbsd-link \
    && printf '#!/bin/sh\nexec clang -target x86_64-unknown-openbsd7.7 --sysroot=%s -fuse-ld=lld "$@"\n' \
        "${OPENBSD_SYSROOT}" > /opt/cross/bin/x86_64-unknown-openbsd-link \
    && printf '#!/bin/sh\nexec clang-20 -target aarch64-unknown-openbsd7.7 --sysroot=%s -fuse-ld=lld-20 "$@"\n' \
        "${OPENBSD_AARCH64_SYSROOT}" > /opt/cross/bin/aarch64-unknown-openbsd-link \
    && printf '#!/bin/sh\nexec clang -target aarch64-unknown-freebsd14.0 --sysroot=%s "$@"\n' \
        "${FREEBSD_AARCH64_SYSROOT}" > /opt/cross/bin/aarch64-unknown-freebsd-cc \
    && printf '#!/bin/sh\nexec clang -target aarch64--netbsd --sysroot=%s "$@"\n' \
        "${NETBSD_AARCH64_SYSROOT}" > /opt/cross/bin/aarch64-unknown-netbsd-cc \
    && printf '#!/bin/sh\nexec clang -target aarch64--netbsd --sysroot=%s -stdlib=libstdc++ "$@"\n' \
        "${NETBSD_AARCH64_SYSROOT}" > /opt/cross/bin/aarch64-unknown-netbsd-cxx \
    && printf '#!/bin/sh\nexec clang -target x86_64-unknown-openbsd7.7 --sysroot=%s "$@"\n' \
        "${OPENBSD_SYSROOT}" > /opt/cross/bin/x86_64-unknown-openbsd-cc \
    && printf '#!/bin/sh\nexec clang-20 -target aarch64-unknown-openbsd7.7 --sysroot=%s "$@"\n' \
        "${OPENBSD_AARCH64_SYSROOT}" > /opt/cross/bin/aarch64-unknown-openbsd-cc \
    && printf '#!/bin/sh\nexec clang -target i686--netbsd --sysroot=%s -fuse-ld=lld -stdlib=libstdc++ "$@"\n' \
        "${NETBSD_I386_SYSROOT}" > /opt/cross/bin/i686-unknown-netbsd-link \
    && printf '#!/bin/sh\nexec clang -target i686--netbsd --sysroot=%s "$@"\n' \
        "${NETBSD_I386_SYSROOT}" > /opt/cross/bin/i686-unknown-netbsd-cc \
    && printf '#!/bin/sh\nexec clang -target i686--netbsd --sysroot=%s -stdlib=libstdc++ "$@"\n' \
        "${NETBSD_I386_SYSROOT}" > /opt/cross/bin/i686-unknown-netbsd-cxx \
    && printf '#!/bin/bash\nargs=()\nfor a in "$@"; do\n  args+=("${a//elf32ppc_nbsd/elf32ppc}")\ndone\nexec clang -target powerpc--netbsd --sysroot=%s -fuse-ld=/usr/local/bin/bfd-ppc-netbsd -stdlib=libstdc++ "${args[@]}"\n' \
        "${NETBSD_POWERPC_SYSROOT}" > /opt/cross/bin/powerpc-unknown-netbsd-link \
    && printf '#!/bin/sh\nexec clang -target powerpc--netbsd --sysroot=%s "$@"\n' \
        "${NETBSD_POWERPC_SYSROOT}" > /opt/cross/bin/powerpc-unknown-netbsd-cc \
    && printf '#!/bin/sh\nexec clang -target powerpc--netbsd --sysroot=%s -stdlib=libstdc++ "$@"\n' \
        "${NETBSD_POWERPC_SYSROOT}" > /opt/cross/bin/powerpc-unknown-netbsd-cxx \
    && printf '#!/bin/sh\nexec clang -target i686-unknown-openbsd7.7 --sysroot=%s -fuse-ld=lld "$@"\n' \
        "${OPENBSD_I386_SYSROOT}" > /opt/cross/bin/i686-unknown-openbsd-link \
    && printf '#!/bin/sh\nexec clang -target i686-unknown-openbsd7.7 --sysroot=%s "$@"\n' \
        "${OPENBSD_I386_SYSROOT}" > /opt/cross/bin/i686-unknown-openbsd-cc \
    && printf '#!/bin/sh\nexec clang -target riscv64-unknown-openbsd7.7 --sysroot=%s -fuse-ld=lld "$@"\n' \
        "${OPENBSD_RISCV64_SYSROOT}" > /opt/cross/bin/riscv64gc-unknown-openbsd-link \
    && printf '#!/bin/sh\nexec clang -target riscv64-unknown-openbsd7.7 --sysroot=%s "$@"\n' \
        "${OPENBSD_RISCV64_SYSROOT}" > /opt/cross/bin/riscv64gc-unknown-openbsd-cc \
    && chmod +x /opt/cross/bin/x86_64-unknown-freebsd-link \
                /opt/cross/bin/x86_64-unknown-netbsd-link \
                /opt/cross/bin/aarch64-unknown-freebsd-link \
                /opt/cross/bin/aarch64-unknown-netbsd-link \
                /opt/cross/bin/x86_64-unknown-openbsd-link \
                /opt/cross/bin/aarch64-unknown-openbsd-link \
                /opt/cross/bin/i686-unknown-netbsd-link \
                /opt/cross/bin/powerpc-unknown-netbsd-link \
                /opt/cross/bin/i686-unknown-openbsd-link \
                /opt/cross/bin/riscv64gc-unknown-openbsd-link \
                /opt/cross/bin/x86_64-unknown-freebsd-cc \
                /opt/cross/bin/x86_64-unknown-netbsd-cc \
                /opt/cross/bin/aarch64-unknown-freebsd-cc \
                /opt/cross/bin/aarch64-unknown-netbsd-cc \
                /opt/cross/bin/x86_64-unknown-openbsd-cc \
                /opt/cross/bin/aarch64-unknown-openbsd-cc \
                /opt/cross/bin/i686-unknown-netbsd-cc \
                /opt/cross/bin/powerpc-unknown-netbsd-cc \
                /opt/cross/bin/i686-unknown-openbsd-cc \
                /opt/cross/bin/riscv64gc-unknown-openbsd-cc \
                /opt/cross/bin/x86_64-unknown-netbsd-cxx \
                /opt/cross/bin/aarch64-unknown-netbsd-cxx \
                /opt/cross/bin/i686-unknown-netbsd-cxx \
                /opt/cross/bin/powerpc-unknown-netbsd-cxx

# ── Windows MSVC (downloads MSVC headers/libs from NuGet on first use) ────────
RUN cargo install cargo-xwin --locked

# Pre-populate the xwin cache with both the MSVC CRT and the Windows SDK for x86.
#
# cargo-xwin v0.23.0 and xwin v0.9.0 have complementary download behaviour for x86:
#   "cargo xwin build" downloads MSVC CRT (msvcrt.lib) but NOT Windows SDK (kernel32.lib).
#   "xwin splat"       downloads Windows SDK (kernel32.lib) but NOT MSVC CRT (msvcrt.lib).
#
# The cmake compiler-identification test (triggered by AWS_LC_SYS_NO_ASM=1) links a
# test executable that needs BOTH msvcrt.lib AND kernel32.lib.  We need both in the
# image before any test runs.
#
# Strategy: run a cargo-xwin warmup build first.  cargo-xwin downloads x86 MSVC CRT
# and writes an xwin manifest entry marking CRT as done.  The link step fails
# (kernel32.lib is still absent) — that exit code is suppressed with || true.
# Then xwin splat runs: it reads the manifest, sees x86 CRT already present, and
# downloads only what is missing — the Windows SDK for x86 (and CRT+SDK for x86_64
# and aarch64 which are also absent at this point).  The CRT files from the warmup
# remain untouched.  After both steps every arch has msvcrt.lib + kernel32.lib.
RUN mkdir -p /tmp/xwin-warmup/src \
    && printf '[package]\nname = "xw"\nversion = "0.0.1"\nedition = "2021"\n' \
        > /tmp/xwin-warmup/Cargo.toml \
    && printf 'fn main() {}\n' > /tmp/xwin-warmup/src/main.rs \
    && (cd /tmp/xwin-warmup && cargo xwin build --target i686-pc-windows-msvc) || true \
    && rm -rf /tmp/xwin-warmup \
    && cargo install xwin --version "=0.9.0" --locked \
    && xwin --accept-license --arch x86 --arch x86_64 --arch aarch64 \
        splat --output /root/.cache/cargo-xwin/xwin \
    && rm /usr/local/cargo/bin/xwin

RUN cargo install just --locked

# ── WASM tooling ───────────────────────────────────────────────────────────────
# WASI SDK: provides wasm32-wasip1-clang / wasm32-wasip2-clang and the WASI sysroot
# (wasi-libc headers), enabling C-dependent crates (zstd-sys, etc.) to compile for WASI.
ARG WASI_SDK_VER=33
RUN wget -q "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VER}/wasi-sdk-${WASI_SDK_VER}.0-x86_64-linux.tar.gz" \
        -O /tmp/wasi-sdk.tar.gz \
    && tar -xzf /tmp/wasi-sdk.tar.gz -C /opt \
    && mv /opt/wasi-sdk-${WASI_SDK_VER}.0-x86_64-linux /opt/wasi-sdk \
    && rm /tmp/wasi-sdk.tar.gz

RUN WASMTIME_VER=45.0.2; \
    wget -qO- "https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME_VER}/wasmtime-v${WASMTIME_VER}-x86_64-linux.tar.xz" \
    | tar -xJ --strip-components=1 -C /usr/local/bin/ \
        "wasmtime-v${WASMTIME_VER}-x86_64-linux/wasmtime"
RUN cargo install wasm-pack --locked

COPY docker/cargo-config.toml /usr/local/cargo/config.toml

# ── Sanity checks ──────────────────────────────────────────────────────────────
RUN aarch64-linux-gnu-gcc --version \
    && clang --version \
    && ${NDK_BIN}/aarch64-linux-android${NDK_API}-clang --version \
    && aarch64-unknown-linux-gnu-pkg-config --version \
    && pkg-config --exists webkit2gtk-4.1 && echo "webkit2gtk OK (native)" \
    && echo '#include <stdio.h>' > /tmp/t.c && i686-linux-gnu-gcc -c /tmp/t.c -o /tmp/t.o 2>&1 \
       && echo "i686 C compile OK" || echo "WARNING: i686 C compile failed" \
    && aarch64-unknown-linux-gnu-pkg-config --exists webkit2gtk-4.1 \
       && echo "webkit2gtk OK (arm64 sysroot)" || echo "INFO: arm64 sysroot not bundled yet — run just bundle-sysroots" \
    && i686-unknown-linux-gnu-pkg-config --exists webkit2gtk-4.1 \
       && echo "webkit2gtk OK (i686 sysroot)" || echo "INFO: i686 sysroot not bundled yet — run just bundle-sysroots" \
    && pkg-config --exists vulkan && echo "vulkan OK (native)" \
    && aarch64-unknown-linux-gnu-pkg-config --exists vulkan \
       && echo "vulkan OK (arm64 sysroot)" || echo "INFO: arm64 sysroot not bundled yet — run just bundle-sysroots" \
    && rm -f /tmp/t.c /tmp/t.o

WORKDIR /workspace
