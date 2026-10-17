# 1972 — Activating contents 11 and 12: scoping, stopped for the coordinator

Date: 2026-10-16 · Status: Accepted. Brendan ruled P-1972-3 and P-1972-6, and the coordinator P-1972-1, -2, -4 and -5,
on 2026-10-16 (see "Rulings"). Phase 2 (the build of everything outside the cost lane's files) follows. On 2026-10-17
Brendan ruled option (d), "Switch on without floor end": "Phase 3b" mounts content 12 without the floor end.

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
| P-1972-7 | Brendan, **"Natural earth counts"**: (a) (2026-10-16) | Dry, never-cut natural earth counts as support under a landing, by 1971's natural-earth test; the WorldRoutes deck half waits with the cost lane's lines ("Phase 2b") |
| P-1972-8 | Coordinator: (a) (2026-10-16) | This lane edits `underground_locations.gd` `_installed_row_site` only (the cost lane edits another function there), with a floor-stop and a natural-stop test; the terrain-footing refusal gets a negative test through a test double |
| P-1972-9 | Coordinator: (a) (2026-10-16), the coordinator's call under P-1972-7 | Retain the trench floor: natural earth 128 u deep under the Placement's cut set at a natural landing's floor, as the Room's SUPPORT, less the bearings kept; WorldRoutes stays at +33 / −2 |
| P-1972-6 | Brendan, **"Keep 90 ticks"**: (a) | Authored stair paces move to milli-u/s. Every existing authored pace is rescaled ×1,000, so its ticks stay identical; the 169 u retreat takes exactly 90 ticks |
| Phase 3a options | Brendan, **"Switch on without floor end"**: (d) (2026-10-17) | Mount with the stair carry from H down to T6 and back. The floor end (F, U, F′, its edges and the trench retention P-1972-9) waits for slice D's F40. The ~95-character `_carry_eligible` skip in WorldRoutes is cleared ("Phase 3b") |

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

## Phase 2a — what was built outside the cost lane's files (2026-10-16)

Nothing is mounted: the Session still loads content 10 and `qualified-stairs-v9`, and the live entry chain is
unchanged (tick 8,348, the same ledgers).

### The programs and certificates (P-1972-1 (a))

- **`qualified-claw-runtime-v2/claw_program.gd`.**
  - `serves(content)` (10, or its successor `SUCCESSOR_CONTENT` 12) is the one content predicate.
  - `in_block` adds the wall rows 67–70 (`is_wall`): WORK, `POLICY_SOURCE_WORK`, yaws 0..49152, M1's dig clips.
  - Pins move to v13's accessor (its constants for rows 0–66 are v11's).
- **`stair_program.gd`.** It owns rows 71–84 by the source 6/7 image digests:
  - `source_of`, `policy_of`, `yaw_of`, `mode_of` and `_cargo_matches`: a loaded row repeats row 32's or 37's cargo
    words;
  - a rooted row qualifies only on content 12;
  - `ticks_for` takes milli-u/s (P-1972-6).
- **`paw_program.gd`.** `census_matches` admits content 10's census or content 12's (85/637/8).
- **The other consumers read `serves`:**
  - `paw_physical_certificate.gd` (the tap now passes the loaded revision);
  - `qualified-claw-certificate-v2/endpoint_certificate.gd`;
  - runtime-v1's `endpoint_certificates.gd` and `handling_programs.gd` (through `_v2`);
  - `mole_claw_program.gd`, `mole_presentation.gd`;
  - Contacts' two Frontier checks (1019, 2036).
- **`grip_certificate.gd`** admits content 12. Its rooted CARRY rows hold the hold's grip by identity (1981's proof).
- **`underground_entry_bindings.gd`.** A stair stop faces up for any stair row at yaw 32768.
- **`underground_entry_foreman.gd`, Contacts.** Their Pins move to v13.

### Profiles (P-1972-5)

- `selection_policy_leaf` returns 10–13.
- `query_travel_profile_into` admits the rooted words and selects with the row's own mode, so a CARRY row needs the
  actor's actual cargo.
- `is_table_turn` (9 and 13) replaces `_matches`' half-turn exemption.

### Stair timings in milli-u/s (P-1972-6, "Keep 90 ticks")

- **`underground_connector_catalog.gd`:**
  - `RATE_AUTHORED_MILLI` = 2 is admitted only for a row the stair program owns;
  - its cap check is ×1,000;
  - `pace_into` reports every stair-program row's pace in milli-u/s: a u/s authored rate or ground cap ×1,000, so v9's
    rows and the short steps keep their ticks;
  - a rooted row (policy 10–13) may pace the stair Placement's variant from its own source 6/7, and a rooted CARRY
    row may pace the WALK variant.
- **`Stair.ticks_for`** = ceil(length × 30,000 / pace). The 169 u retreat at 56,334 milli-u/s takes exactly 90
  ticks (56,333 gives 91).

### The stair motion owner, the stair path and the bundle

- **`underground_stair_motion.gd`.** `load_carry_file` appends the stair-carry tables after the claw tables:
  - programs, keys and decks are rebased, and every reader serves both;
  - a refusal restores the claw bank;
  - the carry columns retain 33,784 B (its profile digest is checked, not kept; the record above said 33,816).
- **`underground_entry_stair_path.gd`.**
  - Levels reach the sill (6) and the floor (7). The new kinds are H (343 u before A on L0) and F′ (343 u behind F).
  - Plans are six words with a mode: 7 floor-end WALK edges and 21 CARRY edges, both gated on F existing, so the
    entry chain is unchanged until the sill is in.
  - `_joined` compares the mode.
