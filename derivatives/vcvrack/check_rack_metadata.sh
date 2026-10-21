#!/usr/bin/env bash
# Validate Rack-specific metadata files against Rack C++/SVG sources.
# Uses the bundled generator JAR; only Java is required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
JAR="$ROOT/vendor/layla/worldofcake-laylagen.jar"

if [[ ! -f "$JAR" ]]; then
    echo "Missing bundled generator JAR: $JAR" >&2
    echo "Restore it from git (it is committed under vendor/layla)." >&2
    exit 1
fi

if [[ "$#" -gt 0 ]]; then
    modules=("$@")
else
    modules=()
    for metadata in "$ROOT"/layouts/rack/*.edn; do
        [[ -e "$metadata" ]] || continue
        modules+=("$(basename "$metadata" .edn)")
    done
fi

if [[ "${#modules[@]}" -eq 0 ]]; then
    echo "No Rack metadata files found under layouts/rack" >&2
    exit 1
fi

for module in "${modules[@]}"; do
    metadata="$ROOT/layouts/rack/$module.edn"
    module_dir="$ROOT/derivatives/vcvrack/$module"
    if [[ ! -f "$metadata" ]]; then
        echo "Missing metadata file: $metadata" >&2
        exit 1
    fi
    if [[ ! -d "$module_dir" ]]; then
        echo "Missing Rack module directory: $module_dir" >&2
        exit 1
    fi
    java -cp "$JAR" clojure.main -m worldofcake.laylagen.rack-metadata-check \
        --metadata "$metadata" \
        --module-dir "$module_dir" \
        --generated-root "$ROOT/bridge/native"
done
