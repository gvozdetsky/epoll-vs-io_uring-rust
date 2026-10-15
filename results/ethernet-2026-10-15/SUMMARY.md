# Ethernet measurements, 2026-10-15

Direct 1 Gbit/s full-duplex Ethernet, IPv4, MTU 1500. One server worker, 512 keep-alive connections, four wrk threads on the other laptop. Four alternating AB/BA pairs per comparison; each run has 3 s warm-up and 10 s measured, with 1 s pauses and a discarded 20 s control run before each comparison.

Ratios are geometric means; ranges are pair min–max, not confidence intervals. Throughput columns are medians of the four individual runs, so their quotient need not equal the geometric-mean ratio. Latency columns are medians of per-run percentiles, in microseconds. A is monoio/io_uring. The two directions run sequentially.

## i7-server

| B | B/A (min–max) | req/s A / B | p50 µs A / B | p99 µs A / B |
|---|---:|---:|---:|---:|
| monoio:uring | 99.8% (99.5–99.9) | 156933 / 156573 | 3240 / 3245 | 3330 / 3335 |
| tokio | 78.6% (77.6–79.2) | 156423 / 123234 | 3250 / 4135 | 3335 / 4220 |
| monoio:legacy | 69.2% (68.8–69.4) | 156674 / 108382 | 3245 / 4695 | 3330 / 4850 |
| compio:uring | 75.2% (75.1–75.3) | 157396 / 118311 | 3225 / 4315 | 3325 / 4430 |
| tokio-mt | 76.7% (76.5–76.9) | 156794 / 120124 | 3245 / 2110 | 3330 / 66955 |
| tokio-uring | 91.9% (91.0–92.7) | 156779 / 144350 | 3240 / 3555 | 3335 / 3680 |
| compio:poll | 40.1% (39.7–40.6) | 157137 / 63001 | 3240 / 8045 | 3325 / 8335 |
| nginx | 47.1% (46.7–47.3) | 157190 / 74157 | 3240 / 6880 | 3320 / 178540 |

| B | server CPU % A / B | client CPU % A / B | server TX Mbit/s A / B | server RX Mbit/s A / B | NIC errors + drops |
|---|---:|---:|---:|---:|---:|
| monoio:uring | 96.4 / 96.0 | 19.9 / 21.6 | 263.5 / 261.8 | 133.7 / 132.8 | 0 |
| tokio | 95.9 / 95.5 | 21.5 / 15.2 | 261.7 / 204.7 | 132.7 / 103.8 | 0 |
| monoio:legacy | 96.2 / 96.1 | 20.1 / 14.0 | 262.5 / 181.6 | 133.1 / 92.2 | 0 |
| compio:uring | 96.4 / 96.9 | 19.5 / 16.4 | 264.5 / 199.6 | 134.1 / 101.3 | 0 |
| tokio-mt | 96.0 / 96.5 | 20.9 / 19.0 | 261.6 / 206.8 | 132.7 / 102.5 | 0 |
| tokio-uring | 95.9 / 95.5 | 20.6 / 19.8 | 261.8 / 238.2 | 132.8 / 120.8 | 0 |
| compio:poll | 96.5 / 96.0 | 19.6 / 11.3 | 263.9 / 105.4 | 133.8 / 53.5 | 0 |
| nginx | 95.9 / 96.0 | 19.8 / 12.7 | 262.8 / 129.9 | 133.3 / 63.0 | 0 |

## i9-server

| B | B/A (min–max) | req/s A / B | p50 µs A / B | p99 µs A / B |
|---|---:|---:|---:|---:|
| monoio:uring | 100.1% (99.9–100.3) | 168558 / 168521 | 3020 / 3020 | 3120 / 3120 |
| tokio | 100.2% (99.7–100.5) | 169174 / 169677 | 3005 / 2995 | 3095 / 3095 |
| monoio:legacy | 100.1% (100.0–100.1) | 169129 / 169244 | 3010 / 3005 | 3110 / 3115 |

| B | server CPU % A / B | client CPU % A / B | server TX Mbit/s A / B | server RX Mbit/s A / B | NIC errors + drops |
|---|---:|---:|---:|---:|---:|
| monoio:uring | 53.6 / 55.0 | 55.5 / 56.0 | 285.3 / 286.6 | 142.1 / 142.7 | 0 |
| tokio | 56.3 / 52.8 | 56.1 / 54.8 | 286.3 / 283.7 | 142.6 / 141.3 | 0 |
| monoio:legacy | 56.6 / 54.4 | 56.0 / 55.8 | 288.0 / 287.1 | 143.4 / 143.0 | 0 |

CPU values are mean busy shares of the selected CPU sets, including kernel work. Telemetry windows bracket wrk and include command/SSH overhead; utilisation and NIC byte rates are approximate, not process CPU percentages or full wire rates. NIC errors/drops are totals over both hosts and all measured runs in that comparison. All retained measured wrk runs were checked for socket and HTTP errors.

The separate `calibration-i7-c64` files are a two-pair, 64-connection calibration (5 s measured, 2 s warm-up), excluded from these tables. These experiments use ordinary keep-alive HTTP over Ethernet; they do not test TLS, proxying, static files or new-connection-per-request traffic over the cable.
