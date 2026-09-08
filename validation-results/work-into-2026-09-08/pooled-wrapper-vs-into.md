# Pooled work benchmark -- interleaved runs, three workloads reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so none is here.

- before: `new work.gd via the allocating wrappers` (4 driver runs)
- after: `new work.gd via the _into forms` (4 driver runs)
- two-sided permutation test on the difference of medians, 20000 permutations, seed 20260908
- generated: 2026-09-08T17:34:06.366605+00:00

| Config | Workload | Pop | Metric | n before/after | before median us (min-max) | after median us (min-max) | delta | permutation p |
|---|---|---|---|---|---|---|---|---|
| `wu` | bands | 256 | p99 1x | 8/8 | 1673.5 (1640-1728) | 1567.0 (1518-1620) | -6.36% | 0.0028 |
| `wu` | bands | 256 | p95 pair | 8/8 | 3269.0 (3203-3304) | 3048.5 (2969-3163) | -6.75% | 0.0041 |
| `wu` | party | 256 | p99 1x | 8/8 | 1290.5 (1276-1687) | 1255.5 (1240-1290) | -2.71% | 0.0056 |
| `wu` | party | 256 | p95 pair | 8/8 | 2518.0 (2477-2598) | 2449.0 (2425-2469) | -2.74% | 0.0037 |
| `wu` | uniform | 256 | p99 1x | 8/8 | 1941.5 (1908-1969) | 1835.0 (1804-1916) | -5.49% | 0.0032 |
| `wu` | uniform | 256 | p95 pair | 8/8 | 3494.5 (3436-3590) | 3259.0 (3222-3304) | -6.74% | 0.0037 |

## Driver runs pooled

| Side | Path | Started | work.gd SHA-256 | fixture SHA-256 | runner |
|---|---|---|---|---|---|
| before | `validation-results/work-into-2026-09-08/wrapctl-wrapper-1.json` | 2026-09-08T17:26:49.679386+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-wrapper-2.json` | 2026-09-08T17:28:19.038081+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-wrapper-3.json` | 2026-09-08T17:29:49.408297+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-wrapper-4.json` | 2026-09-08T17:31:19.202129+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-1.json` | 2026-09-08T17:27:20.051908+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-2.json` | 2026-09-08T17:28:49.662745+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-3.json` | 2026-09-08T17:30:20.119236+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-4.json` | 2026-09-08T17:31:49.782734+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |

