#!/usr/bin/env bash
# Interleaved ("ABBA") comparison of two server variants.
#
#   scripts/abba.sh [--pairs N] [--duration D] [--warmup D] A B
#
# Runs A B, B A, A B, ... and prints every pair, then the geometric mean
# of the per-pair B/A throughput ratios with their min-max, and the median
# p50 / p99 latency of each side. Alternating the order exposes both sides
# to the same drift (CPU boost, thermals); an even number of pairs cancels
# the small "second run of a pair" effect. Before the pairs, one longer
# throwaway run of A: a CPU coming out of idle boosts for tens of seconds.
#
# Environment: see lib.sh (WORKERS, SERVER_CPUS, CLIENT_CPUS, KEEPALIVE,
# WRK_THREADS, WRK_CONNS, PORT). KEEPALIVE=0 makes every request a new
# connection. Each run is a warm-up wrk (not counted), then the measured one.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PAIRS=8 DURATION=10s WARMUP=5s THROWAWAY=20s COOLDOWN=3
while [[ $# -gt 2 ]]; do
    case "$1" in
        --pairs) PAIRS="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --warmup) WARMUP="$2"; shift 2 ;;
        *) die "unknown option $1" ;;
    esac
done
[[ $# -eq 2 ]] || die "usage: abba.sh [options] A B"
A="$1" B="$2"

work="$(mktemp -d -t abba-XXXXXX)"
trap 'rm -rf "$work"' EXIT
write_conf "$work"

# run VARIANT TAG [DURATION] -> "rps p50 p99 errors requests"
run() {
    local pid
    pid="$(start_server "$1" "$work")"
    run_wrk "$WARMUP" "$work/$2.warm"
    run_wrk "${3:-$DURATION}" "$work/$2.wrk"
    stop_server "$pid"
    wrk_stats "$work/$2.wrk"
}

echo "# A=$A B=$B url=$URL conf=${CONF_DIR:-generated} pairs=$PAIRS duration=$DURATION keepalive=$KEEPALIVE workers=$WORKERS server_cpus=$SERVER_CPUS client_cpus=$CLIENT_CPUS wrk=-t$WRK_THREADS/-c$WRK_CONNS"
run "$A" throwaway "$THROWAWAY" >/dev/null
sleep "$COOLDOWN"

errors=0
for ((i = 0; i < PAIRS; i++)); do
    if (( i % 2 == 0 )); then
        a=($(run "$A" "a$i")); sleep "$COOLDOWN"; b=($(run "$B" "b$i"))
    else
        b=($(run "$B" "b$i")); sleep "$COOLDOWN"; a=($(run "$A" "a$i"))
    fi
    sleep "$COOLDOWN"
    errors=$((errors + a[3] + b[3]))
    printf 'pair %d A %s p50 %s p99 %s | B %s p50 %s p99 %s | B/A %s%%\n' "$i" \
        "${a[0]}" "${a[1]}" "${a[2]}" "${b[0]}" "${b[1]}" "${b[2]}" \
        "$(awk -v a="${a[0]}" -v b="${b[0]}" 'BEGIN { printf "%.2f", b / a * 100 }')" \
        | tee -a "$work/pairs"
done

awk -v A="$A" -v B="$B" '
    function median(x, n,   i, j, t) {
        for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++)
            if (x[j] < x[i]) { t = x[i]; x[i] = x[j]; x[j] = t }
        return (n % 2) ? x[(n + 1) / 2] : (x[n / 2] + x[n / 2 + 1]) / 2
    }
    {
        n++; r = $NF; sub("%", "", r); r += 0
        lsum += log(r); if (n == 1 || r < lo) lo = r; if (n == 1 || r > hi) hi = r
        ap50[n] = $6; ap99[n] = $8; bp50[n] = $13; bp99[n] = $15
    }
    END {
        printf "RESULT %s / %s: %.1f%% (min %.1f, max %.1f; %d pairs)", B, A, exp(lsum / n), lo, hi, n
        printf "  p50 us A %d B %d", median(ap50, n), median(bp50, n)
        printf "  p99 us A %d B %d\n", median(ap99, n), median(bp99, n)
    }' "$work/pairs"
(( errors == 0 )) || { echo "ERROR: $errors error responses / timeouts" >&2; exit 1; }
