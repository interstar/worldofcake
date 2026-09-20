#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODULE="$ROOT/derivatives/vcvrack/goldenpond"
ARTIFACTS="$ROOT/build/vcvrack/goldenpond"
NATIVE="$ARTIFACTS/native"
HXCPP_ROOT="$(haxelib path hxcpp | sed -n '1p' | tr -d '\r')"

if [[ ! -d "$HXCPP_ROOT/include" ]]; then
    echo "hxcpp include directory not found: $HXCPP_ROOT/include" >&2
    exit 1
fi

make -C "$MODULE" codegen

mapfile -t HXCPP_OBJECTS < <(find "$NATIVE/obj/linux64" -maxdepth 1 -name '*.o' ! -name '*___main__.o' -type f | sort)
if [[ ${#HXCPP_OBJECTS[@]} -eq 0 ]]; then
    echo "No hxcpp objects found under $NATIVE/obj/linux64" >&2
    exit 1
fi

OUTPUT="$ARTIFACTS/goldenpond-rack-stress"
"${CXX:-g++}" -O3 -std=c++14 -pthread \
    -DHXCPP_VISIT_ALLOCS -DHX_SMART_STRINGS -DHXCPP_API_LEVEL=430 \
    -I"$NATIVE/include" -I"$ROOT/bridge/native" -I"$HXCPP_ROOT/include" \
    "$ROOT/test/native/GoldenpondRackStress.cpp" \
    "$ROOT/bridge/native/GoldenpondControlRunner.cpp" \
    "$ROOT/bridge/native/ControlThread.cpp" \
    "${HXCPP_OBJECTS[@]}" -ldl -lm -o "$OUTPUT"

exec "$OUTPUT" "${1:-600}" "${2:-4}"
