# Overnight measurements

B/A is the geometric mean of the per-pair throughput ratios (8 pairs, each run 5 s warm-up + 10 s measured, alternating A B / B A); min-max are the extremes of the pair ratios; p50/p99 are wrk's latency percentiles, median over the pairs, in microseconds. The control against itself is the noise floor.

## i7

### info

See `i7/01-info.txt`.

### util-L2

See `i7/02-util-L2.txt`.

### util-L3

See `i7/03-util-L3.txt`.

### util-L1

See `i7/04-util-L1.txt`.

### util-ALL

`WORKERS=12 SERVER_CPUS=0-11 CLIENT_CPUS=0-11 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| FAILED monoio:uring | | | | |
| FAILED compio:uring | | | | |
| FAILED tokio | | | | |
| FAILED tokio-mt | | | | |
| FAILED tokio-uring | | | | |
| FAILED monoio:legacy | | | | |
| FAILED compio:poll | | | | |
| FAILED nginx=/usr/sbin/nginx | | | | |
| FAILED ruxen=/home/eugene/ruxen-bench/article/bin/ruxen-a205d4b2:io_uring | | | | |
| FAILED ruxen=/home/eugene/ruxen-bench/article/bin/ruxen-a205d4b2:epoll | | | | |

### variants-L2-keepalive

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=1 monoio:uring vs monoio:uring) | 100.1% | 99.7–100.7 | 1380 / 1365 | 1500 / 1645 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 83.5% | 83.1–84.2 | 1380 / 1690 | 1590 / 1855 |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 76.3% | 75.8–76.7 | 1390 / 1875 | 1500 / 1985 |
| tokio-mt / monoio:uring (keepalive=1 tokio-mt vs monoio:uring) | 73.8% | 71.7–74.7 | 1375 / 1470 | 1565 / 14240 |
| tokio-uring / monoio:uring (keepalive=1 tokio-uring vs monoio:uring) | 91.8% | 91.2–92.4 | 1370 / 1515 | 1540 / 1660 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 66.6% | 66.1–67.0 | 1375 / 2165 | 1575 / 2340 |
| compio:poll / monoio:uring (keepalive=1 compio:poll vs monoio:uring) | 42.7% | 42.2–43.3 | 1380 / 3355 | 1515 / 3700 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 52.6% | 51.3–53.5 | 1375 / 2715 | 1545 / 2925 |

### variants-L2-new-connection

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=0 monoio:uring vs monoio:uring) | 99.2% | 94.6–102.9 | 1240 / 1240 | 4535 / 4620 |
| compio:uring / monoio:uring (keepalive=0 compio:uring vs monoio:uring) | 75.9% | 73.9–78.6 | 1250 / 12860 | 4690 / 13390 |
| tokio / monoio:uring (keepalive=0 tokio vs monoio:uring) | 91.9% | 91.0–92.7 | 1240 / 8450 | 4510 / 12995 |
| tokio-mt / monoio:uring (keepalive=0 tokio-mt vs monoio:uring) | 79.0% | 75.7–82.7 | 1240 / 6925 | 4875 / 14605 |
| tokio-uring / monoio:uring (keepalive=0 tokio-uring vs monoio:uring) | 66.1% | 65.2–67.4 | 1255 / 14830 | 6725 / 15285 |
| monoio:legacy / monoio:uring (keepalive=0 monoio:legacy vs monoio:uring) | 97.7% | 95.7–101.4 | 1250 / 6620 | 6670 / 11795 |
| compio:poll / monoio:uring (keepalive=0 compio:poll vs monoio:uring) | 102.0% | 99.5–105.7 | 1240 / 3520 | 5525 / 6640 |
| nginx / monoio:uring (keepalive=0 nginx vs monoio:uring) | 76.5% | 74.7–80.5 | 1250 / 8905 | 5085 / 16285 |

### ruxen-L2-epoll-vs-io_uring

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:epoll / ruxen:io_uring (ruxen m1_hello: ruxen:epoll vs ruxen:io_uring) | 66.7% | 64.4–69.0 | 2040 / 3115 | 2305 / 3280 |
| ruxen:epoll / ruxen:io_uring (ruxen m1_no_keepalive: ruxen:epoll vs ruxen:io_uring) | 128.1% | 121.5–133.1 | 5005 / 8815 | 20260 / 16485 |
| ruxen:epoll / ruxen:io_uring (ruxen proxy_hello: ruxen:epoll vs ruxen:io_uring) | 71.8% | 70.3–73.4 | 7060 / 11055 | 291385 / 13180 |
| ruxen:epoll / ruxen:io_uring (ruxen m3_static_1k: ruxen:epoll vs ruxen:io_uring) | 70.2% | 65.1–81.2 | 4265 / 6230 | 4550 / 6575 |
| ruxen:epoll / ruxen:io_uring (ruxen tls_hello: ruxen:epoll vs ruxen:io_uring) | 68.6% | 66.9–70.5 | 2905 / 4380 | 3485 / 4590 |

### per-request-L2-keepalive

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| variant | keep-alive | instr/req user | kernel | total | cycles/req | syscalls/req | calls |
|---|---|---:|---:|---:|---:|---:|---|
| compio:poll | yes | – | – | – | – | 2.061 | epoll_ctl 0.016 sendto 1.004 recvfrom 1.016 (0.011 failed) |
| compio:uring | yes | – | – | – | – | 0.034 | io_uring_enter 0.033 |
| monoio:legacy | yes | – | – | – | – | 2.036 | epoll_ctl 0.005 sendto 1.003 recvfrom 1.012 (0.009 failed) |
| monoio:uring | yes | – | – | – | – | 0.009 | io_uring_enter 0.008 |
| nginx | yes | – | – | – | – | 2.030 | epoll_wait 0.006 writev 1.003 recvfrom 1.006 |
| ruxen:epoll | yes | – | – | – | – | 2.047 | epoll_ctl 0.006 mprotect 0.010 sendto 1.003 recvfrom 1.013 (0.010 failed) |
| ruxen:io_uring | yes | – | – | – | – | 0.011 | io_uring_enter 0.008 |
| tokio | yes | – | – | – | – | 2.043 | epoll_wait 0.017 sendto 1.003 recvfrom 1.005 |
| tokio-mt | yes | – | – | – | – | 2.046 | epoll_ctl 0.006 epoll_wait 0.017 sendto 1.003 recvfrom 1.006 |
| tokio-uring | yes | – | – | – | – | 0.049 | epoll_wait 0.039 io_uring_enter 0.008 |

### per-request-L2-new-connection

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| variant | keep-alive | instr/req user | kernel | total | cycles/req | syscalls/req | calls |
|---|---|---:|---:|---:|---:|---:|---|
| compio:poll | no | – | – | – | – | 5.298 | read 0.033 (0.033 failed) setsockopt 1.009 epoll_ctl 0.130 close 1.005 epoll_pwait 0.033 accept4 1.042 (0.032 failed) sendto 1.005 timerfd_settime 0.033 recvfrom 1.005 |
| compio:uring | no | – | – | – | – | 3.154 | setsockopt 1.006 io_uring_enter 1.139 close 1.006 |
| monoio:legacy | no | – | – | – | – | 7.088 | setsockopt 1.011 epoll_ctl 2.017 epoll_wait 0.015 close 1.007 accept4 1.019 (0.008 failed) sendto 1.006 recvfrom 1.006 |
| monoio:uring | no | – | – | – | – | 2.083 | setsockopt 1.006 io_uring_enter 1.070 mprotect 0.006 |
| nginx | no | – | – | – | – | 6.047 | epoll_ctl 1.003 epoll_wait 1.026 writev 1.003 close 1.003 accept4 1.003 recvfrom 1.003 |
| ruxen:epoll | no | – | – | – | – | 7.139 | setsockopt 1.013 epoll_ctl 2.023 epoll_wait 0.013 close 1.011 mprotect 0.021 accept4 1.020 (0.007 failed) sendto 1.010 futex 0.014 (0.013 failed) recvfrom 1.010 |
| ruxen:io_uring | no | – | – | – | – | 2.054 | setsockopt 1.006 io_uring_enter 1.028 mprotect 0.010 futex 0.006 (0.006 failed) |
| tokio | no | – | – | – | – | 7.186 | setsockopt 1.011 epoll_ctl 2.017 epoll_wait 0.060 write 0.018 close 1.006 accept4 1.054 (0.043 failed) sendto 1.006 recvfrom 1.006 |
| tokio-mt | no | – | – | – | – | 9.976 | setsockopt 1.007 epoll_ctl 2.015 epoll_wait 1.945 write 0.942 close 1.008 accept4 1.007 sendto 1.007 futex 0.032 (0.006 failed) recvfrom 1.007 |
| tokio-uring | no | – | – | – | – | 5.075 | setsockopt 1.006 epoll_wait 2.033 io_uring_enter 1.027 close 1.006 |

### variants-ALL-keepalive

`WORKERS=12 SERVER_CPUS=0-11 CLIENT_CPUS=0-11 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=1 monoio:uring vs monoio:uring) | 99.9% | 99.2–100.7 | 489 / 488 | 7830 / 7840 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 98.1% | 97.6–98.6 | 483 / 815 | 7875 / 7295 |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 97.1% | 96.5–97.7 | 484 / 747 | 7765 / 7215 |
| tokio-mt / monoio:uring (keepalive=1 tokio-mt vs monoio:uring) | 90.8% | 89.8–91.6 | 492 / 1100 | 7785 / 4225 |
| tokio-uring / monoio:uring (keepalive=1 tokio-uring vs monoio:uring) | 97.3% | 96.9–97.8 | 484 / 733 | 7795 / 7980 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 91.7% | 90.9–92.2 | 486 / 1015 | 7815 / 7085 |
| compio:poll / monoio:uring (keepalive=1 compio:poll vs monoio:uring) | 68.2% | 67.7–69.0 | 484 / 1630 | 7815 / 7290 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 73.3% | 72.4–74.1 | 486 / 1445 | 7805 / 7100 |

