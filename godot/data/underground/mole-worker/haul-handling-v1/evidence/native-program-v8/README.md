# Native haul image v8 — 12 clips, source-only candidate

ADR 1198 step 4a. One native-replayed haul actor image holds the eight reviewed
haul clips (unchanged from v7) and the four tool-free clips from
`evidence/empty-walk-v1/` (ADR 1199). It changes no runtime consumer, driver,
profile, simulation owner, project configuration or memory registry. Independent
review is pending.

Image: `compiled/haul-handling.ugactor`, 993,008 bytes,
sha256 `cc8542712705248f944d7430cbba0b7a365860f0073473c2fc0cb9106cf97a85`.

| # | Clip | Keys | Loop | Part mask |
|---|---|---|---|---|
| 0–7 | approach, lift, place, recovery, hold, enter, carry, exit | 61, 61, 61, 61, 2, 65, 219, 65 | carry only | body+stock (3) |
| 8 | stand | 122 | yes | body only (1) |
| 9 | walk | 45 | yes | body only (1) |
| 10 | enter_haul | 31 | no | body+stock (3) |
| 11 | leave_haul | 31 | no | body+stock (3) |

That is 824 stored keys and 812 rendered intervals. Twelve clips fit the
sixteen-clip limit (MAX_CLIPS).

## How a tool-free clip is encoded

The `.ugactor` wire has one fixed part list, here body and stock, and a uniform
per-frame stride. Every frame therefore carries a transform for every part. The
format has **no per-clip part-presence field**. Part presence already belongs to
the Actor: `Actor.set_parts_visible(mask)`, which the presentation owner sets
when it selects a clip. No format change was needed.

- For `stand` and `walk`, the stock column holds the exact S fixture transform.
  This is the same float32 value that approach key 0, recovery's last key and
  both joins already show. Their mask is 1, so the stock is hidden. The body
  columns are byte-identical to the pinned empty-walk sources. No stock geometry
  is moved, scaled, collapsed or invented. Because the hidden value is the
  fixture's own value, the stand-to-enter_haul and leave_haul-to-stand joins are
  byte-exact across the whole row.
- `plan.json` carries `part_visibility_masks`, and its SHA-256 is bound into the
  wire header. `program.json` repeats the mask per clip.
- The native capture applies each clip's mask through the real Actor. It records
  the actual `MeshInstance3D.visible` bits of both parts in every row's eighth
  integer, and the verifier requires them to equal the plan.

The hidden stock's lowest point reaches −3.75 u, because the per-frame stand and
walk grounding moves every part. It is neither rendered nor a physical claim, so
the floor proof covers visible parts only and reports this value separately.

## Result and limits

- 9,780 native samples across the same three nonzero World-root/heading views as
  v7, with 39,220 native assertions. Zero failures, diagnostics or leaks. The
  import was clean, and the analyzer found zero warnings in the v8 capture script.
- Zero coefficient mismatches. The largest source-to-native-input vertex
  differences are the same as v7's: body 0.000287307 u, stock 0.000995328 u.
- Minimum visible floor gap: body 0.00136567 u, stock 0.00194168 u.
- 11,256 exact rational two-hand witnesses, the same set as v7 (the tool-free
  clips have none).
- Per view: thirteen exact joins (v7's nine, plus stand@8→enter_haul,
  enter_haul→approach, recovery→leave_haul and leave_haul→stand@8) and four
  exact reversal pairs (v7's three, plus enter_haul/leave_haul).
- Seventeen executable tests pass. They include:
  - v7 executables and image unchanged;
  - byte-identical v8 rebuild;
  - the eight reviewed clips identical to v7;
  - the tool-free body equal to its source and the hidden stock equal to the fixture;
  - refusal of changed source bytes;
  - loop wraps;
  - stock visible during walk refuses;
  - a hidden stock coefficient that is still exact;
  - the World root applied twice;
  - a broken stand join;
  - the wire census.

As in v7, this is sampled native **input** evidence. It does not establish:

- GPU roundoff or unsampled Q16 coefficients;
- foot sliding or root advance on the joins;
- body self-clearance;
- finite World traversal;
- runtime rows or presentation binding;
- gameplay timing;
- joint memory admission.

## Census (`census.json`, loader declarations, not measured)

- Palette: 992,096 bytes, against v7's 716,380.
- Tables: 888 bytes.
- Declared offline peak: 7,486,168 bytes, against v7's 7,210,260. The separate
  544,768-byte WorldBasis is excluded.
- Runtime transitive script closure: 86 files.
- Capture: 12,596,656 bytes.

The global simulation state delta is zero, and runtime admission remains false.

## Pins and reproduction

- `source-sha256.json` pins the executables and the 86-script closure used by
  the native run.
- `compiled/proof.json` pins every reviewed input: the haul program, the loaded
  gait, the empty-walk manifest and clips, the wrapper and the basis.
- `final-source-sha256.json` pins all eleven executables, including the verifier
  and the tests.
- `output-sha256.json` pins every output.
- External inputs:
  - `all-cast-v9.ugpal` `5b368eb3…`
  - `mole-grip-v3.ugpal` `08de5453…`
  - `body.glb` `a559a5f8…` and `.import` `a485ee3d…`

  All of these come from
  `/Users/brendan/Developer/redwall-rts-codex-ug-space/godot/demo/assets/`.

Run these with the NumPy Python
`/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`:

1. `run_native_program_v8.py --palette … --grip-palette … --body … --out <new>`.
   The exact argv is in `invocation.json`. It runs compile, the headless import,
   the analyzer on port 6364, and the **non-headless** Metal replay.
2. `verify_native_program_v8.py` and `test_native_program_v8.py`, as in
   `validation-invocation.json`.
3. `census.py --capture <dir>`.

The v7 tools, `native_replay/` and every earlier output are unchanged.
