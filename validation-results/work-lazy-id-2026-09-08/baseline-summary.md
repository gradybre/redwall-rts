# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T15:18:05.649965+00:00
- build: Editor binary, no export presets, empty export-template directory. These figures compare configurations against each other on one machine. They are not a release measurement and not the REQ-SET-163 qualification-floor measurement.

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 70/72 | 71.0 | 134/136 | 135.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 70/70 | 70.0 | 134/134 | 134.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 72/74 | 73.0 | 136/137 | 136.5 | - | - | - | - |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1250/1272 | 1261.0 | 2467/2497 | 2482.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 1256/1268 | 1262.0 | 2467/2485 | 2476.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 1282/1262 | 1272.0 | 2511/2480 | 2495.5 | - | - | - | - |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 140/139 | 139.5 | 257/244 | 250.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 145/146 | 145.5 | 259/262 | 260.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 116/117 | 116.5 | 211/212 | 211.5 | - | - | - | - |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 2614/2570 | 2592.0 | 5106/5045 | 5075.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 2988/2993 | 2990.5 | 5406/5428 | 5417.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 2104/2144 | 2124.0 | 4116/4120 | 4118.0 | - | - | - | - |

### `combined` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 217/213 | 215.0 | 398/390 | 394.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 213/214 | 213.5 | 394/393 | 393.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 199/193 | 196.0 | 364/360 | 362.0 | - | - | - | - |

### `combined` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 3818/3854 | 3836.0 | 7429/7514 | 7471.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 4185/4157 | 4171.0 | 7743/7708 | 7725.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 3380/3352 | 3366.0 | 6634/6556 | 6595.0 | - | - | - | - |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 137/138 | 137.5 | 239/237 | 238.0 | - | - | - | - |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 2277/3289 | 2783.0 | 4463/5806 | 5134.5 | - | - | - | - |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 275/289 | 282.0 | 431/449 | 440.0 | - | - | - | - |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 2337/2349 | 2343.0 | 4611/4638 | 4624.5 | - | - | - | - |

## Core sources timed

| File | this run | prior run |
|---|---|---|
| `scripts/core/catalog.gd` | `1237f9c6e4c99970` | `-` |
| `scripts/core/entity_directory.gd` | `c70773df0bf2cae7` | `-` |
| `scripts/core/int_math.gd` | `fba44816a36e9a2d` | `-` |
| `scripts/core/inventory.gd` | `640460a5ae4b9949` | `-` |
| `scripts/core/item_definitions.gd` | `4e745577260b8cbb` | `-` |
| `scripts/core/jobs.gd` | `abb1a2a509ff305e` | `-` |
| `scripts/core/needs.gd` | `3d601d8b6442f2ed` | `-` |
| `scripts/core/priorities.gd` | `ef5cfeb2deb574c3` | `-` |
| `scripts/core/reservations.gd` | `3211416652559e63` | `-` |
| `scripts/core/residents.gd` | `ae0844149659b903` | `-` |
| `scripts/core/schedule.gd` | `9da6ee9fde956812` | `-` |
| `scripts/core/sim_clock.gd` | `44ef99615ce2a054` | `-` |
| `scripts/core/work.gd` | `372d86d9511d9380` | `-` |

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

