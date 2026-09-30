# 0211 — The construction theatre, hazard warnings, surface signs and large beds
Date: 2026-09-30 · Status: Accepted

Phase P5 ("Construction theatre and hazard visuals") of the approved underground revamp
([`docs/design/underground_revamp.md`](../design/underground_revamp.md) §2 "Digging" and "Living", §6 "Hazards made
visible", §8 P5; Brendan's rulings in its §10), with two carry-overs from P4 ([0210](0210-fit-out-and-living.md)):
large beds for the big residents, and the HUD's "Beds: Unavailable". It builds on 0207 (swept bores, the pooled
lights, the stoop), 0208 (the network graph and the spoil ledger), 0209 (rooms) and 0210 (fixtures, the night, the
chimney smoke). Everything here is presentation: nothing changes a dig's rate, a cost, the spoil ledger, a hazard's
clock or anything the simulation owns. MOVE-G01–G05 stay open.

New files: `godot/demo/tunnel/` `warren_particles.gd` (the particle budget), `dig_theatre.gd` (the face),
`warren_kit.gd` (hand lantern, basket), `spoil_haul.gd` and `haul_view.gd` (baskets), `hazard_look.gd` and
`hazard_view.gd` (warnings), `warren_signs.gd` (seams and vents); `godot/demo/ui/demo_beds_label.gd`. Tests:
`godot/test/test_demo_theatre.gd`, `godot/test/test_demo_warnings.gd`, and additions to the fit-out and night suites.

## Decision

### 1. The dig face

**Shape** (`bore_mesh.gd add_face`). The face is no longer a flat cap: three rings step into the earth ahead of the
last full ring, each smaller and further in, to a middle vertex FACE_DEPTH_M (0.22 m) deep -- a concave bowl -- with
each ring's vertices jittered by up to 3.5 cm, repeatably by position, so it reads as hacked, not turned. Its
triangles are wound by their summed vertex normals, so the jitter never flips one. The bore's vertex channel COLOR.a
(1 − fresh-cut) is 0 at the middle and 1 − FACE_RIM_MARK (0.55) at the rim, and the earth shader
(`bore_surface.gdshaderinc` THE FACE) draws fresh-cut earth darker and damper, with loose crumbs on the floor.

**The theatre** (`dig_theatre.gd`). A face is a segment being dug whose digger stands in it underground. Up to
FACE_SLOTS (3) faces at once each get: the Foremole's **hand lantern** (procedural, `warren_kit.gd`: an iron frame,
emissive glass), set down on the floor 0.55 m behind the digger and 0.28 m to its left, facing the face; one of the
**pooled lights** over it (`tunnel_lanterns.gd set_face_spot`, a row of its own so a small move neither re-assigns nor
re-blooms it); a **burst of clods** from the face with every new quantum cut (`cut_count` rising); and the tunnel
overlay's mound, while it shows, **throwing clods** from the particle pool. A room's body is its own face (the
digger's position, the door's way back). A fourth dig at once shows no theatre: the budget below.

### 2. Baskets: the heap grows as loads are tipped, and the ledger is untouched

The design: "Behind the face a helper fills a basket and carries it out stooped. The heap at the mouth grows when the
load is dumped." The spoil ledger (0208: `mouth_spoil`, posted at the cut and read by the farm's spoil books, Raise,
Bank and the clearers) is **not** moved to the tip. Instead `spoil_haul.gd` **locates** it: per mouth, what is
*tipped* on the heap and what is *carried* in baskets; the rest is *piled* behind the face. So

> pile + carried + tipped = the ledger, every frame, each at least 0

(the conservation tests check it every step of a crew's round, through joins, fills, tips, leaving, a hauler called
away, the last basket and a mouth row laid again). With nobody hauling for a mouth, its heap is drawn at the whole
ledger, as before P5 (a solo mole's dig, a room's, a clearing). The overlay draws the heap at **tipped**; the farm's
spoil books take only what is tipped (`farm_tunnels.gd spoil_left`), so nothing can be taken from a basket still on
its way.

