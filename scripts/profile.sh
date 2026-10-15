#!/usr/bin/env bash
# Where one variant spends its CPU under load: a 10 s `perf record` of
# the server's processes while wrk runs, reported flat by shared object
# (kernel vs the binary vs libc) and by symbol.
#
#   scripts/profile.sh VARIANT
#
# Needs perf with kernel.perf_event_paranoid <= 1 (kernel symbols also
# need a readable /proc/kallsyms; without it they show as addresses).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[[ $# -eq 1 ]] || die "usage: profile.sh VARIANT"
V="$1"

work="$(mktemp -d -t prof-XXXXXX)"
trap 'rm -rf "$work"' EXIT
write_conf "$work"
pid="$(start_server "$V" "$work")"
run_wrk 5s "$work/warm"
pids="$(printf '%s\n' "$pid" $(pgrep -P "$pid" || true) | paste -sd,)"
run_wrk 15s "$work/run.wrk" &
wrk_pid=$!
sleep 2
perf record -q -F 1999 -p "$pids" -o "$work/perf.data" -- sleep 10 2>"$work/rec.err" || {
    echo "== $V: perf record failed: $(head -c 200 "$work/rec.err")"
    wait "$wrk_pid"; stop_server "$pid"; exit 0
}
wait "$wrk_pid"
stop_server "$pid"
echo "== $V: $(wrk_stats "$work/run.wrk" | awk '{ print $1 }') req/s during the profile"
echo "-- by shared object"
perf report -i "$work/perf.data" --stdio --no-children --sort dso --percent-limit 0.5 2>/dev/null \
    | grep -v '^#' | grep -v '^$' | head -15
echo "-- by symbol (top 40)"
perf report -i "$work/perf.data" --stdio --no-children --sort dso,sym --percent-limit 0.4 2>/dev/null \
    | grep -v '^#' | grep -v '^$' | head -40
