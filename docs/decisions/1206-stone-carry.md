# 1206 — Stone carry: the procedural stone lump as the hauled stone

Date: 2026-10-06 · Status: In progress. Native image v9 and the stone rows done; content 6 next

## Brendan's decisions (2026-10-06)

| Question | Decision |
|---|---|
| Stone inputs (ADR 1203) | **Author a stone carry**: carry, load and unload rows, with the same native capture, proofs and grip certificate as wood. |
| Which mesh is the carried stone | **The procedural stone lump**, `bore_dressing.gd::stone_mesh()` (`godot/demo/tunnel/bore_dressing.gd:329`). |
| Carried size | **Sized to the log grip**: scale the lump so the existing carry pose's two certified hand contacts fit it. Keep the 0.8 vertical squash and no rotation unless the derivation shows they cannot seat both hands. Brendan explicitly approved this new size constant. Catalog mass stays 5,000 g/unit, and Brendan accepts that the stone looks larger than a solid 5 kg rock. |
| Carried size, after step 2 | **A smaller lump with a new grip.** Keep the squashed lump at the largest size clear of the body. Author a brand-new two-hand grip, lift, place, loaded gait and joins for it. Stop for Brendan's grip review before the lift. |
| Grip review (step 4) | **Candidate v1 approved**: R−S 576 u, the same stands as wood. Brendan accepted the about 1.7 mm snout gap. |
| Motion review (step 9) | **Approved**: the staged lift and place, the chest hold, the carry loop and the stand joins. |

The pinned demo assets have no stone part. `all-cast-v5…v9`, `mole-grip-v1…v3` and `pilot-v1…v4` carry
only the body, `log`, `mole_pick` and eleven vegetable props. The demo's hall and infirmary draw carried stone
as a `basket` prop, which exists only in side checkouts. Brendan chose the lump.

Stone is compiled item **53** (ascending-ASCII ids over `item_definitions.json`, as wood is 60). Its catalog mass
is 5,000 g/unit, the same as wood, so a 1,000-milli trip needs no new balance constant.

## Step 1 — exact source capture (done)

`haul-handling-v1/native_capture_stone/capture_stone.gd` runs inside the game project and calls the real
factory, never a re-typed copy. Output is `evidence/stone-source-v1/native-stone.json`.

- **Capture.** It contains every committed vertex and index of surface 0: 70 vertices, 108 triangles, indexed
  `PRIMITIVE_TRIANGLES`, format `34359742487`. The unit lump's AABB is about 2.12 × 2.08 × 2.00 (radius ≈ 1).
- **Pins** (`evidence/stone-source-v1/source-sha256.json`):

  | File | SHA-256 |
  |---|---|
  | factory `bore_dressing.gd` | `31000317…` |
  | `capture_stone.gd` | `b2710cd4…` |
  | `native-stone.json` | `ddcb70bf…` |

- **Reproducible.** Two runs give identical bytes. `test_stone_source.py --godot godot` reruns the capture and
  requires identical bytes. It also checks the pins and topology (5 tests).

**No palette bake is needed for the geometry.** The wood stock also entered the haul image through a factory
capture (`native_capture/capture_stock.gd` → `native-stock.json`), not through a palette. The palette supplied
only the carry clip's body pose, and that pose is reused unchanged for stone. Baking a stone carry into a new
palette would first need a stone hold binding in `demo_actor.gd`, which does not exist. Authoring one would
invent presentation. So no palette was written. The existing palettes are untouched.

## Step 2 — deriving the size from the wood grip (done; the rule does not fit)

`haul-handling-v1/derive_stone_scale.py` writes `evidence/stone-scale-v1/derivation.json`. It reads:

- the captured lump;
- the certified contacts C − S from `haul-rows-v1/rows.json` (station `grip_contacts`): (−344.7, 101.4, −0.1) u
  and (354.2, 92.9, 28.0) u;
- the reviewed static pose (`static-contact-review-v1/candidate/poses.npz`). Its 9,283 solid (non-grip)
  triangles come from the review's own hand partition.

The lump rests 1/512 u above the floor at S, as the wood stock does. It is a radially displaced sphere, so it is
star-shaped. "Inside" is tested exactly along each ray from the centre. These are float diagnostics, not the
exact static proof.

