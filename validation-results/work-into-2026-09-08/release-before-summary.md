# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T17:11:23.147514+00:00
- runner: `release` (template_release); asserts live in the timed binary: False
- build: Exported release build (template_release), asserts proven compiled out: the probe evaluated 0 assert conditions in this binary against 3 in the editor control, and walked past a failing assert the editor control halted on. This is a release measurement on one machine. It is NOT the REQ-SET-163 qualification-floor measurement (Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080), and Windows is deferred.

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 49/49 | 49.0 | 89/89 | 89.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 51/47 | 49.0 | 90/88 | 89.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 52/47 | 49.5 | 95/89 | 92.0 | - | - | - | - |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 883/880 | 881.5 | 1675/1664 | 1669.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 843/851 | 847.0 | 1646/1652 | 1649.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 875/855 | 865.0 | 1674/1669 | 1671.5 | - | - | - | - |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 79/82 | 80.5 | 146/146 | 146.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 87/88 | 87.5 | 155/155 | 155.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 68/71 | 69.5 | 125/128 | 126.5 | - | - | - | - |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1627/1608 | 1617.5 | 3087/3059 | 3073.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 1833/2010 | 1921.5 | 3316/3541 | 3428.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 1257/1227 | 1242.0 | 2404/2378 | 2391.0 | - | - | - | - |

### `result` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 5/5 | 5.0 | 10/10 | 10.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 6/5 | 5.5 | 11/10 | 10.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 6/6 | 6.0 | 10/11 | 10.5 | - | - | - | - |

### `result` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 112/107 | 109.5 | 200/201 | 200.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 112/116 | 114.0 | 196/202 | 199.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 107/110 | 108.5 | 196/197 | 196.5 | - | - | - | - |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 80/76 | 78.0 | 142/140 | 141.0 | - | - | - | - |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1387/1358 | 1372.5 | 2615/2585 | 2600.0 | - | - | - | - |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 87/85 | 86.0 | 153/154 | 153.5 | - | - | - | - |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1437/1489 | 1463.0 | 2808/2831 | 2819.5 | - | - | - | - |

## Core sources timed

| File | this run | prior run |
|---|---|---|
| `scripts/core/catalog.gd` | `1237f9c6e4c99970` | `-` |
| `scripts/core/entity_directory.gd` | `c70773df0bf2cae7` | `-` |
| `scripts/core/int_math.gd` | `fba44816a36e9a2d` | `-` |
| `scripts/core/inventory.gd` | `640460a5ae4b9949` | `-` |
| `scripts/core/item_definitions.gd` | `4e745577260b8cbb` | `-` |
| `scripts/core/jobs.gd` | `873ae548eac451f7` | `-` |
| `scripts/core/needs.gd` | `3d601d8b6442f2ed` | `-` |
| `scripts/core/priorities.gd` | `ef5cfeb2deb574c3` | `-` |
| `scripts/core/reservations.gd` | `3211416652559e63` | `-` |
| `scripts/core/residents.gd` | `ae0844149659b903` | `-` |
| `scripts/core/schedule.gd` | `9da6ee9fde956812` | `-` |
| `scripts/core/sim_clock.gd` | `44ef99615ce2a054` | `-` |
| `scripts/core/work.gd` | `efeea4965e30c2c8` | `-` |

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

