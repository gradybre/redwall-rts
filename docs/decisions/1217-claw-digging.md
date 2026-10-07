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

### Brendan's review of step 1c (2026-10-07): **approved as is**

Brendan reviewed `overview.png`, `walk.png` and `paws.png` and approved the 11° (left) and 13° (right) swing. The
corrected stand, walk and joins are carried by the content successor with the claw rows. Next: paw handling and seating
of the L0/T0 bearers (step 2).

## Step 2 — paw handling and paw seating of the L0/T0 bearers (authored; stopped for Brendan's review)

The tools are in `claw-work-v1/`: `author_paw_seat.py`, `probe_paw_seat.py`, `prove_paw_seat.py`,
`render_paw_seat.py` and `test_paw_seat.py` (6 tests). The review packet is `evidence/paw-seat-review-v1/`.

**Two motions replace rows 29 and 16.** Both start from the approved corrected stand with step 1b's posture recipe.

- **Handling (seat).** Both paws come to rest on the delivered bearer's top, 1/512 u above it, the accepted seat
  gap.
- **Seating (tap).** Both paws press together by the accepted tap's height law, 80 u above the top down to 2 u
  below it. The right paw works at row 16's contact point (128, 128, −448), the left at its mirror. Both points lie
  on the L0 and T0 bearers' common section, so one program serves both installations.
- **Entry.** The body settles first, then the arms reach on the accepted handling entry's raised path (128 u, 30/46)
  with the elbows turned outward.

**Proofs.** Candidate a clears every exact proof, with no exception, on both the L0 and T0 install fixtures:

- world prisms with sole support, where a paw may press into the bearer's top by at most the tap's own 2 u;
- each paw's contact crossing at exactly (±128, 128, −448);
- self-clearance per arm and arm against arm.

Its recipe is lean 40°, drop 64 u, head lift 60°, palms rolled 90°.

## Brendan's decision (2026-10-07): the stairs are fitted by paw

The stairs below T0 keep the six timber treads and the T6 sill (ADR 1209 D1–D3). They are fitted by paw, using
step 2's paw seating motion, adapted per tread as the proofs require. ADR 1209's derived station, 310 u behind
T_{k−1}'s far edge, stays; T6's sill plane is y = 64. The pick tread tap stays parked. This follows the L0/T0 review.

### Brendan's review of step 2 (2026-10-07): **approved**

Brendan approved paw seating candidate a (overview, motion and hands) and chose to **keep handling and seating as two
separate motions**, as authored: the handling seat replaces row 29 and the seating tap replaces the INSTALL tap.
Next: per-tread paw seating (re-proved per tread), then native capture, then the claw rows with the Frontier
successor at 1,430 u, then the content successor carrying the corrected stand and walk, then the runtime switch.

## Step 2b — paw seating of the treads: stopped, the tread station needs Brendan's choice

`claw-work-v1/prove_tread_seat.py` re-authors the approved paw motion at ADR 1209's tread site and proves it with
step 2's provers, unchanged. The site is the station-local fixture with the station 310 u behind T_{k−1}'s far
edge. The workpiece is T_k's bearer across T_{k−1}'s forward edge, z ∈ [−310, −182]; its top is at y = 128, or 64
for the T6 sill. `author_paw_seat` gained a `site` parameter with the L0/T0 bearer as the default, and the L0/T0
candidate still rebuilds byte for byte.

**Finding: from this station the paws cannot seat a tread without pressing into the mole's own legs.**

