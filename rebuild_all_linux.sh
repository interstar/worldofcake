#!/usr/bin/env bash
# Clean, regenerate, test, build, and install the Linux World of Cake outputs.
#
# Distribution build script. Layla layout generation uses the self-contained
# generator JAR committed under vendor/layla, so this script does NOT require a
# Layla checkout, Clojure, or Maven; the only Layla-related prerequisite is a
# Java 11+ runtime. The Haxe / Lime / OpenFL and VCV Rack SDK toolchains are
# still required for their respective steps (as they are for any local build).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

JAR="$ROOT/vendor/layla/worldofcake-laylagen.jar"
APPS=(gbloink timeslider kdiagram tileland zewp)
OPENFL_APPS=(gbloink kdiagram tileland timeslider zewp)
GOLDENPOND_ROOT="${GOLDENPOND_ROOT:-$ROOT/../goldenpond/goldenpond}"

if [[ ! -f "$JAR" ]]; then
    echo "Missing bundled generator JAR: $JAR" >&2
    echo "Restore it from git (it is committed under vendor/layla)." >&2
    exit 1
fi

if [[ -d "$GOLDENPOND_ROOT/current/haxe/src/goldenpond" ]]; then
    OPENFL_APPS+=(goldenpond)
fi

step() {
    printf '\n=== %s ===\n' "$1"
}

step "Clean generated and build outputs"
rm -rf build derivatives/openfl/Export Source/generated bridge/native/worldofcake/generated

step "Generate Layla UI outputs"
for app in "${APPS[@]}"; do
    echo "--- $app ---"
    java -jar "$JAR" \
        --input "$ROOT/layouts/openfl/$app.layla" \
        --config "$ROOT/layouts/openfl/$app.edn" \
        --output "$ROOT/Source" \
        --native-output "$ROOT/bridge/native"
done

if [[ -d "$GOLDENPOND_ROOT/current/haxe/src/goldenpond" ]]; then
    echo "--- goldenpond ---"
    java -jar "$JAR" \
        --input "$ROOT/layouts/openfl/goldenpond.layla" \
        --config "$ROOT/layouts/openfl/goldenpond.edn" \
        --output "$ROOT/Source" \
        --native-output "$ROOT/bridge/native"
else
    echo "Goldenpond source not found at $GOLDENPOND_ROOT; skipping Goldenpond UI generation."
fi

step "Generate Rack metadata outputs"
"$ROOT/derivatives/vcvrack/generate_rack_metadata.sh"

step "Generate Rack layout outputs"
"$ROOT/derivatives/vcvrack/generate_rack_layout.sh"

step "Validate Rack metadata"
"$ROOT/derivatives/vcvrack/check_rack_metadata.sh"

step "Validate Rack layout outputs"
"$ROOT/derivatives/vcvrack/generate_rack_layout.sh" --check

step "Run Haxe headless tests"
for app in gbloink zewp kdiagram tileland timeslider; do
    echo "--- $app ---"
    haxe "hxml/tests/test-$app-headless.hxml"
done

step "Run optional Goldenpond compiler test"
if [[ -d "$GOLDENPOND_ROOT/current/haxe/src/goldenpond" ]]; then
    GOLDENPOND_ROOT="$GOLDENPOND_ROOT" "$ROOT/test-goldenpond-linux.sh"
else
    echo "Goldenpond source not found at $GOLDENPOND_ROOT; skipping Goldenpond app/test."
fi

step "Build OpenFL Neko apps"
for app in "${OPENFL_APPS[@]}"; do
    echo "--- $app ---"
    lime build "derivatives/openfl/project-$app.xml" neko
done

step "Clean Rack artifacts"
"$ROOT/derivatives/vcvrack/build_all.sh" clean

step "Build, package, and install Rack modules"
"$ROOT/derivatives/vcvrack/install_linux_local.sh"

step "Complete"
