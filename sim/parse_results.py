#!/usr/bin/env python3
"""
sim/parse_results.py
Parses vvp simulation log files and produces:
  - results/test_results.csv
  - results/performance_comparison.csv
  - results/performance_summary.md

Author : Kaavya (Verification Engineer)
"""

import re
import os
import sys

RESULTS_DIR = "results"
os.makedirs(RESULTS_DIR, exist_ok=True)

# ── helpers ──────────────────────────────────────────────────────────────────

def parse_log(log_path: str):
    """Return dict with test results and per-trace performance metrics."""
    if not os.path.exists(log_path):
        print(f"[WARN] Log not found: {log_path}")
        return None

    with open(log_path) as f:
        lines = f.readlines()

    tests = []           # list of (name, result)
    traces = {}          # trace_name -> {req, hits, misses, hit_rate, miss_rate}

    # Patterns
    test_re  = re.compile(r'\s+\[(PASS|FAIL)\]\s+(.*)')
    trace_re = re.compile(
        r'\s+(Sequential|Repeated|Conflict|Mixed)\s+\|\s+'
        r'Req=(\d+)\s+Hits=(\d+)\s+Misses=(\d+)\s+HitRate=(\d+)%\s+MissRate=(\d+)%'
    )
    overall_re = re.compile(
        r'Total Requests\s*:\s*(\d+)|'
        r'Cache Hits\s*:\s*(\d+)|'
        r'Cache Misses\s*:\s*(\d+)'
    )
    overall = {"total": None, "hits": None, "misses": None}
    ovr_keys = ["total", "hits", "misses"]
    ovr_idx  = 0

    for line in lines:
        m = test_re.match(line)
        if m:
            tests.append((m.group(2).strip(), m.group(1)))

        m = trace_re.match(line)
        if m:
            name = m.group(1)
            traces[name] = {
                "requests":  int(m.group(2)),
                "hits":      int(m.group(3)),
                "misses":    int(m.group(4)),
                "hit_rate":  int(m.group(5)),
                "miss_rate": int(m.group(6)),
            }

        m = overall_re.search(line)
        if m and ovr_idx < 3:
            val = next(v for v in m.groups() if v is not None)
            overall[ovr_keys[ovr_idx]] = int(val)
            ovr_idx += 1

    return {"tests": tests, "traces": traces, "overall": overall}


# ── run ───────────────────────────────────────────────────────────────────────

log_2way   = os.path.join(RESULTS_DIR, "sim_2way.log")
log_direct = os.path.join(RESULTS_DIR, "sim_direct.log")

data_2way   = parse_log(log_2way)
data_direct = parse_log(log_direct)

if data_2way is None and data_direct is None:
    print("[ERROR] No simulation logs found. Run sim/run_sim.sh first.")
    sys.exit(1)

# ── 1. test_results.csv ───────────────────────────────────────────────────────

csv_tests = os.path.join(RESULTS_DIR, "test_results.csv")
with open(csv_tests, "w") as f:
    f.write("Cache Type,Test Name,Result\n")
    if data_2way:
        for name, result in data_2way["tests"]:
            safe = name.replace('"', "'")
            f.write(f'2-Way Set-Associative,"{safe}",{result}\n')
    if data_direct:
        for name, result in data_direct["tests"]:
            safe = name.replace('"', "'")
            f.write(f'Direct-Mapped,"{safe}",{result}\n')

print(f"[OK] {csv_tests}")

# ── 2. performance_comparison.csv ────────────────────────────────────────────

trace_names = ["Sequential", "Repeated", "Conflict", "Mixed"]
csv_perf = os.path.join(RESULTS_DIR, "performance_comparison.csv")
with open(csv_perf, "w") as f:
    f.write("Trace,Cache Type,Total Requests,Hits,Misses,Hit Rate (%),Miss Rate (%)\n")
    for tr in trace_names:
        for label, data in [("2-Way Set-Associative", data_2way),
                             ("Direct-Mapped",         data_direct)]:
            if data and tr in data["traces"]:
                t = data["traces"][tr]
                f.write(
                    f'{tr},{label},{t["requests"]},'
                    f'{t["hits"]},{t["misses"]},'
                    f'{t["hit_rate"]},{t["miss_rate"]}\n'
                )
            else:
                f.write(f'{tr},{label},N/A,N/A,N/A,N/A,N/A\n')

print(f"[OK] {csv_perf}")

# ── 3. performance_summary.md ─────────────────────────────────────────────────

def fmt(data, trace, field):
    if data and trace in data.get("traces", {}):
        return str(data["traces"][trace][field])
    return "N/A"

md_path = os.path.join(RESULTS_DIR, "performance_summary.md")
with open(md_path, "w") as f:
    f.write("# Cache Performance Summary\n\n")
    f.write("> Generated automatically by `sim/parse_results.py`  \n")
    f.write("> Results are based on **actual simulation output** — not manually entered.\n\n")

    f.write("## Per-Trace Comparison\n\n")
    f.write("| Trace | Cache | Requests | Hits | Misses | Hit Rate | Miss Rate |\n")
    f.write("|:------|:------|:--------:|:----:|:------:|:--------:|:---------:|\n")
    for tr in trace_names:
        for label, data in [("2-Way", data_2way), ("Direct", data_direct)]:
            f.write(
                f"| {tr} | {label} "
                f"| {fmt(data, tr, 'requests')} "
                f"| {fmt(data, tr, 'hits')} "
                f"| {fmt(data, tr, 'misses')} "
                f"| {fmt(data, tr, 'hit_rate')}% "
                f"| {fmt(data, tr, 'miss_rate')}% |\n"
            )

    f.write("\n## Overall Test Results\n\n")
    f.write("| Cache | Total Requests | Hits | Misses | Hit Rate | Miss Rate |\n")
    f.write("|:------|:--------------:|:----:|:------:|:--------:|:---------:|\n")
    for label, data in [("2-Way Set-Associative", data_2way),
                         ("Direct-Mapped",         data_direct)]:
        if data and data["overall"]["total"]:
            ovr = data["overall"]
            hr = round(ovr["hits"]   * 100 / ovr["total"])
            mr = round(ovr["misses"] * 100 / ovr["total"])
            f.write(
                f'| {label} | {ovr["total"]} | {ovr["hits"]} | '
                f'{ovr["misses"]} | {hr}% | {mr}% |\n'
            )
        else:
            f.write(f"| {label} | N/A | N/A | N/A | N/A | N/A |\n")

    f.write("\n## Test Pass/Fail Summary\n\n")
    f.write("| Cache | Passed | Failed |\n")
    f.write("|:------|:------:|:------:|\n")
    for label, data in [("2-Way Set-Associative", data_2way),
                         ("Direct-Mapped",         data_direct)]:
        if data:
            passed = sum(1 for _, r in data["tests"] if r == "PASS")
            failed = sum(1 for _, r in data["tests"] if r == "FAIL")
            f.write(f"| {label} | {passed} | {failed} |\n")
        else:
            f.write(f"| {label} | N/A | N/A |\n")

    f.write("\n---\n*Hit Rate = (Hits / Total Requests) × 100*\n")

print(f"[OK] {md_path}")
print("Parse complete.")