- The bearer lies 182–310 u ahead of the station, at the knees. (ADR 1209's station range of 296–323 u comes from
  the ready body's front and the riser behind, so the station cannot move back.)
- **The approved recipe does not reach** (`STEP_LEG_REACH`): the work point is too close for the arm.
- **The nearest-first search** over lean and hip drop (head lift and palm rolls kept) found 9 reachable recipes.
  All 9 fail exact self-clearance at both the tread and the sill: paws and forearms against the thighs and shins
  (`evidence/tread-seat-probe-v1/`).
- **A wider float scan** (lean 0–50°, drop 0–96 u, paws at ±128…±224, rolls 0/90/270) gives a largest gap between
  pure-arm vertices and thigh/shin vertices of 11.4 u, across 219 reachable poses. No pose keeps the arms clear of
  the legs.
- The pick reached the bearer on a long handle; paws cannot.

**Options for Brendan:**

1. **Recommended: seat the tread side-on.** The mole stands on T_{k−1} turned a quarter, beside the bearer, so the
   bearer lies at the paws' natural reach (about 450 u), as the L0/T0 bearers do. This needs a derived station on
   the 512 u-deep tread with its own proofs: stance on the deck, riser clearance, the turn, and the half-turn and
   reposition ADR 1209 step 5 already plans to prove.
2. **Seat from T_k's own position.** Lay T_k's bearers first and fit them standing on the trench floor or a
   staging step. This is not supported: the floor is up to 896 u below and nothing stands there yet.
3. **Different staging of the bearer,** for example delivered further out on a temporary support. This needs new
   structure data, which nothing published provides.

L0/T0 are unaffected. The rest of ADR 1217's order (native capture, claw rows with the Frontier successor at
1,430 u, the content successor, the runtime switch) does not depend on the treads.

## Step 3 — native capture

### 3a. The haul images with the corrected stand, walk and joins

`stand-walk-v2/native_haul_v10.py` compiles, replays and verifies the successors of the haul images. It reuses the
accepted v8/v9 compiler, runner, capture script and verifier unchanged; only the clip readers are pointed at the
approved step-1c clips, which are pinned by the step-1c record. The published v8/v9 images are untouched.

| Image | Successor of | Clips changed | Content | Native rows | Mismatches | Max vertex error (u) |
|---|---|---|---|---:|---:|---|
| wood v10 (source 2) | v8 | stand, walk, enter_haul, leave_haul | `fa8dc668…` (993,008 B) | 9,780 | 0 | 0.0003 body, 0.0010 wood |
| stone v10 (source 3) | v9 | enter_haul_stone, leave_haul_stone | `1756932c…` (791,844 B) | 7,794 | 0 | 0.0003 body, 0.0010 stone |

Both replays ran on the real non-headless Metal/Forward+ backend: 0 failures, 0 analyzer warnings, and 0
diagnostics. The stone image's cross-image join (its `enter_haul_stone` key 0 equals wood v10's `stand` key 8,
body and World coefficients) holds in all 3 views. Evidence is in `stand-walk-v2/evidence/native-haul-v10-*`.

### 3b. The claw/paw image (the new source)

`claw-work-v1/native_claw.py` and `claw-work-v1/native/capture_claw_native.gd` produce and check the image. The
capture script is the accepted v8 one without the pick-paw derivative or a second part.

**Image.**

- Content `6be24202…`, with one part: the original imported body (the open paw, `a938d479…`, matched natively).
- 11 approved clips, 421 keys:
  - the corrected stand and walk;
  - pa's dig entry, stroke and recovery, from the corrected ready key;
  - the paw handling seat (entry, work, recovery);
  - the paw seating tap (entry, work, recovery).

**Native replay.**

- 4,953 rows on Metal/Forward+: 0 failures, 0 analyzer warnings, 0 coefficient mismatches.
- Maximum vertex error 0.0003 u.
- 36 exact joins: ready to each entry, entry to work, work to recovery, recovery back to ready, each recovery the
  exact reverse of its entry.
- The minimum floor gap is 0.0014 u for every vertex except the paws while digging.

Evidence is in `claw-work-v1/evidence/native-claw-v1/`.

## Step 4 — claw rows, content 7 and the Frontier successor: integration plan (not started)

The published runtime is bound to the pick rows by row ID and source digest, not only by data:

- `work-approach-v1/source_program.gd`: the source-work protocol accepts profiles 2–25 only, checks source 0's
  actor digest, and holds a fixed clip clock.