### variants-ALL-new-connection

`WORKERS=12 SERVER_CPUS=0-11 CLIENT_CPUS=0-11 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=0 monoio:uring vs monoio:uring) | 100.1% | 99.7–100.6 | 1850 / 1860 | 10430 / 10340 |
| compio:uring / monoio:uring (keepalive=0 compio:uring vs monoio:uring) | 100.3% | 99.8–100.8 | 1845 / 2030 | 10460 / 12910 |
| tokio / monoio:uring (keepalive=0 tokio vs monoio:uring) | 98.7% | 98.5–99.1 | 1845 / 2975 | 10565 / 13935 |
| tokio-mt / monoio:uring (keepalive=0 tokio-mt vs monoio:uring) | 90.5% | 90.2–91.1 | 1860 / 6820 | 10515 / 9755 |
| tokio-uring / monoio:uring (keepalive=0 tokio-uring vs monoio:uring) | 97.0% | 96.7–97.2 | 1855 / 2890 | 10530 / 21365 |
| monoio:legacy / monoio:uring (keepalive=0 monoio:legacy vs monoio:uring) | 100.4% | 99.9–101.3 | 1855 / 2600 | 10530 / 12810 |
| compio:poll / monoio:uring (keepalive=0 compio:poll vs monoio:uring) | 97.2% | 96.7–97.9 | 1845 / 3320 | 10600 / 12175 |
| nginx / monoio:uring (keepalive=0 nginx vs monoio:uring) | 99.0% | 98.6–99.4 | 1860 / 4025 | 10660 / 19325 |

### ruxen-ALL-epoll-vs-io_uring

`WORKERS=12 SERVER_CPUS=0-11 CLIENT_CPUS=0-11 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:epoll / ruxen:io_uring (ruxen m1_hello: ruxen:epoll vs ruxen:io_uring) | 78.8% | 78.2–79.2 | 1150 / 1640 | 6790 / 7290 |
| ruxen:epoll / ruxen:io_uring (ruxen m1_no_keepalive: ruxen:epoll vs ruxen:io_uring) | 100.5% | 100.3–100.7 | 4020 / 4540 | 27720 / 22020 |
| ruxen:epoll / ruxen:io_uring (ruxen proxy_hello: ruxen:epoll vs ruxen:io_uring) | 77.3% | 77.0–77.8 | 3735 / 4730 | 6245 / 9790 |
| ruxen:epoll / ruxen:io_uring (ruxen m3_static_1k: ruxen:epoll vs ruxen:io_uring) | 74.8% | 73.3–76.2 | 2065 / 3300 | 6195 / 25925 |
| ruxen:epoll / ruxen:io_uring (ruxen tls_hello: ruxen:epoll vs ruxen:io_uring) | 84.1% | 82.8–84.9 | 1890 / 2500 | 9035 / 9675 |

