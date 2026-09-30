# 0208 — The tunnels are one network graph
Date: 2026-09-30 · Status: Accepted

Phase P2 ("The network graph") of the approved underground revamp
([`docs/design/underground_revamp.md`](../design/underground_revamp.md) §3, §4 and §8 P2; Brendan's
rulings in its §10). It builds on [0206](0206-the-underground-view-is-a-layer-cutaway.md) (the layer
cutaway) and [0207](0207-swept-bores-lantern-light-and-the-stoop.md) (swept bores, ramps, lanterns, the
stoop). Everything here is presentation: the demo's tunnels shape the demo cast's walks and nothing writes
into the simulation. MOVE-G01–G05 stay open; rooms and chambers as their own structures are P3's.

## Decision

### 1. One packed graph replaces eight tunnel slots

`demo/tunnel/underground_graph.gd` replaces `tunnel_network.gd` (moved, so its history follows). It keeps
the integer u lattice (1024 u a metre), (slot, generation) references and the prefix-sum dig timelines,
and stores four tables in packed columns sized once:

| Table | Cap | Columns |
|---|---:|---|
| Nodes | 96 | kind (MOUTH, JUNCTION, RAMP_END), x, z (u), level, up to four segments |
| Segments | 96 | kind (RAMP, BORE), level, node A, node B, piece, rank in it, spoil mouth; and every column a slot had (phase, generation, digger, route points, lengths, cost, quanta, timeline, bore class, braced, lit, closed range, extra spoil) |
| Mouths | 16 | node, generation, heap spot / radius / side, spoil heaped |
| Pieces | 96 | live, digger, spoil mouth, order laid |

- **A segment is what a slot was**, so the per-segment columns keep their old names and the jobs, hazards,
  crews, finds, queue, drawing and lanterns keep their per-slot shape, now over `MAX_SEGMENTS`. Rows are
  built lazily by everything that draws them.
- **A piece is one dig the player laid**: a chain of segments. From a new mouth it is a 4 m RAMP down to a
  RAMP_END foot, then BORE, then (to a new mouth) a 4 m RAMP up; exactly 8 m is two ramps sharing a foot.
  It is also cut at every crossing. A piece is refused under 8 m mouth to mouth or over 64 m.
- **The dig timeline is per segment.** A shaft only where a segment starts at a mouth (entry) or breaks out
  at one (exit), and every started metre between; segments are dug node A to node B, in order. A piece's
  cuts spoil at its **spoil mouth** (the mouth it starts at; for one started inside the network, the
  nearest mouth by the walk there), an exit shaft at its own mouth; each mouth's heap is one row.
- **Levels.** `level` is a column from day one (MOVE-REQ-013). Every piece is dug on level 1
  (`BUILDABLE_LEVEL`, floor −1.25 m). Level 2 is named (floor −5.25 m, DEC-040's candidate spacing, a demo
  value) but not dug until P6.
- **Splits.** A piece ending on a bore's side, or crossing one, splits it at the junction: the head keeps
  the slot and generation, the tail takes a new slot with a copy of the state. `last_splits` lists them and
  `tunnel_works.after_splits()` hands walkers, chambers (`repoint_split`), hazards (`split`) and finds to
  the half they lie on.
- **Life.** `stop_digging` pauses a segment if its piece has any tick dug or any segment open; otherwise the
  whole piece is dropped (segments freed and generations bumped; the nodes it made freed). A dropped branch
  leaves its junction on the host as a degree-2 node, which is harmless.

### 2. Connection rules and their demo values

The rules are checked in integers on the route polylines (the drawn curve only rounds corners). They are
named in `tunnel_rules.gd` and applied by `tunnel_plan.gd`. Each refusal has words (MOVE-REQ-018). The
network's refusals are `LINK_BASE + k` in a separate `LINK_REASONS`, so the verbatim rules tests' 18
`REASONS` stand.

| Rule | Value | Notes |
|---|---|---|
| A junction's distance from any other node | ≥ 1.5 m (`JUNCTION_GAP_U` 1536) | nodes are junctions, ramp feet and mouths |
| Meeting or crossing angle | ≥ 40° either way (`MEET_SIN_PERMILLE` 642, `MEET_COS_PERMILLE` 766) | at an existing junction, 40° from every branch already there |
| Pillar between voids that do not join | ≥ 1 m of earth (`PILLAR_U`), centreline to centreline plus both half-widths | checked every 0.25 m of the new route |
| Pillar exemption | within 3.2 m (`JOIN_ZONE_U`) of the node where two bores meet | also for the host's neighbours at that node |
| Bend | radius ≥ 1 m (`BEND_RADIUS_U`) | the fillet must fit in 45% of the shorter leg (`FILLET_SHARE_PERMILLE`); a leg ends at a ramp's foot or a crossing |
| A mouth's ramp | straight for 4 m at 1:2.5 | the first bend lies beyond it; a ramp cannot be joined |
| Junction degree | at most 4 | the hub has four openings |
| Host | open and quiet | not being dug, worked or closed |
| Capacity | 96 segments, 96 nodes, 16 mouths, 96 pieces (one per segment, so pieces never run out first) | "the tunnel network is full in this demo" |

