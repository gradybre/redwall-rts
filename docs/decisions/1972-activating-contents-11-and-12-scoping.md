# 1972 — Activating contents 11 and 12: scoping, stopped for the coordinator

Date: 2026-10-16 · Status: Accepted. Brendan ruled P-1972-3 and P-1972-6, and the coordinator P-1972-1, -2, -4 and -5,
on 2026-10-16 (see "Rulings"). Phase 2 (the build of everything outside the cost lane's files) follows.

Number range 1972–1980 was allocated by the coordinator and checked free on every local and remote ref. Branch
`feat/activate-content-11-12`, from origin/master `a0daf1ab` (#260 content 11, #262 C2.1, #264 C2.2, #265 dig cost,
#266 content 12). Line numbers below are at `a0daf1ab`; 1971's inventory numbers in Routes have moved since.

## Rulings (2026-10-16, relayed by the coordinator)

| Proposal | Ruling | What it means here |
|---|---|---|
| P-1972-1 | Coordinator: (a) | Widen the runtime-v2 programs and the certificates in place, with one predicate for "content 10 or its successor 12" |
| P-1972-2 | Coordinator: (a) | `Budget.PROFILE_BYTES` +4,096, to 282,624, with its own ledger row through ADR 1212. C2.3 and the cost lane also move the census, so master's figures are taken at merge time and re-projected |
| P-1972-3 | Brendan, **"Refuse them, recorded"**: (a) | Saves made before activation that hold an underground Session are refused at load (`SAVE_UNDERGROUND_RESTORE_REFUSED`). This record is where it is recorded |
| P-1972-4 | Coordinator | The two `demo/burrow/modular_runtime.gd` lines are cleared, but only after PR #267 (Mound POC) merges |
| P-1972-5 | Coordinator: yes | Build the Profiles edits now, clear of the cost lane's hunks; one pin renewal after its merge |
| P-1972-6 | Brendan, **"Keep 90 ticks"**: (a) | Authored stair paces move to milli-u/s. Every existing authored pace is rescaled ×1,000, so its ticks stay identical; the 169 u retreat takes exactly 90 ticks |

Indexed in `docs/handoff/RULINGS.md`. Sections "The brief" to "Proposals" are the scoping as it was put.

## The brief (relayed by the coordinator)

Brendan asked for "Real digging, in full". Until activation the claw crew reaches only the legacy 1 quantum, the room
foreman (C2.1, 1931–1933) digs nothing in the game, and no one can carry stock down a stair. P-1971-3 ("Painted
height") takes effect at activation. P-1981-4 (a) and 1971's inventory give this lane the engine admission of both
contents together, with one pin renewal, one checkpoint regeneration and one census pass.

## Three findings that reshape the inventories

1. **Content 11 is never loaded.** Content 12 (`qualified-stair-carry-v13`, revision 12, 85 rows, 637 boxes, 8
   sources) carries content 11's rows 0–70 byte for byte. Activation mounts content 12 at **revision 12**. Every
   check that compares a content revision with 10 must admit 12. That is more than the inventories list: the
   handling selector, the paw program's exact census (67/547/6), the endpoint and grip certificates, the Frontier's
   `_header[5]`, and the route composition's `PROFILE_CONTENT_REVISION`.
2. **The programs are bound by image digest, not by content.** `Claw2.owns` and `Stair.owns`
   (`qualified-claw-runtime-v2/claw_program.gd:39-48`, `stair_program.gd:30-37`) test the row range, the row's
   source word and source 4's image digest. They never test the content revision. Routes and WorldRoutes dispatch
   only through `owns`. So if the two runtime-v2 programs are widened in place (the claw program owns 67–70; the
   stair program owns 71–84 by the source 6/7 digests), **Routes needs no dispatch edit** and WorldRoutes needs one
   line (P-1972-1).
3. **Content 12 overflows `PROFILE_BYTES` by 2,024 B.** The Motion/Profile/Level joint becomes 270,824 B. The census
   adds the Session slice (1,536) and the retirement slice (8,192): `tools/underground_current_census.py:486` and
   `tools/underground_room_memory.py:576-577`. That gives 280,552 B against `Budget.PROFILE_BYTES` 278,528
   (`underground_budget.gd:22`). Decision 1981's "leaving 7,704 B" counted the joint without the two slices. The
   arithmetic, from `underground_motion_memory.py:150`: profile = 2 × (98 × 85 + 28 × 637 + 32 × 8 + 32) + 32,768 =
   85,676 (content 10: 76,980). See P-1972-2.

## Edit list per file (1971's and 1981's inventories merged and re-checked)

"Gated" means the edit waits for the cost lane (`perf/dig-tick-cost-2`).

### A. Mount (catalog, Session, composition)

| File:line | Edit |
|---|---|
| `data/underground/mole-worker/mole_profile_catalog.gd` 13, 14–19, 23, 26, 175–176 | Pins → v13; 85 / 637 / revision 12 / 26,462 / 52,908; WIRE_PATH v13; `SOURCE_COUNT` 8; `_hash_sources` adds the wood and stone digests. Stale comments 3, 9–12, 24–25 |
| `scripts/core/underground_session.gd` 40, 43–67, 276–277, 337–342 | Constants for sources 6/7: wood 7,589,568 B and stone 7,370,344 B peak. `PRESENTATION_SET_BYTES` 42,735,176 → 57,695,088. The capacity checks follow the Catalog |
| `scripts/core/underground_route_composition.gd` 16–20, 129–133 | Bundle → v10; `PROFILE_CONTENT_REVISION` follows; the stair motion owner loads both tables |
| `scripts/core/underground_entry_composition.gd:16`, `underground_entry_site.gd:10` | Bundle → v10 |
| `data/underground/runtime_files.gd` 18–33 | The demo pack (decision 1841): the two images and the stair-carry `.ugstair` |
| `tools/godot/verify_demo_pack.gd:46-47` | Stale size comment only (the wood image fits 4 MiB) |
| `tools/renew_source_pins.py` 4, 27 | `ACTIVE` → v13 (`run_tests.sh:88` checks only `ACTIVE`) |

### B. Programs and certificates admitting revision 12 (P-1972-1 (a))

| File:line | Edit |
|---|---|
| `qualified-claw-runtime-v2/claw_program.gd` 12–16, `in_block`, `yaw_of`, `clip` | Pins → v13. Own rows 67–70: WORK, `POLICY_SOURCE_WORK`, yaws 0..49152, M1's dig clips. Add one predicate, `carries_content_ten(content)` (10 or 12), for every consumer below |
| `qualified-claw-runtime-v2/stair_program.gd` 15–17, `owns`, `policy_of`, `yaw_of`, `family_mask_of`, `profile_refusal`, `clock_refusal` | Own rows 71–84 by the source 6/7 digests: rooted words 10–13, family 1, WALK for 71/72, and CARRY with the item's cargo for 73–84. `MAX_KEY` 270 already covers the 271-key turn |
| `qualified-claw-runtime-v2/paw_program.gd` 14–17, 69–71 | Exact 67/547/6 → content 10 or 12 at its own counts (as `Assembly.uses` admits successors, ADR 1200) |
| `qualified-claw-runtime-v2/paw_physical_certificate.gd` 22–24, 331–333 | Follows the predicate |
| `qualified-claw-certificate-v2/endpoint_certificate.gd` 14, 17, 96, 456–457 | Pins v13; revision 10 or 12 |
| `qualified-claw-runtime-v1/endpoint_certificates.gd` 16, 22, 31 | `Claw10.CONTENT` → the predicate |
| `qualified-claw-runtime-v1/handling_programs.gd` 26–144 (13 sites) | `content == Paw10.CONTENT` → the predicate |
| `qualified-claw-runtime-v1/grip_certificate.gd` 15, 101 | Admit 12, and the rooted CARRY rows at the hold (the grip is the hold's, 1981) |
| `data/underground/mole-worker/mole_claw_program.gd` 11, 18–21 | Content 12 dispatches to `Claw10`; the row range includes 67–70 |
| `scripts/core/underground_connector_contacts.gd` 35, 1019, 2036 | Pins v13; `_header[5] == Paw10.CONTENT` → the predicate |
| `scripts/core/underground_entry_foreman.gd:25`, `underground_entry_bindings.gd:1605-1616` | Pins v13. `_stair_stop_bounds`' `up` reads the row's yaw (32768), so the rooted ascent and retreat stops face up |
| `scripts/core/underground_motion_catalog.gd` 10, 30–31 | Test-only owner, which pins v11. Left on content 10 as a fixture (a census input; no live use) |

### C. Profiles selection (`scripts/core/underground_profiles.gd`, shared core; the cost lane also edits it)

**The mount depends on this.** `mole_profile_catalog.gd:212-214` re-hashes every row's policy through
`selection_policy_of`, which returns −1 for rows 71–84 today (`MOLE_CATALOG_DESCRIPTOR`). So content 12 cannot load
until the leaf returns 10–13.

- `selection_policy_leaf` (623–631): the bound `<= POLICY_STAIR_TURN` → `<= POLICY_ROOTED_TURN`.
- `query_travel_profile_into` (633–646): admit the rooted words; use the row's own mode (`_policy_mode`), so a CARRY
  row is selected with the actor's actual cargo through `_read_dynamic`.
- `_matches` (776–778): the heading exemption covers `POLICY_ROOTED_TURN`, through one static
  `is_table_turn(policy)` that WorldRoutes shares.

The cost lane's Profiles hunks (195, 219, 290: the load revision and the cache checks) are disjoint from these.

### D. Routes and WorldRoutes (cost lane's files): what waits, and its budget

Under P-1972-1 (a):

| File | Edit | Characters |
|---|---|---|
| `underground_routes.gd` | **None.** Every dispatch is through `Stair.owns` / `Claw2.owns` (2343–2344, 2382–2383, 2394, 2400, 2591–2592, 3153, 3271, 3283, 3321–3323, 3666, 3741–3754). `refresh_travel_actor` passes WALK, and `_actor_profile_into` sends a non-automatic explicit row to `query_travel_profile_into`, which then takes the row's own mode (C). `_source_clock_leaf`'s legacy branch (2369) takes only policy ≤ 0 | 0 |
| `underground_world_routes.gd:1503` | The stale-selection heading exemption also covers `POLICY_ROOTED_TURN` (`not Profiles.is_table_turn(...)`) | about +15 |
| `underground_world_routes.gd` `_stair_decks_refusal` (1035–1043) | **Measured at build (M-1).** The floor decks of rows 71/72/78/84 (y −128..0 in the start frame, reaching back under the stair), and row 53's T6 → floor deck, must be covered by SUPPORT of the edge's Room. If the trench floor is World-owned natural earth, either the bundle successor declares it a natural bearing of the stair Room (no engine edit; preferred), or the deck rule admits never-cut natural footing as the 1971 scrape does | 0, or about +600 |

The backward-heading rule (1206) does **not** apply: rooted rows are stair rows, qualified by `_stair_edge_refusal`,
which checks the exact span. So 1981's inventory item for 1206 is not needed.

Under P-1972-1 (c) (1971's literal plan: v3 successors dispatched beside v2), Routes needs about 2,300–2,600
characters: two preloads, and a third and fourth owner at each of the 13 dispatch sites above, with the clock leaf,
ready request, stationary and arrive branches. WorldRoutes needs about 150 more.

Routes is 244,295 characters at master and 246,841 on the cost lane's branch, against the 262,144 cap
(`mole_profile_catalog.gd SOURCE_CHARS`).

### E. The stair carry's entry side (not the cost lane's files)

- **The bundle successor** `first-entry-prefix-v1/qualified-stairs-v10/` (create-only, from
  `publish_qualified_stairs.py`):
  - content 12's wire (revision 12, `fa96acbe…`) and rebound ground caps;
  - DEC-050's authored paces on the stair Placement's variant 0 (`STAIR_PACES`, publisher 71–72): 30 ticks a tread
    (528 u/s), 45 the turn (116 u/s over 174 u), and 90 for the 343 u handoffs (115 u/s). **The 169 u retreat (rows
    77/83) cannot take 90 ticks** (P-1972-6);
  - `GROUND_PACE_COUNT` 29 → 43 (`underground_route_composition.gd:27`); `FRONTIER_REVISION` 9; `PROFILE_SHA`
    `fa96acbe…`, `GROUND_SHA` `3234f2d2…` (content 12's ground caps still name the v1 claw image, so `rebound_ground`
    stays). The publisher is edited in place, as v8 and v9 were (create-only output);
  - new LANDINGs for T6 (y −896) and the floor (y −1024, z −6318..−5801), appended; appending moves the OPENING's
    region ordinal, so every reader that indexes regions by ordinal is checked;
  - new endpoints appended after the 44 existing ones, so `stair_first + 4 + 3·level + 1` does not move. A stop must
    name a source-4 travel row (`underground_entry_frontier.gd:480-484`), so the floor stops name 53/54/55, never
    71–84;
  - `underground_entry_contact_retirement_scope.gd:18-30`: the hard-coded census 8/22/6/38/44/14 follows v10;
  - `tools/underground_current_census.py:99-100`: `FRONTIER` and `FRONTIER_SHA`;
  - the stops H (L0, z −1536), F (−5975), F′ (−6318) and the floor ascent start (−5801);
  - the T6 and floor stops' footing (M-1).
- **`underground_connector_catalog.gd` `_pace_row_refusal` (532–553):** rows 71–84 fail at 540 (the source is not
  `header[10]`), and rows 73–84 also fail at 551 (CARRY on the WALK variant). The edit: when the row's policy is
  rooted, skip the source clause and let a CARRY row pace the WALK variant. The content stays bound, because
  `header[8]` must equal the pinned Profiles revision.
- **`underground_entry_stair_path.gd`:**
  - `LEVELS` (20, 61) grows to T6 and the floor; the new kinds are H (L0, 512 behind) and F′ (floor, −174). F and the
    floor ascent start classify as A and U of level 7;
  - the edge plan gains a mode word, with the empty WALK edges below T5 and the CARRY edges (1981's list). It plans no
    edge that no row qualifies (`WORLD_ROUTE_NO_FITTING_PROFILE` fails the whole publish);
  - `_stage_edge` (146–147) takes mode and family from the plan; `_joined` and `_missing_count` compare mode;
  - a publish after T6 commits, since nothing publishes the floor stops' edges today;
  - the floor and T6 stop footing (`underground_entry_bindings.gd:1609-1630`) against Locations' installed-contact
    proof is unconfirmed (M-1).
- **The stair motion owner** `underground_stair_motion.gd`: it also loads `qualified-stair-carry-motion-v1/` (14
  programs, revision 12, bound to content 12's wire). The claw tables stay bound to content 10's wire digest
  (`:73`). That is sound because rows 51–55 are byte-identical, and the owner checks the binding against the
  accessor, not the live bank. `program_of` returns the carry programs for 71–84. Census: 33,816 B retained
  (4 × (12 × 14 + 5 × 1,634 + 6 × 18) + 32).

### F. Room height (1971 §6)

- `underground_room_approach.gd` 31–32, 684, 687–698: delete `LEGACY_CONTENT` and `_legacy_band_height_u` **in
  the same commit as the mount**. On its own, the deletion makes content 10's claw height 0, and the demo then
  refuses every level.
- `demo/burrow/modular_runtime.gd:20, 397-415`: `ClawPins` → v13, and its stale docstring. Re-pointing alone
  changes nothing (row 56 is the same in v11–v13); the height follows the mounted bank. **This is a demo file: the
  coordinator's clearance is asked (the Mound PR's neighbourhood).**

### G. Tests that follow the mount

- **Break and must move to content 12:**
  - `test_mole_haul_profiles.gd:93` (67);
  - `test_underground_motion_catalog.gd:38, 80, 94`;
  - `test_underground_support_clearance.gd:42-43`;
  - `test_underground_stairs_bundle_source.gd:101-103`;
  - `test_underground_route_source_checks.gd:162-173` (the owner oracle; the cost lane edits it too);
  - `test/live/demo_build_dig_live.gd:64-65` (`dug_u == 1024` → 4,096);
  - `test_mole_claw_wall_profiles.gd:111-117` (content 10's LEGACY 1,024 u → 0);
  - `test_mole_stair_carry_profiles.gd:153-157` (rooted rows become selectable).
- **Live chain:** `test_underground_host` (`DONE_TICK` 3,462, `DESCENT_DONE_TICK` 8,348, 31 paths). The new floor
  stops and edges may change the path count. Any tick change is measured and reported, never re-pinned silently.
- **Fixtures that keep content 10 and pass unchanged under P-1972-1 (a):** `test_claw_stair_programs`,
  `test_claw_tread_programs`, `test_mole_claw_stairs_profiles`, `test_underground_entry_work_area`,
  `test_underground_haul_grip`, `test_underground_paid_assembly_handling`, `test_underground_stair_routes`,
  `test_underground_room_footprint`.
- **New suites:**
  - the claw wall rows through Routes (entry, stroke, recovery, column);
  - the rooted rows: Routes crossings at 90, 30 and 45 ticks, loaded and empty;
  - the stair path's floor stops;
  - the foreman digging with a way in (§ Behaviour);
  - negative edits for every widened predicate.

## Pins, census and checkpoints (one pass each, after the cost lane merges)

- **Pins:** one `renew_source_pins.py --write` over v13 (now `ACTIVE`). It catches the cost lane's and this lane's
  edits of the ten consumer paths (Profiles, WorkFace, Contacts, Routes, WorldRoutes, the actor, ContentSet, the
  driver and the two programs). Checked with `--check` on v11, v12 and v13.
- **Memory:**
  - `underground_motion_memory.py:151, 208`: joint 270,824; counts (85, 637, 8).
  - `current_census.py` `stair_tables` (396–412, 475–478): the second set of tables, 33,816 B per Session.
  - The `PROFILE_BYTES` row (P-1972-2).
  - `reviewed-deltas.json` (the catalog and Session constants) and `REVIEWED_SHA`.
  - `ready07_arithmetic.py` 323–328, 351–353, 502–505: a new allocation row and a `DECISION_1972` term.
  - `systems_architecture.md` §2.3 rows and the ARCH-MEM-009 trail (`merge_gate.py`).
  - `underground_memory_pack.json` regenerated.
  - Tool tests: `test_underground_motion_memory.py:27`, `test_underground_memory_budget.py:78…`,
    `test_underground_current_census.py:41`.
- **Checkpoints:** `./tools/regenerate_test_checkpoints.sh` (`underground_entry`, `underground_spare`).
  - Unlike 1971 and 1981, the **saves will change**: every resident and edge stores its content revision (Routes
    `R_CONTENT_REVISION`, `E_CONTENT_REVISION`), now 12.
  - The regenerated ledgers and ticks are compared with today's.

## Behaviour change at activation

- **Demo build panel (C1 ledger):** `dug_height_u` = min(4,096, unlimited) = 4,096 u.
  - `quanta_per_cell` = 4. A cell costs wood 1,000, stone 1,000, 16,920 milli-WU and 8,000 milli-U of earth; today it
    is 250, 250, 4,230 and 2,000 (`scripts/ui/build_ledger.gd:34-39, 93-102`).
  - A 2 × 2 Passage patch is 16 quanta. The ground survey reads a 4,096 u column, so more cells near water may become
    unpaintable.
- **Game:** a confirmed room's plan height is 4,096 u, so each painted cell becomes 4 Sites through the cut map
  (`underground_room_bindings.gd:478-507`), paid per phase at DEC-059's amounts.
  - The game has no per-cell price.
  - Every species fits (DEC-039: the badger is 2,611 u).
- **The C2.1 foreman:** nothing composes it outside tests yet. `adopt_underground_rooms` is called only by
  `test_underground_room_runtime.gd`, and C2.3 composes it. Levels 1–4 also have no way in until slice D.
  - What activation makes true is shown in a fixture with a way in: the ADR 1161 Kitchen beside the open Corridor,
    with the content-12 bank and a tool-free claw crew bound to retreat row 47.
  - The planner picks wall rows 67–70: the station is 521 u from the wall, and the stroke strikes the floor-band
    cube. After FINISH, `continue_column` digs the three upper quanta from the same station.
  - The expected ledger for the 2 × 2 Kitchen is 16 Sites: wood and stone 4,000 each, earth 32,000 milli-U and
    67,680 milli-WU. These are decision 1933's ledgers, now on claws instead of the retired pick.
  - Today the same fixture on content 10 halts with `ROOM_STATION_REACH_MISSING`.
  - This is the test this lane adds (a sibling of `test_underground_room_foreman.gd`).
- **The stair carry:** Routes can cross the stair laden, and the empty mole can reach and leave the floor.
  - No caller asks for either until C2.3 binds Delivery's leg-wise reach and the hauler's leg list. They are proved by
    Routes suites and the frames.
  - `ROOM_HAUL_NO_STAIR_CARRY` (`underground_room_builder.gd:72, 315`) stays raised until C2.3.
- **Saves from before activation** that hold an underground Session are refused at load
  (`SAVE_UNDERGROUND_RESTORE_REFUSED`), because their content-10 edges and actors no longer match. ADR 1229 6a's
  9 → 10 switch did the same, unrecorded. See P-1972-3.
- **Cost:** 18 more rows enter every full-row scan:
  - phase requalification (`_compile_profiles`);
  - the itinerary's 16 checks per row;
  - the planner's 8 per row;
  - `_carry_eligible`;
  - the footprint's row-extent cache (+432 B per builder).

  The dig benchmark (`tools/benchmark_dig_tick.gd`) is re-run against the cost lane's numbers.

## Proposals

**P-1972-1 — How revision 12 reaches the content-10 programs (for the coordinator).**

- **(a) Recommended: widen runtime-v2 in place.**
  - One predicate (content 10 or 12); the claw program owns 67–70; the stair program owns 71–84 by the source 6/7
    digests.
  - Rows 0–66 and sources 0–5 are byte-identical, and the Session loads only the pinned wire. The grip certificate
    already set this precedent for content 10 (ADR 1229).
  - Routes needs 0 characters and WorldRoutes about 15, so almost nothing waits for the cost lane. Content-10
    fixtures keep passing.
- **(b)** runtime-v3 successors, with Routes' two preloads repointed (about 0 net characters, 2 lines). The v2 files
  stay untouched, but content-10 route fixtures must move to content 12.
- **(c)** 1971's literal plan: v3 successors dispatched beside v2. Routes needs about 2,500 characters and
  WorldRoutes about 150, all waiting for the cost lane.

**P-1972-2 — `PROFILE_BYTES` (for the coordinator; an engineering budget with its own ledger row, as ADR 1217 step
5).**

- **(a) Recommended:** raise `Budget.PROFILE_BYTES` by 4,096 to 282,624, leaving 2,072 B. This needs a new
  `systems_architecture.md` §2.3 row and the pack regenerated. The world reserve has 49.7 MB of headroom.
- **(b)** Raise it by 16,384 (294,912, ADR 1217's step), leaving 14,360 B for the next content.
- **(c)** Shrink the Session or retirement slice instead. Not recommended: both are reviewed rows unrelated to this
  change.

**P-1972-3 — Pre-activation saves with an underground Session (for Brendan, via the coordinator).**

- **(a) Recommended:** refuse them with the existing code, as 6a did, and record it. The underground is a
  proof-of-concept surface.
- **(b)** A load-time migration that rewrites revision 10 → 12 in Routes' columns. Rows 0–66 are identical, but it
  is a new save-schema path with its own record.

**P-1972-4 — `demo/burrow/modular_runtime.gd` (for the coordinator).** Only the `ClawPins` path and a docstring
change, and the height follows the mount without it. Recommended: edit those two lines in this lane, sequenced after
the Mound PR if it touches the file.

**P-1972-6 — The 169 u retreat's pace (for Brendan; P-1981-3 ruled 90 ticks for each handoff).** A crossing takes
ceil(length × 30 / rate) ticks, and the ticks must divide the clip's 90 intervals. For 169 u, rate 56 gives 91
ticks and 57 gives 89, so no integer u/s rate gives 90. Rows 77/83 would refuse `WORLD_ROUTE_STAIR_PACE`.

- **(a) Recommended:** keep 90 ticks with a finer unit for authored stair paces (milli-u/s). This is a connector
  catalog format extension and `Stair.ticks_for`, with the bundle's existing stair paces rescaled (528,000 and
  116,000) and their ticks unchanged. It honours the ruling. It costs one more format change and its tests, and no
  Routes characters if the unit is applied inside `ticks_for`; that is checked at build.
- **(b)** 45 ticks (rate 113–115): the three retreat steps play at twice the approach's speed.
- **(c)** 30 ticks (rate 169).

**P-1972-5 — Profiles edits before the cost lane merges (for the coordinator).** The hunks are disjoint from the
cost lane's. Recommended: build them now and take the one pin renewal after the merge.

## Order of work, after the reply

1. B, C, E, F and G in this lane's files, with fixture tests (no Routes or WorldRoutes edit).
2. Stop and report.
3. After the cost lane merges: merge master, the one WorldRoutes line (and M-1 if needed), the mount (A), the census
   (P-1972-2), one pin renewal and one checkpoint regeneration.
4. Gates: the CI-style run, the analyzer at `--max 0`, the contracts, mutation testing, the independent
   `code-reviewer`, and the frames (a claw-digging mole at a wall; a stair carry at 1280×720 and 1920×1080 in
   `scratchpad/activate_check/`).

## Source

- Decisions 1971, 1981, 1229, 1951, 1931–1935; `docs/handoff/RULINGS.md` 169–205; DEC-039, DEC-050, DEC-054
  (2026-10-15 addendum), DEC-059.
- The code at `a0daf1ab`, read directly and by three read-only research passes (not committed).
- The cost lane's worktree, read only (`git diff --stat` and hunk headers against its merge base `fd1c6d70`).
