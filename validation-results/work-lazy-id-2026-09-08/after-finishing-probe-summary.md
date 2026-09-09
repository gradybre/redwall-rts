# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T15:39:46.756549+00:00
- build: Editor binary, no export presets, empty export-template directory. These figures compare configurations against each other on one machine. They are not a release measurement and not the REQ-SET-163 qualification-floor measurement.

Prior columns come from a separate driver run:
- prior fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- prior started: 2026-09-08T15:18:05.649965+00:00
- prior and current fixtures are byte-identical: True

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 72/69 | 70.5 | 137/136 | 136.5 | 73.0 | -3.4% | 136.5 | +0.0% |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1259/1260 | 1259.5 | 2481/2475 | 2478.0 | 1272.0 | -1.0% | 2495.5 | -0.7% |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 114/114 | 114.0 | 218/217 | 217.5 | 137.5 | -17.1% | 238.0 | -8.6% |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 2026/2160 | 2093.0 | 3963/3963 | 3963.0 | 2783.0 | -24.8% | 5134.5 | -22.8% |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 123/122 | 122.5 | 236/235 | 235.5 | 282.0 | -56.6% | 440.0 | -46.5% |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 2186/2197 | 2191.5 | 4327/4345 | 4336.0 | 2343.0 | -6.5% | 4624.5 | -6.2% |

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
| `needs` | party | 12 | True | `ea6a971a8d895944` |
| `needs` | party | 256 | True | `a544173849f5e112` |
| `party_fast` | party | 12 | True | `0262e9ccc199d4aa` |
| `party_fast` | party | 256 | True | `9fbb747dc8ccb8db` |
| `party_finish` | party | 12 | True | `53016279a98329b1` |
| `party_finish` | party | 256 | True | `7b8aa772d59675f4` |