`meets_squarely` and `branches_apart` compare unit directions `DIR_SCALE` (1024) long. 642‰ is
sin 40° = 0.6428 rounded **down**, so exactly 40° passes after the truncation of the unit vectors.

**Snapping.** A start or end within 1.5 m of a junction snaps to it (`SNAP_NODE_U`). One within 1.2 m of a
bore's side snaps to the nearest point on it (`SNAP_U`), where a junction will be cut. Mouths are not
snap targets: a new piece opens its own. The snap target glows brass.

### 3. The router

`graph_paths.gd` runs a Dijkstra (h = 0, the SET-MOVE-001 §4 reference solver) from every live mouth over
the segments each fit class can use: CLASS_ANY (every bore) and CLASS_WIDE (widened only). Loaded or
unloaded is decided by the walker's fit, `walker_class`.

- **Costs** are integers: a segment's planner cost (legs rounded up) × 1000 / its walking speed (a lit
  bore is quicker), so equal routes tie exactly.
- **Ties** go to fewer segments, then the lower slot into a node. The same graph always gives the same
  route.
- **Rebuilds** happen lazily, once per network revision per class, on a binary heap over packed columns
  (no allocation). `path_between` answers one-off node-to-node questions in a scratch row.

`tunnel_router.gd` keeps its lazy-surface shape. A tunnel edge between two mouths costs the table's walk
plus the queue wait at the first. A trip bound for a node **underground** (a dig's start, a job) reaches
its goal only by the network (`goal_node`). A tunnel edge is emitted as **one waypoint per segment**, with
leg code `slot × 2 + reversed`. Water crossings keep their own codes above every segment's, and
`MAX_CROSSING_PAIRS` stays 8.

The brain walks that leg list segment by segment. At each node it re-checks the next segment: usable,
topology unchanged, starting where it stands. If that fails it re-plans below to the stretch's end
(`path_between`); failing that it walks out to the cheaper mouth, and stranded, it waits and looks again.

Walkers keep their distance **across** nodes: `room_ahead` and `oncoming` also see a walker just past the
node ahead on another segment. Without this, a follower walked into a leader who had crossed a ramp's
foot.

**MOVE-TEST-09-style fixture.** `test_demo_graph.gd` checks the graph's shortest walks against a
Floyd–Warshall reference, including the deterministic ties.

### 4. The digging skill replaces the species lock

`dig_skills.gd`. Anybeast whose body fits a standard bore can dig: mice, moles and squirrels. The body
decides, not the species (LORE-P12, DEC-041's follow-up).

- **XP** follows GDD §5.3: 10 per work unit, a WU being 12.5 of the 30 Hz ticks, so a quantum's dig ticks
  × 10 × 60 / 750 (a loam metre is 90 XP).
- **Level** uses the forestry curve; the crew's rate is the pipeline × (1000 + 50 × the lead's level) /
  1000.
- **Moles start at level 3** (45000 XP), the design's working assumption (§10 ruling 5). Everyone else
  starts at 0 and learns at the face, as do crew members at their post who fit the bore.
- **Shown** in the party panel ("Digging 3 · XP 45000/80000", or "dig 3" in a list) and in the resident's
  action list (`resident_abilities.gd`).
- **Named gap:** §4.3's JobKind list has no excavation skill, so digging is a demo skill kept apart from
  any settlement Skills row.

The one rules-test line that changed is `REASONS[REFUSE_NOT_A_DIGGER]`: "nobody selected can dig --
select someone who fits a bore (moles dig best)".

### 5. The B Dig tool and the job list

`tunnel_control.gd`.

- **Opening it.** B, or T as an alias, or the panel's "Dig tunnel (B)", opens the tool. The HUD's Build
  key B is locked in the demo, so the demo takes it; the command strip's Build tooltip says so. U stays
  the view's own switch. The tool turns the underground view on and puts it back when it closes.
- **Laying.** Drag to lay and dig in one motion (Shift drops a bend), or click points and press
  Enter / right-click. Esc drops the piece laid and, with none, closes the tool. The tool **stays open**
  after a dig.
- **The ghost** (`tunnel_overlay.show_ghost`) is the piece's curved ribbon to the pointer (the same
  `BoreCurve` fillets), with a snap ring. It is chalk-cream while the piece may be dug and clay with the
  reason when it may not.
