# Settlement validation tools

Specification `SET-VALIDATION-001`, revision 1. Review work in `redwall-rts`; no commit is part of this workflow.

## 1. What exists

| File | Executed purpose | Scope limit |
|---|---|---|
| `setting_contract.py` | Validate v2 catalog counts, 183 material/recipe references, roast arithmetic and admission reference fixtures | Static spec checks and independent examples; no runtime admission/lifecycle coverage |
| `arithmetic.py` | Reproduce GDD §7.1 worked examples, orchard dates, calendar horizons, FIFO search bound and planned memory sums | Arithmetic, not a settlement simulation |
| `winter.py` | Run both 12-resident controls at every tick through a winter or collapse; emit daily CSV and deaths | Isolated food/health experiment; excluded mechanics are in each report |
| `qualify.py` | Validate submitted Windows timing streams, separate tick/frame budgets, matrix completeness and replay digests | Requires real release-build evidence; checks submitted records, not physical hardware authenticity |
| `test_winter.py` | Meal duration, sleep interruption, schedule boundaries, starvation, skill/work accounting, repeatability | Reference-model regression tests |
| `test_qualify.py` | GDD arithmetic and rejection tests for bad/missing qualification evidence | Timing arrays in these tests are explicitly synthetic; they are never performance results |
| `headless/` | Typed GDScript winter control, packed resident allocator, integer scheduler and reference checkpoint codec | Standalone Godot project; not integrated into the release settlement runtime |
| `run_headless.py` | Runs Godot, compares complete Python outcomes, retains source digests and optionally compares/loads a Mac checkpoint on Windows | Requires the pinned Godot executable; headless evidence is not renderer performance |
| `test_headless_runner.py` | Rejects numeric type drift, truncated results and script/engine failures | Evidence checker tests |
| `hardware.json`, `WINDOWS_START.md` | Deferred USER-PC profile and exact resume command | User reports 5090 GPU / 64 GB RAM; remaining hardware fields await detection |

**VAL-AUTH-001.** WHEN a result is generated, the report SHALL distinguish `ARITHMETIC_ONLY_NOT_THREE_YEAR_SURVIVAL`, `ISOLATED_CONTROL_NOT_FULL_SURVIVAL_VALIDATION`, `BLOCKED`, `INVALID_EVIDENCE`, `FAIL_OR_INCOMPLETE`, `PASS_CAPTURE_ONLY`, and `PASS_SUBMITTED_EVIDENCE`. None of these alone certifies the complete game. `[NEW evidence taxonomy]`

**VAL-AUTH-002.** The GDD's immutable values SHALL remain unchanged. The Python tools are an independent validation model, not a replacement for the typed GDScript settlement runtime. A feature not implemented in this model SHALL be named as excluded rather than credited with a favorable result. `[GDD §8.1; NEW tool boundary]`

## 2. Reproduce the results

Use a Python 3.9-or-newer interpreter `[NEW tooling requirement]`. These scripts use only its standard library. Run from `/Users/brendan/Developer/redwall-rts`:

```sh
python3 -B -m unittest discover -s docs/validation -p 'test_*.py' -v
python3 -B docs/validation/arithmetic.py --output validation-results/arithmetic.json
python3 -B docs/validation/winter.py --output validation-results/winter-controls
python3 -B docs/validation/qualify.py --manifest validation-results/windows/manifest.json --output validation-results/windows-status.json
```

The first three commands exit 0 on success. The fourth intentionally exits 2 while evidence is absent, invalid, incomplete, or failing. A missing manifest is not generated as a pretend successful capture. No command modifies the Godot project, stages files, commits, or pushes. Python `-B` prevents bytecode cache files in the repository.

## 3. Winter control definition and accounting

