# 1229 — Stair travel and tread fitting in the runtime (tool-free fitter, T1–T6)

Date: 2026-10-08 · Status: Engineering plan, accepted direction (Brendan approved the motions; this record plans
their runtime). Increment 1 (native capture) is done; the rest is in progress.

## What exists

All motion is approved and proved at source level: ADR 1217 steps 2d and 5b, M7, and ADR 1209 step 5.

| Motion | Clip (native claw/paw v2, ADR 1217 §6.1) | Pace |
|---|---|---|
| Descent one tread, 169 u from the far edge → 169 u on the tread below | `descent` (91 keys, root track (0, −128, −512)) | DEC-050: 30 ticks |
| Ascent one tread, 343 u → 343 u on the tread above | `ascent` (91 keys) | DEC-050: 30 ticks |
| Step back 169 → 310 u, step forward 310 → 169 u | `step_back`, `step_forward` (5 keys each) | ADR 1164's short step at 3,277 u/s |
| Half-turn and reposition 169 u (down) → 343 u (up) | `turn` (271 keys, heading 0 → 32768) | DEC-050: 45 ticks |
| Tread fitting tap; paw handling | `tread_tap_*` (source 4); `tread_seat_*` (source 5) | the INSTALL/handling clocks |

The runtime cannot use any of it yet:

- Routes and WorldRoutes refuse every connector edge (`WORLD_ROUTE_FIXED_CONNECTOR_SOURCE_REQUIRED`).
- The motion catalog is the pick-era source tables and refuses activation (`MOTION_SOURCE_ONLY`).
- No profile row describes stair travel.
- The first-entry bundle stops at T0.

## Constraints read from the owners

1. **Stair edges are `EARTH_TIMBER` (family 0) connector edges.** The catalog admits only WALK or CARRY on a
   non-ladder variant (`_variant_refusal`), and an authored connector pace row must name a profile whose mode
   equals the variant's (`_pace_row_refusal`). So stair rows are **MODE_WALK** rows with family bit 0.
2. **Authored connector pace rows must name a profile on the catalog's bound source** (`header[10]`, the Frontier
   source 4). So the stair rows live on source 4.
3. **Rows sort by key within a source**, and WALK keys precede WORK keys. So content 10 inserts the new source-4
   WALK rows before source 4's WORK rows. **The claw WORK and paw rows are renumbered**: content 9's rows 51–59
   move up. The runtime pins (`qualified-claw-runtime-v1` claw/paw programs, Frontier and Workpieces) move with
   them in the same activation. Content 9 stays published.