### ruxen-L2-io_uring-vs-nginx

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:io_uring / nginx (ruxen m1_hello: ruxen:io_uring vs nginx) | 130.5% | 127.9–137.9 | 2680 / 2035 | 2800 / 2235 |
| ruxen:io_uring / nginx (ruxen m1_no_keepalive: ruxen:io_uring vs nginx) | 64.5% | 62.8–66.2 | 9210 / 5190 | 13655 / 19560 |
| ruxen:io_uring / nginx (ruxen proxy_hello: ruxen:io_uring vs nginx) | 119.6% | 112.7–131.0 | 9495 / 7210 | 10850 / 288515 |
| ruxen:io_uring / nginx (ruxen m3_static_1k: ruxen:io_uring vs nginx) | 155.2% | 152.7–160.2 | 6765 / 4290 | 7130 / 4520 |
| ruxen:io_uring / nginx (ruxen tls_hello: ruxen:io_uring vs nginx) | 179.9% | 173.9–184.1 | 5340 / 2930 | 5695 / 3355 |

### ruxen-L2-epoll-vs-nginx

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:epoll / nginx (ruxen m1_hello: ruxen:epoll vs nginx) | 87.4% | 84.2–90.7 | 2720 / 3055 | 2885 / 3315 |
| ruxen:epoll / nginx (ruxen m1_no_keepalive: ruxen:epoll vs nginx) | 83.2% | 80.4–86.5 | 9135 / 9960 | 13535 / 16680 |
| ruxen:epoll / nginx (ruxen proxy_hello: ruxen:epoll vs nginx) | 84.8% | 83.7–87.7 | 9570 / 11225 | 10805 / 12885 |
| ruxen:epoll / nginx (ruxen m3_static_1k: ruxen:epoll vs nginx) | 109.2% | 106.8–110.7 | 6720 / 6125 | 7055 / 6550 |
| ruxen:epoll / nginx (ruxen tls_hello: ruxen:epoll vs nginx) | 121.4% | 115.8–128.3 | 5455 / 4500 | 5760 / 4815 |

