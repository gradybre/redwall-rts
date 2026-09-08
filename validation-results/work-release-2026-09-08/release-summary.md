# Work benchmark -- three workloads, reported independently

Decision 0024 section 3 forbids combining these into one weighted score without an
explicitly defined workload distribution. No such distribution exists, so no
combined figure is produced here.

- protocol: `redwall-work-benchmark-v1/sha256/utf8-canonical-lines`
- nearest rank, 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration
- fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- subprocess bound: 120 s
- started: 2026-09-08T16:25:15.357759+00:00
- runner: `release` (template_release); asserts live in the timed binary: False
- build: Exported release build (template_release), asserts proven compiled out: the probe evaluated 0 assert conditions in this binary against 3 in the editor control, and walked past a failing assert the editor control halted on. This is a release measurement on one machine. It is NOT the REQ-SET-163 qualification-floor measurement (Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080), and Windows is deferred.

Prior columns come from a separate driver run:
- prior runner: `editor` (editor)
- prior fixture SHA-256: `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
- prior started: 2026-09-08T16:21:20.115703+00:00
- prior and current fixtures are byte-identical: True

### `needs` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 51/49 | 50.0 | 92/92 | 92.0 | 69.5 | -28.1% | 127.5 | -27.8% |
| uniform, solo jobs -- synchronised XP/write burst | 50/53 | 51.5 | 92/96 | 94.0 | 69.5 | -25.9% | 126.0 | -25.4% |
| mixed bands, parties -- coordinator/member structure | 50/50 | 50.0 | 93/92 | 92.5 | 71.0 | -29.6% | 128.5 | -28.0% |

### `needs` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 875/870 | 872.5 | 1707/1701 | 1704.0 | 1196.0 | -27.0% | 2342.5 | -27.3% |
| uniform, solo jobs -- synchronised XP/write burst | 866/863 | 864.5 | 1694/1687 | 1690.5 | 1195.5 | -27.7% | 2321.5 | -27.2% |
| mixed bands, parties -- coordinator/member structure | 881/925 | 903.0 | 1721/1746 | 1733.5 | 1215.5 | -25.7% | 2359.5 | -26.5% |

### `wu` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 82/81 | 81.5 | 150/152 | 151.0 | 124.5 | -34.5% | 218.5 | -30.9% |
| uniform, solo jobs -- synchronised XP/write burst | 90/91 | 90.5 | 159/161 | 160.0 | 126.5 | -28.5% | 227.5 | -29.7% |
| mixed bands, parties -- coordinator/member structure | 71/70 | 70.5 | 131/130 | 130.5 | 106.0 | -33.5% | 187.0 | -30.2% |

### `wu` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1607/1665 | 1636.0 | 3126/3165 | 3145.5 | 2366.5 | -30.9% | 4493.0 | -30.0% |
| uniform, solo jobs -- synchronised XP/write burst | 1850/1868 | 1859.0 | 3336/3349 | 3342.5 | 2662.0 | -30.2% | 4816.0 | -30.6% |
| mixed bands, parties -- coordinator/member structure | 1274/1322 | 1298.0 | 2461/2515 | 2488.0 | 1799.5 | -27.9% | 3465.0 | -28.2% |

### `combined` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 144/136 | 140.0 | 246/253 | 249.5 | 196.5 | -28.8% | 347.0 | -28.1% |
| uniform, solo jobs -- synchronised XP/write burst | 140/141 | 140.5 | 252/253 | 252.5 | 199.5 | -29.6% | 365.0 | -30.8% |
| mixed bands, parties -- coordinator/member structure | 130/128 | 129.0 | 222/225 | 223.5 | 183.0 | -29.5% | 314.0 | -28.8% |

### `combined` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 2462/2534 | 2498.0 | 4835/4876 | 4855.5 | 3557.5 | -29.8% | 6798.5 | -28.6% |
| uniform, solo jobs -- synchronised XP/write burst | 2704/2695 | 2699.5 | 5011/4992 | 5001.5 | 3818.0 | -29.3% | 7122.5 | -29.8% |
| mixed bands, parties -- coordinator/member structure | 2159/2162 | 2160.5 | 4178/4169 | 4173.5 | 3022.5 | -28.5% | 5947.0 | -29.8% |

### `loop` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 1/1 | 1.0 | 1/1 | 1.0 | 1.0 | +0.0% | 2.0 | -50.0% |
| uniform, solo jobs -- synchronised XP/write burst | 1/1 | 1.0 | 1/1 | 1.0 | 1.0 | +0.0% | 1.5 | -33.3% |
| mixed bands, parties -- coordinator/member structure | 1/1 | 1.0 | 1/1 | 1.0 | 1.0 | +0.0% | 1.0 | +0.0% |

### `loop` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 5/5 | 5.0 | 8/9 | 8.5 | 6.5 | -23.1% | 12.0 | -29.2% |
| uniform, solo jobs -- synchronised XP/write burst | 5/5 | 5.0 | 9/8 | 8.5 | 6.0 | -16.7% | 12.0 | -29.2% |
| mixed bands, parties -- coordinator/member structure | 5/5 | 5.0 | 8/8 | 8.0 | 6.5 | -23.1% | 12.0 | -33.3% |

### `pid` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 8/7 | 7.5 | 14/14 | 14.0 | 11.5 | -34.8% | 22.0 | -36.4% |
| uniform, solo jobs -- synchronised XP/write burst | 7/8 | 7.5 | 14/14 | 14.0 | 11.0 | -31.8% | 21.5 | -34.9% |
| mixed bands, parties -- coordinator/member structure | 7/8 | 7.5 | 14/14 | 14.0 | 11.0 | -31.8% | 21.5 | -34.9% |

### `pid` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 158/162 | 160.0 | 284/285 | 284.5 | 239.5 | -33.2% | 452.5 | -37.1% |
| uniform, solo jobs -- synchronised XP/write burst | 162/164 | 163.0 | 283/286 | 284.5 | 231.5 | -29.6% | 448.5 | -36.6% |
| mixed bands, parties -- coordinator/member structure | 161/161 | 161.0 | 289/290 | 289.5 | 232.0 | -30.6% | 446.5 | -35.2% |

### `xp` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 15/15 | 15.0 | 30/30 | 30.0 | 23.0 | -34.8% | 44.5 | -32.6% |
| uniform, solo jobs -- synchronised XP/write burst | 14/14 | 14.0 | 27/27 | 27.0 | 21.0 | -33.3% | 41.0 | -34.1% |
| mixed bands, parties -- coordinator/member structure | 15/16 | 15.5 | 30/30 | 30.0 | 23.0 | -32.6% | 45.0 | -33.3% |

### `xp` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 324/327 | 325.5 | 615/617 | 616.0 | 481.5 | -32.4% | 942.5 | -34.6% |
| uniform, solo jobs -- synchronised XP/write burst | 297/297 | 297.0 | 560/560 | 560.0 | 434.0 | -31.6% | 848.0 | -34.0% |
| mixed bands, parties -- coordinator/member structure | 324/326 | 325.0 | 614/613 | 613.5 | 478.5 | -32.1% | 934.0 | -34.3% |

### `result` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 6/6 | 6.0 | 10/11 | 10.5 | 9.0 | -33.3% | 18.0 | -41.7% |
| uniform, solo jobs -- synchronised XP/write burst | 6/6 | 6.0 | 10/11 | 10.5 | 9.0 | -33.3% | 18.0 | -41.7% |
| mixed bands, parties -- coordinator/member structure | 6/6 | 6.0 | 11/10 | 10.5 | 9.0 | -33.3% | 18.0 | -41.7% |

### `result` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 107/111 | 109.0 | 201/200 | 200.5 | 181.0 | -39.8% | 354.5 | -43.4% |
| uniform, solo jobs -- synchronised XP/write burst | 111/125 | 118.0 | 205/233 | 219.0 | 187.5 | -37.1% | 357.0 | -38.7% |
| mixed bands, parties -- coordinator/member structure | 115/113 | 114.0 | 203/206 | 204.5 | 185.0 | -38.4% | 355.0 | -42.4% |

### `factor` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 24/25 | 24.5 | 45/46 | 45.5 | 33.5 | -26.9% | 65.0 | -30.0% |
| uniform, solo jobs -- synchronised XP/write burst | 23/24 | 23.5 | 45/45 | 45.0 | 34.0 | -30.9% | 66.5 | -32.3% |
| mixed bands, parties -- coordinator/member structure | 24/27 | 25.5 | 46/46 | 46.0 | 33.5 | -23.9% | 65.5 | -29.8% |

### `factor` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 489/486 | 487.5 | 952/936 | 944.0 | 706.5 | -31.0% | 1389.0 | -32.0% |
| uniform, solo jobs -- synchronised XP/write burst | 486/493 | 489.5 | 936/944 | 940.0 | 711.5 | -31.2% | 1404.0 | -33.0% |
| mixed bands, parties -- coordinator/member structure | 487/502 | 494.5 | 938/968 | 953.0 | 763.5 | -35.2% | 1463.0 | -34.9% |

### `gate` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 9/9 | 9.0 | 18/18 | 18.0 | 14.0 | -35.7% | 27.0 | -33.3% |
| uniform, solo jobs -- synchronised XP/write burst | 9/9 | 9.0 | 18/18 | 18.0 | 14.0 | -35.7% | 26.5 | -32.1% |
| mixed bands, parties -- coordinator/member structure | 9/9 | 9.0 | 18/17 | 17.5 | 14.5 | -37.9% | 28.0 | -37.5% |

### `gate` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, solo jobs -- ordinary-play comparison | 200/199 | 199.5 | 370/359 | 364.5 | 287.5 | -30.6% | 542.0 | -32.7% |
| uniform, solo jobs -- synchronised XP/write burst | 197/196 | 196.5 | 356/362 | 359.0 | 288.0 | -31.8% | 541.5 | -33.7% |
| mixed bands, parties -- coordinator/member structure | 199/199 | 199.0 | 361/362 | 361.5 | 293.0 | -32.1% | 561.0 | -35.6% |

### `party_fast` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 79/78 | 78.5 | 145/145 | 145.0 | 120.0 | -34.6% | 215.5 | -32.7% |

### `party_fast` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1349/1373 | 1361.0 | 2628/2659 | 2643.5 | 1964.5 | -30.7% | 3805.5 | -30.5% |

### `party_finish` at population 12

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 87/84 | 85.5 | 158/157 | 157.5 | 130.0 | -34.2% | 227.0 | -30.6% |

### `party_finish` at population 256

| Workload | p99 1x per rep (us) | p99 mean | p95 pair per rep (us) | pair mean | prior p99 mean | p99 delta | prior pair mean | pair delta |
|---|---|---|---|---|---|---|---|---|
| mixed bands, parties -- coordinator/member structure | 1497/1500 | 1498.5 | 2881/2910 | 2895.5 | 2345.5 | -36.1% | 4322.5 | -33.0% |

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

