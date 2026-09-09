# Pooled work benchmark -- interleaved runs, three workloads reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so none is here.

- before: `work.gd before 0024 s2, fixture calls tick_solo()/tick_party()` (10 driver runs)
- after: `work.gd with _into, fixture calls tick_solo_into()/tick_party_into()` (10 driver runs)
- two-sided permutation test on the difference of medians, 20000 permutations, seed 20260908
- generated: 2026-09-08T17:33:58.413456+00:00

| Config | Workload | Pop | Metric | n before/after | before median us (min-max) | after median us (min-max) | delta | permutation p |
|---|---|---|---|---|---|---|---|---|
| `needs` (drift control) | bands | 256 | p99 1x | 12/12 | 888.0 (870-945) | 889.5 (873-893) | +0.17% | 0.7199 |
| `needs` (drift control) | bands | 256 | p95 pair | 12/12 | 1734.5 (1680-1762) | 1743.0 (1698-1749) | +0.49% | 0.3242 |
| `needs` (drift control) | party | 256 | p99 1x | 12/12 | 887.0 (860-1036) | 886.0 (870-924) | -0.11% | 0.8390 |
| `needs` (drift control) | party | 256 | p95 pair | 12/12 | 1739.0 (1679-2003) | 1736.5 (1702-1789) | -0.14% | 0.7611 |
| `needs` (drift control) | uniform | 256 | p99 1x | 12/12 | 879.0 (860-921) | 882.5 (872-910) | +0.40% | 0.4950 |
| `needs` (drift control) | uniform | 256 | p95 pair | 12/12 | 1718.0 (1662-1749) | 1724.0 (1690-1740) | +0.35% | 0.1859 |
| `wu` | bands | 256 | p99 1x | 20/20 | 1637.5 (1601-1782) | 1558.0 (1518-1620) | -4.85% | 0.0000 |
| `wu` | bands | 256 | p95 pair | 20/20 | 3204.5 (3123-3478) | 3035.5 (2948-3163) | -5.27% | 0.0000 |
| `wu` | party | 256 | p99 1x | 20/20 | 1277.5 (1248-1310) | 1256.0 (1240-1328) | -1.68% | 0.0004 |
| `wu` | party | 256 | p95 pair | 20/20 | 2492.0 (2433-2521) | 2449.5 (2410-2597) | -1.71% | 0.0003 |
| `wu` | uniform | 256 | p99 1x | 20/20 | 1895.5 (1852-1913) | 1810.5 (1777-1916) | -4.48% | 0.0000 |
| `wu` | uniform | 256 | p95 pair | 20/20 | 3400.0 (3320-3440) | 3234.5 (3186-3304) | -4.87% | 0.0000 |

## Driver runs pooled

| Side | Path | Started | work.gd SHA-256 | fixture SHA-256 | runner |
|---|---|---|---|---|---|
| before | `validation-results/work-into-2026-09-08/interleaved-before-1.json` | 2026-09-08T17:15:59.226300+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/interleaved-before-2.json` | 2026-09-08T17:17:33.299804+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/interleaved-before-3.json` | 2026-09-08T17:19:08.124610+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/interleaved-before-4.json` | 2026-09-08T17:20:43.099624+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/interleaved-before-5.json` | 2026-09-08T17:22:18.233435+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/interleaved-before-6.json` | 2026-09-08T17:23:53.573577+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-before-1.json` | 2026-09-08T17:26:19.936630+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-before-2.json` | 2026-09-08T17:27:48.797652+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-before-3.json` | 2026-09-08T17:29:18.818725+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| before | `validation-results/work-into-2026-09-08/wrapctl-before-4.json` | 2026-09-08T17:30:48.981355+00:00 | `efeea4965e30c2c8` | `a73f265f290dd419` | `release` |
| after | `validation-results/work-into-2026-09-08/interleaved-after-1.json` | 2026-09-08T17:16:46.618297+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/interleaved-after-2.json` | 2026-09-08T17:18:21.315830+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/interleaved-after-3.json` | 2026-09-08T17:19:56.237032+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/interleaved-after-4.json` | 2026-09-08T17:21:31.427726+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/interleaved-after-5.json` | 2026-09-08T17:23:06.590536+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/interleaved-after-6.json` | 2026-09-08T17:24:41.814986+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-1.json` | 2026-09-08T17:27:20.051908+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-2.json` | 2026-09-08T17:28:49.662745+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-3.json` | 2026-09-08T17:30:20.119236+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |
| after | `validation-results/work-into-2026-09-08/wrapctl-after-4.json` | 2026-09-08T17:31:49.782734+00:00 | `e15d149387046410` | `226b6d7c06480a7f` | `release` |

