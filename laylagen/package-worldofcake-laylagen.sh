#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${LAYLA_ROOT:?Set LAYLA_ROOT to the Layla language source checkout}"
OUTPUT="${1:-$ROOT/vendor/layla/worldofcake-laylagen.jar}"

for required in \
    "$LAYLA_ROOT/src/layla/core.cljc" \
    "$ROOT/laylagen/src/worldofcake/laylagen/main.clj" \
    "$ROOT/laylagen/src/worldofcake/laylagen/core.clj"; do
    if [[ ! -f "$required" ]]; then
        echo "Missing required source: $required" >&2
        exit 1
    fi
done

MAVEN_ROOT="${MAVEN_ROOT:-$HOME/.m2/repository}"
JARS=(
    "$MAVEN_ROOT/org/clojure/clojure/1.11.1/clojure-1.11.1.jar"
    "$MAVEN_ROOT/org/clojure/spec.alpha/0.3.218/spec.alpha-0.3.218.jar"
    "$MAVEN_ROOT/org/clojure/core.specs.alpha/0.2.62/core.specs.alpha-0.2.62.jar"
    "$MAVEN_ROOT/instaparse/instaparse/1.5.0/instaparse-1.5.0.jar"
)

for jar in "${JARS[@]}"; do
    if [[ ! -f "$jar" ]]; then
        echo "Missing dependency JAR: $jar" >&2
        echo "Run the Layla/WorldOfCake Clojure dependency setup first." >&2
        exit 1
    fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/classes" "$WORK/classes/layla" "$WORK/classes/worldofcake/laylagen"
cp -a "$LAYLA_ROOT/src/layla/." "$WORK/classes/layla/"
cp -a "$ROOT/laylagen/src/worldofcake/laylagen/." "$WORK/classes/worldofcake/laylagen/"
javac --release 11 -d "$WORK/classes" "$ROOT/laylagen/WorldOfCakeLaylagenMain.java"

# Flatten the JVM dependencies into one executable JAR. The last dependency
# wins for duplicate metadata files; these libraries do not require services
# that need to be merged for the offline generator.
for jar in "${JARS[@]}"; do
    (cd "$WORK/classes" && jar xf "$jar")
done

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT"
jar cfe "$OUTPUT" WorldOfCakeLaylagenMain -C "$WORK/classes" .

echo "Created $OUTPUT"
echo "Layla source: $LAYLA_ROOT"
echo "SHA-256:"
sha256sum "$OUTPUT"
