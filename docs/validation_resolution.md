# Validation resolution and evidence record

**New adopted scope:** [SET-MOVE-001](movement_direction_amendment.md), DEC-035, adds required connected movement. Existing controls/measurements remain evidence for their original baseline only. No traversal runtime test or Windows benchmark was executed by this document/research update.

Specification `SET-RESOLUTION-001`, revision 1, 2026-09-05. Applies to `/Users/brendan/Developer/redwall-rts`. Status: partial validation completed; full settlement simulation and Windows qualification remain incomplete. No inherited GDD number has been changed. No files have been staged or committed.

## 1. Requirement disposition

| Requirement / conflict | Disposition | Evidence or exact remaining dependency |
|---|---|---|
| GDD §7.1 worked economy values | `EXECUTED_ARITHMETIC` | `validation-results/arithmetic.json`; assertions cover demand, crops, seed replacement, winter rations, quality and starter stocks |
| Meal, sleep, starvation and productive-work boundaries | `EXECUTED_REFERENCE_TESTS` | 27 tests across the winter model, arithmetic and evidence checker; includes exact 150-tick meals and 41250-tick closed starvation |
| Three-ready-food-day experiment | `EXECUTED_ISOLATED_CONTROL` | Both controls executed; exact state and exclusions in §2 and `winter_report.json` |
| READY_03 full first-winter daily outcome | `BLOCKED_RUNTIME` | The 12-day control is available; each strategy still needs its own genuine first-winter trace from the normal starter state |
| READY_03 three-year Forager rush, Farm-first, Balanced | `BLOCKED_RUNTIME` | Requires the absent settlement systems, then `BAL-RUN-001–008`; no strategy trajectories have been invented |
| READY_03 actual seasonal labor at 12/24/48/80/120/180/256 | `BLOCKED_RUNTIME` | Control activity accounting is measured at 12 residents; it does not replace observed workforce supply at every requested cohort |
| Actual day-37 recovery branches, deaths, and M4 reachability | `BLOCKED_RUNTIME` | Must retain actual needs, injuries, jobs, crops, equipment, weather and inventories from each validated strategy save |
| ARCH-CONFLICT-009 performance evidence handling | `IMPLEMENTED_CHECKER` | `qualify.py` checks measured streams and the complete Windows matrix; absent evidence exits 2 with `BLOCKED` |
| Windows performance and Mac/Windows save parity | `BLOCKED_RUNTIME_AND_HARDWARE` | No matching settlement release build or measured Windows captures exists in the repository |
| Whole-number ratio restriction versus fixed GDD values | `RESOLVED_BY_AUTHORITY` | Use exact fixed GDD fractions, including whole ratios. The task's explicit authority rule outranks the lower-priority blanket ratio preference |
| Orchard fruit in the three-year horizon | `RESOLVED_SCOPE` | Apples first harvest day 169; pears day 219 in the earliest-planting calculation. Use the ten non-orchard recipes in §4 for the proposed M4 policy |
| Calendar horizon discrepancy | `RESOLVED_REPORTING` | Report tick 2587500 for calendar day 144 end; extend through 2592000 for three elapsed years |
| Missing durability/batch/save state | `RESOLVED_IN_ARCHITECTURE` | Preserve GDD fields and implement the explicitly budgeted auxiliary arrays in systems_architecture §3; runtime still absent |
| Two simultaneous world allocations | `RESOLVED_IN_ARCHITECTURE` | Use the selected disk-backed rollback/load contract; arithmetic verifies 66101862 planned bytes versus 117599532 for two worlds; live peaks remain unmeasured |
| M4 maintenance wording | `SOURCE_AMBIGUITY_REMAINS` | Midnight samples cannot prove continuous maintenance. §5 gives an exact proposed interpretation; source remains untouched |
| Universal route deadline with fixed search quota | `PROVEN_WORKLOAD_CONFLICT` | Cold FIFO reference burst needs 31 ticks at p95, exceeding 7 complete ticks allowed by 1/4 second. §6 gives exact options |

**RES-AUTH-001.** WHEN the implementation agent reads this record, it SHALL use the disposition column as evidence status, not permission to replace GDD values. A planned architecture, arithmetic pass, isolated control, and observed game result are distinct forms of evidence. `[NEW reporting requirement; GDD §8.1]`