- `work-step-v1/source_program.gd`: the short-step protocol.
- `qualified-assembly-v1/source_program.gd` and `handling_clock.gd`: `PROFILE = 29`, `SOURCE = 1`, the handling
  actor digest, and the tool box.
- `underground_session.gd`: the source count and the per-source actor digests.
- `underground_connector_contacts.gd`: the installation source must name the tool.
- `mole_profile_catalog.gd`, `mole_presentation.gd`, `mole_profile_driver.gd`: the source-to-row map.
- Routes, WorldRoutes, the room itinerary and planner, the foreman and the installer, which take row IDs from the
  Frontier and `Assembly.PROFILE`.

So claw rows cannot be published as data alone. The plan, in order:

1. **Content 7** = content 6 plus:
   - source 4, the claw/paw image `6be24202…`;
   - sources 2 and 3 swapped to wood v10 and stone v10 (the corrected stand and walk);
   - rows 30/31 re-derived from the corrected clips (body sweep 651 → 712 u);
   - claw rows appended after row 41: dig WORK rows at the 4 yaws, a seating WORK row, and a paw handling row.

   Rows 0–29 stay published and dormant, so no published ID moves. Every box is derived by the accepted
   `compile_state_program` / profile-source-gate derivations; nothing is chosen by hand.
2. **Source programs** for the claw source, as successors of `work-approach-v1` and `qualified-assembly-v1`:
   - the dig and seating protocol (entry 31, work 33, recovery 31 keys);
   - the paw handling clock (entry 31, seat 2, recovery 31).

   Routes dispatches to these by row source instead of by the hard-coded ranges.
3. **Travel to a claw station** uses tool-free rows 30/31 (automatic), then the switch at rest (ADR 1210) into the
   claw WORK row. No tool-free source travel family is needed for the first entry.
4. **Frontier successor at 1,430 u**: create-only, like `qualified-landing-v4`.
   - Stations 4–9 move to x = ±1,430 and name the claw dig rows.
   - The INSTALL stations name the claw seating row, and handling names the paw handling row.
   - Endpoint travel names row 31.
   - The bundle links content 7's wire digest.
5. **Runtime switch**:
   - crew selection without a tool;
   - BUILD Jobs with `GATE_NOT_REQUIRED`;
   - the hauler without unequip and re-equip;
   - connector contacts accepting a tool-free installation source;
   - per-source presentation for source 4;
   - G11 retired.

   Then the hauled complete-prefix test is re-run on the claw rows with exact ledgers, and pins and the memory
   census are renewed.

**Coordination.** Items 2–5 edit `underground_routes.gd` (admission and source dispatch), the entry
foreman/installer/hauler and the room itinerary and planner. Other workers are changing these right now: G5 Routes
admission and occupancy, G10 entry persistence, and the room planner. This work starts after those land, from a
fresh rebase.

## Brendan's decision (2026-10-07): treads are fitted side-on

Brendan chose option 1 of step 2b. On the tread above, the mole turns a quarter turn and stands beside the bearer,
so the bearer sits at the paws' natural reach, as at L0/T0. Each tread needs a new side-on station with footing,
riser-clearance and turn proofs, beside ADR 1209 step 5's reposition. It is queued after the runtime switch and
stops for review when the side-on seating pose is ready.

## Step 4a — content 7 published (data only, not active)

**Rows.** `claw-work-v1/derive_claw_rows.py` derives the claw/paw rows:

- It applies the accepted cardinal derivation to the approved clips: outward Q24 vertex hulls with the local, native
  World and cardinal residual (`common_padding`), the clipped floor and plane partitions, the accepted foot
  projection, and the exact quarter turns.
- The body is split by the real skin weights into the paws and the rest; the paws take the pick's role in the stroke.
- Contacts are each paw's exact downward crossing, per heading. CONTACT_POINT is the right paw's anchor;
  CONTACT_PATCH is the union of both paws' patches.
