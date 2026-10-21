#!/usr/bin/env bash
# Build, install, and refresh local Linux VCV Rack plugin folders for World of Cake.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${WOC_RACK_PLUGIN_DIR:-$HOME/.local/share/Rack2/plugins-lin-x64}"

MODULES=(gbloink timeslider kdiagram tileland zewp)
PLUGIN_NAMES=(
  WorldOfCake-Gbloink
  WorldOfCake-TimeSlider
  WorldOfCake-KDiagram
  WorldOfCake-TileLand
  WorldOfCake-Zewp
)
PLUGIN_PACKAGES=(
  WorldOfCake-Gbloink-2.0.1-lin-x64.vcvplugin
  WorldOfCake-TimeSlider-2.0.0-lin-x64.vcvplugin
  WorldOfCake-KDiagram-2.0.0-lin-x64.vcvplugin
  WorldOfCake-TileLand-2.0.2-lin-x64.vcvplugin
  WorldOfCake-Zewp-2.0.0-lin-x64.vcvplugin
)
GOLDENPOND_ROOT="${GOLDENPOND_ROOT:-$ROOT/../../../goldenpond/goldenpond}"
if [[ -d "$GOLDENPOND_ROOT/current/haxe/src/goldenpond" ]]; then
  MODULES+=(goldenpond)
  PLUGIN_NAMES+=(WorldOfCake-Goldenpond)
  PLUGIN_PACKAGES+=(WorldOfCake-Goldenpond-2.0.0-lin-x64.vcvplugin)
else
  echo "Goldenpond source not found at $GOLDENPOND_ROOT; skipping Rack Goldenpond installation."
fi

if [[ ${#MODULES[@]} -ne ${#PLUGIN_NAMES[@]} || ${#MODULES[@]} -ne ${#PLUGIN_PACKAGES[@]} ]]; then
  echo "Module/package table length mismatch" >&2
  exit 1
fi

echo "Building and installing plugin archives into: $PLUGIN_DIR"
"$ROOT/build_all.sh" install

mkdir -p "$PLUGIN_DIR"

for plugin_name in "${PLUGIN_NAMES[@]}"; do
  echo "Removing extracted $plugin_name"
  rm -rf "$PLUGIN_DIR/$plugin_name"
done

for i in "${!MODULES[@]}"; do
  module="${MODULES[$i]}"
  package="${PLUGIN_PACKAGES[$i]}"
  archive="$PLUGIN_DIR/$package"
  if [[ ! -f "$archive" ]]; then
    echo "Missing installed package: $archive" >&2
    exit 1
  fi
  echo "Extracting $package"
  tar --zstd -xf "$archive" -C "$PLUGIN_DIR"
done

echo "Installed plugin binaries:"
for plugin_name in "${PLUGIN_NAMES[@]}"; do
  plugin_so="$PLUGIN_DIR/$plugin_name/plugin.so"
  if [[ ! -f "$plugin_so" ]]; then
    echo "Missing plugin binary: $plugin_so" >&2
    exit 1
  fi
  ls -lh "$plugin_so"
done
