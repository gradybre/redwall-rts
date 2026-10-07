# 1217 — Claw digging and paw fitting: no tools for now

Date: 2026-10-07 · Status: Accepted direction (DEC-052). Step 1 reviewed: stations move in to 1,430 u and the stroke
becomes two-paw. Step 1b, the two-paw stroke, is stopped for Brendan's review.

## Decision

Brendan's decisions (DEC-052, 2026-10-07):

1. **Scrap the pickaxe for now.** All digging uses the mole's claws.
2. **Paws for fitting too.** No tools at all. Moles dig with claws and seat and fasten timber (the paid L0, T0 and
   tread installations) by hand.
3. **Keep the pick work, inactive.** Rows 2–29, the curled pick paw (ADR 1216) and the tread-tap candidates
   (ADR 1209 step 4) stay as dormant published content. The runtime switches to claw and paw rows once they are
   authored.

Nothing published is edited. Claw and paw content arrives as successors: new motion sources, new integer rows in a
content successor, and renewed pins.

## Why

Brendan's call. In engineering terms it also removes the hardest open seam of the first entry: G11 (no settlement
mole ever has a tool) and the tooled/tool-free juggling in the hauler (ADR 1210). The cost is new motion content,
because every work row published today holds the pick.

## Balance: what depends on the tool

- **Unchanged:** every work amount and bill (brace 2,000, cut 4,000, finish 3,000 milli-WU; wood 250 + stone 250
  per quantum; L0 4,000 wood / 32,000 mWU; T0 and each tread 1,000 / 12,000), DEC-050's pace, and the haul rows.
- **Depends on the tool, and changes:** tool wear. SET-MOVE-ECON-001 bills 1 durability per 10 completed WU on
  "BUILD, tool" rows (GDD §5.7). Claw work has no tool, so it wears nothing. The "tool" owner condition of every
  row of that table is amended (a note sits under it): Brendan extended claws to backfill, spoil-tip preparation,
  compaction, reclaim and tip closure on 2026-10-07.
- No GDD requirement or balance table scales a dig or BUILD rate by the tool, so no rate changes.

## Impact map: every runtime path that assumes a tool

"Now" means it can be done before any claw motion exists. "Waits" means it needs authored claw/paw rows first.
Paths are under `godot/`.