- Output is `evidence/claw-rows-v1/rows.json` (`540bb052…`): 4 dig rows and 4 seating-tap rows (11 boxes each), and
  1 paw handling row (7 boxes).
- As a check, the derived ready floor box equals published row 13's.

**Publication.** `publish_claw_runtime.py` writes `qualified-claw-v8/` (create-only), content revision 7. Wire
`8b79294f…`: 51 rows, 472 boxes, 5 sources.

- Sources 0/1 are unchanged; sources 2 and 3 are the v10 haul images; source 4 is the claw/paw image.
- Rows 0–41 keep every descriptor word; the pick rows 0–29 are dormant.
- Rows 30/31 are re-derived from the corrected stand and walk (body sweep 712 u).
- Rows 42–50 are the claw block: dig 42/45/47/49, seating tap 43/46/48/50, paw handling 44.
- The ground paces and the motion bank are rebound to the new wire and revision only.

**Tests.** `godot/test/test_mole_claw_profiles.gd` (5 tests, 796 assertions) loads content 7 through the actual
Profiles loader and validator. `test_publish_claw_runtime.py` (4 tests) rebuilds it byte for byte.

**Not active yet.** The catalog, Session and consumers still load content 6. Activation needs step 5's source
programs and Routes dispatch.

## Step 4b — the Frontier successor at 1,430 u cannot be data-only against content 7 (stopped for a choice)

The current owners bind a first-entry bundle to **one** profile source and need a **separate** set-down source:

- `underground_entry_frontier.gd`:
  - `_station_profile_refusal`: every station profile must be on the Frontier source (header word 64).
  - `_travel_refusal`: every endpoint travel profile must be a WALK/CARRY/CLIMB row on that same source.
  - `_sources_refusal`: the Frontier source must equal the Catalog's `header[10]`.
- `underground_connector_workpieces.gd` `_distinct_program_leaf` (and `entry_source_constants.py`
  `WORKPIECES_NOT_DISTINCT`): the set-down program's source must differ from the Frontier's. In content 6 these are
  the pick (source 0: stations 16/17/25, travel 2/6/12) and assembly handling (source 1: row 29).

Content 7 puts dig, seating tap and paw handling all on source 4, and has no source-4 travel row. Rows 30/31 are
on source 2. So a Frontier naming claw rows 43/45/49 with travel row 31 is refused by `_travel_refusal`, and a
workpieces file naming row 44 is refused as not distinct. The plan's "endpoint travel names row 31" (item 4 above)
was wrong. Catalog pace rows are unaffected: all fifteen are ground caps (family -1), which may name any source.

Options:

1. **Recommended — a content successor that mirrors the pick/assembly split.**
   - Source 4 becomes a claw image with stand, walk, dig and tap clips; source 5 is a paw-handling image with the
     seat clips. Both come from the approved clips, with a new native capture of two images.
   - Source-4 tool-free STAND/WALK rows are derived from the claw image's own stand and walk clips, with ground
     pace caps.
   - The Frontier binds source 4: dig and tap stations, and travel on the source-4 walk row. The workpieces file
     binds source 5 (paw handling).
   - Every runtime invariant stays. Item 5 is left with only the tool-related changes.
   - Content 7 (5a44207f) is local and has no consumer, so it can be replaced rather than succeeded. That is the
     coordinator's call; otherwise this is content 8.
2. **Relax the owners in item 5:**
   - Allow a Frontier travel profile from another source of the same content, as ADR 1200 did for ground caps.
   - Drop the distinct set-down source rule.

   There is less data churn, but this weakens two deliberate invariants (ADR 1190), and it must wait for G10.

Until one is chosen, no Frontier successor is published.

### Decision (coordinator, engineering, 2026-10-07): option 1, split the sources as content 8

- Content 7 (`qualified-claw-v8`, f46407f2) is pushed, so it stays published and unused.
- The split is published as **content 8**, a create-only successor:
  - **Source 4:** a claw image with the stand, walk, dig and tap clips. Its tool-free STAND/WALK rows are derived
    from its own stand and walk clips and get ground pace caps.
  - **Source 5:** a paw-handling image with the seat clips.
  - Both images come from one new two-image native capture of the already-approved clips. Nothing is re-authored.