### variants-L1-keepalive

`WORKERS=1 SERVER_CPUS=0 CLIENT_CPUS=1,2,3,4,5,7,8,9,10,11 WRK_THREADS=10 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=1 monoio:uring vs monoio:uring) | 100.5% | 98.8–101.5 | 2950 / 2930 | 3075 / 3055 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 82.7% | 81.7–83.2 | 2955 / 3575 | 3080 / 3695 |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 81.2% | 79.2–82.5 | 2930 / 3610 | 3055 / 3715 |
| tokio-mt / monoio:uring (keepalive=1 tokio-mt vs monoio:uring) | 76.8% | 76.0–77.8 | 2960 / 1860 | 3100 / 68765 |
| tokio-uring / monoio:uring (keepalive=1 tokio-uring vs monoio:uring) | 93.0% | 91.7–94.1 | 2965 / 3190 | 3095 / 3330 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 71.3% | 69.5–72.3 | 2935 / 4100 | 3060 / 4250 |
| compio:poll / monoio:uring (keepalive=1 compio:poll vs monoio:uring) | 44.9% | 43.7–45.4 | 2930 / 6470 | 3050 / 6765 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 55.5% | 53.7–57.1 | 2945 / 5285 | 3060 / 194360 |

### connections-L2

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| **WRK_CONNS=64** | | | | |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 80.2% | 79.7–80.6 | 172 / 222 | 210 / 260 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 70.0% | 68.1–71.1 | 173 / 256 | 216 / 303 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 87.1% | 86.4–87.4 | 174 / 202 | 226 / 255 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 55.5% | 52.9–56.9 | 172 / 322 | 218 / 372 |
| **WRK_CONNS=2048** | | | | |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 71.7% | 71.6–71.8 | 3060 / 3865 | 3250 / 5040 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 69.7% | 68.8–70.4 | 3040 / 4415 | 3330 / 4590 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 83.2% | 82.6–84.2 | 3035 / 3690 | 3370 / 3890 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 55.4% | 54.4–57.1 | 3060 / 5585 | 3250 / 5850 |

### variants-L2-keepalive-repeat

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=1 monoio:uring vs monoio:uring) | 100.2% | 99.9–100.7 | 1370 / 1370 | 1620 / 1585 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 83.3% | 82.7–84.3 | 1375 / 1690 | 1605 / 1830 |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 76.1% | 75.2–76.8 | 1370 / 1880 | 1535 / 1990 |
| tokio-mt / monoio:uring (keepalive=1 tokio-mt vs monoio:uring) | 73.9% | 72.0–74.7 | 1380 / 1465 | 1520 / 14820 |
| tokio-uring / monoio:uring (keepalive=1 tokio-uring vs monoio:uring) | 92.2% | 90.7–93.1 | 1370 / 1495 | 1560 / 1635 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 66.5% | 65.2–67.1 | 1370 / 2140 | 1555 / 2250 |
| compio:poll / monoio:uring (keepalive=1 compio:poll vs monoio:uring) | 42.5% | 40.5–43.1 | 1370 / 3340 | 1495 / 3640 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 52.1% | 49.5–54.4 | 1375 / 2750 | 1580 / 2930 |

### ruxen-L2-epoll-vs-io_uring-repeat

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:epoll / ruxen:io_uring (ruxen m1_hello: ruxen:epoll vs ruxen:io_uring) | 67.0% | 66.0–67.9 | 2025 / 3065 | 2280 / 3300 |
| ruxen:epoll / ruxen:io_uring (ruxen m1_no_keepalive: ruxen:epoll vs ruxen:io_uring) | 126.5% | 121.2–130.7 | 5160 / 9430 | 19535 / 16545 |
| ruxen:epoll / ruxen:io_uring (ruxen proxy_hello: ruxen:epoll vs ruxen:io_uring) | 71.7% | 70.4–73.3 | 7020 / 11085 | 298325 / 13390 |
| ruxen:epoll / ruxen:io_uring (ruxen m3_static_1k: ruxen:epoll vs ruxen:io_uring) | 69.6% | 68.5–71.5 | 4270 / 6145 | 4545 / 6445 |
| ruxen:epoll / ruxen:io_uring (ruxen tls_hello: ruxen:epoll vs ruxen:io_uring) | 67.1% | 58.3–70.9 | 2945 / 4390 | 3380 / 4725 |

### variants-L2-new-connection-repeat

`WORKERS=2 SERVER_CPUS=0,1 CLIENT_CPUS=2,3,4,5,8,9,10,11 WRK_THREADS=8 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=0 monoio:uring vs monoio:uring) | 100.6% | 95.2–105.3 | 1265 / 1250 | 4815 / 5995 |
| compio:uring / monoio:uring (keepalive=0 compio:uring vs monoio:uring) | 78.6% | 74.6–86.7 | 1280 / 12750 | 11430 / 13295 |
| tokio / monoio:uring (keepalive=0 tokio vs monoio:uring) | 92.9% | 91.8–94.8 | 1255 / 6855 | 6285 / 12935 |
| tokio-mt / monoio:uring (keepalive=0 tokio-mt vs monoio:uring) | 79.7% | 74.1–87.7 | 1255 / 6835 | 4790 / 14370 |
| tokio-uring / monoio:uring (keepalive=0 tokio-uring vs monoio:uring) | 67.6% | 65.2–70.9 | 1250 / 14775 | 5130 / 15285 |
| monoio:legacy / monoio:uring (keepalive=0 monoio:legacy vs monoio:uring) | 96.8% | 95.9–99.9 | 1240 / 5750 | 4875 / 11745 |
| compio:poll / monoio:uring (keepalive=0 compio:poll vs monoio:uring) | 101.9% | 100.2–106.3 | 1255 / 3555 | 4925 / 6635 |
| nginx / monoio:uring (keepalive=0 nginx vs monoio:uring) | 76.9% | 74.8–80.9 | 1275 / 9175 | 8770 / 16255 |

