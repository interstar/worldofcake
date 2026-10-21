#!/usr/bin/env bash
# Build every VCV Rack module under derivatives/vcvrack/ (Linux).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MODULES=(gbloink timeslider kdiagram tileland zewp)
GOLDENPOND_ROOT="${GOLDENPOND_ROOT:-$ROOT/../../../goldenpond/goldenpond}"
if [[ -d "$GOLDENPOND_ROOT/current/haxe/src/goldenpond" ]]; then
	MODULES+=(goldenpond)
else
	echo "Goldenpond source not found at $GOLDENPOND_ROOT; skipping Rack Goldenpond module."
fi
for name in "${MODULES[@]}"; do
	echo "=== $name ==="
	"$ROOT/build_module.sh" "$name" "$@"
done
