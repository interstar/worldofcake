#!/usr/bin/env bash
# Compatibility wrapper: verify Rack metadata against the module sources (optionally for named modules).
# Generation for every target now lives in generate.sh (see docs/BUILD_INSTRUCTIONS.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "$#" -eq 0 ]]; then
    exec "$ROOT/generate.sh" all rack --check
fi
for module in "$@"; do
    "$ROOT/generate.sh" "$module" rack --check
done
