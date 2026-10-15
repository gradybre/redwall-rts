# 1914 — Rounded, hand-dug walls on the dug level

Date: 2026-10-15 · Status: Accepted (Brendan approved the burrow-walls mockup, "Let's build this", relayed by the
coordinator on 2026-10-15); the PROPOSALS at the end await his word

Number range: 1914–1919, allocated to this lane by the coordinator; checked with `decision_numbers.py` and over every
ref. This is the lane record. It replaces no BACKLOG range.

## Decision

The painted-room proof of concept (decisions 1912, 1913, 1921) drew every dug cell as a square pit. The dug level is now
drawn as space dug by paws: smooth in plan, coved in section, a little uneven. **Rooms stay on the 1 m cell grid for
every rule** -- painting, validity, footprints, digging and cost. Only the drawing of dug space changes, in
`godot/demo/build_panel/` (no core owner, no rule, no saved byte).

- **The outline in plan.** A field of the distance from the dug cells is offset outward by `OFFSET_M` (0.45 × the
  radius), so a room's convex corners round outward into the earth. Where two dug sides meet round an earth corner,
  the corner is filleted with the mockup's polynomial smooth-min (`FILLET_M`, 1.8 × the radius), so a passage's mouth
  flares where it meets a room. The radius is a third of a cell, the mockup's default.
- **The section.** The wall's depth follows a cosine across `BAND_M` (0.35 + 0.6 × the radius = 0.55 m): rounded at
  the top lip, curving into the floor at the foot, with no overhang.
- **The wobble.** Fixed value noise (two octaves as in the mockup, `WOBBLE_M` 0.14 m either way) moves the contour. It
  comes from one seamless table made once from a fixed seed, read by world position, so it is identical every frame and
  every run.
- **Rule (a): never hide a usable cell.** Every point of a dug cell's closed square is floor, before anything else.
  The curves carve outward, never into a cell, and every piece of furniture stands on flat floor.
- **Rule (b): plan in squares, see it rounded once dug.** The ghosts, the chalk and the validity outlines are
  unchanged. Ordered cells are never rounded into. The rounding shows only on dug space and grows as cells are dug.
- **The cell being dug** deepens as before, and the rounding round it grows with it.
- **A faint cell grid** shows on the dug floor while the Rooms or Furnish tab is open.

## Engineering choices