- **The cost readout** (`dig_readout.gd`) is two lines beside the pointer, for example "14.0 m · 14 quanta
  · 5.2 h (crew of 3)" over "28 U spoil · clay 4 m (slow), sand 2 m (weak: brace)".
  - Hours are demo-calendar hours: 75 of the dig's ticks, over the crew's skilled rate.
  - Brace cost ("brace as dug") is not in it yet.
- **The digger** is the first selected resident who can dig, else the village's most skilled free digger.
  If it is busy, the piece is **queued** in the job list (pieces in the order laid, `job_list_into`,
  `next_dig_for`), and the digger takes it up when its present piece opens.

### 6. Junction hubs

Where three or four open bores meet, `bore_mesh.build_hub` lathes the horseshoe into a round chamber. It
has 32 sectors, and its radius is 1.5 × the bore's floor half-width (`HUB_SCALE`). The design sketched
1.2; at 1.2 the four openings left only slivers of wall.

- **The bores and the hub cut each other in the shader.** `bore_earth.gdshader` discards inside a hub
  (CUSTOM0/1 carry each end's hub). `hub_earth.gdshader` discards its wall inside each opening
  (CUSTOM0..3). Both use the shared `bore_surface.gdshaderinc`.
- **The seams are clean.** The bore's jitter fades to the clean profile within 0.5–1.0 m of an underground
  end, so the section there is exact and no seam floats.
- **The cap** stamps the hub's disc. At a dig face every disc that reaches the face is cut at the face
  line, which fixes an older gap where a lattice disc opened the cap up to 0.5 m past the face.

### 7. What the rest of the demo reads now

- **Heaps and the queue** are per mouth row (`CastSpace.set_heap(m, …)`, `tunnel_queue.clear_mouth`).
- **Evacuation** plans in at the near mouth and out at the far one.
- **Irrigation and drainage** find a water-edge mouth connected through the paths.
- **Cellars** keep the `root_cellar:<slot>:<gen>` key; their door is the nearest mouth by the walk.
- **Chambers** refuse ramps.
- **Crews** follow a piece across its segments (`move_site`).
- **Say / say_about** notices are per piece.
- **Resume hooks** and spoil heaps and clearing are unchanged in shape.
- **Marks.** A brace frame at a segment's start inside the network (a ramp's foot, a junction) is left to
  the segment arriving there, so none is doubled. Every segment's selection line shares one prewarmed
  material.
- **Quanta.** A diagonal piece counts each segment's quanta on the stretch of route it was cut from, not
  on its lattice-rounded ends, so a 4096 u ramp never cuts a phantom fifth metre.

## Deviations from the design, and why

- **Segments run up to 64 m, not 32 m.** The existing 64 m route cap and its rules tests stand, and one
  piece is the unit the player lays.
- **Curves are the route's polyline with 0207's fillets**, not interior control points smoothed as
  Catmull-Rom. There is one centreline for everything, and the bend rule is checked on it.
- **Phase is per segment, not per quantum range.** A segment is short: pieces are cut at their ramp feet
  and crossings.
- **Junction hosts must be open.** The design allowed planned hosts too; splitting a plan's timeline was
  not worth it in P2.
- **No BEND or SOCKET nodes.** Bends live inside segments, and sockets are P3's.
- **The mouth table's "surface kind"** is only the tunnel ramp. Home doors and cellar hatches are P3's.
- **The chamber buttons stay in the tunnel panel** until P3's room tools replace them.

## Measured

- **First cold U toggle** over the acceptance T (main (−6, 5)→(−6, 21) and a branch off its bore at
  (−6, 13), braced and lit, a hub at the junction), at 1920×1080 on the Mac with its shader and pipeline
  caches cleared: the worst frame is 12.0 ms (the bar is 50 ms). 20 toggles after it: worst 10.0 ms, no
  stall banner, no clock diagnostic pause, no pipeline compiles.
- **Route planning**, 400 seeded trips over the demo world's 192 obstacle circles with eight open
  mouth-to-mouth tunnels (the old cap), three runs each (headless):
  - the graph router: p95 125.3–127.4 ms, median 9.1 ms;
  - the P1 router (00f5d9d): p95 126.3–127.5 ms, median 9.0 ms.

  The surface planner dominates both; the graph's tables add nothing measurable.
