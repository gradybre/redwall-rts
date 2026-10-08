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
