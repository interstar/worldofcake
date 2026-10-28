#!/usr/bin/env bash
# Generate every app's code for each target with the bundled generator JAR (Java 11+ only).
# Apps under apps/<app>/ (app.edn plus <target>.edn/.layla overlays) are generated per target;
# apps not yet migrated still use layouts/openfl and layouts/rack.
# See docs/APP_TARGETS.md and docs/BUILD_INSTRUCTIONS.md.
#
#   ./generate.sh [app|all] [openfl|juce|rack|all] [--check]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
JAR="$ROOT/vendor/layla/worldofcake-laylagen.jar"
ALL_APPS=(gbloink timeslider kdiagram tileland zewp goldenpond)

APP="all"
TARGET="all"
CHECK=()
positional=()
for arg in "$@"; do
    if [[ "$arg" == "--check" ]]; then CHECK=(--check); else positional+=("$arg"); fi
done
[[ ${#positional[@]} -ge 1 ]] && APP="${positional[0]}"
[[ ${#positional[@]} -ge 2 ]] && TARGET="${positional[1]}"

if [[ ! -f "$JAR" ]]; then
    echo "Missing bundled generator JAR: $JAR" >&2
    echo "Restore it from git (it is committed under vendor/layla)." >&2
    exit 1
fi

if [[ "$APP" == "all" ]]; then apps=("${ALL_APPS[@]}"); else apps=("$APP"); fi
if [[ "$TARGET" == "all" ]]; then targets=(openfl juce rack); else targets=("$TARGET"); fi

generator() {
    local main="$1"; shift
    java -cp "$JAR" clojure.main -m "$main" "$@"
}

for app in "${apps[@]}"; do
    app_dir="$ROOT/apps/$app"
    migrated=false
    [[ -f "$app_dir/app.edn" ]] && migrated=true
    for target in "${targets[@]}"; do
        # Each target has its own tree; its builds see only that tree.
        HAXE_OUT="$ROOT/generated/$target/haxe"
        NATIVE="$ROOT/generated/$target/native"
        if [[ ${#CHECK[@]} -eq 0 ]]; then
            # Start this app's part of the tree afresh, so files a target no longer generates do not linger.
            rm -rf "$HAXE_OUT/generated/$app" "$NATIVE/worldofcake/generated/$app" \
                   "$NATIVE/worldofcake/generated/juce/$app" "$NATIVE/worldofcake/generated/rack/$app"
        fi

        # The app's code: control IDs, metadata and model data, plus layout constants and composition
        # for targets this generator draws (Rack's rack.edn says :generate-views false). Apps not yet
        # migrated use their canonical OpenFL pair for every target.
        if $migrated; then
            core_from=(--app "$app_dir" --target "$target")
        else
            core_from=(--input "$ROOT/layouts/openfl/$app.layla" --config "$ROOT/layouts/openfl/$app.edn")
        fi
        generator worldofcake.laylagen.main "${core_from[@]}" --output "$HAXE_OUT" --native-output "$NATIVE" "${CHECK[@]}"

        if [[ "$target" == "rack" ]]; then
            module_dir="$ROOT/derivatives/vcvrack/$app"
            if $migrated; then
                from=(--app "$app_dir" --target rack)
                layout_from=("${from[@]}")
            else
                rack_edn="$ROOT/layouts/rack/$app.edn"
                [[ -f "$rack_edn" ]] || continue
                from=(--metadata "$rack_edn")
                layout_from=(--input "$ROOT/layouts/rack/$app.layla" --config "$rack_edn")
            fi
            generator worldofcake.laylagen.rack-metadata-generate "${from[@]}" --output "$NATIVE" "${CHECK[@]}"
            generator worldofcake.laylagen.rack-layout-generate "${layout_from[@]}" \
                --output "$module_dir" --native-output "$NATIVE" "${CHECK[@]}"
            if [[ ${#CHECK[@]} -gt 0 ]]; then
                generator worldofcake.laylagen.rack-metadata-check "${from[@]}" \
                    --module-dir "$module_dir" --generated-root "$NATIVE"
            fi
        fi
    done
done