**With the 0.8 squash and no rotation, no scale seats both contacts** (sweep 0.02–0.80 m/unit, step 0.01):

| Uniform scale s (m/unit) | Contact ratio (≤ 1 seats) | Solid body vertices inside the stone |
|---|---|---|
| 0.15, the largest clear | 2.20 / 2.68 | 0 |
| 0.18 | 1.84 / 2.23 | 236 |
| 0.66 | 1.03 / 0.997 | 5,053 |
| 0.80 | above 1 on the left | about 6,000 |

The certified contacts sit 0.09–0.10 m above the floor and about 0.35 m either side of S. The pose's arms and
torso reach down to 42 u within 0.3 m of S, so the free space there is about the log's own envelope. A lump
wide enough to reach both hands at that height rises into the leaning body. It never quite seats, because its
lower flanks are lumpy.

**Relaxing the squash is not enough either.** A stretched rod does fit. The derivation's shape sweep (sx
0.32–0.56, sy 0.04–0.12, sz 0.04–0.56 m/unit) finds 29 scales that seat both contacts with no solid vertex
inside at the static pose. The smallest are:

- (0.44, 0.08, 0.10), a stone bar about 0.98 × 0.17 × 0.20 m;
- (0.48, 0.06, 0.08), about 1.04 × 0.13 × 0.16 m.

Each is longer than the 0.82 m log. Neither is a lump in the sense Brendan approved: it is a stone bar
following the log's envelope. The size rule therefore needs Brendan's choice before the grip is authored.

**Options:**

1. **Stone bar**: adopt a rod scale from the sweep (recommended: (0.44, 0.08, 0.10)). The whole reviewed wood
   motion is reused rigidly in the log's frame. The exact static proof, then every program, gait and join
   proof, must still pass for the new shape.
2. **Lump with its own grip**: keep the 0.8 squash at a clear size (0.15 m/unit or less, about
   0.33 × 0.26 × 0.31 m). Author new contacts and a new static pose and program for it. This needs new static
   candidates and a grip review like wood's `static-contact-review-v1`, then new lift, place, gait and joins.

Brendan chose option 2.

## Step 3 — the adopted scale (done)

`refine_stone_scale.py` writes `evidence/stone-scale-v2/fine.json`. It walks the squashed lump up in
0.001 m/unit steps against the reviewed body:

- **0.150 m/unit is adopted**, which gives (0.150, 0.120, 0.150). It is the last scale with no solid vertex
  inside the stone. At 0.151, two vertices of the snout are inside.
- The stone is then about 0.33 × 0.26 × 0.31 m.

This is Brendan's approved size constant.

## Step 4 — the static grip candidates (done; awaiting review)

The authoring tool, `author_stone_grip.py`, reuses wood's whole pose recipe (`author_handling.contact_pose`):
the carry hub, a 95° lean, a 96 u squat, fixed-length arm solves and `plant_soles`. Only two things change:

- the stock is the lump at S;
- each hand keeps its wood-grip orientation and is moved inward along X by its own amount.

The rest of the series follows wood's process:

- **Search.** `probe_stone_grip.py` ranks recipes by sampled vertices (`evidence/stone-grip-probe-v1/`).
- **Proof.** `prove_stone_contact.py` applies wood's exact `prove_static_contact.prove` to the lump unchanged.
- **Review numbers.** `review_stone_grip.py` adds float clearances for the reviewer.

All five candidates (`evidence/stone-contact-v1…v5`) pass the exact static rules: complete solid separation,
two exact hand witnesses, and three floor contacts.

- **v1 is recommended.** It keeps wood's station, R−S = (0,0,576), so the existing haul stands serve stone too.
  Its snout is 1.7 mm from the stone.
- **v4 is the alternative.** R−S = 640 gives the snout 63 mm of clearance, but stone hauls would then need
  their own stands.

`test_stone_grip.py` holds 8 tests: byte-identical rebuilds, the exact proofs, and the counterexamples (short
hands, buried hands, a lifted stone, an unplanted pose).

