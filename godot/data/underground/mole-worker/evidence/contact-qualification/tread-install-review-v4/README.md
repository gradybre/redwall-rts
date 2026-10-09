# Tread installation tap on the curled pick paw: human review packet (ADR 1209 step 4 rev 4, ADR 1216)

This packet is for **Brendan's review of the tap with the approved curled paw**.

## What changed since revision 3

Brendan approved the curled paw's shape (ADR 1216). ADR 1216's steps then ran:

1. **The GDScript successor** `mole_grip_curl_source.gd`. It applies the approved deformation to the true original
   mesh, with analytic normals and tangents. It refuses any other source body, hand or pick fit (the accepted
   checks), and it pins the derived fingerprint `2a8517bb…`. Run natively on the staged body, it matches the
   Python author to 1.2e-7 m at every vertex (`capture_curled_paw.gd`).
2. **The native bake** (`rebake_curled_grip.py` → `tools/bake_mole_curl_grip_content.gd`) wrote
   `mole-grip-v4.ugpal` (`d72d3fd6…`): 7 gripped states, 354 frames, 8,496 native matrix checks, and no unexpected
   diagnostics or leaks. The palette and its 150-file import archive are committed, under LFS, in
   `../grip-source-v4/content/`. The pick-source proofs read it through `curl_source.py`; the haul authors keep v3.
3. **The successor closure:**
   - `grip-proof-v3` envelopes;
   - `curl-v1`, the compiled content (`8ad9d1ad…`);
   - `topology-curl-v1`, a native census (34,119 assertions, 0 failures).
4. **Grip exclusion and grip proof** (`../curl-grip-proof-v1/proof.json`). The accepted exclusion rule picks out
   exactly the same 845-vertex, 448-triangle grip patch on the curled mesh, so no successor rule was needed. At the
   re-held ready key:
   - nothing outside the patch penetrates the pick;
   - the exact test finds palm and claw contact on the shaft (it stopped at its 32-pair limit);
   - the claws wrap 105° around it.
5. **Native capture** (`../curl-native-v1/`): 731 poses, 0 failures, and 0 analyzer warnings in 4 files. It
   includes idle, walk, crouch and swing PNGs of the curled grip.

**The tap** (`../author_tread_install_v4.py`) reuses revisions 1 and 2 unchanged: the station, the workpiece, the
fixture, the swivel elbow with the ready wrist, the keys and every accepted proof. Only the source closure is new.
All candidates are **upright** with a handle lean within the accepted 25–50°.

## Candidates (`../tread-install-v4/`, all clear every proof)

| | Strike (x, z) | Lean, azimuth | Shaft angle | Wrist turned from ready, at contact / maximum | Tool to body | Image |
|---|---|---|---:|---|---:|---|
| accepted v4 (L0 → T0, closed paw) | 128, −448 | 35°, 30° | 65.7° | — | 7.8 u | `adc61764…` source |
| **s** | 160, −270 | **35°**, 60° | **65.7°** | **3.3° / 39.1°** | **21.0 u** | `15693f6ed23f…` |
| t | 64, −294 | 35°, 60° | 65.7° | 7.1° / 42.4° | 7.6 u | `ec9364bf3b30…` |
| u | 64, −294 | 30°, 60° | 60.7° | 10.1° / 31.0° | 16.7 u | `3ea3cd0dd165…` |

How to read the table:

- The shaft angle is from the two-key search: the line from the adze end to the grip, measured above horizontal.
- The wrist column is the forearm-to-paw angle compared with the ready carry, from each candidate's
  `pose_solver_diagnostics`.
- Tool to body is the float vertex gap to the non-grip body over every key (`review.json`).
- Every candidate keeps 13.7 u to the bearer and 13.6 u to the riser.

**Recommendation: s.** It holds the accepted handle angle (35°, shaft 65.7°) with the ready wrist at contact
(3.3°), and has the widest tool clearance (21.0 u).

## Images (per candidate, in `candidate-*/`)

| Image | What it shows |
|---|---|
| `grip.png` | The paw on the handle at the contact key, from the front, the right side and the top, all at ×1.4 on the grip pivot. Row 1 is the **accepted v4 contact (closed paw)**; row 2 is the **candidate (curled paw)**. |
| `overview.png` | The contact key from the front, the side and the top, with the bearer and decks outlined. |
| `hands.png` | The adze on the bearer, and the feet between the bearer and the riser. |
| `motion.png` | Entry keys 0, 10, 20 and 30, and tap keys 0 and 16, from the side. |

Native pictures of the curled grip in the baked states are in `../curl-native-v1/`, for example `idle-00.png`,
`walk-24.png` and `hammer-48.png`. Digests are in each `review.json`. The tap images are painter renders, not
native captures.

## What to judge

1. **The wrap.** In `grip.png` row 2, do the claws read as closed around the shaft lower down, compared with v4's
   end-in-palm grip in row 1?
2. **The handle angle and line.** The shaft reads at v4's angle, but it still crosses in front of the body toward
   the strike.
3. **The entry swing** (`motion.png`).

## Not done, and why

- **Per-source presentation for sources 0 and 1 is not wired.** The Content refuses any part whose geometry
  fingerprint differs (`Content.mesh_binding_refusal`). Sources 0 and 1 are the accepted cut and install images,
  compiled on the closed paw with the accepted fit. Drawing them with the curled paw would refuse them and drop
  the mole from the demo. Holding the pick by the old fit while drawing the curled claws would look wrong anyway.
  - The curled paw therefore enters presentation with the first image compiled on it: this tap, as its own source
    with content 7.
  - That source adds one Content reservation (`curl-v1` declares 6,920,048 B admitted peak, the same as firm-v1) and
    one derived body mesh.
  - Rows 2–29 move to the curled paw when they are re-authored ("later").
- **Native capture of the tap itself** comes with content 7.
- **Still open:** the arrival step back from the descent's end, and T6's sill plane at 64 u.

## Reproduce

`invocation.json` lists the commands. For the run, the demo assets were cloned from the frozen
`redwall-rts-codex-ug-space` worktree and imported; every pinned input was hash-checked, and the clone was removed
afterwards. The tests:
- `../test_curl_grip_chain.py`: 5 tests, with a reconstruction test that skips without the assets;
- `godot/test/test_mole_grip_curl_source.gd`: 5 tests.

Both are recorded in `tests.log`.
