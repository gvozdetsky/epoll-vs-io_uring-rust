#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
out="$(realpath -m "${1:?usage: network.sh OUTPUT_DIR [VARIANT ...]}")"
shift
mkdir -p "$out"
control="$(mktemp -d -t netbench-ssh-XXXXXX)"
export SSH_CONTROL_PATH="$control/%C"
cleanup() {
    for host in "$SERVER_HOST" "$CLIENT_HOST"; do
        [[ -z "$host" ]] || ssh -S "$SSH_CONTROL_PATH" -O exit "$host" 2>/dev/null || true
    done
    rm -rf -- "$control"
}
trap cleanup EXIT
export NET_STATS=1
: "${SERVER_IFACE:?set SERVER_IFACE}"
: "${CLIENT_IFACE:?set CLIENT_IFACE}"
: "${CLIENT_URL:?set CLIENT_URL to the server Ethernet address}"
variants=("$@")
if (( ${#variants[@]} == 0 )); then
    variants=(monoio:uring tokio monoio:legacy compio:uring tokio-mt tokio-uring compio:poll)
fi
for role in server client; do
    if [[ "$role" == server ]]; then
        host="$SERVER_HOST"; interface="$SERVER_IFACE"; root="$SERVER_ROOT"
    else
        host="$CLIENT_HOST"; interface="$CLIENT_IFACE"; root="$CLIENT_ROOT"
    fi
    on_host "$host" bash -c '
        date -Is
        uname -a
        ip -br address
        ip route
        cat "/sys/class/net/$1/speed" "/sys/class/net/$1/duplex" "/sys/class/net/$1/mtu"
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | sort | uniq -c
        sha256sum "$2"/target/release/spike-* 2>/dev/null
        if command -v ethtool >/dev/null; then ethtool -k "$1"; fi
    ' bash "$interface" "$root" >"$out/$role-info.txt" 2>&1
done
index=0
for variant in "${variants[@]}"; do
    index=$((index + 1))
    name="$(printf '%02d' "$index")-${variant//[^a-zA-Z0-9_-]/_}"
    printf '[%s] START %s\n' "$(date -Is)" "$variant" | tee -a "$out/campaign.log"
    OUTPUT_DIR="$out/$name-raw" bash "$ROOT/scripts/abba.sh" \
        --pairs "${PAIRS:-8}" --duration "${DURATION:-10s}" --warmup "${WARMUP:-5s}" \
        "${CONTROL:-monoio:uring}" "$variant" >"$out/$name.txt" 2>&1
    tail -n 1 "$out/$name.txt" | tee -a "$out/campaign.log"
done
printf '[%s] DONE\n' "$(date -Is)" | tee -a "$out/campaign.log"
