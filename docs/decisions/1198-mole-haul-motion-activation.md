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
