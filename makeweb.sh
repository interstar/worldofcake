#!/usr/bin/env bash
# Build (or rebuild) the World of Cake website previews under website/site/.
# Thin wrapper around website/make.py. Requires Haxe + Lime/OpenFL + Python 3.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

python3 website/make.py "$@"