4. **A stair row must not overlap a ground row's key** (`_overlap_keys`: same policy, key and yaw is ambiguous).
   The narrow approach is also WALK, source 4, yaw 0. Stair rows therefore carry a new policy,
   **POLICY_STAIR = 8** (descent, ascent) and **POLICY_STAIR_TURN = 9** (the half-turn, which would otherwise share
   the descent's key and heading). Profiles admits them only on YAW_EXACT WALK rows, with no tool or cargo, whose
   family mask names a connector family. The tread fitting row uses a new contact kind, **CONTACT_TREAD_FIT = 5**
   (DEC-058): a source-work BUILD row with five roles and no point or patch, as CONTACT_HAUL_GRIP has none.
   This is a Profiles format extension with a negative test.

## Content 10 (create-only)

- **Sources 4 and 5** become the v2 images (`b85f9195…`, `9cdafc55…`); sources 0–3 are content 9's.
- **Rows** (all derived by the accepted cardinal derivation, nothing chosen):
  - **stair WALK rows on source 4, POLICY_STAIR, family mask 1:**
    - descent, yaw 0;
    - ascent, yaw 32768;
    - turn (POLICY_STAIR_TURN), yaw 0 → 32768. Its program owns the heading table; its boxes are the handoff
      prover's exact interval enclosures.
  - **short steps on source 4:** step back as POLICY_SHORT_BACKWARD and step forward as POLICY_SHORT_FORWARD, yaw 0,
    ground (family −1). Their 141 u span is checked by the step program, as ADR 1164's 232 u was.
  - **tread fitting:** a WORK row on source 4 (yaw 0, INSTALL, `CONTACT_NONE` per DEC-058, roles from the
    approved clips) and a handling row on source 5.
  - Content 9's rows otherwise keep their words and boxes.
- **Ground paces:** content 9's, plus the step rows' ground caps.
- **Stair paces** are not ground caps. They are authored connector rows (RATE_AUTHORED) in the bundle's structure
  catalog, one per tread variant, from DEC-050.

## Runtime increments, in order

1. **Profiles: POLICY_STAIR** (format, selection and tests).
2. **Content 10** published and loaded by the actual loader in a fixture store (not active).
3. **Stair program** (`qualified-claw-runtime-v1/stair_program.gd`), as Claw and ShortStep are:
   - fixed ticks per edge (30 descent or ascent, 45 turn), from the pace row;
   - the clip's root track sampled by the handoff root equation (ceil of the rational interpolation);
   - the heading from the turn's table;
   - interruption and save state in the existing Routes columns (progress and remainder).
4. **Motion catalog successor** carrying the claw stair tables (root, heading, plant, support primitive per key) in
   place of the pick-era banks. It is charged in the memory census and activated when Routes binds it.
5. **WorldRoutes** qualifies an `EARTH_TIMBER` edge for a POLICY_STAIR profile from the catalog variant and the
   motion catalog's source proofs (terrain, flight, handoff, self-clearance: ADR 1217 M7 and step 5b), instead of
   refusing it. Ground edges are unchanged.
6. **The T1–T6 bundle successor** (structure, Catalog, Grouping, Recipes, Frontier, Workpieces; create-only):
   - six new assemblies with T0's bill per tread (D3), the sill's bearers cut to 64 u (D1);
   - cut episodes for T2–T6's cube rows and the seventh row (D2), from surface stations at ±1,430 u (DEC-052),
     translated along the trench;
   - one `EARTH_TIMBER` variant per tread segment with its DEC-050 pace;
   - INSTALL rows per tread at the 310 u station;
   - episode order: all cuts → for each k, descend, step back, fund and handle (the bearer appears only after the
     fitter arrives), install, step forward, turn, ascend.
7. **Foreman and installer** continue past T0 down the stair. Then the G9 alert moves from the descent to the
   Kitchen (DEC-054), as `ENTRY_KITCHEN_UNBUILT`.
8. **Exact-ledger tests:**
   - the hauled prefix through T6, and the live host chain via `run_tick` to the new end;
   - save/restore and settlement save→load byte identity;
   - memory census, pins and registry rows.

## Coordination

Increments 3–7 edit Routes, WorldRoutes, Profiles, the foreman, the installer and the hauler. The save-UI worker's
files (UI and save) are not touched. Save byte-identity is kept by storing stair progress in the existing Routes
columns. A new column would be a declared schema change with its own record.

## Progress

- **Increment 1 (Profiles), done.** `underground_profiles.gd` admits POLICY_STAIR (8), POLICY_STAIR_TURN (9) and
  CONTACT_TREAD_FIT (5). `test_underground_profiles.gd`'s unknown-policy check now uses 10.
- **Increment 2 (content 10), done.**
  - `claw-work-v1/derive_stair_rows.py` derives the seven rows into `evidence/stair-rows-v1/rows.json`.
  - `publish_claw_stairs_runtime.py` writes `qualified-claw-stairs-v11/` (create-only, revision 10): wire
    `9791eb59…`, 67 rows, 547 boxes, 6 sources.
  - `test_mole_claw_stairs_profiles.gd` loads it through the actual loader (6 tests, including three negative
    edits); `test_publish_claw_stairs_runtime.py` holds 5 tests.
  - It is not active: the catalog and Session still load content 9.
- **Increment 3 (stair program, stair tables, Routes and WorldRoutes), done.** Details and the engineering choices
  below (§ Increment 3).
- **Increment 4 (content 10's handling layer), done.** Below (§ Increment 4).
- **Increment 5 (the T1-T6 bundle, create-only), done.** Below (§ Increment 5).
- **Increment 6a (content 10 and the bundle mounted), done.** Below (§ Increment 6a).
- **Increment 6b (down the stair: T1-T6 installed by the live chain), done.** Below (§ Increment 6b).

## Increment 3 — the stair program and stair edges in Routes and WorldRoutes (2026-10-08)

### What was built

- **The claw stair tables** (`publish_claw_stair_motion.py` → `qualified-claw-stair-motion-v1/`, create-only, wire
  `e7840c7b…`, 9,620 B) and their owner `underground_stair_motion.gd`. For rows 51–55 they hold, in the start root's
  frame: the root and heading per key, the deck supporting each interval and the fixture decks each proof stood on.
  Nothing is chosen:
  - the descent and ascent roots are the content-10 motion wire's gait tables (M7: "the root tracks are the
    accepted ones"); the ascent's are turned by the exact half turn;
  - the half-turn's roots and headings are its handoff program 1 (step 5b: the author runs unchanged), checked
    against the claw turn record's controls;
  - the decks and per-interval support are M7's terrain proof's; the steps' standing decks are the step proofs'
    fixtures moved into the start frame.
- **Content 10's runtime programs** (`qualified-claw-runtime-v2/`): `claw_program.gd` is runtime-v1's on content 10's
  row layout (travel 42–50, dig/tap 56–63, the tread fitting tap 64 on the tread tap clips); `stair_program.gd` owns
  51–55. Routes dispatches to them by row and image digest beside the content-9 programs, which stay as they are until
  activation.
- **Routes.** A stair row crosses one two-point edge in `ceil(length × 30 / pace)` ticks; the pose at tick t is the
  program's whole key `t × intervals / ticks` (the gaits' and half-turn's root track and heading, the step's straight
  share). A queued READY leaves the READY hub on the same tick, and a finished crossing runs straight into a queued
  next one, so a crossing takes exactly its ticks. The source word is READY or WALK; the clock's time lane holds the
  presented key; the progress column the elapsed ticks (no new column).
- **WorldRoutes** qualifies a source-proved row on an edge when: the edge is exactly the motion's span (two points,
  rotation 0); its pace lands on whole keys; both endpoints are live; every fixture deck is covered by installed
  SUPPORT of the edge's Room (the World's, outside a Room); and each body and recovery box at the start root meets
  only void, floor metadata or that Room's SUPPORT, and is covered by void, the Room's timber or terrain-proved
  exterior air. Each tick re-proves the certificate and the whole motion's box for other actors and exclusions.
