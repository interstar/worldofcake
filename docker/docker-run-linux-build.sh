#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec docker run --rm \
    -e RACK_DIR=/opt/rack-sdk/Rack-SDK \
    -v "$ROOT:/opt/worldofcake" \
    -w /opt/worldofcake \
    worldofcake:linux \
    "$@"
