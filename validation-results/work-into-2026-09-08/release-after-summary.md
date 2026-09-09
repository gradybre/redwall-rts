# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `226b6d7c06480a7f60beba8ee9c697574ebea0506c9e38c80e77fefc353e95be`
- subprocess bound: 120 s
- started: 2026-09-08T17:12:45.518247+00:00
- runner: `release` (template_release); asserts live in the timed binary: False
- build: Exported release build (template_release), asserts proven compiled out: the probe evaluated 0 assert conditions in this binary against 3 in the editor control, and walked past a failing assert the editor control halted on. This is a release measurement on one machine. It is NOT the REQ-SET-163 qualification-floor measurement (Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080), and Windows is deferred.

Prior columns come from a separate driver run:
- prior runner: `release` (template_release)
- prior fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- prior started: 2026-09-08T17:11:23.147514+00:00
- prior and current fixtures are byte-identical: False

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 49/49 | 49.0 | 90/89 | 89.5 | 49.0 | +0.0% | 89.0 | +0.6% |
| uniform, solo jobs -- synchronised XP/write burst | 49/48 | 48.5 | 89/89 | 89.0 | 49.0 | -1.0% | 89.0 | +0.0% |
| mixed bands, parties -- coordinator/member structure | 50/50 | 50.0 | 94/91 | 92.5 | 49.5 | +1.0% | 92.0 | +0.5% |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 886/853 | 869.5 | 1722/1662 | 1692.0 | 881.5 | -1.4% | 1669.5 | +1.3% |
| uniform, solo jobs -- synchronised XP/write burst | 922/864 | 893.0 | 1676/1667 | 1671.5 | 847.0 | +5.4% | 1649.0 | +1.4% |
| mixed bands, parties -- coordinator/member structure | 864/870 | 867.0 | 1688/1698 | 1693.0 | 865.0 | +0.2% | 1671.5 | +1.3% |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 75/75 | 75.0 | 138/139 | 138.5 | 80.5 | -6.8% | 146.0 | -5.1% |
| uniform, solo jobs -- synchronised XP/write burst | 84/89 | 86.5 | 147/157 | 152.0 | 87.5 | -1.1% | 155.0 | -1.9% |
| mixed bands, parties -- coordinator/member structure | 66/68 | 67.0 | 122/123 | 122.5 | 69.5 | -3.6% | 126.5 | -3.2% |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1786/1563 | 1674.5 | 3366/2982 | 3174.0 | 1617.5 | +3.5% | 3073.0 | +3.3% |
| uniform, solo jobs -- synchronised XP/write burst | 1881/1766 | 1823.5 | 3336/3158 | 3247.0 | 1921.5 | -5.1% | 3428.5 | -5.3% |
| mixed bands, parties -- coordinator/member structure | 1233/1221 | 1227.0 | 2360/2365 | 2362.5 | 1242.0 | -1.2% | 2391.0 | -1.2% |

### `result` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 6/6 | 6.0 | 10/10 | 10.0 | 5.0 | +20.0% | 10.0 | +0.0% |
| uniform, solo jobs -- synchronised XP/write burst | 6/6 | 6.0 | 10/10 | 10.0 | 5.5 | +9.1% | 10.5 | -4.8% |
| mixed bands, parties -- coordinator/member structure | 5/5 | 5.0 | 10/10 | 10.0 | 6.0 | -16.7% | 10.5 | -4.8% |

### `result` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 109/107 | 108.0 | 202/201 | 201.5 | 109.5 | -1.4% | 200.5 | +0.5% |
| uniform, solo jobs -- synchronised XP/write burst | 109/114 | 111.5 | 199/205 | 202.0 | 114.0 | -2.2% | 199.0 | +1.5% |
| mixed bands, parties -- coordinator/member structure | 111/117 | 114.0 | 200/205 | 202.5 | 108.5 | +5.1% | 196.5 | +3.1% |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 76/75 | 75.5 | 141/139 | 140.0 | 78.0 | -3.2% | 141.0 | -0.7% |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1310/1354 | 1332.0 | 2562/2600 | 2581.0 | 1372.5 | -3.0% | 2600.0 | -0.7% |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 84/87 | 85.5 | 156/153 | 154.5 | 86.0 | -0.6% | 153.5 | +0.7% |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1463/1462 | 1462.5 | 2819/2823 | 2821.0 | 1463.0 | -0.0% | 2819.5 | +0.1% |

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
| `scripts/core/work.gd` | `e15d149387046410` | `efeea4965e30c2c8` |

## Determinism digests

| Config | Workload | Population | repetitions agree | final digest |
|---|---|---|---|---|
| `needs` | bands | 12 | True | `c1f4e99a9c1a4737` |
| `needs` | bands | 256 | True | `ae1aaec9b96d5c4a` |
| `needs` | uniform | 12 | True | `f2012cd81d25340f` |
| `needs` | uniform | 256 | True | `64f769bd9d8f3ede` |
| `needs` | party | 12 | True | `ea6a971a8d895944` |
| `needs` | party | 256 | True | `a544173849f5e112` |
| `wu` | bands | 12 | True | `d75a6fcf3f191a8a` |
| `wu` | bands | 256 | True | `bbc36cf7828a5c90` |
| `wu` | uniform | 12 | True | `bc2bef7d0acb2348` |
| `wu` | uniform | 256 | True | `e261bb3e72163350` |
| `wu` | party | 12 | True | `adb14e25023718b4` |
| `wu` | party | 256 | True | `bc13c46bb6325eef` |
| `result` | bands | 12 | True | `273e4782f2070a7f` |
| `result` | bands | 256 | True | `9a5b2e8f759bc512` |
| `result` | uniform | 12 | True | `d946abcd3088bb90` |
| `result` | uniform | 256 | True | `04376abaa09ecafa` |
| `result` | party | 12 | True | `3849416a8b45a532` |
| `result` | party | 256 | True | `142a062a126b248d` |
| `party_fast` | party | 12 | True | `0262e9ccc199d4aa` |
| `party_fast` | party | 256 | True | `9fbb747dc8ccb8db` |
| `party_finish` | party | 12 | True | `53016279a98329b1` |
| `party_finish` | party | 256 | True | `7b8aa772d59675f4` |

