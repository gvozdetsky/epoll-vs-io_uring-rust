#!/usr/bin/env bash
# The overnight measurement plan for the article, one machine at a time:
#
#   scripts/night.sh i9|i7 RESULTS_DIR HOURS
#
# Phases run in priority order; once HOURS have passed, the remaining ones
# are skipped (logged as such), so the run ends on time. Every phase writes
# RESULTS_DIR/<nn>-<name>.txt, and night.log has the start and end of each.
# A failed comparison is logged and the next one runs.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
MACHINE="${1:?usage: night.sh i9|i7 RESULTS_DIR HOURS}"
OUT="${2:?}"
HOURS="${3:?}"
mkdir -p "$OUT"
LOG="$OUT/night.log"
START=$(date +%s)
DEADLINE=$((START + ${HOURS%.*} * 3600))
NGINX="${NGINX:-/usr/sbin/nginx}"
RUXEN="${RUXEN:-$PWD/bin/ruxen-a205d4b2}"
CONTROL=monoio:uring
VARIANTS=(monoio:uring compio:uring tokio tokio-mt tokio-uring monoio:legacy compio:poll "nginx=$NGINX")
SEQ=0

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

# phase NAME FUNCTION [ARGS...]: run it unless the deadline has passed.
phase() {
    local name="$1"; shift
    SEQ=$((SEQ + 1))
    local file
    file="$OUT/$(printf '%02d' "$SEQ")-$name.txt"
    if (( $(date +%s) >= DEADLINE )); then
        log "SKIP $name (deadline)"
        return
    fi
    log "START $name"
    {
        echo "# $name on $MACHINE, $(date '+%F %T')"
        echo "# WORKERS=$WORKERS SERVER_CPUS=$SERVER_CPUS CLIENT_CPUS=$CLIENT_CPUS WRK_THREADS=$WRK_THREADS WRK_CONNS=${WRK_CONNS:-512}"
        "$@"
    } >"$file" 2>&1
    log "END $name"
}

# layout NAME: the server's and the client's cores on this machine.
layout() {
    case "$MACHINE:$1" in
        # i7-9750H: CPUs 0-5 are the six cores, 6-11 their SMT siblings.
        # L3 leaves wrk too few cores (it saturates them first); kept
        # only to show that. L2 and L1 are server-limited.
        i7:L3) export WORKERS=3 SERVER_CPUS=0,1,2 CLIENT_CPUS=3,4,5,9,10,11 WRK_THREADS=6 ;;
        i7:L2) export WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 ;;
        i7:L1) export WORKERS=1 SERVER_CPUS=0 CLIENT_CPUS=1,2,3,4,5,7,8,9,10,11 WRK_THREADS=10 ;;
        # The draft's original method: 12 workers, nothing pinned apart.
        i7:ALL) export WORKERS=12 SERVER_CPUS=0-11 CLIENT_CPUS=0-11 WRK_THREADS=16 ;;
        # i9-13900HX: CPUs 0-15 are 8 P-cores x 2 threads, 16-31 E-cores.
        i9:W1) export WORKERS=1 SERVER_CPUS=0 CLIENT_CPUS=8-31 WRK_THREADS=16 ;;
        i9:W2) export WORKERS=2 SERVER_CPUS=0,2 CLIENT_CPUS=8-31 WRK_THREADS=16 ;;
        i9:W4) export WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 ;;
        i9:W8) export WORKERS=8 SERVER_CPUS=0,2,4,6,8,10,12,14 CLIENT_CPUS=16-31 WRK_THREADS=16 ;;
        *) echo "no layout $1 on $MACHINE" >&2; return 1 ;;
    esac
    export WRK_CONNS=512 KEEPALIVE=1
}

info() {
    echo "## host"; uname -a; grep PRETTY /etc/os-release; lscpu
    echo "## governor"; cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort | uniq -c
    echo "## mitigations"; grep -r . /sys/devices/system/cpu/vulnerabilities/ 2>/dev/null
    echo "## kernel command line"; cat /proc/cmdline
    echo "## io_uring sysctl"; cat /proc/sys/kernel/io_uring_disabled 2>/dev/null
    echo "## perf_event_paranoid"; cat /proc/sys/kernel/perf_event_paranoid
    echo "## kptr_restrict"; cat /proc/sys/kernel/kptr_restrict
    echo "## tools"; wrk -v 2>&1 | head -1; $NGINX -v 2>&1; "$RUXEN" -V 2>&1 | sed -n 2p
    echo "## crates (Cargo.lock)"
    awk '/^name = /{n=$3} /^version = /{ if (n ~ /"(monoio|compio|compio-driver|tokio|tokio-uring|mio|polling|io-uring)"/) print n, $3 }' Cargo.lock
    echo "## memory"; free -m
}

# variants KA: every variant against the control (the control against
# itself is the noise floor).
variants() {
    local v
    for v in "${VARIANTS[@]}"; do
        echo "=== keepalive=$1 $v vs $CONTROL"
        KEEPALIVE=$1 scripts/abba.sh "$CONTROL" "$v" || echo "FAILED $v"
    done
}

# some KA VARIANT...: a subset against the control.
some() {
    local ka="$1" v; shift
    for v in "$@"; do
        echo "=== keepalive=$ka $v vs $CONTROL"
        KEEPALIVE=$ka scripts/abba.sh "$CONTROL" "$v" || echo "FAILED $v"
    done
}

