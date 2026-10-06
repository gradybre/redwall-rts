# 1198 — Activating the authored mole haul motion at runtime

Date: 2026-10-06 · Status: Accepted plan; implementation in progress

## Why

ADR 1197 found that the real mole cannot haul. All 30 runtime profile rows
require the BASIC tool, and none is a CARRY or HAUL row. Delivery (now
extended to cut inputs, G3) needs both. Brendan chose to author and activate
the motion before continuing the live-demo integration.

ADR 1144 already authored most of it in `haul-handling-v1/`:

- the static two-hand grip;
- the four-phase approach, lift, place and recovery program;
- the exactly-1,000-milli loaded gait (hold, enter, carry, exit);
- a native replay (v7, 8 clips).

That work was deliberately kept out of the runtime until it was physically
qualified.

## Brendan's decisions (2026-10-06)

| Question | Decision |
|---|---|
| Grip contact | **Certified curved grip.** A new haul-grip contact kind plus a certificate module proves both real hand contacts on the wood mesh, following row 29's assembly-palm precedent. A planar box is not accepted. |
| Empty-handed walking | **Author a tool-free stand/walk** and its joins into the load and unload programs, through the same native capture and proofs. |
| Carry pace | **Reuse the adopted ground pace cap.** Clip playback follows it, and no new balance constant is introduced (ADR 1144). |
| Haul stand points | **Offset sideways** beside M and R. The rest of the ADR 1191 layout is unchanged and re-proved. |

## Engineering decisions (Claude, recorded here)

- **Rows.** Profiles gains per-source sorted blocks. Rows 0–29 keep their IDs
  (Assembly.PROFILE, the ShortStep IDs, the driver pins, the Frontier
  selectors), and the new tool-free rows sit in their own source's block.
- **Presentation.** One Content and one Actor per source image (actor,
  assembly, haul), with the selected row's source made visible. This does
  not raise MAX_CLIPS or recompile ACTOR_SHA. It also closes ADR 1197 G8
  (row 29 has no clip).
- **Haul policy.** Automatic rows first, matching the passing Delivery tests.
  A source-clock policy for interruption and reversal comes later if needed.
- **Quantity.** Exactly 1,000 milli per trip (ADR 1144). Delivery refuses any
  other quantity and any partial-remainder unload. Shipments are whole-unit
  trips.

## Plan (each step committed and tested on its own)

1. **Author the missing sources** (native rendering): a loaded turn in place,
   and a tool-free stand/walk with joins. Then native-program v8.
2. **Derive integer boxes** from the authored poses: an all-yaw CARRY union,
   per-heading load and unload rows, and the R−S and C−S offsets.
3. **Profiles changes:**
   - per-source blocks;
   - the `CONTACT_HAUL_GRIP` kind and its certificate;
   - generalize `Assembly.uses` and `ShortStep.uses` to "earlier rows
     byte-identical".
4. **Publish content 5:** a haul image staged for runtime, the bundle,
   ground-pace rows for the new travel rows, the runtime publication, the
   catalog constants, a motion-bank rebind and renewed pins.
5. **Work-area haul stations:** two stand Locations beside M and R, plus
   WALK and CARRY edges.
6. **Delivery station seam:** the worker stands at R and the grip contains S
   at the certified offset, both rechecked in the final leaf. Admission
   reaches the source over walking edges and the destination over carry
   edges. Quantity is exactly 1,000.
7. **Presentation** as above, plus a haul mode in the driver.
8. **Foreman and demo hookup:** surface-stock staging plus Delivery hauls,
   which clears ADR 1197 G4.

## Open items, in addition to ADR 1144's

- Joint memory census for the extra images, inside the 100 MB gate.
- Partial unload (still-loaded HAUL_OUTPUT) and BUILD set-down remain open.
  Delivery's whole-unit trips do not need them.

## Progress and findings (2026-10-06)

- **Step 3 (part 1), `4098b849`:** profile rows are key-sorted within each
  source, so an appended source never renumbers earlier rows. Automatic
  lookup scans every row (bounded by `MAX_PROFILES`), and any second automatic
  match is ambiguous.