- **Tests.** `test_claw_stair_programs.gd` (5) and `test_underground_stair_routes.gd` (5, the hand fixture: a descent
  in 30 ticks on its root track, the half-turn in 45 to heading 32768, the ascent in 30, the step back in 2, and a
  short lower deck, an obstacle in the body and unbound tables each refusing); `test_publish_claw_stair_motion.py` (5).

### Engineering choices (recorded here so they are not undone by accident)

1. **The short steps are source-proved too.** Content 10's rows 51 and 52 carry the swept foot hull as their stance
   (up to 248 u high), as derived. The ground route proof requires a stance box wholly inside SUPPORT, so it can never
   admit them; they are qualified by the same fixture rule as the stair rows. Their published bytes are unchanged.
2. **Stair paces are one row per stair profile on the Placement's single variant.** A Placement binds exactly one
   catalog variant (`H_CATALOG_ROW`), and every tread segment has the same length, so DEC-050 needs one authored row
   per profile on variant 0, not one variant per tread: descent and ascent 528 u/s over the 528 u tread edge
   (`ceil_root(128² + 512²)`), the half-turn 116 u/s over its 174 u span — exactly 30 and 45 ticks.
3. **The half-turn's heading is its table's.** Profiles' exact-heading match and WorldRoutes' selection check skip
   POLICY_STAIR_TURN; Routes refuses to start a crossing unless the actor faces the program's start heading.
4. **No per-key support re-proof at runtime.** The support primitive per key is carried by the tables; the live check
   is that every deck the proofs stood on is installed. The source proofs (M7 flight and bottom, step 5b, the step
   proofs) cover the rest.

### Still to come in this plan

- Increment 4: the paw program for rows 65/66, the handling and endpoint-certificate selectors on content 10, the
  presentation of the v2 images, and the Session mounting the stair tables (memory census).
- Tread Locations and the pending bearer: the arrival (169 u) and ascent start (343 u) of T_{k−1} physically overlap
  T_k's staged bearer (ADR 1209 step 5), so their Locations and stair edges must not exist while it is pending.
  They are retracted before FUND and restored after the installation commits (increment 5/6).

## Increment 4 — content 10's handling layer (2026-10-08)

Content 10 moves the rows the handling layer named by number: content 9's paw handling row 59 is a claw tap there,
the yaw-0 seating tap 52 is the step forward. So the layer now reads every row under its content:

- **The handling selector** (`qualified-claw-runtime-v1/handling_programs.gd`) takes the content with the row:
  `is_handling`, `is_install_tap`, `clock_refusal`, `source_of`, `role_count`, `part_count`, `bearer_refusal` and
  `part_refusal`; the physical proofs read the selection's content. Routes, WorldRoutes, Contacts, ConnectorWork and
  Workpieces pass it. Content 9's behaviour is unchanged (its suites pass unchanged).
