#!/usr/bin/env bash
# Thin shim — real logic lives in the shared build-system repo.
# OUT_DIR is set so archives land in docker/sysroots/ for the Dockerfile COPY.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/sysroots" \
exec bash /opt/sysroots/.build/build-system/bundle-sysroots.sh "$@"
