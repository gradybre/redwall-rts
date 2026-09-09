# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T16:21:20.115703+00:00
- runner: `editor` (editor); asserts live in the timed binary: True
- build: Editor binary, with assert() live. These figures compare configurations against each other on one machine. They are not a release measurement and not the REQ-SET-163 qualification-floor measurement.

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 69/70 | 69.5 | 126/129 | 127.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 71/68 | 69.5 | 126/126 | 126.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 73/69 | 71.0 | 129/128 | 128.5 | - | - | - | - |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1202/1190 | 1196.0 | 2346/2339 | 2342.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 1212/1179 | 1195.5 | 2331/2312 | 2321.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 1197/1234 | 1215.5 | 2357/2362 | 2359.5 | - | - | - | - |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 125/124 | 124.5 | 223/214 | 218.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 127/126 | 126.5 | 228/227 | 227.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 104/108 | 106.0 | 184/190 | 187.0 | - | - | - | - |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 2376/2357 | 2366.5 | 4513/4473 | 4493.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 2679/2645 | 2662.0 | 4851/4781 | 4816.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 1833/1766 | 1799.5 | 3488/3442 | 3465.0 | - | - | - | - |

### `combined` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 198/195 | 196.5 | 347/347 | 347.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 203/196 | 199.5 | 372/358 | 365.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 182/184 | 183.0 | 315/313 | 314.0 | - | - | - | - |

### `combined` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 3573/3542 | 3557.5 | 6821/6776 | 6798.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 3831/3805 | 3818.0 | 7144/7101 | 7122.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 2952/3093 | 3022.5 | 5771/6123 | 5947.0 | - | - | - | - |

### `loop` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1/1 | 1.0 | 2/2 | 2.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 1/1 | 1.0 | 1/2 | 1.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 1/1 | 1.0 | 1/1 | 1.0 | - | - | - | - |

### `loop` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 7/6 | 6.5 | 12/12 | 12.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 6/6 | 6.0 | 12/12 | 12.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 7/6 | 6.5 | 12/12 | 12.0 | - | - | - | - |

### `pid` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 11/12 | 11.5 | 22/22 | 22.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 11/11 | 11.0 | 21/22 | 21.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 11/11 | 11.0 | 22/21 | 21.5 | - | - | - | - |

### `pid` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 236/243 | 239.5 | 451/454 | 452.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 235/228 | 231.5 | 456/441 | 448.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 229/235 | 232.0 | 447/446 | 446.5 | - | - | - | - |

### `xp` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 23/23 | 23.0 | 45/44 | 44.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 21/21 | 21.0 | 41/41 | 41.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 23/23 | 23.0 | 45/45 | 45.0 | - | - | - | - |

### `xp` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 482/481 | 481.5 | 941/944 | 942.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 436/432 | 434.0 | 848/848 | 848.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 476/481 | 478.5 | 929/939 | 934.0 | - | - | - | - |

### `result` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 9/9 | 9.0 | 18/18 | 18.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 9/9 | 9.0 | 18/18 | 18.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 9/9 | 9.0 | 18/18 | 18.0 | - | - | - | - |

### `result` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 182/180 | 181.0 | 357/352 | 354.5 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 187/188 | 187.5 | 356/358 | 357.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 189/181 | 185.0 | 356/354 | 355.0 | - | - | - | - |

### `factor` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 34/33 | 33.5 | 66/64 | 65.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 34/34 | 34.0 | 67/66 | 66.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 33/34 | 33.5 | 65/66 | 65.5 | - | - | - | - |

### `factor` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 709/704 | 706.5 | 1392/1386 | 1389.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 707/716 | 711.5 | 1398/1410 | 1404.0 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 818/709 | 763.5 | 1538/1388 | 1463.0 | - | - | - | - |

### `gate` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 14/14 | 14.0 | 27/27 | 27.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 14/14 | 14.0 | 27/26 | 26.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 15/14 | 14.5 | 29/27 | 28.0 | - | - | - | - |

### `gate` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 288/287 | 287.5 | 545/539 | 542.0 | - | - | - | - |
| uniform, solo jobs -- synchronised XP/write burst | 292/284 | 288.0 | 549/534 | 541.5 | - | - | - | - |
| mixed bands, parties -- coordinator/member structure | 299/287 | 293.0 | 581/541 | 561.0 | - | - | - | - |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 123/117 | 120.0 | 219/212 | 215.5 | - | - | - | - |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1957/1972 | 1964.5 | 3801/3810 | 3805.5 | - | - | - | - |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 131/129 | 130.0 | 227/227 | 227.0 | - | - | - | - |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 2583/2108 | 2345.5 | 4516/4129 | 4322.5 | - | - | - | - |

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
| `loop` | uniform | 12 | True | `d946abcd3088bb90` |
| `loop` | uniform | 256 | True | `04376abaa09ecafa` |
| `loop` | bands | 12 | True | `273e4782f2070a7f` |
| `loop` | bands | 256 | True | `9a5b2e8f759bc512` |
| `loop` | party | 12 | True | `3849416a8b45a532` |
| `loop` | party | 256 | True | `142a062a126b248d` |
| `pid` | uniform | 12 | True | `d946abcd3088bb90` |
| `pid` | uniform | 256 | True | `04376abaa09ecafa` |
| `pid` | bands | 12 | True | `273e4782f2070a7f` |
| `pid` | bands | 256 | True | `9a5b2e8f759bc512` |
| `pid` | party | 12 | True | `3849416a8b45a532` |
| `pid` | party | 256 | True | `142a062a126b248d` |
| `xp` | uniform | 12 | True | `d946abcd3088bb90` |
| `xp` | uniform | 256 | True | `04376abaa09ecafa` |
| `xp` | bands | 12 | True | `273e4782f2070a7f` |
| `xp` | bands | 256 | True | `9a5b2e8f759bc512` |
| `xp` | party | 12 | True | `3849416a8b45a532` |
| `xp` | party | 256 | True | `142a062a126b248d` |
| `result` | uniform | 12 | True | `d946abcd3088bb90` |
| `result` | uniform | 256 | True | `04376abaa09ecafa` |
| `result` | bands | 12 | True | `273e4782f2070a7f` |
| `result` | bands | 256 | True | `9a5b2e8f759bc512` |
| `result` | party | 12 | True | `3849416a8b45a532` |
| `result` | party | 256 | True | `142a062a126b248d` |
| `factor` | uniform | 12 | True | `d946abcd3088bb90` |
| `factor` | uniform | 256 | True | `04376abaa09ecafa` |
| `factor` | bands | 12 | True | `273e4782f2070a7f` |
| `factor` | bands | 256 | True | `9a5b2e8f759bc512` |
| `factor` | party | 12 | True | `3849416a8b45a532` |
| `factor` | party | 256 | True | `142a062a126b248d` |
| `gate` | uniform | 12 | True | `d946abcd3088bb90` |
| `gate` | uniform | 256 | True | `04376abaa09ecafa` |
| `gate` | bands | 12 | True | `273e4782f2070a7f` |
| `gate` | bands | 256 | True | `9a5b2e8f759bc512` |
| `gate` | party | 12 | True | `3849416a8b45a532` |
| `gate` | party | 256 | True | `142a062a126b248d` |
| `party_fast` | party | 12 | True | `0262e9ccc199d4aa` |
| `party_fast` | party | 256 | True | `9fbb747dc8ccb8db` |
| `party_finish` | party | 12 | True | `53016279a98329b1` |
| `party_finish` | party | 256 | True | `7b8aa772d59675f4` |