## 2. Executed winter controls

These are `[OBSERVED: docs/validation/winter.py]` results. Both begin with the same 12 residents, initial needs 7500, health 100, exactly 267840 ready NP, 600 grain U, 60 water U and 100 wood U. The ready reserve is exactly three winter food-days. Cooking-enabled maintains 12 prepared portions and replenishes water; conversion-disabled never produces food. All initial stocks and service capacities beyond the GDD starter composition/need values are `[NEW experimental boundary conditions]`.

Both cases consume heating fuel. Both assume warm reachable services and omit exposure, injuries, rescue, relationships, ingredient buffs, memories, immigration, construction, ecology, crop growth, reservations and gear wear. Grain is finite potential food, excluded from ready food-days. This comparison tests whether a conversion chain can recover readiness from pre-existing ingredients; it does not test recovery after all potential food is exhausted.

| Completed winter days | Enabled living | Enabled ready NP | Enabled food-days, hundredths | Enabled grain, milli-U | Enabled wood, milli-U | Disabled living | Disabled ready NP |
|---|---|---|---|---|---|---|---|
| 1 | 12 | 271440 | 304 | 574520 | 94700 | 12 | 234240 |
| 2 | 12 | 262020 | 293 | 537280 | 88800 | 12 | 147840 |
| 3 | 12 | 260820 | 292 | 490240 | 82400 | 12 | 56640 |
| 4 | 12 | 260820 | 292 | 441240 | 75900 | 12 | 0 |
| 5 | 12 | 257400 | 288 | 394200 | 69500 | 10 | 0 |
| 6 | 12 | 249180 | 279 | 351080 | 63300 | 0 | 0 |
| 7 | 12 | 243000 | 272 | 307960 | 57100 | 0 | 0 |
| 8 | 12 | 238200 | 266 | 262880 | 50800 | 0 | 0 |
| 9 | 12 | 233400 | 261 | 217800 | 44500 | 0 | 0 |
| 10 | 12 | 228780 | 256 | 172720 | 38200 | 0 | 0 |
| 11 | 12 | 224160 | 251 | 127640 | 31900 | 0 | 0 |
| 12 | 12 | 218820 | 245 | 82560 | 25600 | 0 | 0 |

Disabled rows from day 6 onward are the absorbing zero-living result, carried forward for comparison; the simulation itself stops at collapse and does not invent subsequent work or stock changes. Its last CSV sample is tick 91500, two game hours into winter day 6. By the day-5 midnight sample two residents have died; ten more die before the collapse boundary. The complete death-event log is in the JSON report. `[OBSERVED; NEW absorbing-state display convention]`

Enabled reaches the stated control stabilization criterion at the day-3 sample: three consecutive samples with all residents alive, no hunger at zero, at least two ready-food days, and at least two heating-fuel days. It finishes at tick 216000 with no deaths; minimum health is 100 at every daily sample. This does not award an in-game recovery milestone. `[OBSERVED; criterion NEW in BAL-RUN-008, reduced to this control's active systems]`

### 2.1 Measured time and production, enabled control

| Quantity | Exact measured value | Meaning |
|---|---|---|
| Alive resident-ticks | 2592000 | 12 × 216000 |
| Productive-work ticks | 41562 | Active work intervals, excluding travel |
| Travel ticks | 17744 | Timed well trips |
| Sleep ticks | 613736 | Heated-bed sleep |
| Eating ticks | 81900 | Completed 150-tick meal intervals |
| Social ticks | 215540 | Social schedule intervals |
| Idle ticks | 1621518 | No active job or need activity; not automatically usable labor |
| Incapacitated ticks | 0 | No incapacitation in this branch |
| COOK work | 3168000 milli-WU | 264 completed porridge batches |
| HAUL work | 480000 milli-WU | 48 draws of 10 water U |
| Grain used | 517440 milli-U | Paid actual discounted inputs |
| Water used | 528000 milli-U | 60000 initial + 480000 drawn − 12000 remaining |
| Wood used | 74400 milli-U | 48000 heating + 26400 kitchen fuel |
| Prepared nutrition | 966780 NP | Measured output-quality mix, not assumed PLAIN output |
| Swallowed nutrition | 1015800 NP | Includes consumed initial food |
| Final ready nutrition | 218820 NP | 267840 + 966780 − 1015800 |

