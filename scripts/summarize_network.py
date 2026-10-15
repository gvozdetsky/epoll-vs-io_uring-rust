#!/usr/bin/env python3
import json
import math
from pathlib import Path
import re
import statistics
import sys


RESULT = re.compile(
    r'RESULT (\S+) / (\S+): ([\d.]+)% \(min ([\d.]+), max ([\d.]+); '
    r'(\d+) pairs\)  p50 us A (\d+) B (\d+)  p99 us A (\d+) B (\d+)'
)
PAIR = re.compile(
    r'pair \d+ A ([\d.]+) p50 \d+ p99 \d+ \| B ([\d.]+) '
    r'p50 \d+ p99 \d+ \| B/A ([\d.]+)%'
)


def comparison(path):
    text = path.read_text()
    result = RESULT.search(text)
    if not result or 'ERROR:' in text or 'FAILED' in text:
        raise ValueError(f'Incomplete or failed comparison: {path}')
    pairs = [tuple(map(float, pair)) for pair in PAIR.findall(text)]
    if len(pairs) != int(result[6]):
        raise ValueError(f'Wrong pair count: {path}')
    ratio = math.exp(statistics.mean(math.log(pair[2]) for pair in pairs))
    if abs(ratio - float(result[3])) > 0.051:
        raise ValueError(f'Ratio does not match raw pairs: {path}')
    for actual, reported in ((min(pair[2] for pair in pairs), result[4]),
                             (max(pair[2] for pair in pairs), result[5])):
        if abs(actual - float(reported)) > 0.051:
            raise ValueError(f'Range does not match raw pairs: {path}')
    samples = {}
    latencies = {}
    raw = path.with_name(path.stem + '-raw')
    for side in ('a', 'b'):
        samples[side] = []
        latencies[side] = {50: [], 99: []}
        for index in range(len(pairs)):
            prefix = raw / f'{side}{index}'
            wrk = prefix.with_suffix('.wrk').read_text()
            throughput = re.search(r'Requests/sec:\s+([\d.]+)', wrk)
            if not throughput or abs(float(throughput[1]) - pairs[index][0 if side == 'a' else 1]) > 0.011:
                raise ValueError(f'Throughput does not match raw wrk output: {prefix}')
            for percentile in (50, 99):
                latency = re.search(rf'^\s+{percentile}%\s+([\d.]+)(us|ms|s)', wrk, re.MULTILINE)
                if not latency:
                    raise ValueError(f'Missing latency in {prefix}')
                latencies[side][percentile].append(round(float(latency[1]) * {'us': 1, 'ms': 1000, 's': 1000000}[latency[2]]))
            errors = sum(map(int, re.findall(
                r'(?:connect|read|write|timeout) (\d+)', wrk)))
            errors += sum(map(int, re.findall(r'Non-2xx or 3xx responses: (\d+)', wrk)))
            if errors:
                raise ValueError(f'wrk errors in {prefix}: {errors}')
            telemetry = json.loads(prefix.with_suffix('.telemetry.json').read_text())
            samples[side].append(telemetry)
    for side, percentile, field in (('a', 50, 7), ('b', 50, 8), ('a', 99, 9), ('b', 99, 10)):
        if int(statistics.median(latencies[side][percentile])) != int(result[field]):
            raise ValueError(f'Latency does not match raw wrk output: {path}')
    return result, pairs, samples


def main(directory):
    output = ['# Ethernet measurements, 2026-10-15', '',
              'Direct 1 Gbit/s full-duplex Ethernet, IPv4, MTU 1500. '
              'One server worker, 512 keep-alive connections, four wrk threads on the other laptop. '
              'Four alternating AB/BA pairs per comparison; each run has 3 s warm-up and 10 s measured, '
              'with 1 s pauses and a discarded 20 s control run before each comparison.', '',
              'Ratios are geometric means; ranges are pair min–max, not confidence intervals. '
              'Throughput columns are medians of the four individual runs, so their quotient need not '
              'equal the geometric-mean ratio. Latency columns are medians of per-run percentiles, '
              'in microseconds. A is monoio/io_uring. The two directions run sequentially.', '']
    for host in sorted(Path(directory).glob('*-server')):
        output += [f'## {host.name}', '',
                   '| B | B/A (min–max) | req/s A / B | p50 µs A / B | p99 µs A / B |',
                   '|---|---:|---:|---:|---:|']
        telemetry_rows = []
        for path in sorted(host.glob('[0-9][0-9]-*.txt')):
            result, pairs, samples = comparison(path)
            name = result[1].replace('nginx=/usr/sbin/nginx', 'nginx')
            rates = [statistics.median(pair[index] for pair in pairs) for index in (0, 1)]
            output.append(f'| {name} | {result[3]}% ({result[4]}–{result[5]}) | '
                          f'{rates[0]:.0f} / {rates[1]:.0f} | {result[7]} / {result[8]} | '
                          f'{result[9]} / {result[10]} |')
            metrics = []
            for role, field in (('server', 'cpu_mean'), ('client', 'cpu_mean'),
                                ('server', 'tx_mbps'), ('server', 'rx_mbps')):
                metrics.append(' / '.join(f'{statistics.median(sample[role][field] for sample in samples[side]):.1f}'
                                          for side in ('a', 'b')))
            drops = sum(sample[role]['counters'][field]
                        for side in ('a', 'b') for sample in samples[side]
                        for role in ('server', 'client')
                        for field in ('rx_errors', 'tx_errors', 'rx_dropped', 'tx_dropped'))
            telemetry_rows.append(f'| {name} | ' + ' | '.join(metrics) + f' | {drops} |')
        output += ['', '| B | server CPU % A / B | client CPU % A / B | server TX Mbit/s A / B | server RX Mbit/s A / B | NIC errors + drops |',
                   '|---|---:|---:|---:|---:|---:|', *telemetry_rows, '']
    output += ['CPU values are mean busy shares of the selected CPU sets, including kernel work. '
               'Telemetry windows bracket wrk and include command/SSH overhead; utilisation and '
               'NIC byte rates are approximate, not process CPU percentages or full wire rates. '
               'NIC errors/drops are totals over both hosts and all measured runs in that comparison. '
               'All retained measured wrk runs were checked for socket and HTTP errors.', '',
               'The separate `calibration-i7-c64` files are a two-pair, 64-connection calibration '
               '(5 s measured, 2 s warm-up), excluded from these tables. '
               'These experiments use ordinary keep-alive HTTP over Ethernet; they do not test '
               'TLS, proxying, static files or new-connection-per-request traffic over the cable.']
    print('\n'.join(output))


if __name__ == '__main__':
    main(sys.argv[1])
