#!/usr/bin/env python3
"""Tables from a night of scripts/night.sh output.

    scripts/summarize.py RESULTS_DIR [RESULTS_DIR ...] > SUMMARY.md

Each RESULTS_DIR holds the numbered phase files of one machine. For every
ABBA comparison: B/A (geometric mean of the pair ratios), the min-max of
the pairs, and the median p50 / p99 of each side. Per-request counts are
the median over rounds. Utilisation and profiles are linked, not copied.
"""
import os
import re
import statistics
import sys

RESULT = re.compile(
    r"RESULT (?P<b>\S+) / (?P<a>\S+): (?P<r>[\d.]+)% \(min (?P<lo>[\d.]+), max (?P<hi>[\d.]+); "
    r"(?P<n>\d+) pairs\)\s+p50 us A (?P<p50a>\d+) B (?P<p50b>\d+)\s+p99 us A (?P<p99a>\d+) B (?P<p99b>\d+)"
)
PERF = re.compile(
    r"round=\d+ keepalive=(?P<ka>\d) (?P<v>\S+) instr/req user (?P<u>\d+) kernel (?P<k>\d+) "
    r"total (?P<t>\d+)\s+cycles/req (?P<c>\d+)"
)
SYS = re.compile(r"round=\d+ keepalive=(?P<ka>\d) (?P<v>\S+) syscalls/req \((?P<req>\d+) requests\):(?P<rest>.*)")


def short(v):
    v = re.sub(r"ruxen=\S*/ruxen-[0-9a-f]+", "ruxen", v)
    v = re.sub(r"nginx=\S*nginx", "nginx", v)
    return v


def comparisons(text):
    rows, label = [], None
    for line in text.splitlines():
        if line.startswith("=== ") or line.startswith("### "):
            label = line[4:].strip() if line.startswith("=== ") else line.strip("# ")
            if line.startswith("### "):
                rows.append(("section", label))
            continue
        if line.startswith("FAILED"):
            rows.append(("failed", line))
        m = RESULT.search(line)
        if m:
            rows.append(("row", label, m))
    return rows


def per_request(text):
    perf, sysc = {}, {}
    for line in text.splitlines():
        m = PERF.search(line)
        if m:
            perf.setdefault((m["ka"], short(m["v"])), []).append(
                tuple(int(m[x]) for x in "ukct"))
        m = SYS.search(line)
        if m:
            total = re.search(r"total ([\d.]+)", m["rest"])
            calls = re.sub(r"\s+total [\d.]+", "", m["rest"]).strip()
            sysc.setdefault((m["ka"], short(m["v"])), []).append(
                (float(total[1]) if total else 0.0, calls))
    return perf, sysc


def main():
    out = ["# Overnight measurements", ""]
    out.append("B/A is the geometric mean of the per-pair throughput ratios (8 pairs, "
               "each run 5 s warm-up + 10 s measured, alternating A B / B A); min-max are "
               "the extremes of the pair ratios; p50/p99 are wrk's latency percentiles, "
               "median over the pairs, in microseconds. The control against itself is the "
               "noise floor.")
    out.append("")
    for d in sys.argv[1:]:
        machine = os.path.basename(os.path.normpath(d))
        out += [f"## {machine}", ""]
        files = sorted(f for f in os.listdir(d) if re.match(r"\d\d-.*\.txt$", f))
        for f in files:
            text = open(os.path.join(d, f), errors="replace").read()
            head = text.splitlines()[1] if len(text.splitlines()) > 1 else ""
            name = f[3:-4]
            rows = comparisons(text)
            perf, sysc = per_request(text)
            if rows:
                out += [f"### {name}", "", f"`{head.lstrip('# ')}`", "",
                        "| comparison | B/A | min–max | p50 A / B | p99 A / B |",
                        "|---|---:|---:|---:|---:|"]
                for r in rows:
                    if r[0] == "section":
                        out.append(f"| **{r[1]}** | | | | |")
                    elif r[0] == "failed":
                        out.append(f"| {r[1]} | | | | |")
                    else:
                        m = r[2]
                        out.append(f"| {short(m['b'])} / {short(m['a'])} ({short(r[1] or '')}) "
                                   f"| {m['r']}% | {m['lo']}–{m['hi']} | {m['p50a']} / {m['p50b']} "
                                   f"| {m['p99a']} / {m['p99b']} |")
                out.append("")
            elif perf or sysc:
                out += [f"### {name}", "", f"`{head.lstrip('# ')}`", "",
                        "| variant | keep-alive | instr/req user | kernel | total | cycles/req | syscalls/req | calls |",
                        "|---|---|---:|---:|---:|---:|---:|---|"]
                for key in sorted(set(perf) | set(sysc), key=lambda k: (k[0], k[1])):
                    p = perf.get(key)
                    s = sysc.get(key)
                    med = (lambda i: str(int(statistics.median(x[i] for x in p)))) if p else (lambda i: "–")
                    st = f"{statistics.median(x[0] for x in s):.3f}" if s else "–"
                    calls = s[0][1] if s else ""
                    out.append(f"| {key[1]} | {'yes' if key[0] == '1' else 'no'} | {med(0)} | {med(1)} | "
                               f"{med(3)} | {med(2)} | {st} | {calls} |")
                out.append("")
            else:
                out += [f"### {name}", "", f"See `{machine}/{f}`.", ""]
    print("\n".join(out))


main()
