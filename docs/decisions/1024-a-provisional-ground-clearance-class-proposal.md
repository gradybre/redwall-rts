# 1024 — A provisional ground clearance class for the four starter adults (PROPOSAL)
Date: 2026-10-02 · Status: Proposed — awaiting Brendan's confirmation. **PROVISIONAL; closes no MOVE gate.**

Numbered 1024 from the range the brief assigned (1021–1029). No record numbered 1021–1029
exists on any local or remote branch or in any sibling worktree (`git ls-tree` over every ref,
2026-10-02).

## Decision (proposed)

Brendan ruled on 2026-10-02 that the four starter adult species get a **provisional** ground
clearance class, recorded as NOT closing MOVE-G01, so that task 06.4's slice H3 can compose the
real navigation and movement code; he asked H0 to propose the values from existing adopted
geometry for his confirmation. The proposal:

| Profile | Species | Proposed provisional class | Square it needs | Body box used (u, local, quantized outward, margin 0) | Translated min at `(+256,+256)` |
|---:|---|---:|---|---|---|
| 0 | mouse | **1** | one 0.5 m cell | x −149..149, z −118..118 | (107, 138) |
| 1 | mole | **1** | one 0.5 m cell | x −185..185, z −157..157 | (71, 99) |
| 2 | otter | **1** | one 0.5 m cell | x −229..229, z −199..199 | (27, 57) |
| 3 | squirrel | **1** | one 0.5 m cell | x −171..171, z −142..142 | (85, 114) |

All four share class 1, so every starter shares one route-cache bucket and a 0.5 m opening admits
each of them.

## How the values were derived

1. **Heights — adopted.** DEC-039 (`USER_CONFIRMED`, `docs/setting_decisions.md`): mouse 1024 u,
   mole 922 u, squirrel 1178 u, otter 1526 u.
2. **Body box — the only horizontal geometry with an approved scale.** The proportion comparison
   manifest (`godot/assets/lookdev/proportion_comparison_manifest.json`, the DEC-039 review scene)
   gives each species `torso_width` and `torso_depth` as permille of crown: mouse 290/230, mole
   400/340, squirrel 290/240, otter 300/260. Width = height × permille, centred on the root.
3. **Class — the adopted envelope method.** MOVE-C2-R01 Q1 §3–5
   (`docs/rulings/2026-09-14_cycle02_movement_envelopes.md`): quantize outward
   (`lo = floor(1024·min) − margin`, `hi = ceil(1024·max) + margin`), translate by the baseline
   root offset `(256, 256)`, require `ox+xlo ≥ 0, oz+zlo ≥ 0, ox+xhi ≤ 512k, oz+zhi ≤ 512k`, and take
   the least `k`. Computed with `tools/validate_movement_envelopes.py`'s own
   `quantize_axis_units()` and `classes_admitting()` (scratch probe, not committed); every species
   fits `k = 1` and no larger class is needed.
4. **Map meaning — unchanged.** `spatial_world.gd`'s `_clearance[c]` is the side of the largest
   passable square whose north-west corner is `c`; class 1 asks only that the route cell itself be
   walkable.

## The other derivations, and why they do not give values

| Box | mouse | mole | squirrel | otter | Why not proposed |
|---|---|---|---|---|---|
| Walking-pose blockout bounds (includes the tail) | 3 | PLACEMENT_INCOMPATIBLE | 4 | PLACEMENT_INCOMPATIBLE | Mole (x −277) and otter (x −343) put the body behind the north-west anchor at `+256`; MOVE-C2-R01 §5: "no larger class repairs that placement". |
| Carrying-pose blockout bounds | PLACEMENT_INCOMPATIBLE for all four | | | | The carried prop reaches back past the anchor in z. |
| `ceil(max(width, depth) / 512)` | 1–3 | | | | MOVE-C2-R01 §4: "only a lower bound and never replaces offset containment". |
| Class 2 for mole and otter with a recentred offset | — | 2 | — | 2 | Needs a G02 placement contract MOVE-C2-R01 §5 forbids this work from granting; the NW-anchored square would also make a class-2 body unable to approach a footprint from its west or north side. |

## What this does NOT claim — the caveats Brendan is confirming past

- **It is a torso proxy.** MOVE-C2-R01 (Astra, 2026-09-14): "Torso-width proxy values are not
  clearance measurements"; `movement_profile_authoring.md` §6.3 disqualifies the blockout bounds
  as qualification evidence on five grounds. Those rulings stand: this value is PROVISIONAL by
  Brendan's 2026-10-02 ruling, which outranks them for this purpose only (AGENTS.md authority
  order), and qualification remains open.
- **No tail, ears, turn sweep, satchel or margin.** The squirrel's tail is 950‰ of its height and
  the mouse's 820‰; the box ignores both. A 45° turn sweeps the otter's torso to ±303 u, which
  would not fit `k = 1` at `+256`. The carried satchel's bounds are not measured. `margin_u` is 0
  and unauthored.
- **MOVE-G01 stays open.** Q2-01–05 (swept bounds, vertical extent, margin, anchor-to-root offset,
  derived class) stay empty; this fills none of them. MOVE-G02–05 are untouched.
- **No code binds it yet.** `movement.gd::profile_clearance_class_into()` still refuses every
  starter profile, and `test_no_profile_publishes_a_clearance_class` still pins that. Binding the
  value is H3's change, made only after confirmation, and it will mark the bound value PROVISIONAL
  in code and keep MOVE-G01's open status in `movement_profile_readiness.json`.

## Options for Brendan

- **(a) Recommended:** class 1 for all four, as above.
- (b) Class 1 for mouse and squirrel only; mole and otter stay refused until measured (hauls by
  moles and otters wait).
- (c) Walking-pose bounds: mouse 3, squirrel 4, mole and otter refused (a 1.5–2 m passage
  requirement for a mouse; most of the starter map's paths would refuse).

## Source

Brendan's 2026-10-02 hauling rulings (R-H1, relayed by the coordinator; decision 1021); DEC-039;
MOVE-C2-R01 Q1 §3–6; `godot/assets/lookdev/proportion_comparison_manifest.json`;
`godot/scripts/core/spatial_world.gd` `_recompute_clearance()`; decision 0185 /
GROUND-CLEARANCE-R01v1; `docs/planning/movement_profile_authoring.md` §4.1, §6.3.
