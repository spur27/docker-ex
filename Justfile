# docker-ex — task runner
# Install: cargo install just
# Usage:   just <recipe>

# ── Docker image management ───────────────────────────────────────────────────

GHCR_IMAGE := "ghcr.io/spur27/docker-ex"

docker-build:
    cp /opt/sysroots/.build/build-system/linux/build-sysroot-extras.sh docker/build-sysroot-extras.sh
    docker build -f docker/Dockerfile -t docker-ex:latest .
    rm -f docker/build-sysroot-extras.sh

docker-run *ARGS:
    docker run --rm \
        -v "$(pwd):/workspace" \
        -v "$(pwd)/docker/cargo-config.toml:/workspace/.cargo/config.toml:ro" \
        -w /workspace docker-ex:latest {{ARGS}}

docker-pull TAG="latest":
    docker pull {{GHCR_IMAGE}}:{{TAG}}
    docker tag {{GHCR_IMAGE}}:{{TAG}} docker-ex:{{TAG}}

docker-login:
    gh auth token | docker login ghcr.io -u spur27 --password-stdin

docker-push TAG="latest":
    docker tag docker-ex:latest {{GHCR_IMAGE}}:{{TAG}}
    docker push {{GHCR_IMAGE}}:{{TAG}}

docker-publish TAG="latest": docker-login docker-build (docker-push TAG)

# ── Sysroot management ────────────────────────────────────────────────────────

bundle-sysroots:
    sudo env "PATH=$PATH" bash docker/bundle-sysroots.sh