- **Content 10's programs** (`qualified-claw-runtime-v2/`): `paw_program.gd` for rows 65 (L0/T0) and 66 (the treads)
  on the paw v2 image (clips 0-2 and 3-5); `paw_physical_certificate.gd`, whose L0/T0 stations keep the pick
  certificate's roots, prisms, transforms and real-air volumes with tap 57; `tread_geometry.gd`, ADR 1209's derived
  stations and staged bearers (T_k's left bearer is part 7(k+1)+1 turned as T0's part 8, translated by T0's
  translation plus d − R(d) for the tread offset d; the sill's bearer 64 u lower).
- **Tread stations** are proved against their own fixture: the station body may meet the station Room's own installed
  SUPPORT (the timber the tread fitting proof stood among: the deck behind, the bearers and posts) besides void, the
  certified pending bearer and exterior air; the stance must lie in the station's footing. Tap 64 is certified at a
  tread station over its derived prism (DEC-058: the bearer was hard for every triangle, tread and sill).
- **The claw endpoint certificate successor** (`qualified-claw-certificate-v2/`) serves L0 and T0 on content 10
  (rows 43/47/57/65); `endpoint_certificates.gd` routes content 10 to it.
- **The Frontier** admits a station whose WORK row is the tread fitting motion (`CONTACT_TREAD_FIT`, DEC-058) beside
  the exact anchor-and-patch contact, and an episode with no bearing under it (the seventh row, D2).
- Tests: `test_claw_tread_programs.gd` (5). The routes, world routes, contacts, first prefix, haul grip and hauled
  assembly suites pass unchanged on content 9.

## Increment 5 — the T1–T6 bundle `qualified-stairs-v7` (create-only, 2026-10-08)

`first-entry-prefix-v1/publish_qualified_stairs.py` writes `qualified-stairs-v7/` from pinned inputs only: the ADR
1209 prefix spec, `qualified-claw-v6`, content 10's profile image and ground caps. Its docstring lists every table.
In short:

- **Structure:**
  - 52 parts in eight assemblies (L0, T0, T1–T5, the T6 sill with 64 u bearers and no posts);
  - natural bearings under every post and the sill's bearers;
  - a LANDING per standing deck;
  - paces are content 10's 26 ground caps, then DEC-050's rows on variant 0: 53 and 54 at 528 u/s, 55 at 116 u/s.
- **Bills and workpieces:**
  - T0's bill per tread (D3);
  - L0/T0 on paw row 65;
  - each tread's staged left bearer on row 66, by `TreadGeometry`.
- **Frontier, revision 6:**
  - claw-v6's rows with content 10's row ids (52→57, 53→58, 57→62);
  - eight more cube episodes for rows 4–7 from surface stations at ±1,430 u (D2's seventh row has no bearing);
  - the stair stops on L0 and T0–T5 (arrival 169, station 310 WORK on row 64, ascent start 343);
  - the crossing arrival (0, 0, −664) on the yaw-32768 approach 45;
  - an INSTALL row per tread at its station on the tread above.
- **Two engineering findings:**
  - Content 10's published `ground-pace.ugconn` names content 9's claw image (v1) in its header digest, so it cannot
    link to a structure bound to the v2 image. The published file is not edited. No runtime reads it (the
    structure carries the caps), so the bundle's copy carries the v2 digest and every row stays byte for byte
    (`rebound_ground`, tested).
  - The entry source formatter (`entry_source_constants.py`) required the structure's paces to equal the ground
    caps. It now admits the caps followed by authored connector rows (family ≥ 0, RATE_AUTHORED, rate ≥ 1). Any
    changed cap is still GROUND_SOURCE (tested).
- **Not active.** The mounted Session still runs `qualified-claw-v6`. The work area's eight new cut stations, the
  stair-stop Location bounds and the stair path helper land with activation (increment 6).
- **Tests:**
  - `test_underground_stairs_bundle_source.gd` (3): the actual Catalog, Recipes, Assemblies and Frontier readers
    over content 10;
  - `test_publish_qualified_stairs.py` (5).

## Increment 6a — content 10 and the T1–T6 bundle are mounted (2026-10-08)

The Session now loads content 10, and its route and entry compositions mount `qualified-stairs-v8`.
`qualified-stairs-v8` supersedes v7, which stays published and unused. The live `run_tick` chain still builds
the L0/T0 prefix: on content 10 it finishes at tick 4,670 with the same Work ledger, the same tick as on content 9.
The descent past T0 is increment 6b.

- **What changed at activation:**
  - `mole_profile_catalog.gd` loads `qualified-claw-stairs-v11` (67 rows, 547 boxes);
  - `renew_source_pins.py` renews that publication's consumer pins;
  - the Session presents the v2 claw and paw images (16 and 6 clips);
  - the route composition loads the claw stair tables once and lends them to Routes;
  - the grip certificate admits content 10, which keeps content 9's rows 0–50 and haul images;
  - the work area publishes 19 endpoints;
  - the progress record is version 3 (19 endpoints, up to 64 planned steps).
- **v7 → v8.** The entry plan's claims are the Frontier's CUT rows, and the entry bindings require them to be
  exactly the cubes the episodes cut. v7 gave the seventh row cube episodes but no CUT group, so the plan was
  refused (ENTRY_EXACT_CUT_SET_REQUIRED). v8 adds that group, which no tread names, as Frontier revision 7.
  Nothing else changed.
- **Latent defect fixed.** The contact retirement scope read an INSTALL row's field 0 (the assembly) as its
  station. In the claw bundle the two coincided (assemblies 0/1 at stations 0/1). The scope now reads field 1, and
  its source tuple is sized by the mounted Frontier's census (8/22/6/38/44/14).
- **Cold check budgets.** Every cold operation shares one `Space.MAX_CHECKS` = 1,048,576 bound. The bundle's
  larger census exceeded it in three places. No budget was raised; each scan was made to scale instead:
  1. *Surface contact proofs.* Each of the 19 surface endpoints was charged 16 checks per Location slot (16,384)
     twice per entry confirmation. The anchor-namespace scan now charges one check per slot plus 16 per live row,
     as ADR 1227 charges Contacts' Region scans.
  2. *Path requalification.* Every Space phase and installation requalifies every live path. With paths from M and
     R to all 14 cut stations, the L0 CUT phase ran out. The descent's eight stations now get their paths, from M
     only, just before the first of them is worked, in the same preparation that retires the four T0 stations'
     paths. The foreman asks the runtime through `bind_station_paths`; the answer is derived from the live graph,
     so a restored chain asks the same question.
  3. *Installed witnesses.* Contacts closed every Terrain observation of the T0 commit with the full installation
     leaf, re-deriving every installed Location's paid witness about 19 times. With the stair stops that ran the
     Locations operation budget out. Contacts' per-observation closure now skips only the witness pass:
     `prepared_installation_leaf_refusal(..., witnesses = false)`. ConnectorWork's final funding leaf, after
     Contacts, still runs the complete leaf. A witness pass also resolves each Room's source once.
- **Memory.** The census charges the claw stair tables (9,580 B per Session) as a new retained row and the larger
  entry plan (+5,680 B). Content 10's Profile bank adds 3,052 B inside the PROFILE_BYTES joint.

## Increment 6b — the live chain builds the descent down the stair (2026-10-08)

After T0 the foreman plans all eight installations. The crew cuts the descent's eight cubes from the surface, then
installs T1-T6, each from the tread above. On the flexible schedule the live `run_tick` chain finishes on tick
13,690 with every group installed once:

- ledger `[50 tasks, 126,000 cut mWU, 19 hauled units, 116,000 install mWU, 8 INSTALLED]`;
- then the entry raises G9 at the Kitchen: `ENTRY_KITCHEN_UNBUILT` (DEC-054) replaces ADR 1227's
  `ENTRY_DESCENT_UNBUILT`.

### What was built

- **The stair path publisher** (`underground_entry_stair_path.gd`, stateless). It finds the installed stair stops
  by their source points: X, the crossing arrival on L0; then P, A, S and U on L0 and on each standing tread. It
  publishes, in one WorldRoutes publication, every stair edge whose two stops are live. Each edge is exactly one
  approved motion's span: approach, step forward/back, descent, half-turn, ascent and the yaw-32768 approach.
- **Retracting a stop.** A pending tread bearer is staged where the arrival stop of the tread above stands (ADR
  1209 step 5). At FUND the installer removes that stop, its edges and the climb from the stop its half-turn
  reaches. The tread's commit re-creates the stop (`_timber_new_locations` also creates the tread above's missing
  selectors).
- **The installer.** A tread order walks M → X on the material profile, then down the stair:
  1. walk-in, step forward, one descent per tread;
  2. a step back onto the station.

  From a previous tread station, the haul's first legs are the climb back to X: step forward, half-turn, ascents,
  approach. The plan's leg lists, the retracted stop and the down-leg cursor are in the record:
  `INSTALLER_FIXED_BYTES` 165 → 185, `MAX_LEGS` 3 → 5, two lists of at most `MAX_STAIR_LEGS` = 4 legs.
- **The foreman.**
  - It plans T1-T6 directly after one another; a tread's walk to M keeps the last cut's travel profile.
  - It asks the runtime for station paths before each installation. The descent cuts' paths close once the crew
    has left them, so the stair edges take their place in every later requalification.
- **Contacts.**
  - A tread station admits the tread fitting row (`CONTACT_TREAD_FIT`, DEC-058).
  - Its body is proved against the actual Regions: void, the station Room's own timber, the order's own piece
    and exterior air.
  - It is reached by a static per-leg edge certificate check down and back up the stair. A graph search per leg
    would charge the Location census each time.
  - The worker leaves the station by the step forward.
- **Routes and WorldRoutes.**
  - A stair crossing past the start deck's far edge is contained in the end deck's section.
  - The tread fitting tap is admitted at a tread station by occupancy alone, as a stair row is: its motion is
    proved by the installation's Contacts and its certified tap.
- **Locations: the installed-witness pass shares work within itself.** Every closure of an installation re-derives
  every installed witness after its observers. One installation runs about eleven such passes. Each record's
  surface-site proof charged a full installed-sources proof (1,024) and 96 per paid-prefix part. At T2 that was
  87,324 per pass, and the T2 commit ran out of `LOCATION_OPERATION_BUDGET`.
  - A pass is synchronous and runs no observer. Within one pass, the sources verdict is now proved once (then 16
    per record), and the paid prefix's installed prisms are derived once into `_prism_boxes` (then 4 per part per
    record).
  - The pass number changes at every pass, so nothing survives one: each pass, including the final one after the
    last observer, still re-derives everything from current columns.
  - A memo across passes was tried first and rejected. Two adversarial suites in `test_underground_entry_bindings.gd`
    change a paid Site or the profile bank inside the last observer, and they caught it.
  - Census: 6,201 B of controls (6 × `Catalog.MAX_PARTS` int32 plus the key and counters). No budget was raised.