A **crew member** at its post (`tunnel_crew_task.gd`) joins the haul for its dig's spoil mouth. When at least a
quantum's worth (2 U) lies behind the face and nobody else of that mouth is filling, it **fills** (FILL_S 1.4 s of demo
time, the hand clip; the basket stands before it, its spoil rising), takes the whole pile, and **carries it out**
(`resident_brain.gd task_haul_out`: the carry clip, loaded, through the network to the mouth and on to a spot by the
heap -- on its side away from the ramp, else the other, else straight out, the first clear of obstacles), where it
**tips** it (TIP_S 0.9 s, the `pull_radish` heave; the basket leans toward the heap and empties) with a dust puff, and
walks back down. The heap grows by that load. When the Foremole's work ends, a member with spoil still behind the face
takes one last basket out and its place ends at the heap. While it hauls -- filling, carrying, tipping and walking
back down to its place -- a member **still counts as at its post** (`set_present`), so the crew's dig rate, its rock
breaking and its XP are unchanged: the theatre shows the work the rate already charges. A hauler whose mouth row is
freed on the way stops hauling and goes back to its post (the basket's spoil went with the row).

### 3. Drying walls

The design's "fresh walls stay dark and damp, then dry to a paler colour over a game day". The bores already carried
a dig day per 0.25 m step (UV2.x, 0207); the shader's `dry_days` is **1.0 game day** (60 s at 1x on the demo
calendar). Added: a **widening** re-cuts the steps it passes (their day becomes the widening's), a **junction hub**
keeps the day it first broke ground when a branch rebuilds it, and **rooms** dry too -- each growth stage of a room's
dig remembers its day, every point of the shell takes the day of the stage that first took it in (so a room dries
from its door outward as it was dug, and a later rebuild keeps its walls' days), and while a room is dug its newest
stage's walls are fresh-cut, the room's own face.

### 4. Braces, lanterns and fixtures go up one at a time

**Braces** (`tunnel_marks.gd` PUT UP ONE AT A TIME): while a paid BRACE job works, a frame stands for each metre the
work has reached; the newest **rises** from the floor over 0.6 s (a slight overshoot) with a **dust puff**. Braced,
all stand. **Lanterns**: while a LANTERNS job works, each lantern hangs as the work reaches it, its glow swelling on;
every light pool **blooms** (`tunnel_lanterns.gd bloom`: from dark to BLOOM_PEAK 1.3 at 0.8 s, settling to 1 by 1.6
s; a spot already lit keeps its age when the row is handed in again). **Fixtures** (`fixture_view.gd` PUT IN): a
planned fixture with work on it **rises out of its chalk ring**, higher as the work goes on; in, a puff. The design
asked for existing clips only: **heavy** pieces (beds, the large bed, the hearth, the table, shelves, racks, the bin)
are heaved with `pull_radish`; **light** ones (the lantern, hanging stores, the rug) placed with `collect_object`
(`install_task.gd clip_for`). No new clips.

### 5. The hazards' visual language

DEC-040: hazards are "warned" and show in the geometry before they strike. `hazard_look.gd` maps tunnel_hazards.gd's
two pressures (per mille of the way to striking) to looks:

| State | Look | Level drawn |
|---|---|---|
| under SIGN_PERMILLE (250), or braced | plain earth | 0 |
| seep from 250 | **first signs**: the wet stretch darkens and glosses, a puddle on the floor, drips from the crown | rises 0 → 1000 as the pressure goes 250 → 1000 |
| seep from WARN_PERMILLE (500) | **warned**: the same, spreading along the bore (4 m either way at full), heavier; the news warns; the ends are ringed in clay | continues |
| flooded | the flood's own look (0208) | 0 |
| strain from 250 | **first signs**: cracks over the weak section (where its fall would drop), sand stains down the walls and a sandy spill on the floor, sand trickling from the crown | rises 0 → 1000 |
| strain from 500 | **warned**: wider, more cracks; the crown **sags** (up to 7 cm) over the section; news and clay rings | continues |
| collapsed | the rubble plug (0208) | 0 |

So a hazard is seen at half the warning's pressure, before the feed names it, and grows to the strike. Drawn without
building anything (`hazard_view.gd`): each segment's bore chunks get four **instance uniforms** -- `seep_level`,
`seep_span`, `strain_level`, `strain_span` (the wet quanta's stretch; the fall section, ±0.5 m) -- written only when a
level moves LEVEL_STEP (16 per mille) or reaches or leaves 0; the shader draws the rest. The HAZARD_SLOTS (2) worst
seeps drip and the 2 worst strains trickle sand, over the middle of their stretch from 0.9 of the crown's height.
The warning's clay rings are now drawn in the **U view** too (over the cap, no depth test), where the hazard is seen.
Readable at RTS distance: the probe's frames at 8 m and 17 m (below).

### 6. The particle budget: 200 live, by construction

`CPUParticles3D.amount` is each emitter's most alive, so the budget is the sum of the amounts of the emitters that
exist. `warren_particles.gd` owns every warren emitter as fixed pools:

| Pool | Emitters × amount | Particles |
|---|---:|---:|
| Chimney smoke (0210, `fixture_kit.gd SMOKE_AMOUNT`) | 8 homes × 16 | 128 |
| Face clods | 3 faces × 6 | 18 |
| Mound clods | 3 faces × 4 | 12 |
| Dust puffs (braces, fixtures, tips) | 2 × 8 | 16 |
| Drips | 2 seeps × 6 | 12 |
| Sand | 2 strains × 6 | 12 |
| **Total** | | **198 of 200** |

Whoever asks past a pool (a fourth face, a third seep, a third puff at once) is simply not drawn; a puff takes the
next dust emitter round. The tunnel overlay's mound, which had its own clods, now has none (the pool's mound clods).
The boot prewarm's two samples (a clod and a puff, one particle each, freed when the prewarm ends) are the only
other warren emitters. **Outside the budget**, their own pools from before the revamp: the weather's rain and snow, the woods' chips and
leaves, the swimmers' bubbles -- sized for the sky or a felled tree, not the warren. All pools run on the demo clock
(paused, a clod hangs; at 4x it flies four times as fast). Dust is **lit** (a dark puff below, catching lantern
light), not unshaded: unshaded, the U view's environment turned it into a glowing ball. The stress test (8 homes
smoking, 3 faces and their mounds, dust, 2 seeps, 2 strains, all at once) holds at most 200 alive and could never
hold more.

### 7. Surface signs

`warren_signs.gd`, on the SURFACE layer only:

- **Turf seams**: over each tunnel's stretch under the ground (past a ramp's open cutting), as far as it is dug -- a
  dig under way grows its seam behind the face -- a ragged strip of cut and relaid turf as wide as the bore. Each
  0.25 m **heals** over SEAM_HEAL_DAYS (3 game days) from the day it was dug (the bores' dig days) and a healed seam is
  hidden: a young tunnel shows, an old one does not. Rebuilt only when its tunnel changes or its fade moves a
  SEAM_STEP (5%). Three days, not the walls' one: at one a player at 1x barely sees a young tunnel's seam. The overlay's old faint earth trace over an open tunnel is gone; the seam is its successor.
- **Air vents** over every open tunnel at least 6 m long: a dark hole in a ring of fieldstones every 5 m of its
  stretch, evenly spaced, none within 1.5 m of its ends or on a crop bed; one MultiMesh (160 at most), placed again
  only when the network changes.
- **Mouth arches hang a lantern** (`tunnel_mouth.gd`): an iron bracket out from the lintel, a chain, a cage and an
  emissive glass, part of the gateway mesh (a second surface).

### 8. The brace cost in the Dig tool

The readout's second line adds what bracing the route would cost, from the jobs' own rates: "brace 4.0 wood + 4.0
stone" (`dig_readout.gd brace_text`, whole units to the tenth, rounded down).

### 9. Large beds (P4 carry-over)

0210's burrow bed (1.6 m) fits bodies up to the otters' 1.49 m and left the badger (2.55 m) on the hall's floor. Now
every resident has a **size** by its height (`bed_allocation.gd`): **small** up to 1.3 m (the moles, mice and
squirrels) and **big** over that (the beaver 1.40 m, the otters 1.49 m, the badger 2.55 m). A resident is permitted
only beds of its own size, so matching is exact -- a mouse never lies in the badger's bed, and a big resident with no
large bed free has none although burrow beds are -- and REQ-SET-132's order (current bed, then nearest free, ties to
the lower room then place) holds within each size. The badger nearer a burrow bed walks past it to the large one.

