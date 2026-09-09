# Work benchmark — two runs side by side

- **editor** — runner `editor` (editor), asserts live in the timed binary: True
  - started 2026-09-08T16:21:20.115703+00:00, fixture SHA-256 `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
  - 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration, nearest rank
  - Editor binary, with assert() live. These figures compare configurations against each other on one machine. They are not a release measurement and not the REQ-SET-163 qualification-floor measurement.
- **release** — runner `release` (template_release), asserts live in the timed binary: False
  - started 2026-09-08T16:25:15.357759+00:00, fixture SHA-256 `a73f265f290dd41968cb726167ed81ab01e3d89947451a303ec84bacdec3795a`
  - 300 warm-up ticks discarded, 3000 sampled, 2 independent processes per configuration, nearest rank
  - Exported release build (template_release), asserts proven compiled out: the probe evaluated 0 assert conditions in this binary against 3 in the editor control, and walked past a failing assert the editor control halted on. This is a release measurement on one machine. It is NOT the REQ-SET-163 qualification-floor measurement (Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB at 1920x1080), and Windows is deferred.

- both runs timed a byte-identical fixture: True
- both runs timed byte-identical core sources: True

Decision 0024 section 3 forbids combining the three workloads into one weighted score without an explicitly defined workload distribution. None exists, so none is produced here.

No figure in this document is a REQ-SET-163 qualification-floor measurement: the floor is a Ryzen 5 3600 / GTX 1660 Super 6GB / 16GB machine at 1920x1080, and Windows remains deferred.

## Did the ranking change?

| workload | population | baseline order | candidate order | same order |
|---|---|---|---|---|
| mixed bands, solo jobs | 256 | factor > xp > gate > pid > result | factor > xp > gate > pid > result | True |
| uniform, solo jobs | 256 | factor > xp > gate > pid > result | factor > xp > gate > pid > result | True |
| mixed bands, parties | 256 | factor > xp > gate > pid > result | factor > xp > gate > pid > result | True |
| mixed bands, solo jobs | 12 | factor > xp > gate > pid > result | factor > xp > gate > pid > result | True |
| uniform, solo jobs | 12 | factor > xp > gate > pid > result | factor > xp > gate > pid > result | True |
| mixed bands, parties | 12 | factor > xp > gate > pid > result | factor > xp > gate > pid > result | True |

## p99 at 1x (us)

### Population 256

| config | workload | editor per rep | editor mean | release per rep | release mean | change |
|---|---|---|---|---|---|---|
| `needs` | mixed bands, solo jobs | 1202/1190 | 1196.0 | 875/870 | 872.5 | -27.0% |
| `needs` | uniform, solo jobs | 1212/1179 | 1195.5 | 866/863 | 864.5 | -27.7% |
| `needs` | mixed bands, parties | 1197/1234 | 1215.5 | 881/925 | 903.0 | -25.7% |
| `wu` | mixed bands, solo jobs | 2376/2357 | 2366.5 | 1607/1665 | 1636.0 | -30.9% |
| `wu` | uniform, solo jobs | 2679/2645 | 2662.0 | 1850/1868 | 1859.0 | -30.2% |
| `wu` | mixed bands, parties | 1833/1766 | 1799.5 | 1274/1322 | 1298.0 | -27.9% |
| `combined` | mixed bands, solo jobs | 3573/3542 | 3557.5 | 2462/2534 | 2498.0 | -29.8% |
| `combined` | uniform, solo jobs | 3831/3805 | 3818.0 | 2704/2695 | 2699.5 | -29.3% |
| `combined` | mixed bands, parties | 2952/3093 | 3022.5 | 2159/2162 | 2160.5 | -28.5% |
| `loop` | mixed bands, solo jobs | 7/6 | 6.5 | 5/5 | 5.0 | -23.1% |
| `loop` | uniform, solo jobs | 6/6 | 6.0 | 5/5 | 5.0 | -16.7% |
| `loop` | mixed bands, parties | 7/6 | 6.5 | 5/5 | 5.0 | -23.1% |
| `pid` | mixed bands, solo jobs | 236/243 | 239.5 | 158/162 | 160.0 | -33.2% |
| `pid` | uniform, solo jobs | 235/228 | 231.5 | 162/164 | 163.0 | -29.6% |
| `pid` | mixed bands, parties | 229/235 | 232.0 | 161/161 | 161.0 | -30.6% |
| `xp` | mixed bands, solo jobs | 482/481 | 481.5 | 324/327 | 325.5 | -32.4% |
| `xp` | uniform, solo jobs | 436/432 | 434.0 | 297/297 | 297.0 | -31.6% |
| `xp` | mixed bands, parties | 476/481 | 478.5 | 324/326 | 325.0 | -32.1% |
| `result` | mixed bands, solo jobs | 182/180 | 181.0 | 107/111 | 109.0 | -39.8% |
| `result` | uniform, solo jobs | 187/188 | 187.5 | 111/125 | 118.0 | -37.1% |
| `result` | mixed bands, parties | 189/181 | 185.0 | 115/113 | 114.0 | -38.4% |
| `factor` | mixed bands, solo jobs | 709/704 | 706.5 | 489/486 | 487.5 | -31.0% |
| `factor` | uniform, solo jobs | 707/716 | 711.5 | 486/493 | 489.5 | -31.2% |
| `factor` | mixed bands, parties | 818/709 | 763.5 | 487/502 | 494.5 | -35.2% |
| `gate` | mixed bands, solo jobs | 288/287 | 287.5 | 200/199 | 199.5 | -30.6% |
| `gate` | uniform, solo jobs | 292/284 | 288.0 | 197/196 | 196.5 | -31.8% |
| `gate` | mixed bands, parties | 299/287 | 293.0 | 199/199 | 199.0 | -32.1% |
| `party_fast` | mixed bands, parties | 1957/1972 | 1964.5 | 1349/1373 | 1361.0 | -30.7% |
| `party_finish` | mixed bands, parties | 2583/2108 | 2345.5 | 1497/1500 | 1498.5 | -36.1% |

### Population 12

| config | workload | editor per rep | editor mean | release per rep | release mean | change |
|---|---|---|---|---|---|---|
| `needs` | mixed bands, solo jobs | 69/70 | 69.5 | 51/49 | 50.0 | -28.1% |
| `needs` | uniform, solo jobs | 71/68 | 69.5 | 50/53 | 51.5 | -25.9% |
| `needs` | mixed bands, parties | 73/69 | 71.0 | 50/50 | 50.0 | -29.6% |
| `wu` | mixed bands, solo jobs | 125/124 | 124.5 | 82/81 | 81.5 | -34.5% |
| `wu` | uniform, solo jobs | 127/126 | 126.5 | 90/91 | 90.5 | -28.5% |
| `wu` | mixed bands, parties | 104/108 | 106.0 | 71/70 | 70.5 | -33.5% |
| `combined` | mixed bands, solo jobs | 198/195 | 196.5 | 144/136 | 140.0 | -28.8% |
| `combined` | uniform, solo jobs | 203/196 | 199.5 | 140/141 | 140.5 | -29.6% |
| `combined` | mixed bands, parties | 182/184 | 183.0 | 130/128 | 129.0 | -29.5% |
| `loop` | mixed bands, solo jobs | 1/1 | 1.0 | 1/1 | 1.0 | +0.0% |
| `loop` | uniform, solo jobs | 1/1 | 1.0 | 1/1 | 1.0 | +0.0% |
| `loop` | mixed bands, parties | 1/1 | 1.0 | 1/1 | 1.0 | +0.0% |
| `pid` | mixed bands, solo jobs | 11/12 | 11.5 | 8/7 | 7.5 | -34.8% |
| `pid` | uniform, solo jobs | 11/11 | 11.0 | 7/8 | 7.5 | -31.8% |
| `pid` | mixed bands, parties | 11/11 | 11.0 | 7/8 | 7.5 | -31.8% |
| `xp` | mixed bands, solo jobs | 23/23 | 23.0 | 15/15 | 15.0 | -34.8% |
| `xp` | uniform, solo jobs | 21/21 | 21.0 | 14/14 | 14.0 | -33.3% |
| `xp` | mixed bands, parties | 23/23 | 23.0 | 15/16 | 15.5 | -32.6% |
| `result` | mixed bands, solo jobs | 9/9 | 9.0 | 6/6 | 6.0 | -33.3% |
| `result` | uniform, solo jobs | 9/9 | 9.0 | 6/6 | 6.0 | -33.3% |
| `result` | mixed bands, parties | 9/9 | 9.0 | 6/6 | 6.0 | -33.3% |
| `factor` | mixed bands, solo jobs | 34/33 | 33.5 | 24/25 | 24.5 | -26.9% |
| `factor` | uniform, solo jobs | 34/34 | 34.0 | 23/24 | 23.5 | -30.9% |
| `factor` | mixed bands, parties | 33/34 | 33.5 | 24/27 | 25.5 | -23.9% |
| `gate` | mixed bands, solo jobs | 14/14 | 14.0 | 9/9 | 9.0 | -35.7% |
| `gate` | uniform, solo jobs | 14/14 | 14.0 | 9/9 | 9.0 | -35.7% |
| `gate` | mixed bands, parties | 15/14 | 14.5 | 9/9 | 9.0 | -37.9% |
| `party_fast` | mixed bands, parties | 123/117 | 120.0 | 79/78 | 78.5 | -34.6% |
| `party_finish` | mixed bands, parties | 131/129 | 130.0 | 87/84 | 85.5 | -34.2% |

## p95 pair proxy (us)

### Population 256

| config | workload | editor per rep | editor mean | release per rep | release mean | change |
|---|---|---|---|---|---|---|
| `needs` | mixed bands, solo jobs | 2346/2339 | 2342.5 | 1707/1701 | 1704.0 | -27.3% |
| `needs` | uniform, solo jobs | 2331/2312 | 2321.5 | 1694/1687 | 1690.5 | -27.2% |
| `needs` | mixed bands, parties | 2357/2362 | 2359.5 | 1721/1746 | 1733.5 | -26.5% |
| `wu` | mixed bands, solo jobs | 4513/4473 | 4493.0 | 3126/3165 | 3145.5 | -30.0% |
| `wu` | uniform, solo jobs | 4851/4781 | 4816.0 | 3336/3349 | 3342.5 | -30.6% |
| `wu` | mixed bands, parties | 3488/3442 | 3465.0 | 2461/2515 | 2488.0 | -28.2% |
| `combined` | mixed bands, solo jobs | 6821/6776 | 6798.5 | 4835/4876 | 4855.5 | -28.6% |
| `combined` | uniform, solo jobs | 7144/7101 | 7122.5 | 5011/4992 | 5001.5 | -29.8% |
| `combined` | mixed bands, parties | 5771/6123 | 5947.0 | 4178/4169 | 4173.5 | -29.8% |
| `loop` | mixed bands, solo jobs | 12/12 | 12.0 | 8/9 | 8.5 | -29.2% |
| `loop` | uniform, solo jobs | 12/12 | 12.0 | 9/8 | 8.5 | -29.2% |
| `loop` | mixed bands, parties | 12/12 | 12.0 | 8/8 | 8.0 | -33.3% |
| `pid` | mixed bands, solo jobs | 451/454 | 452.5 | 284/285 | 284.5 | -37.1% |
| `pid` | uniform, solo jobs | 456/441 | 448.5 | 283/286 | 284.5 | -36.6% |
| `pid` | mixed bands, parties | 447/446 | 446.5 | 289/290 | 289.5 | -35.2% |
| `xp` | mixed bands, solo jobs | 941/944 | 942.5 | 615/617 | 616.0 | -34.6% |
| `xp` | uniform, solo jobs | 848/848 | 848.0 | 560/560 | 560.0 | -34.0% |
| `xp` | mixed bands, parties | 929/939 | 934.0 | 614/613 | 613.5 | -34.3% |
| `result` | mixed bands, solo jobs | 357/352 | 354.5 | 201/200 | 200.5 | -43.4% |
| `result` | uniform, solo jobs | 356/358 | 357.0 | 205/233 | 219.0 | -38.7% |
| `result` | mixed bands, parties | 356/354 | 355.0 | 203/206 | 204.5 | -42.4% |
| `factor` | mixed bands, solo jobs | 1392/1386 | 1389.0 | 952/936 | 944.0 | -32.0% |
| `factor` | uniform, solo jobs | 1398/1410 | 1404.0 | 936/944 | 940.0 | -33.0% |
| `factor` | mixed bands, parties | 1538/1388 | 1463.0 | 938/968 | 953.0 | -34.9% |
| `gate` | mixed bands, solo jobs | 545/539 | 542.0 | 370/359 | 364.5 | -32.7% |
| `gate` | uniform, solo jobs | 549/534 | 541.5 | 356/362 | 359.0 | -33.7% |
| `gate` | mixed bands, parties | 581/541 | 561.0 | 361/362 | 361.5 | -35.6% |
| `party_fast` | mixed bands, parties | 3801/3810 | 3805.5 | 2628/2659 | 2643.5 | -30.5% |
| `party_finish` | mixed bands, parties | 4516/4129 | 4322.5 | 2881/2910 | 2895.5 | -33.0% |

### Population 12

| config | workload | editor per rep | editor mean | release per rep | release mean | change |
|---|---|---|---|---|---|---|
| `needs` | mixed bands, solo jobs | 126/129 | 127.5 | 92/92 | 92.0 | -27.8% |
| `needs` | uniform, solo jobs | 126/126 | 126.0 | 92/96 | 94.0 | -25.4% |
| `needs` | mixed bands, parties | 129/128 | 128.5 | 93/92 | 92.5 | -28.0% |
| `wu` | mixed bands, solo jobs | 223/214 | 218.5 | 150/152 | 151.0 | -30.9% |
| `wu` | uniform, solo jobs | 228/227 | 227.5 | 159/161 | 160.0 | -29.7% |
| `wu` | mixed bands, parties | 184/190 | 187.0 | 131/130 | 130.5 | -30.2% |
| `combined` | mixed bands, solo jobs | 347/347 | 347.0 | 246/253 | 249.5 | -28.1% |
| `combined` | uniform, solo jobs | 372/358 | 365.0 | 252/253 | 252.5 | -30.8% |
| `combined` | mixed bands, parties | 315/313 | 314.0 | 222/225 | 223.5 | -28.8% |
| `loop` | mixed bands, solo jobs | 2/2 | 2.0 | 1/1 | 1.0 | -50.0% |
| `loop` | uniform, solo jobs | 1/2 | 1.5 | 1/1 | 1.0 | -33.3% |
| `loop` | mixed bands, parties | 1/1 | 1.0 | 1/1 | 1.0 | +0.0% |
| `pid` | mixed bands, solo jobs | 22/22 | 22.0 | 14/14 | 14.0 | -36.4% |
| `pid` | uniform, solo jobs | 21/22 | 21.5 | 14/14 | 14.0 | -34.9% |
| `pid` | mixed bands, parties | 22/21 | 21.5 | 14/14 | 14.0 | -34.9% |
| `xp` | mixed bands, solo jobs | 45/44 | 44.5 | 30/30 | 30.0 | -32.6% |
| `xp` | uniform, solo jobs | 41/41 | 41.0 | 27/27 | 27.0 | -34.1% |
| `xp` | mixed bands, parties | 45/45 | 45.0 | 30/30 | 30.0 | -33.3% |
| `result` | mixed bands, solo jobs | 18/18 | 18.0 | 10/11 | 10.5 | -41.7% |
| `result` | uniform, solo jobs | 18/18 | 18.0 | 10/11 | 10.5 | -41.7% |
| `result` | mixed bands, parties | 18/18 | 18.0 | 11/10 | 10.5 | -41.7% |
| `factor` | mixed bands, solo jobs | 66/64 | 65.0 | 45/46 | 45.5 | -30.0% |
| `factor` | uniform, solo jobs | 67/66 | 66.5 | 45/45 | 45.0 | -32.3% |
| `factor` | mixed bands, parties | 65/66 | 65.5 | 46/46 | 46.0 | -29.8% |
| `gate` | mixed bands, solo jobs | 27/27 | 27.0 | 18/18 | 18.0 | -33.3% |
| `gate` | uniform, solo jobs | 27/26 | 26.5 | 18/18 | 18.0 | -32.1% |
| `gate` | mixed bands, parties | 29/27 | 28.0 | 18/17 | 17.5 | -37.5% |
| `party_fast` | mixed bands, parties | 219/212 | 215.5 | 145/145 | 145.0 | -32.7% |
| `party_finish` | mixed bands, parties | 227/227 | 227.0 | 158/157 | 157.5 | -30.6% |

## Probe decomposition, both sides

Probe costs overlap and omit interaction; they are not a partition of the tick.

#### mixed bands, solo jobs, population 256

`wu` p99: editor 2366.5 us, release 1636.0 us (-30.9%)

| probe | editor us above floor | share of editor `wu` | release us above floor | share of release `wu` | rank editor | rank release |
|---|---|---|---|---|---|---|
| `pid` | 233.0 | 9.8% | 155.0 | 9.5% | 4 | 4 |
| `xp` | 475.0 | 20.1% | 320.5 | 19.6% | 2 | 2 |
| `result` | 174.5 | 7.4% | 104.0 | 6.4% | 5 | 5 |
| `factor` | 700.0 | 29.6% | 482.5 | 29.5% | 1 | 1 |
| `gate` | 281.0 | 11.9% | 194.5 | 11.9% | 3 | 3 |
| **loop floor** | 6.5 | 0.3% | 5.0 | 0.3% | - | - |
| **probes summed (they overlap; not a partition)** | 1863.5 | 78.7% | 1256.5 | 76.8% | - | - |
| **unattributed remainder (a subtraction, not a measurement)** | 496.5 | 21.0% | 374.5 | 22.9% | - | - |

#### uniform, solo jobs, population 256

`wu` p99: editor 2662.0 us, release 1859.0 us (-30.2%)

| probe | editor us above floor | share of editor `wu` | release us above floor | share of release `wu` | rank editor | rank release |
|---|---|---|---|---|---|---|
| `pid` | 225.5 | 8.5% | 158.0 | 8.5% | 4 | 4 |
| `xp` | 428.0 | 16.1% | 292.0 | 15.7% | 2 | 2 |
| `result` | 181.5 | 6.8% | 113.0 | 6.1% | 5 | 5 |
| `factor` | 705.5 | 26.5% | 484.5 | 26.1% | 1 | 1 |
| `gate` | 282.0 | 10.6% | 191.5 | 10.3% | 3 | 3 |
| **loop floor** | 6.0 | 0.2% | 5.0 | 0.3% | - | - |
| **probes summed (they overlap; not a partition)** | 1822.5 | 68.5% | 1239.0 | 66.6% | - | - |
| **unattributed remainder (a subtraction, not a measurement)** | 833.5 | 31.3% | 615.0 | 33.1% | - | - |

#### mixed bands, parties, population 256

`wu` p99: editor 1799.5 us, release 1298.0 us (-27.9%)

| probe | editor us above floor | share of editor `wu` | release us above floor | share of release `wu` | rank editor | rank release |
|---|---|---|---|---|---|---|
| `pid` | 225.5 | 12.5% | 156.0 | 12.0% | 4 | 4 |
| `xp` | 472.0 | 26.2% | 320.0 | 24.7% | 2 | 2 |
| `result` | 178.5 | 9.9% | 109.0 | 8.4% | 5 | 5 |
| `factor` | 757.0 | 42.1% | 489.5 | 37.7% | 1 | 1 |
| `gate` | 286.5 | 15.9% | 194.0 | 14.9% | 3 | 3 |
| **loop floor** | 6.5 | 0.4% | 5.0 | 0.4% | - | - |
| **probes summed (they overlap; not a partition)** | 1919.5 | 106.7% | 1268.5 | 97.7% | - | - |
| **unattributed remainder (a subtraction, not a measurement)** | -126.5 | -7.0% | 24.5 | 1.9% | - | - |

#### mixed bands, solo jobs, population 12

`wu` p99: editor 124.5 us, release 81.5 us (-34.5%)

| probe | editor us above floor | share of editor `wu` | release us above floor | share of release `wu` | rank editor | rank release |
|---|---|---|---|---|---|---|
| `pid` | 10.5 | 8.4% | 6.5 | 8.0% | 4 | 4 |
| `xp` | 22.0 | 17.7% | 14.0 | 17.2% | 2 | 2 |
| `result` | 8.0 | 6.4% | 5.0 | 6.1% | 5 | 5 |
| `factor` | 32.5 | 26.1% | 23.5 | 28.8% | 1 | 1 |
| `gate` | 13.0 | 10.4% | 8.0 | 9.8% | 3 | 3 |
| **loop floor** | 1.0 | 0.8% | 1.0 | 1.2% | - | - |
| **probes summed (they overlap; not a partition)** | 86.0 | 69.1% | 57.0 | 69.9% | - | - |
| **unattributed remainder (a subtraction, not a measurement)** | 37.5 | 30.1% | 23.5 | 28.8% | - | - |

#### uniform, solo jobs, population 12

`wu` p99: editor 126.5 us, release 90.5 us (-28.5%)

| probe | editor us above floor | share of editor `wu` | release us above floor | share of release `wu` | rank editor | rank release |
|---|---|---|---|---|---|---|
| `pid` | 10.0 | 7.9% | 6.5 | 7.2% | 4 | 4 |
| `xp` | 20.0 | 15.8% | 13.0 | 14.4% | 2 | 2 |
| `result` | 8.0 | 6.3% | 5.0 | 5.5% | 5 | 5 |
| `factor` | 33.0 | 26.1% | 22.5 | 24.9% | 1 | 1 |
| `gate` | 13.0 | 10.3% | 8.0 | 8.8% | 3 | 3 |
| **loop floor** | 1.0 | 0.8% | 1.0 | 1.1% | - | - |
| **probes summed (they overlap; not a partition)** | 84.0 | 66.4% | 55.0 | 60.8% | - | - |
| **unattributed remainder (a subtraction, not a measurement)** | 41.5 | 32.8% | 34.5 | 38.1% | - | - |

#### mixed bands, parties, population 12

`wu` p99: editor 106.0 us, release 70.5 us (-33.5%)

| probe | editor us above floor | share of editor `wu` | release us above floor | share of release `wu` | rank editor | rank release |
|---|---|---|---|---|---|---|
| `pid` | 10.0 | 9.4% | 6.5 | 9.2% | 4 | 4 |
| `xp` | 22.0 | 20.8% | 14.5 | 20.6% | 2 | 2 |
| `result` | 8.0 | 7.5% | 5.0 | 7.1% | 5 | 5 |
| `factor` | 32.5 | 30.7% | 24.5 | 34.8% | 1 | 1 |
| `gate` | 13.5 | 12.7% | 8.0 | 11.3% | 3 | 3 |
| **loop floor** | 1.0 | 0.9% | 1.0 | 1.4% | - | - |
| **probes summed (they overlap; not a partition)** | 86.0 | 81.1% | 58.5 | 83.0% | - | - |
| **unattributed remainder (a subtraction, not a measurement)** | 19.0 | 17.9% | 11.0 | 15.6% | - | - |

## Machine drift control

The unmodified `needs` configuration, unchanged by any optimisation, across every run of this session. A release-versus-editor difference is only interpretable against this spread.

#### `needs` control, p99_us, population 256

| workload | editor | release | editor recheck | editor, earlier session |
|---|---|---|---|---|
| mixed bands, solo jobs | 1196.0 | 872.5 | 1249.5 | 1215.0 |
| uniform, solo jobs | 1195.5 | 864.5 | 1263.0 | 1215.5 |
| mixed bands, parties | 1215.5 | 903.0 | 1232.0 | 1225.5 |

#### `needs` control, p99_us, population 12

| workload | editor | release | editor recheck | editor, earlier session |
|---|---|---|---|---|
| mixed bands, solo jobs | 69.5 | 50.0 | 78.5 | 72.0 |
| uniform, solo jobs | 69.5 | 51.5 | 69.0 | 70.5 |
| mixed bands, parties | 71.0 | 50.0 | 70.0 | 70.0 |

#### `needs` control, p95_pair_us, population 256

| workload | editor | release | editor recheck | editor, earlier session |
|---|---|---|---|---|
| mixed bands, solo jobs | 2342.5 | 1704.0 | 2426.5 | 2368.5 |
| uniform, solo jobs | 2321.5 | 1690.5 | 2417.5 | 2336.0 |
| mixed bands, parties | 2359.5 | 1733.5 | 2420.0 | 2364.5 |

#### `needs` control, p95_pair_us, population 12

| workload | editor | release | editor recheck | editor, earlier session |
|---|---|---|---|---|
| mixed bands, solo jobs | 127.5 | 92.0 | 132.5 | 130.0 |
| uniform, solo jobs | 126.0 | 94.0 | 129.5 | 128.5 |
| mixed bands, parties | 128.5 | 92.5 | 133.0 | 130.0 |

## Determinism digests across the two runs

- triples present in both runs: 58
- digest disagreements: 0