### Engineering findings (recorded so they are not undone)

1. **Fragment banks at T3.** T3's handling body meets the trench's thin void slabs (64 u layers under the timber)
   and T2's timber. Subtracting them in Region order overflowed the fixed 32-fragment bank, and the order refused
   `ASSEMBLY_PHYSICAL_BUDGET`. The paw certificate now subtracts the void first and the timber second. After each
   subtraction it merges fragments that share two axis intervals and abut on the third. The union is unchanged,
   and so are the bank size and the budget. T1-T6 all prove.
2. **The section-6 bound of the progress record was stale since 6a.** `progress_record`'s `max_count` stayed 2,559
   (ADR 1218) while `Progress.MAX_WIRE_BYTES` grew to 4,287 in 6a. A mid-descent record (3,166-3,363 B) then
   could not be saved. It is now `MAX_WIRE_BYTES` = 4,507 in the canonical registry, the generated section-6
   schema and the capacity audit.
3. **The live chain cannot finish the descent on the default schedule.** It starts at 06:00 with hunger and rest
   both 7,500. Measured:
   - the 18:00-20:00 SOCIAL hours pause it at a resting point for 1,468 ticks;
   - at 22:00 it pauses again;
   - the crew holds the entry Job and is never put to sleep or fed, so rest only decays: 375/h, 0 by tick 15,000.
     The chain then waits for ever.

   The suites therefore run the whole descent on the flexible template (GDD 5.3, every hour ANYTHING). Its rest
   is still 655 at the finish, above REQ-SET-015's 500. Brendan's decision on this: "Reduce time to build them
   greatly". The measured breakdown and the proposal are in § Build time below.

### Tests

- `test_underground_host.gd`:
  - the prefix suites stop at the end of the prefix (task 20, tick 4,670, the same ledger), and the chain runs on;
  - `test_the_live_chain_builds_the_descent_down_the_stair_to_the_sill` runs the whole descent: tick 13,690, the
    ledger above, G9 at the Kitchen, re-raised by a finished entry.