**RES-LABOR-001.** The implementation SHALL preserve productive work and base-time opportunity separately. It SHALL NOT multiply measured productive-work ticks by 80 and label that skilled output: this fixture produces 3648000 milli-WU while its active work intervals represent 3324960 base-opportunity milli-WU. Nor SHALL it label the large idle remainder as guaranteed available full-game workforce supply. `[GDD §5.2; NEW report invariant; OBSERVED control totals]`

## 3. Reproducibility and qualification evidence

The commands and exact CSV/manifest contracts are in `docs/validation/README.md`. `winter_report.json` records the source-code digest, authoritative input-document digests, Python/platform identity, assumptions, daily results and death events. `arithmetic.json` records each source domain separately. Test timing data stays inside unit tests and is never copied into Windows evidence.

`qualify.py` requires 24 throughput captures, 8 soaks and 9 cross-platform save/load comparison cases under its explicit matrix. It calculates nearest-rank percentiles, tests individual tick timing separately from aggregate frame work, rejects missing tick samples, validates per-frame count/CPU reconciliation, checks memory maxima, includes route request latency and requires the complete runtime feature set. GPU visual correctness, cold-start behavior, VSync presentation, transactional memory peaks and raw route-log completeness remain reviewed attestations. `[NEW evidence contract; inherited gates GDD §5.11 and crowd §0.3]`

The current generated `windows-status.json` is `BLOCKED`; no Windows timing value or cross-platform hash match is claimed. A successful Mac prototype test cannot change that status. The existing Godot prototype still requires the architecture's settlement migration before this capture matrix is meaningful.

## 4. Orchard scope resolution without changing maturity

**RES-ORCHARD-001.** During the requested first three years, the policy SHALL credit no harvested orchard fruit. At earliest M3/planting day 49, apple maturity is day 145 and the next legal apple window begins day 169; pear maturity is day 193 and the next pear window begins day 219. Orchard care, pollination, and long-term investment may still occur. `[DERIVED: GDD §5.6, §5.11]`

**RES-ORCHARD-002.** The proposed ten-recipe mastery target SHALL use this ordered set: `porridge`, `root_stew`, `fish_stew`, `bean_hotpot`, `nut_loaf`, `dry_fish`, `woodland_pie`, `nut_roast`, `feast_fish`, `ration`. The first six are available by M1; the last four at M2. No member requires orchard fruit or honey. The first three plus `dry_fish` provide four start-unlocked candidates for M2's three-mastery prerequisite. `[NEW policy; GDD §5.7 recipe inputs/unlocks, §5.11 gates]`

Mastery still requires the specified repeated GOOD/EXCELLENT production; listing candidate recipes does not count them as mastered, provide ingredients, or prove the eight specialists/six skills, feasts, reserve, population or mood requirements. This closes the orchard dependency assumption, not the full M4 simulation gap.

## 5. M4 temporal ambiguity: exact proposed amendment

The existing drafts interpreted the source as checks at the starts of winter days 10,11,12. Three point samples do not prove continuous maintenance between those samples. The GDD both says “conditions maintained last 3 winter days” and permits award at midnight starting winter day 12. Its timing words need one explicit interpretation; changing a threshold is unnecessary.

**RES-M4-PROPOSAL-001.** Proposed wording, not an applied GDD edit: “At the midnight beginning winter day 12, after needs, deaths and lifecycle commit, award M4 only if every current predicate holds and has held at every completed tick throughout the preceding 54000 ticks. These are winter days 9,10,11. A false predicate resets the maintained interval immediately.” `[NEW proposed interpretation; 54000 DERIVED from GDD 3 × 18000]`

| Boundary in year 3 | Absolute day | Completed tick |
|---|---|---|
| Start winter day 9 | 141 | 2515500 |
| Start winter day 10 | 142 | 2533500 |
| Start winter day 11 | 143 | 2551500 |
| Start winter day 12 / existing award instant | 144 | 2569500 |
| End winter day 12 | 145 | 2587500 |

