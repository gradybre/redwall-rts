# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `373984edc73253660026cf8d576f1d640cb13610f513385a0fd4ce0d29ba2472`
- subprocess bound: 120 s
- started: 2026-09-08T18:30:46.103476+00:00
- runner: `release` (template_release); asserts live in the timed binary: False
- build: Exported release build (template_release), asserts proven compiled out: the probe evaluated 0 assert conditions in this binary against 3 in the editor control, and walked past a failing assert the editor control halted on. This is a release measurement on one machine. It is NOT the REQ-SET-163 qualification-floor measurement (Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080), and Windows is deferred.

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1525/1539 | 1532.0 | 2899/2888 | 2893.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 1765/1745 | 1755.0 | 3152/3120 | 3136.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 1237/1247 | 1242.0 | 2377/2389 | 2383.0 | - | - | - | - |

### `factor` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 548/480 | 514.0 | 1060/924 | 992.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 483/483 | 483.0 | 933/929 | 931.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 481/482 | 481.5 | 934/925 | 929.5 | - | - | - | - |

### `dirctl` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 266/266 | 266.0 | 496/497 | 496.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 267/266 | 266.5 | 501/496 | 498.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 267/263 | 265.0 | 514/496 | 505.0 | - | - | - | - |

### `prioctl` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 830/836 | 833.0 | 1604/1634 | 1619.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 853/817 | 835.0 | 1661/1594 | 1627.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 819/821 | 820.0 | 1593/1607 | 1600.0 | - | - | - | - |

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
| `scripts/core/work.gd` | `e15d149387046410` | `-` |

## Determinism digests

| Config | Workload | Population | repetitions agree | final digest |
|---|---|---|---|---|
| `wu` | bands | 256 | True | `bbc36cf7828a5c90` |
| `wu` | uniform | 256 | True | `e261bb3e72163350` |
| `wu` | party | 256 | True | `bc13c46bb6325eef` |
| `factor` | bands | 256 | True | `9a5b2e8f759bc512` |
| `factor` | uniform | 256 | True | `04376abaa09ecafa` |
| `factor` | party | 256 | True | `142a062a126b248d` |
| `dirctl` | bands | 256 | True | `9a5b2e8f759bc512` |
| `dirctl` | uniform | 256 | True | `04376abaa09ecafa` |
| `dirctl` | party | 256 | True | `142a062a126b248d` |
| `prioctl` | bands | 256 | True | `9a5b2e8f759bc512` |
| `prioctl` | uniform | 256 | True | `04376abaa09ecafa` |
| `prioctl` | party | 256 | True | `142a062a126b248d` |