- `test_underground_paid_assembly_handling.gd`: the record offsets include the stair plan.
- `test_save_section_auxiliary.gd` and `test_canonical_state_hash.gd`: the new `max_count`.
- Census, registry (`underground_entry_stair_path.gd`, `_prism_boxes`, `_prism_key`), consumer pins (Contacts, Routes,
  WorldRoutes) and the capacity audit follow.

## Build time: measurement and proposal (2026-10-08, awaiting Brendan)

Brendan's decision (in chat, after increment 6b's first run stalled at T3): **"Reduce time to build them greatly."**

### Target

The values come from GDD §5.2 and §5.3.

- **Needs.** Rest decays 375 an hour awake; seek sleep is at 2,500 or below and collapse at 500 or below. Hunger
  decays 250 an hour for an adult small mole; eat is at 3,500 or below.
- **Start state.** The generated settlement's crew starts at 06:00 with hunger 7,500 and rest 7,500. Rest therefore
  reaches the seek-sleep line after 13.3 h (tick 10,000, 19:20), and hunger reaches the eat line at tick 12,000
  (22:00).
- **Schedule.** The default schedule lets the crew work 06:00–18:00 (ANYTHING and WORK). It rests 18:00–20:00
  (SOCIAL) and sleeps from 22:00.
- **The crew's needs are not met.** While it holds the entry chain it is never fed and never put to bed. That is a
  separate gap, not addressed here.

**Target:** the whole entry (prefix and descent) finishes inside the first work block with margin:

- by about 17:15 (tick 8,470);
- so the descent takes at most about 3,800 ticks (5.1 game hours) after the prefix's 4,670.

At that tick rest is about 3,265 and hunger 4,675, both above their seek lines.

### Measured (live chain, `run_tick`, the flexible schedule so that no schedule pause hides the work)

The same ticks were measured with and without the needs held up. Haul handling is double-ticked by the settlement
(ADR 1226 addendum).

| Where the ticks go | Prefix L0/T0 (1–4,670) | Descent cuts (8 cubes) | T1–T6 (6 treads) |
|---|---:|---:|---:|
| Cut Work (`EARN`), mWU and rate | 594 (54,000; 91/tick) | 832 (72,000; 86.5/tick) | – |
| Claw entry / recovery between the three phases of a cube | 546 / 810 (18 ops) | 728 / 1,168 (24 ops; 30 + 49 each) | – |
| Travel to cut stations (each via M, about 20,000 u) | 701 (6) | 1,461 (8; about 183 each) | – |
| Fastening Work (`EARN`, 12,000 mWU each) | 501 (2 groups) | – | 822 (137 each; 87.6/tick) |
| Handling / INSTALL entry / recovery | 122 / 60 / 103 | – | 366 / 180 / 318 |
| Walk to M before each tread (from a station: step forward, half-turn, ascents, approach, walk) | – | – | 1,221 (141, 156, 186, 216, 246, 276) |
| Haul trips (walk to R, lift, carry, set down, home) | 427 (9 trips) + 324 walk to M | 194 (4) + 235 walk to M | 324 (6 trips, 1 wood each) |
| M → crossing arrival, then down the stair to the station | 54 + 55 | – | 324 + 810 (58 + 30(k−1) each) |
| Stair motion inside the above | – | – | 21 descents (630), 15 ascents (450), 5 half-turns (225), 17 steps |
| Crew's surface walk to H | 366 | – | – |
| **Total** | **4,669** | **4,618** | **4,371** (590, 636, 696, 756, 816, 876) |

- **Round trips.** T2–T6 each climb back to the crossing arrival and walk to M, then come back down. That is 15
  ascents, 5 half-turns and 15 repeated descents (about 1,125 ticks of stair motion), plus about 190 ticks of
  surface walk and haul per tread.
- **Schedule waits (default schedule, same start).** 18:00–20:00 pauses the crew at a resting point for 1,468 ticks
  in the descent's cuts.
- **The stall.** At 22:00 the crew pauses at R's stand on T3's haul. Its rest reaches 0 at tick 15,000, and the
  chain never resumes. The descent needs 8,989 working ticks (12.0 h) after the prefix, which ended at 12:13.
- **Work is a fifth of the descent.** Cut and fastening Work together are 1,654 of 8,989 ticks. The rest is
  motion overhead, travel and the per-tread round trips.

### Proposal (nothing below is implemented; each needs Brendan's approval)