The **large bed** is the library's bed drawn 1.2 m × 2.7 m (the badger's 2.55 m and a pillow's room, as the burrow bed
is the otters' length and 0.11 m); it costs **4 planks** and 40 WU (1.8× the burrow bed's timber, rounded up to whole
planks, and twice its work). It goes in a **bed alcove** of a home, the place a burrow bed would take. A 4 m home has
no room for a 2.7 m bed without it crossing the middle, so the alcove is **dug on into a nook** when a large bed is
first planned there: a deep, flat-topped lobe of the room's own wall (`room_mesh.gd alcove_scale`), 3.8 m out from
the middle along the alcove's axis, and the bed lies out along that axis with its middle 2.3 m from the room's middle
(its foot as clear of the middle as the table). The nook is the room's own void: for the pillar every other dig keeps
it counts as a capsule (1.8 m round the alcove's axis from 2.4 to 3.4 m out), it stays when the bed is taken out, and
it may only be dug where that capsule keeps a pillar's earth from every tunnel not joined to the room, from every
other room, off the water and the buildings, and inside the village (`underground_rooms.gd nook_refusal`); refused,
in words ("Burrow home 1 has no alcove where a large bed's nook can be dug: a tunnel runs within 1 m of where its
nook would go"). **Which alcove**: the back one between two sockets (place 0), else the one by the door (place 2),
never the one under the hung lantern's wall. **Chosen over** a separate larger "big home" template (a second room
kind to lay and join, for three residents) and over a large bed on the floor (it would block the hearth or the
door's walk). The palette offers the large bed after the bed; the **suggested layout** puts one large bed in a home
that has none, in the first alcove whose nook may be dug (the demo's cast is six small residents to four big: a home's
layout now costs 10 planks, 3 wood and 6 stone).

### 10. The HUD's Beds cell: relabelled, not fed

The top-left Beds counter is UI-SET's settlement housing count; the demo does not run the settlement, so the shell
draws it "Unavailable" -- which, with homes full of beds, read as a bug. **Feeding** it (writing the demo's bed count)
was refused: the shell's contract refuses a value for an unwired counter ("writing a value into it would be exactly
the fabricated reading this shell exists not to produce", `ui_shell.gd`), and the design (§4) and 0210 keep the HUD's
Beds the simulation's. So `demo_beds_label.gd` **relabels the caption "Sim beds"**, adds a tooltip saying the
simulation is not running and where the demo's beds are counted (a home's panel, a resident's panel, the Tunnels
panel's "Burrow homes: 1 (3 demo beds)"), and **writes no value**. When the shell repaints the cell, the next frame's
`sync()` writes the relabel back (it compares two strings a frame).

### 11. Two behaviour fixes the theatre needed

- **A crowded task site** (`resident_brain.gd CROWDED_SITE_M`). Two crew members sent to one mouth at once crowded
  each other on its spot, replanned four times and abandoned their places (both stood at the mouth "holding"). This
  was there before P5 but only now mattered: a task's walk stuck within 0.35 m of its site on the ground has arrived
  (the crew enters from that near). A walker stopped by someone standing squarely on its site halts about 0.5 m
  off, outside that reach, and still replans as before.
- **An empty replan** (`_replan_or_abandon`): a route replanned while boxed in by standing residents could come back
  empty, and `_begin_leg` then read past its end (a crash seen on the probe's branch dig). It now abandons the trip.
- **The nook's tunnel check** skips another room's body and walks (they lie in its void, which the room check
  measures), so a room near a nook is refused as a room, not as "a tunnel".

### 12. Cadence

The warnings and the surface signs change over game minutes and days, so `tunnel_ext.gd` refreshes each once every
THEATRE_SLOW_FRAMES (6) frames, on different frames (~50 µs and ~25 µs a pass over every segment), and both at once
whenever the network changes (a tunnel laid, opened or closed shows the same frame); the face and the baskets every
frame (~6 µs and ~1 µs).

## Deviations from the design, and why

- The heap does not *receive* spoil at the tip; the ledger is posted at the cut as before and the tip only moves where
  it is drawn and whether it may be taken (§2). Moving the ledger would have changed Raise, Bank, the clearers and the
  farm's books for a presentation feature.
- "Carries it out stooped": the basket is carried on the carry clip, which the bore's stoop (0207) bends over; no
  new stooped-carry clip (no new clips).
- The crack is drawn in the shader (isolines of the earth's grain), not a decal: no decal to place per segment and it
  follows the bore.

## Measured

On the probe (`scratchpad/revamp_p5_agent/p5probe.gd`, 1920×1080, Metal, cold shader and pipeline caches moved aside
before each run; the P3/P4 playtest scene fitted out, with a new 16 m dig and its crew of two under way). The machine
was at load ~4 (a separate Codex service); one run showed two 16 ms toggle frames with no compiles and was re-run, as
the brief asks -- the table is the re-run:

| | P4 (0210) | P5 |
|---|---:|---:|
| First cold U toggle, worst frame | 12.6 ms | **12.6 ms** (4 new pipeline specialisations: the dust, the hazard uniforms; no banner, no clock pause) |
| 20 U toggles, worst frame | 9.5 ms | **9.4 ms** (no compiles, no banner) |
| U view: objects / primitives / draws; median and p95 frame | 112 / 69,294 / 53 (fitted, by day) | 102 / 43,830 / 42; 8.34 / 8.59 ms (this scene's framing) |
| Surface: median and p95 frame | 8.33 ms | 8.30 / 8.69 ms |

- **GPU**: Metal reports no GPU timestamps, so, as in P1–P4, the budget is compared by frame time and draws: both views
  hold the 120 Hz floor (8.33 ms) with vsync off.
- **CPU a frame** (1000 calls each): the dig theatre 5.6 µs, the baskets 0.9 µs, the warnings 52 µs and the surface
  signs 26 µs a pass -- each one frame in six, ~13 µs a frame between them -- and the marks (existing, now raising
  frames) 20 µs: about 40 µs a frame, inside P1's 0.2 ms.
- **Particles**: 198 of 200 by construction; the stress test (all at once) holds at most 200 alive.
- **The frames** (`scratchpad/revamp_p5_check/final/`, looked at one by one): the face with its clods at 3 m and lit by
  its hand lantern at 5 m and 8 m; a mouse filling its basket, carrying it below and up to the heap, tipping it (the
  heap 6.0 → 8.0 U tipped of 22.0 → 26.0 U in the ledger: the pile and the baskets hold the rest), the heap after with its
  puff; a brace frame rising and more going up; a lantern blooming and bloomed; braced and lit at 8 m; the seep's and
  the strain's first signs and warnings at 8 m and 17 m; the fresh seam with its vents, healing at 1.5 days and gone at
  3.5; the mouth's lantern; the badger asleep in the large bed in its nook (the probe gave the one large bed to the
  badger by leaving the other big residents unpermitted for that night: the cast has four big residents and the home
  one large bed).

## Tested

- **The suite.** `./tools/run_tests.sh`: `ok: 6377 tests, 548593 assertions, 0 failures.` (P4: 6317.)
  `test_demo_theatre.gd` (29) and `test_demo_warnings.gd` (20) are new: the budget table and the stress test (8 homes
  smoking, 3 faces, their mounds, dust, 2 seeps, 2 strains), the clock driving the pools, puffs round the dust pool;
  the baskets' conservation at every step (join, fill, top up, tip, leave, the last leaver, a mouth row laid again),
  the farm taking only what is tipped, a crew member's whole round (fill, carry loaded, tip for TIP_S, walk back, the
  heap growing by exactly the load, counted present throughout), one filler at a time and only a basketful, the last
  basket, a hauler called away, the baskets' drawing; the face (slot, lantern behind and beside, light, clods per cut,
  its digger in another bore); the concave face mesh; braces and lanterns going up with the work (nothing unpaid),
  rise and swell curves, bloom and births; fixtures rising and the installer's clips; drying (a room's stage days, a
  hub's first day, a widening's re-cut); two crew members crowding one mouth; a replan with no way at all; the
  hazards' looks for every state, levels drawn however faint, only when moved a step, not for a tunnel not open, the
  worst two dripping and trickling, the U view's clay rings; seams healing and growing with a dig, vents (none under
  6 m, none on a crop bed), the mouth's lantern; the readout's brace cost; the Sim beds relabel. Large beds in the
  fit-out and night suites: the order and its cost, every nook refusal and its words, the first alcove's reason, the
  tunnel sending it by the door, a room refusing it, the nook in the void, take-out, a large bed as a big bed in its
  nook, the layout not suggesting a second, a place emptied back to a burrow bed, a home laid again; sizes, strict
  size matching in REQ-SET-132's order, and a badger and a mouse in a village each walking to and lying in their own.
  Tests changed for P5: the fit-out's palette and layout (10 planks), the night's bed quads, the face and the heap
  reach in the tunnel suite, the readout, the bores, the overlay's mound.
- **Mutation testing** of the new logic, one mutant at a time, restored and checked by hash each time: 122 distinct
  mutants, all killed or shown to be dead code.
  - First set (115): the baskets, particles, hazard looks and view, surface signs, readout, Sim beds, bed sizes,
    large beds and nooks, lanterns, marks, the face, the crew's round, the brain, the installer, the farm, the night,
    drying. 87 killed. 16 more were first reported killed by an unrelated tunnel test that the new refresh cadence had
    broken (the slow views not drawn on the first frame; fixed: a network change redraws them at once) -- rerun, they
    survived and are counted with the survivors. Of the 28 survivors, 7 exposed redundant code, now removed (a
    permitted check `nearest_free` already makes, the large bed's home-template test, the phase test in `kind_at`, the
    carried term and a re-sync in the baskets, the underground test in `is_face`, the last-basket flag); 20 were killed
    by new tests; one is equivalent (`bloom` at exactly 0 is 0 either way).
  - The changed code (7 new): 6 killed; one equivalent (ending a finished hauler's place at the tip rather than on the
    next step, which `_last_basket` ends it on).
  - The review's fixes (12): 11 killed (the last three by two new tests: a seam's shape, a split segment's strain);
    one exposed a dead line (clearing the walk-back flag at the post, which is only read after a tip), removed.
- `python3 tools/demo_texture_imports.py --godot godot`: 0 changed; `godot --headless --path godot --editor --quit`:
  exit 0, no errors.

## Review

An independent `code-reviewer` pass on the uncommitted diff against c90a02c (it ran two probes of its own):
**0 CRITICAL, 2 HIGH, 3 MEDIUM, 4 LOW.**

| Finding | Handling |
|---|---|
| H1: after a tip, the member's walk back down counted it **absent** from its post, so the crew dug slower (in rock, a lone breaker's rate), and lost XP -- 491 of 5400 frames in the reviewer's probe, against §2's "rate unchanged" | Fixed: a tip sets `_returning`, and a member not in its place is counted present while it is set (`tunnel_crew_task.gd`). Tested: the round's test now follows the walk back to the post and checks presence on every frame; a first walk in is still not present |
| H2: the only test of "rate unchanged" stopped before the walk back | Fixed with H1: the test covers the whole round, and fails without the fix (mutants R01, R04, R12) |
| M1: `set_speed` built an Array literal and wrote 13 emitters every frame | Fixed: one prebuilt list, written only when the speed changes; tested (mutants R07, R08) |
| M2: a seam rebuild allocated four Arrays per 0.25 m quad and its mesh arrays every build | Fixed: corners, the quad order (a const), the normals and the mesh arrays are reused; the seam's shape is now tested (R09, R10) |
| M3: a hauler whose mouth row was freed mid-carry read the freed row (negative indices wrap: wrong positions, no crash) | Fixed: `_haul` checks the mouth first and sends the member back to its post; tested (R05, R06) |
| L1: the boot prewarm's two samples are warren emitters outside the pools | One particle each now, and §6 names them |
| L2: the hazard spans' key could collide past 65,536 u | The key is generation << 32 \| length; a split (same generation, new length) is tested (R11) |
| L3: `room_view.configure` and `tunnel_ext.configure` over 30 lines | Split (`_size_day_columns`; the nook site moved into `_start_living`) |
| L4: this record's placeholders | Filled |

