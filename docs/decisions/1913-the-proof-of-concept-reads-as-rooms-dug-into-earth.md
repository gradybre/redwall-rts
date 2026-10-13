# 1913 — The proof of concept reads as rooms dug into earth

Date: 2026-10-13 · Status: Accepted (Brendan asked for it: "Merge it, then start visual polish", relayed by the
coordinator on 2026-10-13); both PROPOSALS ruled the same day (below)

Number range: 1913–1919, allocated to this lane by the coordinator; checked with `decision_numbers.py`. This is the
lane record. It replaces no BACKLOG range.

## Decision

Decision 1912's painted-room proof of concept worked, but its frames looked unfinished. The dug rooms were pale beige
boxes standing on a black void. Two labels overlapped, and one label looked doubled. Nothing told a waiting cell from
the cell being dug except colour. The Entrance was a flat dark square. This record makes the loop look like rooms dug
into soil, in the cutaway the EG2 study aims at (`docs/design/underground-planning/evil-genius-2-building-study.md`).
The change is presentation only, in `godot/demo/build_panel/` and its checks. No rule or behaviour of the proof of
concept changes.

- **The earth** (`demo_build_earth.gd`, new). The level shown is a block of earth. Its top is the level's floor
  plane, the plane cells are painted and picked on, so nothing painted floats. Every dug cell is a pit 1 m deep (E10's
  room height) with a packed-earth floor and earth walls where dug space meets earth. Both use the planner's own
  surface materials (`modular_materials.gd`), so the unexcavated top is darker than the dug faces. A soft shade lies
  along each wall's foot and a dark lip along each cut edge. The top follows the actual World's ground, tile by tile,
  as the World view's section draws it (E1).
- **The cells, by shape and by words.** Each state is shown by its shape and named in words, never by colour alone.
  - An **ordered** cell is on the top, pegged out in chalk. Its tag reads "Waiting for the mole: N cells".
  - The cell **being dug** is cut out of the top and deepens as the dig goes on (`set_progress`, a transform each
    frame, no rebuild). Its tag reads "Digging", and the waiting count leaves that cell out.
  - A **dug** cell is a pit.
- **The ways** (`demo_build_ways.gd`, new). These use the earth tones of the legacy tunnel mouth.
  - A confirmed Entrance is a burrow mouth on the surface: a horseshoe mound of dug earth round a dark hole, with a
    trodden tongue leading in.
  - A dug landing has earth steps rising out of it to the top, with the top tread dark where the way goes on up.
  - A Way down whose landing is dug has steps cut down into the floor, darker with each tread.
  - The words stay as before: "Entrance", "Way up to the surface", "Way up", "Way down".
- **Light** (`demo_build_dug.gd`). The dug view has its own sun, high and from the south-west, on the dug layer. It
  casts shadows only from the dug view's own layers. A dim fill lights the earth's top from above. The rooms therefore
  stand out of the darker mass, the far walls are lit, and each cut's west and south edges cast shade into the room.
- **Tags** (`demo_build_tags.gd`, new). Every tag draws its outline under its text. A tag drawn the other way round
  read as doubled, which is the "Waiting for the mole" ghosting the coordinator saw (E5). Each frame a level is
  shown, the figures' names and the level's tags are measured on screen. Each tag is then lifted, by its own
  `offset`, just clear of the ones before it. The names go first so that they stay over the bodies (E6).
- **The figure** stands on the pit's floor: its body and name are drawn 1 m below its place. A right click that
  sends visitors picks on the pit floor, where the player sees it (E2).

## Engineering choices