| # | Change | Ticks saved (descent) | What changes | Risk |
|---|---|---:|---|---|
| P1 | **Chain the treads down without climbing back.** T1's haul brings all six treads' wood to M at once (the same six trips). After T_k commits, the fitter steps forward, makes one descent and steps back onto T_(k+1)'s station; no M visit between treads. | about 1,950 (3,780 → about 1,590 for T2–T6, plus 240 more haul at T1) | The approved episode order (§ Increment 5: "…install, step forward, turn, ascend" per tread) and ADR 1202's material leg for treads. Contacts' reach rule is unchanged; the edges exist. No balance number and no new motion. | Medium: installer and foreman sequencing, save record legs. The crew ends at the bottom, as now. |
| P2 | **Keep the claw in WORK across brace → cut → finish at one station.** Enter once and recover once per cube, not per phase. | 1,264 (8 × 2 × 79); 948 more if applied to the prefix | The phase transition (ADR 1191/1210 enter-and-recover per Project). The dig loop must hand from one phase's row to the next without recovery, so a new transition proof or Brendan's motion approval is needed. | Medium–high: REQ-SET-034 rest still needs READY, so a rest hour would recover as now. |
| P3 | **Lower work amounts.** Factor 0.47, not a clean number. Brace 2,000 → 940, cut 4,000 → 1,880, finish 3,000 → 1,410 mWU (DEC-052, SET-MOVE-ECON-001). Each tread's fastening 12,000 → 5,640 mWU (ADR 1209 D3). Bills of wood unchanged. | about 880 (cuts 441, treads 436); about 550 more in the prefix if applied there | Balance numbers Brendan owns (DEC-052, D3), and a create-only bundle successor (Frontier/Recipes), with pins and `docs/gameplay_balance.md` rows. | Low technically; a design choice. |
| P4 | **Cut the four left stations, then the four right.** Use direct same-side paths (1,024 u, about 10 ticks), not a perimeter walk via M for every station. | about 1,000 | The Frontier's episode order (a bundle successor) and the work area's path topology. 6a's requalification budget must be re-measured, and so must each cube's cut-order support. | Medium: cold budgets were tight in 6a. |

**Engineering-only savings.** None were found that change no approved order, motion or number:

- the M visits, the per-tread climbs and the per-phase entry/recovery are all in the approved plan;
- the station-to-station travel only shortens with P4's reorder.

So nothing was implemented ahead of approval.

**Combinations.**

| Option | Descent ticks | Entry finishes |
|---|---:|---|
| Today | 8,989 | – |
| P1 + P2 + P4 | about 4,770 | tick 9,440 (18:35): misses the target |
| P1 + P2 (also applied to the prefix) + P4 | about 4,770, plus 948 saved in the prefix | tick 8,490 (17:19): meets it with no balance change |
| All four | about 3,900 | about tick 8,560 (17:25) |
| All four, with P2 and P3 also in the prefix | about 3,900, plus about 1,500 saved in the prefix | about tick 7,060 (15:25) |

Recommended: P1 + P2 + P4, with P2 applied to the prefix too, then P3 only if more margin is wanted.

### Brendan's choice (DEC-059, 2026-10-08)

Brendan chose P1, P2 (the prefix included) and P3, and not P4. He also chose a **shift change** for crew needs: at
the GDD seek thresholds the crew hands off at a safe point by ADR 1225's path. Order of work:

1. P3, a bundle successor with the new amounts;
2. P1;
3. P2, proved with the accepted provers, or stopped for review if a joining motion is needed;
4. the shift change.

The target is the default schedule's first work block (§ Target). The ledger rows of the stair runtime (+22,269 B,
increments 6a and 6b) were added to `docs/systems_architecture.md` §2.3 in the same commit. They had been missing
since 6a, which is why `ready07_arithmetic.py` failed.

## DEC-059 P3 — work amounts × 0.47 (2026-10-08)

- **Excavation.** `excavation_contract.gd`: brace, cut and finish go from 2,000, 4,000 and 3,000 to 940, 1,880 and
  1,410 milli-WU. Every excavation phase reads them through `ExcavationContract.work_mwu`. Bills, spoil and refunds
  are unchanged.
