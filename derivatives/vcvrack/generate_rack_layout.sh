#!/usr/bin/env bash
# Generate or check Rack SVG and native layout data from Rack Layla/EDN.
# Uses the bundled generator JAR; only Java is required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JAR="$ROOT/vendor/layla/worldofcake-laylagen.jar"

if [[ ! -f "$JAR" ]]; then
    echo "Missing bundled generator JAR: $JAR" >&2
    echo "Restore it from git (it is committed under vendor/layla)." >&2
    exit 1
fi

CHECK_ARGS=()
if [[ "${1:-}" == "--check" ]]; then CHECK_ARGS+=(--check); fi

for input in "$ROOT"/layouts/rack/*.layla; do
    [[ -e "$input" ]] || continue
    app="$(basename "$input" .layla)"
    config="$ROOT/layouts/rack/$app.edn"
    output="$ROOT/derivatives/vcvrack/$app"
    [[ -f "$config" ]] || { echo "Missing Rack EDN for $app: $config" >&2; exit 1; }
    java -cp "$JAR" clojure.main \
        -m worldofcake.laylagen.rack-layout-generate \
        --input "$input" \
        --config "$config" \
        --output "$output" \
        --native-output "$ROOT/bridge/native" \
        "${CHECK_ARGS[@]}"
done