| Parameter | Value | Provenance |
|---|---|---|
| Initial residents | 10 small, 2 medium, all adult | [GDD §5.1 starter composition] |
| Starting instant | Winter day 1 at midnight, local tick 0 | [NEW isolated fixture; not the normal world start] |
| Horizon | 216000 ticks or zero living, whichever occurs first | [DERIVED: 12 winter days × 18000 ticks/day; GDD §5.1] |
| Initial five needs / health | 7500 / 100 | [GDD starter values, reused at the NEW winter boundary] |
| Ready demand / initial nutrition | 89280 NP/day / 267840 NP | [DERIVED: GDD §5.2, §5.10; NEW three-day fixture] |
| Ready stock | 111000 milli-U PLAIN rations and 1800 milli-U PLAIN roots | [NEW exact representable fixture] |
| Other stocks | 600000 milli-U grain, 60000 water, 100000 wood | [NEW fixture, not food acquired in a three-year run] |
| Services | 1 kitchen bench, 1 well, 12 warm beds, 12 dining seats, adequate storage | [NEW pre-existing fixture; construction/access legality assumed] |
| Kitchen target / water reorder point | 12000 prepared milli-portions / water below 10000 milli-U | [NEW control policy] |
| Heating | 4000 milli-U wood/day | [GDD §5.9 tier-1 hearth winter fuel] |
| Well trip | 20 m outbound and 20 m return at size speed cap | [NEW distance; GDD §5.2 speed] |
| Meal duration | 150 complete tick intervals | [GDD §5.2] |
| RNG | xorshift32, seed 20260905 | [crowd §6; UI §4.3 seed reused for NEW isolated stream] |
| Need/health denominator | 750000 | [DERIVED: 750 ticks/hour × rate scale 1000] |
| Productive work numerator | 1000000 per WU | [DERIVED: milli-WU × work-factor denominator 1000] |

**VAL-WINTER-001.** WHILE a resident is alive, exactly one activity counter SHALL advance per interval: productive work, travel, sleep, eating, social activity, idle, or incapacitated. The sum SHALL equal that resident's elapsed alive ticks. `[NEW validation invariant; GDD §5.2, §5.8]`

**VAL-WINTER-002.** WHEN a work interval ends, productive work SHALL be `min(remaining_numerator,80*factor)`; carry skill XP remainder at 100000 work-numerator units per XP. COOK and HAUL XP SHALL be independent. Assignment at a completed boundary SHALL credit no work from the preceding interval. `[GDD §5.2 work/XP; NEW integration convention consistent with architecture §5]`

**VAL-WINTER-003.** WHEN a daily sample is emitted, initial ready NP plus newly cooked NP SHALL equal ready NP plus swallowed NP plus spoiled NP plus NP held in active meals plus lost held-meal NP. This ledger deliberately treats cooking as a transformation; raw grain's potential NP is never added to ready stock. `[GDD §5.7–5.8; NEW assertion]`

**VAL-WINTER-004.** IF hunger reaches 1500 while asleep and food is available, the resident SHALL begin eating at that boundary. Without reachable food, sleep SHALL not be repeatedly cancelled. Sleep that reaches 9000 rest SHALL not restart during the same scheduled sleep window. `[GDD §5.2 and §7]`

The fixture ages cooked meals in a heated pantry and grain in winter covered storage. It tracks baseline needs, mood/health work factors, cooking quality, fuel, finite water drawing and XP. Its full omissions are stored in `winter_report.json`: no ingredient buffs, meal memories, relationships/conflict/departure, ecology, farming, construction, immigration, injuries, rescue, exposure, reservations/WIP handoff, or gear wear. Water travel remains warm by experimental boundary condition; it is not a claim about an outdoor well. The normal population cap is unchanged.

`day` in CSV means complete local winter days elapsed. The terminal row can occur between midnights; use `tick` for exact time. A terminal row with `day=5,tick=91500` is during winter day 6. Daily samples are cumulative counters; subtract consecutive samples for a day's activity. Initial counters are zero. `food_days_centi=100*ready_np//daily_demand` while living; zero living uses 0 only in this diagnostic report. All divisions floor nonnegative inputs. `[NEW report conventions]`

## 4. Windows evidence contract

Every field, file shape, and coverage matrix in this section is `[NEW measurement plumbing]`; thresholds, machines and durations are inherited from `[GDD §5.11; crowd §0.2–0.3; systems_architecture §12]`. This protocol is ready to consume evidence after the runtime exists.

### 4.1 Required capture matrix