| Path | Today | What changes | When |
|---|---|---|---|
| **Profiles rows 0–1, 2–12** (source 0) | Tooled STAND/WALK (0/1, automatic) and source-clocked pick travel: approach READY_FORWARD 2–5, retreat READY_BACKWARD 6–9, short step 10/11, canonical ground 12. All carry tool 54 / BASIC. | Dormant. Plain ground travel uses the tool-free rows 30/31. The work-approach family (forward/backward, short step, canonical ground) needs tool-free successors, because the Room planner (ADR 1213) and Frontier itineraries select by identity, tool included (`underground_room_station_planner.gd` `IDENTITY_FIELDS`). | Waits (motion M6) |
| **WORK rows 13–28** (4 yaws × down/high/front/INSTALL) | Pick strokes. BRACE, CUT and FINISH all select the same downward program (ADR 1188). | Claw successors: one downward claw stroke serves all three phases (M1), then high (M2) and front (M3) strokes for the Room, and paw seating for INSTALL (M4). Each is authored at yaw 0 and rotated exactly into the four yaws, as 13→17 is today. | Waits (M1–M4) |
| **Row 29, handling** (source 1, `ASSEMBLY_PALM`, `qualified-assembly-v1/source_program.gd` `F_TOOL` 54) | Holds the pick while the palms handle the bearer. | A tool-free handling source (M5). | Waits |
| **Crew selection** `scripts/core/underground_entry_runtime.gd` `_select_crew` (:156–172) | Takes the first present mole with an occupied, equipped Gear row; `_crew.tool` is that lot. Otherwise `ENTRY_CREW_NO_TOOLED_MOLE` → G11. | Select a present adult mole with no tool requirement; `Crew.tool` becomes `NULL_REF` for claw work. | Waits: switching before the claw rows exist only moves the refusal to Profiles (`PROFILE_TOOL_REQUIRED`). Change it in the same step as the content successor. |
| **Foreman** `underground_entry_foreman.gd` (:292 `claim_tool_for_work`, :304 `admit_work_actor(..., tool)`, :318 `set_tool_gate(SATISFIED)`, :345/:370 travel and work refresh with the tool) | Every phase claims and gates the tool. | Claw phases bind their Jobs with `GATE_NOT_REQUIRED`, claim nothing, and pass `NULL_REF`. | Waits (rows), but the gate change is small |
| **Excavation sites** `excavation_sites.gd` :1143, :1299 | `REFUSE_TOOL_NOT_CLAIMED` unless the Job's tool gate is satisfied. | Accept `GATE_NOT_REQUIRED` for claw phases (DEC-052 amends ECON-002's tool condition for brace/cut/finish). | Waits; with the foreman change |
| **Work / Gear** `work.gd` :772–834, :1231–1246; wear settlement :1411–1464 | Tool claim, gate and wear. | No change to the owners. Claw work simply never claims a tool, so no wear settles. | — |
| **Hauler** `underground_entry_hauler.gd` (:188–191 `gear.unequip` at M, :194–205 switch at rest to row 31, :300–307 `gear.equip` on return; the foreman :292 and installer :214–217 switch back to the tooled source profile) | Puts the tool in M's container, hauls tool-free, re-equips. | **Unequip and re-equip go away.** The worker never holds a tool. | Waits; with the crew change |
| **Switch at rest** (ADR 1210, `Routes._source_refresh_refusal`) | Needed to move between the source-clocked tooled family and the automatic tool-free family. | **Still needed, for a different reason.** Claw WORK rows are source-clocked (`POLICY_SOURCE_WORK`, READY/ENTRY clocks), while haul and plain travel rows (30–41) are automatic. The switch stays a policy-family change with the full re-proof; it is no longer a tool change. If M6 authors a tool-free source travel family, travel-to-work never needs it; haul-to-work still does. The rule itself is unchanged. | — |
| **Connector contacts** `underground_connector_contacts.gd` :972–987, :2035–2064 | The installation source must name the BUILD tool (`F_TOOL == tool item`). | Accept a tool-free installation source (paw seating). | Waits (M4/M5) |
| **Room world bindings** `underground_room_world_bindings.gd` :725, :754, :766–802 | Room Jobs need a satisfied tool gate; the retreat row's `F_TOOL` must match. | As the foreman: no tool gate for claw phases; identity matching then selects tool-free rows. | Waits (M2, M3, M6) |
| **Routes / WorldRoutes** `_physical_tool_leaf` (:3773), `_turn_tool_leaf` (:3941) | Already accept a null tool when the row's tool is −1 (rows 30–41 use this). | None. | — |
| **Delivery** `underground_connector_delivery.gd` | Already tool-free (HAUL, `GATE_NOT_REQUIRED`, no equipped tool). | None. | — |
| **Presentation** `demo/cast/entry_worker_meshes.gd` (:59 shared body fitted to the pick, :64 `held`), `mole_presentation.gd` (sources 0–3), `mole_profile_driver.gd` (:85–109 refuses `tool == NULL_REF`, :139 rows must hold a BASIC tool) | Sources 0/1 draw the pick on the closed paw; the source-0 driver is pick-only. | A new claw source (content successor) drawn on the **open paw** with no held part. Per-source presentation (ADR 1201/1211) already selects the Actor by the row's source digest. The pick-only driver stays for the dormant rows; the claw source is drawn by the per-source Actor from the simulation's selected row, as rows 29–41 are. One body mesh per source: see "Open paw versus closed paw". | Waits (M1 onwards) |
| **G11 alert** (`ENTRY_CREW_NO_TOOLED_MOLE`, `settlement_system.gd` :1954, :2237–2243) | Raised by the live demo; ADR 1197 planned tools from stores. | Tool equipping no longer blocks the first entry. The alert stays until claw rows land; then crew selection stops requiring a tool and the code is retired. | Waits |
| **Descent plan** (ADR 1209) | Stair gaits (`stair-descent-v7`, `stair-motion-v15`, handoffs) hold the pick; step 4 is the pick tread tap. | Step 4 (the tap) is **parked**. Tread T_k is seated by paw from T_{k−1} (M4b), and the T6 sill by paw at y = 64 (M4c). The stair gaits need tool-free re-proof (M7). The flight geometry, D1–D3, the cut rows and the bills are unchanged; the cut stations reuse the claw stroke. | Waits |
| **Pick paw** (ADR 1216) | Curled paw, `mole-grip-v4`, `curl-v1`, its proofs and captures. | Dormant, kept. No per-source curled paw is wired. | — |
| **Tests** that equip a tool as the G11 stand-in (`test_underground_host.gd` `_equip_first_mole`, `test_underground_first_prefix.gd` `_finite_stock_and_worker`, `test_underground_paid_assembly_handling.gd`, and about 15 more fixtures) | Equip a BASIC tool. | Keep them: they exercise the dormant tooled rows. New claw tests start tool-free. | — |

