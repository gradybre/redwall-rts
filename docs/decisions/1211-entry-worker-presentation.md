# 1211 — Entry worker presentation: the stone source, the row program and the surface hand-off alert

Date: 2026-10-06 · Status: Accepted; steps 1–3 implemented

ADR 1197 G8 (remainder) and the presentation half of G5. It builds on ADR 1201 (per-source presentation) and
ADR 1206 (native stone image v9 as runtime source 3). Presentation only: nothing here advances a simulation clock or
grants work, contact or movement.

## Step 1 — the stone image is the fourth presentation source

| Piece | Change |
|---|---|
| `godot/demo/cast/underground_content_set.gd` | `MAX_SOURCES` 3 → **4**. Nothing else changes: each slot still holds one exact-sha image inside the one declared budget. |
| `godot/scripts/core/underground_session.gd` | `STONE_ACTOR_PATH`, `STONE_ACTOR_SHA` (`49ff3018…`, equal to `Pins.STONE_SOURCE_SHA`), `STONE_PRESENTATION_BYTES` = 7,285,004, and `PRESENTATION_SET_BYTES` now sums four images. |
| `godot/data/underground/mole-worker/mole_presentation.gd` | `SOURCE_STONE` = 3, `STONE_MASKS` (v9 `plan.json`: mask 3 on all ten clips), `load_sources(sources, include_haul, include_stone)` over `load_sources_within(…, budget, …)`, and `stone_material()`. |
| `godot/data/underground/mole-worker/mole_haul_program.gd` | The clip ordinals of both haul images (0–7 shared; v8 8–11 stand/walk/enter_haul/leave_haul; v9 8–9 enter_haul_stone/leave_haul_stone). |

**The stone image needs the haul image.** v9 holds no stand or walk; the tool-free stand and walk (rows 30/31)
are v8's, and v9's `enter_haul_stone`@0 is v8's `stand`@8 (the ADR 1206 cross-image join). Asking for stone without
haul refuses `MOLE_PRESENTATION_INPUT`.

