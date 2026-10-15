#!/usr/bin/env bash
# Everything behind the article's tables, in one run (about two hours):
#
#   scripts/campaign.sh RESULTS_DIR [RUXEN_BIN RUXEN_BENCH_DIR]
#
# 1. Each variant against monoio io_uring, keep-alive and a new connection
#    per request, plus the control against itself (the noise floor).
# 2. With a ruxen binary and its bench/ directory: ruxen's epoll driver
#    against its io_uring driver on five of its bench scenarios.
# 3. Per-request instructions and system calls, three times each.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
OUT="${1:?usage: campaign.sh RESULTS_DIR [RUXEN_BIN RUXEN_BENCH_DIR]}"
RUXEN="${2:-}" RUXEN_BENCH="${3:-}"
mkdir -p "$OUT"

CONTROL=monoio:uring
VARIANTS=(monoio:uring compio:uring tokio tokio-mt tokio-uring monoio:legacy compio:poll)

for ka in 1 0; do
    for v in "${VARIANTS[@]}"; do
        echo "=== keepalive=$ka $v vs $CONTROL"
        KEEPALIVE=$ka scripts/abba.sh "$CONTROL" "$v"
    done
done 2>&1 | tee "$OUT/variants.txt"

if [[ -n "$RUXEN" ]]; then
    while read -r name dir url ka; do
        echo "=== ruxen $name"
        CONF_DIR="$RUXEN_BENCH/$dir" URL="$url" KEEPALIVE="$ka" \
            scripts/abba.sh "ruxen=$RUXEN:io_uring" "ruxen=$RUXEN:epoll"
    done <<EOF 2>&1 | tee "$OUT/ruxen.txt"
m1_hello m1 http://127.0.0.1:8080/ 1
m1_no_keepalive m1_no_keepalive http://127.0.0.1:8081/ 0
proxy_hello proxy_pass http://127.0.0.1:8095/ 1
m3_static_1k m3 http://127.0.0.1:8090/hello.txt 1
tls_hello tls https://127.0.0.1:8443/ 1
EOF
fi

per=("${VARIANTS[@]:1}" "$CONTROL")
[[ -n "$RUXEN" ]] && per+=("ruxen=$RUXEN:io_uring" "ruxen=$RUXEN:epoll")
for round in 1 2 3; do
    for v in "${per[@]}"; do
        scripts/per_request.sh "$v"
    done
done 2>&1 | tee "$OUT/per_request.txt"
