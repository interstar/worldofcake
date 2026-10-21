#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GOLDENPOND_ROOT="${GOLDENPOND_ROOT:-$ROOT/../goldenpond/goldenpond}"
GOLDENPOND_SRC="$GOLDENPOND_ROOT/current/haxe/src/goldenpond"

if [[ ! -d "$GOLDENPOND_SRC" ]]; then
    echo "Goldenpond source not found at $GOLDENPOND_SRC; skipping Goldenpond test."
    exit 0
fi

haxe --interp \
    -cp "$ROOT/Source" \
    -cp "$GOLDENPOND_SRC" \
    --main test.TestGoldenpondScoreCompiler