| Dimension | Exact values |
|---|---|
| Profile | `W-N`, `W-A` |
| Driver | `vulkan`, `d3d12` |
| Speed | `1`, `4` |
| Throughput repeats | `1`, `2`, `3`; each warms 60000000 real microseconds and records at least 180000000 |
| Soak | `kind=soak,repeat=1`; records at least 1200000000 real microseconds after warmup |
| Population | 256 living throughout each measured interval |
| Resolution | `[1920,1080]`, internal scale 1000 per mille, one viewport |

The Cartesian matrix contains 24 throughput captures and 8 soaks. Each must exercise dense interiors, food-expiry bursts, a seasonal crossing, queued navigation, and the maximum specified child stores. The capture includes the complete settlement feature set listed by `FEATURES` in `qualify.py`; an empty rendering demo cannot pass by supplying fast frame times. Report individual run percentiles and the maximum of each metric across repeats. Never merge the three repeats into a percentile distribution that hides the slowest run.

### 4.2 Manifest fields

`validation-results/windows/manifest.json` SHALL be one JSON object with the following keys. A file descriptor always has `{path:string,sha256:string}`; paths are relative to the manifest directory and cannot escape it. Digests are lowercase 64-digit SHA-256 strings.

| Key | Type / required value |
|---|---|
| `schema_version`, `scope` | integer `1`, string `settlement` |
| `build_sha256` | Digest of measured release executable |
| `rules_sha256`, `catalog_sha256`, `map_sha256` | Digests of the actual inputs used by that build |
| `source_commit` | 40-digit lowercase Git commit |
| `source_diff_sha256` | Digest of exact dirty-source patch; empty patch uses SHA-256 of empty bytes |
| `captures` | Array of capture records defined below |
| `parity` | Array of replay records defined below |
| `visual_review_passed` | Boolean; reviewed driver/shader/artifact evidence |
| `cold_start_review_passed` | Boolean; cold-start capture reviewed separately from warm timing |
| `vsync_review_passed` | Boolean; presentation repeats reviewed with VSync enabled |
| `transactional_peak_memory_passed` | Boolean; busiest save/load/rollback peak was measured within the simulation/process limits |
| `raw_route_log_complete` | Boolean; review confirms every request was recorded, including failures and requests still pending when measurement ended |

The last five booleans are human-reviewed attestations, not facts inferred by Python. Archive their original captures and review record beside the manifest. A positive checker result is evaluation of these supplied records; it is not an independently witnessed hardware certification.

Each capture record has `build_sha256`, `metadata`, and the `frames`, `ticks`, `routes` file descriptors. All captures must identify the same executable digest as the manifest.

| Metadata key | Exact contract |
|---|---|
| `profile`, `cpu`, `gpu`, `ram_bytes`, `os` | `W-N` or `W-A`; CPU `AMD Ryzen 5 3600`; GPU `NVIDIA GeForce GTX 1660 SUPER` for W-N or `AMD Radeon RX 6600` for W-A; RAM `17179869184`; OS `Windows 11` |
| `driver`, `driver_version` | Matrix driver; actual installed driver version string |
| `engine` | `4.7.2.stable.official.ed1daf0bf` |
| `build_mode`, `renderer` | `export_release`, `forward_plus` |
| `resolution`, `scale_per_mille`, `viewports` | `[1920,1080]`, `1000`, `1` |
| `vsync`, `frame_limit` | `false`, `0` for the timed throughput/soak matrix |
| `speed`, `warmup_us`, `kind`, `repeat` | Values from §4.1 |
| `features` | Array containing every string in `qualify.py::FEATURES` |
| `exercised_scenes` | Array containing every string in `qualify.py::SCENES`; scene instrumentation must have observed each condition during this capture |
| `allocated_payload_bytes` | At least `57713254`, the complete planned payload before reserve; allocation is not equivalent to exercised occupancy |
| `dropped_ticks`, `speed_fallbacks` | Both `0`; any overload fallback invalidates the requested-speed performance claim |

### 4.3 Exact CSV headers and measurement boundaries

```csv
frame_id,elapsed_us,frame_us,sim_cpu_us,ui_cpu_us,sim_ram_bytes,process_ram_bytes,skeletal_count,living,ticks_executed
```

