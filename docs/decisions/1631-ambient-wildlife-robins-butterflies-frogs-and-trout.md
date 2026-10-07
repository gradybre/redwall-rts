# 1631 — Ambient wildlife: robins, butterflies, frogs and trout
Date: 2026-10-07 · Status: Accepted (the rules used are adopted; the demo values and PROPOSALS below wait on Brendan)

**Numbering.** The handoff's packet assigns WILDLIFE decisions 1301–1310 (`docs/handoff/BACKLOG.md`, "WILDLIFE"). The
lead remapped this lane to **1631–1649**, because a parallel digging branch already uses 0991–1217 and the packets'
ranges from 1101 collide with it. This record is 1631; the livelier weather is 1632.

## Decision

The live demo draws ambient, presentational wildlife: robins hopping, pecking and flying about the lawn and paths,
peacock butterflies over the beds, common frogs on the pond's bank and brown trout leaping in the pond and the stream's
run, following the season, the hour and the weather. It uses the rigged art pass 2 models (decision 0951) at Brendan's
DEC-047 sizes. Nothing is simulated: there is no population, no row, no save, nothing the settlement reads.

Feature #11, approved by Brendan on 2026-10-01 in "NEW 2". That approval is recorded only in the coordinator's
tracker; `docs/handoff/RULINGS.md` ("New features, NEW 2") is its first repository record.

## The rules used

- **No fauna simulation.** GDD REQ-SET-059 keeps FaunaStockReserved canonical empty and REQ-SET-065 keeps the retired
  hunting slots inactive; `docs/planning/fauna_component_validation_contract.md` introduces "no active fauna". So which
  animals show is a pure function of the date, the hour and the weather the HUD already shows
  (`wildlife/wildlife_rules.gd` `count_of`), and the view writes nothing anywhere (`test_the_wildlife_writes_nothing_to_
  the_weather`).
- **No hunting.** REQ-ADM-001 rejects any mammal or bird harvest source. The animals are not selectable (no collision
  body; the live harness checks it), carry no job, and nothing can take them.
- **No swarms.** ECO-038 bounds landscape risk; at most 4 robins, 5 butterflies, 3 frogs and 2 trout show.
- **The robin reads as a wild bird, not a resident.** Sapient birds (sparrows, kestrels) can be residents in this world.
  The robin is drawn at bird scale (0.45 m beside the 1.00 m mouse, DEC-047), has no name, label, clothes or voice, and
  only hops, pecks and flies.
- **Sizes: DEC-047** ("ambient wildlife, not residents"): robin 0.45 m long, butterfly 0.36 m span, frog 0.40 m long,
  trout 0.80 m long. The bodies are exported at these sizes and drawn at scale 1.0. The live harness measures each
  staged body's longest extent against them.
- **Daylight: GDD §5.10** (06–19 spring, 05–21 summer, 07–18 autumn, 08–16 winter), read from
  `world/daylight_curves.gd`, which already holds those hours.
- **Reduced motion** (decision 0471, UI §8.1): nothing crosses the screen. Robins neither hop nor fly, butterflies rest,
  frogs sit and trout do not leap. Each still breathes in its idle clip.

## What was built

| File | What |
|---|---|
| `godot/demo/wildlife/wildlife_rules.gd` | who is about: the season table, daylight, the weather |
| `godot/demo/wildlife/wildlife_spots.gd` | where: robin ground spots, butterfly loops, frog bank spots and trout spots, measured on the real water map |
| `godot/demo/wildlife/wildlife_motion.gd` | how they move: the hop's air frames, the robin's arc, the butterfly's loop |
| `godot/demo/wildlife/wildlife_bodies.gd` | the pooled bodies: the staged model (looping clips set) or a stand-in of the same size |
| `godot/demo/wildlife/wildlife_view.gd` | the view: pools, states, the robin's flush, the prewarm, `wire` (the village's hook) |
| `godot/test/test_demo_wildlife.gd` | 32 tests |
| `godot/test/live/demo_wildlife_live.gd` | the live harness and its frames |

**Shared files touched:** `godot/demo/demo_village.gd`: a `WildlifeScript` const, a `_wildlife` var, a call to
`_build_wildlife()` in `_ready` after `_build_hall()`, and that six-line builder (make it, add it, `wire` it). `wire` registers the wildlife's own boot-prewarm frame step
(`demo_prewarm.gd` `add_frame_step`), so `demo_prewarm.gd` itself is not changed. **No key** was added.

### How it behaves

- **Robins** rest, peck, hop (turning a little each time, and hopping back once 0.5 m from their spot) and every few
  rests fly to another free spot in a 1.6 m-plus arc. A resident on the surface coming within 1.6 m flushes a robin at
  once: it takes wing to another spot. In rain or snow robins are fewer (half) and do not fly.
- **Butterflies** flutter in an uneven loop round their spot, now and then settle on a plant top (0.45 m) for a few
  seconds, and rise again.
- **Frogs** sit facing the pond's middle and hop 0.3 m along the bank and back.
- **Trout** wait under the surface and leap every 6–16 s, along the run's flow in the stream or round the pond. The
  `leap` clip carries its own 1.2 m of travel, so the body is placed half a leap behind its spot.
- **Not staged** (CI, a fresh clone): each animal is a rounded stand-in of its size and colour with no clips. It counts,
  places and moves the same, so the suites test the same logic.

### Cost

