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