- **Suite** (`./tools/run_tests.sh`, after the review fixes): `6161 test(s), 546171 assertion(s), 0
  failure(s)`, from P1's 6096 tests.
- **Mutation testing** of the new logic, one mutant at a time: 54 mutants on the graph, paths, rules, plan,
  readout, bore sharing and router. 47 were killed once eight tests were added; 6 were argued equivalent,
  and one (dead code) was removed. A further 19 of 19 were killed on the review fixes.

## Review

An independent `code-reviewer` pass on the diff against 00f5d9d reported 4 CRITICAL, 6 HIGH, 5 MEDIUM and 2
LOW findings, most reproduced with headless probes. Each fix below has a test, and each fix's logic was
mutation-tested (19 of 19 mutants killed after three more tests).

| Finding | Fix |
|---|---|
| C1: a digger sent to a new dig underground could walk on through its own half-dug bore's undug far end | A resident in a segment still being dug may walk only to its node A; otherwise it takes the end whose walk plus the way on costs least (`_ends_open`, `_end_toward`). With no way on below, it walks out still bound for the node and goes in again at a mouth that leads there |
| C2: a trip abandoned underground left the resident holding in the bore for good | `_abandon_trip` walks out to the nearest mouth whenever it is underground |
| C3: a split's new half counted its cut stone into the stores again | `after_splits` re-baselines both halves' seen cuts and stone |
| C4: the hubs' change key allocated an Array per junction per frame | The key is folded from integers |
| H1: crossings were gathered in slot order, so a sound piece across two bores could be refused depending on the direction it was drawn | They are sorted into route order |
| H2: a split-off tail in a lower slot could become its piece's first segment | The first segment must also have no same-piece segment ending where it starts |
| H3: a resident standing past a node blocked a walker or not depending on how that segment was drawn | Someone standing still is always someone to pass |
| H4: the ghost's whole-piece check took 5.4 ms a pointer step | The pillar check samples only segments whose grown box holds each sample, and tracks its leg as it goes: 0.8 ms; a test holds it under 3 ms |
| H5: a tautological XP assertion | Replaced with the hand-worked 147 ticks and 117 XP |
| H6: the split hand-off was tested with hard-coded arguments | The test now drives `add_piece`, then `tunnel_works.after_splits`, asserting walkers, finds and stores |
| M1: stale names and comments (`MAX_TUNNELS`; "tunnel_network" in two places) | Removed or fixed. `is_digger` / `DIGGER_SPECIES` keep their names because the rules tests are kept verbatim; their docs now say "starts skilled" |
| M2: finds went to the wrong half when one piece split a segment twice | Each find goes to the half passing nearest it |
| M3: a piece cut off from every mouth could spoil at a planned piece's mouth, whose row a drop frees | The crow-flies fallback takes only opened mouths |
| M4: finished pieces keep their rows, so one-segment branches ran out of pieces first | `MAX_PIECES` = `MAX_SEGMENTS` |
| M5: two route copies were allocated per pointer move while snapping | The snap reads the route in place; a test checks it matches the graph's own functions |
| LOW: two-element array literals on each ghost redraw | Removed |
| LOW: `Array.hash()` state keys could collide | Left: they run only when a bore is rebuilt, and a collision would at worst skip one rebuild until the next change |

The review's probes also led to the hub floor's shading patches. A bore split and drawn before a branch
broke ground at its junction was not rebuilt when the hub appeared, so its floor showed through the hub's
in another dig day's shade. The overlay's mesh key now includes whether a hub stands at either end. The
hub's cut also lifts a bore floor jittered a few millimetres below the level's floor onto it.

## Consequences

- P3 builds rooms as their own table with sockets on this graph: a room's passage is a piece ending
  END_NODE at a socket node, and `goal_node` already routes a trip to a node underground.
- The job list is per digger and in laid order. P3/P4 can add priorities without changing its storage.
- A junction's host must be open. A branch can be planned into a bore still being dug only once it opens.

## Source

`docs/design/underground_revamp.md` §3 (spatial model, connection rules, routing), §4 (tools, ghost, cost
readout, who digs, job list), §8 P2 and §10 (Brendan's rulings: digging is a skill moles start with);
SET-MOVE-001 §4 (the Dijkstra reference); GDD §5.3 (XP per WU); LORE-P12 and DEC-041 (no species locks).
