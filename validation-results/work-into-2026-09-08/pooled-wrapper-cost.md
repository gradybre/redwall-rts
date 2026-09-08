# Pooled work benchmark -- interleaved runs, three workloads reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so none is here.

- before: `old work.gd, fixture calls tick_solo()/tick_party()` (4 driver runs)
- after: `new work.gd, fixture STILL calls the allocating wrappers` (4 driver runs)
- two-sided permutation test on the difference of medians, 20000 permutations, seed 20260908
- generated: 2026-09-08T17:34:06.032992+00:00

| Config | Workload | Pop | Metric | n before/after | before median us (min-max) | after median us (min-max) | delta | permutation p |
|---|---|---|---|---|---|---|---|---|
| `wu` | bands | 256 | p99 1x | 8/8 | 1646.5 (1601-1782) | 1673.5 (1640-1728) | +1.64% | 0.1300 |
| `wu` | bands | 256 | p95 pair | 8/8 | 3207.0 (3123-3478) | 3269.0 (3203-3304) | +1.93% | 0.0726 |
| `wu` | party | 256 | p99 1x | 8/8 | 1281.5 (1248-1293) | 1290.5 (1276-1687) | +0.70% | 0.2830 |
| `wu` | party | 256 | p95 pair | 8/8 | 2500.0 (2433-2521) | 2518.0 (2477-2598) | +0.72% | 0.2383 |
| `wu` | uniform | 256 | p99 1x | 8/8 | 1898.0 (1852-1913) | 1941.5 (1908-1969) | +2.29% | 0.0043 |
| `wu` | uniform | 256 | p95 pair | 8/8 | 3408.5 (3335-3440) | 3494.5 (3436-3590) | +2.52% | 0.0027 |

## Driver runs pooled

| Side | Path | Started | work.gd SHA-256 | fixture SHA-256 | runner |
|---|---|---|---|---|---|
| before | `validation-results/work-into-2026-09-08/wrapctl-before-1.json` | 2026-09-08T17:26:19.936630+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-before-2.json` | 2026-09-08T17:27:48.797652+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-before-3.json` | 2026-09-08T17:29:18.818725+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-before-4.json` | 2026-09-08T17:30:48.981355+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-wrapper-1.json` | 2026-09-08T17:26:49.679386+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-wrapper-2.json` | 2026-09-08T17:28:19.038081+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-wrapper-3.json` | 2026-09-08T17:29:49.408297+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-wrapper-4.json` | 2026-09-08T17:31:19.202129+00:00 | `e15d149387046410` | `a73f265f290dd419` | `release` |

