#!/usr/bin/env bash
# Compatibility wrapper: generate (or with --check, verify) the Rack panels and layout headers.
# Generation for every target now lives in generate.sh (see docs/BUILD_INSTRUCTIONS.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$ROOT/generate.sh" all rack "$@"
