# Pooled work benchmark -- interleaved runs, three workloads reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so none is here.

- before: `before 0024 s4: work.gd reads health, mood and the factor separately` (10 driver runs)
- after: `after 0024 s4: needs.work_factor_for_resident_into(), one call per resident` (10 driver runs)
- two-sided permutation test on the difference of medians, 20000 permutations, seed 20260908
- generated: 2026-09-08T18:53:03.984311+00:00

| Config | Workload | Pop | Metric | n before/after | before median us (min-max) | after median us (min-max) | delta | permutation p |
|---|---|---|---|---|---|---|---|---|
| `dirctl` (drift control) | bands | 256 | p99 1x | 20/20 | 270.0 (267-301) | 269.0 (267-283) | -0.37% | 0.5953 |
| `dirctl` (drift control) | bands | 256 | p95 pair | 20/20 | 505.5 (498-574) | 501.5 (498-549) | -0.79% | 0.1738 |
| `dirctl` (drift control) | party | 256 | p99 1x | 20/20 | 268.5 (266-293) | 269.0 (266-274) | +0.19% | 0.7563 |
| `dirctl` (drift control) | party | 256 | p95 pair | 20/20 | 503.5 (498-540) | 502.5 (498-516) | -0.20% | 0.7610 |
| `dirctl` (drift control) | uniform | 256 | p99 1x | 20/20 | 269.0 (266-291) | 270.0 (266-282) | +0.37% | 0.5230 |
| `dirctl` (drift control) | uniform | 256 | p95 pair | 20/20 | 504.0 (498-568) | 505.0 (499-523) | +0.20% | 0.5658 |
| `factor` | bands | 256 | p99 1x | 20/20 | 488.5 (483-503) | 502.5 (495-527) | +2.87% | 0.0001 |
| `factor` | bands | 256 | p95 pair | 20/20 | 943.0 (931-964) | 969.5 (953-996) | +2.81% | 0.0000 |
| `factor` | party | 256 | p99 1x | 20/20 | 487.5 (483-640) | 504.0 (497-512) | +3.38% | 0.0001 |
| `factor` | party | 256 | p95 pair | 20/20 | 940.5 (931-1261) | 971.0 (959-997) | +3.24% | 0.0000 |
| `factor` | uniform | 256 | p99 1x | 20/20 | 488.0 (483-503) | 505.0 (499-524) | +3.48% | 0.0000 |
| `factor` | uniform | 256 | p95 pair | 20/20 | 942.5 (933-968) | 978.0 (965-1009) | +3.77% | 0.0000 |
| `prioctl` (drift control) | bands | 256 | p99 1x | 20/20 | 832.0 (810-1052) | 830.5 (812-1065) | -0.18% | 0.8155 |
| `prioctl` (drift control) | bands | 256 | p95 pair | 20/20 | 1622.0 (1584-2034) | 1617.5 (1583-2093) | -0.28% | 0.8920 |
| `prioctl` (drift control) | party | 256 | p99 1x | 20/20 | 827.5 (815-1028) | 838.5 (819-1097) | +1.33% | 0.0105 |
| `prioctl` (drift control) | party | 256 | p95 pair | 20/20 | 1614.5 (1590-1718) | 1638.0 (1596-2144) | +1.46% | 0.0270 |
| `prioctl` (drift control) | uniform | 256 | p99 1x | 20/20 | 834.5 (817-1007) | 842.5 (821-1102) | +0.96% | 0.2265 |
| `prioctl` (drift control) | uniform | 256 | p95 pair | 20/20 | 1621.0 (1593-1695) | 1639.5 (1599-2062) | +1.14% | 0.0988 |
| `wu` | bands | 256 | p99 1x | 20/20 | 1536.5 (1519-1632) | 1515.0 (1495-1609) | -1.40% | 0.0007 |
| `wu` | bands | 256 | p95 pair | 20/20 | 2972.5 (2943-3038) | 2942.5 (2902-3149) | -1.01% | 0.0115 |
| `wu` | party | 256 | p99 1x | 20/20 | 1248.0 (1221-1292) | 1228.0 (1204-1286) | -1.60% | 0.0005 |
| `wu` | party | 256 | p95 pair | 20/20 | 2417.5 (2372-2459) | 2381.5 (2333-2494) | -1.49% | 0.0004 |
| `wu` | uniform | 256 | p99 1x | 20/20 | 1787.0 (1763-1820) | 1767.5 (1749-1848) | -1.09% | 0.0040 |
| `wu` | uniform | 256 | p95 pair | 20/20 | 3187.0 (3152-3262) | 3147.5 (3110-3391) | -1.24% | 0.0014 |

## Driver runs pooled

| Side | Path | Started | work.gd SHA-256 | fixture SHA-256 | runner |
|---|---|---|---|---|---|
| before | `validation-results/work-fused-2026-09-08/interleaved-before-1.json` | 2026-09-08T18:31:58.350616+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-10.json` | 2026-09-08T18:50:47.315364+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-2.json` | 2026-09-08T18:34:03.290070+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-3.json` | 2026-09-08T18:36:09.917792+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-4.json` | 2026-09-08T18:38:16.489592+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-5.json` | 2026-09-08T18:40:22.087602+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-6.json` | 2026-09-08T18:42:27.529878+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-7.json` | 2026-09-08T18:44:32.748653+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-8.json` | 2026-09-08T18:46:37.402850+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| before | `validation-results/work-fused-2026-09-08/interleaved-before-9.json` | 2026-09-08T18:48:42.101158+00:00 | `e15d149387046410` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-1.json` | 2026-09-08T18:33:00.927027+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-10.json` | 2026-09-08T18:51:49.443846+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-2.json` | 2026-09-08T18:35:06.376092+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-3.json` | 2026-09-08T18:37:13.713491+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-4.json` | 2026-09-08T18:39:19.237798+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-5.json` | 2026-09-08T18:41:24.691210+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-6.json` | 2026-09-08T18:43:30.147509+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-7.json` | 2026-09-08T18:45:35.299896+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-8.json` | 2026-09-08T18:47:39.727751+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |
| after | `validation-results/work-fused-2026-09-08/interleaved-after-9.json` | 2026-09-08T18:49:44.465134+00:00 | `6bfeccedef1de679` | `373984edc7325366` | `release` |