**The stone part binds the tunnel dressing's own lump.** `Content.mesh_fingerprint(bore_dressing.gd::stone_mesh(),
0, 70, 1)` is exactly v9's part-1 hash (`e9c10ccc…`), so the Actor binds the shared factory mesh with no copy.

**Stone material (no new art).** The dressing's lump material colours each MultiMesh instance
(`vertex_color_use_as_albedo`); a single Actor part has no instance colour, so v9's replay drew the lump white.
`stone_material()` duplicates that same material (roughness 0.9, back-face culling) and fixes the albedo at the
dressing's own `STONE_COLOUR` with vertex colour off. The dressing's MultiMesh material is untouched, and the derived
material passes `Actor._material_error` (no next pass, grow or billboard). It is bound as a material override on part
1 only; the body keeps its original material.

### Budget and memory census

| Source | Image | Declared peak (B) |
|---|---|---|
| 0 actor | `install-program-compile-v3` (`adc61764…`) | 7,141,920 |
| 1 assembly | `qualified-assembly-v1/compiled-3` (`b94d676e…`) | 6,628,488 |
| 2 wood haul | `native-program-v8` (`cc854271…`) | 7,486,168 |
| 3 stone haul | `native-program-v9` (`49ff3018…`) | 7,285,004 |
| **`PRESENTATION_SET_BYTES`** | plain sum, nothing shared | **28,541,580** (was 21,256,576) |

Each figure is that image's exact `Content.required_peak_bytes()` (retained palette, the larger of a second palette
copy or the 17,172-vertex mesh pass, tables, and the 2 MiB control reserve). It is a declared upper bound, not a
measurement. Retained palettes: 647,752 + 134,848 + 992,096 + 791,028 = 2,565,724 B. This is presentation memory,
outside the 100 MB simulation-owned gate (REQ-SET-163); simulation-owned memory changes by **0 B** in this ADR.
`tools/underground_memory_budget.py` is not changed here.

Refusals are exact: one byte short of the set refuses the stone image with `CONTENT_SET_BUDGET` and keeps the
other three admitted; a reserve below the exact peak refuses `ACTOR_CONTENT_PRESENTATION_RESERVE`.

## Step 2 — rows 29–41 are drawn from the simulation's own selected row

`MolePresentation.present_row(routes, worker, tick, out)` reads the actual Routes actor (`read_actor_into`) on one
fixed tick and draws exactly the row the simulation selected:

- **Row 29** goes through `present_handling`: the handling clock word, as in ADR 1201. Nothing new.
- **Rows 30–41** are drawn from their row program (`mole_haul_program.gd`). The source is the image whose digest is
  the row's Profile source (`ContentSet.source_for_row`), so wood rows draw source 2 and stone rows source 3.
- **Source-0 rows** refuse `MOLE_PRESENTATION_ROW_DRIVER`: they stay with the pinned `mole_profile_driver.gd`
  (ADR 1201). A row whose image is not loaded refuses `MOLE_PRESENTATION_SOURCE_ABSENT`. Every refusal leaves the
  output and the shown Actor unchanged.
- **Masks.** Every draw goes through `present_clip`, which applies the clip's part mask and hides every other source
  (ADR 1198 step 7 rule). The tool-free stand and walk show the body only (mask 1).

### The row program (decision)

There is **no simulation source clock for the haul rows**: Delivery advances a lift or set-down through Work ticks,
and travel through route ticks. The presenter therefore needs its own reading of time. It uses the settlement's
fixed tick (`SettlementSystem.ticks_run()`, passed in as `tick`). When the observed key changes, the program restarts
at that tick. The key is (row, revision, content, Job, in travel), and the program plays on the ticks since then.
It never advances or reads back any simulation clock.

The program is read from the row's own immutable Descriptor (mode and cargo), not from row numbers:

| Kind | Rows | Clips (each once; the last loops or clamps) |
|---|---|---|
| STAND | 30 | v8 `stand` (loop) |
| WALK | 31 | v8 `walk` (loop) |
| CARRY, queued or travelling | 32, 37 | `hold`, `enter`, `carry` (loop) |
| CARRY, idle or held (arrived) | 32, 37 | `exit`, `hold` |
| HAUL load (WORK, no cargo) | 33/34, 38/39 | `enter_haul`, `approach`, `lift` (clamps holding the stock) |
| HAUL unload (WORK, cargo) | 35/36, 40/41 | `hold`, `place`, `recovery`, `leave_haul` (clamps with the stock set down) |

The clip lists are the derived rows' own (`haul-rows-v1` and `stone-rows-v1` `rows.json`: CARRY covers
hold/enter/carry/exit, load covers approach/lift/recovery, unload covers hold/place/recovery). The two joins are the
native-replayed ones (stand@8 → enter_haul → approach, recovery → leave_haul → stand@8). Clips play at their own
authored durations (Q16 ticks), which ADR 1198 tied to the adopted ground pace cap.

**Known limits.** These are presentation-only, and nothing here hides them:

- A lift or set-down clip can end before or after the Work ticks that complete it. The final pose then holds, or the
  row changes mid-clip.
- A row change cuts between clips with no blend. For example, CARRY → unload goes from `exit`/`hold` to `hold`.
- A frame equation that would span two masks is still refused (ADR 1201).

A simulation-side haul source clock, like row 29's handling clock, would remove the first limit. It is not built.

Tests: `godot/test/test_entry_worker_presentation.gd`. A real tool-free mole hauls one staged stone unit through
Delivery on the real content-6 bank, and each stage is drawn from the actual selected row:

- WALK 31 (source 2, walk, mask 1);
- the wood lift 34 (source 2, `enter_haul`);
- the stone lift 39 (source 3, `enter_haul_stone` → `approach` → `lift`, clamped);
- CARRY 37 in travel (`hold` → `carry`, looping), then on arrival (`exit`);
- the set-down 41 (`hold` … `leave_haul_stone`, clamped).

Each draw checks the source, the clip, the mask and that every other Actor is hidden. With the stone image absent,
row 39 refuses `MOLE_PRESENTATION_SOURCE_ABSENT` and the shown wood Actor keeps its pose. In
`test_mole_presentation.gd`, `present_row` routes row 29 through the handling clock.

## Step 3 — the live demo composes the worker, and G5's presentation half

### Composition (G8 remainder)

`godot/demo/cast/entry_worker_view.gd` is added once at boot (`demo_village.gd::_build_entry_worker`, right after the
cast). The boot now loads all four images (`load_sources(sources, true, true)`), because content 6 publishes the
wood and stone rows. Composition then works like this:

- **One Actor per loaded source**, hidden, built by `MolePresentation.configure_actor`. The meshes come from
  `godot/demo/cast/entry_worker_meshes.gd`, which builds only factories that already exist:
  - the staged `mole_digger` import through the approved hand derivative (`mole_grip_source.gd`, with
    `pick_fit()` pinned by `FIT_DIGEST`) is the body of all four sources. All four images carry `DERIVED_DIGEST` as
    part 0.
  - `mole_pick` is part 1 of sources 0 and 1.
  - v8's stock factory is part 1 of source 2. Its cylinder and its own material are the replay's, and the
    fingerprint `cb0bf551…` matches.
  - the dressing lump is part 1 of source 3, with the derived stone material from step 1.
- **Exactness is checked by the Content, not trusted.** Every part goes through `mesh_binding_refusal`. A wrong
  mesh refuses, and nothing is drawn in its place.
- **A composition refusal disables drawing.** Examples are unstaged assets (`ENTRY_WORKER_ASSETS_NOT_STAGED`) or a
  fingerprint mismatch. The refusal is kept and raised as an alert only when the crew's resident is a Routes actor
  that would need drawing. A headless run's `UNDERGROUND_RENDERER_UNAVAILABLE` is the environment, not a game gap,
  so it is not alerted.
- **Placement uses the Actor's local path.** No World basis (`world-yaw-v1.ugyaw`) is staged in the demo. The view
  sets the shown Actor node to the actor's integer point (÷1024 m) and to `Basis(UP, yaw·2π/65536)`, the same
  expression `tools/bake_underground_world_basis.gd` tabulates. This is presentation, not the native-certified
  world equation.
- **Memory census.** There are four Actor nodes for the one entry worker: four skeleton RIDs, one shared derived body
  mesh and three small held meshes. Only one Actor is visible at a time. That is within the 24-skeletal-actor
  ceiling (it uses 4) and adds no simulation-owned bytes. The Content palettes are the step 1 reservation, shared
  by every Actor of a source, never copied.

Each frame, `advance(SettlementSystem.ticks_run())` reads `SettlementSystem.underground_entry()`. Before crew
selection (today G11 stops it) nothing is drawn. Once the crew's resident is a Routes actor, `present_row` draws it
(step 2). A source-0 row raises `MOLE_PRESENTATION_ROW_DRIVER` once: the live driver hookup for the tooled cut rows
is not built here (see Remaining).

### G5 — what is built (presentation) and what the simulation hand-off still needs

**Built.** With a crew chosen and its resident not yet a Routes actor, the view picks the first cast actor drawn
with the `mole_digger` body (the body every source image was compiled from). Through the demo's existing surface
walk (`DemoCast.order_move`), it sends that actor to the stair-top anchor H. H is work-area endpoint 0,
`WorkArea.point(origin, 0)`, converted at 1,024 units per metre with −Z forward in both frames. The walk is ordered
once. On arrival (within 0.75 m on the ground plane) the view raises **`ENTRY_SURFACE_HANDOFF_UNBUILT`** once
through `UIManager.push_refusal`, with gap row G5 (`EntryWorkerView.gap_of`). Nothing is placed, admitted or moved
in the simulation. When the resident later becomes a Routes actor, the walker is released back to wandering and the
underground Actor takes over.

**Still needed in the simulation** (another worker's scope: the entry runtime, `settlement_system.gd` and
Movement):

1. **Surface Movement and Navigation are composed**, so the chosen resident's settlement Transform actually walks to
   H. Today residents do not walk in the simulation (`settlement_system.gd`'s ARCH-SYS-011/012 notes).
2. **The resident's Transform is placed exactly on H's point**: `Transforms.place(worker, H.x, H.y, H.z, yaw)` with
   `H = WorkArea.point(origin, 0)`, integers, no rounding. That is the precondition of every Routes admission
   ("register only an already positioned actual actor").
3. **Routes admission at endpoint 0** (`published.endpoints[0]`):
   - a tooled mole uses `routes.admit_travel_actor(worker, job, endpoints[0], <source WALK row>, 1,
     content_revision, POSTURE_UPRIGHT, -1, tool)`, which ADR 1197 G5 names. It admits only source-program rows.
   - a tool-free hauler uses `routes.admit_actor(worker, job, endpoints[0], MODE_WALK, 0, -1)`, as the ADR 1206
     Delivery test admits it on R.
4. **A real route underground** from H (`request_route` over the published work-area edges).
5. **Exposing the crew.** The entry runtime should give a read-only accessor for the crew (`crew()`). The view
   reads the runtime's `_crew` field today, because that file is outside this change.

The alert clears in effect once 2 and 3 exist: the resident is then a Routes actor and the view stops walking and
draws instead.

**Assumption, recorded:** the village's metre frame and the settlement's unit frame share their origin, because
both are metres with −Z forward. If the generated settlement is ever offset from the village ground, the anchor
conversion is the one place to change.

### Remaining (not in this ADR)

- **Source-0 rows in the live demo.** These are the tooled cut rows 0–28 other than 29. They are drawn by the pinned
  `mole_profile_driver.gd` (`read_route_into`), which needs configuring per crew with its pins and tool. Until then
  they alert `MOLE_PRESENTATION_ROW_DRIVER`.
- **A simulation-side haul source clock** (step 2's known limits).
- **The native world basis in the demo staging**, if the exact native world equation is wanted over the local
  path.
- **The underground render layer** for these Actors (they use the default layer today).

## Tests

`godot/test/test_mole_presentation.gd` (step 1): four pinned images at their exact peaks and the new set sum; the
stone digest equals the catalog's; stone clip masks and spans; stone optional and dependent on haul; the dressing
lump's exact fingerprint and the derived material; stone clips shown only on the stone Actor; the one-byte-short
budget refusal.

`godot/test/test_entry_worker_presentation.gd` (step 2): the real stone haul drawn row by row, and the absent-image
refusal.

`godot/test/test_entry_worker_view.gd` (step 3):

- **G5 on the real ADR 1197 chain.** A generated settlement stops at G4 with its crew chosen, using the G11 test
  stand-in tool. The crew's resident is not a Routes actor. The walk is ordered once to H in metres. A metre short
  is not arrival, arrival raises `ENTRY_SURFACE_HANDOFF_UNBUILT` exactly once, and the gap rows map.
- **No crew.** Before crew selection nothing is drawn.
- **No cast mole** raises `ENTRY_WORKER_NO_CAST_MOLE`.
- **An admitted worker** on the real stone haul is drawn on its own row and placed on its point and heading.
- **Unstaged assets** refuse composition, and the alert waits until the worker needs drawing.
- **Mesh factories.** The stock and stone factories and the pick fit equal their images' pinned fingerprints, and
  all four bodies are the approved derivative.
