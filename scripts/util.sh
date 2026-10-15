#!/usr/bin/env bash
# Is the server the limit, not wrk? CPU use of the server's and the
# client's cores during one measured wrk run, from /proc/stat.
#
#   scripts/util.sh VARIANT
#
# Prints throughput and the average busy share (user + system + irq +
# softirq) of SERVER_CPUS and of CLIENT_CPUS. The server should be near
# 100% and wrk clearly below it; otherwise the run measures wrk.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[[ $# -eq 1 ]] || die "usage: util.sh VARIANT"
V="$1"

work="$(mktemp -d -t util-XXXXXX)"
trap 'rm -rf "$work"' EXIT
write_conf "$work"
pid="$(start_server "$V" "$work")"
run_wrk 5s "$work/warm"
grep '^cpu[0-9]' /proc/stat >"$work/before"
run_wrk 10s "$work/run.wrk"
grep '^cpu[0-9]' /proc/stat >"$work/after"
stop_server "$pid"

python3 - "$V" "$SERVER_CPUS" "$CLIENT_CPUS" "$work/before" "$work/after" \
    "$(wrk_stats "$work/run.wrk")" <<'PY'
import sys
v, scpus, ccpus, fb, fa, stats = sys.argv[1:]

def cpus(spec):
    out = set()
    for part in spec.split(','):
        if '-' in part:
            a, b = part.split('-')
            out.update(range(int(a), int(b) + 1))
        else:
            out.add(int(part))
    return out

def read(f):
    d = {}
    for line in open(f):
        p = line.split()
        n = [int(x) for x in p[1:]]
        # user nice system idle iowait irq softirq steal
        busy = n[0] + n[1] + n[2] + n[5] + n[6] + n[7]
        d[int(p[0][3:])] = (busy, busy + n[3] + n[4])
    return d

b, a = read(fb), read(fa)

def share(cs):
    s = [(a[c][0] - b[c][0]) / max(1, a[c][1] - b[c][1]) for c in sorted(cs) if c in a]
    return 100 * sum(s) / len(s), 100 * min(s), 100 * max(s)

rps, p50, p99, err, n = stats.split()
srv, cli = cpus(scpus), cpus(ccpus)
s, c = share(srv), share(cli - srv)
print(f"{v} rps {float(rps):.0f} p50us {p50} p99us {p99}  server cpus {scpus}: "
      f"{s[0]:.0f}% (min {s[1]:.0f}, max {s[2]:.0f})  client cpus {ccpus}: "
      f"{c[0]:.0f}% (min {c[1]:.0f}, max {c[2]:.0f})")
PY