The amendment would preserve the source's award instant and all numeric thresholds. Implementation would need saved `m4_true_since_tick:i64` and a sentinel for false, plus corresponding memory/schema revision, or an equivalent explicitly budgeted interval-validity representation. It must test a predicate failure between midnights and reset across save/load. No array field is silently added to the current memory ledger by this proposal. Until the wording is adopted in a versioned source revision, M4 outcome certification remains withheld; the existing point-sample interpretation is not evidence of continuous maintenance.

## 6. Path deadline: exact incompatible workload and options

The reference workload is `[NEW]` 256 distinct, cold FIFO requests, each needing 256 search expansions, with no cache sharing and all requests visible at the same boundary. At the fixed 2048 expansions/tick `[GDD §5.11]`, nearest-rank p95 is request `ceil_div(95*256,100)=244`. It needs `244*256=62464` expansions and `ceil_div(62464,2048)=31` ticks. At 30 ticks/real second that is `31/30` seconds, exceeding `1/4` second. The most allowed complete ticks inside that gate is 7. `[DERIVED]`

| Option | Exact contract | Effect on source |
|---|---|---|
| Retain quota, qualify measured supported workloads | Preserve 2048 expansions/tick and measure request-to-ready including queue wait; explicitly fail overload workloads. Caching/coalescing may reduce actual work but may not hide waiting time | No numeric amendment; does not promise the impossible cold-burst case |
| Widen this burst's latency gate | At least 31 ticks for the stated p95 workload | Changes source performance requirement; requires a versioned amendment |
| Raise quota for this burst | At least `ceil_div(62464,7)=8924` expansions/tick for this p95 case; at least `ceil_div(65536,7)=9363` for all 256 | Changes fixed source quota; needs a new measured tick/frame CPU budget test |

**RES-PATH-001.** The current implementation contract SHALL retain 2048 and report this cold-burst failure. It SHALL NOT reset the latency clock at search admission, infer a universal latency guarantee from caching, or increase the quota without an explicit source revision. A request admission cap of 58 can pass the isolated 256-expansion batch p95 bound; it does not remove the waiting time of the remaining requests and is not a solution to the universal claim. `[GDD fixed quota; NEW evidence rule]`

## 7. Next executable milestone

**RES-NEXT-001.** The next game implementation milestone SHALL be the headless settlement runtime from systems_architecture §11, beginning with packed stores, integer clock, catalogs, inventory, needs and jobs. Its completed acceptance gate is the GDD §7.1 fixtures plus equivalent winter boundary tests running inside Godot. The current Python controls remain external comparison evidence. `[NEW sequencing; existing architecture migration order]`

**RES-NEXT-002.** After ecology, crops/weather, rooms/heat, production, social behavior, lifecycle, immigration, progression and saves are active, the agent SHALL execute all three policies through tick 2592000, retain daily CSV, commands and state hashes, and fork the real day-37 recovery branches. Only those artifacts can close the actual workforce, three-year trajectory and complete starvation-cascade requirements. `[BAL-RUN-001–008]`

**RES-NEXT-003.** After the representative settlement render/UI scene is available, the agent SHALL produce the release capture build and execute the documented Windows matrix on the reference machines. A different available Windows machine provides development measurements only until its difference from the reference floor is explicitly recorded. `[GDD §5.11; crowd §0.3]`

## 8. Numeric provenance

Inherited: clock, needs, health, sizes, speed, food NP, recipe quantities/work/quality, XP, spoilage, winter fuel, orchard maturity/windows and performance gates. Derived: fixture arithmetic, exact three-day NP, activity totals, calendar ticks, path-queue bounds and memory sums. Originated: isolated winter inventory/service assumptions, target/reorder policy, well distance, evidence formats/coverage matrix, the non-orchard mastery policy, and the proposed temporal clarification. No control result was copied into a three-year trajectory or extrapolated past the living cap.

## 9. Mac execution and deferred Windows return point

