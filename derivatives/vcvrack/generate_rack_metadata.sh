#!/usr/bin/env bash
# Generate or check Rack-native data derived from layouts/rack/*.edn.
# Uses the bundled generator JAR; only Java is required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JAR="$ROOT/vendor/layla/worldofcake-laylagen.jar"

if [[ ! -f "$JAR" ]]; then
    echo "Missing bundled generator JAR: $JAR" >&2
    echo "Restore vendor/layla from git, or rebuild it with laylagen/package-worldofcake-laylagen.sh (maintainers only)." >&2
    exit 1
fi

CHECK_ARGS=()
if [[ "${1:-}" == "--check" ]]; then
    CHECK_ARGS+=(--check)
fi

for metadata in "$ROOT"/layouts/rack/*.edn; do
    [[ -e "$metadata" ]] || continue
    java -cp "$JAR" clojure.main \
        -m worldofcake.laylagen.rack-metadata-generate \
        --metadata "$metadata" \
        --output "$ROOT/bridge/native" \
        "${CHECK_ARGS[@]}"
done
