# Shared by abba.sh and per_request.sh: starting and stopping one server
# variant, and running wrk against it.
#
# A variant is NAME or NAME:DRIVER, where NAME is a binary in
# target/release without the `spike-` prefix (monoio, compio, tokio,
# tokio-uring, tokio-mt) and DRIVER goes to SPIKE_DRIVER (uring, legacy,
# fusion, poll). `ruxen=PATH[:DRIVER]` runs a ruxen binary on the same
# config, DRIVER going to RUXEN_DRIVER (io_uring, epoll). `nginx=PATH` runs
# nginx on it.

export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-18080}"
WORKERS="${WORKERS:-4}"
# Server and client on separate cores, so that the server is the limit.
# Defaults fit the i9-13900HX: four P-cores, one hardware thread each, for
# the server; the other four P-cores and all 16 E-cores for wrk.
SERVER_CPUS="${SERVER_CPUS:-0,2,4,6}"
CLIENT_CPUS="${CLIENT_CPUS:-8-31}"
WRK_THREADS="${WRK_THREADS:-16}"
WRK_CONNS="${WRK_CONNS:-512}"
KEEPALIVE="${KEEPALIVE:-1}"
# CONF_DIR: run on a copy of this directory's nginx.conf instead (ruxen's
# bench configs), with worker_processes set to WORKERS; URL says where.
CONF_DIR="${CONF_DIR:-}"
URL="${URL:-http://127.0.0.1:$PORT/}"
CLIENT_URL="${CLIENT_URL:-$URL}"
SERVER_HOST="${SERVER_HOST:-}"
CLIENT_HOST="${CLIENT_HOST:-}"
SERVER_ROOT="${SERVER_ROOT:-$ROOT}"
CLIENT_ROOT="${CLIENT_ROOT:-$ROOT}"
# A command the server is started under (per_request.sh: strace).
WRAP="${WRAP:-}"

die() { echo "error: $*" >&2; exit 1; }

on_host() {
    local host="$1"; shift
    if [[ -z "$host" ]]; then
        "$@"
        return
    fi
    local quoted
    local ssh_args=(-o BatchMode=yes -o ConnectTimeout=10)
    [[ -z "${SSH_IDENTITY:-}" ]] || ssh_args+=(-i "$SSH_IDENTITY" -o IdentitiesOnly=yes)
    [[ -z "${SSH_CONTROL_PATH:-}" ]] || ssh_args+=(-o ControlMaster=auto -o ControlPersist=30 -o "ControlPath=$SSH_CONTROL_PATH")
    printf -v quoted '%q ' "$@"
    ssh "${ssh_args[@]}" "$host" "$quoted"
}

sync_conf() {
    [[ -n "$SERVER_HOST" ]] || return 0
    on_host "$SERVER_HOST" mkdir -p "$1"
    tar -C "$1" -cf - . | on_host "$SERVER_HOST" tar -C "$1" -xf -
}

snapshot_hosts() {
    on_host "$SERVER_HOST" python3 "$SERVER_ROOT/scripts/netstats.py" snapshot >"$1.server.json"
    on_host "$CLIENT_HOST" python3 "$CLIENT_ROOT/scripts/netstats.py" snapshot >"$1.client.json"
}

# write_conf DIR: a config both the spike servers and ruxen read.
write_conf() {
    local dir="$1" ka="65"
    if [[ -n "$CONF_DIR" ]]; then
        cp -r "$CONF_DIR"/. "$dir/"
        mkdir -p "$dir/logs"
        sed -e "s/^worker_processes .*/worker_processes $WORKERS;/" \
            "$CONF_DIR/nginx.conf" >"$dir/bench.conf"
        return
    fi
    [[ "$KEEPALIVE" == 1 ]] || ka="0"
    mkdir -p "$dir/logs"
    cat >"$dir/bench.conf" <<EOF
worker_processes $WORKERS;
error_log $dir/logs/error.log crit;
pid $dir/logs/server.pid;
events { worker_connections 4096; }
http {
    access_log off;
    keepalive_timeout $ka;
    keepalive_requests 1000000;
    server {
        listen $PORT reuseport backlog=4096;
        location / { return 200 "hello"; }
    }
}
EOF
}