- **E1. The World view's section is replaced in the build view, not cut.** The planner's World view
  (`modular_world_view.gd`) draws the level as one plane at the floor height. A pit below that plane cannot be seen,
  and the plane cannot be offset: its catalogue accepts only its own section offsets, and the view refuses any
  transform that is not the identity. The World view is still mounted and checked, and its terrain kinds are read
  once at the mount (`demo_build_world.gd section_kinds`, through the view's own `_read_terrain`). The earth applies
  the section's own rule (`_kind_at`), so land is earth and the deep protected water columns keep the World view's own
  matte mark. That mark is drawn unlit; drawn lit, with no light reaching it, it read as the void. While a level is
  shown, the U view draws the marks layer and the earth's top layer (`SHOWN_MASK`), not the section layer. Without a
  World (no underground composed: review M4's case), the whole level is plain earth. This is the same actual World at
  5 m that P-C6 (a) asks for, drawn by the earth instead of by the section plane. P-1913-1 asks Brendan to confirm it.
- **E2. The paint plane is the earth's top, and the pits are sunk below it.** The other choice was to raise the earth
  1 m above the floor plane. That would have put the painted ghosts and the picked cells under the earth, or about a
  cell's parallax away from where the player looks. With pits sunk, painting is unchanged. `paint.pick` and `screen_of`
  take a `lift_u`, and only the visit's right click uses it (−1,024 u: the pit floor). The figure's place
  (`BelowTask.world_of`, checked by the suite) is unchanged; only its drawing is lowered.
- **E3. A camera draws only the lights on the layers it draws.** In Godot 4.7, a DirectionalLight3D is itself culled
  by the camera's cull mask through its own `layers` (default 1). A probe showed a box on layer 2 or 256, drawn by a
  camera masked to that layer, getting no light at all from a light whose `light_cull_mask` included the layer. The
  light became visible once its `layers` matched. This is why decision 1912's `BuildWorldLight` (on layer 1 while the
  U view drew layers 128 and 256) never lit the section, and why the section looked black or dark brown. The dug
  view's lights now sit on the layers they light, and the unused `BuildWorldLight` is removed.
- **E4. Two lights, and shadows from the dug layers only.**
  - The sun lights only the dug faces (layer 256). The earth's top (layer 512) takes a fill of 0.22.
  - `shadow_caster_mask` holds only the two dug-view layers, so the village above, 4.6 m up, never shades the level.
  - The sun comes from behind the camera, so the far walls are lit. Lit from the north, the far walls stood in
    their own shade and the rooms read as flat holes.
- **E5. The doubled tag.** The ghost tags already set `outline_render_priority` below `render_priority`. The dug view's
  tags and the figure's name did not, so with `no_depth_test` the outline sometimes drew over the glyphs. Both now use
  5 for the text and 4 for the outline.
- **E6. Keeping the tags apart.** `spread` and `clear_of` lift each rect just above every earlier rect it meets, `GAP_PX`
  apart.
  - A rect only ever rises, so it passes each earlier rect at most once. The loop is bounded by the number of rects
    placed so far.
  - A rect with no area (a tag behind the camera) is ignored.
  - Screen rects come from the tag's anchor and its text size, projected along the camera's right and up axes. This
    holds for any projection.
  - The lift is written to `Label3D.offset.y`, whose positive y is up (a probe measured the AABB). It is written only
    when it moves by more than 0.5 px, because a Label3D rebuilds its text mesh on a change.
  - The working arrays are reused from frame to frame (`spread_into`).
  - The loop harness checks "no two tags sit on each other" while the mole digs and with the visitor inside.
- **E7. Rebuild cost.** The earth is rebuilt only when the works, the level or the cell being dug change; each frame
  only one transform moves. Reading the World's tiles into row runs is done once at the mount: 13 ms for the
  256 × 256-cell map. A rebuild with a 48 × 24 dug room took 5.7–6.8 ms (272 top quads, 1,152 floors, 144 walls,
  304 marks; headless, Brendan's Mac). Pits are drawn a quad a cell, which is the simplest way. Merging floor quads
  into runs is left for C3's real view.
- **E8. Stairs only once a way is dug.** A way's stairs appear when its landing's four cells are all open
  (`Earth.way_dug`). Until then the landing is pegged out in chalk like any ordered cell, and its tag names it.
- **E9. The Overview level (5) is no underground level.** The dug view used to draw "level ≥ 1". The new
  `underground(level)` check is 1–4, so the bar's Overview indexes no floor. The input harness caught this.
- **E10. The surface frame.** The loop harness's Entrance stands under an oak whose crown covers it from straight
  above. The harness's new last frame therefore aims the camera low from the west (`demo_camera.gd aim`: yaw 270,
  pitch 38, 7 m) and lets the crowns settle before it captures.

- **E11. The review's findings** (independent `code-reviewer` on `9260d5b2`: no CRITICAL, no HIGH; five MEDIUM, all
  fixed in `c1ab280c`):
  - M1: a Way down's stairs were drawn (and counted) under an unbroken top when its landing was dug before its own
    cells. Stairs down now need the way dug through, landing and its own 2 × 2 (`Earth.way_open`), and the floor is
    left out only then.
  - M2: on the first cell of a trip the mole stands on the cell it digs, and was drawn buried under the shallow pit.
    `Figure.set_sink` now puts it on the floor dug so far.
  - M3: a lifted tag could land one float32 ulp short and meet the same rect again; it is lifted a further
    `LIFT_SLACK_PX` (0.01 px).
  - M4: a pooled tag kept the last owner's lift (the surface "Entrance" floated); `_tag` clears it.
  - M5: the checks now sum the earth top's area (the planning area and its apron, less each pit and the digging
    cell) and cover the stairs and the sink.
  - LOW, fixed: L1 (a cell's side is `CELL_U`, not the pit's depth), L3 (a stale docstring), L6 (`overlaps` ignores an
    empty rect on either side). LOW, left: L2 (the digging pit's UVs stretch as it deepens; it lasts 1.5 s), L3's
    second read of the World's tiles (13 ms once; the view keeps no copy and is not this lane's to change), L4 (the
    World view still sets its hidden section's height), L5 (layer numbers named in several files), L7 (rebuild-time
    allocations), L8 (a degenerate fan quad; the material draws both faces), L9 (figures walk through the stairs).