**Review packet:** `haul-handling-v1/evidence/stone-contact-review-v1/`. It contains `README.md` (what to
judge), `invocation.json`, `tests.log` and these images:

- `candidate-v1/overview.png` and `candidate-v1/hands.png`
- `candidate-v4/overview.png` and `candidate-v4/hands.png`

## Step 5 — approval and exact star containment (done)

`evidence/stone-contact-review-v1/review-acceptance.md` records Brendan's approval of v1, in the same way wood's
reviews record theirs. The frozen packet hashes are unchanged.

**Finding: the shared provers' containment test assumes a convex stock.** `prove_static_contact.solid_containment`
counts a point inside only if it is behind every face plane. That is exact for the wood cylinder, but it can miss
points inside a non-convex lump.

The lump is star-shaped about its origin, the stock translation, because its sphere vertices were only pushed
radially. `stone_geometry.py` tests containment exactly on that basis:

- it refuses a mesh whose faces are not all oriented alike about the origin;
- it refuses any direction that no face covers.

`prove_stone_star.py` confirms the approved v1 pose has no solid vertex inside or on the lump
(`stone-contact-v1/static-contact-star.json`). A buried-stone counterexample refuses. Every later stone proof uses
the star test for containment, alongside the unchanged surface separation.

## Step 6 — the four-phase program (done)

`author_stone_program.py` writes `evidence/stone-program-v1/` (61 keys per clip).

**Wood's single lift path fails for the stone.** It raises the stock and draws it in on one smoothstep, which
pulls the lump into the snout: it penetrates up to 57 u around key 8 of 16. The test
`test_wood_unstaged_path_buries_the_snout` proves the refusal exactly.

The stone path is staged instead, in sixteenths of the clip:

1. Over [0, 8], the stone eases 48 u away from the worker.
2. Over [2, 12], it rises 448 u.
3. Over [8, 16], it is drawn in to z = −384 u, once the head has lifted clear.

The body follows wood's recipe unchanged: the squat and lean, then a hub lean of 15° (wood used 20°). The stone
never rotates, and both arms keep the approved hand–stone relation.

**Proofs:** all four clips pass wood's continuous `prove_program.prove` (`*-proof.json`), plus exact star
containment at every key:

- all intervals separate;
- the feet are supported on every interval;
- nothing goes below the floor;
- both exact hand certificates hold on every lift and place interval.

**Structure:**

- Lift key 0 is the approved v1 pose, byte for byte.
- Place reverses lift, and recovery reverses approach.
- During approach and recovery the floor stone is fixed world geometry.

Renders of lift keys 0, 30 and 60 are in `render-lift-*/`. `test_stone_program.py` holds 6 tests.

## Step 7 — the loaded gait (done)

`author_stone_gait.py` writes `evidence/stone-gait-v1/`. It follows wood's recipe (`author_loaded_gait`) with no
change:

- the held upper body and stone come from the proved lift's final key;
- the hips and legs come from every key of the supplied `carry_heavy_object_walk`;
- the stone follows the spine rigidly;
- the entry is a smoothstep blend into the loop;
- lower-envelope sole-transfer keys are added where support would otherwise fail.

The clips are hold 2, enter 65, carry 219 (looped) and exit 65 keys, the same counts as wood. The variant is
exactly 1,000 milli of stone at the Catalog's 5,000 g/unit. No rate or density is adopted.

**Proofs:** all four clips pass wood's `prove_loaded_gait.prove`, including the carry loop's wrap
(`*-proof.json`), plus exact star containment at every key:

- every interval separates;
- support alternates between the soles;
- nothing goes below the floor;
- both rotating-stock hand certificates hold (Bernstein sign proofs).

The carry proof checks 10,436 pairs in about 66 s.

**Joins:** lift → hold → enter → carry → exit join byte for byte. Renders of carry keys 0, 54 and 110 are in
`render-carry-*/`. `test_stone_gait.py` holds 4 tests, including a stone pushed into the chest, which refuses.

## Step 8 — the stand joins (done)

`author_stone_joins.py` writes `evidence/stone-joins-v1/` and follows wood's join recipe
(`author_empty_walk.join_keys`, `support_keys`, `with_fixture`):

