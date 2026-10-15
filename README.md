# epoll vs io_uring: the same tiny HTTP server on seven Rust runtime/driver setups

The benchmark behind the article "epoll or io_uring? What monoio and tokio
actually do on Linux in 2026". One minimal keep-alive server (`GET` → `200`,
a 5-byte body, the same request loop and the same response bytes) on:

| binary | `SPIKE_DRIVER` | runtime | kernel interface |
|---|---|---|---|
| `spike-monoio` | `uring` (default) | monoio 0.2.4, `IoUringDriver` | io_uring |
| `spike-monoio` | `legacy` | monoio 0.2.4, `LegacyDriver` (mio 0.8) | epoll |
| `spike-monoio` | `fusion` | monoio 0.2.4, `FusionDriver`: io_uring if it works, else legacy | either |
| `spike-compio` | `uring` (default) | compio 0.19.2 | io_uring |
| `spike-compio` | `poll` | compio 0.19.2, polling driver (`polling` 3) | epoll |
| `spike-tokio` | | tokio 1.53, one current-thread runtime + `LocalSet` per worker | epoll (mio 1.x) |
| `spike-tokio-mt` | | tokio 1.53, one multi-thread (work-stealing) runtime, one listener | epoll (mio 1.x) |
| `spike-tokio-uring` | | tokio-uring 0.5.0, one runtime per worker | io_uring |

All but `spike-tokio-mt` run one single-threaded runtime per worker thread,
each with its own `SO_REUSEPORT` listener. The multi-thread tokio comparison
changes both scheduling and listener topology, not just the I/O layer.

io_uring setup, the same for every io_uring variant: 4096 submission
entries, no SQPOLL, no setup flags (`COOP_TASKRUN`, `DEFER_TASKRUN`,
`SINGLE_ISSUER` all off), plain single-shot `accept` / `recv` / `send`, no
registered files or buffers. These are the runtimes' defaults apart from the
ring size.

## Running it

Needs Linux, a Rust toolchain, `wrk`, `curl`, `taskset`, and for
`per_request.sh` also `perf` (`kernel.perf_event_paranoid` ≤ 1) and `strace`.

```bash
cargo build --release --locked
scripts/abba.sh monoio:uring tokio                  # one comparison
KEEPALIVE=0 scripts/abba.sh monoio:uring tokio      # new connection per request
scripts/per_request.sh monoio:legacy                # instructions and syscalls per request
scripts/campaign.sh results/my-machine              # everything (about two hours)
```

`abba.sh` runs A B, B A, A B, … (8 pairs by default), each run being a 5 s
wrk warm-up and a 10 s measured wrk run on a fresh server, after one 20 s
throwaway run of A. It prints every pair and then the **geometric mean of the
per-pair B/A throughput ratios with their min–max**, and the median p50 / p99
latency of each side.

Server and client are restricted to separate CPU sets (`taskset`). Verify
client headroom for each workload; affinity alone does not establish the
bottleneck. Workers can migrate within the server set. The defaults fit an i9-13900HX: the server gets
4 workers on one hardware thread of four P-cores (`SERVER_CPUS=0,2,4,6`), wrk
gets `-t16 -c512` on the other four P-cores and all E-cores
(`CLIENT_CPUS=8-31`). Check this on your machine: during a run the server
should sit at 100% of its cores and wrk well below.

Variables (see `scripts/lib.sh`): `WORKERS`, `SERVER_CPUS`, `CLIENT_CPUS`,
`WRK_THREADS`, `WRK_CONNS`, `KEEPALIVE`, `PORT`. A variant can also be a ruxen
binary: `ruxen=/path/to/ruxen:epoll`, with `CONF_DIR` pointing at one of
ruxen's `bench/<scenario>/` directories and `URL` at the scenario.

## Results

See [the overnight summary](results/night-2026-10-15/SUMMARY.md) and its raw
logs. Ratios are geometric means, ranges are pair minima/maxima rather than
confidence intervals. Rows followed by `FAILED` are not valid measurements;
in particular, the i9 `m1_hello` scenario failed in all four comparisons.
The i7 `util-ALL` collector also failed. Its final new-connection repeat is
complete in the synchronized data.

The recorded governors were `performance` on the i7 and `powersave` on the
i9. They are separate host experiments, not a controlled comparison of CPU
mitigations. The raw logs retain machine metadata and local paths for provenance.

The ruxen scenarios require a separately built ruxen binary at commit
`a205d4b2f13ccc338d2a209579532f9bb394a786` from
[gvozdetsky/ruxen](https://github.com/gvozdetsky/ruxen).
Set `RUXEN` and `NGINX` when using `scripts/night.sh`; binaries are not
included in this repository. TLS keys are generated locally by
`ruxen-configs/tls/generate.sh` and are not published.

## License

Apache-2.0, like ruxen, where this code started (issue #272).