- **Frontier successor at ±1,430:** binds source 4. Dig and tap stations use source-4 rows, and travel uses source
  4's walk row.
- **Workpieces:** bind source 5, the paw handling row.
- **Unchanged:**
  - every ADR 1190 rule (single Frontier source, distinct set-down program);
  - items 2, 3 and 5, which still wait for G10.

## Step 4c — content 8: the split claw and paw-handling sources

This carries out the step 4b decision. Content 7 stays published and unused.

### 4c.1 Two-image native capture (done)

`claw-work-v1/native_claw_split.py` succeeds `native_claw.py`. It reuses the accepted step-3b compiler, capture
script, runner steps and verifier equations unchanged. As `native_haul_v10.py` did, it only selects each image's
clips and content name. Nothing is re-authored: every clip is step 3b's, pinned by its approval record.

| Image | Source | Clips (keys) | Content | Native rows | Mismatches | Joins | Max vertex error (u) |
|---|---|---|---|---:|---:|---:|---|
| claw | 4 | stand 122, walk 45, dig entry/stroke/recovery 31/33/31, tap entry/work/recovery 31/33/31 | `2b58852e…` (413,340 B) | 4,212 | 0 | 24 | 0.0003 |
| paw handling | 5 | seat entry/work/recovery 31/2/31 | `cbe80b76…` (74,392 B) | 741 | 0 | 12 | 0.0002 |

- Both replays ran on the real non-headless Metal/Forward+ backend, with 0 failures, 0 analyzer warnings and 0
  diagnostics.
- The paw image has no stand. Its ready joins (entry start and recovery end) are checked across images against the
  claw capture's stand key 8, as stone v9 checked its stand join against wood v8. All 36 joins of step 3b hold.
- Captures: claw `19b93668…`, paw `65564db1…`.
- The minimum floor gap is 0.0014 u, with the paws excepted only while digging.

Evidence is in `claw-work-v1/evidence/native-claw-split-v1/{claw,paw}/`. The palettes were staged from the frozen
`redwall-rts-codex-ug-space` worktree (ADR 1192 §6), checked against their pins (`5b368eb3…`, `08de5453…`,
`de8c3b04…`), and removed after the run.

### 4c.2 Source-4 STAND/WALK rows (done)

`claw-work-v1/derive_claw_stand_rows.py` derives them as rows 30/31 were derived (ADR 1199,
`compile_state_program.carry_bounds` over every stand and walk key, then `prove_empty_walk.ground_roles`). The
only change is the body. These rows use the claw image's own body, the open paw, while rows 30/31 use the closed
paw. The clips are checked against the claw image's compilation record. The output is
`evidence/claw-split-rows-v1/stand-walk.json`.

**Result:** the boxes are the same as corrected rows 30/31: body `[-712,0,-712,712,930,712]`, floor
`[-402,-1,-402,402,0,402]` and stance `[-406,-1,-406,406,0,406]`. The open paw changes no outward-rounded bound.
`test_derive_claw_stand_rows.py` holds 3 tests, including a rebuild from the staged inputs.

The dig, tap and handling boxes are content 7's `claw-rows-v1/rows.json`. Those rows were derived from the same
pinned clips on the same body, so splitting the image into two changes none of them.

### 4c.3 Content 8 published (data only, not active)

`publish_claw_split_runtime.py` writes `mole-worker/qualified-claw-split-v9/` (create-only), content revision 8.

- **Wire** `2b79e39b…`: 18,684 B, 52 rows, 477 boxes, 6 sources. The paired bank is 37,352 B, 540 B more than
  content 7's.
- **Sources:** 0–3 are content 7's. Source 4 is the claw image `2b58852e…` and source 5 the paw-handling image
  `cbe80b76…`.