# start_server VARIANT DIR -> prints the pid
start_server() {
    local variant="$1" dir="$2" bin driver
    if [[ -n "$SERVER_HOST" ]]; then
        on_host "$SERVER_HOST" env WORKERS="$WORKERS" SERVER_CPUS="$SERVER_CPUS" \
            PORT="$PORT" URL="$URL" SERVER_HOST= CLIENT_HOST= \
            bash -c 'source "$1/scripts/lib.sh"; start_server "$2" "$3"' \
            bash "$SERVER_ROOT" "$variant" "$dir"
        return
    fi
    if [[ "$variant" == nginx=* ]]; then
        # nginx itself, the C reference (epoll): master + WORKERS workers,
        # all on SERVER_CPUS. `nginx=PATH`.
        bin="${variant#nginx=}"
        $WRAP taskset -c "$SERVER_CPUS" "$bin" -p "$dir/" -c "$dir/bench.conf" \
            -e "$dir/logs/nginx-error.log" -g "daemon off;" >"$dir/logs/server.out" 2>&1 &
    elif [[ "$variant" == ruxen=* ]]; then
        variant="${variant#ruxen=}"
        bin="${variant%%:*}"
        driver=""; [[ "$variant" == *:* ]] && driver="${variant#*:}"
        RUXEN_DRIVER="$driver" $WRAP taskset -c "$SERVER_CPUS" \
            "$bin" -p "$dir/" -c "$dir/bench.conf" >"$dir/logs/server.out" 2>&1 &
    else
        bin="$ROOT/target/release/spike-${variant%%:*}"
        driver="uring"; [[ "$variant" == *:* ]] && driver="${variant#*:}"
        [[ -x "$bin" ]] || die "no $bin (cargo build --release)"
        SPIKE_DRIVER="$driver" RUXEN_WORKERS="$WORKERS" $WRAP taskset -c "$SERVER_CPUS" \
            "$bin" -c "$dir/bench.conf" >"$dir/logs/server.out" 2>&1 &
    fi
    local pid=$!
    for _ in $(seq 100); do
        curl -sk -o /dev/null "$URL" && { echo "$pid"; return; }
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    cat "$dir/logs/server.out" >&2
    die "$variant did not start"
}

stop_server() {
    if [[ -n "$SERVER_HOST" ]]; then
        on_host "$SERVER_HOST" env PORT="$PORT" URL="$URL" SERVER_HOST= CLIENT_HOST= \
            bash -c 'source "$1/scripts/lib.sh"; stop_server "$2"' bash "$SERVER_ROOT" "$1"
        return
    fi
    kill -TERM "$1" 2>/dev/null || true
    wait "$1" 2>/dev/null || true
    # ruxen's workers are separate processes; wait until the port is free.
    for _ in $(seq 50); do
        curl -sk -o /dev/null -m 0.2 "$URL" || return 0
        sleep 0.1
    done
    die "server on port $PORT did not stop"
}

# run_wrk DURATION OUT
run_wrk() {
    on_host "$CLIENT_HOST" env LC_ALL=C taskset -c "$CLIENT_CPUS" \
        wrk -t "$WRK_THREADS" -c "$WRK_CONNS" --latency \
        -d "$1" "$CLIENT_URL" >"$2" 2>&1
}

# wrk_stats FILE -> "rps p50_us p99_us errors requests"
wrk_stats() {
    awk '
        function us(v) {
            if (v ~ /us$/) return v + 0
            if (v ~ /ms$/) return v * 1000
            if (v ~ /s$/)  return v * 1000000
            return v
        }
        /^Requests\/sec:/            { rps = $2 }
        $1 == "50%"                   { p50 = us($2) }
        $1 == "99%"                   { p99 = us($2) }
        /Non-2xx or 3xx responses:/   { err += $NF }
        /Socket errors:/              { gsub(",", ""); err += $4 + $6 + $8 + $10 }
        / requests in /               { n = $1 }
        END { printf "%s %.0f %.0f %d %s\n", rps, p50, p99, err, n }
    ' "$1"
}