## i9

### info

See `i9/01-info.txt`.

### util-W4

See `i9/02-util-W4.txt`.

### util-W8

See `i9/03-util-W8.txt`.

### variants-W4-keepalive

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=1 monoio:uring vs monoio:uring) | 100.7% | 94.5–108.2 | 558 / 548 | 844 / 820 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 85.7% | 73.5–89.6 | 488 / 560 | 579 / 714 |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 82.6% | 71.9–90.4 | 542 / 675 | 825 / 1010 |
| tokio-mt / monoio:uring (keepalive=1 tokio-mt vs monoio:uring) | 82.5% | 77.0–90.4 | 570 / 703 | 820 / 1425 |
| tokio-uring / monoio:uring (keepalive=1 tokio-uring vs monoio:uring) | 96.8% | 92.7–104.2 | 558 / 572 | 835 / 852 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 83.6% | 83.2–84.1 | 483 / 586 | 569 / 677 |
| compio:poll / monoio:uring (keepalive=1 compio:poll vs monoio:uring) | 60.6% | 57.8–64.6 | 483 / 814 | 593 / 1025 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 70.9% | 68.6–73.0 | 483 / 697 | 612 / 796 |

### variants-W4-new-connection

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=0 monoio:uring vs monoio:uring) | 101.8% | 96.8–112.3 | 633 / 599 | 5285 / 4895 |
| compio:uring / monoio:uring (keepalive=0 compio:uring vs monoio:uring) | 105.8% | 99.0–116.5 | 632 / 672 | 5920 / 6710 |
| tokio / monoio:uring (keepalive=0 tokio vs monoio:uring) | 103.6% | 80.6–127.6 | 580 / 2900 | 4800 / 6590 |
| tokio-mt / monoio:uring (keepalive=0 tokio-mt vs monoio:uring) | 94.2% | 87.7–100.5 | 591 / 2270 | 5395 / 5140 |
| tokio-uring / monoio:uring (keepalive=0 tokio-uring vs monoio:uring) | 106.8% | 89.1–122.4 | 559 / 676 | 5195 / 4905 |
| monoio:legacy / monoio:uring (keepalive=0 monoio:legacy vs monoio:uring) | 119.9% | 110.5–138.9 | 584 / 940 | 5500 / 6425 |
| compio:poll / monoio:uring (keepalive=0 compio:poll vs monoio:uring) | 125.9% | 119.6–133.4 | 610 / 1190 | 5190 / 5760 |
| nginx / monoio:uring (keepalive=0 nginx vs monoio:uring) | 89.7% | 68.3–128.3 | 627 / 3470 | 5705 / 6335 |