## Open paw versus closed paw

The tool-free haul sources (2 and 3) are drawn on the closed paw, because their wood and stone grips were
certified on it (ADRs 1198, 1206). Brendan's instruction is that claw and paw work uses the **open paw**: the
original cast mesh (`a938d479…`), whose claws are spread. Its skin weights and influences are identical to the
closed paw's; only 845 right-hand positions differ. A claw source therefore needs no derived mesh.

Consequence: at the switch between a haul row (closed paw) and a claw row (open paw) the right paw changes shape
at READY. Rows 30/31 (source 2) are on the closed paw too. M6 can add open-paw stand/walk at little cost: the
supplied idle and walk clips were captured on the open paw, so only the ADR 1199 proofs need re-running on it.
**Brendan (2026-10-07): the shape change at the switch is acceptable.** Rows 30/31 stay on the closed paw.

## Motion authoring plan

Every motion follows the established path:

1. **Pose recipe**, authored from published sources only (the open-paw body from `all-cast-v9.ugpal`, the rig and
   triangles of `topology-v5`, the tool-free stand key 8 of ADR 1199).
2. **Exact provers.** Contact crossing and patch, the below-surface envelope inside the target, world prisms with
   sole support, and limb self-clearance, all on the existing rational/interval machinery.
3. **Review packet** (`overview.png`, `hands.png`, `motion.png`, `README.md`). **Stop for Brendan.**
4. **Native capture** of the approved source.
5. **Integer rows**: role boxes derived as the published rows were (`compile_state_program` / profile-source gates),
   yaw 0, then exact quarter turns.
6. **Content successor**: a new tool-free source block (tool −1) after row 41, create-only, fully pinned.
7. **Pins and consumers** renewed; then the runtime changes in the impact map.

| # | Motion | Replaces | Reuses | Needed for |
|---|---|---|---|---|
| M1 | **Claw downward stroke** at the top face, both paws alternately: BRACE, CUT and FINISH (one program, ADR 1188) | rows 13/17/21/25 | open paw, stand key 8, ADR 1144's lean/drop recipe | the six L0/T0 cubes, the descent's cut rows, the Room's level-0 tops |
| M5 | **Paw handling** of the bearer | row 29 | the haul two-paw grip recipe (ADR 1144) | L0, T0 and treads |
| M4a | **Paw seating** of the T0 bearer from L0 (contact 128 u up) | row 16 family | M5's hold; the INSTALL target faces of `install-source-v4` | L0 → T0 |
| M6 | Tool-free source travel (approach/retreat, short step, canonical ground), open paw | rows 2–12 | empty walk (ADR 1199), rows 30/31 | Frontier and Room itineraries |
| M4b/c | Paw seating from the tread above; the T6 sill at 64 u | ADR 1209 step 4 (parked) | M4a | the descent |
| M7 | Tool-free stair gaits and handoffs | `stair-descent-v7`, `stair-motion-v15`, handoffs v1 | the accepted leg motion (feet unchanged), the tool-free upper body | the descent |
| M2, M3 | Claw high-wall and front strokes | rows 14/15 families | M1's solver | Room levels 0–1 |

**Order.** M1 → M5 + M4a → M6 (or a decision to travel on rows 30/31 with a switch at rest at each station) →
content 7 and the runtime changes above, which retire G11 → M7 + M4b/c (descent) → M2/M3 (Room).