`frames.csv` starts at frame ID 1. `elapsed_us` is measured monotonic time since recording started at a frame boundary. `frame_us` equals the difference from the preceding elapsed value, initially zero. CPU values measure elapsed CPU stage intervals on the main thread; they are not GPU time and are not estimates from FPS. `sim_cpu_us` encloses every tick plus simulation bookkeeping on that frame. Record allocator peaks encountered during the frame, including temporary save/load work, rather than sampling only after deallocation. `process_ram_bytes` is peak resident process memory for that interval; sampling limitations must be stated in the reviewed capture record.

```csv
tick,frame_id,tick_cpu_us
```

`ticks.csv` contains every executed simulation tick, including catch-up ticks, with contiguous absolute tick IDs. Never divide aggregate frame time by tick count to create tick samples. Per-frame counts must reconcile with `frames.csv`; aggregate simulation CPU cannot be less than its measured tick CPU sum. Up to 8 ticks of total capture-boundary difference from `elapsed_us*30*speed//1000000` is permitted `[NEW instrumentation tolerance matching the scheduler cap]`; no skipped work is permitted.

```csv
request_id,request_us,ready_us
```

`routes.csv` contains every request made in the recording interval. Request/ready times use the same monotonic real clock. Continue draining after recording to measure final requests. A request that never yields a route fails the fixture; report a reversed sentinel `(request_us=1,ready_us=0)` only when it is explicitly unresolved, so the checker rejects it. Do not remove failed requests from the percentile denominator. An additional raw route-event log is the basis for the completeness review.

Nearest-rank percentile is `sorted_values[ceil_div(p*N,100)-1]`. Gates: frame p95 ≤16670 us; frame p99 ≤20000 us; UI p95 ≤1500 us; simulation peak ≤100000000 bytes; process peak ≤4000000000 bytes; skeletal peak ≤24. At 1×, tick p99 ≤2000 us and route p95 ≤250000 us. At 4×, aggregate simulation/frame p95 ≤6000 us. Timings and counters must be nonnegative base-10 integers; memory peaks use maximum, not a percentile. `[GDD §5.11; NEW explicit measurement encoding]`

### 4.4 Cross-platform save/load parity

Required fixtures are `busy_construction`, `feast_preparation`, `winter_starvation`, each at speeds 1,2,4. Each replay record contains:

| Key | Contract |
|---|---|
| `fixture`, `speed` | One required fixture and one required speed |
| `platforms` | `['macOS','Windows 11']` encoded as a JSON string array |
| `engine` | Exact pinned build string |
| `tested_save_load` | `true`; Windows loaded the saved Mac boundary |
| `same_initial_state_and_commands` | `true`; requires retained input evidence |
| `initial_state_sha256`, `commands_sha256` | Digests, identical across speeds for a given fixture |
| `mac_uninterrupted`, `windows_reloaded` | File descriptors for the corresponding state streams |

Each state CSV has exactly `tick,state_sha256`, beginning at the saved boundary and continuing for at least 750 ticks. The comparison streams and validates every tick, including the first tick after load; it rejects gaps, truncation and any differing digest. A ruleset/configuration change requires a new manifest. This capture protocol does not substitute for the source's corruption, interrupted-write, or rollback tests.

## 5. Remaining execution dependencies

**VAL-RUN-001.** Before actual three-year results can replace the analytical tables, the settlement runtime SHALL execute `BAL-RUN-001` through `BAL-RUN-008` with all ordinary systems active. The current prototype does not contain that runtime. No output in this directory claims three different strategy trajectories, observed capacity for 256 residents, or Hearth Charter reachability.

**VAL-RUN-002.** The full recovery test SHALL branch from each strategy's real day-37 save and retain its crops, weather, needs, injuries, inventories, tools, layout, reservations and jobs. The isolated winter inventory is not a permitted substitute. `[gameplay_balance §8 BAL-RUN-008]`

**VAL-RUN-003.** The runtime work SHALL follow `systems_architecture.md` §11 in order. GDD §7.1 acceptance values now have executable reference arithmetic. The winter controls provide independent boundary checks for needs, meals and work. After runtime implementation, compare equivalent isolated Godot fixtures against these controls before executing full policy runs. Document every intentional fixture exclusion in the comparison. `[NEW integration sequence]`

