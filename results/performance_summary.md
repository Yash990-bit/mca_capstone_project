# Cache Performance Summary

> Generated automatically by `sim/parse_results.py`  
> Results are based on **actual simulation output** — not manually entered.

## Per-Trace Comparison

| Trace | Cache | Requests | Hits | Misses | Hit Rate | Miss Rate |
|:------|:------|:--------:|:----:|:------:|:--------:|:---------:|
| Sequential | 2-Way | 16 | 8 | 8 | 50% | 50% |
| Sequential | Direct | 16 | 8 | 8 | 50% | 50% |
| Repeated | 2-Way | 8 | 7 | 1 | 87% | 12% |
| Repeated | Direct | 8 | 7 | 1 | 87% | 12% |
| Conflict | 2-Way | 12 | 0 | 12 | 0% | 100% |
| Conflict | Direct | 12 | 0 | 12 | 0% | 100% |
| Mixed | 2-Way | 10 | 5 | 5 | 50% | 50% |
| Mixed | Direct | 10 | 3 | 7 | 30% | 70% |

## Overall Test Results

| Cache | Total Requests | Hits | Misses | Hit Rate | Miss Rate |
|:------|:--------------:|:----:|:------:|:--------:|:---------:|
| 2-Way Set-Associative | 71 | 33 | 38 | 46% | 54% |
| Direct-Mapped | 73 | 26 | 47 | 36% | 64% |

## Test Pass/Fail Summary

| Cache | Passed | Failed |
|:------|:------:|:------:|
| 2-Way Set-Associative | 18 | 0 |
| Direct-Mapped | 17 | 0 |

---
*Hit Rate = (Hits / Total Requests) × 100*