- **E12. Two frame fixes after the coordinator's look.** (a) The surface "Entrance" tag was drawn at a world size, so
  the close surface camera made it huge; surface tags now keep a constant screen size, as the village's own tags do
  (`fixed_size`, `tunnel_overlay.gd`'s 0.0006 m a pixel). (b) The earth block ended at the map's edge, and past it
  the background showed as a black hole; the top now runs on `APRON_M` (96 m) past every edge. The level's water mark,
  drawn unlit in the World view's near-black ink, also read as a hole; it is now a dark wet slate (`WATER`, the legacy
  cap's water hue, darkened: unshaded at full strength it glared).

## Anything else seen in the frames, and what was done

- **Fixed:**
  - The black void around the rooms is now earth.
  - The level's water reads as a flat mark, not as the void (E1).
  - The far half of the mole was hidden inside a box wall; the figure now stands in the pit.
- **Left, and why:**
  - The paint grid is drawn over the pits on the paint plane: it is the planning grid.
  - The tags are small at 1,280 × 720 (36 px at 0.01 m a pixel, about 14 screen px). That is as before; a fixed
    screen size is a UI-BUILD question for C3.
  - The figure is still a capsule stand-in (decision 1912 E13). Drawing the actors' own rigs below is engineering for
    C3, not art; see P-1913-2.

## Brendan's rulings (2026-10-13, relayed by the coordinator)

- **P-1913-1: "Keep the earth view"**: (a) as built.
- **P-1913-2: "Yes, all three (78 credits)"**: the burrow-mouth prop (30), the stair flight (30) and the two earth
  textures (18), with a hard cap of 78 credits including any retry. The art is a separate step, recorded in its own
  section of this record when done; the procedural pieces stay as the fallback where the art is not staged (CI).

## PROPOSALS for Brendan (as put to him)

- **P-1913-1 — The level's look replaces the World view's section in the build view (E1).** Options:
  - (a) As built: the same World terrain, drawn as cut-away earth with pits.
  - (b) Keep the section plane and draw the dug rooms as raised boxes, as in decision 1912.

  **Recommend (a).** It is the only way the pits can be seen.
- **P-1913-2 — Real art, if wanted.** Nothing was generated or downloaded. The itemised cost at Meshy's published
  rates (no model was run) is:

  | Item | Tool | Credits |
  |---|---|---|
  | Burrow-mouth prop (earth mound, roots, a few stones), image-to-3D with a 2K texture | Meshy (meshy-6) | 30 |
  | Timber-and-earth stair flight for landings, text-to-3D preview plus refine | Meshy | 30 |
  | Tileable packed-earth and dug-wall textures, two images | nano-banana-pro | 18 |
  | **Total** | | **78** |

  The stand-in figures could become the residents' own models underground with no paid generation (engineering).
  Options:
  - (a) Approve the 78 credits.
  - (b) Approve some items.
  - (c) Keep the procedural pieces until C3.

  **Recommend (c)** for the proof of concept, since C3 replaces this view.

## The art (P-1913-2, as ruled)

Bought within Brendan's cap of 78 credits including retries, delegated under decision 0961. The balance was checked
before the first call and between each group: **86 → 77 → 68 → 48 → 18 → 8. 78 credits, six calls, no retry, no
failure.**

| # | Item | Tool and model | Task | Credits | Balance after |
|---|---|---|---|---|---|
| 1 | Packed-earth floor texture, tileable | text-to-image, nano-banana-pro, 1:1 | `01a1356b-d802-70bf-8505-3cd3d221f661` | 9 | 77 |
| 2 | Dug earth wall texture, tileable | text-to-image, nano-banana-pro, 1:1 | `01a1356c-8780-74c8-9bdc-f544dd7fff42` | 9 | 68 |
| 3 | Stair flight, preview (untextured high-poly) | text-to-3d, latest (meshy-7.1), no remesh | `01a1356d-6523-7537-a2bc-c321a5d7a293` | 20 | 48 |
| 4 | Stair flight, texture (2K, PBR) | text-to-3d refine | `01a1356e-8a07-74b9-aeac-632997f602eb` | 10 | — |
| 5 | Burrow mouth, preview | text-to-3d, latest (meshy-7.1), no remesh | `01a1356e-a6d7-732b-88d8-2ac226b50bf3` | 20 | 18 |
| 6 | Burrow mouth, texture (2K, PBR) | text-to-3d refine | `01a13571-9abb-75b5-82a8-026b040b4d95` | 10 | 8 |

Each preview was rendered and looked at before its texture was paid for. The prompts are in the calls' rows of
`docs/art-reference/asset_library/meshy_tasks.jsonl`; the palette was locked in them to the earth's own tones (umber
#452E1B, warm brown #7D5938, humus #2E1E12, rust clay #8A4A2A).

- **One deviation: the burrow mouth was made from text, not from an image.** P-1913-2 itemised it as image-to-3D with a
  2K texture (30), but no concept image existed for it and a concept was not in the approved list. Text-to-3D preview
  plus refine is the same 30 credits for the same item; it was used instead. Recorded here, not hidden.
- **Measured before use** (the asset pipeline's rule): both models are glTF Y-up with an identity node, the mouth
  1.87 × 0.90 × 1.90 m and the flight 1.90 × 0.48 × 1.69 m as delivered; the mouth opens toward +Z (its +Z edge is
  ground, max height −0.29 m) and the flight rises toward −Z. Both match the procedural pieces' directions.
- **Where it lives.** As decision 0188 rules, nothing generated is committed: the high-poly sources are in the
  gitignored `assets/library/prop/{burrow_mouth,dig_stairs}/` and `assets/library/texture/{earth_floor,earth_wall}/`,
  and are re-downloadable by task ID. `tools/make_demo_props.py` makes each prop's game L0 at the furniture budget
  (`burrow_mouth` 1,900 triangles, decimated; `dig_stairs` 1,899, voxel remesh then decimate; 1,024 px baked maps);
  the new `tools/stage_build_art.py` copies each texture byte for byte, only when its SHA-256 is the recorded one,
  into the manifest's new `build` section (`tools/stage_demo_assets.py` runs it; `test_stage_build_art.py` in CI).
- **How it is drawn** (`demo_build_dug.gd use_props`, `demo_build_earth.gd set_textures`):
  - The mouth replaces the procedural mound, 3.0 m across (`demo_props.gd` SIZES): its arch is tall enough for a
    0.90 m mole.
  - The flight is stretched over a landing's 2 × 2 m and the room's 1 m rise for a way up. For a way down it is
    turned about its middle and sunk a room's depth, inside the procedural cut's walls (`Ways.cut_mesh`).
  - The floor texture tiles every 4 m on the floors and on the top; the top is darkened (`TOP_TINT`). The wall
    texture tiles every 2 m.
  - With nothing staged (CI, a fresh clone), every piece keeps its procedural drawing. The checks cover both, and an
    art-free props table.
- **The mouth's arch faces the default heading.** The village camera starts at yaw 0, looking north from the south.
  The mouth opens to +Z, toward that camera; the procedural mound opens the same way. A Way down's landing gives no
  better direction: the landing lies straight under the Entrance.
  - **In the open the model reads as an entrance.** Seen from the default heading at 35°, it is a stone-arched earth
    mound with a dark tunnel mouth (`mouth_in_the_open_default_heading_*.png`, below).
  - **At the loop harness's Entrance, (10, 36), it does not, and no camera fixes that.** An oak's trunk and a fallen
    log stand just south of the mouth, and crowns close over it. The camera allows nothing nearer than 7 m or lower
    than 30° (`demo_camera.gd`). Four headings were tried: yaw 0 at 7.5 m and 32°; 320; 340; and 300. From every one
    the arch is hidden behind the trunk or the log, or the eye is pushed out above the crowns.
  - **The surface frame therefore looks from the west** (yaw 270, 38°, 7 m), the clearest side. It shows the mound
    whole and the arch in profile; from there it reads as a mound, not as a hole.
  - **Nothing was spent to fix it**, and none of the 8 credits left is approved. Moving the harness's loop to an open
    site would show the arch, but it would move every cell the loop paints; that is left for Brendan to ask for.
- **Frames**, at both sizes:
  - Before (procedural): `polish_check/art_before_1280x720/` and `art_before_1920x1080/`.
  - After: `art_after_1280x720/` and `art_after_1920x1080/`. These include the re-aimed `loop_entrance_open_*` and
    `mouth_in_the_open_default_heading_*`, the staged mouth alone on open ground.
  - The textured floors read as packed earth and the stairs as timber treads.
- **The review of the wiring** (independent `code-reviewer` on `b1bb4779`) found no CRITICAL and no HIGH. Fixed:
  - **M1:** the way-down test could not fail on direction. A wedge flight, made both ways round, now checks it.
  - **M2:** the flight's direction was assumed. It is now measured (`rises_north`) and turned if needed. The bought
    flight rises north as delivered.
  - **M3:** the art and its cut shared planes. The flight is laid `ART_INSET_M` (1 cm) inside the landing's sides.
  - **LOW 4:** `set_art` starts again on a second call.
  - **LOW 5:** a flat flight is not drawn.
  - **LOW 7:** the staging tool removes a staged texture that no key names.
  - **LOW 8:** the tool's `main` is checked.
  - **LOW 9:** the texture rows carry `multi_view`, and the model is named `meshy-7.1` with `ai_model: latest` in its
    params.

  Six new mutants over the art logic were all killed. Left as they are:
  - **LOW 6:** the two textures are decoded and mipmapped once, when the panel is built, uncompressed, about 5.6 MB
    each at 1,024 px.
  - **LOW 9, timestamps:** the ledger's six `created` times are the minutes the calls were made, not the API's
    timestamps.
- **No art is accepted.** These are candidates; visual acceptance is Brendan's, through `tools/art_gate.py`.
  `docs/planning/art_approvals.json` was not touched. The request block, for him to paste if he wants the gate:
  `{"id": "ART-BUILD-POC", "what": "Build panel proof of concept: burrow_mouth and dig_stairs props, earth_floor and
  earth_wall textures (decision 1913) -- visual acceptance", "spends_credits": false, "estimated_credits": 0,
  "why_gated": "visual acceptance", "status": "pending", "requested": "2026-10-13", "decided": null,
  "decided_by": null}`.

## Gates

At `c1ab280c` (code), merged with `origin/master` `8e2bc009` (`fe09e6ee`; no content change), Godot 4.7.2, 2026-10-13.

- **Full CI-style run** (`godot/demo/assets` aside, `godot/.godot` deleted, imported with no `handle_crash`;
  `./tools/run_tests_parallel.sh`, 10 shards, 4 jobs): every shard exit 0; verify `ok: 500 suite files executed
  exactly once across 10 shards`; 12,437 tests, 1,229,292 assertions, 0 failures, 0 unexpected errors or warnings,
  0 leaked objects or resources on every shard's `diagnostics:` and `log:` line; 1,399 s. The art was put back and
  re-imported afterwards.
- **Suites touched** (with the art): test_demo_build_dig 15 tests (80 assertions), test_demo_build_panel,
  test_demo_build_works, test_modular_world_view, test_demo_input_live, test_demo_guide_live: 0 failures,
  0 unexpected diagnostics, 0 leaks.
- **Live harnesses, windowed**: demo_build_dig_live 25 / 25 at 1280×720 and 1920×1080; headless demo_input_live
  296 / 296.
- **Analyzer** (`tools/gdscript_warnings.py --max 0 --port 6419`): 0 warnings in 0 of 1,528 files. Functions ≤ 30
  lines.
- **Decision numbers**: PASS, 550 records with this one, 0 problems.
- **Independent review**: E11.
- **Mutation testing** (`scratchpad/polish_check/mut/run.py`, over the tag spread, the earth's holes, walls, chalk,
  stairs and apron, the dug view's level and digging checks, the figure's sink and the trip's dig reads; run against
  test_demo_build_dig and test_demo_build_panel): 29 mutants. The first pass killed 22; the seven survivors (an empty
  rect inside another, the wall beside the digging cell, the digging cell's chalk, a digging cell on another level, a
  quarter-dug landing, the step's scale, the digging tag on another level) were real gaps, each now checked, and the
  second pass killed all seven: **29 of 29 killed, none survived.**
- **Frames looked at**, the whole loop at both sizes, before and after (session scratchpad, not committed):
  `polish_check/before_1280/`, `before_1920/` (decision 1912's look) and `after_1280x720/`, `after_1920x1080/`
  (entrance placed, painted, mole digging, rooms open, visitor inside, and the new entrance open).

## Source

Brendan's request of 2026-10-13 (relayed by the coordinator: "Merge it, then start visual polish"). Decision 1912 and
its rulings. The EG2 study. `docs/ui_ux_controls.md` (words, not colour).
