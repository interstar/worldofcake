#!/usr/bin/env bash
# Build a VCV Rack plugin: derivatives/vcvrack/<name>/ (Linux).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:?Usage: $0 <module-dir> [make-args...]}"
shift || true
DIR="$ROOT/$NAME"
if [[ ! -d "$DIR" ]]; then
	echo "No directory: $DIR" >&2
	exit 1
fi
cd "$DIR"
exec make "$@"