- **Rows 0–41** keep content 7's words and boxes.
- **Source 4's block:**
  - 42 is the tool-free WALK;
  - 43/45/47/49 dig at yaws 0, 16384, 32768 and 49152;
  - 44/46/48/50 tap at the same yaws.
- **Source 5:** 51 is paw handling.
- The dig, tap and handling rows are content 7's words and boxes, re-homed. The publisher re-checks them against
  `claw-rows-v1/rows.json`.
- **Ground paces** `fb749b77…`: content 7's fifteen ground caps plus row 42's, at revision 8. They reuse the adopted
  Movement cap; no constant is new.
- **Motion bank** `19b2b71c…`: rebound to revision 8 and the new wire only.

**Finding: source 4 can carry a WALK, but not a STAND.** Rows 30/31 are automatic. Profiles' key excludes the
source, so an automatic source-4 STAND or WALK would have exactly row 30's or 31's key, and the loader refuses that
pair as `PROFILE_AMBIGUOUS_KEY`. Profiles admits a non-automatic policy only on WALK rows. The only one a YAW_ALL
WALK may carry is `POLICY_CANONICAL_GROUND`, the policy of row 12, the pick's Frontier travel row.

- Row 42 is therefore row 31's words with source 4 and that policy: the tool-free counterpart of row 12, which
  is the role the Frontier's endpoint travel needs.
- The derived STAND row is not published. STAND admits only the automatic policy, so it cannot be published
  without the ambiguity. The derivation record keeps it.
- At activation (step 5), row 42 is source-clocked canonical-ground travel, like row 12, so the source-program
  dispatch for source 4 must accept it. This joins items 2 and 3.

**Ground-pace binding.** The ground catalog now binds source 4, the Frontier source, instead of source 0. A
first-entry bundle can then carry it unchanged beside a structure that binds source 4:
`entry_source_constants._linked` requires the two headers to agree. The catalog holds only ground caps, which may
name a row of any source (ADR 1200), so the binding grants no travel. No runtime path loads this file.

**Tests.**

- `godot/test/test_mole_claw_split_profiles.gd`: 6 tests, 847 assertions, through the actual loader and validator.
  One test edits row 42 back to the automatic policy and gets `PROFILE_AMBIGUOUS_KEY`.
- `test_publish_claw_split_runtime.py`: 6 tests, including a byte-for-byte rebuild.
- The renewed consumer pins of `qualified-claw-split-v9` check clean, and the registry audit passes.

**Not active.** The catalog, Session and consumers still load content 6.

### 4c.4 The Frontier successor at ±1,430: stopped for a choice

The decision puts every endpoint's travel on source 4's WALK (row 42). Rows 42–50 pass the Frontier owner's own
checks: source, mode, policy, heading and certificate. So a Frontier built that way would load, and the
Frontier and structure suites would pass. It would still reopen a blocker that Brendan has already resolved.

**Finding: row 42 at the L0 contact contains the pending T0 bearer (ADR 1202 blocker 3).**

- Endpoint 3 is the L0 WORK contact, the station of T0 handling and installation.
- Under ADR 1202's split landing it travels on the narrow READY_FORWARD row 2.
- Row 42's all-yaw body `[-712,0,-712,712,930,712]`, placed at the contact (0, 0, −1536), reaches z = −2248. It
  therefore contains the pending T0 prism `[-256,0,-2048,256,128,-1920]`.
- T0 START would refuse `LOCATION_ENVELOPE_BLOCKED`. The endpoint certificate exempts only the narrow H envelope
  (the union of rows 2/6/16/29).
- No published tool-free row is narrow enough to replace row 2. Rows 30/31/42 all have the 712 u sweep. Even an
  exact-heading walk hull reaches 521 u forward (z = −2057), which is inside the prism's z range.

In content 6, endpoints 0 and 2 (H and R) and the arrival 13 also used the narrow source rows 2 and 6. Arrival 13
clears the bearer with row 42. Endpoints 0 and 2 were not checked here.