User update: a Windows PC with a 5090 GPU and 64 GB RAM exists but is not currently available. Windows execution is deferred by instruction; CPU, OS version and driver are intentionally unfilled in `docs/validation/hardware.json`. This USER-PC profile is separate from the W-N/W-A reference-floor profiles. Resume instructions are in `docs/validation/WINDOWS_START.md`; no reminder schedule or date was assumed.

| New work | Observed status | Scope |
|---|---|---|
| Typed GDScript winter port | PASS; both complete result objects exactly match Python | 18 daily/terminal rows and 12 death events |
| Packed resident allocator kernel | PASS; 512 slots, 256 living cap, stable identity and overflow cases | Kernel tests; not the release global directory/child transaction |
| Integer scheduler kernel | PASS; clock/calendar, independent pause reasons, bounded catch-up and retained debt | Control driver; not integrated with release UI commands |
| 1×/2×/4× state parity | PASS at completed tick 18000 | Same Mac process; no rendering dependency |
| Checkpoint continuation | PASS at every tick 3001–18000 after loading tick 3000 | 15000 exact state comparisons |
| Saved-file handoff through a second Mac process | PASS; 15001 retained hash rows identical, `cross_platform=false` | Tests the Windows resume path locally; not Windows evidence |
| Test totals | 324 Godot checks and 33 Python tests pass | Logs and digests retained in `validation-results/godot-mac/` |
| Windows execution | DEFERRED_BY_USER | Ready to run the isolated package when the PC is available |

The headless reference checkpoint has its own explicitly scoped codec and does not replace the release save contract. All 40 mutable control-world fields are included, with field-coverage tests, digest checks, shape validation and damaged/truncated-file rejection. Full three-year strategies, actual cohort labor, release save semantics and scene performance remain unexecuted. The next integration work is the full catalog/inventory/job/room/ecology runtime under architecture §11, using these verified kernels and controls as regression evidence.

## 10. Adopted setting rules v2

DEC-005/006 are adopted. `setting_rules_amendment.md` defines scenario admission, the authored refuge petition, retired hunting content, replacement nut roast and Orchard main course. The non-orchard ten-recipe policy now uses nut_roast. The packed memory budget stays unchanged through reserved fields; full-game admission transactions, mastery reachability and all-scenario survival still require runtime integration. Prior measurements describe isolated controls and are not retroactively evidence for new admission behavior. Source-bound winter evidence was regenerated after the GDD/UI revision and now also hashes the amendment. The refreshed run passes 33 Python tests, 324 Godot checks, exact Python/Godot winter outcome comparison and 15001 saved-boundary/continuation hashes through a second Mac process. The new static contract check validates 60 items, 24 main recipes, 12 ancillary recipes, 30 buildings, 9 furniture types, 5 crops and 183 input/output/material dependency edges. It also checks roast levels 0–10, feast batch coverage for 1–256 attendees, the non-orchard recipe set and four admission reference examples. These examples are independent arithmetic checks, not game admission tests.

## RES-MOVE-001 — movement disposition after adoption

| Requirement | Status | Exact next evidence |
|---|---|---|
| User movement decision and owning-document reconciliation | `DOCUMENTED` | DEC-035; SET-MOVE-001; linked GDD/UI/balance/architecture/crowd obligations |
| Complete production catalogs, finite schema and UI/asset contracts | `SPEC_INCOMPLETE` | MOVE-G01–04 closure artifacts; no defaulted constants |
| Movement correctness and conservation | `BLOCKED_RUNTIME` | F01–F14 from traversal review plus MOVE-TEST-01–10, replay and transaction evidence |
| Expanded memory and route latency | `UNMEASURED` | Recomputed bounds, arena saturation, mixed-domain path bursts and workload p95 |
| Mac/Windows parity | `DEFERRED_WINDOWS` | Same seeds/commands/checkpoints with hashes on available Mac and returning Windows PC |
| Qualification floor | `UNMEASURED` | Required floor target runs; 64 GB/RTX 5090 specs do not establish floor results |

Research coverage is recorded separately in `redwall-design/source_audit.json`: 12 works, 115 passage records, 47,139 inspected extracted words in this targeted pass. It proves passage coverage, not gameplay completeness, complete sequential rereading, canonical map measurements or working recipes.