- **Step 2, `f72134a7`:** `haul-handling-v1/derive_haul_rows.py` produces
  `evidence/haul-rows-v1/rows.json`:
  - CARRY all-yaw: body above floor `[-679,0,-679,679,932,679]`, stock
    `[-714,447,-714,714,704,714]`, stance `[-375,-1,-375,375,0,375]`.
  - Haul load and unload rows at yaw 0.
  - R−S = (0,0,576) and both exact hand-contact witnesses (C−S ≈
    (−344.7,101.4,−0.1) and (354.2,92.9,28.0)).

  Ten tests, including the full rotational sweep at every heading.
- **Step 1 (empty walk), `390f3482`:** tool-free stand (122 keys) and walk
  (45 keys) from the supplied `idle.plain`/`walk.plain`, plus joins into and
  out of the haul program. Rows A and A′ have body `[-651,0,-651,651,930,651]`
  and stance `[-406,-1,-406,406,0,406]`. Recorded in ADR 1199. Seventeen tests.
- **Heading convention:** yaw 0 faces −Z (native table metadata). S sits at
  z = −576 from R.
- **Contact rows C and D** carry no CONTACT_POINT or PATCH yet. The certified
  grip (`CONTACT_HAUL_GRIP` and its certificate) supplies them next. Until then
  they would fail the current WORK-row rule, as intended.
- **The stock rests at S, outside R's stance.** Floor support at S must be
  proved separately by the station seam (step 6).
- **Inputs outside the repository:** the derivations read
  `all-cast-v9.ugpal`, `mole-grip-v3.ugpal` and `world-yaw-v1.ugyaw` from the
  demo-assets checkout, pinned by SHA-256. This is the repository's existing
  convention for uncommitted demo assets. Running them needs NumPy, from
  `/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`.
- **Shared-tool bug:** `compile_profiles.clipped_triangle_floor` takes `.min()`
  where `.max()` belongs for the maximum crossing. The haul derivation uses a
  corrected copy. Fixing the shared function, and checking whether published
  rows change, is a separate task.
- **Step 4a (native haul image v8):** `haul-handling-v1/evidence/native-program-v8/`
  holds one 12-clip image (`cc854271…`, 993,008 bytes, 824 keys). It contains
  the eight reviewed haul clips, byte-identical to v7, plus stand (122), walk (45),
  enter_haul (31) and leave_haul (31). New sibling tools
  (`compile/run/verify/test_native_program_v8.py`, `native_replay_v8/`) leave
  the v7 tools and outputs unchanged.
  - **Format finding:** the `.ugactor` wire has no per-clip part presence. Every
    frame carries every part's transform. Presence is the existing per-Actor
    `set_parts_visible` mask.
  - **Decision:** the tool-free stand/walk keep the stock column at the exact S
    fixture value, with mask 1 (body only). `plan.json` binds the per-clip
    masks into the image digest. No format change and no faked geometry.
  - **The presentation owner must apply the clip's mask on every clip
    selection (step 7).**
  - **Native replay:** a real Metal replay ran 9,780 rows and 39,220 assertions
    with zero failures, and checked native part visibility on every row. It
    found zero coefficient mismatches, 13 exact joins and 4 reversals per view,
    and 17 passing tests. The declared offline peak is 7,486,168 bytes; this is
    not runtime admission.
- **Step 7 (presentation), ADR 1201:** a per-source content set (actor, assembly and optional
  haul, inside `PRESENTATION_SET_BYTES` = 21,256,576 B) and `mole_presentation.gd`. One Actor per
  source is chosen by the row's source digest, and each clip's mask is applied on every selection.
  Row 29 is drawn from the handling clock. Haul program modes wait for the content-5 rows.