- **Treads.** `qualified-stairs-v9` is a create-only successor of v8, with the same parts, rows, stops and paces.
  T1-T6's recipe fastens in 5,640 milli-WU. L0 (32,000) and T0 (12,000) keep theirs: Brendan's choice named the
  tread fastening of the proposal, which was T1-T6 (ADR 1209 D3's per-tread bill). Its Frontier is revision 8.
  - The Session's entry and route compositions, the work area and the census now mount v9.
  - v8 stays published and unused.
- **Census.** `excavation_contract.gd` is a reviewed projected input (constants only, 0 B).
- **Balance.** The rows are in `docs/gameplay_balance.md` BAL-UG-001.
- **Measured** (the live chain on the flexible schedule):
  - the prefix finishes on tick 4,382 (was 4,670), ledger `[20, 25,380, 9, 44,000, 2]`;
  - the whole descent finishes on tick 12,474 (was 13,690), ledger `[50, 59,220, 19, 77,840, 8]`.

## DEC-059 P1 — the treads chained down the stair (2026-10-08)

Brendan approved the change (DEC-059). It amends increment 5's per-tread episode order ("…install, step forward,
turn, ascend") and ADR 1202's material leg for T2–T6. ADR 1209 records the amendment.

- **The first tread's haul.** T1's quote is multiplied by `Tread.TREADS` when its missing units are counted, so
  its haul brings all six treads' wood to M in one session. That is six trips, the same count as before. D3's
  per-tread bills are identical.
- **The chain.** `_plan_stairs` gives an order whose fitter stands on the previous tread's station a `chain`:
  [A on that tread by the step forward, A on the next by one descent]. The installer then:
  - takes the Job where the fitter stands and walks the chain (`STAGE_LEG_CHAIN` = 14);
  - steps back onto the station;
  - never visits M.

  If M lacks the bill, it refuses `ENTRY_INSTALLER_CHAIN_STOCK` and hauls nothing.
- **Other fitters.** A fitter that stands anywhere else keeps the full path from M. That covers a replacement
  crew, and a restored record whose crew is elsewhere. A DEC-057 resume walks the full `downs` from M.
- **Record.** The plan's chain list follows its up legs: `INSTALLER_FIXED_BYTES` 185 → 189, and the leg bound is
  `3 × MAX_STAIR_LEGS`. `MAX_WIRE_BYTES` is 4,591, and the section-6 `max_count` follows. The census adds 296 B.
- **Measured** (flexible schedule): T2–T6 take 251 ticks each, down from 636–876. The descent finishes on tick
  10,484 (12,474 after P3).

## DEC-059 P2 — one claw entry and recovery a cube (2026-10-08)

The prefix's cubes and the descent's are both affected.

**What changes.** When a BRACE or CUT finishes, and the next step is the same cube's next phase at the same
station on the same claw row (CUT or FINISH), the foreman no longer recovers the source to READY and re-enters. In
the same tick it:

1. settles the finished phase;
2. opens the next phase and its BUILD Job, and assigns the crew;
3. hands the working source to that Job (`Routes.hand_over_source_job`);
4. runs the next phase's START as after an entry.

A cube now has one entry and one recovery: the entry before its brace and the recovery after its finish.

**Why no new motion.** Every phase of a cube uses its station's single claw dig row (`station[5]`), so the source
is in the same row's WORK loop before and after.

- **Nothing in the motion changes.** The row, endpoint, heading, source word and clock all stay as they are. The
  loop simply continues, as it does between two Work ticks of one phase. No clip joins two motions.
- **The proofs that run are the accepted ones.**
  - `hand_over_source_job` requires the exact WORK tuple at rest on its endpoint (`source_work_leaf_refusal`).
  - It runs the complete admission proof a refresh runs (`_qualify_actor_at`) for the next Job, and refuses if
    the selection would change.
  - The next phase's START then runs its usual physical worker proof.
  - Settlement ran its own proofs with the source in WORK on the unchanged pose.
- **Consumer pins** (Routes) are renewed.

**The schedule.** A hand-over is skipped while the crew's hour forbids work. The source then recovers to READY at
the station, the resting point, as before (ADR 1226). One consequence: while it works, a crew stops for a rest hour
at a cube boundary (READY after FINISH), not at every phase. A cube is 4,230 milli-WU, under one 30-WU safe segment.

**Measured.** The default schedule now applies; no flexible schedule is needed.

- The prefix ends on tick 3,462. The whole entry ends on tick 8,348 (17:07), with `[50, 59,220, 19, 77,840, 8]`.
- At the finish, hunger is 4,751 and rest 3,376: neither has reached its seek line.

## DEC-059 shift change (2026-10-08)

The rules are recorded in ADR 1225's amendment. With P1–P3, the default-schedule chain finishes on tick 8,348 with
hunger 4,751 and rest 3,376, so the shift change does not trigger in the goal run. It is exercised by its own suite,
which starts the crew 375 rest points above the line.

## Re-measured after DEC-059 (default schedule, live `run_tick` chain, no needs held up)

| Where the ticks go | Prefix L0/T0 (before → now) | Descent cuts, 8 cubes | T1–T6 |
|---|---:|---:|---:|
| Cut Work | 594 → 280 | 832 → 400 (33,840 mWU) | – |
| Claw entry / recovery | 546 / 810 → 186 / 284 | 728 / 1,168 → 248 / 352 (one each a cube) | – |
| Travel to cut stations (via M; P4 not chosen) | 701 | 1,461 | – |
| Fastening Work | 501 → 497 | – | 822 → 390 (5,640 mWU each) |
| Handling / INSTALL entry / recovery | 122 / 60 / 107 | – | 366 / 180 / 366 |
| Walk to M before each tread | – | – | 1,221 → 141 (T1 only) |
| Haul trips + walks to M | 418 + 324 | 194 + 235 | 324 (T1's six trips) |
| Down the stair to the station | 109 | – | 1,134 → 279 (T1 from M; T2–T6 31 each) |
| Schedule pauses | 6 | 1,468 → 0 | stall at 22:00 → none |
| **Total** | **4,669 → 3,461** | **4,618 (+1,468 paused) → 2,890** | **4,371 (stalled) → 1,997** (741, then 251 each) |

The whole entry finishes on tick 8,348 (17:07) of the first day, inside the 06:00–18:00 work block, with hunger
4,751 and rest 3,376. It used to stall at T3 from 22:00 (tick 12,178) for good. Ledger: 50 tasks, 59,220 cut
mWU, 19 hauled units, 77,840 install mWU, 8 groups.

**Found by the whole-entry save goal: the Space authority's static proof is not saved.** `test_settlement_save_underground`
now saves and reloads at ten checkpoints through the descent. A load taken while a cut phase was in EARN failed
`SPACE_STATIC_PROOF_MISSING`: the proof is a cache, and nothing re-derived it after a load. The foreman's EARN
tick now re-derives it with the authority's own cold revalidation (`refresh_static_proof`, "recovers funded work
after revision/load changes") and retries the same tick's Work. A loaded chain therefore spends exactly the ticks
the uninterrupted one does, and every checkpoint is byte-identical to tick 8,400.
