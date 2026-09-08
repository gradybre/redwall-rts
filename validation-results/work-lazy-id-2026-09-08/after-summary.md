# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T15:32:34.943454+00:00
- build: Editor binary, no export presets, empty export-template directory. These figures compare configurations against each other on one machine. They are not a release measurement and not the REQ-SET-163 qualification-floor measurement.

Prior columns come from a separate driver run:
- prior fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- prior started: 2026-09-08T15:18:05.649965+00:00
- prior and current fixtures are byte-identical: True

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 71/73 | 72.0 | 130/130 | 130.0 | 71.0 | +1.4% | 135.0 | -3.7% |
| uniform, solo jobs -- synchronised XP/write burst | 71/70 | 70.5 | 128/129 | 128.5 | 70.0 | +0.7% | 134.0 | -4.1% |
| mixed bands, parties -- coordinator/member structure | 70/70 | 70.0 | 129/131 | 130.0 | 73.0 | -4.1% | 136.5 | -4.8% |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1205/1225 | 1215.0 | 2363/2374 | 2368.5 | 1261.0 | -3.6% | 2482.0 | -4.6% |
| uniform, solo jobs -- synchronised XP/write burst | 1200/1231 | 1215.5 | 2333/2339 | 2336.0 | 1262.0 | -3.7% | 2476.0 | -5.7% |
| mixed bands, parties -- coordinator/member structure | 1224/1227 | 1225.5 | 2359/2370 | 2364.5 | 1272.0 | -3.7% | 2495.5 | -5.2% |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 130/120 | 125.0 | 216/221 | 218.5 | 139.5 | -10.4% | 250.5 | -12.8% |
| uniform, solo jobs -- synchronised XP/write burst | 130/131 | 130.5 | 230/229 | 229.5 | 145.5 | -10.3% | 260.5 | -11.9% |
| mixed bands, parties -- coordinator/member structure | 105/100 | 102.5 | 188/185 | 186.5 | 116.5 | -12.0% | 211.5 | -11.8% |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 2486/2435 | 2460.5 | 4648/4591 | 4619.5 | 2592.0 | -5.1% | 5075.5 | -9.0% |
| uniform, solo jobs -- synchronised XP/write burst | 2699/2686 | 2692.5 | 4844/4816 | 4830.0 | 2990.5 | -10.0% | 5417.0 | -10.8% |
| mixed bands, parties -- coordinator/member structure | 1834/1811 | 1822.5 | 3536/3533 | 3534.5 | 2124.0 | -14.2% | 4118.0 | -14.2% |

### `combined` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 198/197 | 197.5 | 355/352 | 353.5 | 215.0 | -8.1% | 394.0 | -10.3% |
| uniform, solo jobs -- synchronised XP/write burst | 202/202 | 202.0 | 370/369 | 369.5 | 213.5 | -5.4% | 393.5 | -6.1% |
| mixed bands, parties -- coordinator/member structure | 186/183 | 184.5 | 323/323 | 323.0 | 196.0 | -5.9% | 362.0 | -10.8% |

### `combined` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 3580/3628 | 3604.0 | 6961/7043 | 7002.0 | 3836.0 | -6.0% | 7471.5 | -6.3% |
| uniform, solo jobs -- synchronised XP/write burst | 3899/3878 | 3888.5 | 7179/7177 | 7178.0 | 4171.0 | -6.8% | 7725.5 | -7.1% |
| mixed bands, parties -- coordinator/member structure | 3050/3100 | 3075.0 | 5948/6054 | 6001.0 | 3366.0 | -8.6% | 6595.0 | -9.0% |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 124/124 | 124.0 | 219/214 | 216.5 | 137.5 | -9.8% | 238.0 | -9.0% |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1966/1993 | 1979.5 | 3848/3878 | 3863.0 | 2783.0 | -28.9% | 5134.5 | -24.8% |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 136/139 | 137.5 | 229/234 | 231.5 | 282.0 | -51.2% | 440.0 | -47.4% |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 2277/2132 | 2204.5 | 4281/4195 | 4238.0 | 2343.0 | -5.9% | 4624.5 | -8.4% |

## Core sources timed

| File | this run | prior run |
|---|---|---|
| `scripts/core/catalog.gd` | `1237f9c6e4c99970` | `1237f9c6e4c99970` |
| `scripts/core/entity_directory.gd` | `c70773df0bf2cae7` | `c70773df0bf2cae7` |
| `scripts/core/int_math.gd` | `fba44816a36e9a2d` | `fba44816a36e9a2d` |
| `scripts/core/inventory.gd` | `640460a5ae4b9949` | `640460a5ae4b9949` |
| `scripts/core/item_definitions.gd` | `4e745577260b8cbb` | `4e745577260b8cbb` |
| `scripts/core/jobs.gd` | `873ae548eac451f7` | `abb1a2a509ff305e` |
| `scripts/core/needs.gd` | `3d601d8b6442f2ed` | `3d601d8b6442f2ed` |
| `scripts/core/priorities.gd` | `ef5cfeb2deb574c3` | `ef5cfeb2deb574c3` |
| `scripts/core/reservations.gd` | `3211416652559e63` | `3211416652559e63` |
| `scripts/core/residents.gd` | `ae0844149659b903` | `ae0844149659b903` |
| `scripts/core/schedule.gd` | `9da6ee9fde956812` | `9da6ee9fde956812` |
| `scripts/core/sim_clock.gd` | `44ef99615ce2a054` | `44ef99615ce2a054` |
| `scripts/core/work.gd` | `efeea4965e30c2c8` | `372d86d9511d9380` |

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

