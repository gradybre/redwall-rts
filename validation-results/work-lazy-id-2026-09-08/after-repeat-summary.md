# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T15:36:04.889924+00:00
- build: Editor binary, no export presets, empty export-template directory. These figures compare configurations against each other on one machine. They are not a release measurement and not the REQ-SET-163 qualification-floor measurement.

Prior columns come from a separate driver run:
- prior fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- prior started: 2026-09-08T15:32:34.943454+00:00
- prior and current fixtures are byte-identical: True

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 71/69 | 70.0 | 131/131 | 131.0 | 72.0 | -2.8% | 130.0 | +0.8% |
| uniform, solo jobs -- synchronised XP/write burst | 68/69 | 68.5 | 126/127 | 126.5 | 70.5 | -2.8% | 128.5 | -1.6% |
| mixed bands, parties -- coordinator/member structure | 71/70 | 70.5 | 131/132 | 131.5 | 70.0 | +0.7% | 130.0 | +1.2% |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1231/1243 | 1237.0 | 2408/2422 | 2415.0 | 1215.0 | +1.8% | 2368.5 | +2.0% |
| uniform, solo jobs -- synchronised XP/write burst | 1261/1240 | 1250.5 | 2458/2403 | 2430.5 | 1215.5 | +2.9% | 2336.0 | +4.0% |
| mixed bands, parties -- coordinator/member structure | 1256/1235 | 1245.5 | 2445/2430 | 2437.5 | 1225.5 | +1.6% | 2364.5 | +3.1% |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 125/129 | 127.0 | 218/218 | 218.0 | 125.0 | +1.6% | 218.5 | -0.2% |
| uniform, solo jobs -- synchronised XP/write burst | 132/132 | 132.0 | 231/230 | 230.5 | 130.5 | +1.1% | 229.5 | +0.4% |
| mixed bands, parties -- coordinator/member structure | 104/101 | 102.5 | 186/187 | 186.5 | 102.5 | +0.0% | 186.5 | +0.0% |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 2428/2373 | 2400.5 | 4706/4598 | 4652.0 | 2460.5 | -2.4% | 4619.5 | +0.7% |
| uniform, solo jobs -- synchronised XP/write burst | 2714/2699 | 2706.5 | 4873/4867 | 4870.0 | 2692.5 | +0.5% | 4830.0 | +0.8% |
| mixed bands, parties -- coordinator/member structure | 1842/1836 | 1839.0 | 3586/3552 | 3569.0 | 1822.5 | +0.9% | 3534.5 | +1.0% |

### `combined` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 202/202 | 202.0 | 361/358 | 359.5 | 197.5 | +2.3% | 353.5 | +1.7% |
| uniform, solo jobs -- synchronised XP/write burst | 201/201 | 201.0 | 367/369 | 368.0 | 202.0 | -0.5% | 369.5 | -0.4% |
| mixed bands, parties -- coordinator/member structure | 174/171 | 172.5 | 335/333 | 334.0 | 184.5 | -6.5% | 323.0 | +3.4% |

### `combined` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 3651/3662 | 3656.5 | 7168/7224 | 7196.0 | 3604.0 | +1.5% | 7002.0 | +2.8% |
| uniform, solo jobs -- synchronised XP/write burst | 3927/3909 | 3918.0 | 7227/7237 | 7232.0 | 3888.5 | +0.8% | 7178.0 | +0.8% |
| mixed bands, parties -- coordinator/member structure | 3121/4339 | 3730.0 | 6160/8251 | 7205.5 | 3075.0 | +21.3% | 6001.0 | +20.1% |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 209/246 | 227.5 | 317/366 | 341.5 | 124.0 | +83.5% | 216.5 | +57.7% |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 3063/3025 | 3044.0 | 5810/5773 | 5791.5 | 1979.5 | +53.8% | 3863.0 | +49.9% |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 224/252 | 238.0 | 341/374 | 357.5 | 137.5 | +73.1% | 231.5 | +54.4% |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 3341/3437 | 3389.0 | 6252/6359 | 6305.5 | 2204.5 | +53.7% | 4238.0 | +48.8% |

## Core sources timed

| File | this run | prior run |
|---|---|---|
| `scripts/core/catalog.gd` | `1237f9c6e4c99970` | `1237f9c6e4c99970` |
| `scripts/core/entity_directory.gd` | `c70773df0bf2cae7` | `c70773df0bf2cae7` |
| `scripts/core/int_math.gd` | `fba44816a36e9a2d` | `fba44816a36e9a2d` |
| `scripts/core/inventory.gd` | `640460a5ae4b9949` | `640460a5ae4b9949` |
| `scripts/core/item_definitions.gd` | `4e745577260b8cbb` | `4e745577260b8cbb` |
| `scripts/core/jobs.gd` | `873ae548eac451f7` | `873ae548eac451f7` |
| `scripts/core/needs.gd` | `3d601d8b6442f2ed` | `3d601d8b6442f2ed` |
| `scripts/core/priorities.gd` | `ef5cfeb2deb574c3` | `ef5cfeb2deb574c3` |
| `scripts/core/reservations.gd` | `3211416652559e63` | `3211416652559e63` |
| `scripts/core/residents.gd` | `ae0844149659b903` | `ae0844149659b903` |
| `scripts/core/schedule.gd` | `9da6ee9fde956812` | `9da6ee9fde956812` |
| `scripts/core/sim_clock.gd` | `44ef99615ce2a054` | `44ef99615ce2a054` |
| `scripts/core/work.gd` | `efeea4965e30c2c8` | `efeea4965e30c2c8` |

## Determinism digests

| Config | Workload | Population | repetitions agree | final digest |
|---|---|---|---|---|
| `needs` | uniform | 12 | True | `f2012cd81d25340f` |
| `needs` | uniform | 256 | True | `64f769bd9d8f3ede` |
| `needs` | bands | 12 | True | `c1f4e99a9c1a4737` |
| `needs` | bands | 256 | True | `ae1aaec9b96d5c4a` |
| `needs` | party | 12 | True | `ea6a971a8d895944` |
| `needs` | party | 256 | True | `a544173849f5e112` |
| `wu` | uniform | 12 | True | `bc2bef7d0acb2348` |
| `wu` | uniform | 256 | True | `e261bb3e72163350` |
| `wu` | bands | 12 | True | `d75a6fcf3f191a8a` |
| `wu` | bands | 256 | True | `bbc36cf7828a5c90` |
| `wu` | party | 12 | True | `adb14e25023718b4` |
| `wu` | party | 256 | True | `bc13c46bb6325eef` |
| `combined` | uniform | 12 | True | `f469d38446ac735b` |
| `combined` | uniform | 256 | True | `cf1ad31d790243ea` |
| `combined` | bands | 12 | True | `6397bde42edd0cc0` |
| `combined` | bands | 256 | True | `040d60d4d5f76546` |
| `combined` | party | 12 | True | `6f8e0152f62f7728` |
| `combined` | party | 256 | True | `ca24ee1624cbc6c1` |
| `party_fast` | party | 12 | True | `0262e9ccc199d4aa` |
| `party_fast` | party | 256 | True | `9fbb747dc8ccb8db` |
| `party_finish` | party | 12 | True | `53016279a98329b1` |
| `party_finish` | party | 256 | True | `7b8aa772d59675f4` |