- **E1 — The field is the cells', not the rooms'.** The mockup smooth-mins whole room boxes. A painted room is any cell
  set (rectangle, oval, brush), and a smooth-min over cells ripples along every straight wall, about 0.15 m once a
  metre. So the field is the exact distance to the dug cells (`demo_build_burrow_field.gd base_g`: to each dug side
  and corner of a cell's eight neighbours), with the smooth-min applied only where two dug sides meet round an earth
  corner. That fillet fades to nothing at the far sides of its cell (`FILLET_FADE_M`), so it never makes a seam.
- **E2 — The band lies outside the cells (a DEVIATION from the mockup's script).** In the mockup, the wall band runs
  inward from the offset contour. At a straight wall, a cell's edge is drawn only 0.17 of the depth down, and the outer
  0.4 m of every edge cell slopes. That breaks rule (a). Here the floor is the dug cells' closed squares, carried out by
  `OFFSET_M`, and the whole band lies beyond it, in the earth. `WOBBLE_M` (0.14) is less than `OFFSET_M` (0.15), so the
  wobble never reaches back to a cell. The cost is that rooms look up to about 0.85 m wider than their cells at the
  top lip, against about 0.3 m in the mockup. Furniture and the floor grid show where the cells are.
- **E3 — A point on a cell edge is judged by every cell it touches.** A dug one wins (floor); otherwise the shallowest
  wins. The field is therefore a function of the point alone, and two patches drawing one edge draw it the same. The
  test `test_the_walls_have_no_cracks` checks it, and so does `test_fill_patch_matches_the_field_point_by_point`. Earth
  further than a cell from any dug cell is the top: `OFFSET_M + BAND_M + WOBBLE_M` is 0.84 m.
- **E4 — Kept square (HARD).** These cells are never rounded into: ordered cells (rule b, including the cell being dug
  until it is dug), the World's wet cells (the deep protected water columns), and the two cells a dug landing's stairs
  rise into. A HARD cell beside a dug one is drawn at the top, with its edge falling in one lattice step (0.125 m). That
  is narrower than the chalk's inset (0.14 m), so the chalk always lies on flat top. A wet cell's patch keeps the water
  mark on its top.
- **E5 — A one-cell wall keeps its crest.** Two rooms a cell apart would have their bands overlap, and the wall between
  them would sag to about 0.3 m (the mockup has no such wall). An earth cell with dug cells on two opposite sides has
  its distances across it stretched by `THIN_SCALE`, so the whole section fits in half a cell and the crest is the top.
- **E6 — The rebuild.**
  - **When.** The dug view rebuilds only when the works, the level shown or the cell being dug change (its key, as
    in decision 1913). Deepening is a shader uniform, never a rebuild.
  - **What.** Each wall cell is a patch, a 9 × 9 heightfield (`SAMPLES` 8 a metre). A patch depends only on the
    kinds of the 5 × 5 cells round it and on where the cell being dug is among them. Patches are kept by that
    signature, so a dug cell remakes only the patches round it. Dug floors are flat quads in row runs, and the rest of
    the top is quads.
  - **Where.** In the live demo (`threaded`), `request` reads what the build needs on the main thread: the level's
    states (a copy, the new `Works.level_states`; review H1: a packed array kept in an Array is shared, so it is duplicated), its box and the ways. It then builds
    the fields, the surfaces' arrays and the chalk on a `WorkerThreadPool` task. `poll` adds the arrays to the mesh
    when the task is done, a frame or two later. Only one build is in flight; a request made meanwhile waits, and only
    the newest is built after it.
  - **The dig while a build is in flight.** If the build is for a different cell being dug, the cell shown keeps its
    depth until the new mesh is shown. If that build is shown while a newer request for another cell waits, the cell
    it shows being dug has been dug by then, so it keeps its depth too (review M-a). A just-dug cell never pops back
    up.
  - **Synchronous builds.** Tests and `draw` build on the spot. A freed earth waits for its task, and so does
    `set_kinds`.
- **E7 — Rebuild timings** (Brendan's Mac, headless, load average about 5; `scratchpad/rounded_proto/measure.gd`; every
  cell of a level dug one by one, a rebuild for each, after a first cold build):

  | Level | Build (worker) | Main thread, threaded | On the spot |
  |---|---|---|---|
  | The furnish loop and a bent passage, 88 cells | median 3.9 ms, p95 5.7, max 6.3 | median 0.11 ms, p95 0.14, max 0.18 | median 3.8 ms, p95 5.4 |
  | One 48 × 24 room, 1,152 cells | median 10.7 ms, p95 16.0, max 17.2 | median 0.31 ms, p95 0.38, max 0.54 | median 11.0 ms, p95 15.4 |

  These are the final code's numbers (after the review's fixes). The first, cold build (no patch kept) of the large
  room took 15 ms. The main thread pays only for reading the works
  and adding the arrays, a fraction of a millisecond, so no frame stalls. Without the patch cache the large room took
  about 30 ms a rebuild, and before E6's worker the main thread paid all of it.
- **E8 — One surface, mapped in world metres** (`build_burrow.gdshader`).
  - **What it draws.** The top, the floors and the walls are one heightfield in one shader. The bought floor
    texture is laid from above. The wall texture is laid from the side each face looks to (triplanar on x and z, the
    weights sharpened to the fourth power), and the two are blended by slope, so a curved wall never stretches
    either.
  - **With nothing staged (CI),** it draws `modular_surface.gdshader`'s packed earth with the same darkening of the
    uncut top.
  - **Light.** Decision 1913 lit the top by a dim fill and what was cut by the sun, by putting them on two layers.
    The rounded top and wall are now one surface, so the mesh is on both layers, and the shader's `light()` gives the
    sun to what is cut and the fill to the uncut top. The fill is told apart by its direction (`FILL_TOWARD`, shared
    with `demo_build_dug.gd`), and the hand-over runs over the first 0.12 m of a cut, so there is no seam at the lip.
  - **Marks removed.** Decision 1913's shade at a wall's foot and dark lip along a cut are gone: the coved geometry
    and the sun's shadows draw them.
- **E9 — The cell being dug** (the brief asked for this choice to be recorded). It is counted in a second field as dug.
  Each vertex near it carries how far it moves once dug (`UV2.x`) and its normal once dug (`COLOR`). The shader moves
  it by `dig_share` (`set_progress`: `dug_depth_m(share)`), so the cell sinks from the top to the floor and the
  rounding round it grows with it. The cell's middle starts at the top, so the mole's sink (`dug_depth_m`) is unchanged.
- **E10 — Ways.**
  - **Stairs up.** The cells a dug landing's stairs rise into are kept square (E4). The top tread meets the top, as
    it met the square pit's wall before, and is neither left floating over a rounded wall nor buried in a bulge.
  - **Stairs down.** As before, no floor is drawn under a way down's stairs. The cut's sides meet the floor at the
    2 × 2's edge, which is floor.
  - **The burrow mouth** is on the surface and is unchanged.
- **E11 — The floor grid.** The shader draws it only on the dug floors' quads (`UV.x`), at the cell lines, at
  `GRID_ALPHA` 0.15. That is fainter than the ghosts' 0.23 because it is lit with the floor. `demo_build.gd` shows it
  while a level is shown and the tab is not Decor. It is a uniform, never a rebuild.
- **E12 — Checks of the two rules on the drawn earth.** The live checks wait for the game's own frames to show the
  build (`_after_the_earth`, never a forced `finish`), so they check what the player sees.
  - `Earth.cells_off_the_floor` samples each cell's closed square, 5 × 5 points, from the built vertices.
  - `Earth.cells_rounded` samples inside each cell's chalk.
  - The dig loop checks both: rule (b) mid-dig and rule (a) once the rooms are open.
  - The furnish loop checks every fitted piece's footprint and every dug cell.

## Shared files touched, and the hook

- `demo_build.gd`: the earth is threaded; `set_grid` each frame.
- `demo_build_dug.gd`: `refresh` polls the earth and requests a rebuild; the fill uses `Earth.FILL_TOWARD`.
- `demo_build_works.gd`: `level_states` and `area`, both read-only.
- `test_demo_build_furnish_live.gd`: 59 checks. `test_demo_input_live.gd`: the dig loop's minimum is 27 checks.
- `test_demo_build_panel.gd`: the still-frame check shows the earth's build before it measures (a build shown by a
  later frame makes its meshes once).
