# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T17:14:06.787259+00:00
- runner: `release` (template_release); asserts live in the timed binary: False
- build: Exported release build (template_release), asserts proven compiled out: the probe evaluated 0 assert conditions in this binary against 3 in the editor control, and walked past a failing assert the editor control halted on. This is a release measurement on one machine. It is NOT the REQ-SET-163 qualification-floor measurement (Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080), and Windows is deferred.

Prior columns come from a separate driver run:
- prior runner: `release` (template_release)
- prior fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- prior started: 2026-09-08T17:11:23.147514+00:00
- prior and current fixtures are byte-identical: True

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 50/49 | 49.5 | 91/91 | 91.0 | 49.0 | +1.0% | 89.0 | +2.2% |
| uniform, solo jobs -- synchronised XP/write burst | 48/49 | 48.5 | 91/91 | 91.0 | 49.0 | -1.0% | 89.0 | +2.2% |
| mixed bands, parties -- coordinator/member structure | 48/51 | 49.5 | 91/92 | 91.5 | 49.5 | +0.0% | 92.0 | -0.5% |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 885/882 | 883.5 | 1703/1701 | 1702.0 | 881.5 | +0.2% | 1669.5 | +1.9% |
| uniform, solo jobs -- synchronised XP/write burst | 864/872 | 868.0 | 1677/1706 | 1691.5 | 847.0 | +2.5% | 1649.0 | +2.6% |
| mixed bands, parties -- coordinator/member structure | 878/865 | 871.5 | 1710/1685 | 1697.5 | 865.0 | +0.8% | 1671.5 | +1.6% |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 80/80 | 80.0 | 149/149 | 149.0 | 80.5 | -0.6% | 146.0 | +2.1% |
| uniform, solo jobs -- synchronised XP/write burst | 90/88 | 89.0 | 159/156 | 157.5 | 87.5 | +1.7% | 155.0 | +1.6% |
| mixed bands, parties -- coordinator/member structure | 69/70 | 69.5 | 128/129 | 128.5 | 69.5 | +0.0% | 126.5 | +1.6% |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1716/1604 | 1660.0 | 3197/3103 | 3150.0 | 1617.5 | +2.6% | 3073.0 | +2.5% |
| uniform, solo jobs -- synchronised XP/write burst | 1854/1860 | 1857.0 | 3339/3346 | 3342.5 | 1921.5 | -3.4% | 3428.5 | -2.5% |
| mixed bands, parties -- coordinator/member structure | 1286/1251 | 1268.5 | 2452/2435 | 2443.5 | 1242.0 | +2.1% | 2391.0 | +2.2% |

### `result` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 5/6 | 5.5 | 10/10 | 10.0 | 5.0 | +10.0% | 10.0 | +0.0% |
| uniform, solo jobs -- synchronised XP/write burst | 6/6 | 6.0 | 10/11 | 10.5 | 5.5 | +9.1% | 10.5 | +0.0% |
| mixed bands, parties -- coordinator/member structure | 6/6 | 6.0 | 10/10 | 10.0 | 6.0 | +0.0% | 10.5 | -4.8% |

### `result` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 111/109 | 110.0 | 205/203 | 204.0 | 109.5 | +0.5% | 200.5 | +1.7% |
| uniform, solo jobs -- synchronised XP/write burst | 112/114 | 113.0 | 202/200 | 201.0 | 114.0 | -0.9% | 199.0 | +1.0% |
| mixed bands, parties -- coordinator/member structure | 115/112 | 113.5 | 206/202 | 204.0 | 108.5 | +4.6% | 196.5 | +3.8% |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 81/79 | 80.0 | 145/144 | 144.5 | 78.0 | +2.6% | 141.0 | +2.5% |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1362/1360 | 1361.0 | 2634/2625 | 2629.5 | 1372.5 | -0.8% | 2600.0 | +1.1% |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 87/85 | 86.0 | 158/159 | 158.5 | 86.0 | +0.0% | 153.5 | +3.3% |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1475/1480 | 1477.5 | 2875/2887 | 2881.0 | 1463.0 | +1.0% | 2819.5 | +2.2% |

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