Nothing skipped. The reviewer found the spoil conservation, the fixed pools, the refresh paths (no per-frame nodes),
typing and docstrings, the Sim beds relabel and the brain's two fixes correct.

## Consequences

- **For P6 (second level).** The hazard uniforms, the face slots, the seams and the vents are per segment and read
  the segment's own floor and crown, so a level-2 segment works as it is; its seams and vents must not be drawn over a
  level-1 tunnel's (the surface signs are for the top level only). A nook is per room: a level-2 home digs its own. The
  particle budget is village-wide: a second level shares the 200 (its faces take the same three slots).
- **For P7.** The hand lantern, the basket and the mouth's lantern are procedural (`warren_kit.gd`,
  `tunnel_mouth.gd`) and swap for generated props; the large bed is the library bed stretched and wants its own model.
- **Open.** The dig-face frame at 3 m looks down past the Foremole's back, which hides much of the face. Side and
  front angles were tried (`scratchpad/revamp_p5_check/face/`) and are worse: the U view looks down into a 1 m bore, so
  only a camera inside the bore would show the face square on. The nook's overhang (the dome's cut edge stays round) covers part of a large bed from straight
  above. 0210's L2 (a bed taken out from under its sleeper) stays open.

## Source

`docs/design/underground_revamp.md` §2 "Digging" and "Living", §6 "Hazards made visible", §8 P5, §10; the P5 brief
(the face and clods, the hand lantern, basket hauling matching the spoil accounting, braces with dust, lanterns
blooming, install animations from the chalk ring with existing clips, warnings mapped to tunnel_hazards' states,
surface seams, vents and mouth lanterns, the brace cost in the readout, a 200-particle budget with a stress test, large
beds, the HUD's Beds); DEC-040 ("warned"); GDD REQ-SET-132 and REQ-SET-133 (§5.9); UI-SET's counters
(`scripts/ui/ui_shell.gd`); decisions 0207–0210.