## 6. Executed Godot foundation

The isolated Godot comparison now exists. The Mac run passes 324 explicit checks, including GDD economy examples, allocator boundaries and the clock. Both winter result objects match the Python reference exactly: all 18 daily/terminal rows, all 12 death events and both final outcomes. A saved tick-3000 checkpoint matches uninterrupted state at every tick 3001–18000. At tick 18000, runs driven at 1×, 2× and 4× have identical control-state hashes. The Python suite now contains 33 passing tests. `[OBSERVED: validation-results/godot-mac/comparison.json]`

```sh
python3 -B docs/validation/run_headless.py --godot /opt/homebrew/bin/godot --output validation-results/godot-mac
```

**VAL-GODOT-001.** WHEN a model changes, the runner SHALL reject stale Python source/document digests and require exact nested result equality, including integer types. Matching only final survivor count is insufficient. `[NEW comparison rule]`

**VAL-GODOT-002.** The resident allocator kernel SHALL allocate 512 packed slots, refuse a 257th living resident before mutation, use a preallocated minimum-index free heap, increment generation on reuse and retire maximum-generation slots permanently. It SHALL refuse persistent-ID overflow. Its local slot checks do not replace the release global-directory kind/reverse-owner/child-allocation transaction. `[GDD §4.1; architecture §4; NEW isolated kernel scope]`

**VAL-GODOT-003.** The scheduler kernel SHALL use integer host microseconds and debt, execute at most 8 ticks per host frame, preserve outstanding debt during 4→2→1→pause overload, and require explicit acknowledgement to discard catch-up debt. The initial calendar remains day 1 at 06:00, first midnight tick 13500. Pause flags PLAYER=1, MENU=2, CRITICAL=4, VICTORY=8, LOAD=16 are `[NEW local encoding]`; all clock/calendar numbers otherwise follow architecture §5 and GDD §5.1.

**VAL-GODOT-004.** The reference checkpoint SHALL contain all 40 mutable world fields, audited against Godot's script-property list. Envelope: 8 ASCII bytes `RWLCTRL1`, a little-endian u32 payload length, 32 SHA-256 payload-digest bytes, then the pinned engine's object-free Variant encoding of the field array. Maximum payload is 1048576 bytes `[NEW fixture bound]`. Decode validates envelope, digest and field type/shape before field assignment. Variable lots/histories have explicit bounds. It does not implement the release format, complete semantic ownership validation, transactional rollback, rule migration, or the 100 MB allocation contract. `[NEW control-only codec; release format remains ARCH-SAVE]`

**VAL-GODOT-005.** WHEN the Windows PC becomes available, run `WINDOWS_START.md` using its retained Mac checkpoint and hash stream. Only an actual Windows run loading that checkpoint can receive `PASS_ISOLATED_MAC_WINDOWS_PARITY`. A second Mac process may validate package/reload mechanics but SHALL report `cross_platform=false`. `[NEW evidence rule]`

**VAL-GODOT-006.** Script errors, unknown engine errors, missing output and process failures SHALL fail the runner. This Mac sandbox reports failure to create Godot's unused default user-data directory and an OS certificate-lookup diagnostic; the runner recognizes only those precise startup diagnostics, preserves them in logs and the comparison report, and uses explicit permitted output paths for all checkpoints/results. No network operation is part of the control. These diagnostics are not a renderer-performance measurement or a silent exemption for gameplay errors. `[OBSERVED environment behavior; NEW narrow handling]`

The standalone project uses a headless dummy display. Its Compatibility setting is only a minimal control-project default and does not change the shipping Forward+ contract. Keep its generated `.godot` cache ignored. None of these tools changes the legacy game's autoloads, current scene or project settings.

## 8. Adopted setting rules v2

Run `python3 -B docs/validation/setting_contract.py --output validation-results/setting-contract.json` from the repository root. This validates the active Markdown catalogs and reference arithmetic. Its pass does not certify admission transactions, UI behavior, release saves or full settlement survival. The Python winter report now hashes `setting_rules_amendment.md` along with its previous source documents; regenerate the winter report before comparing against changed sources.
