#!/usr/bin/env bash
# Cost per request of one variant: instructions (user and kernel) from
# `perf stat`, and system calls from `strace -c`, each divided by the
# requests wrk completed in the same window.
#
#   scripts/per_request.sh VARIANT
#
# perf stat barely disturbs the server; strace slows it down a lot, so it
# gets a second server started under it, and only the per-request counts
# are kept (the startup's few hundred calls are noise against them).
# Needs kernel.perf_event_paranoid <= 1. On a hybrid CPU perf splits each
# event into cpu_core/... and cpu_atom/...; they are summed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[[ $# -eq 1 ]] || die "usage: per_request.sh VARIANT"
V="$1"

work="$(mktemp -d -t perreq-XXXXXX)"
trap 'rm -rf "$work"' EXIT
write_conf "$work"
pid="$(start_server "$V" "$work")"
run_wrk 5s "$work/warm"

# perf: 10 s window, wrk alongside. All the server's processes (nginx's
# workers are children of its master). Skipped where perf isn't allowed
# (kernel.perf_event_paranoid > 1 for a user).
pids="$(printf '%s\n' "$pid" $(pgrep -P "$pid" || true) | paste -sd,)"
run_wrk 10s "$work/perf.wrk" &
wrk_pid=$!
perf_ok=1
perf stat -x, -e instructions:u,instructions:k,cycles,context-switches \
    -p "$pids" -- sleep 10 2>"$work/perf.csv" || perf_ok=0
wait "$wrk_pid"
reqs="$(wrk_stats "$work/perf.wrk" | awk '{ print $5 }')"
if (( perf_ok == 0 )); then
    echo "$V instr/req: perf unavailable ($(head -c 120 "$work/perf.csv" | tr '\n' ' '))"
else
awk -F, -v n="$reqs" -v v="$V" '
    $1 !~ /^[0-9]+$/ { next }
    $3 ~ /instructions\/u/ { iu += $1 } $3 ~ /instructions\/k/ { ik += $1 }
    $3 ~ /cycles/ { cy += $1 } $3 == "context-switches" { cs += $1 }
    END { printf "%s instr/req user %.0f kernel %.0f total %.0f  cycles/req %.0f  ctxsw/req %.3f\n",
          v, iu / n, ik / n, (iu + ik) / n, cy / n, cs / n }' "$work/perf.csv"
fi

stop_server "$pid"

# strace: a second server, started under it. No warm-up: every call it
# counts is either startup or one of the requests wrk counts.
pid="$(WRAP="strace -f -c -o $work/strace.txt" start_server "$V" "$work")"
run_wrk 5s "$work/strace.wrk"
server="$(pgrep -P "$pid")"
kill -TERM $server
# start_server ran in a subshell, so `wait` cannot reap strace: poll.
while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
reqs="$(wrk_stats "$work/strace.wrk" | awk '{ print $5 }')"
# strace -c columns: % time, seconds, usecs/call, calls, [errors,] syscall
awk -v n="$reqs" -v v="$V" '
    $1 ~ /^[0-9.]+$/ && $NF != "total" {
        c[$NF] = $4; tot += $4; if (NF == 6) e[$NF] = $5
    }
    END {
        printf "%s syscalls/req (%d requests):", v, n
        for (k in c) if (c[k] / n >= 0.005) {
            printf " %s %.3f", k, c[k] / n
            if (e[k] / n >= 0.005) printf " (%.3f failed)", e[k] / n
        }
        printf "  total %.3f\n", tot / n
    }' "$work/strace.txt"
