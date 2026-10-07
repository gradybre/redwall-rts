# 1199 — Tool-free mole stand/walk source and its haul joins
Date: 2026-10-06 · Status: Accepted source checkpoint; native replay and runtime rows pending

## Decision

ADR 1198 step 1, empty-handed half. Brendan chose to author a tool-free stand and walk
rather than reuse the pick walk. The packet is in
`godot/data/underground/mole-worker/haul-handling-v1/` (`author_empty_walk.py`,
`prove_empty_walk.py`, `test_empty_walk.py`, `reproduce_empty_walk.py`). Its evidence is
`evidence/empty-walk-v1/`. No published profile, actor image or runtime consumer changes.

- **Sources.** The supplied Meshy clips `mole_digger.idle.plain` (122 keys) and
  `mole_digger.walk.plain` (34 keys) come from `all-cast-v9.ugpal` (`5b368eb3…`). They are
  bound to the current body and rig from `mole-grip-v3.ugpal` (`08de5453…`) exactly as ADR
  1144's handling sources are. There is no pick part. Every supplied matrix is kept
  byte-for-byte.
- **Grounding.** Each key is re-grounded with `author_loaded_gait.ground_key`, which leaves
  the same 1/512 u sole gap as the loaded gait. The original per-frame grounding left the
  current body up to 6.9e-7 u below the floor.
- **Loop closure.** The native bake's final key is a wrap re-sample of time 0, differing by at
  most 5.7e-7. It is replaced by key 0 exactly, so the rendered wrap edge is exact.
- **Walk support.** The original walk loses one-foot support on 10 of its 33 intervals. The
  reviewed `support_keys` recipe adds 11 measured sole-transfer keys, giving 45 keys. As with
  the loaded gait, this lengthens the source cycle from 33 to 44 key intervals. Source timing
  is not a walk rate: playback follows the adopted ground pace cap (ADR 1198). The stand needs
  no transfer keys.
- **Joins.** `enter_haul` (31 keys) blends from stand key 8, the driver's existing ready time,
  into the haul `approach` start. It uses `author_program.global_blend` with smoothstep and the
  same re-grounding. `leave_haul` is its exact reverse, out of `recovery`'s end. Both haul
  endpoints are the same byte-identical pose, and both join endpoints are byte-exact. The
  floor stock at S is shown as world geometry, as in approach/recovery.
- **Proofs.**
  - No exact current-mesh vertex lies below the floor at any key.
  - Every rendered interval, including the loop wraps, has a foot vertex in the closed
    [0, 1] u cell at both ends.
  - The joins keep every non-grip triangle clear of the floor stock (`prove_program.prove`).
- **Row geometry.** Rows A STAND (mode 0) and A' WALK (mode 1) use the exact derivation of
  published ground rows 0/1/12: `compile_state_program.carry_bounds` over stand+walk. This
  covers the source hull, outward native/world residual over the full root range, the clipped
  whole-triangle floor and the full foot projection. Each is swept about the root with
  `rotated_box` and the world-yaw basis norm (`de8c3b04…`). Roles are assembled as
  `close_profile_source_gates.compile_ground` does; the pick's third box is absent. The rows
  are YAW_ALL with tool −1/−1, cargo −1/−1 and quantity 0..0:

  | Role | Boxes (u, root-relative) |
  |---|---|
  | BODY_HELD_LOAD, TURN_RECOVERY | `[-651,0,-651, 651,930,651]` and `[-402,-1,-402, 402,0,402]` |
  | STANCE_SUPPORT | `[-406,-1,-406, 406,0,406]` |

  The joins' own enclosure, `[-620..620]` with y up to 849, fits inside these roles.

## Why

The pick-holding rows cannot describe a tool-free hauler (ADR 1197). Reusing the supplied
tool-free clips keeps real animation and anatomy. The changes are limited to grounding,
loop closure, transfer keys and joins, using recipes that ADR 1144 already reviewed.
Reusing `carry_bounds` and the role assembly unchanged keeps the new rows comparable with
rows 0/1/12. The floor and support boxes come out identical to those rows, and only the
body sweep shrinks (651 against 738), because the pick no longer swings.

Rejected alternatives:

- Transfer keys only on failing intervals: this changes the cadence just as much, and it
  departs from the reviewed recipe.
- A both-feet support rule: the supplied idle rests its right foot 2–3 u above the floor.
- Keeping the native grounding: it penetrates the floor by up to 6.9e-7 u.

## Open

- ~~Native replay (ADR 1198's native-program v8).~~ Done in
  `evidence/native-program-v8/`. The four clips share the haul image. Stand/walk hide the
  stock with the Actor part mask, and the stock coefficient stays at the S fixture value.
  See ADR 1198, step 4a.
- Body self-clearance.
- Foot sliding and root advance on the joins.
- Profile wire rows and states, per-source blocks, the presentation binding, and joint memory
  admission (ADR 1198 steps 3–7).

Reproduce:
`reproduce_empty_walk.py --palette <all-cast-v9.ugpal> --grip-palette <mole-grip-v3.ugpal> --world-basis <world-yaw-v1.ugyaw> --out <new dir>`.
The reproduction runs 17 tests, including byte-identical rebuilds of every output.

## Successor: paws out of the thighs (ADR 1217, 2026-10-07)

ADR 1217's exact per-arm self-separation found that this stand rests its paws inside its thighs. The left paw is
unseparated from the left thigh on 75 of 121 stand intervals. The right paw is unseparated from the right thigh
and shin on 41 intervals with the open paw, or 21 with the closed paw. In the walk, the left paw touches on 3 of 44
intervals. This was the open "body self-clearance" item above.

Brendan chose to fix it at the source, for every use. The successor `stand-walk-v2/` swings each upper arm outward
by the smallest whole-degree constant that separates every pair. It re-authors the wood and stone joins by their
accepted recipe from the corrected ready key. Rows 30/31 and the v8/v9 images are unchanged until a content
successor carries it.

**Brendan approved the successor on 2026-10-07** (11° left, 13° right, as authored).