**Activation notes (not blocking publication):**

- The actual Workpieces owner sends an ASSEMBLY_PALM set-down row to `qualified-assembly-v1/source_program.gd`,
  which accepts row 29 only. Workpieces naming row 51 is therefore refused by the owner until the paw-handling
  source program (step-4 item 2) lands. The Python formatter accepts it.
- `entry_source_constants._linked` compares the structure's source digest with profile source 0. A source-4
  structure needs that check read through the structure's own source word, as Godot's `SourceFacts` already does.

**Options:**

1. **Recommended: author narrow tool-free source-4 approach and retreat rows** (an M6 subset). They are READY_FORWARD
   into the claw ready key and READY_BACKWARD out of it, derived as rows 2/6 were, and go through the usual review.
   A claw successor of the endpoint certificate goes with them. The Frontier then gives the narrow endpoints those
   rows and every other endpoint row 42.
2. **Publish now with every endpoint on row 42, as decided.** The T0 installation then waits for a re-layout (ADR
   1202 option 3).
3. **Re-lay the T0 station or bearer** clear of the 712 u sweep now (ADR 1202 option 3). Then publish with row 42
   everywhere.

Until this is chosen, no Frontier, structure or workpieces successor is published. Content 8 itself does not
depend on the choice.

### Brendan's decision on step 4c.4 (2026-10-07): option 1, narrow tool-free approach and retreat rows

Brendan chose **option 1**. These are the decision's parts:

- Narrow tool-free approach and retreat rows are authored on source 4 for the endpoints that need them. One is
  the L0 contact (endpoint 3). H (endpoint 0) and R (endpoint 2), which used the narrow rows in content 6, are
  checked as well.
- They are derived from the claw image's own stand and walk clips, the way the pick-era rows 2–9 were. They go
  through the exact provers and stop with a review packet before anything is published.
- A claw version of the endpoint certificate goes with them.
- Every other endpoint uses row 42.
- After approval, content 9 is published with the Frontier/bundle successor at ±1,430. It binds source 4, and its
  workpieces file binds source 5.
- The runtime's active content is not switched.

## Step 4d — narrow claw approach and retreat: derived and proved, stopped for review

- **Tools.** `claw-work-v1/author_claw_approach.py`, `render_claw_approach.py`, `measure_approach_gaps.py` (a
  review aid) and `test_claw_approach.py` (5 tests).
- **Record and packet.** The record is `evidence/claw-approach-v1/approach.json`. The review packet is
  `evidence/claw-approach-review-v1/`: `README.md`, `overview.png`, `motion.png`, `paws.png` and `fade-gaps.json`.

**Recipe.** This is the pick's approach recipe (`work-approach-v1/compile_work_approach.py`) on the claw image's
own stand and walk. Nothing is authored.

- The walk plays at a fixed body heading while the root moves along the station line. The driver's READY fade
  joins it to stand key 8. The retreat plays the same poses in reverse.
- The boxes are the outward hull of every walk key plus ready key 8, turned exactly to the four headings: 8 rows,
  READY_FORWARD and READY_BACKWARD.
- BODY is `[-485,0,-521,479,930,412]`, floor `[-271,-1,-274,284,0,249]` and stance `[-274,-1,-274,299,0,249]`.
- This is 40 u wider than pick row 2 on −X and 66 u on +Z, so H's surveyed air must cover it at activation.

**Proofs.** They run over the 45 fade simplices the rows use, selected as the pick's `selected_handoffs` selects
them, with `prove_state_handoffs.separated_simplex`.

- **Pending bearers: clear.** The L0 bearer at H and the T0 bearer at the L0 contact are
  `qualified-assembly-v1/source_program.gd::bearer_refusal`'s prisms. Each is checked with the root anywhere from 0
  to 4,096 u behind the station.