### ruxen-W4-epoll-vs-io_uring

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:epoll / ruxen:io_uring (ruxen m1_hello: ruxen:epoll vs ruxen:io_uring) | 98.6% | 93.2–102.7 | 179965 / 182065 | 1525000 / 1185000 |
| FAILED m1_hello | | | | |
| ruxen:epoll / ruxen:io_uring (ruxen m1_no_keepalive: ruxen:epoll vs ruxen:io_uring) | 116.5% | 96.9–128.1 | 920 / 3545 | 7840 / 7345 |
| ruxen:epoll / ruxen:io_uring (ruxen proxy_hello: ruxen:epoll vs ruxen:io_uring) | 102.8% | 100.0–105.3 | 2110 / 2100 | 12870 / 2925 |
| ruxen:epoll / ruxen:io_uring (ruxen m3_static_1k: ruxen:epoll vs ruxen:io_uring) | 91.0% | 85.0–98.1 | 1015 / 1105 | 1145 / 1300 |
| ruxen:epoll / ruxen:io_uring (ruxen tls_hello: ruxen:epoll vs ruxen:io_uring) | 89.9% | 89.4–90.7 | 818 / 920 | 970 / 1080 |

### per-request-W4-keepalive

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| variant | keep-alive | instr/req user | kernel | total | cycles/req | syscalls/req | calls |
|---|---|---:|---:|---:|---:|---:|---|
| compio:poll | yes | 5613 | 23483 | 29096 | 18420 | 2.024 | epoll_ctl 0.012 sendto 1.001 recvfrom 1.007 (0.006 failed) |
| compio:uring | yes | 5280 | 18672 | 23951 | 12530 | 0.033 | io_uring_enter 0.033 |
| monoio:legacy | yes | 1551 | 18316 | 19867 | 13175 | 2.014 | sendto 1.001 recvfrom 1.009 (0.008 failed) |
| monoio:uring | yes | 2158 | 17595 | 19753 | 11152 | 0.016 | io_uring_enter 0.016 |
| nginx | yes | 7650 | 17993 | 25623 | 15327 | 2.014 | epoll_wait 0.008 writev 1.001 recvfrom 1.001 |
| ruxen:epoll | yes | 9609 | 18288 | 27897 | 16912 | 2.017 | sendto 1.001 recvfrom 1.009 (0.009 failed) |
| ruxen:io_uring | yes | 10482 | 17795 | 28273 | 15045 | 0.017 | io_uring_enter 0.016 |
| tokio | yes | 1610 | 17255 | 18866 | 12452 | 2.025 | epoll_wait 0.016 sendto 1.001 recvfrom 1.002 |
| tokio-mt | yes | 1735 | 17335 | 19071 | 13439 | 2.024 | epoll_wait 0.016 sendto 1.001 recvfrom 1.002 |
| tokio-uring | yes | 2491 | 18713 | 21204 | 11605 | 0.059 | epoll_wait 0.043 io_uring_enter 0.016 |

### per-request-W4-new-connection

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| variant | keep-alive | instr/req user | kernel | total | cycles/req | syscalls/req | calls |
|---|---|---:|---:|---:|---:|---:|---|
| compio:poll | no | 8874 | 52798 | 61671 | 37280 | 6.026 | read 0.090 (0.090 failed) setsockopt 1.003 epoll_ctl 0.553 close 1.003 epoll_pwait 0.090 accept4 1.068 (0.065 failed) sendto 1.002 timerfd_settime 0.090 recvfrom 1.125 (0.122 failed) |
| compio:uring | no | 9863 | 55041 | 64903 | 39358 | 3.178 | setsockopt 1.002 io_uring_enter 1.170 close 1.002 |
| monoio:legacy | no | 4504 | 58520 | 63025 | 39991 | 7.195 | setsockopt 1.003 epoll_ctl 2.007 epoll_wait 0.117 close 1.003 accept4 1.055 (0.051 failed) sendto 1.003 recvfrom 1.003 |
| monoio:uring | no | 5819 | 60601 | 66420 | 40746 | 2.187 | setsockopt 1.002 io_uring_enter 1.182 |
| nginx | no | 10155 | 55490 | 65645 | 38496 | 6.078 | epoll_ctl 1.003 epoll_wait 1.060 writev 1.003 close 1.003 accept4 1.003 recvfrom 1.003 |
| ruxen:epoll | no | 17744 | 59163 | 76908 | 47045 | 7.163 | setsockopt 1.003 epoll_ctl 2.007 epoll_wait 0.088 close 1.003 mprotect 0.006 accept4 1.045 (0.042 failed) sendto 1.003 recvfrom 1.003 |
| ruxen:io_uring | no | 19919 | 60799 | 80719 | 49356 | 2.316 | setsockopt 1.002 io_uring_enter 1.306 |
| tokio | no | 6796 | 60021 | 66817 | 43037 | 7.234 | setsockopt 1.003 epoll_ctl 2.007 epoll_wait 0.120 write 0.018 close 1.003 accept4 1.073 (0.069 failed) sendto 1.002 recvfrom 1.003 |
| tokio-mt | no | 6748 | 58550 | 65298 | 50040 | 12.793 | setsockopt 1.005 epoll_ctl 2.010 epoll_wait 2.521 write 0.703 close 1.005 accept4 1.005 sendto 1.004 futex 2.533 (0.202 failed) recvfrom 1.005 |
| tokio-uring | no | 9424 | 59444 | 68868 | 42545 | 5.305 | setsockopt 1.003 epoll_wait 2.149 (0.057 failed) io_uring_enter 1.147 close 1.003 |