- **Step 4b (content 5), ADR 1200:** `qualified-haul-v6` (wire `dc4969e4…`, 37 rows/334 boxes/3
  sources) adds rows 30–36 in source 2's block: A STAND, A′ WALK, B CARRY, and C/D load/unload at
  yaw 0 and 16384. The successor bundle `first-entry-prefix-v1/qualified-haul-v2` carries
  ground-cap paces for 31 and 32. The connector catalog now admits ground-cap pace rows from any
  source, and `Assembly.uses` accepts successor counts. The grip certificate module, presentation
  and the station seam are still open.
- **Step 5 (work-area haul stations):** `underground_entry_work_area.gd` appends stand 9 beside M and stand 10
  beside R; indices 0–8 are unchanged. Each stand is its stock point plus the certified R−S turned to yaw 16384,
  (0,0,576) → (576,0,0), so the worker faces −X onto the stock at the storage point (rows 34/36).
  - Air is the already-surveyed storage corridor. Footing is the stand's own `STAND_FOOT`
    `[-579,-1,-412,406,0,412]`: the union of every floor box of rows 30–32, 34 and 36, including the stock's
    floor contact at S. `STORAGE_FOOT` stops at z = 2454, and the stock at M reaches 2460, so M's own footing
    cannot carry it. The site survey covers both stands through `ENDPOINTS`.
  - Stands are `ROLE_WORK`. They hold no container, and a separate endpoint keeps Inventory's one-container-per-cell
    rule untouched.
  - **Edges (three, not eight):** WALK R→stand R, CARRY stand R→stand M, WALK stand M→M. Delivery admits the
    source stand over WALK and the destination stand over CARRY (step 6). The return trip uses the existing
    M→H→R walks. 31 edges in total.
  - **Finding, check budget:** the entry confirmation requalifies every edge against the new Room inside one
    `Space.MAX_CHECKS` (1,048,576) preparation. Measured peaks: 929,330 before this step (88.6%), 1,028,537
    with the two stands and three edges (98.1%). The full symmetric set of eight edges refused with
    `WORLD_ROUTE_CHECK_CAPACITY` (about 23–33k checks per edge). Further work-area growth, such as G9's T0 and
    Kitchen cuts, will exceed the budget unless preparation cost or the budget changes. **This needs Brendan's
    decision.** Options: (a) raise the cold preparation budget for the work area; (b) make route
    requalification incremental, so it checks only edges whose swept volume meets the changed geometry; (c)
    publish haul edges only while a haul is pending, and retire them after.
- **Step 6 (Delivery station seam), ADR 1203:** `qualified-haul-v6/grip_certificate.gd` proves the exact rows 32–36
  and, at runtime, the stand transform: S − R at the row's heading, and both rows.json hand contacts inside the hand
  and stock volumes. Delivery derives each stand from the certificate. It reaches the source stand by WALK and the
  destination stand by CARRY row 32, and rechecks the stand plus `station_refusal` in the final leaf. It proves the
  stock's floor contact on the stand's footing, which is floor support at S. Trips are exactly 1,000 milli of wood.
  - The CARRY edge now arrives on the grip heading, because no loaded turn exists and ground turns admit only
    STAND/WALK.
  - Tests in `test_underground_haul_grip.gd`: certificate words against rows.json, station refusals, a part-unit
    refusal, and a wrong-heading refusal at begin_load.
- **Step 8, Delivery part:** surface stock is staged as a 1,000-milli wood lot in R's real
  `create_spatial_ground_staging` container. In `test_toolless_mole_hauls_one_staged_wood_unit_to_m_through_delivery`
  a real adult mole holds no tool and hauls it through Delivery into the BRACE Site's validated container at M:
  - WALK to R's stand, then an empty-handed turn to 16384;
  - row 34 lift, `load_payload`;
  - CARRY to M's stand, arriving at 16384;
  - row 36 set-down, `unload_payload`.

  This runs on the real content-5 bank, the production work area and the real Room/Site/Inventory owners. The
  Job completes, R's staging is emptied and M gains the lot. The foreman hookup is not built here. ADR 1203
  ("Open") lists the hook sequence and the two blockers for the live G4: stone has no authored grip rows, and
  R's container is shared with spoil.
