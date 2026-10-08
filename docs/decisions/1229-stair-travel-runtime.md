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