### profiles-W4-keepalive

See `i9/09-profiles-W4-keepalive.txt`.

### ruxen-W4-io_uring-vs-nginx

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:io_uring / nginx (ruxen m1_hello: ruxen:io_uring vs nginx) | 99.3% | 94.7–101.3 | 180795 / 182025 | 1310000 / 1305000 |
| FAILED m1_hello | | | | |
| ruxen:io_uring / nginx (ruxen m1_no_keepalive: ruxen:io_uring vs nginx) | 65.8% | 58.5–81.9 | 760 / 890 | 6000 / 6970 |
| ruxen:io_uring / nginx (ruxen proxy_hello: ruxen:io_uring vs nginx) | 85.4% | 83.3–88.5 | 1875 / 2095 | 2405 / 12610 |
| ruxen:io_uring / nginx (ruxen m3_static_1k: ruxen:io_uring vs nginx) | 108.4% | 104.9–114.4 | 1055 / 975 | 1220 / 1145 |
| ruxen:io_uring / nginx (ruxen tls_hello: ruxen:io_uring vs nginx) | 122.7% | 121.9–123.5 | 1030 / 822 | 1165 / 920 |

### ruxen-W4-epoll-vs-nginx

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:epoll / nginx (ruxen m1_hello: ruxen:epoll vs nginx) | 98.4% | 93.8–100.4 | 173580 / 176240 | 1300000 / 1305000 |
| FAILED m1_hello | | | | |
| ruxen:epoll / nginx (ruxen m1_no_keepalive: ruxen:epoll vs nginx) | 67.4% | 54.3–84.1 | 706 / 3595 | 5715 / 7360 |
| ruxen:epoll / nginx (ruxen proxy_hello: ruxen:epoll vs nginx) | 86.9% | 83.6–89.9 | 1860 / 2120 | 2260 / 2915 |
| ruxen:epoll / nginx (ruxen m3_static_1k: ruxen:epoll vs nginx) | 97.1% | 94.6–100.0 | 1050 / 1115 | 1270 / 1280 |
| ruxen:epoll / nginx (ruxen tls_hello: ruxen:epoll vs nginx) | 110.4% | 109.3–112.2 | 1020 / 930 | 1160 / 1050 |

### scaling-W1-keepalive

`WORKERS=1 SERVER_CPUS=0 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 96.5% | 95.7–98.6 | 1625 / 1690 | 1660 / 1760 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 92.3% | 89.1–101.9 | 1635 / 1790 | 1675 / 1870 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 82.5% | 76.2–99.4 | 1720 / 2120 | 1750 / 2150 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 78.9% | 69.1–87.7 | 1640 / 2070 | 1690 / 56410 |

### scaling-W2-keepalive

`WORKERS=2 SERVER_CPUS=0,2 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 92.2% | 88.3–101.8 | 787 / 875 | 885 / 970 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 86.5% | 85.0–91.8 | 773 / 915 | 836 / 1015 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 86.4% | 75.9–91.6 | 777 / 885 | 841 / 985 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 75.6% | 74.6–76.6 | 774 / 1035 | 860 / 1100 |

### scaling-W8-keepalive