- **`qualified-stairs-v10`** (create-only; publisher edited in place as v8 and v9 were):
  - content 12, Frontier revision 9;
  - all 17 stair timings as milli rows from ceil(length × 30,000 / ticks);
  - LANDINGs for the sill and the floor;
  - five stops appended after v9's 44: A and U on the sill, and F, U and F′ on the floor;
  - `entry_source_constants.py` admits kind 2.
  - **H is not a new stop:** it is claw-v6's L0 station at (0, 0, −1536), already endpoint 3. A first draft added a
    duplicate, which was removed before any use.

### Tests

- `test_content_twelve_programs.gd` (11): the predicate, the wall rows, the rooted rows and six edited-word
  refusals, the paw and certificate admission, the carry bank, and the stair path's classes, plan and gate.
- `test_underground_stair_routes.gd` is parameterised by content. Its subclass `test_underground_stair_carry_routes.gd`
  reruns the five claw stair tests on content 12 with milli paces and adds:
  - the empty walk-off in 90 ticks;
  - the milli reporting;
  - the refusal of a milli pace on row 43;
  - the rooted source rule.
- Updated: `test_claw_stair_programs` (milli `ticks_for`), `test_mole_stair_carry_profiles` (rooted rows now
  selectable), `test_underground_stairs_bundle_source` (v9's rates reported ×1,000), the bundle's Python tests (7).
- Census: the catalog's two constants (reviewed delta, `REVIEWED_SHA`) and the stair motion owner's two members. The
  pack is regenerated with live totals unchanged (100,250,607 B). The checkpoints are regenerated, with saves
  byte-identical.
- **Gates run so far:**
  - focused suites: 143 tests, 0 failures, 0 unexpected diagnostics, 0 leaks;
  - `test_underground_host` and the entry suites on content 10: 94 tests pass, ticks unchanged;
  - the analyzer: 0 warnings in 1,568 files;
  - contracts: decision numbers, merge gate, registry, lane notes, pins, census and `ready07`, dispatch, state table,
    inbox: pass.
  - The full CI-style run, mutation testing and the independent review are for the final phase.

## Measurement M-1 (2026-10-16), on a scratch mount (not committed)

The mount (section A plus the LEGACY deletion, `PROFILE_BYTES` 282,624 and the retirement scope's 49 endpoints) was
applied in the worktree, the live descent run, and the change reverted. The patch is
`scratchpad/activate_mount/mount-v2.patch`.

### M-2: content 12 overflows the shared check bound on master's WorldRoutes

- With content 12 mounted, the live descent stops on **tick 7,093** with `WORLD_ROUTE_CHECK_CAPACITY`. A WorldRoutes
  preparation needs more than `Space.MAX_CHECKS` (1,048,576).
- On content 10 the same chain's largest preparation spends **1,038,133 (99.0 %)**.
- Content 12's 18 more rows enter every per-profile loop (`_compile_profiles`, `_carry_eligible`). With the bound
  raised in scratch only, the peak is 1,067,179 and the chain reaches tick 8,348 with unchanged ticks.
- No budget was raised. This is the cost lane's ground (P-1951-2 (a), skip unchanged refused profiles), so the mount
  is re-measured on master after that merge. If it still overflows, it comes back as a proposal.

### M-1: the floor end cannot stand on natural earth as the engine is written

With the bound raised in scratch, the sill commit refuses `ENTRY_INSTALLED_CONTACT_REQUIRED`:

- **The sill's stops (A and U on T6) qualify.** The sill deck is installed solid under its LANDING.
- **The floor stops do not** (endpoint 46, F first). `underground_entry_bindings.gd _timber_staged_support` requires
  the whole LANDING to have *installed* SUPPORT owned by the installation under it. The trench floor is natural,
  never-cut earth, so the 2,048 × 1,536 u floor LANDING is uncovered.
- **The floor decks have the same gap.** Decision 1981's tables give the floor rows (71, 72, 78, 84) the bottom
  fixture's whole floor slab as their deck: y −128..0 under the start, from 1,193 u ahead to 5,975 u behind, that is
  under the whole stair. WorldRoutes' `_stair_decks_refusal` covers decks only with SUPPORT owned by the edge's Room
  or, outside a Room, the World's. Natural earth under the treads is neither, so those edges would refuse
  `WORLD_ROUTE_STAIR_SUPPORT` once the stops exist.
- **Consequence.** Until this is ruled, the floor stops, the floor end's edges and every CARRY edge (which waits for
  F) do not exist in the game. Routes itself carries rooted rows: the fixture suite crosses them on World-owned
  SUPPORT.

### Two gated lines in the cost lane's files, measured

They were tried in scratch and then reverted. The patch is `scratchpad/activate_mount/gated-routes-lines.patch`, and
the tests that need them are in `scratchpad/activate_mount/test_underground_stair_carry_routes.full.gd`.

- **`underground_routes.gd` `_actor_profile_into`: +33 characters.** `mode == MODE_WALK` becomes WALK or CARRY.
  - A CARRY actor's every later re-selection reads its committed mode, CARRY, which otherwise falls to automatic
    lookup and refuses `ROUTE_CONTACT_PROFILE_STALE`.
  - This corrects §D's "0 characters".
- **`underground_world_routes.gd` (1503): −2 characters.** The stale-selection heading exemption reads
  `Profiles.is_table_turn`.
- **With both lines:**
  - a loaded descent crosses in 30 ticks, its row admitted only with the wood;
  - the loaded 169 u retreat takes exactly 90 ticks;
  - the loaded floor half-turn ends on heading 32768 in 45 ticks;
  - 17 tests, 0 failures.

### What else the mount needs (re-checked on the scratch mount)

- `underground_entry_contact_retirement_scope.gd`: `ENDPOINTS` 44 → 49, which moves its registry sizes (8 and 1 words
  per endpoint): `_source32` 1,356 → 1,396 and `_source64` 158 → 163, with their registry rows.
- `underground_route_composition.gd`: `GROUND_PACE_COUNT` 29 → 43, and the carry bank loaded beside the claw tables.
- A publish of the floor end and the carry edges after the sill commits. Today the stair path publishes only before
  each tread's installation.
- The presentation of sources 6/7 (`mole_presentation.gd present_stair`) and the ContentSet's `MAX_SOURCES` 6 → 8
  (`demo/cast/underground_content_set.gd`, demo side).

## P-1972-7 — The floor end's footing (for Brendan, via the coordinator)

The trench floor is natural ground (ADR 1209). The engine accepts only installed, Room-owned solid under a stop's
LANDING and under a stair deck.

- **(a) Recommended: natural footing counts.** Under a LANDING and under a stair deck, never-cut, dry, natural earth
  counts as support: 1971's scrape test, `Terrain.natural_support_refusal` and no Site ever cut it.
  - The LANDING half is in `underground_entry_bindings.gd` (not the cost lane's).
  - The deck half is in WorldRoutes `_stair_decks_refusal` (the cost lane's file, about +600 characters).
  - No content changes.
- **(b) Data only.** The bundle retains the floor as a natural bearing of the sill's assembly (Room-owned SUPPORT,
  as the posts' bearings are), and the stair-carry tables are republished with each floor deck clipped to the floor
  the proof's contacts actually stood on. That is a successor of decision 1981's tables from its own tooling, with
  the proofs re-run.
- **(c)** Leave the floor end out of this lane. Loaded travel then ends on T6, which is not the room level, and C2.3
  cannot supply a room.

## Phase 2b — natural earth under a landing (P-1972-7 (a), 2026-10-16)

The coordinator's further rulings (2026-10-16):
- **M-2:** `Space.MAX_CHECKS` is not raised. It is re-measured after the cost lane merges; if it still overflows, the
  lane stops with options.
- **Demo files:** `demo/cast/underground_content_set.gd` (`MAX_SOURCES` 6 → 8) and the two `modular_runtime.gd` lines
  are cleared after PR #267 merges.
- **With the mount:** the retirement endpoints and registry rows, `GROUND_PACE_COUNT`, the republish after the sill,
  and the presentation of sources 6/7.

### Built (`underground_entry_bindings.gd`, the one cleared edit)

`_timber_staged_support` keeps its rule that a LANDING must have actual solid under its whole footprint. What the
installation's own SUPPORT leaves (`_timber_support_residual`) may now be natural earth, proved as a natural bearing
is proved, in two halves:

- **While staging** (`_timber_natural_support`): no Site ever cut a quantum it meets (`_timber_virgin_keys`), and
  only unclaimed natural matter or support stands in it (`_timber_natural_rows`).
- **Under the sealed candidate** (`_timber_landing_footing` in `_timber_physical`'s final pass): the terrain's
  original footing is dry there (`Terrain.FOOTING` with the sealed Space token).
  - Terrain facts cannot be read while staging. A natural bearing defers the same check to its final pass, and so
    does this.
  - The preflight pass (no Space token) skips it, because nothing is staged yet.

Natural-bearing code is reused, not WorkFace's: the module already proves natural earth for the posts' bearings.

### Tests (`test_underground_entry_bindings.gd`, 43 pass)

- `test_a_landing_over_natural_earth_is_supported`. Mode 6: the LANDING reaches 512 u past its deck. It publishes,
  with one natural proof, clear, and the sealed footing observing the one natural fragment.
- `test_a_landing_over_a_dug_cube_is_not_supported`. Mode 7: the deck covers only the far half; the near half is
  over the paid, dug cube. It refuses `ENTRY_INSTALLED_CONTACT_REQUIRED`, nothing is published and the receipts are
  kept.
- `test_shared_landing_stages_support_once_but_proves_every_contact` now also asserts that a landing on its deck
  needs no natural earth and leaves no residual.

### M-1 rerun: the next gap is in Locations

On the scratch mount (with the check bound raised in scratch only), the floor's LANDING now stages. The sill's
commit then refuses `LOCATION_PAID_SITE_MISSING`:

- `underground_locations.gd _installed_row_site` witnesses an installed (LANDING) record only when it stands on the
  top of one of the Placement's installed prisms, and takes its paid Site from that prism.
- A floor stop stands on natural earth, so it has no prism and no witness.
- The natural counterpart is the paid cube the stop stands in: the trench's cut cube, a Site of the stair's Room.
  The non-LANDING path already uses `_installed_site_row(_cube_origin(point))`.
- The fix: when no prism top holds the point, accept that cube if it is a paid Site of the record's Room and the
  landing's residual is natural. That edit is in `underground_locations.gd`, which this lane was not cleared for. It
  is asked of the coordinator (P-1972-8).

**P-1972-8 — clearance for `underground_locations.gd` `_installed_row_site` (for the coordinator).**

- **(a) Recommended:** clear the edit in this lane, with tests (a floor stop witnessed by its cut cube; a stop over
  natural earth outside any paid cube refused).
- **(b)** The cost lane's owner makes it.

## Phase 2c — the floor stops stand (P-1972-8 (a), 2026-10-16)

### Built

- **`underground_locations.gd` `_installed_row_site` (the one cleared hunk).**
  - It still witnesses a LANDING stop through the prism top it stands on.
  - New: when no installed prism top holds the point at all, the stop stands on natural earth. It is witnessed only by
    the completed (`SUPPORTED_VOID`) same-Room paid cube whose floor it stands on: the point's y is that cube's
    floor. For the trench floor, that is its own cut cube.
  - A prism that holds the point but fails its witness still refuses, as before. So does an uninstalled prefix, and so
    does a fractional root inside a cube (its y is not the floor).
- **`underground_entry_bindings.gd`.** Two more pieces were needed beside the cleared support edit:
  - **`_stage_natural_support`.** The proved natural earth under a landing is retained as the Room's SUPPORT, staged
    beside the landing's datum, exactly as the posts' natural bearings already are (Room-owned SUPPORT at
    y −1152..−1024).
    - Locations covers a stop's footing only with SUPPORT rows, and the natural ground under the trench floor has no
      Space row. Measured: only the posts' bearings are rows there.
    - So without this, a floor stop refuses `LOCATION_COVERAGE_MISSING`.
  - **`_timber_prism_residual`.** The final pass now finds the natural part as what this Placement's installed timber
    prisms leave, not what SUPPORT rows leave. Once the natural earth is retained as SUPPORT, rows can no longer tell
    it apart; prisms can.
- **The terrain-footing negative test, through a test double.** `ObservedBinding._timber_terrain` stands in a
  non-dry verdict only on a landing's natural residual (`residual_terrain`), so the final pass's refusal is
  exercised: `test_a_landing_whose_natural_earth_is_not_dry_footing_is_refused`.

### Tests (`test_underground_entry_bindings.gd` and `test_underground_locations.gd`: 113 pass)

- **The natural-landing test** now also asserts that the natural strip under the landing is a live SUPPORT row of
  exactly its box.
- **`test_a_stop_over_natural_earth_outside_any_paid_cube_is_refused`.** A stop on the landing's natural part, above
  unpaid ground, refuses `LOCATION_PAID_SITE_MISSING`.
- **The positive witness (a floor stop accepted through its cut cube)** is proved on the live chain: this fixture has
  one LANDING and no cut cube with a bare natural floor.
  - On the scratch mount the whole descent finishes on tick 8,348 with `ENTRY_KITCHEN_UNBUILT`, the normal end. The
    sill's stops A(T6) and U(T6) and the floor's F, U and F′ all stand (`scratchpad/activate_m1/m1-floor-stops-created.log`).
  - Its committed assertion lands with the mount, in `test_underground_host_whole_chain.gd`: the five stops exist
    after the sill, each witnessed by its cut cube or the sill.

### M-1, re-measured with everything above

The floor end's first refused edge is the claw descent from the sill to the floor (row 53, A(T6) → F), with
`WORLD_ROUTE_NO_FITTING_PROFILE`. This is with Routes' and WorldRoutes' gated lines applied in scratch.

- Row 53's lower fixture deck (64 u of floor), and the carry rows' floor slab (128 u, reaching under the whole stair),
  are deeper and wider than the 1 u strip retained under the landing.
- So the WorldRoutes deck half of P-1972-7 (natural earth under a stair deck) is needed, as expected. It waits with
  the cost lane's lines.
- Its design question for then: WorldRoutes binds Terrain but not Sites, so "never cut" has to come from the Space
  rows and Terrain's footing, or Sites has to be bound.

## Phase 2d — can retained natural earth replace the WorldRoutes deck rule? (2026-10-16)

The coordinator asked whether retaining natural earth as the Room's SUPPORT could stand in for the WorldRoutes deck
rule. With that, WorldRoutes' existing rule (Room or World SUPPORT) would accept the decks unchanged.

### Built

When a landing stands partly on natural earth, the natural earth under its **whole footprint, 128 u deep**
(`NATURAL_DEPTH_U`, the natural bearings' depth in ADR 1209: y −1152..−1024 under a floor at −1024) is:
- proved by the cut history and matter (`_timber_virgin_keys`, `_timber_natural_rows`), once, at that depth;
- retained as the Room's SUPPORT;
- checked at the final pass for dry original footing over the same depth.

A landing on timber alone has no natural strip and is not observed.

### Measured on the scratch mount (each planned edge published alone after the live descent)

Logs are in `scratchpad/activate_m1/`.

- **Published:**
  - every CARRY edge on the stair: H → A(L0), each tread descent to T6, each ascent from T6 to U(L0), and U(L0) → H;
  - the sill's WALK edges (T5 → T6 and T6 → T5).
- **The decks under the floor landing now pass.** These are rows 53, 54 and 55 and their loaded twins (74–76,
  80–82). Their next refusal is their **body cover** (`WORLD_ROUTE_COVERAGE`):
  - the bodies at a floor root reach 1–2 u below the floor plane (y −1..−2 lows), and 512 u past the floor landing
    under the sill (z −5632..−5120);
  - there the earth is natural but not retained;
  - `_stair_covered_refusal` accepts only void, the Room's SUPPORT or exterior air.
- **The handoff rows' floor slabs still refuse** (`WORLD_ROUTE_STAIR_SUPPORT`). These are rows 71, 72 and 78/84, and
  73/79 as the walk-off. Decision 1981's tables give them the bottom fixture's whole floor slab, 128 u deep under the
  entire stair (to z 0, or to −4439 for the walk-off), far outside the floor landing.

### So landing-sized retention is not enough. Two ways to finish

- **(a) Recommended: retain the trench floor.** When a group's landing stands on natural earth at a cut floor,
  retain, 128 u deep, the natural earth under every cut cube of the Placement's Frontier cut set at that floor (for
  this bundle the whole trench, x ±1024, z −7168..0) as the Room's SUPPORT, less the bearings already retained.
  - Proof, retention and the final footing check are the same three steps as above.
  - It covers both the bodies' sub-floor sliver and the handoff slabs. **WorldRoutes needs nothing beyond the +33 /
    −2 lines, and nothing new needs Sites.**
  - The footprint comes from the bundle's own cut set, not a new constant.
  - Cost: about 30 subtracted bearing boxes, so a few dozen staged rows inside `REGION_CAPACITY` 6,144, once, at
    the sill's commit.
  - It blocks no planned dig:
    - rooms cut above their floor, never below it;
    - the 1971 floor scrape admits never-cut earth whoever owns it (review M6, "Leave as built");
    - only a future dig *under* the stair (slice D) would meet it, and that is earth the stair stands on.
- **(b) The WorldRoutes rule.** Admit natural earth (Space rows plus Terrain footing, without Sites) in both
  `_stair_decks_refusal` and `_stair_covered_refusal`. That is now about 900 characters, because the bodies need it
  too.

## Phase 2e — the trench floor is retained (P-1972-9 (a), 2026-10-16)

**The coordinator's call under P-1972-7 (Brendan, "Natural earth counts").** The retention follows directly from
that ruling. WorldRoutes stays at its +33 / −2 lines, and no Sites binding is added.

### Built (`underground_entry_bindings.gd`)

- `_stage_natural_support` retains two things, when a landing stands partly on natural earth, 128 u deep, less what
  is already SUPPORT (the posts' and the sill's bearings):
  - the natural earth under the landing's footprint;
  - **every cut cube of the Placement's Frontier cut set whose floor is the landing's floor.** For this bundle that is
    the whole trench, x ±1024, z −7168..0: the prefix's cubes and rows 4–7.
- Each part is proved by `_retain_natural`, with the same staging proofs: no Site ever cut it, and only natural
  matter or support stands in it.
- `_cut_floor_footing` adds the dry-footing proof at the final pass, under the sealed candidate, over what the
  installed timber prisms leave of each cut-floor slab.
- A landing on timber alone is neither retained nor observed.

### Why it blocks no planned dig (the coordinator asked for this analysis)

- **No room is dug at the flight's floor today, and a room on level 1 does not reach the strip except by overlapping
  the stair itself.** (Corrected below, "What the stair carry supplies"; the first draft said "a room on the Kitchen
  level digs y −1024..0 cubes", which was wrong.) Rooms are cut above their own floor, never below it.
- **The claw floor scrape** (decision 1971, P-1971-2 (a)) may enter never-cut natural earth whoever owns it (review
  M6, "Leave as built"). So a wall dig beside the trench may scrape into the stair Room's strip.
- **Only a future dig under the stair (slice D) would meet it,** and that is earth the stair stands on. Refusing to
  undermine it is right.

### Measured (scratch mount, every planned edge published alone after the live descent)

Log: `scratchpad/activate_m1/m1-all-edges-publish.log`.

- **All 33 planned edges past the descent publish:**
  - the floor end's seven WALK edges, including rows 53, 54 and 55 to and on the floor;
  - the walk-off and back-up F ↔ F′;
  - every CARRY edge: H → A(L0), eight descents to F, F ↔ F′, the floor half-turn, eight ascents to U(L0), and
    U(L0) → H.
- This was with the gated Routes and WorldRoutes lines applied, and the check bound raised in scratch only (M-2
  stays open until the cost lane).
- The descent still ends on tick 8,348 with `ENTRY_KITCHEN_UNBUILT`.

### Tests

- **`test_underground_work_face.gd`:** `test_a_retained_trench_floor_never_blocks_a_room_dig_beside_it`. Another
  Room's 128 u SUPPORT strip lies under the target cube:
  - the cube above it is dug as before;
  - the floor scrape into the strip is admitted;
  - with the strip's quantum marked cut, the same scrape refuses, which shows it does reach the strip.
- **`test_underground_entry_bindings.gd`:** 45 pass. A landing on timber alone has no natural strip and no sealed
  footing observation.
- **Not yet covered by a committed test:** the cut-set retention itself. Its fixture has one LANDING and no cut floor
  at a landing's level. It is proved on the live chain above. Its committed assertions land with the mount in
  `test_underground_host_whole_chain.gd`:
  - the retained SUPPORT under the trench;
  - the floor and CARRY edges published after the sill.

## What the stair carry supplies, and what waits for slice D (2026-10-16)

The slice D session (decision 2041 §1, branch `docs/slice-d-flight`) raised a level mismatch. It is checked here
against the code at `c11da82e`.

### The flight's floor is not a room level

- The first-entry flight ends at the trench floor: local y −1024, which is world −512 with the domain datum at 512.
- Room admission (`underground_room_bindings.gd _level_refusal`, through `underground_level_catalog.gd level_into`)
  accepts a Room only at a roofed level's authored floor. Level 1's floor is the datum less the 5,120 u spacing,
  −4,608, with the section offsets −1,024, 0 and +1,024: so **−5,632, −4,608 or −3,584**.
- A room painted at the flight's floor (−512) is therefore refused `ROOM_AUTHORED_LEVEL_REQUIRED`.
- **The "Kitchen level" this record and decision 1981 speak of is the trench floor, and it serves no C2.3 room dig.**
  Room digs on level 1 need slice D's full-level flight (F40).

### So the stair carry activated here supplies the entry and its trench floor

- A loaded mole can carry wood or stone from H on L0 down the stair to the floor (F, F′), turn, and carry it back up.
  The empty mole can reach the floor and climb from it.
- That is the stair and its floor. **It is not yet room supply.** C2.3's leg-wise Delivery reach and the hauler's leg
  list have no room destination on that floor to serve.
- Room supply on level 1 waits for F40, which will need the same rooted rows on a longer flight.

### Phase 2e, corrected

- The retained trench-floor strip lies at world −640..−512.
- **Level 1's rooms** stand at floors −5,632 to −3,584, with 4,096 u of clear height. Only a level-1 room at the
  +1,024 section offset reaches as high as the strip, and only directly under the trench. Such a room would already
  meet the stair's own Space there (its void and timber), so the strip adds no new conflict.
- **The claw floor scrape** still admits never-cut earth whoever owns it (review M6).
- **Slice D's digs under the stair** meet earth the stair stands on.
- The committed test (`test_a_retained_trench_floor_never_blocks_a_room_dig_beside_it`) shows the general rule on a
  corridor fixture: another Room's retained strip under a target cube neither blocks the cube's dig nor its scrape.

### File handoff (2026-10-16, from the coordinator)

Slice D will not edit this lane's files until activation merges:
- the stair path, entry bindings, connector catalog, Contacts, Locations, Profiles, the stair motion owner and the
  entry foreman.

This lane keeps its edits to what activation needs.

## Phase 3a — after the cost lane (2026-10-16): M-2 still overflows; stopped for options

### Done

- **Master merged** with #269 (the cost lane, `353706cd`). Conflicts were the census `REVIEWED_SHA` (recomputed), the
  two checkpoint manifests and the memory pack (master's, then regenerated), content 10's pins (master's, then
  renewed), and `RULINGS.md` (both sides' rows kept).
- **The two gated lines are applied**, with the held-back loaded tests (`test_underground_stair_carry_routes.gd`,
  11 + 6 tests pass):
  - Routes `_actor_profile_into`: WALK or CARRY, +33 characters;
  - WorldRoutes' stale-selection heading exemption through `Profiles.is_table_turn`, −2 characters.
- **Retention proofs:** a trench-floor slab, which lies wholly below a cut floor, is proved at once, not fragment by
  fragment. The cut-floor footing is observed slab by slab. A landing's footprint, which may hold timber in a dug
  cube, is still proved fragment by fragment.

### M-2, re-measured on master after the cost lane (the mount in scratch, `Space.MAX_CHECKS` not raised)

- **The live descent still stops on tick 7,093** with `WORLD_ROUTE_CHECK_CAPACITY`. The same preparation still needs
  more than 1,048,576 checks (`scratchpad/activate_m1/m2-overflow-tick7093.log`). The cost lane's memos did not
  reach it.
- **Where:** a tread installation's completion:
  - `Installer._recover` → `complete_order` → `Placements.prepare_completion` → `_prepare_routes` → WorldRoutes
    requalifies every live edge;
  - the extra spend is content 12's 18 rows in `_carry_eligible`'s per-profile loop.
  - The empty rooted rows 71/72 kind-match every ground (family −1) WALK edge, so each is swept against every change
    since the certificate. Yet a rooted row can never serve a ground edge, since its certificate is span-exact.
- **One candidate measured (scratch only, not kept).** In `_carry_eligible`, skip a rooted stair row on a ground
  edge: `if edge.family < 0 and Routes.Stair.is_rooted(profile) and _stair_row(profile): continue`, about +95
  characters in WorldRoutes. The descent's peak falls to **1,000,378 (95.4 %)**, below content 10's own 1,038,133.
- **A second overflow behind it: the sill's commit.**
  - With the trench retained (48 SUPPORT rows: the floor slabs less the 26 retained bearings), the sill's completion
    requalification needs **1,687,943** checks (161 %). Each retained row is a Space change every live edge's carried
    certificate must be swept against.
  - The republish of all 33 floor and CARRY edges after the sill, in one preparation, needs 544,031 (52 %).

### Options (for the coordinator)

- **(a)** Admit the +95-character `_carry_eligible` skip (the cost lane's file).
  - For the sill commit, retain only what the floor end needs: the cut cubes under the floor stops and the sill, a
    handful of rows.
  - Republish decision 1981's stair-carry tables with each floor deck clipped to the floor its proof stood on, so no
    deck reaches under the treads. This is a data successor from that lane's own tooling, with the proofs re-run.
- **(b)** Keep the whole-trench retention and make the requalification cost independent of how many rows a commit
  adds: a WorldRoutes change in the cost lane's domain (for example, sweeping a carried certificate against the union
  bounds of a commit's changes). Its size is not yet measured.
- **(c)** Raise `Space.MAX_CHECKS` (a budget ruling; the gate forbids it without one). 2,097,152 holds every
  preparation measured above.
- **(d)** Mount without the floor end. The stair carry then works from H to T6 and back, and the floor end waits for
  slice D's F40, which needs the floor anyway. Only the `_carry_eligible` skip is needed.

**Recommendation: (a).** It keeps every budget, all three parts are bounded, and the clipped decks also remove an
over-wide fixture artifact from the runtime proof.

## Phase 3b — mounted without the floor end (Brendan, 2026-10-17: "Switch on without floor end")

Brendan chose option (d) of Phase 3a. Content 12 is mounted with the stair carry from H on L0 down to the sill (T6)
and back. The floor end waits for slice D's full-level flight (F40), which reworks that floor anyway. The coordinator
cleared the `_carry_eligible` skip in WorldRoutes. Nothing was sent to slice D.

### Built

- **WorldRoutes `_carry_eligible`** (the cleared line, +95 characters): a rooted stair row is skipped on a ground
  edge, `if edge.family < 0 and Routes.Stair.is_rooted(profile) and _stair_row(profile): continue`. A rooted row's
  certificate is span-exact, so it can never serve a ground edge. Without the skip the empty rooted rows 71/72
  kind-match every ground WALK edge and each is swept against every Space change since its certificate (M-2).
- **`qualified-stairs-v10`, republished in place** (create-only and never merged, so no successor is needed):
  - one more LANDING, the sill's top (T6); the floor's LANDING is gone;
  - two more stops after v9's 44: A and U on T6 (46 endpoints). H is claw-v6's endpoint 3, (0, 0, −1536);
  - the 17 milli-u/s stair paces are unchanged (rows 53–55 and 71–84).
- **`underground_entry_stair_path.gd`:** levels L0, T0..T5 and the sill (no floor level, no F′ kind). Past the
  descent's 33 WALK edges, the plan holds the sill's two WALK edges (T5 → T6 on the descent, T6 → T5 on the ascent)
  and 17 CARRY edges: H → A(L0), seven descents to T6, the half-turn A → U on T6, seven ascents to U(L0), U(L0) → H.
  They wait for the sill's arrival A(T6), so the chain up to the sill is unchanged.
- **`underground_entry_foreman.gd`:** after each installation's `STAGE_DONE` the foreman publishes the edges that
  installation made possible (`_publish_sill_edges`), so the carry edges stand as soon as the sill is in.
- **`underground_entry_bindings.gd`:** the trench retention (P-1972-9) is removed, so it cannot run at the sill's
  commit: `_stage_natural_support` retains only a natural landing's own footprint, and `_cut_floor_footing` is gone.
- **The mount's other items:**
  - the catalog accessor (`mole_profile_catalog.gd`: v13 pins, 85 rows, 637 boxes, 8 sources);
  - `Budget.PROFILE_BYTES` 282,624 (P-1972-2 (a));
  - the route and entry composition and entry site on bundle v10, 43 ground paces, the stair-carry tables loaded
    into the stair motion owner's second bank;
  - the retirement scope's 46 endpoints;
  - decision 1971's LEGACY band in `underground_room_approach.gd` deleted (the claw crew now digs the whole column);
  - the Session's presentation set with the two stair-carry images (sources 6 and 7);
  - `mole_presentation.gd` presenting a stair row from its own source, and the held stock and stone meshes;
  - `runtime_files.gd` and the demo pack; `renew_source_pins.py` ACTIVE on content 12;
  - the source-only motion catalog and clock (`underground_motion_catalog.gd`, `underground_motion_clock.gd`) rebound
    to content 12's motion wire (`qualified-stair-carry-v13/motion.ugmotion`, revision 12, the same tables), as
    ADR1229 rebound them to content 10's; the clock census pin is renewed for that digest only;
  - the save registry's SOURCE32/SOURCE64 rows and the census (below).

### P-1972-7 kept, P-1972-8 removed, and why

- **P-1972-7, natural earth under a landing, is kept** (`_timber_natural_support`, `_timber_landing_footing` and
  `_timber_prism_residual`):
  - it is Brendan's ruling ("Natural earth counts"), and F40 needs it;
  - it is harmless: it acts only when a landing stands partly on natural earth. Every mounted landing (L0, T0..T6)
    stands on installed timber, so the proof is empty and returns at once (`proof.count == 0`), and the chain's
    ticks are unchanged. The independent review confirmed it inert: with all three branches forced to refuse, the
    whole chain stays green;
  - `test_underground_entry_bindings.gd` covers it on a fixture, refusals included.
- **P-1972-8, the Locations paid-cube witness, is removed** (`underground_locations.gd` is master's again):
  - no mounted stop reaches it (the review forced it to refuse and the whole chain stayed green);
  - but it is not harmless. It witnesses any stop on an authored landing that no prism top holds, if the stop lies
    on the floor of a completed same-Room paid cube, and nothing checks what is under that floor: a stop over a cube
    dug above another would be witnessed over void. Its three guards had no test that could fail;
  - F40 needs a witness for stops on natural earth; it should add one with a never-cut check under the floor. The
    removed code is in the inventory below;
  - `test_a_stop_over_natural_earth_outside_any_paid_cube_is_refused` stays: without the witness that stop is
    refused as before.

### M-2, measured on the mount (skip in, floor end out, `Space.MAX_CHECKS` unchanged)

Log: `scratchpad/activate_m1/m2-final.log`.

- **Peak per-preparation checks: 1,000,378 of 1,048,576 (95.4 %), a margin of 48,198.** Content 10's own peak on
  master was 1,038,133.
- The descent finishes on tick 8,348 with `ENTRY_KITCHEN_UNBUILT`, as before.
- Every planned edge is published (none missing). At the end: 49 WALK edges (29 ground, 20 EARTH_TIMBER, the sill's
  two among them) and 19 CARRY edges: the stair carry's 17 on EARTH_TIMBER and the ground hauls' 2.
- The whole-chain test now asserts the sill's stops, no stop below them, and exactly 17 EARTH_TIMBER CARRY edges
  beside the ground hauls' 2 (`test_underground_host_whole_chain.gd`).

### Memory

- Stair-carry tables: +33,784 B (`CARRY_RESERVED_BYTES`); the shared profile reserve for content 12: +4,096 B.
- Live with reserve: 105,779,636 B of the 150,000,000 B gate (headroom 44,220,364). The ledger rows are in
  `docs/systems_architecture.md`; `ready07_arithmetic.py` passes with them.

### The floor end: F40's inventory

Everything below was built and measured on this branch before the ruling, then removed. Commit `a8c4a831` on
`feat/activate-content-11-12` holds it whole. This is the inventory F40 starts from.

**The data (`publish_qualified_stairs.py`, bundle v10 before the ruling).**

- A second LANDING appended after the sill's, the floor:
  `[-1024, top(FLOOR), -7168, 1024, top(FLOOR) + 1, far(SILL)]`, from the seventh row's end wall to the sill, with
  `FLOOR = 7`.
- Three more stops, all the sill's (assembly 7), on that LANDING (49 endpoints in all):
  - F, the floor arrival, `stop(FLOOR, ARRIVAL)`, travel row DESCENT, at (0, −1024, −5975);
  - U, the floor ascent start, `stop(FLOOR, ASCENT_START)`, ASCENT, at (0, −1024, −5801);
  - F′, `stop(FLOOR, ARRIVAL - HANDOFF_EDGE_U)`, DESCENT, at (0, −1024, −6318).

**The stair path (`underground_entry_stair_path.gd`).**

- `LEVELS = Tread.TREADS + 3`, `FLOOR_LEVEL = Tread.TREADS + 1`, `KIND_B = 6` (F′), with a `b` handle in `Stops`.
- `classify`: `if level == FLOOR_LEVEL and behind == Tread.ARRIVAL - HANDOFF_U: return Vector2i(KIND_B, level)`.
- `floor_plan(walk)`, seven WALK edges (family 0): T5 → T6 → F; F → U on the floor (row 55); U(floor) → U(T6) →
  U(T5); F → F′ (walk-off, row 71) and F′ → F (back-up, row 72).
- `carry_plan()`, 21 CARRY edges: H → A(L0); eight descents to F; F → F′ and F′ → F; the half-turn F → U(floor);
  eight ascents to U(L0); U(L0) → H.
- `_planned` gated every edge past the descent on F (`stops.a[FLOOR_LEVEL + 1]`).

**The trench retention, P-1972-9 (`underground_entry_bindings.gd`).**

- `_stage_natural_support`, after the landing footprint: for each CUT row of the Placement's Frontier whose floor is
  the landing's (`cut[1] == _cube[1]`), the slab `cut[1] - NATURAL_DEPTH_U .. cut[1]` retained by
  `_retain_natural(proof, token, cut, true)`, proved whole (`_timber_natural_support(proof, bounds)`), not fragment
  by fragment.
- `_cut_floor_footing(proof, token)` at the sealed final pass: the same slabs observed by
  `_timber_terrain(proof, cut, Terrain.FOOTING, token)`.
- `test_underground_work_face.gd`'s `test_a_retained_trench_floor_never_blocks_a_room_dig_beside_it` stays. It tests
  the general rule (another Room's retained strip blocks neither a dig nor its floor scrape), which F40 needs too.

**The Locations witness, P-1972-8 (`underground_locations.gd` `_installed_row_site`).** After the prism loop, a
`held` flag set by any prism top holding the stop; when none does:

```gdscript
	if held: return found
	var origin: Vector3i = _cube_origin(record.point)
	var floor_row: int = _installed_site_row(physical, origin) if origin.y == record.point.y else -1
	if floor_row < 0 or physical._phase[floor_row] != Sites.SUPPORTED_VOID or physical._room_slot[floor_row] != record.room.x \
			or physical._room_generation[floor_row] != record.room.y: return NULL_REF
	return Vector2i(floor_row, Sites.SITE_GENERATION)
```

F40 should add, before reusing it, a check that the earth under that floor was never cut, and a test for each
guard (wrong phase, foreign Room, a point not on the cube's floor).

**What was measured with it** (Phases 2b–3a above):

- every floor and CARRY edge published (all 33 past the descent), the floor's stops stood on natural earth;
- **the cost that stopped it:** the trench's 48 SUPPORT rows made the sill's completion requalification need
  1,687,943 checks (161 % of `MAX_CHECKS`), and publishing all 33 floor and CARRY edges in one preparation 544,031.

**What F40 has to settle.** The flight's floor (world −512) is not a room level; level 1's floors are −5,632,
−4,608 and −3,584 ("What the stair carry supplies"). F40's longer flight moves the floor, so F, U and F′ move with
it, and the retention's cost has to fit under `MAX_CHECKS` (Phase 3a's options (a) to (c)). Decision 1981's rows 71
and 72 (the empty walk-off and back-up) and the loaded walk-off and back-up uses of the approach rows are published
in content 12 and paced in the bundle, but no edge uses them until F40.

### The independent review (`code-reviewer`, 2026-10-17)

No CRITICAL finding. Both HIGH findings are fixed:

- **H1, the P-1972-8 witness:** removed (above, "P-1972-7 kept, P-1972-8 removed").
- **H2, the `_carry_eligible` skip's `edge.family < 0` guard had no test that could fail:**
  `test_a_change_in_a_rooted_rows_sweep_requalifies_its_stair_edge` stages an obstacle in the loaded descent's sweep
  after its CARRY edge is published; the refresh re-proves the edge and refuses it. Without the guard the edge would
  be carried over unproved. The reviewer also proposed keying the skip on "no ground pace row" instead of
  `Stair.is_rooted`; that is a different WorldRoutes line from the one cleared, so it is left for the cost lane.

MEDIUM:

- **M1:** the milli-pace owner test now gives row 43 the EARTH_TIMBER family bit first, so only the owner rule can
  refuse it.
- **M2:** `test_a_milli_pace_above_the_cap_times_one_thousand_is_refused`.
- **M3:** the carry bank's rollback moved into `_append_carry`, so a refusal cuts the columns back wherever it is
  called; `test_a_malformed_carry_bank_is_refused_and_cut_back_to_the_claw_bank` covers a wrong row and a deck out of
  span.
- **M4:** the whole-chain test now checks that the sill's stops are the lowest installed stops, from the Frontier,
  instead of an always-true stop lookup.
- **M5, a refusal publishing the sill's edges fails the finished entry:** intended. It is the same rule as every
  tread station's stair edges (`_connect_contact` returns the stair path's refusal), and the alert names the
  code. A stair whose carry edges cannot be published is not a working stair.
- **M6:** `test_a_live_walk_edge_never_hides_its_carry_twin` covers `_joined`'s mode check in the fast tier.
- **M7, `Stair.owns`' digest comparison on each stair `pace_into`:** about 128 character reads per call, no
  allocation, for each actor on a stair. Not changed here (it would add cached state to Profiles' readers); it is
  for the cost lane's next measurement.

LOW: the stale "content 10" comments are corrected; `_timber_staged_support`'s docstring now says it refuses
nothing itself; the loaded policies and cargo fields are constants; the held meshes are built once. Left as they
are: `ENDPOINTS = 46` and the census counts in `paw_program.gd` are literal because the census and registry parse
them; `CARRY_RESERVED_BYTES` stays on one line because the census parser reads only single-line constants.

### One test margin moved (for the coordinator to see)

`test_underground_entry_work_area.gd`'s entry confirmation asserted it spends under half of `Space.MAX_CHECKS`. On
the mounted v10 bundle with content 12's 85 rows it spends **525,592** (50.1 %): 18 more rows to sweep for each of
the 36 carried paths. The assertion is now three fifths of the bound. The fixture must follow the mounted bundle
(the paid-handling suites build on it and need its 46 endpoints), so it cannot stay on v9. The mounted chain's peak,
1,000,378 (95.4 %), is unchanged by this; the confirmation is one of the preparations inside it.