- `demo_build_dig_live.gd` and `demo_build_furnish_live.gd`: the rule checks.

**Keys:** none.

## Gates

Godot 4.7.2, 2026-10-15, on Brendan's Mac (load average 5 to 11 with other lanes running). The final code is at
`cb90e1b4`.

- **Full CI-style run.** `godot/demo/assets` was set aside, `godot/.godot` deleted and the project imported, then
  `./tools/run_tests_parallel.sh` ran 10 shards, 4 at a time.
  - **First run:** shard 5 failed one test, `test_demo_build_panel.gd test_a_still_frame_allocates_nothing` ("expected
    4729, got 4733"). The worker's build was shown during the 200 frames measured. The test now shows it first
    (`cb90e1b4`).
  - **Second run:** every shard exited 0, and verify printed `ok: 504 suite files executed exactly once across 10
    shards`. 12,521 tests, 1,229,971 assertions, 0 failures. Every shard's `diagnostics:` and `log:` line shows 0
    unexpected errors or warnings and 0 leaked objects or resources. It took 1,698 s.
  - Afterwards the art was put back and re-imported; `demo_texture_imports.py --check` reported 0 files that would
    change.
- **Suites touched** (with the art): test_demo_build_burrow (28 tests, 171 assertions, 0.9 s), test_demo_build_dig
  (18 tests) and test_demo_build_panel (30 tests). All had 0 failures, 0 unexpected diagnostics and 0 leaks.
- **Analyzer** (`tools/gdscript_warnings.py --max 0 --port 6414`): 0 GDScript warnings in 0 of 1,541 files. Every new
  or changed function is 30 lines or fewer.
- **Decision numbers:** PASS, 552 records with this one, 0 problems.
- **Live harnesses**, on the final code:
  - **Headless at both sizes:** `demo_build_dig_live.gd` 27 / 27 at 1280×720 and 1920×1080, and
    `demo_build_furnish_live.gd` 59 / 59 at both sizes. The rule checks pass: mid-dig, 0 of 33 ordered cells rounded;
    every dug cell whole; 0 of 32 fitted cells off the floor.
  - **`demo_build_rounded_live.gd`, windowed with the art:** 66 / 66 at both sizes.
  - **Before the review's fixes, windowed:** the dig loop passed at 1920×1080. At 1280×720 its first run stopped at
    "the mole walks in and digs": the village did not move while other lanes' tests loaded the machine. The rerun
    passed 27 / 27.
- **Mutation testing** (`scratchpad/rounded_check/mut/run.py`, one mutant a run against test_demo_build_burrow and
  test_demo_build_dig): 44 mutants.
  - **The first 30** cover the field (section, offset, wobble, the one-cell wall, the edge rule, sides and corners,
    the fillet and its fade, `fill_patch`, the signature), the earth (which cells are walls, the floor under stairs,
    ordered and wet cells kept square, the top's holes, the stair heads, the held and reset dig, backwards strips) and
    the patch builder (the dig's direction, the normals, the water mark).
  - **The other 14**, added after the review, cover the threaded rebuild (`poll`, the waiting request, the hold and
    its release, the wait on free, the pop), the cache (kept across tops, the wet bit, the dig's reach, never
    refreshed), the dug normal, the water mark on the slope, and the works' copy.
  - **Survivors were all real gaps.** The first pass left 5 (the floor just inside the offset, the dig in the
    signature, walls round the cell being dug, the share reset, the normals in x). The review's mutants left 4 (the
    hold for a request behind a same-cell build, a kept-square cell turned wet, the works' copy, the dig two cells
    from a kept patch). Tests were added for each.
  - **Kills by script error:** 3 mutants were killed by the script errors they raise as well as by failures: a
    kept-square cell read through an empty table (2), and the worker reading a freed earth (1).
  - **Result: 44 of 44 killed, none survived.**
- **Independent review** (`code-reviewer` on `b3185ee2`): 2 HIGH, 6 MEDIUM and 10 LOW. All HIGH and MEDIUM are
  fixed in `67d3af06` and `d9c9921a`.
  - **H1:** `level_states` returned the works' own array (a packed array kept in an Array is shared), so the worker
    raced the mole. It now returns a copy, and a test checks it.
  - **H2:** the threaded path had no test, and the live checks forced the build. There are now tests through `poll`,
    the waiting request, the released hold, freeing and `set_kinds` mid-build. The live checks wait for the game's
    frames.
  - **M-a:** a cell dug while its build was in flight popped back to the top for a frame. That build now keeps the
    hold when a newer request for another cell waits.
  - **M-b:** `g_at` truncated negative lattice points. It now uses floor division, and the `fill_patch` test covers
    the edge cells.
  - **M-c:** the dead depth cache and helpers are removed.
  - **M-d:** the patch cache is pruned each build to the patches drawn, and a patch no longer keeps its scratch
    arrays.
  - **M-e:** all 256 mask tables are made on the main thread at configure, and the index pattern has a mutex.
  - **M-f:** absolute checks were added for the dug normal, the level switch, the wet bit and the water mark on the
    top only.
  - **LOW, fixed:** the in-flight hold compares the dig on this level only; the signature's sentinel is a named
    constant (`NOT_NEAR`); the triplanar weights are sharpened (`pow 4`); the mesh's cull margin covers the dig; the
    dig loop's minimum is 27 checks; two long lines are wrapped.
  - **LOW, left:**
    - The lattice maps are written for `SAMPLES` 8; the brief's range is 6 to 8, and changing it means
      rewriting them.
    - The dug normal is stored in 8-bit `COLOR` (about 0.45°), and every vertex mixes in 4% of it.
    - The fill is told from the sun by direction.
    - A few containers are untyped.
- **Frames looked at** (session scratchpad, not committed):
  - Before, at both sizes: `rounded_check/before2_1280x720/` and `before2_1920x1080/`.
  - After (final code): `rounded_check/final_1280x720/` and `final_1920x1080/`. They show the dug Kitchen, Passage and
    Dormitory with their furniture (`rounded_rooms_furnished_*`, `furnish_kitchen_ready_*`, `furnish_beds_*`); the
    Passage's mouth into the Kitchen close up (`rounded_passage_mouth_*`); the bent passage (`rounded_bent_tunnel_*`);
    and a room mid-dig, with the ordered cells square under their chalk (`rounded_mid_dig_*`).
  - The dig loop's own frames: `after_dig_1920x1080/` and `after_dig2_1280x720/`.

## PROPOSALS for Brendan

- **P-1914-1 — A player-facing "Rounding" setting.** Not built: the rounding is a named constant (`RADIUS_M`, a third
  of a cell, with the offset, band and fillet following it as in the mockup) and the wobble another (`WOBBLE_M`).
  - (a) No setting.
  - (b) A Settings toggle, "Rounded walls" on or off (off would draw decision 1913's square pits).
  - (c) A slider, as in the mockup.

  **Recommend (a)** for the proof of concept. A toggle is cheap later, but every look it offers must keep rule (a).
- **P-1914-2 — The walls sit outside the cells (E2), so a room reads up to about 0.85 m wider than its cells at the
  lip.**
  - (a) As built.
  - (b) A smaller radius (a quarter of a cell), so the walls sit closer but look less scooped.

  **Recommend (a).** It is the mockup's look with rule (a) kept.
- **P-1914-3 — A one-cell wall between two rooms keeps its crest (E5).**
  - (a) As built.
  - (b) Let it sag, as the bands overlap.

  **Recommend (a).** Otherwise two rooms read as one.
- **P-1914-4 — `demo_build_rounded_live.gd`** (the furnish loop with a bent passage, its frames and the rule checks)
  is run by hand, not in CI. The dig and furnish loops already check both rules in CI.
  - (a) Keep it by hand.
  - (b) Add it to CI's slow tier (about 2 minutes).

  **Recommend (a).**

## Source

- Brendan's approval of the burrow-walls mockup, 2026-10-15: "Let's build this", relayed by the coordinator with the
  brief's two rules.
- Decisions 1912 (the proof of concept), 1913 (its earth view, lights and art) and 1921 (the Furnish tab).
- SET-BUILD-001 (rooms on the 1 m grid).
- `docs/ui_ux_controls.md` (state in words and shape, never colour alone).
