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
rm -rf build derivatives/openfl/Export generated

step "Generate every app for every target"
"$ROOT/generate.sh" all all

step "Verify generated outputs and Rack sources"
"$ROOT/generate.sh" all all --check

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

step "Build web previews"
python3 "$ROOT/website/make.py"

step "Clean Rack artifacts"
"$ROOT/derivatives/vcvrack/build_all.sh" clean

step "Build, package, and install Rack modules"
"$ROOT/derivatives/vcvrack/install_linux_local.sh"

step "Complete"