**Known risk for M2.** The open paw's reach is the arm (182 + 128 u) plus 202 u from the wrist to the claw tip.
Standing upright, the right shoulder is 549 u up, so the claw tip reaches at most about 1,060 u above the stance.
The Room's level-1 cubes need an anchor above 1,024 u (ADR 1213), which leaves a thin band. If it does not fit,
Brendan will be asked to choose between a standing datum (a step or bench) and another station layout.

## Step 1 — the first claw stroke (M1): authored, and stopped for Brendan's station choice

The packet is `godot/data/underground/mole-worker/claw-work-v1/`:

| File | What it does |
|---|---|
| `claw_source.py` | The pinned tool-free open-paw closure. |
| `author_claw_stroke.py` | The pose recipe. |
| `probe_claw_stroke.py` | The bounded search. |
| `prove_claw_stroke.py` | The exact proofs. |
| `render_claw_stroke.py` | The review images. |
| `test_claw_stroke.py` | 10 tests. |

The review packet is `evidence/claw-stroke-review-v1/`.

**The stroke.** One program serves BRACE, CUT and FINISH (ADR 1188), authored for the Frontier's first episode:
cube 0 from station 4, which replaces row 25 at yaw 0. It is built as follows:

- the open paw and the tool-free stand key 8;
- ADR 1144's hip drop, sole planting and lean;
- the accepted fixed-length arm solve, aimed at the claw tip (vertex 2, the paw's most distal vertex);
- a 33-key rake loop, 80 u above the face (the fitting tap's raise) to 60 u below it (row 13's stroke depth);
- an entry of 31 keys with the arm solved on every key, and its exact reverse as the recovery.

**Exact proofs.** All run on the accepted Q24 interval machinery with the full native residual:

- the claw-tip face crossing, with its anchor and patch;
- the clipped below-face hull of every non-foot triangle, which must lie inside the target cube and touch it with
  the paw only;
- every triangle against the ground prisms, with sole support on every interval;
- right-arm self-clearance against the rest of the body.

**Finding: claw reach forces a station choice.** Today's cut stations stand 512 u behind the cube's near face
(1,536 u out, ADR 1188). From there the open paw reaches only 70–100 u into the cube, and the back of the paw dips
under the face behind the near edge, into retained earth.

- The best recipe at that station (candidate p) refuses: its paw's exact below-face hull reaches 26 u past the
  near face.
- The bounded search found **no** clear recipe at 1,536 (0 of 94 solvable).
- Moved in by **106 u**, the same pose clears every proof (candidate a), as do two variants (b, c).
- 106 is derived, not chosen: 512 minus the 406 u stance half-width of tool-free rows 30/31. It is the most
  ADR 1188's foot rule allows.

Options, put to Brendan in the packet's README:

1. **Recommended: move the six cut stations to 1,430 u** (a Frontier successor).
2. Keep 1,536 and only scratch the surface, about 12–24 u deep: a new constant, with thin margins.
3. Another design, such as a starter hole or a two-paw stroke.

Native capture, integer rows, the content successor and the runtime changes wait on that choice and on his review
of the stroke.

### Brendan's review of step 1 (2026-10-07)

Brendan reviewed candidate a's overview and motion images and decided:

1. **Move the six cut stations in by 106 u, to 1,430 u** (option 1). A create-only Frontier successor, as
   `qualified-landing-v4` was. The feet then stand at the dig area's edge.
2. **Two paws, alternately:** both paws scoop in turn, which is more mole-like than a one-paw rake.
3. **The paw changing shape** between hauling (closed) and digging (open) is acceptable.
4. **Claws for all earth work:** backfill, spoil-tip work, compaction, reclaim and tip closure too (DEC-052 and the
   SET-MOVE-ECON-001 note are extended).

**Order.** The Frontier successor is not published in the same run as the two-paw stroke. Its station rows name the
WORK profile and its header links the profile wire's content revision and source digest
(`entry_source_constants._frontier`), and the claw rows do not exist until the stroke is approved and the content
successor is published. Moving the stations while they still name pick row 25 would publish a Frontier no worker
can use. It follows the content successor: stations 4–9 at x = ±1,430, the same endpoints translated, and paths
re-proved through WorldRoutes and Locations.

## Step 1b — the two-paw alternating stroke at 1,430 u (authored; stopped for Brendan's review)

`claw-work-v1/author_claw_pair.py`, `probe_claw_pair.py`, `prove_claw_pair.py`, `render_claw_pair.py` and
`test_claw_pair.py` (7 tests). The review packet is `evidence/claw-pair-review-v1/`.

**The stroke.** It is step 1's recipe with both paws. Each paw follows the rake loop toward its own claw tip, the
left half a cycle behind the right. The clip starts where both claws are 10 u above the face. Each claw crosses the
face downward once per cycle. Two authored turns were needed, both rigid like ADR 1144's lean and both measured or
searched:

- **Squared shoulders.** The supplied idle stands with its shoulder line turned 26°. Without squaring, the left
  arm cannot reach the face.
- **Head lift.** At a 70° lean the forearms meet the cheeks. The head now turns up 60° about the neck joint.

**Result.** Candidates pa (paws at ±224) and pb (±192) clear every exact proof for both paws:

- each claw's contact and patch on the moved-in cube's top face;
- the below-face hull inside the cube, reached by paw triangles only;
- world prisms with sole support;
- self-clearance per arm (step 1's rule, per side) and arm against arm.

**Finding: the published stand's left paw rests in its thigh.** The accepted stand of rows 30/31 holds the left paw
slightly into the left thigh. Held still, 9 triangle pairs do not separate. The entry pulls the paw out over its
first 6 (pa) or 7 (pb) of 30 intervals. The prover reports those left-paw × left-thigh pairs apart, and requires
them to form an unbroken run from the ready key. Brendan is asked whether to accept that or to have a lift-off
path authored. **Recommended: pa.**

### Brendan's review of step 1b (2026-10-07)

1. **pa is approved:** paws at ±224, anchor −544, lean 70°, drop 96 u, claw tilt 60°, palm rolls 90°/90°, head
   lift 60°.
2. **The left paw in the thigh: "fix for dig and non-dig".** The fix goes into the source. The tool-free stand and
   walk (rows 30/31 and their haul joins, ADR 1199) must not hold a paw inside a thigh, whether the mole is
   digging, walking or hauling. The step-1b entry exception (`released_stand_contact`) is then removed, and the dig
   entry is re-proved from the corrected ready key with no exception.

The corrected stand, walk and joins are successors. The published v8/v9 images and content 5/6 stay unchanged until
the content successor that carries the claw rows also carries the corrected stand and walk.

**Order after the stand review:** paw handling and seating of the L0/T0 bearers, then native capture, then the
claw rows and the Frontier successor at 1,430 u, then the content successor, then the runtime switch.

## Step 1c — the stand and walk corrected at the source (authored; stopped for Brendan's review)

`godot/data/underground/mole-worker/stand-walk-v2/` holds four tools, `author_stand_walk_v2.py`,
`prove_stand_walk_v2.py`, `render_stand_walk_v2.py` and `test_stand_walk_v2.py` (5 tests), with the review packet in
`evidence/stand-walk-review-v2/`.

**What was wrong.** The published stand rests both paws into the thighs. The left is unseparated on 75 of 121
intervals. The right is unseparated on 41 with the open paw and 21 with the closed paw. In the walk the left paw
touches on 3 of 44 intervals.

**The correction.** Each upper arm gets one constant outward swing about its own joint around the body's forward
axis, on every key; every other local transform is supplied. Bisection gave the smallest whole-degree swings:
**11° left, 13° right**. One degree less leaves pairs unseparated. The wood and stone joins are re-authored by their
accepted recipe from the corrected ready key.

**Proofs (all clear, no exception):**

- support and floor for the stand, the walk (both bodies) and the four joins;
- per-arm separation everywhere;
- stock separation for the wood and stone joins;
- the approved pa re-proved from the corrected ready key with the stand-contact release switched off (0 released
  pairs), so step 1b's exception is no longer needed.

**Row consequence.** The all-yaw STAND/WALK body sweep grows from 651 to 712 u, still within ground row 12's 738.
It is carried only by the content successor.
