#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOHELP'
Usage:
  collect_rack_diagnostics.sh [PID]

Behavior:
  - If PID is given, monitor that process.
  - Otherwise, monitor the newest process whose command name is "Rack".

Outputs:
  Creates a timestamped directory under derivatives/vcvrack/diagnostics/
  containing:
    - summary.txt
    - ps.log
    - proc_status.log
    - smaps_rollup.log (if available)

Environment overrides:
  INTERVAL_SEC   Poll interval in seconds (default: 5)
  OUT_DIR        Output directory root
EOHELP
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

INTERVAL_SEC="${INTERVAL_SEC:-5}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_ROOT="${OUT_DIR:-$SCRIPT_DIR/diagnostics}"

resolve_pid() {
	if [[ $# -ge 1 ]]; then
		printf '%s\n' "$1"
		return 0
	fi

	local found
	found="$(pgrep -n Rack || true)"
	if [[ -z "$found" ]]; then
		echo "No Rack process found. Start Rack first, or pass a PID explicitly." >&2
		exit 1
	fi
	printf '%s\n' "$found"
}

process_state() {
	local pid="$1"
	if [[ ! -r "/proc/$pid/status" ]]; then
		return 1
	fi
	awk '/^State:/ {print $2}' "/proc/$pid/status"
}

process_alive() {
	local pid="$1"
	if ! kill -0 "$pid" 2>/dev/null; then
		return 1
	fi
	local st
	st="$(process_state "$pid" || true)"
	if [[ -z "$st" || "$st" == "Z" ]]; then
		return 1
	fi
	return 0
}

PID="$(resolve_pid "${1:-}")"

if ! [[ "$PID" =~ ^[0-9]+$ ]]; then
	echo "PID must be numeric: $PID" >&2
	exit 1
fi

if ! process_alive "$PID"; then
	echo "Process is not running: PID $PID" >&2
	exit 1
fi

STAMP="$(date '+%Y%m%d_%H%M%S')"
RUN_DIR="$OUT_ROOT/$STAMP"
mkdir -p "$RUN_DIR"

SUMMARY_FILE="$RUN_DIR/summary.txt"
PS_LOG="$RUN_DIR/ps.log"
PROC_LOG="$RUN_DIR/proc_status.log"
SMAPS_LOG="$RUN_DIR/smaps_rollup.log"

{
	echo "collect_rack_diagnostics.sh"
	echo "started_at=$(date '+%F %T %Z')"
	echo "pid=$PID"
	echo "interval_sec=$INTERVAL_SEC"
	echo "hostname=$(hostname)"
	echo "cwd=$(pwd)"
	echo "cmdline=$(tr '\0' ' ' </proc/$PID/cmdline 2>/dev/null || true)"
} >"$SUMMARY_FILE"

echo "Writing diagnostics to: $RUN_DIR"
echo "Monitoring Rack PID: $PID"

while process_alive "$PID"; do
	{
		echo "=== $(date '+%F %T %Z') ==="
		ps -o pid=,ppid=,etime=,%cpu=,%mem=,rss=,vsz=,nlwp=,stat=,cmd= -p "$PID"
		echo
	} >>"$PS_LOG"

	{
		echo "=== $(date '+%F %T %Z') ==="
		grep -E '^(Name|State|Pid|PPid|Threads|VmPeak|VmSize|VmHWM|VmRSS|RssAnon|RssFile|RssShmem|VmData|VmStk|VmExe|VmLib|VmPTE|VmSwap):' "/proc/$PID/status" || true
		echo
	} >>"$PROC_LOG"

	if [[ -r "/proc/$PID/smaps_rollup" ]]; then
		{
			echo "=== $(date '+%F %T %Z') ==="
			cat "/proc/$PID/smaps_rollup"
			echo
		} >>"$SMAPS_LOG"
	fi

	sleep "$INTERVAL_SEC"
done

{
	echo "ended_at=$(date '+%F %T %Z')"
	echo "status=process_exited_or_zombie"
	if [[ -r "/proc/$PID/status" ]]; then
		echo "final_state=$(process_state "$PID" || true)"
	fi
} >>"$SUMMARY_FILE"

echo "Rack process $PID exited. Logs saved in $RUN_DIR"