- `enter_haul_stone` (31 keys) blends from wood's stand ready key 8 into the stone approach's first key.
- `leave_haul_stone` is its exact reverse, out of the stone recovery's last key.

The stand and walk clips are wood's own, reused byte for byte.

`prove_stone_joins.py` applies wood's join rules: exact floor and one-foot support, plus non-grip separation from
the floor stone (`prove_empty_walk.support_proof` / `join_proof`). It adds exact star containment. Both joins pass
(`joins-proof.json`). `test_stone_joins.py` holds 3 tests: a rebuild, the exact endpoints and the stored proof.

## Step 9 — motion review packet (approved)

Wood's program and gait each had a review before native capture, so the stone motion stops here.

**Packet:** `haul-handling-v1/evidence/stone-motion-review-v1/`. It contains `README.md` (what to judge),
`motion-review.json` (the closest approach per clip), `invocation.json` and renders of the lift, the carry loop
and the join. Native image v9 and everything after it wait for Brendan's approval.

## Step 10 — native stone image v9 (done)

`evidence/native-program-v9/` (see its README) holds a separate 10-clip image, runtime source 3:

- `stone-handling.ugactor`, 791,844 B, `49ff3018…`;
- parts: the body and the stone lump; the compiler is `compile_native_program_v9.py`.

**Replay:** a real Metal replay (`run_native_program_v9.py`, with the real stone factory staged) records 7,794
samples and 31,262 assertions with zero failures. `verify_native_program_v9.py` finds zero coefficient
mismatches, 11,256 exact two-hand witnesses, 11 joins and 4 reversals per view. It also checks the cross-image
join: v8's `stand`@8 equals v9's `enter_haul_stone`@0.

**Finding:** stone-source-v1's JSON numbers lost 16 negative zeros, which the engine's mesh fingerprint hashes.
`stone-source-v2` records the exact bits, and its engine fingerprint is `e9c10ccc…`.

**Census:** the declared peak is 7,285,004 B (v8: 7,486,168). The declared presentation set with stone is
28,541,580 B. That is a presentation reservation, not simulation-owned memory under the 100 MB gate.
`tools/underground_memory_budget.py --check` still fails on the pre-existing qualified-step-v4 witness digest;
this change does not touch it.

## Step 11 — integer stone rows (done)

`derive_stone_rows.py` writes `evidence/stone-rows-v1/rows.json` (`caa36d82…`). It is `derive_haul_rows.py`'s
derivation, unchanged, including the corrected `clip_below` floor maximum (ADR 1198), both native heading tables
and the residuals, applied to the ten v9 stone clips:

| Row | Boxes (u, root-relative, yaw 0) |
|---|---|
| CARRY stone, YAW_ALL | body `[-556,0,-556,556,937,556]`; body floor `[-286,-1,-286,286,0,286]`; stone `[-598,447,-598,598,821,598]`; stance `[-375,-1,-375,375,0,375]` |
| HAUL load stone, yaw 0 | body `[-349,0,-637,346,860,234]` and floor; stroke: stone `[-174,0,-779,154,704,-229]` and floor contact `[57,-1,-514,60,0,-504]` |
| HAUL unload stone, yaw 0 | the same, with the approach adding the held stone |

**Station:** R−S = (0,0,576), wood's station, and S = (0,0,−576). Both hand contacts are re-derived exactly
from grip v1: C−S cells `[-155,112,37 …]` and `[122,171,30 …]`.

**The stone's floor contact is off-centre.** The lowest vertex of the lump is 67 u toward the worker from S.
`test_derive_stone_rows.py` holds 5 tests, including a byte-identical re-derivation.

## Remaining steps

1. ~~Static contact candidates and exact witnesses~~ (step 4); v1 approved.
2. The four-phase program.
3. The loaded gait.
4. The stand/walk joins.
5. Native image v9, using sibling tools; v8 stays untouched.
6. The integer rows, with the corrected `clipped_triangle_floor` maximum.
7. Content 6, as the successor of `qualified-haul-v6`.
8. The certificate extension, the consumer switch and renewed pins.
9. The Delivery test for a tool-free stone haul from R to M.

Image sizes and the joint memory census (ADR 1198 open item, 100 MB gate) are recorded at step 5.