`WORKERS=8 SERVER_CPUS=0,2,4,6,8,10,12,14 CLIENT_CPUS=16-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 103.6% | 98.5–105.3 | 196 / 189 | 398 / 383 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 102.3% | 96.6–107.5 | 198 / 189 | 1201 / 391 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 100.6% | 98.0–103.2 | 194 / 239 | 398 / 407 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 96.0% | 91.6–97.9 | 196 / 379 | 397 / 471 |

### connections-W4

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| **WRK_CONNS=64** | | | | |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 102.3% | 98.6–106.1 | 70 / 70 | 94 / 101 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 100.5% | 98.4–102.7 | 73 / 71 | 98 / 96 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 92.6% | 86.7–96.1 | 70 / 75 | 100 / 108 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 79.5% | 76.0–82.0 | 70 / 89 | 96 / 117 |
| **WRK_CONNS=2048** | | | | |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 92.0% | 90.7–94.3 | 2100 / 2300 | 2450 / 2535 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 88.1% | 87.0–90.1 | 2120 / 2440 | 2450 / 2640 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 83.8% | 81.1–86.9 | 2130 / 2605 | 2420 / 2880 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 73.0% | 72.0–74.1 | 2125 / 2845 | 2390 / 3350 |

### variants-W4-keepalive-repeat

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=1 monoio:uring vs monoio:uring) | 100.5% | 97.7–104.2 | 487 / 483 | 591 / 565 |
| compio:uring / monoio:uring (keepalive=1 compio:uring vs monoio:uring) | 87.3% | 83.7–93.0 | 492 / 569 | 565 / 671 |
| tokio / monoio:uring (keepalive=1 tokio vs monoio:uring) | 89.9% | 88.2–91.1 | 484 / 555 | 582 / 642 |
| tokio-mt / monoio:uring (keepalive=1 tokio-mt vs monoio:uring) | 82.7% | 80.7–86.1 | 482 / 584 | 576 / 1120 |
| tokio-uring / monoio:uring (keepalive=1 tokio-uring vs monoio:uring) | 94.9% | 92.4–96.4 | 482 / 508 | 572 / 598 |
| monoio:legacy / monoio:uring (keepalive=1 monoio:legacy vs monoio:uring) | 85.7% | 83.8–87.3 | 486 / 585 | 593 / 649 |
| compio:poll / monoio:uring (keepalive=1 compio:poll vs monoio:uring) | 60.3% | 58.0–63.6 | 485 / 824 | 568 / 1000 |
| nginx / monoio:uring (keepalive=1 nginx vs monoio:uring) | 72.3% | 67.1–74.5 | 482 / 674 | 574 / 778 |

### ruxen-W4-epoll-vs-io_uring-repeat

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| ruxen:epoll / ruxen:io_uring (ruxen m1_hello: ruxen:epoll vs ruxen:io_uring) | 100.0% | 99.7–100.7 | 173860 / 173455 | 1320000 / 1160000 |
| FAILED m1_hello | | | | |
| ruxen:epoll / ruxen:io_uring (ruxen m1_no_keepalive: ruxen:epoll vs ruxen:io_uring) | 114.1% | 92.2–147.5 | 875 / 3665 | 7860 / 7350 |
| ruxen:epoll / ruxen:io_uring (ruxen proxy_hello: ruxen:epoll vs ruxen:io_uring) | 102.9% | 98.7–106.3 | 2080 / 2105 | 14500 / 2685 |
| ruxen:epoll / ruxen:io_uring (ruxen m3_static_1k: ruxen:epoll vs ruxen:io_uring) | 91.0% | 88.2–95.5 | 980 / 1100 | 1160 / 1230 |
| ruxen:epoll / ruxen:io_uring (ruxen tls_hello: ruxen:epoll vs ruxen:io_uring) | 90.0% | 89.5–90.6 | 825 / 930 | 960 / 1030 |

### variants-W4-new-connection-repeat

`WORKERS=4 SERVER_CPUS=0,2,4,6 CLIENT_CPUS=8-31 WRK_THREADS=16 WRK_CONNS=512`

| comparison | B/A | min–max | p50 A / B | p99 A / B |
|---|---:|---:|---:|---:|
| monoio:uring / monoio:uring (keepalive=0 monoio:uring vs monoio:uring) | 103.5% | 92.1–114.2 | 563 / 567 | 5100 / 4565 |
| compio:uring / monoio:uring (keepalive=0 compio:uring vs monoio:uring) | 105.3% | 91.7–116.9 | 583 / 663 | 5510 / 6290 |
| tokio / monoio:uring (keepalive=0 tokio vs monoio:uring) | 83.1% | 70.1–90.8 | 631 / 5095 | 5735 / 6260 |
| tokio-mt / monoio:uring (keepalive=0 tokio-mt vs monoio:uring) | 93.4% | 86.2–104.4 | 594 / 2220 | 5500 / 5060 |
| tokio-uring / monoio:uring (keepalive=0 tokio-uring vs monoio:uring) | 99.8% | 93.5–114.6 | 625 / 746 | 5480 / 6735 |
| monoio:legacy / monoio:uring (keepalive=0 monoio:legacy vs monoio:uring) | 115.8% | 98.0–131.4 | 600 / 586 | 5260 / 6440 |
| compio:poll / monoio:uring (keepalive=0 compio:poll vs monoio:uring) | 118.4% | 84.1–134.1 | 561 / 1160 | 4975 / 5055 |
| nginx / monoio:uring (keepalive=0 nginx vs monoio:uring) | 91.5% | 68.5–134.1 | 593 / 4150 | 5155 / 6405 |