- **Pooled.** Every body is built in `configure` (14 animals and 4 robin flight bodies), and only shown, hidden and
  moved after. A frame creates no Object (`test_a_frame_allocates_no_object`, 3,600 frames). `OBJECT_COUNT` does not
  count arrays, so "no array, string or dictionary per frame" rests on the code: the per-frame path uses value types
  and packed columns only (the one array literal, in `_follow_speed`, is built only when the game's speed changes).
- **Hidden bodies cost nothing to animate.** A hidden body's `AnimationPlayer` is switched off (`active = false`).
- **Distance culling.** Every mesh is culled past 55 m (`visibility_range_end`). The butterflies cast no shadow.
- **Skinning is small.** The rigs are 3–4 joints each (decision 0951's Blender rigs), far under a resident's.
- **Frame cost**, measured with the scale test at 9 and 25 residents: see "Gates" below.

## Gates

Run on 2026-10-07 on Brendan's machine, which was loaded (load average 21–27 from other lanes), so the frame
differences below are within noise.

- **Frame cost** (`tools/scale_test/scale_test.gd --plan short`, windowed 1920x1080, `--fixed-fps 60`; the spring
  morning shows 4 robins, 3 butterflies, 3 frogs and 2 trout). The wildlife script's own time was **37 µs a frame at 9
  residents and 40 µs at 25** (the run's per-script totals). The A/B against the same build without the wildlife hook:

  | Residents | Phase | Work p50, with | Work p50, without | Work p95, with | Work p95, without |
  |---|---|---:|---:|---:|---:|
  | 9 | 1x | 9.28 ms | 9.21 ms | 10.08 ms | 10.14 ms |
  | 9 | 4x | 14.36 ms | 14.16 ms | 16.36 ms | 15.94 ms |
  | 25 | 1x | 9.62 ms | 9.37 ms | 10.63 ms | 10.91 ms |
  | 25 | 4x | 15.08 ms | 14.89 ms | 17.52 ms | 16.89 ms |

- **Focused suite:** `test_demo_wildlife.gd`: 32 tests, 0 failures; diagnostics 0 unexpected, 0 leaked.
- **Live harness** (`test/live/demo_wildlife_live.gd`, staged models), at 1920x1080 and 1280x720: `LIVE-SUMMARY 30 0`
  each. It checks:
  - the counts against the rules at a summer noon, a winter noon and a summer night;
  - that each animal is in its frame;
  - that the flight body flaps, its clip stands still while paused, and the perched body's player is off;
  - DEC-047's sizes, measured from the staged bodies: 0.45, 0.36, 0.40 and 0.80 m;
  - that no collision body exists;
  - that the boot prewarm drew them.
- **Frames looked at** (session scratchpad `wildlife_check/frames_final/`, not committed): the lawn, a robin perched, a
  robin on the wing, a butterfly on a radish bed, frogs on the bank, a trout mid-leap, and winter robins.
- **Analyzer:** `0 GDScript warning(s)`. **Contracts:** all pass, including `decision_numbers.py` (330 records, 0
  problems).
- **Mutation testing:** 41 mutants, one per run, against `test_demo_wildlife.gd`.
  - The first round killed 28 of 32. The 4 survivors were real gaps, each closed by a new test:
    - a hidden animal not shown again;
    - a temperature-only change not re-read;
    - the trout's depth filter;
    - a late landing.
  - The 9 that followed, on the review's fixes and the frog spots, were all killed.
  - Final: 41 of 41 killed. `SURVIVED_MUTANTS: none`.
  - Not mutated in the unit suite: which AnimationPlayer plays and its speed. Stand-ins have no player, so the live
    harness checks these on the staged models.
- **Independent review** (`code-reviewer`). There were no CRITICAL findings. All of these were fixed:
  - **H1:** reduced motion let butterflies drift and hover. They now hold on their plant; the test checks every body's
    position.
  - **M1:** a robin's flight body showed for one frame at a stale place. It is now posed at take-off.
  - **M2:** a repeated peck froze on its last frame. The clip now restarts.
  - **M3:** six surviving mutants. Each now has a test (the four that can run on stand-ins), or a live-harness check
    (the two about players and speed).
  - **M4:** an always-true "bodies staged" check. It is now an info line.
  - **M5:** an unread `last_usec`. It was removed and the measurements are recorded above.
  - **The LOWs:**
    - a frog faces the water again on landing home;
    - a butterfly keeps its flight heading when it settles;
    - it starts on its flutter path;
    - the hook moved into a `_build_wildlife()` helper.

## PROPOSALS for Brendan

None of these is in an adopted document. Each is built as the smallest sensible behaviour, and a different ruling is a
table change in `wildlife_rules.gd` or `wildlife_view.gd`.

- **W1. The animals' year and counts.**
  - Robins all year (4; 3 in winter); butterflies spring to autumn (3 / 5 / 2), at 10 °C or warmer in dry daylight, an
    hour clear of dawn and dusk; frogs spring to autumn (3 / 2 / 2), day and night above freezing; trout spring to
    autumn (2), in daylight.
  - Options: (a) as built; (b) more animals (more pool, more cost); (c) fewer.
  - Recommendation: (a).
- **W2. A robin flushes when a resident comes within 1.6 m.**
  - Options: (a) as built; (b) robins ignore residents.
  - Recommendation: (a). It is the one place the wildlife notices the village, and it costs one distance check per robin
    per resident.
- **W3. Reduced motion stills the wildlife**, rather than hiding it.
  - Options: (a) as built; (b) hide every animal with reduced motion on.
  - Recommendation: (a).

## Follow-ups (not built here)

- **Sound.** There is no birdsong or frog cue in the CC0 sound library staged for the demo (`demo/sound/`). A dawn chorus
  would sell the robins. It needs a download, which decision 0493's group R asks Brendan before each one.
- **A splash ring under the trout's leap.** The warren's particle budget is spent (decision 0211), so it would be a
  decal or a shader ring, not particles.
