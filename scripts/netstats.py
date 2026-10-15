#!/usr/bin/env python3
import json
from pathlib import Path
import socket
import sys
import time


def snapshot():
    cpus = {}
    for line in Path('/proc/stat').read_text().splitlines():
        fields = line.split()
        if fields[0].startswith('cpu') and fields[0][3:].isdigit():
            cpus[fields[0][3:]] = list(map(int, fields[1:9]))
    network = {}
    for interface in Path('/sys/class/net').iterdir():
        network[interface.name] = {
            field: int((interface / 'statistics' / field).read_text())
            for field in ('rx_bytes', 'tx_bytes', 'rx_packets', 'tx_packets',
                          'rx_errors', 'tx_errors', 'rx_dropped', 'tx_dropped')
        }
    return dict(host=socket.gethostname(), monotonic=time.monotonic(),
                time=time.time(), cpus=cpus, network=network)


def cpu_set(spec):
    result = []
    for part in spec.split(','):
        bounds = list(map(int, part.split('-')))
        result.extend(range(bounds[0], bounds[-1] + 1))
    return result


def report(prefix, server_cpus, client_cpus, server_interface, client_interface):
    result = {}
    for role, cpus, interface in (('server', server_cpus, server_interface),
                                   ('client', client_cpus, client_interface)):
        before = json.loads(Path(f'{prefix}.before.{role}.json').read_text())
        after = json.loads(Path(f'{prefix}.after.{role}.json').read_text())
        elapsed = after['monotonic'] - before['monotonic']
        busy = {}
        for cpu in cpu_set(cpus):
            delta = [end - start for start, end in
                     zip(before['cpus'][str(cpu)], after['cpus'][str(cpu)])]
            busy[str(cpu)] = 100 * (sum(delta) - delta[3] - delta[4]) / max(1, sum(delta))
        network = {field: value - before['network'][interface][field]
                   for field, value in after['network'][interface].items()}
        result[role] = dict(host=after['host'], seconds=elapsed, cpu_busy=busy,
                            cpu_mean=sum(busy.values()) / len(busy), interface=interface,
                            rx_mbps=network['rx_bytes'] * 8 / elapsed / 1e6,
                            tx_mbps=network['tx_bytes'] * 8 / elapsed / 1e6,
                            counters=network)
    return result


if __name__ == '__main__':
    value = snapshot() if sys.argv[1] == 'snapshot' else report(*sys.argv[2:])
    print(json.dumps(value, indent=2))