util_all() {
    local ka v
    for ka in "$@"; do
        for v in "${VARIANTS[@]}" "ruxen=$RUXEN:io_uring" "ruxen=$RUXEN:epoll"; do
            KEEPALIVE=$ka scripts/util.sh "$v" | sed "s/^/keepalive=$ka /" || echo "FAILED $v"
        done
    done
}

# ruxen's five scenarios: A vs B for each (A, B: io_uring, epoll or nginx).
RUXEN_SCENARIOS=(
    "m1_hello m1 http://127.0.0.1:8080/ 1"
    "m1_no_keepalive m1_no_keepalive http://127.0.0.1:8081/ 0"
    "proxy_hello proxy_pass http://127.0.0.1:8095/ 1"
    "m3_static_1k m3 http://127.0.0.1:8090/hello.txt 1"
    "tls_hello tls https://127.0.0.1:8443/ 1"
)
ruxen_pair() {
    local a="$1" b="$2" s name dir url ka
    for s in "${RUXEN_SCENARIOS[@]}"; do
        read -r name dir url ka <<<"$s"
        echo "=== ruxen $name: $b vs $a"
        CONF_DIR="$PWD/ruxen-configs/$dir" URL="$url" KEEPALIVE="$ka" \
            scripts/abba.sh "$a" "$b" || echo "FAILED $name"
    done
}
var() {
    case "$1" in
        io_uring|epoll) echo "ruxen=$RUXEN:$1" ;;
        nginx) echo "nginx=$NGINX" ;;
    esac
}

per_request_all() {
    local rounds="$1" ka="$2" r v
    for ((r = 1; r <= rounds; r++)); do
        for v in "${VARIANTS[@]}" "ruxen=$RUXEN:io_uring" "ruxen=$RUXEN:epoll"; do
            KEEPALIVE=$ka scripts/per_request.sh "$v" | sed "s/^/round=$r keepalive=$ka /" \
                || echo "FAILED $v"
        done
    done
}

profiles() {
    local v
    for v in "${VARIANTS[@]}" "ruxen=$RUXEN:io_uring" "ruxen=$RUXEN:epoll"; do
        scripts/profile.sh "$v" || echo "FAILED $v"
    done
}

conns() {
    local c
    for c in "$@"; do
        echo "### WRK_CONNS=$c"
        WRK_CONNS=$c some 1 tokio monoio:legacy compio:uring "nginx=$NGINX"
    done
}

log "night.sh $MACHINE, until $(date -d @"$DEADLINE" '+%F %T')"
bash scripts/../ruxen-configs/tls/generate.sh >/dev/null 2>&1 || log "tls cert generation failed"

case "$MACHINE" in
i7)
    layout L2
    phase info info
    phase util-L2 util_all 1 0
    layout L3; phase util-L3 util_all 1
    layout L1; phase util-L1 util_all 1
    layout ALL; phase util-ALL util_all 1
    layout L2
    phase variants-L2-keepalive variants 1
    phase variants-L2-new-connection variants 0
    phase ruxen-L2-epoll-vs-io_uring ruxen_pair "$(var io_uring)" "$(var epoll)"
    phase per-request-L2-keepalive per_request_all 3 1
    phase per-request-L2-new-connection per_request_all 1 0
    layout ALL
    phase variants-ALL-keepalive variants 1
    phase variants-ALL-new-connection variants 0
    phase ruxen-ALL-epoll-vs-io_uring ruxen_pair "$(var io_uring)" "$(var epoll)"
    layout L2
    phase ruxen-L2-io_uring-vs-nginx ruxen_pair "$(var nginx)" "$(var io_uring)"
    phase ruxen-L2-epoll-vs-nginx ruxen_pair "$(var nginx)" "$(var epoll)"
    layout L1; phase variants-L1-keepalive variants 1
    layout L2
    phase connections-L2 conns 64 2048
    phase variants-L2-keepalive-repeat variants 1
    phase ruxen-L2-epoll-vs-io_uring-repeat ruxen_pair "$(var io_uring)" "$(var epoll)"
    phase variants-L2-new-connection-repeat variants 0
    ;;
i9)
    layout W4
    phase info info
    phase util-W4 util_all 1 0
    layout W8; phase util-W8 util_all 1
    layout W4
    phase variants-W4-keepalive variants 1
    phase variants-W4-new-connection variants 0
    phase ruxen-W4-epoll-vs-io_uring ruxen_pair "$(var io_uring)" "$(var epoll)"
    phase per-request-W4-keepalive per_request_all 3 1
    phase per-request-W4-new-connection per_request_all 1 0
    phase profiles-W4-keepalive profiles
    phase ruxen-W4-io_uring-vs-nginx ruxen_pair "$(var nginx)" "$(var io_uring)"
    phase ruxen-W4-epoll-vs-nginx ruxen_pair "$(var nginx)" "$(var epoll)"
    for w in W1 W2 W8; do
        layout $w
        phase "scaling-$w-keepalive" some 1 tokio monoio:legacy compio:uring "nginx=$NGINX"
    done
    layout W4
    phase connections-W4 conns 64 2048
    phase variants-W4-keepalive-repeat variants 1
    phase ruxen-W4-epoll-vs-io_uring-repeat ruxen_pair "$(var io_uring)" "$(var epoll)"
    phase variants-W4-new-connection-repeat variants 0
    ;;
*) echo "machine: i9 or i7" >&2; exit 1 ;;
esac
log "DONE"
