#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

docker build -t worldofcake:linux -f "$ROOT/docker/Dockerfile" "$ROOT"
