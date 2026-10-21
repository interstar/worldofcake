#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOHELP'
Usage:
  collect_rack_postmortem.sh

Collects post-crash evidence for a recent Rack failure into a timestamped
directory under derivatives/vcvrack/postmortem/.

Captured data may include:
  - Rack log.txt from the standard Linux user directory
  - latest diagnostics summary if one exists
  - coredumpctl list/info for recent Rack crashes
  - a non-interactive gdb backtrace from the newest Rack core, if available

Environment overrides:
  RACK_USER_DIR   Rack user directory root
  OUT_DIR         Output directory root
EOHELP
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_ROOT="${OUT_DIR:-$SCRIPT_DIR/postmortem}"
RACK_USER_DIR="${RACK_USER_DIR:-$HOME/.local/share/Rack2}"
STAMP="$(date '+%Y%m%d_%H%M%S')"
RUN_DIR="$OUT_ROOT/$STAMP"
mkdir -p "$RUN_DIR"

SUMMARY_FILE="$RUN_DIR/summary.txt"
{
	echo "collect_rack_postmortem.sh"
	echo "started_at=$(date '+%F %T %Z')"
	echo "hostname=$(hostname)"
	echo "cwd=$(pwd)"
	echo "rack_user_dir=$RACK_USER_DIR"
} >"$SUMMARY_FILE"

if [[ -f "$RACK_USER_DIR/log.txt" ]]; then
	cp "$RACK_USER_DIR/log.txt" "$RUN_DIR/rack_log.txt"
	echo "copied_rack_log=$RUN_DIR/rack_log.txt" >>"$SUMMARY_FILE"
fi

LATEST_DIAG="$(ls -1dt "$SCRIPT_DIR"/diagnostics/* 2>/dev/null | head -n 1 || true)"
if [[ -n "$LATEST_DIAG" && -d "$LATEST_DIAG" ]]; then
	echo "latest_diagnostics=$LATEST_DIAG" >>"$SUMMARY_FILE"
	cp "$LATEST_DIAG/summary.txt" "$RUN_DIR/latest_diagnostics_summary.txt" 2>/dev/null || true
fi

if command -v coredumpctl >/dev/null 2>&1; then
	coredumpctl list Rack >"$RUN_DIR/coredumpctl_list.txt" 2>&1 || true
	coredumpctl info Rack >"$RUN_DIR/coredumpctl_info.txt" 2>&1 || true

	if grep -q '^Storage:' "$RUN_DIR/coredumpctl_info.txt"; then
		coredumpctl gdb Rack \
			--batch \
			-ex 'set pagination off' \
			-ex 'thread apply all bt' \
			>"$RUN_DIR/coredump_gdb_bt.txt" 2>&1 || true
	fi
fi

{
	echo "ended_at=$(date '+%F %T %Z')"
	echo "status=complete"
} >>"$SUMMARY_FILE"

echo "Postmortem saved in $RUN_DIR"