- **Self-clearance: not clear.** 404 pairs are unresolved, all of them the right arm against the rest, in the READY
  fade from walk keys 28–37. The sampled float gap falls to 0.009 u: the right paw grazes the right thigh as the
  late stride blends back to ready.
  - Every other handoff is clear.
  - The idle-to-ready fades belong to a STAND row, which source 4 does not carry. Those were not counted.

**Endpoints.** Row 42's 712 u sweep contains the pending bearer 384 u ahead at both the L0 contact (endpoint 3) and
H (endpoint 0). R (endpoint 2) is install row 0's retreat, and leaving H on row 42 would turn into the L0 bearer.
The proposal replaces like for like:

- content 6's row 2 (endpoints 0, 1 and 3) becomes the narrow forward row;
- row 6 (endpoints 2 and 13) becomes the narrow backward row;
- row 12 (endpoints 4–12) becomes row 42.

**Options for Brendan** (the packet's README):

1. **Recommended: gate the fade by walk phase.** The source clock fades to ready only from walk intervals 0–27 or
   38–43, which are proved clear. Arriving in keys 28–37, the walk plays on to key 38 first, at most 10 key
   intervals. No geometry changes.
2. **Author a fade path** that carries the right arm out, like step 1c's swing. This is new motion and another
   review.

Content 9, the claw endpoint certificate and the Frontier/bundle successor wait for this review.

### Brendan's review of step 4d (2026-10-07): fade only from clear frames

Brendan reviewed `overview.png`, `motion.png` and `paws.png` and decided:

1. **Fade only from clear frames.** The fade to ready may start only from walk keys 0–27 or 38–43. A mole that
   arrives in keys 28–37 walks on to key 38 first, which takes at most 10 keys. The rule is published with the
   rows as data that the source program reads.
2. **The narrow rows are accepted as derived.**
3. **The like-for-like endpoint mapping is accepted:**
   - row 2 becomes the narrow approach for endpoints 0, 1 and 3;
   - row 6 becomes the narrow retreat for endpoints 2 and 13;
   - row 12 becomes row 42 for endpoints 4–12.

   M (endpoint 1) and the T0 arrival (endpoint 13) are to be verified.

Next: content 9, the claw endpoint certificate, and the Frontier/bundle successor at ±1,430.

## Step 4e — content 9, the claw endpoint certificate and the Frontier successor

### 4e.1 Content 9 published (data only, not active)

`publish_claw_approach_runtime.py` writes `mole-worker/qualified-claw-approach-v10/` (create-only), content revision
9.

- **Wire** `c8e34f12…`: 60 rows, 517 boxes, content 8's 6 sources.
- **Rows:**
  - 0–42 are content 8's;
  - 43–46 are the narrow approach (READY_FORWARD) at yaws 0, 16384, 32768 and 49152;
  - 47–50 are the narrow retreat (READY_BACKWARD) at the same yaws;
  - 51–59 are content 8's rows 43–51: dig 51/53/55/57, tap 52/54/56/58, paw handling 59 on source 5.
- **Why the claw rows move.** Profiles sorts rows by key within each source, so source 4's WALK rows must precede
  its WORK rows. Content 8 has no consumer, and the moved rows keep their words and boxes.
- **Narrow rows.** Their words are row 42's with YAW_EXACT, the heading and the policy (pick rows 2–9 without the
  tool). Their boxes are `claw-approach-v1/approach.json`'s, copied as derived.
- **Ground paces** `7bcaec94…`: 24 ground caps, adding one per narrow row as pick rows 2–9 have. No constant is new.
- **Fade window.** The accessor publishes it for the source program to read, along with the row IDs:
  `CLAW_FADE_BLOCKED_FIRST`/`LAST` = 28/37 and `CLAW_FADE_RESUME_KEY` = 38. The publisher refuses unless every
  unresolved self-clearance pair in the derivation record lies in a fade from those keys and both bearers are clear.
- **Tests.**
  - `godot/test/test_mole_claw_approach_profiles.gd`: 4 tests, 1,011 assertions, through the actual loader.
  - `test_publish_claw_approach_runtime.py`: 5 tests.
