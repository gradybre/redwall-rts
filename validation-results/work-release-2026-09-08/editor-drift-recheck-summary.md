# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T16:28:00.386467+00:00
- runner: `editor` (editor); asserts live in the timed binary: True
- build: Editor binary, with assert() live. These figures compare configurations against each other on one machine. They are not a release measurement and not the REQ-SET-163 qualification-floor measurement.

Prior columns come from a separate driver run:
- prior runner: `editor` (editor)
- prior fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- prior started: 2026-09-08T16:21:20.115703+00:00
- prior and current fixtures are byte-identical: True

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 87/70 | 78.5 | 133/132 | 132.5 | 69.5 | +12.9% | 127.5 | +3.9% |
| uniform, solo jobs -- synchronised XP/write burst | 70/68 | 69.0 | 130/129 | 129.5 | 69.5 | -0.7% | 126.0 | +2.8% |
| mixed bands, parties -- coordinator/member structure | 70/70 | 70.0 | 134/132 | 133.0 | 71.0 | -1.4% | 128.5 | +3.5% |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1229/1270 | 1249.5 | 2408/2445 | 2426.5 | 1196.0 | +4.5% | 2342.5 | +3.6% |
| uniform, solo jobs -- synchronised XP/write burst | 1288/1238 | 1263.0 | 2424/2411 | 2417.5 | 1195.5 | +5.6% | 2321.5 | +4.1% |
| mixed bands, parties -- coordinator/member structure | 1227/1237 | 1232.0 | 2406/2434 | 2420.0 | 1215.5 | +1.4% | 2359.5 | +2.6% |

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

