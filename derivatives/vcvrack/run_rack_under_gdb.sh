#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOHELP'
Usage:
  run_rack_under_gdb.sh /path/to/Rack/dir

Example:
  run_rack_under_gdb.sh ~/Downloads/Rack2Free

Behavior:
  - changes into the given Rack directory
  - launches ./Rack under gdb
  - follows the main Rack process (not helper forks)
  - suppresses noisy non-fatal signals commonly seen in GUI/audio apps
  - auto-runs immediately

When gdb stops on a real fault, run:
  thread apply all bt
  thread apply all bt full

Useful extra commands:
  info inferiors
  info threads
EOHELP
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -ne 1 ]]; then
	usage
	exit $([[ $# -eq 1 ]] && echo 0 || echo 1)
fi

RACK_DIR="$1"
if [[ ! -d "$RACK_DIR" ]]; then
	echo "No such directory: $RACK_DIR" >&2
	exit 1
fi

if [[ ! -x "$RACK_DIR/Rack" ]]; then
	echo "Expected executable not found: $RACK_DIR/Rack" >&2
	exit 1
fi

cd "$RACK_DIR"

exec gdb \
	-ex 'set pagination off' \
	-ex 'set confirm off' \
	-ex 'set print thread-events off' \
	-ex 'set follow-fork-mode parent' \
	-ex 'set detach-on-fork on' \
	-ex 'handle SIGPIPE nostop noprint pass' \
	-ex 'handle SIGALRM nostop noprint pass' \
	-ex 'handle SIGUSR1 nostop noprint pass' \
	-ex 'handle SIGUSR2 nostop noprint pass' \
	-ex 'echo \nRack gdb session ready.\n' \
	-ex 'echo If gdb stops on a fault, run:\n' \
	-ex 'echo   thread apply all bt\n' \
	-ex 'echo   thread apply all bt full\n\n' \
	-ex 'run' \
	--args ./Rack
