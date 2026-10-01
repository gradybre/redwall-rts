> **External review of this repository at commit 157a3a4** (157a3a461c8cca0070ef1fb666d3c4bce5923951), dated 30 September 2026, kept verbatim below this line; its approval log is decision 0493.

# Redwall needs clearer decisions and consequences

Reviewed **30 September 2026**, at frozen commit **157a3a461c8cca0070ef1fb666d3c4bce5923951**, only in `/Users/brendan/Developer/redwall-review`.

The demo has a distinctive foundation—cooperative woodland work, physical hauling, species-aware crossings, underground routes and seasonal growing—but its systems do not yet form a dependable, understandable colony experience. This expanded audit records **53 distinct findings**: route/job/resource failures, measurable interface loss at the minimum viewport, contradictory stocks and identities, missing management/food/session interfaces, and specific asset-contact and lifecycle problems. The most consequential reproduced failures lose a harvest, abandon a crew or saved job, enter a now-forbidden crossing, or delay rescue until the victim runs out of air. The UI’s central problem is information ownership and hierarchy: unrelated settlement data, diagnostics, future content and ordinary actions compete while the player’s current intent disappears. The strongest next milestone is **one believable community day that culminates in a meal and leads into seasonal preparation**, supported by truthful work, stock and incident interfaces. Nine reviewable plans below make that direction concrete, including a 16-surface information map, proposed copy, wireframes, phased work and acceptance cases.

This is a read-and-report audit and a set of proposals, not implementation approval. No code fix, commit, push, export or paid asset generation was performed. The main checkout and `/private/tmp/claude-501/` were not used for review work; the supplied main-checkout asset library was read only by the authorized staging command. Underground rooms, burrow homes, root cellars and Windows export remain excluded. Godot automatically reserialized `godot/project.godot` when its editor opened. After closing the editor, that worktree file was restored byte-for-byte from the frozen commit using `git show` and a direct file write, with no checkout/reset. Final checks after the last probe confirmed detached HEAD at the full commit above, empty tracked working-tree and index diffs, and no remaining review Godot process. Only untracked `REVIEW.md` and `.review-artifacts/` remain; nothing was committed or pushed.

## Read the evidence before treating a finding as reproduced

The requested instructions and references were read: AGENTS.md, CLAUDE.md, docs/ENVIRONMENT.md, the demo README, underground_revamp.md, decisions 0196 and 0205–0208, and the September 29 playtest. The expansion traced farm/forestry work, selection/focus/layout, pantry/session controls, rescue/incidents, asset support/lifecycle and adopted gameplay, UI and art direction. Primary developer sources support the game comparisons. Those are design lessons, not controlled evidence of player preference, retention or commercial success.

**Evidence labels matter.** “Visually verified” means inspected in the running scene. “Reproduced” means actual production components or handlers were exercised, often using deterministic fixtures; injected failures are identified. “Measured layout” means real Control rectangles, visibility and clipping in the loaded scene, not image-quality judgment. “Measured geometry” means transformed staged mesh triangles compared with terrain, not automatic proof an underwater gap is visible. “Reading only” and “design assessment” are not disguised as playtest observations. Missing-feature severity concerns the playable demo, not the absence of all related production kernels from the repository.

The full suite ran in the original pass at this same frozen commit. The actual summary line was:

```text
ok: 6161 tests, 546171 assertions, 0 failures.
```

This expansion adds focused probes; it does not claim the full suite was rerun. Its log had no `SCRIPT ERROR`, but contained 53 `ERROR` and 359 `WARNING` entries, including negative-fixture diagnostics and a shutdown warning about 1,067 ObjectDB instances and 11 resources. Zero failed assertions does not mean a silent process. Those test-process diagnostics were not attributed to the playable scene; a separate startup run was clean.

| Check | Actual result | Evidence limit |
|---|---|---|
| `./tools/run_tests.sh` | 6,161 tests, 546,171 assertions, 0 failures | Broad existing regression coverage; related unit tests can still bypass the failing handoffs. |
| `godot --headless --path godot --editor --quit` | Passed before staging and after imports settled; no ERROR/SCRIPT ERROR in completed checks | Import/parse check, not gameplay or performance acceptance. |
| `python3 tools/stage_demo_assets.py --library /Users/brendan/Developer/redwall-rts/assets/library` | 102 world assets and 9 creatures staged | Real ignored assets available in the detached worktree. |
| `python3 tools/demo_texture_imports.py --godot godot` | 111 color, 110 normal, 110 roughness maps compressed; 44 images kept as files | Import preparation, not visual approval. |
| `godot --headless --path godot demo/demo_village.tscn --quit-after 180` | Exit 0, no logged errors/warnings | Startup and loading only. |
| Six original targeted probes | Documented graph/brain/crew/water failures and capacity mismatch | Source embedded in Appendix C; one navigation failure deliberately injected. |
| New farm/UI/forest/rescue probes | Conservation, stale state, modal input, incident flood, dispatch and retention failures | Findings describe actual production path and fixture; no claim all were mouse-driven. |
| Actual all-nine group move benchmark | 24 accepted; median 17.3645 ms, p95 25.644 ms, max 26.079 ms | Synchronous CPU command time under uncontrolled shared load, not frame-p95 or sim-tick. |
| Rendered native performance samples | Focused 20 s phase p95 intervals: village 21.194 ms; group moves at 4× 17.587 ms; wide forest 11.618 ms | Process-frame callback wall intervals, not GPU/present timestamps; uncontrolled shared host, no hardware qualification. |
| Actual Controls at 1920×1080/1280×720 | Party content collapses; nine-person frame disappears at 720p; water controls below fold | Objective layout/visibility; not font contrast or rasterization. |
| 210.095-second idle soak at 4× | About 14 demo days, Spring 1 → Summer 3; no pause or logged ERROR/SCRIPT ERROR | Short stability check. Nodes 1,914 → 1,915 then stable; objects 7,204 → 7,214; static memory ~1.4735 GB largely flat. No long-session leak or GPU clearance. |

In that soak, all six beds were bare by Spring 9; pantry peaked at 18 U and ended at 8 U. This is an unattended trajectory, not a validated difficulty curve, proof auto-replanting should be mandatory, or a consumption forecast. It illustrates the need to explain production, loss and the next useful task.

The original live pass used Godot 4.7.2, Metal/Forward+ on an Apple M5 Pro and viewports reported as 1918×1079 and 1281×721. It inspected the village, HUD, Tunnels, Water, roster and resident detail. The expanded pass used 1920×1080 then 1280×720 and directly inspected Pantry, crop picking/sowing, Woods, Water, group selection and Menu. Plant→Radish→Sow queued assigned the actual fieldworker and later displayed “Being sown”; the success notice said the field crew would see to it. Basic sowing therefore has a working, visible path, even though later conservation and management boundaries fail. At 4×, reading and operating panels advanced the calendar from day 1 to day 2; this was observed pacing, not a measured usability verdict.

The central buildings, props and cast looked coherent and grounded in the inspected sun/rain views, with no obvious missing-texture placeholders. A separate camera-only review harness exposed the weir’s disconnected raised-diorama appearance (F41). That view used the real scene, clear weather and pause, with explicit test-camera positioning. It did not change production code. Surface entrances, crouching, every species’ contact animation, complete visual rescue/build sequences and sound have not received full acceptance. The original debugger showed 404 combined diagnostics; inspected samples included integer-division warnings, and this report does not call them 404 runtime failures. The expanded controlled views also reproduced foliage occlusion (F53) and inspected frost treatment (F42); their fixture and visibility limits are explicit in those findings.

Severity follows behavioral/player impact except where [CLAUDE.md:142](/Users/brendan/Developer/redwall-review/CLAUDE.md:142) explicitly grades hot-loop allocations and memory leaks CRITICAL. F01 and F18 use that standards classification; they do not claim catastrophic observed crashes. HIGH readiness gaps are labeled separately. Original findings retain F01–F17; new ones use F18 onward. The list is globally severity-ranked, so IDs are intentionally not consecutive down the page.

## Fifty-three findings identify where trust breaks

| ID | Severity | Finding |
|---|---|---|
| F01 | CRITICAL | Crew following and selection polling allocate in frame paths |
| F18 | CRITICAL | Repeated tree felling and regrowth retains hidden scene nodes |
| F02 | HIGH | An underground destination becoming unreachable causes an out-of-bounds error |
| F03 | HIGH | Helpers abandon the crew at a segment boundary, depending on cast order |
| F04 | HIGH | Completing a dig does not resume saved unfinished work |
| F05 | HIGH | A failed walk is accepted as arrival, allowing remote spoil work |
| F06 | HIGH | Synchronous route planning can consume many render-frame budgets |
| F19 | HIGH | A full store destroys the harvested crop instead of leaving a recoverable load |
| F20 | HIGH | At 720p, selecting the full cast hides the entire party inspector |
| F21 | HIGH | Harvesting cannot culminate in feeding the visible community |
| F22 | HIGH | Automatic labor remains split into hidden fixed crews |
| F23 | HIGH | The playable session has no demonstrated save-and-resume contract |
| F07 | MEDIUM | Turning swim shortcuts off does not stop a previously planned water entry |
| F08 | MEDIUM | Mouth capacity blocks valid underground-only expansion |
| F09 | MEDIUM | Transition tests bypass the exact handoffs that currently fail |
| F10 | MEDIUM | The top bar and playable resource economy give conflicting information |
| F11 | MEDIUM | Important demo warnings expire without a unified place to recover them |
| F12 | MEDIUM | Water controls are buried under an unfiltered, non-interactive resident roster |
| F13 | MEDIUM | Fishing has a model and scenery but no completed player-to-pantry loop |
| F14 | MEDIUM | Residents and minimap do not describe the playable village |
| F24 | MEDIUM | Cancelling a harvest bypasses travel and instantly delivers its cargo |
| F25 | MEDIUM | Interrupting and transferring sapling planting pays the compost cost twice |
| F26 | MEDIUM | Pantry leaves world order input active behind its large overlay |
| F27 | MEDIUM | Pantry “spoils in N h” is not a calendar-hour forecast |
| F28 | MEDIUM | Fractional inventory is displayed as zero and pantry totals disagree |
| F29 | MEDIUM | Menu opens the New Settlement creator; the running demo lacks a normal session/settings entry point |
| F30 | MEDIUM | Demo action controls cannot be reached by keyboard focus |
| F31 | MEDIUM | Party text clips critical intent, while group and resume lists have no expansion path |
| F32 | MEDIUM | There is no usable common work queue or job assignment interface |
| F33 | MEDIUM | Action buttons omit costs, consequences, and useful disabled reasons |
| F34 | MEDIUM | Farm units and labels mix raw simulation scales with player-facing percentages |
| F35 | MEDIUM | The demo panels ignore the shell's UI scaling model |
| F36 | MEDIUM | Crop picker eligibility and its date freeze while the live calendar advances |
| F37 | MEDIUM | Resolved dry/wet conditions do not re-alert when they recur in the same season |
| F38 | MEDIUM | One low-air event replaces the entire village-news history |
| F39 | MEDIUM | Rescue chooses a nondiver for a submerged victim while a diver is available |
| F40 | MEDIUM | Tree footing uses a radial estimate that does not match visible roots |
| F41 | MEDIUM | The weir sits as a disconnected diorama without bed or bank support |
| F42 | MEDIUM | Frost and snow use a flat camera-following sheet across water |
| F43 | MEDIUM | No demo sound integration was found |
| F44 | MEDIUM | Selection changes assignment semantics without a common preview |
| F45 | MEDIUM | No overview connects local conditions to village priorities |
| F46 | MEDIUM | Pantry gives inactive recipe prose priority over usable stock decisions |
| F47 | MEDIUM | Overlay cycling hides the active question and misrepresents mixed groups |
| F48 | MEDIUM | Ambient professions and props imply productive actions they do not own |
| F49 | MEDIUM | The demo has many verbs but no integrated first-session objective path |
| F53 | MEDIUM | The camera enters opaque foliage and selected workers disappear under canopies |
| F15 | LOW | A bridge access failure names the wrong resident after clearing its builder |
| F16 | LOW | Surface tunnel entrances depict a dark strip rather than the traversed ramp |
| F17 | LOW | Underground walking still relies on a deformed normal walk rather than a crouching gait |
| F50 | LOW | Debug/scenario actions occupy primary player interfaces |
| F51 | LOW | Ground and water materials apply a UI-only palette constraint |
| F52 | LOW | Tree growth jumps abruptly from sapling to mature silhouette |

### F01 — CRITICAL — Crew following and selection polling allocate in frame paths

**Location:** [underground_graph.gd:1524](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/underground_graph.gd:1524), `underground_graph.gd:1545`, `tunnel_crew_task.gd:88`; also `demo_waterplay.gd:290` → `demo_command.gd:507`.

**What goes wrong:** each moving crew helper calls `piece_offset_m()` and `piece_locate_into()`. Each creates and fills a fresh `PackedInt32Array`, then reconstructs the piece chain. `piece_segments_into()` repeatedly scans the segment table through `first_of_piece()`/`next_in_piece()`. This happens during brain substeps. The water controller also calls `selected()` every rendered frame, which constructs a new packed array, before determining whether the selection changed.

**Trigger:** keep several helpers following a dig through a segmented piece, especially at 4×, or leave residents selected while the water controller processes. The same unchanged topology/selection is repeatedly reconstructed. This violates the explicit hot-loop rule and consumes avoidable frame budget; the helper cost also grows with chain length and table occupancy.

**Suggested fix:** cache ordered segment chains and cumulative offsets by topology revision, or traverse into persistent scratch buffers without rebuilding them per helper. Expose a selection revision and a cached selection/read-into API; only rebuild on a selection change. Profile the resulting frame paths at 1× and 4×.

**Evidence:** **reading only**, traced from `demo_cast.gd:57` → `demo_actor.gd:247` → brain/task stepping, and `demo_waterplay.gd:245` → `_follow_selection()`. Allocation sites are explicit. No measured allocation count or budget overrun is claimed.

### F18 — CRITICAL — Repeated tree felling and regrowth retains hidden scene nodes

**Location:** [forest_view.gd:318–321](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_view.gd:318). `_start_fall` assigns newly created lower/upper nodes over the existing array entries. [_forget_parts:180](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_view.gd:180) frees only the current entries, and its caller is `_replace_tree_node`, which runs when the look changes. Ordinary same-species regrowth does not take that path.

**Trigger:** fell an oak, haul its wood, let its 48-day regrowth complete, fell it again. Repeat during a long-lived village. Old parts remain hidden children even after their array references have been overwritten.

**Observed:** four production `fell_into → view.sync → view.advance → take_trunk_into → regrow_due → view.sync` cycles on a real staged oak produced direct child counts **10, 12, 14, 16**. The first lower node was still parented, was no longer the current `_lower_nodes[0]` reference, and was hidden. Deferred frees were allowed to run between cycles. This is retained attached state, not an orphan-node claim; meshes remain shared. No process-memory growth in MB was measured.

**Suggested fix:** reuse each tree's cached parts across cycles, or explicitly free/replace both old parts before creating new ones. Regression: after warmup, 20 complete fall/regrow cycles keep node counts and owned resources bounded, including species replacement and uprooting.

**Evidence:** actual staged asset and production lifecycle, with accelerated calendar dates. [Probe](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.gd), [output](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.log). `CLAUDE.md` grades memory leaks as CRITICAL; practical impact here is long-session retention, not a demonstrated immediate crash.

### F02 — HIGH — An underground destination becoming unreachable causes an out-of-bounds error

**Location:** [resident_brain.gd:894](/Users/brendan/Developer/redwall-review/godot/demo/cast/resident_brain.gd:894), `resident_brain.gd:598`; `tunnel_router.gd:250`.

**What goes wrong:** `_replan_or_abandon()` calls `_plan_trip()` and then `_begin_leg()` unconditionally. Unlike a failed surface route, a failed route to an underground node is empty. `_begin_leg()` indexes `path[0]`. The brain remains in a walking/turning state with an empty route instead of reporting failure or recovering. The initial `_start_trip_below()` checks for an empty path; this retry path does not.

**Trigger:** send a resident toward a node below ground, then close the routes into that component before it reaches the entrance. On reaching the now-unusable entrance, its ordinary walking update replans and errors.

**Suggested fix:** make planning success explicit and handle an empty/unreachable result before starting a leg. Preserve or suspend the job appropriately, release reservations, and give the player a blocked-route reason. Apply the guard to all route-start/retry entry points.

**Evidence:** **reproduced by headless integration probe**. An open 12 m tunnel initially produced two waypoints. Both entrance routes were closed; normal `brain.step()` calls then produced:

```text
SCRIPT ERROR: Out of bounds get index '0' (on base: 'PackedVector2Array')
  at: _begin_leg (res://demo/cast/resident_brain.gd:598)
  _replan_or_abandon → _enter_tunnel_leg → _leg_handled → _step_walk → step
```

The resulting path size was 0 and the brain remained in `WALK`. The probe uses the production `task_walk_to_node()` entry point, not a visual click sequence.

### F03 — HIGH — Helpers abandon the crew at a segment boundary, depending on cast order

**Location:** [tunnel_crew_task.gd:63](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_crew_task.gd:63), `tunnel_works.gd:278`, `resident_brain.gd:1733`.

**What goes wrong:** the lead opens one segment and immediately starts the next during its brain update. A helper processed afterward still has the old `member_site`. `crew_active(old_segment)` is now false, so its task finishes and removes it from the crew. The migration in `TunnelWorks._watch_opening()` happens afterward and has nobody left to move.

**Trigger:** select a lead that appears before its helpers in cast order, assign the group to a new multi-segment dig, and let it finish the entrance ramp. The lead proceeds alone while helpers stand down. Cast processing has priority −10 and advances all actors before `tunnel_ext._process()` steps the works, so this is the live scheduling order, not merely a hypothetical interleave.

**Suggested fix:** migrate the crew synchronously with the segment transition, or resolve the active segment of its piece before a helper decides that the job ended. Keep the scheduler contract explicit and test both lead/helper ordering permutations and multiple substeps at 4×.

**Evidence:** **reproduced by headless integration probe** using real brains, `TunnelWorks` and `TunnelCrewTask`, stepping lead, helper, then works. On the first ramp opening: lead moved to segment 1, helper membership changed from 0 to −1, helper task became empty, and the piece was still unfinished.

### F04 — HIGH — Completing a dig does not resume saved unfinished work

**Location:** [resident_brain.gd:1743](/Users/brendan/Developer/redwall-review/godot/demo/cast/resident_brain.gd:1743), `resident_brain.gd:1750`, `resident_brain.gd:1769`.

**What goes wrong:** dig completion checks for another segment and queued dig, then walks out and holds under `ORDER_MOVE`. It never calls the general completion/resume path for saved jobs. The panel can continue promising “Then back to…” while the resident holds indefinitely.

**Trigger:** interrupt a resumable job with a fresh dig. Finish that dig and all its queued pieces. The previous job remains on the stack but is not taken back up.

**Suggested fix:** after finishing queued digs and safely stepping clear of the mouth, invoke the normal unfinished-job completion logic. Preserve the distinction between completing work and the player's explicit R/release, which intentionally forgets saved jobs. Cover both surface-ending and underground-ending pieces.

**Evidence:** **reproduced by headless integration probe**. The real graph/brain completed a 12 m piece after interrupting the existing resume suite's `CountedTask` fixture. After 200 simulated seconds: `piece_done=true`, `order=MOVE`, `state=HOLD`, `task_resumed=false`, and `saved_jobs=["unfinished lanterns"]`. This verifies the completion handoff with a resumable task fixture, not a literal lantern-building playthrough.

### F05 — HIGH — A failed walk is accepted as arrival, allowing remote spoil work

**Location:** [spoil_crew.gd:228](/Users/brendan/Developer/redwall-review/godot/demo/spoil/spoil_crew.gd:228), `spoil_crew.gd:251`; the same assumption appears in `waterplay/bridge_crew.gd:212`.

**What goes wrong:** spoil work starts whenever a worker is in `HOLD` with the expected move order/goal. The brain also enters `HOLD` after abandoning an unreachable trip, retaining that goal. No proximity check distinguishes arrival from failure. The worker can dig a heap remotely, and the corresponding carry/drop path has the same weakness. Bridge work likewise treats `HOLD` as source/site arrival.

**Trigger:** a heap's approach or its drop route becomes obstructed after assignment and the brain exhausts its replans. The crew advances from walking to productive work at the worker's actual, incorrect position.

**Suggested fix:** use an explicit arrival outcome plus a proximity check against the reserved work spot. A failed route should pause/reassign the job and give feedback, never credit work or a delivery. Recheck the goal/position while working as well as on arrival. Apply the same contract to bridge source and site transitions.

**Evidence:** **spoil transition reproduced in a headless probe with an injected navigation failure**. After the real crew issued its walk, the probe invoked the brain's production `_abandon_trip()` failure transition 2.64 m short of its goal. Normal stepping then removed a 2,000 milli-U load while the worker was 4.28 m from the heap centre. I did not independently arrange a physical obstruction to exhaust the retries. The bridge extension is **reading only**, not a separately reproduced remote bridge completion.

### F06 — HIGH — Synchronous route planning can consume many render-frame budgets

**Location:** [tunnel_router.gd:243](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_router.gd:243), `cast_space.gd:584`, `resident_brain.gd:894`; supporting measurement in `docs/decisions/0208-the-tunnels-are-one-network-graph.md:193`.

**What goes wrong:** the graph/surface route search and refinements run synchronously inside a resident command or brain update. There is no frame-time budget or pending-route state. Multiple residents ordered or replanning together add their costs in one frame.

**Trigger:** issue a group move through the obstacle-heavy village/network, or cause multiple residents to replan after a closure. The existing decision's 400-trip benchmark reports graph-router p95 **125.3–127.4 ms** and median **9.1 ms**. The document attributes this to the surface planner, so this is an existing demo bottleneck rather than evidence that the new graph made routing slower.

**Suggested fix:** budget and schedule path requests across frames, preserving a visible “finding a route” state; cache reusable static navigation work and bound refinement. Measure actual rendered p95/p99 with simultaneous orders and closures, at 1× and 4×. A <250 ms route-ready target does not authorize spending that entire latency on the render thread.

**New evidence:** **actual staged-demo production-command timing**. With all nine residents selected, the real `cast.order_move` was invoked to eight fixed surface goals, repeated three times, with starting positions held fixed and no constructed tunnels. All 24 requests were accepted. Conventional median was **17.3645 ms**, nearest-rank p95 **25.644 ms**, maximum **26.079 ms**, minimum **4.792 ms**; **12/24 calls exceeded 16.67 ms**. This is synchronous CPU duration, under uncontrolled shared-machine workload, not rendered frame-p95 or simulation-tick timing. The probe’s printed p50 uses the upper middle sample (20.134 ms); the conventional median above was recomputed correctly. [Probe](/Users/brendan/Developer/redwall-review/.review-artifacts/group_order_probe.gd), [log](/Users/brendan/Developer/redwall-review/.review-artifacts/group-order.log).

**Historical evidence:** the earlier repository benchmark above was not rerun. A slow route is not by itself proof that overall frame p95 fails, because route frequency matters. It is a concrete hitch risk against the 16.67 ms frame target, and cannot be certified by headless unit tests or the <2 ms simulation-tick target.

**Rendered follow-up:** two native-window samples were also collected. The focused repeat’s p95 process-frame intervals were **21.194 ms** in the central village at 1×, **17.587 ms** with periodic group moves at 4×, and **11.618 ms** in a wide forest view at 1×. These exceed the 16.67 ms target in two of the three local phases, but phase-to-phase and run-to-run variability prevents a causal attribution to routing or forest cost. They are wall intervals between `process_frame` callbacks, not GPU timestamps or presentation-deadline capture. The performance section preserves both runs and all qualification limits; no <2 ms simulation-tick conclusion follows from them.

### F19 — HIGH — A full store destroys the harvested crop instead of leaving a recoverable load

**Location:** [farm_crew.gd:374](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:374), [farm_crew.gd:407](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:407), [farm_crew.gd:432](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:432).

**Trigger:** Covered store contains 399 U of wheat, leaving 1 U in its 400 U capacity. Harvest the ripe carrot bed yielding 5.1 U.

**What goes wrong:** The harvest consumes the standing crop before finding a suitable store. No store can accept the complete load. `_finish()` calls `_deliver_load()`, which clears the carried quantity before unsuccessful storage writes, then closes the job. The crop becomes empty and neither the pantry nor the worker retains the food. The notice says only “No room in any store for the carrot.” The player cannot recover it by making space.

**Evidence:** **Reproduced.** Real `crew.order(HARVEST, 2, [3], PLAYER)` and normal cast/crew stepping finished with `stage_before=4`, `stage_after=0`, `pantry_carrots_milli=0`, `carried_milli=0`.

**Suggested fix:** Reserve destination capacity before irreversible harvesting, or retain the physical load and a blocked delivery task. Make partial acceptance explicit. If no store is available, show the shortage before cutting, preserve the crop/load, and provide a jump-to-storage action. Add conservation tests across full storage, storage becoming full while hauling, cancellation, and reassignment.

### F20 — HIGH — At 720p, selecting the full cast hides the entire party inspector

**Location:** [demo_party_panel.gd:303](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:303), [demo_party_panel.gd:320](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:320).

**Trigger:** Use the demo at 1280×720. Select one resident, then select all nine.

**What goes wrong:** `_fit()` progressively removes help, skills, and orders; if the remaining panel still does not fit it hides the whole frame. No alternative scroll, expand, compact inspector, or selection summary preserves its information/actions. A user has less feedback precisely when controlling a larger group.

**Evidence:** **Measured on the real staged scene** in [.review-artifacts/layout_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/layout_probe.gd) and [.review-artifacts/layout-results.json](/Users/brendan/Developer/redwall-review/.review-artifacts/layout-results.json). Selected Mousekeeper has 631 visible text characters at 1920×1080, but only 45 at 1280×720: essentially title/name/wandering/Dig. Selecting all nine hides the entire party frame at 720p; 528 characters remain at 1080p. These are Control visibility/layout measurements, not a screenshot impression.

**Suggested fix:** Reserve a stable compact selection summary and always-visible primary actions. Put details in a vertically scrollable inspector or expandable section, keep the selected count and current order visible, and allow browsing individual members. Test minimum resolution with 1, 6, and 9 residents plus concurrent notices and details.

**Expanded live check:** at 1280×720, box-selecting the central group made the party panel disappear entirely. The full-nine measurement above remains the exact controlled layout case; the visual observation confirms the practical group-selection failure.

### F21 — HIGH — Harvesting cannot culminate in feeding the visible community

**What goes wrong and triggering scenario:** A successful harvest cannot complete the fantasy of feeding the visible residents. After delivering carrots, the player can inspect hypothetical dishes or wait for spoilage, but cannot order a meal for this cast. There is no consumption method in the demo pantry's public surface.

**Suggested fix and source locations:** Complete one harvest→cooking→serving→need loop, then preservation; do not label raw total U as ready food-days. **Missing integration**, not a regression. [farm_pantry_panel.gd:9/37](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:9), [farm_pantry.gd:174](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:174); Plan P3.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository. This HIGH severity is a product-readiness judgment. It is separate from the reproduced HIGH correctness failures.

### F22 — HIGH — Automatic labor remains split into hidden fixed crews

**What goes wrong and triggering scenario:** The demo does not let the player manage the labor model its colony-builder shell promises. Queue a bed job with nobody selected: only the fieldworker/gatherer routinely claim it. Queue woods work: a separate fixed crew claims it. Other residents may visibly wander even though useful work waits.

**Suggested fix and source locations:** Expose the actual crews and pending jobs immediately; then connect priorities, schedules, safety and manual overrides through a common owner. **Adopted direction, incomplete playable integration.** [farm_crew.gd:6/35](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:6), [forest_crew.gd:7/42](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_crew.gd:7), [GDD eligibility](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:362); P2.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository. This HIGH severity is a product-readiness judgment. It is separate from the reproduced HIGH correctness failures.

### F23 — HIGH — The playable session has no demonstrated save-and-resume contract

**What goes wrong and triggering scenario:** The save browser/rows are gated with “needs the save codec (task 09)”, and the demo state has no discovered save binding in its bootstrap. A player investing in routes, harvests and bridges cannot assume the menu will preserve that work.

**Suggested fix and source locations:** Establish a truthful session-continuity contract and test the *demo's actual state* across quit/reload. A settlement save elsewhere is not evidence that this presentation world is saved. [ui_availability.gd:108/219](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:108), [demo state bootstrap](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:74), [save requirements](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:812); P9.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository. This HIGH severity is a product-readiness judgment. It is separate from the reproduced HIGH correctness failures. No save → quit → reload sequence was performed. The actual Menu destination was exercised in a handler probe and visually (F29); no corrupt-save or observed lost-progress claim is made.

### F07 — MEDIUM — Turning swim shortcuts off does not stop a previously planned water entry

**Location:** [water_crossings.gd:261](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/water_crossings.gd:261), `demo_waterplay.gd:409`.

**What goes wrong:** consent/eligibility is checked when swim links are offered to the planner. When the resident reaches the bank, `_step_link()` calls `water_in()` without checking again. The UI toggle updates state but does not invalidate the approaching route.

**Trigger:** order a swimmer across the stream, then turn “Swim shortcuts” off while it is still approaching the water. It enters anyway despite the state now refusing that swim. Eligibility changing between planning and entry deserves the same protection as the explicit swim-task entry check.

**Suggested fix:** recheck consent, stamina and current water eligibility at the bank before committing to the swim. If refused, replan from land and surface the reason. Define separate safe behavior for someone who is already swimming; simply canceling an in-water leg is not sufficient.

**Evidence:** **reproduced by headless integration probe** using the real `toggle_consent()` control handler and real water map/crossings. The route contained crossing code 230; afterward consent was 0 and `swim_refusal()` returned `NO_CONSENT`, yet `entered_water=true` during ordinary cast/water stepping.

### F08 — MEDIUM — Mouth capacity blocks valid underground-only expansion

**Location:** [tunnel_control.gd:440](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_control.gd:440), `underground_graph.gd:303`, `underground_graph.gd:521`.

**What goes wrong:** opening the Dig tool requires `has_room()`, which always requires two free mouths, four nodes and three segments. A connection between existing bores can need no new mouth; a branch to the surface needs only one. The actual `room_for(spec)` correctly calculates these requirements, but the player cannot reach that validation once the coarse entry gate refuses.

**Trigger:** consume all 16 mouth slots, then try to connect two existing bores; or leave one mouth free and try to add a one-mouth branch. The tool says the network is full despite sufficient rows for the intended piece.

**Suggested fix:** allow planning whenever any supported piece could fit, or defer capacity refusal until the spec is known. Report the particular exhausted capacity when rejecting the final piece.

**Evidence:** **verified with a headless capacity probe**, not a UI interaction. Eight open mouth-to-mouth pieces used all mouths and left 72 segment rows free: `has_room=false`, while `room_for()` for a connection between two existing bores returned true. Reading `begin_plan()` confirms that it refuses before that spec can be laid.

### F09 — MEDIUM — Transition tests bypass the exact handoffs that currently fail

**Location:** [test_demo_tunnel_ext_world.gd:780](/Users/brendan/Developer/redwall-review/godot/test/test_demo_tunnel_ext_world.gd:780), `test_demo_resume.gd:135`, `test_demo_resume.gd:159`, `test_demo_water_play.gd:603`.

**What goes wrong:** the crew-following test supplies an always-true active callback and explicitly calls `crew.move_site()` before the next task step. It cannot catch F03's production scheduling gap. Resume tests directly call `work_done()` and validate the stack, without completing a new dig to see whether it calls completion (F04). The swim-route eligibility test checks eligibility at planning time, not a changed condition at entry (F07).

**Trigger:** regress the actual completion or scheduler wiring while leaving the helper methods correct. These tests continue passing, as this frozen suite did with the reproduced failures present.

**Suggested fix:** retain these useful unit tests, and add small integration cases that run the real owners in live process order: lead/helper/works across a ramp boundary; saved job → dig → automatic completion; plan → consent change → bank arrival; blocked walk → no spoil/bridge credit. Assert final position, job ownership and resource changes, not just flags or calls made manually by the test.

**Evidence:** **read the tests, ran the complete suite, and reproduced their missed cases**. I found no literal `assert_true(true)`/same-operand tautologies in the targeted demo-test scan. This finding is about insufficient behavioral coverage, not a claim that the entire suite or these unit assertions are meaningless.

### F10 — MEDIUM — The top bar and playable resource economy give conflicting information

**Location:** [tunnel_stores.gd:5](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:5), `farm/farm_hud.gd:4`, `farm/farm_hud.gd:44`.

**What goes wrong:** wood/stone in the main HUD belong to the settlement simulation; bracing, lanterns, sawing and bridges use the demo's separate stores. Meanwhile the Food counter is overwritten with the demo pantry total, but its ledger still records settlement figures. A single HUD row therefore mixes different economies, and drilling into a number can change its meaning.

**Trigger:** haul wood or spend it on tunnel/bridge work, then check the top bar; or compare the Food counter with its ledger. The visible totals do not consistently explain the action the player just took. Players can diagnose a stock shortage from the wrong inventory.

**Suggested fix:** use a coherent demo HUD adapter for all resources, including drill-down screens, or clearly separate and label the settlement diagnostics from playable demo stores. Show the relevant wood/stone/plank balances and reservations beside build costs. This can be done in presentation code without writing demo quantities into the simulation.

**Evidence:** **partly verified visually, with the backing code read**. At Spring 5 the top bar showed **Wood 180 U / Stone 100 U**, while the simultaneously open Tunnels panel showed **demo wood 40.0 U / stone 20.0 U / planks 0.0 U**. The panel explains that the HUD uses settlement figures, but the player still has two conflicting resource surfaces. The Food-ledger mismatch is **reading only**; I did not open that ledger in the visual session. The split is intentional and documented; the finding is the user-facing information mismatch, not an unauthorized simulation-state write.

**Expanded live check:** Woods again displayed 40.0 U wood while the HUD displayed 180 U, with a parenthetical explanation that the HUD’s Wood belongs to the settlement. That exposes the implementation split to the player instead of resolving the information conflict.

### F11 — MEDIUM — Important demo warnings expire without a unified place to recover them

**Location:** [demo_news_strip.gd:126](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_news_strip.gd:126), `demo_notices.gd:37`, `farm/farm_bed_panel.gd:8`.

**What goes wrong:** the strip shows at most three recent entries, notes expire after 12 real seconds and warnings after 30, including while paused. The demo feed is deliberately separate from the shell's notification history. The farm panel no longer retains farm warnings, while other panels show only a few source-specific lines. The feed stores 32 records, but there is no unified history UI for them and no unresolved/acknowledged warning state or target navigation.

**Trigger:** a frost/flood/crew warning arrives while the player reads another panel. Pause and inspect for more than 30 seconds, or let a burst of events displace it. The warning disappears from the common surface, and the normal notification-history command does not retrieve that demo entry.

**Suggested fix:** add a village-news history backed by the existing ring, with source/severity filters and jump-to-target actions. Keep unresolved actionable conditions available until resolved or acknowledged; distinguish that from the lifetime of a transient toast. Avoid restoring the old permanently occupied two-card HUD behavior.

**Evidence:** **reading only**, traced through the feed, its consumers and the separate settlement notices. Expiry is explicit real-time code; no visual dismissal sequence was performed.

### F12 — MEDIUM — Water controls are buried under an unfiltered, non-interactive resident roster

**Location:** [water_panel.gd:89](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/water_panel.gd:89), `waterplay_text.gd:171`, `water_panel.gd:131`.

**What goes wrong:** every resident gets a multi-field swimming/breath/stamina line before the swim and bridge controls, regardless of selection or whether it is in water. The roster is a plain label, so it cannot select or centre a resident. The same narrow scrolling column then contains bridge surveying, build actions, all bridge statuses, stores and news. Buttons enable text clipping and do not provide contextual tooltips in `_button()`.

**Trigger:** open Water to build a bridge or react to a rescue. At the observed 1281×721 viewport, the initial panel contained conditions and most of the roster: **every swim and bridge action was below the fold**, despite all nine residents being on land with full breath/stamina. Even at 1918×1079, the log-bridge button was partly cut off at the scroll boundary and bridge status/stores were farther below. The player must scroll past irrelevant status before reaching the relevant action; selecting a resident does not narrow this roster in code.

**Suggested fix:** pin emergencies and the currently selected resident at the top, fold the full roster into a separate list, and make rows select/centre their subject. Separate Swimmers and Bridges sections/tabs, keep chosen-site build controls beside costs and shortage reasons, and add complete hover/accessible descriptions to clipped or disabled actions.

**Evidence:** **visually verified at both viewport sizes**, including scrolling down to find the controls and stores, plus code inspection of roster interactions and tooltip construction. I did not reproduce an actual rescue while navigating this layout, or establish that any particular button caption was truncated; those are separate acceptance cases.

**Expanded verification:** in the second live pass, resizing to **1280×720** again left the initial Water view occupied by “0 in water” and healthy land residents’ breath/stamina rows, with all water actions below the fold. Actual-Control measurements separately found **29 px button heights, 13 px button text and 12 px roster text**, below the documented 32 px target and 14 px minimum text. The log-bridge action was only 76% exposed at 1080p. These dimensions are layout measurements, not contrast or font-rasterization measurements.

**Related overflow defect:** the crop picker nests its ingredient scroll within the outer detail scroll. Its Back button at `(952,581,280,33)` is only **76% exposed** at 720p. Keep one scroll owner and a fixed title/navigation/action region; verify Plant → scroll options → Back as a whole task. [farm_bed_panel.gd:338](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:338), [farm_bed_panel.gd:356](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:356), [UI type minimum](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:121), [measurements](/Users/brendan/Developer/redwall-review/.review-artifacts/layout-results.json).

### F13 — MEDIUM — Fishing has a model and scenery but no completed player-to-pantry loop

**Location:** [fishing_driver.gd:6](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:6), `fishing_driver.gd:138`, `waterplay/water_panel.gd:24`, `water/water_overlay.gd:143`.

**What goes wrong:** the driver can preview and resolve species-specific catches, but explicitly returns lots for later wiring and writes no pantry/inventory. The water panel offers swimming, diving, cramp and bridge actions, not fishing orders or the full catch/gear/risk preview. The overlay exposes fish stocks without a corresponding productive player workflow.

**Trigger:** a player sees the fisher/gear and fishery stocks, then tries to catch a chosen species and feed the village. There is no complete authorize → work → land catch → pantry outcome to exercise.

**Suggested fix:** choose and complete one small fishing loop: site/species/gear selection, readable yield/quota/risk preview, assign resident, carry landed lots to the pantry, and show the resulting stock changes and refusal reasons. Until that is implemented, label the fishery display as an ecology preview so decorative work does not imply food production.

**Evidence:** **reading only; a documented missing feature/UAT gap, not a regression**. Do not treat the driver unit tests as acceptance of the end-to-end food-production feature.

### F14 — MEDIUM — Residents and minimap do not describe the playable village

**Location:** [ui_manager.gd:283](/Users/brendan/Developer/redwall-review/godot/scripts/systems/ui_manager.gd:283), `ui_manager.gd:632`, `ui_manager.gd:666`; `ui_shell.gd:3539`; `demo/demo_village.gd:4`.

**What goes wrong:** the demo replaces the visible world and cast, but the shell's Residents command still reads `SettlementSystem.residents()`, its population counter reads a different economy binding, and its minimap depends on the generated-world session. The resulting interface presents an unrelated resident roster, an unpopulated count and an empty map alongside the populated playable village. This prevents the obvious roster-to-character navigation workflow and wastes substantial screen space on a map that cannot orient the player.

**Trigger:** start the demo and press Residents. The roster shows **Warden Rowan** and multiple **Unnamed resident / mouse / Health 100 / 100** rows, rather than Mouse keeper, the two otters, Mole digger, Badger quarryman and the other playable cast members. Opening Warden Rowan shows needs and experience for that settlement resident, a locked Center view button, and leaves the Demo party panel saying **No one selected**. At the same time, the HUD Residents counter is **--** and the map says **No world generated** over a clearly visible village.

**Suggested fix:** give the demo's Residents command a cast-backed roster/detail adapter that shows the selected actor's current job, saved work, location and relevant capabilities, with select/centre actions. Show the demo population consistently. Supply a map of the authored village with camera extent, stream, crossings and active work sites, or collapse and explicitly label the unavailable map until it exists. Keep unrelated settlement diagnostics in a clearly separate development view.

**Evidence:** **reproduced visually** at the two viewport sizes and traced to the actual roster, population and world bindings. This is a demo integration/UAT gap arising from the deliberately separate presentation cast, not evidence of corrupt settlement identities.

### F24 — MEDIUM — Cancelling a harvest bypasses travel and instantly delivers its cargo

**Location:** [farm_crew.gd:150](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:150), [farm_crew.gd:407](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:407), [farm_crew.gd:435](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:435). Equivalent forestry cleanup: [forest_crew.gd:756](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_crew.gd:756), [forest_crew.gd:785](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_crew.gd:785).

**Trigger:** Let a worker cut a crop and begin carrying it to the store, then select that bed and cancel its job.

**What goes wrong:** Cancellation writes the load into storage immediately, wherever the worker is. This lets the player eliminate hauling time and disconnects displayed physical logistics from authoritative stock. Forestry uses the same cancellation/delivery pattern for wood/planks.

**Evidence:** **Reproduced for farm; read only for equivalent forestry path.** A real carrier 26.843 m from the store had 0 carrots in the pantry before cancellation and 5.1 U immediately afterward. Existing tests in [test_demo_farm_ui.gd:383](/Users/brendan/Developer/redwall-review/godot/test/test_demo_farm_ui.gd:383) and [test_demo_forestry.gd:690](/Users/brendan/Developer/redwall-review/godot/test/test_demo_forestry.gd:690) intentionally expect stock credit on cancellation. This is a gameplay-design flaw that the current tests endorse, not an accidentally uncovered assertion gap.

**Suggested fix:** Separate cancelling production from disposing of a carried load. Continue a visible return-to-store task, drop a recoverable ground bundle, or transfer the bundle locally. Credit storage only on arrival. Preserve the load when another order interrupts the worker.

### F25 — MEDIUM — Interrupting and transferring sapling planting pays the compost cost twice

**Location:** [forest_crew.gd:592](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_crew.gd:592), [forest_crew.gd:743](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_crew.gd:743), [forest_jobs.gd:214](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_jobs.gd:214).

**Trigger:** Order planting at a cleared tree site. After the first worker starts planting and pays 0.25 U of compost, give that worker a movement order. Assign the waiting planting job to another resident.

**What goes wrong:** Rewind returns the job to its walk/start-work phase without preserving that its input was already consumed. The next `_begin_planting()` pays another 0.25 U for the same sapling. With only enough compost for the original cost, resumption would instead be blocked after the first payment.

**Evidence:** **Reproduced.** Production `forestry.order_on()` and normal stepping, then `brain.order_move()`, then another `order_on()` for a different resident: `first_spend=250`, `spent_total=500`, final tree is one sapling. No direct call to the private payment or resume function.

**Suggested fix:** Record/reserve the input cost once per logical job and preserve that state through interruption, transfer, and retries. Decide explicitly whether work progress resumes or restarts; either policy must conserve paid inputs.

### F26 — MEDIUM — Pantry leaves world order input active behind its large overlay

**Location:** [farm_pantry_panel.gd:88](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:88), [farm_pantry_panel.gd:174](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:174), [demo_command.gd:377](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:377). Contract: [ui_ux_controls.md:479](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:479).

**Trigger:** Select a resident, open Pantry, then right-click the world outside the Pantry frame while reading it.

**What goes wrong:** The panel only toggles visibility; it has no modal input owner, backdrop, or registered command guard. The right-click issues a movement order while Pantry stays open. Its own source calls it a modal workspace, and the UI contract requires a modal to prevent background selection/construction.

**Evidence:** **Reproduced through actual scene and Viewport dispatch**, not by calling the command handler directly. At 1920×1080 Pantry frame was `(490,190,940,674)`. Right-click `(420,500)` changed resident 0 from order 0 to MOVE/order 1 and goal `(0,0)` to `(-8.192686,-0.792207)`, while `pantry_visible=true`.

**Suggested fix:** Route Pantry through the central modal/focus/input stack and block world selection/orders while it owns input. Alternatively, deliberately redesign it as a docked nonmodal inspector with a visibly preserved world interaction region; do not present ambiguous modal behavior. Add real Viewport input tests for outside clicks, Escape, keyboard movement, and focus return.

### F27 — MEDIUM — Pantry “spoils in N h” is not a calendar-hour forecast

**Location:** [farm_pantry.gd:174](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:174), [farm_pantry.gd:237](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:237), [farm_pantry_panel.gd:207](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:207).

**Trigger:** Read the shelf-life line for fresh roots during summer and plan when to use them.

**What goes wrong:** The formatter labels remaining effective age units as elapsed game hours. Summer ages stock at 1.5×, so roots displayed as “spoils in 240 h” actually expire after 160 game hours in a covered store. Conversely a slower season makes the same display overly pessimistic. The value is also aggregated by oldest effective age rather than necessarily earliest actual expiry across storage rates.

**Evidence:** **Reproduced component interaction.** Production Pantry formatter showed “Carrot — 5 U · 100% fresh, spoils in 240 h”; calling its production `age_hour(1)` for 160 summer hours spoiled all 5.1 U. The formatting fixture's calendar remained Spring; the formatter never uses the season, and this was not a visual summer playthrough.

**Suggested fix:** Show an actual calendar estimate calculated from lot/storage/season aging, label assumptions, and handle a coming season change; or clearly label it base shelf life rather than a countdown. Show the next lot to expire and amounts at risk, not a single ambiguous freshness scalar.

### F28 — MEDIUM — Fractional inventory is displayed as zero and pantry totals disagree

**Location:** [farm_pantry.gd:224](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:224), [farm_pantry_panel.gd:207](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:207), [farm_pantry_panel.gd:222](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:222).

**Trigger:** Stock has sub-unit remainders for several ingredients, a normal consequence of fractional harvest yields.

**What goes wrong:** The total sums each ingredient after integer truncation. Individual nonempty rows also display 0 U. Storage occupancy uses the overall milli-unit total, so its number disagrees with the headline.

**Evidence:** **Reproduced.** Add 900 milli-units to each of 16 supported foods: actual stock 14.4 U; headline “0 U of food in store”; Carrot row “0 U”; store line “14/400 U.” This is arithmetic/presentation, distinct from F10’s separate parallel-economy issue.

**Suggested fix:** Sum authoritative milli-units before formatting, display a consistent decimal precision, and distinguish zero from less than one unit. Define `U` in player terms and apply the same formatter to stock, cost, yield, capacity, and carried bundles.

### F29 — MEDIUM — Menu opens the New Settlement creator; the running demo lacks a normal session/settings entry point

**Location:** [ui_shell.gd:3451](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3451), [ui_shell.gd:1436](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1436), [ui_availability.gd:112](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:112), [ui_availability.gd:219](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:219).

**Trigger:** During a demo session, press Menu expecting Resume, Restart, Controls, Audio/Accessibility, or Save/Load.

**What goes wrong:** `_on_menu_pressed()` opens `ID_NEW_SETTLEMENT` (103). Save browser and settings are intentionally unavailable behind availability reasons. There is no normal demo session-control surface at this entry point. This is especially confusing because the live demo model and the general settlement shell are separate systems.

**Evidence:** **Reproduced handler destination; read-only availability trace.** Real Shell build + Menu handler returned page 103 equal to `ID_NEW_SETTLEMENT`. This audit did not prove a save/load attempt corrupts demo state; it establishes the missing/unexpected interface.

**Suggested fix:** Make Menu open a truthful pause/session menu with Resume, Restart demo, Controls, Settings, and Quit. Provide explicit persistence status until a demo snapshot exists. Keep general New Settlement creation behind an appropriately named action rather than the main Menu default.

**Expanded live check:** the 720p Menu/hamburger opened a large, mostly blank “New settlement” page offering “Create settlement” and “Back”; it did not show Resume, Save or Settings. Create was not activated.

### F30 — MEDIUM — Demo action controls cannot be reached by keyboard focus

**Location:** [farm_ui.gd:43](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_ui.gd:43), [forest_panel.gd:149](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_panel.gd:149), [tunnel_panel.gd:188](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_panel.gd:188), [demo_detail_zone.gd:103](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_detail_zone.gd:103). Contract: [ui_ux_controls.md:467](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:467).

**Trigger:** Try to navigate Farm/Pantry/Woods/Water detail actions with Tab/Shift-Tab and activate their buttons without a mouse.

**What goes wrong:** Shared button factories and detail tabs/close controls set `focus_mode=FOCUS_NONE`. Many distinct actions have no equivalent key binding. A few special keys, such as Dig/B, do not make the other controls navigable. This conflicts with the documented keyboard/focus requirements and excludes users who rely on focus navigation.

**Evidence:** **Read only across factories; real Farm button probe returned focus_mode=0.** It does not prove all conceivable assistive technologies fail, but ordinary Godot keyboard focus cannot enter these controls.

**Suggested fix:** Give actionable controls focus, visible focus styling, logical traversal, descriptive labels, and a predictable world/panel focus switch. Make the input router consume Enter/Escape according to the focused context; tunnel planning currently listens to Enter in `_input()` ([tunnel_control.gd:276](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_control.gd:276)), so merely restoring focus without routing would create conflicts.

### F31 — MEDIUM — Party text clips critical intent, while group and resume lists have no expansion path

**Location:** [demo_party_panel.gd:255](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:255), [demo_party_panel.gd:380](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:380), [demo_party_panel.gd:215](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:215).

**Trigger:** A resident has several unfinished jobs, a long state/reason string, or the player selects more than six residents.

**What goes wrong:** Rows use `clip_text=true` without a tooltip or multiline expansion. “Then back to” concatenates unfinished labels into one row. Group rows stop at six and show `+N more` without a way to expand those members in this panel. Compact ability text drops the target explanation after the em dash. The player cannot reliably inspect promised job resumption or what target a verb applies to.

**Evidence:** **Read only**, strengthened by F20 measured collapse.

**Suggested fix:** Separate current command, progress/blockage, and planned next work into distinct rows. Offer an inspectable task queue and member list, ellipsis tooltips for incidental names, and context buttons for Stop/Resume/Cancel task. Do not hide essential targeting instructions as the layout fallback.

### F32 — MEDIUM — There is no usable common work queue or job assignment interface

**Location:** [farm_bed_panel.gd:308](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:308), [forest_text.gd:89](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_text.gd:89), [demo_forestry.gd:526](/Users/brendan/Developer/redwall-review/godot/demo/forestry/demo_forestry.gd:526), [tunnel_ext.gd:404](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_ext.gd:404), [tunnel_ext.gd:439](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_ext.gd:439).

**Trigger:** Several farm, wood, and tunnel jobs are queued or interrupted. Find what is waiting, why, which resident will do it, and cancel/reassign one specific task.

**What goes wrong:** Farm shows only a comma-separated jobs line on the selected bed; Woods shows only five queue lines plus an unexpandable remainder and its UI cancel action cancels every forestry job; tunnel jobs are text tied to the tunnel selection inspector. None forms a stable village-wide queue with persistent blocked reasons, priorities, work progress, or reliable individual task controls. Automatic eligibility and next-task selection are hidden in crew code, so “waiting” is not actionable.

**Evidence:** **Read only.** Distinct from F04’s resume correctness bug: even a correct resume model lacks a sufficient player interface. The existing generic shell Jobs interface is not a faithful demo work queue.

**Suggested fix:** Add one authoritative Work screen with Tasks / Residents / Projects views. Show target, requested action, assigned worker, state, blockage, remaining work, and resume intent. Provide individual pause/cancel/reassign/priority and jump-to-target; distinguish Cancel this task from Cancel all work and show its scope before activation.

### F33 — MEDIUM — Action buttons omit costs, consequences, and useful disabled reasons

**Location:** [farm_ui.gd:67](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_ui.gd:67), [farm_bed_panel.gd:319](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:319), [forest_panel.gd:208](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_panel.gd:208), [tunnel_ext.gd:488](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_ext.gd:488), [tunnel_actions.gd:204](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_actions.gd:204).

**Trigger:** Consider Compost/Raise/Bank/Cover, planting a tree, or a tunnel upgrade before committing resources. Alternatively encounter a greyed-out button.

**What goes wrong:** Farm clears enabled-button tooltips and converts refusal enum strings into words for disabled ones. Woods `_enable()` only toggles disabled, generally discarding a reason; compost may be missing while the Woods stock summary only shows wood/planks. Tunnel enablement mostly checks geometry, with busy/material refusal deferred until clicking. The player cannot consistently preview cost, effect, duration, actor, or the exact recovery action.

**Evidence:** **Read only.** Not every action is entirely undocumented: some descriptive text includes a cost, but coverage and placement are inconsistent.

**Suggested fix:** Standardize an action card: result, cost (have/need), expected work, eligible/assigned actor, prerequisites, and explicit disabled reason with a recovery link. Keep useful tooltips on enabled controls as well as disabled ones. Use the same eligibility/cost model for preview and execution.

### F34 — MEDIUM — Farm units and labels mix raw simulation scales with player-facing percentages

**Location:** [farm_text.gd:133](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_text.gd:133), [farm_text.gd:140](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_text.gd:140), [farm_bed_panel.gd:327](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:327), [farm_text.gd:77](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_text.gd:77).

**Trigger:** Compare a bed's moisture, fertility, health, expected yield, and Rest effect to decide what treatment is worthwhile.

**What goes wrong:** Moisture is displayed as raw values such as 6600 with a raw acceptable band; fertility/health use percentages; the Rest tooltip says “regains 50 fertility a day” even though 50 is 0.5 percentage points on the 10000-point authoritative scale. Crop selection combines nominal hours/units with a separate yield multiplier. The player must translate several incompatible numerical conventions and cannot easily compare effective yields.

**Evidence:** **Read only**; numeric Pantry contradictions independently reproduced in F28.

**Suggested fix:** Present moisture as a named state plus a normalized range/bar, use percentage points explicitly, and show one forecasted harvest amount with a breakdown on demand. Define units consistently. Make treatments say their expected player-visible change rather than exposing raw model increments.

### F35 — MEDIUM — The demo panels ignore the shell's UI scaling model

**Location:** [farm_ui.gd:75](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_ui.gd:75), [demo_detail_zone.gd:235](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_detail_zone.gd:235), [demo_party_panel.gd:368](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:368), [ui_shell.gd:1709](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1709).

**Trigger:** The shell layout is computed at 150% scale, as its API supports, while demo panel layout is recomputed for the same viewport.

**What goes wrong:** Demo layout helpers explicitly use user scale 100. Thus the shell scales but demo text/targets/layout do not follow, undermining a future accessibility scale control and risking overlap between independently scaled regions.

**Evidence:** **Reproduced API mismatch:** same 1280×720 viewport, shell scale 1.5 versus demo scale 1.0. **Important limitation:** the settings screen is currently unavailable, so this is an integration/accessibility gap, not a claim that a current accessible Settings slider has been clicked and failed.

**Suggested fix:** Give all demo UI the same resolved geometry/accessibility settings, then expose the setting through the session menu. Test 100/125/150/200% at supported viewport sizes and keep actions reachable with reflow/scroll, not by hiding them.

### F36 — MEDIUM — Crop picker eligibility and its date freeze while the live calendar advances

**Location:** [farm_bed_panel.gd:227](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:227), [farm_bed_panel.gd:338](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:338), [farm_bed_panel.gd:356](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:356).

**Trigger:** Open Plant… near a sowing-window boundary and leave it open while simulation time continues. For instance cross Spring 4 → Spring 5, when wheat becomes unavailable and peas become available.

**What goes wrong:** The picker builds its title, disabled state, reason and row order only in `open_picker()`. The ordinary `refresh()` skips those fields while picking. It continues to offer an out-of-window crop and prevents selection of a crop that has just become valid; the title also shows an old date. Execution eventually refuses the stale enabled choice, but a newly eligible crop is inaccessible until the panel is closed and reopened.

**Evidence:** **Reproduced.** Open the real bed-0 picker at Spring 1, advance the real farm calendar to day 5 and call real `refresh()`: Wheat remains enabled although its current reason is “sow in Spring 1–4”; Pea remains disabled although its current reason is empty; title remains “Y1 Spring 1, 06:00”. The interval was advanced in one deterministic call; a player can cross the same boundary by waiting normally.

**Suggested fix:** Refresh picker eligibility/reasons/title when calendar or bed revision changes, preserving focused item and scroll position. Either reorder only on explicit request or make newly eligible options visibly available without disruptive list movement. Add a test that crosses a real date boundary while the picker remains open.

### F37 — MEDIUM — Resolved dry/wet conditions do not re-alert when they recur in the same season

**Location:** [farm_alerts.gd:111](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_alerts.gd:111), [farm_alerts.gd:122](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_alerts.gd:122).

**Trigger:** A growing bed becomes waterlogged, the player drains it back to a healthy band, then later rain waterlogs it again during the same season. The same pattern applies to repeated drought.

**What goes wrong:** Suppression keys identify only bed + condition + season and are never cleared after resolution. The recurring growth stoppage emits no new warning, even though it is a new actionable occurrence. With the transient feed and no farm overview, the player must happen to inspect the bed again. The source intentionally suppresses standing conditions per season, but it conflates an ongoing condition with a new one after recovery.

**Evidence:** **Reproduced component behavior.** Use the real moisture API to set radish bed to 9800 → 6000 → 9800 and call production `collect_into()` after each change. First output is “Bed 4 (radish) is waterlogged and has stopped growing — Drain it”; resolution and recurrence outputs are empty, final band is waterlogged (4). The probe supplies the moisture changes as a fixture rather than simulating a rain event; it exercises the actual state/alert transition.

**Suggested fix:** Track active conditions and transition history. Deduplicate while a condition remains active, clear/rearm on genuine resolution, and re-announce a new occurrence with a cooldown if necessary. Keep unresolved conditions persistently visible rather than relying on repeatedly emitted notices. This is a different missed-warning cause from F11’s expiry and F38’s event flooding.

### F38 — MEDIUM — One low-air event replaces the entire village-news history

**Location:** [swim_state.gd:155–159](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/swim_state.gd:155) sets LOW_AIR on every submerged tick at or below 450, and AIR_OUT every tick at zero. [rescue.gd:127–130](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:127) posts every event. [demo_notices.gd:69–84](/Users/brendan/Developer/redwall-review/godot/demo/demo_notices.gd:69) appends into a 32-entry ring with no incident coalescing.

**Trigger:** an otter begins a dive with exactly enough air for its plan and reserve; it crosses the low-air advisory while completing the dive. Unconscious ascent has a similar repeated AIR_OUT risk.

**Observed through a real DiveTask:** set the admission-boundary fixture to a valid **338 planned ticks + 300 reserve = 638 air**, then run normal cast and water steps until the dive finishes. **150 notices** were posted; the retained 32 were all low-air notices and a preexisting actionable warning was gone. A smaller isolated state→rescue probe also gave 40 new warnings in 40 ticks. The real task probe—not the smaller injected-mode one—is the strongest evidence.

**Suggested fix:** trigger advisory events on threshold entry with a re-arm threshold, or coalesce them into a persistent per-resident incident whose meter updates in place. Separate toast rate from status updates. Test one low-air notice, one air-out notice, resolution, re-arm, multiple swimmers, and preservation of unrelated history.

**Evidence:** boundary-state setup as used by the existing dive test, followed by the production task path; no production patch. [Probe/output](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.log). This extends F11: history loss happens immediately under one incident, not only by expiry.

### F39 — MEDIUM — Rescue chooses a nondiver for a submerged victim while a diver is available

**Location:** [rescue.gd:175](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:175) selects the nearest eligible swimmer. [may_go:215–221](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:215) checks swimming but not diving. [rescue_tasks.gd:149–159](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue_tasks.gd:149) makes a nondiver tread above a submerged victim. `engaged` then prevents another dispatch.

**Trigger:** a diving otter is cramped while a mouse is the nearest swimmer and a second otter is available farther away. All subjects may be on reachable ground/water.

**Observed:** a real DiveTask walked to the pond, swam out, descended and reached SEARCH. Calling the production `play.cramp([0])` assigned nondiver 1 while diver 2 remained unassigned. Victim air started at **1149**, fell to **0**, and towing only began after **40.0 simulated seconds**, when the victim floated up. No forced victim-depth field was needed in this stronger probe; only species/capability and starting-position fixture setup. The earlier artificial-depth probe is retained separately and clearly labeled.

**Suggested fix:** rank only candidates capable of the required rescue phase; for submerged victims prefer a diver with enough air for descent, recovery and reserve. Reserve the victim atomically. Fall back to surface monitoring/line rescue only with an explicit reason and continuing re-evaluation. Keep the nonfatal safety net.

**Evidence:** full task + actual cramp command + normal simulation stepping. [Probe/output](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.log). This is delayed rescue/avoidable air-out, not a fatality claim.

### F40 — MEDIUM — Tree footing uses a radial estimate that does not match visible roots

**Location:** [forest_roots.gd:48](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_roots.gd:48), [forest_lift.gd:90](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_lift.gd:90). The height is a radial median profile; tree yaw and actual root geometry do not enter it. The entire actor gets that ground height.

**Trigger:** walk close around the authored NW oak, whose roots are irregular, especially the hollow side between exposed roots.

**Measured:** transformed actual staged oak triangles at size 1/yaw 0, after the correct 1.2 m sink, were sampled on 216 ring/bearing points outside the trunk radius. At local **(-0.388229, 1.448889)** in XZ, the lift profile is **0.80 m** but no mesh surface occurs between the ground and 2.5 m directly below that point. Several neighboring samples also hit bare ground, while others 0.15 m away hit raised root/trunk geometry. This is strong evidence the profile does not describe the surface; it is **not** sufficient to claim every foot of an animated resident floats 0.80 m. The largest downward discrepancies may include steep trunk surfaces or overhead geometry and must not be presented as literal foot penetration distances.

**Camera/actor test location:** authored oak `oak_nw` at **(-19.5,-19)**, yaw 110°, size .95. Corresponding suspect point approximately **(-18.08,-19.12)**, profile lift .76 m. Ask a mouse to circle that side and inspect close and default gameplay views.

**Suggested fix:** bake a small oriented root-contact heightfield/support mask from the asset, evaluate in tree-local space, and use simplified root obstacles where no stable walk surface exists. Fit feet/ankles only where necessary; keep the inexpensive cached spatial broad phase.

**Evidence:** actual geometry plus code, **appearance not visually verified**. [Probe](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.gd), [values](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.log). Existing tests use radial formulas and fake banded columns, so they cannot accept this mesh-contact quality: [test_demo_forestry.gd:1018](/Users/brendan/Developer/redwall-review/godot/test/test_demo_forestry.gd:1018), [1098](/Users/brendan/Developer/redwall-review/godot/test/test_demo_forestry.gd:1098).

### F41 — MEDIUM — The weir sits as a disconnected diorama without bed or bank support

**Location:** [water_dressing.gd:67](/Users/brendan/Developer/redwall-review/godot/demo/water/water_dressing.gd:67), placement/sink application [267–287](/Users/brendan/Developer/redwall-review/godot/demo/water/water_dressing.gd:267), terrain [water_terrain.gd:106](/Users/brendan/Developer/redwall-review/godot/demo/water/water_terrain.gd:106).

**Trigger/location:** inspect the weir at **(23.8,-14.0)**, preferably from east/west and lowered pitch. Its actual world footprint is x **22.465–25.133**, z **-15.297…-12.702**; its bottom is **y=-.43**, top **1.07**.

**Measured:** all actual mesh vertices lie above the bed; none touch/penetrate the ground. Ground beneath that mesh ranges **-.866…-1.279 m**. For actual vertices in the bottom 3 cm band, the gap to the **rendered terrain triangles** is **.468706… .834376 m** (the analytic map gives virtually the same answer). All footprint vertices are over submerged terrain, so there are no bank abutments in that geometry. This excludes the claim that it merely intersects the bank somewhere missed by a bounding-box check.

**Consequence:** physically unsupported diorama geometry and a potential “floating island/weir” appearance; the underwater gap may be hidden by the water material in an ordinary camera. The exact underwater clearance is established geometrically; the expanded visual check below confirms the broader integration defect. The model includes its own baked water/earth, a known source of context mismatch.

**Suggested fix:** create a production weir module without a baked water sheet, fit abutments/bank contacts to the channel and extend foundations to the actual bed. Validate visual obstruction, crossing navigation and depth/flow presentation together; do not simply lower the whole weir enough to bury the working crest.

**Evidence:** actual staged model and actual terrain-grid triangle interpolation, no editor changes. [Support probe](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_building_support_probe.gd), [output](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_building_support.log).

**Expanded visual verification:** the production scene was viewed using a review-only camera harness, with clear weather and pause, focus `(23.8,0,-14)`, yaw 90°, distance 9 m and pitch 30°. The weir visibly reads as an isolated raised block/diorama in midstream: cut dirt slab sides, a separate inset water patch, no connection to either bank, and surrounding water around all sides. This was a controlled-camera inspection, not a claim the normal player camera was navigated through that exact sequence. Integrate the mesh with banks/bed and one continuous water surface; merely lowering the whole model cannot resolve the detached dirt slab and baked water patch. [Camera-only harness](/Users/brendan/Developer/redwall-review/.review-artifacts/visual_probe.gd).

### F42 — MEDIUM — Frost and snow use a flat camera-following sheet across water

**Location:** [weather_view.gd:121](/Users/brendan/Developer/redwall-review/godot/demo/weather/weather_view.gd:121), [171–185](/Users/brendan/Developer/redwall-review/godot/demo/weather/weather_view.gd:171). A 60 m plane at y=.02 follows the camera focus; snow/frost alpha is .42/.22. It has no terrain, water, roof or object support mask. Water lies at roughly y=-.18; its bank is carved below y=0.

**Trigger:** frost/snow while viewing or panning across the stream/pond. The same opaque-ish flat veil covers the depressed bank and water at a height above the surface, while roofs/materials do not gain corresponding accumulated snow through this path. At large zoom, its finite edges are a separate acceptance risk.

**Consequence and updated visual evidence:** the geometry is a blanket surface effect rather than accumulation attached to ground, roofs and props. A controlled rendering check called the actual `DemoWeather.observe(3,1,0,-50,100,-1)` and `WeatherView._apply_targets(1.0)` in the paused real scene. Condition 3 is **Frost, not snow**. The weir view showed broad flat white ground treatment and a white horizontal band around low shore/weir geometry, while roofs and raised props remained unchanged. The stream remained visibly watery/textured: this review does **not** claim it became opaque, walkable snow or ice. The plane crosses water in code, but an associated safety misreading has not been demonstrated with players. Snow and finite-edge appearance remain reading-only acceptance risks. This was injected render state, not a playthrough to winter; the fixture’s unchanged Spring HUD is not a game defect.

**Suggested fix:** drive accumulated frost/snow through world-space surface masks on ground/roofs/props; exclude liquid water unless a separately implemented ice state permits it. Particles may still follow the camera. Validate path/shore/selection contrast in each condition.

### F43 — MEDIUM — No demo sound integration was found

**Evidence scope:** a repository scan for `AudioStreamPlayer`, `AudioServer`, `AudioManager`, `play_sound` and `audio_bus` in `godot/demo`, `godot/scripts`, and `godot/project.godot` found no integration. Scene construction wires visual effects, weather, world, crews and UI but no audio owner: [demo_village.gd:139](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:139), [weather_view.gd:66](/Users/brendan/Developer/redwall-review/godot/demo/weather/weather_view.gd:66). **This review did not establish the running demo’s sound output by listening.** This is a code-supported feature gap, not an auditory observation.

**Player consequence/trigger:** felling, chopping, carrying, splashing, warning and construction completion all need the player's eyes to distinguish and confirm them. The woodland community also loses much of its inhabited character.

**Suggested fix:** a bounded ambient/work/feedback sound pass with distinct buses, distance falloff, limited concurrent emitters, rate-limited alert sounds and independent volume/mute controls. No mandatory voice-over or new lore is needed.

### F44 — MEDIUM — Selection changes assignment semantics without a common preview

**What goes wrong and triggering scenario:** The same action has materially different assignment semantics depending on selection and subsystem. A selected group on a farm bed means one nearest worker; selected felling means lead plus haulers; no selection means a hidden routine crew; a bridge may fall to the bridgewright. The player must remember the exception rather than review who will do the order.

**Suggested fix and source locations:** Preview “Assign X now / Queue for crew Y”, affected workers, interruption and saved-work behavior before/with acceptance; keep one command grammar across panels. [farm_crew.gd:100](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:100), [forest_crew.gd:7](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_crew.gd:7), [README bridges](/Users/brendan/Developer/redwall-review/godot/demo/README.md:497); P1/P2.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository.

### F45 — MEDIUM — No overview connects local conditions to village priorities

**What goes wrong and triggering scenario:** A field can tell the player many biological and work facts, but the village cannot answer the higher-level question “What threatens tonight's meal or next season?” A player inspecting six beds and several job queues has to mentally aggregate urgency, labor and supply.

**Suggested fix and source locations:** Add an exception-oriented village overview and a seasonal work calendar, not another permanent wall of detailed numbers. Derive from real state; no fabricated food runway while consumption is disconnected. [GDD daily/seasonal loop](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:70), [bed UI contract](/Users/brendan/Developer/redwall-review/godot/demo/README.md:295); P1/P4.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository. Current implementation anchors: [farm_bed_panel.gd:227](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:227), [farm_bed_panel.gd:308](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:308).

### F46 — MEDIUM — Pantry gives inactive recipe prose priority over usable stock decisions

**What goes wrong and triggering scenario:** The Pantry devotes a full adjacent column to unimplemented recipe candidates, while operational stock is a sentence per ingredient: whole units, oldest freshness and hours. Storage is one joined text line. A player trying to prevent imminent waste has no obvious operational list of exact endangered lots, location, reservations or processing action.

**Suggested fix and source locations:** Split “Stocks / Orders / Recipes”; put endangered usable lots and next actions first; move research candidates to an explicitly separate collection. [farm_pantry_panel.gd:7](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:7), [item_row_text:209](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:209), [stores_text:220](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:220); P1/P3.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository. The expanded live pass also confirmed the empty ingredients column beside long wrapping inactive candidate names, including game-adaptation wording; this is now a direct visual hierarchy observation as well as a source finding.

### F47 — MEDIUM — Overlay cycling hides the active question and misrepresents mixed groups

**What goes wrong and triggering scenario:** A single V cycle must serve moisture, ripeness, water and woodland. To answer a direct question such as “Where can this resident wade?” the player needs to remember position in the cycle; the water view also uses only the first selected resident's height, which may not represent a mixed group.

**Suggested fix and source locations:** Add a labeled layer selector with direct actions, persistent active-layer label and explicit subject; group routes require per-member compatibility summary. Keep V as a convenience shortcut. [README overlay controls](/Users/brendan/Developer/redwall-review/godot/demo/README.md:142), [Water overlay subject](/Users/brendan/Developer/redwall-review/godot/demo/README.md:511); P1/P5.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository. The display can be accurate for its first subject yet misleading for a group; this is not a reproduced wrong traversal.

### F48 — MEDIUM — Ambient professions and props imply productive actions they do not own

**What goes wrong and triggering scenario:** Routine activity can look meaningful while being only a presentation visit. The fisher's route includes the well/square/cauldron, and the boatwright has no boat-production chain here. Clicking an evocative prop therefore has an uncertain contract: scenery, work contact, or productive station.

**Suggested fix and source locations:** Visually distinguish usable work sites; give each a hover name, current purpose and legal verb; connect the few featured stations end to end before dressing future systems as active. [cast_routines.gd:15](/Users/brendan/Developer/redwall-review/godot/demo/cast/cast_routines.gd:15), [README water dressing](/Users/brendan/Developer/redwall-review/godot/demo/README.md:394); P3/P7/P8.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository.

### F49 — MEDIUM — The demo has many verbs but no integrated first-session objective path

**What goes wrong and triggering scenario:** Busy villagers and counters do not establish a reason to keep playing. The current guide explains numerous inputs and subsystems, while the intended experience requires an understandable first goal, a local success, and a seasonal purpose. No demo-specific objective owner was found in its bootstrap/UI module scan; the shell's Objectives command is locked in the original visual pass.

**Suggested fix and source locations:** Add a recoverable guided scenario whose steps complete on real outcomes, with optional free play. **Missing integration**, not a request for a separate campaign. [demo_village.gd:74](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:74), [progressive disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:824), the live coverage stated above; P7.

**Evidence:** **source/UI-structure reading and design assessment**, not a newly reproduced engine failure. The claim concerns the playable demo’s integration, not the absence of every related system from the repository.

### F53 — MEDIUM — The camera enters opaque foliage and selected workers disappear under canopies

**Location:** [demo_camera.gd:277](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:277), [forest_view.gd:153](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_view.gd:153), [selection ring material](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:303).

**What goes wrong:** the orbit camera applies its pose without resolving camera/foliage occlusion. A supported close/low view can enter opaque tree geometry and replace nearly the whole world view with leaves. Moving back outside the canopy does not necessarily reveal the selected worker beneath it. Players lose both spatial context and the subject of their current command.

**Trigger:** focus the authored NW oak at `(-19.5,0,-19)`, yaw 90°, distance 11 m, pitch 30°—within the supported camera range. In the actual runtime this view was almost entirely blocked by foliage. Increasing pitch using the normal Alt+PgUp control and zooming out seven notches to roughly 27 m recovered the exterior view, but the selected mouse under the canopy still had no visible body/outline/locator. A real move order to `(-18.08,0,-19.12)` was accepted and later reported Holding; canopy obstruction prevented judging its foot contact. A wider 24 m / 50° weir view was also heavily blocked by foreground canopy.

**Suggested fix:** constrain/reposition a camera that enters obstructing geometry, and provide a bounded canopy cutaway/fade or selected-worker silhouette/locator. Preserve clear picking semantics: a visible through-canopy marker should identify the actual selected actor. Scope fading to the camera/selection obstruction and budget transparency overdraw; do not globally remove the woodland canopy. Test forest views at minimum/default/far zoom and all supported pitches, with workers behind trees and roofs.

**Evidence:** **visually reproduced in the production scene with a review-only camera harness**, followed by normal camera controls and a real production movement command. The harness changes runtime view/fixture state, not repository source. The root-height mismatch F40 remains geometry-only; an obscured actor is not evidence of floating feet.

### F15 — LOW — A bridge access failure names the wrong resident after clearing its builder

**Location:** [bridge_crew.gd:234](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/bridge_crew.gd:234), `bridge_crew.gd:327`, `demo_cast.gd:94`.

**What goes wrong:** when no work spot is found, `_issue()` calls `_drop(row)` and only then formats `name_of(builder[row])`. `_drop()` has replaced the builder with `NOBODY` (−1). `actor(-1)` indexes the last cast actor, so the refusal blames that resident instead of the worker who failed.

**Trigger:** assign a bridge to someone other than the final cast member, then leave no valid spot near its source or site. The “can't get to…” notice identifies the final actor, confusing reassignment and debugging.

**Suggested fix:** retain the worker ID/name before dropping the row, and reject invalid actor indices at public boundaries. This is also a concrete example of sentinel values leaking into valid negative array indexing.

**Evidence:** **reading only**, including the order of `_drop()` and name lookup; not separately reproduced.

### F16 — LOW — Surface tunnel entrances depict a dark strip rather than the traversed ramp

**Location:** [tunnel_mouth.gd:77](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_mouth.gd:77), especially line 84; `tunnel_mouth.gd:5`.

**What goes wrong:** the cutting is a flat quad at `LIFT_M=0.05` over intact ground, while the resident actually descends the ramp. The mouth is a procedural gate because the generated arch currently has a solid doorway. The visible surface cue therefore does not represent the sloped opening the character traverses.

**Trigger:** follow a resident into a completed mouth in the surface camera, particularly close up or at a low angle. Its descent cannot be read as movement down a visibly open cut.

**Suggested fix:** provide an actually open arch and a terrain aperture/ramp representation with consistent visual and traversal geometry. Keep its scale and entrance selection cue readable from the normal play camera.

**Evidence:** **reading only**, corroborated by decision 0207's explicit open issue. This is a known remaining asset/presentation gap, not a new P2 regression. No room/home/cellar work is included.

### F17 — LOW — Underground walking still relies on a deformed normal walk rather than a crouching gait

**Location:** [demo_actor.gd:62](/Users/brendan/Developer/redwall-review/godot/demo/cast/demo_actor.gd:62), `demo_actor.gd:276`, `demo_actor.gd:300`.

**What goes wrong:** the active clip set has the normal walk but not the generated crouch walk. A procedural modifier bends the body and knees to fit. Decision 0207 explicitly records that the squirrel leans roughly 45° and that replacing this with the generated gait remains P7 work. Mathematical head clearance/foot pinning is not sufficient evidence of convincing locomotion.

**Trigger:** watch a squirrel traverse a long bore or transition between surface, ramp and tunnel. The normal gait continues underneath the substantial pose correction.

**Suggested fix:** integrate the intended crouch clips with matched movement speed and blends; retain the procedural modifier for residual clearance and ramp adjustment. Visually inspect start/stop, turning, hauling and transitions for each species, not just a stationary fit pose.

**Evidence:** **reading only and a documented known limitation**. I did not inspect current animation appearance; this is the asset acceptance work still outstanding, not a claim that the newer foot-grounding fixes failed.

### F50 — LOW — Debug/scenario actions occupy primary player interfaces

**Location:** [forest_panel.gd:42](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_panel.gd:42), [tunnel_panel.gd:41](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_panel.gd:41), [water_panel.gd:35](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/water_panel.gd:35).

**Trigger:** Explore weather, events, forestry, and water controls as a new player.

**What goes wrong:** Test Event / Next Weather / Storm Gust / Cramp style controls mix simulation-testing facilities with ordinary management choices. Labels that admit demo behavior are honest, but the player still must distinguish a debug cause-event action from an in-world decision. It weakens immersion and inflates already crowded action surfaces.

**Evidence:** **Read only, exact labels traced to action dictionaries.** This is a design assessment, not a crash bug.

**Suggested fix:** Move deliberate test triggers into a clearly named Scenario Lab or developer drawer. Keep player-facing forecast, preparedness, rescue, and recovery controls in the ordinary interfaces. If the demo intentionally showcases scenarios, present them as opt-in authored challenges with clear reset/outcome feedback.

### F51 — LOW — Ground and water materials apply a UI-only palette constraint

**Location:** [world_look.gd:4–23](/Users/brendan/Developer/redwall-review/godot/demo/world/world_look.gd:4), [water_surface.gd:10](/Users/brendan/Developer/redwall-review/godot/demo/water/water_surface.gd:10). Both explicitly derive 3D colors from the UI pigment lock.

**Conflict:** the adopted visual direction explicitly says not to impose the UI twelve-pigment palette, outlines or lighting on the 3D world. [Direction alignment](/Users/brendan/Developer/redwall-review/docs/art-reference/visual_direction_alignment.md).

**Suggested fix:** evaluate those materials against DEC-038 on their own merits and replace the mistaken authority comment/constraint with world-domain material/value targets. This is an implementation/contract mismatch; it is **not proof the current chosen colors are ugly or require wholesale replacement**.

**Trigger and consequence:** tune ground/water materials according to the stated UI lock, and the world’s material/value choices are constrained by the wrong adopted authority. **Evidence: source/contract reading only.** The fix is to assess those colors under the approved world-art target, not assume they all need replacement.

### F52 — LOW — Tree growth jumps abruptly from sapling to mature silhouette

**Location:** [forest_view.gd:46–48](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_view.gd:46), [188–205](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_view.gd:188), mature replacement [153–177](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_view.gd:153). The sapling target is 3.2 m and grows to 1.35 share, then visibility switches to the mature tree. Stump shoots also jump back to the mature trunk position on regrowth.

**Trigger:** watch the midnight when a 48-day tree regrows. This is predictable from code, not visually witnessed here.

**Suggested fix:** add at least one intermediate young-tree canopy/trunk stage and crossfade/dither only during a bounded transition, or make the mature conversion occur during a readable seasonal growth moment. Validate both normal and 4× speed and occupancy/obstacle changes. Avoid unnecessary unique high-poly assets per age.

## Feature work should connect a believable community loop

Forestry → hauling → planks → bridges and excavation → access → spoil → bed improvement already provide stronger opportunities than adding disconnected activities. The appropriate quality unit is a complete player intention: a reason to act, a legible tradeoff, physical work, reliable logistics and a lasting consequence. The following audit asks where each existing loop reaches that endpoint.

| Current loop | Goal → decision → work → logistics → payoff → pressure | Experience assessment and evidence |
|---|---|---|
| Farm beds | Grow an ingredient → choose crop/treatment → sow/water/drain/cover/harvest → carry to a store → see stock/freshness → rain, frost, blight, spoilage | Work is tangible and treatments connect to terrain. The chain stops before a visible meal, resident need or useful reserve forecast. The Pantry explicitly calls its dishes candidates for a kitchen that does not exist. [Pantry UI:9](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:9), [pantry model](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:1) |
| Woodland | Obtain material → choose tree/deadfall and protection policy → fell/gather → haul/log stack/saw/plank stack → build/brace → conservation floor/regrowth/weather | One of the most complete visible economic chains. It is undermined by mixed HUD totals, fragmented job ownership, and weak comparison of a construction's benefit against its material/labor cost. [Woods README](/Users/brendan/Developer/redwall-review/godot/demo/README.md:416), [forest board](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_jobs.gd:7), F10 |
| Underground passage | Reach somewhere/protect travel → choose route/ground/clearance → dig with helpers → spoil handling/brace/light → new route and bed drainage → flooding/collapse | Distinctive potential: ordinary village logistics can justify the tunnel, rather than digging only to try the tool. Current completion/resume/crew bugs break trust, and there is no player-facing route-benefit comparison. Excludes rooms/homes/cellars. [README tunnels](/Users/brendan/Developer/redwall-review/godot/demo/README.md), F02–F05, [movement UI requirements](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:530) |
| Bridge | Cross water safely with a load → choose log/plank/span → fetch/build → use real deck → safe/all-resident access → material and route opportunity cost | Useful infrastructure already interacts with timber and body/load restrictions. Its UI mixes survey, swimming, emergency and stock data, so the decision is hard to inspect. A benefit preview and clear project lifecycle would expose existing depth before new bridge types. [Water gameplay README](/Users/brendan/Developer/redwall-review/godot/demo/README.md:470), F12 |
| Swimming/diving/rescue | Cross/find something → consent and air/stamina choice → enter/traverse/search → surface/tow → shortcut/find/recovery → current/cold/exhaustion | Movement has interesting local risk and species-aware presentation. The productive fishing destination is missing, so much of the activity remains an experiment rather than a settlement decision. Rescue currently guarantees wash-ashore fallback, unlike a complete injury/care consequence loop; this is an intentional demo behavior, not grounds to enable unapproved death penalties. [README:470 onward](/Users/brendan/Developer/redwall-review/godot/demo/README.md:470), [fishing driver:6](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:6), [DEC-040](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:977) |
| Resident attachment | Notice a resident → assign suitable work → gain experience/help someone → become important to the village → remember their contribution → juggle needs/absence | The demo's routines are weighted trips among trade and social points of interest, not a needs/schedule loop. The actual journal describes different settlement residents. The current readable labels identify trade, but do little to establish an individual history. [cast_routines.gd:2](/Users/brendan/Developer/redwall-review/godot/demo/cast/cast_routines.gd:2), F14 |


The adopted GDD already calls for targets, priorities and policies while residents reserve, travel, work, haul and meet needs. Food, sustainable use and shared achievement are its emotional core. The strongest differentiation is **a community whose care is visible in its landscape**: a learned trade, a safer crossing, spoil improving a field, a harvest becoming a dish, and remembered assistance. This is a design recommendation, not a newly adopted mechanic. [Daily loop](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:70), [emotional goals](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:52).

Keep species, skill and personality distinct: any resident may learn a trade, while physical clearance is a separate limit. Retain plant staples and the nine whitelisted nonsapient aquatic species; introduce no hunting, husbandry, dairy/egg chain, generic edible fish or eel harvest through a comparison. The 1,755 recipe/serving candidates remain research until their exact quantities, dependencies and ownership are approved. Family life is adopted but unresolved care coefficients are not invented here. [DEC-041](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:1030), [food amendment](/Users/brendan/Developer/redwall-review/docs/setting_rules_amendment.md:19), [content contract](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/authoring_handoff.md), [family direction](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:369).

### Comparable games show useful patterns without defining Redwall’s rules

These primary sources support particular patterns, not copying a whole game. Historical developer posts establish the named design decision at publication; they do not imply exact current balance is unchanged. No comparison title was replayed in full for this task, and no claim relies on fan wikis or mods.

| Source-backed pattern | What the primary source actually says | Redwall application — inference, not source claim |
|---|---|---|
| **Against the Storm: warmth can coexist with clear information structure** | Eremite describes reversing a disliked flat/minimalist redesign and combining the older warm, decorative style with newer readable structure; fonts, layout and information-structure improvements remained. [Rationing Update, 12 May 2022](https://eremitegames.com/rationing-update/) | Keep woodland craft, parchment and warmth. Reorganize content by decisions, consistent rows and hierarchy; do not equate usability with stripping out identity. Compare revised wireframes with players before polishing every frame. |
| **Against the Storm: show the consequence beside the policy** | Its consumption panel exposes restrictions by good/species and previews current and maximum Resolve consequences. This is a developer description of that 2022 system, not a claim its exact current balance is unchanged. [Rationing Update](https://eremitegames.com/rationing-update/) | Show reserve after a feast, consumption effect, labor disruption and unavailable inputs next to the action. Do not import species-based rationing or Resolve as a new Redwall mechanic; its existing world policy and reserve contracts are the starting point. |
| **Factorio: distinguish a recipe from an actual item, and show effective output** | Wube split recipe information from output-slot item information so spoilage and recipe identity could both be inspected. The same post introduces effective throughput in crafting-machine tooltips. [FFF #426, 30 Aug 2024](https://www.factorio.com/blog/post/fff-426) | In Pantry, separate immutable recipe requirements from today's lots, freshness and reservations. A production order should show what this staffed station can currently do, not only the recipe's theoretical values. |
| **Factorio: use cause-specific waiting states and contextual teaching** | Wube distinguishes destination capacity from an absent path and explains that contextual tips should unlock with relevant actions; its tips index is searchable and combines related tutorials. Basic item information stays in direct tooltips. [FFF #361, 2 Oct 2020](https://www.factorio.com/blog/post/fff-361) | Separate “waiting for mouth”, “load too wide”, “no safe exit” and “no route”. Teach tunnel planning when a player first tries it, while maintaining a single searchable help source. Do not bury routine affordances in a long tutorial or imitate Factorio's full factory UI. |
| **Timberborn: make environmental engineering repay preparation** | Mechanistry's official product description ties recurring drought/toxic seasons to food stockpiles, irrigation and keeping fields/forests alive; water shaping and bridges are part of its settlement tools. [Official developer store description](https://store.steampowered.com/app/1062090/Timberborn/) | Forecast rain/frost, then let the player read why drainage, a bridge or a dry tunnel mattered afterward. Borrow the preparation/payoff relationship, not toxic water, advanced industrial automation or a new hydrodynamic simulation. |
| **RimWorld: individuals matter because state has continuing consequences** | Ludeon's site describes backgrounds affecting abilities, relationships changing over time and injuries affecting capacities, within its deliberate story-generator design. [Official RimWorld site](https://rimworldgame.com/) | Show an individual's learned trade, assistance and recovery in the same inspector as their current work. Redwall should emphasize care, everyday humor and earned community memory. Do not import job incapabilities as species destiny, graphic injury systems, raids or cruelty. |
| **Game accessibility: readability must survive configuration changes** | Microsoft's XAG 101 addresses readable text and configurable presentation; XAG 112 requires usable digital navigation and focus order that follows changed layout. [XAG 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101), [XAG 112](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112) | Test long names, a smaller viewport and increased text scale during actual tasks. The desired result is successful use, not only rectangles that stay inside the screen. Preserve action controls and readable text when a detail view grows. |
| **Game accessibility: meaning needs more than one channel** | Microsoft's XAG 103 calls for additional visual/audio channels; XAG 102 describes checking meaningful foreground/background contrast, including the worst area under patterned backgrounds. [XAG 103](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103), [XAG 102](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102) | Warn about a stranded resident with persistent text, icon, target navigation and an optional sound; distinguish overlay states by labels/patterns as well as color. Evaluate actual woodland textures and weather backgrounds, not palette constants alone. |


For Redwall, the common information sequence should be **summary → cause → evidence → legal action**. “Harvest at risk” leads to affected beds, available workers and deadlines, then a relevant assignment. A bridge comparison explains loaded access and the labor/material tradeoff. Woodland framing, language and resident character can remain warm while metrics become aligned and actions predictable. These are testable design hypotheses; comparisons are not authority to import another game’s rules.

## Nine review packets turn the recommendations into bounded work

These plans are for review, not authorized implementation or guessed estimates. P0 means a prerequisite for trusting existing play; P1 is the next integrated slice; P2 is deeper expansion after that succeeds. These priorities differ from finding severity. Each packet separates adopted scope from proposed extensions and specifies the player journey, screens/data, phases, decisions, acceptance and risks. The sample UI names and quantities are illustrative, not approved balance.

| Packet | First deliverable | Expansion gate |
|---|---|---|
| P1 — Truthful interface | One source per field, stable selection and contextual actions | Additional workspaces after data/navigation are coherent. |
| P2 — Work/logistics | Conservation, ownership, visible task lifecycle | Priorities/targets after safe interruption and physical delivery. |
| P3 — Food/community | One crop→meal→resident loop | Then one fishing method, preservation and a bounded celebration. |
| P4 — Seasonal stewardship | Farm overview and actionable deadlines | Policies and before/after preparedness comparisons. |
| P5 — Routes/safety | Correct route/refusal/rescue state | Then benefit previews and optional practice. |
| P6 — Resident attachment | Consistent identity/current work/history | Richer memories and relationships under adopted rules. |
| P7 — First village | Teaching that recognizes real outcomes | Seasonal objective arc and continued free play. |
| P8 — World quality | Featured-asset contact and one complete work loop | Broader assets and bounded sound after acceptance. |
| P9 — Session/accessibility | Truthful menu, focus and scalable flows | Save enabled only after actual busy-state restoration. |

### P1 — One truthful village interface, with information placed where a player uses it

**Priority:** P0. **Status:** integration/usability completion of adopted UI direction. A new free-standing dashboard or command-search interaction needs a registered UI definition; it should not be slipped in as an unreviewed floating HUD widget.

**Problem/evidence:** The visible cast, settlement roster, map, top stocks and playable stores disagree; several subsystem panels mix instruction, diagnostics, global status, object status and actions. F10–F14 and F30–F47 establish the actual information problem. F10/F12/F14, [party layout](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:5), [Pantry layout](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:6).

**Target journey:** A player notices “2 jobs blocked” in village status, opens the queue, sees “Bridge: needs 3 more planks”, clicks the material, opens the relevant saw order, then follows its worker. Closing the workspace restores the previous selection and camera. A player opening Water to build sees its selected site's cost and build action immediately; safe land residents do not occupy its first page.

**Screens/data:** Use a single demo read-model adapter initially, keeping it explicitly separate from authoritative settlement simulation. Global row: usable food/reserve (only once meaningful), wood/stone/planks available/reserved, residents working/idle/at risk, date/weather. Selected-object inspector: identity + main state; most relevant action; concise cause; optional detailed statistics. Work/Stocks/Residents/News/Calendar each has one navigable workspace. The map/layer selector owns spatial questions; a Help/Codex view owns long instruction and library prose. Existing registry templates should be reused where they fit.

**Decisions to approve:** Whether the default demo is a guided village or an explicitly labeled lab; which currently unavailable release commands remain inspectable in the menu; whether a separate compact village overview is needed after existing UI-SET surfaces are correctly populated. Keep engineering reasons out of ordinary button descriptions.

**Work packages:** (1) Draw an information inventory and one source owner per displayed field. (2) Prototype the same selected bed/resident/bridge at 1280×720 and 1920×1080 before skin work; retain fixed title/actions and scroll optional detail. (3) Bind coherent resources, roster, selection and map. (4) Replace prose dumps with labeled/value rows and state-specific primary actions; add complete keyboard/focus descriptions. (5) Consolidate news/history and target navigation; migrate existing panels into this hierarchy, preserving the woodland art.

**Acceptance:** Same material totals across HUD, build cost and stock drill-down after spending/hauling; one resident selected from either world or roster resolves to the same identity and task. Once that setting is exposed, at 1280×720 with 150% user scale and long names, all key actions remain discoverable without shrinking below the documented font minimum. A tester can find the reason for a blocked bridge, take a relevant action, then return to it without the reviewer explaining the panel structure. News events survive a long paused inspection and resolve correctly. These are proposed acceptance scenarios, not claimed test results.

**Dependencies/risks/tradeoffs:** Needs a clear demo→production boundary and stable identity. A beautiful dashboard over false data would make the current confusion worse. More always-visible panels would crowd the world; favor reliable navigation and exceptions over permanent density.

**Concrete screen ownership proposal for P1.** This matrix is a proposed design deliverable to approve and prototype. It does not assert that these screens already exist or that the sample counts below were observed. Each field must map to the actual demo owner initially and the adopted production owner when integrated. “Persistent” means available throughout the session, not necessarily taking screen space all the time.

| Surface / question it owns | Field groups, in reading order | Primary action and navigation | Progressive disclosure; empty/blocked/paused behavior |
|---|---|---|---|
| **HUD — Is the village okay?** | Critical active condition count; food reserve only when meaningful; available/reserved core materials; living/idle/at-risk residents; date, current weather and next known change; selected speed and pause reason | Open the relevant workspace from each summary; one prominent current emergency target | No full resident roster, recipe list, raw XP or all forecasts here. “Unavailable” must not masquerade as zero. A paused badge says why; screen remains operable. Collapse genuinely unsupported summaries in this demo. |
| **Selected resident — What is this person doing, and what can I ask?** | Name/portrait/species/role; current action + target + phase; next/resumed task; relevant immediate risk; usable contextual actions | Center/follow; assign or cancel this order; return to routine; open Work/Skills/History | Show air only in water or when deciding an entry; show learned skill relevant to the current task, not all XP by default. “Holding: awaiting your order” differs from “No eligible work” and “Cannot reach target.” A mixed group becomes a concise group summary, never a blank panel. |
| **Selected bed — What does this crop need next?** | Bed/crop; one pressing need; predicted harvest quantity/date; current moisture band; assigned/queued work | One relevant action such as Harvest/Drain/Plant, with who responds and cost shown; center worker/bed | Soil/fertility/rotation, treatment history and full growth math sit in Details. Empty bed offers Plant with suitability; blocked growth names cause and remedy. Paused jobs show “Will start on resume”; no timer visually runs down. |
| **Crop picker — Which ingredient fits this bed and food plan?** | Four family groups; ingredient identity/icon; sowable now; game-days to maturity; expected quantity for this bed; soil/rotation effect; intended meal/order demand when supported | Select ingredient, review consequence, then Plant/Queue; compare with current crop | Keep shared family arithmetic shared: show one family explanation and distinguish ingredient use through approved recipes/preservation/variety. Do not pretend root variants have different yield/time when they do not. Before P3, label recipe uses as preview and avoid implying a missing mechanical advantage. Unsowable choices remain inspectable with the actual season/soil reason. |
| **Selected tree / zone — What may be taken and what remains?** | Tree state/yield; zone identity and protection; currently committed removals; job/worker; recovery if relevant | Fell/Haul/Gather/Plant based on state; open zone policy | Zone policy shows mature count, protected floor and remaining legal cuts together; other forestry statistics belong in Work/Stocks. Conservation has an explicit “No felling; deadfall gathering allowed” state. A waiting hauler says which feller it awaits. |
| **Selected tunnel segment / planned route — Is this route useful and safe?** | Endpoints and layer; planned/working/open/closed; clearance and eligible residents/loads; condition/hazard; selected job; cost/material delivery and work | Dig/Brace/Repair as appropriate; inspect route; center active worker; cancel/pause project | Hide settlement-wide finds/housing/weather paragraphs from the selected segment's first page. Full ground strata, fit dimensions and rate calculation are expandable. “Waiting at mouth”, “Load too wide”, “Closed by flood” and “No safe exit” are distinct and link to the relevant location. No room/home/cellar redesign. |
| **Bridge planner / project — Should I build this crossing?** | Site/endpoints; span and type; cost versus available/reserved stock; who can cross; work and material phase; benefit estimate with assumptions | Build or Queue; choose alternative type/site; source missing material; center builder | Keep the footer action and shortage visible. Global swimmer roster is elsewhere. With no site: one instruction to choose banks plus the existing-site list. Completed project becomes route/condition details rather than still showing construction-only controls. |
| **Water safety — Who needs attention now?** | Active victim/responder/bank; relevant conditions; selected resident's eligibility/consent/stamina; ordinary swimmers count | Center victim; inspect responder and safe exit; review consent before entry | Healthy residents on land are behind “All residents.” If no one is in water: “No active crossings or rescues”, not nine breath/stamina rows. Persistent unresolved rescue state remains available while paused and through other workspaces. |
| **Work / production — Why is work waiting?** | Counts by blocked/active/queued; rows with task, target, worker, phase, next dependency, priority; filter by system/resident/project | Prioritize, assign, pause/cancel, open dependency and center target; drill into work matrix/schedule | A missing ingredient, busy eligible worker, absent consent, full output store and unreachable contact each have a specific reason. Empty list says “No queued work” with legal creation actions. Paused simulation does not look like blocked labor. |
| **Stocks / Pantry — What can we use, and what will be lost?** | Tabs for Ready food / Ingredients / Materials / Seeds; item, available, reserved, location, next spoilage; endangered lots first when relevant | Open lots, location or consuming/producing orders; queue processing once supported | Keep theoretical recipe facts in Recipes. Storage locations are structured rows, not a joined sentence. Zero stock differs from reserved-only stock. Partial quantities remain visible when actionable. Empty pantry suggests an actual available source, not a giant list of future dishes. |
| **Recipes / orders — What can this station make?** | Active recipe; legal input choices; available/reserved ingredients; output and nutrition; staffing/work; Once/Repeat/Maintain target; blocker | Create/edit production order; inspect missing input or station | Distinguish a stable recipe definition, this order and specific lots. Inactive research candidates are a separately labeled collection. “Missing station”/“Missing ingredient”/“No assigned cook” each points to its owner; do not flatten them into a disabled button. |
| **Village news / chronicle — What happened and what still needs action?** | Active unresolved conditions separate from dated historical events; severity/source/target; latest change; resolution action | Jump to target or relevant remedy; acknowledge informational events; filter history | Toast lifetime never deletes active truth. Repeated rain/queue changes aggregate instead of flooding the list. “No active problems” does not erase past losses or rescues. Pausing permits reading indefinitely. Lore resides in optional detail; the action remains concise. |
| **Map / layers — Where is the thing I need?** | Authored village landmarks, camera extent, actors/sites; explicit active layer; selected subject/profile; legend | Click/keyboard-select and center; direct layer selection; clear layer | V remains a shortcut. Water range states which resident or mixed group is evaluated. Each layer has one question and consistent symbols; avoid simultaneous crop + water + forest text. No selection has a useful default or asks for the needed subject. |
| **Seasonal forecast — What should I prepare for?** | Known near-term events; planting/harvest deadlines; anticipated food/fuel and labor; affected sites; forecast assumptions | Inspect at-risk sites, prioritize preventive jobs, review reserve policy | Keep uncertain estimates distinct from guaranteed events. Offer an accessible table alongside timeline. Empty/no forecast says what is known, rather than implying perfect future weather. Date and event clock must agree with the demo HUD. |
| **Objectives / Help — What am I trying to achieve and how?** | One current objective; economic reason; real completion state; next legal action; optional related help | Center task or open its action; skip/reopen teaching; browse indexed help | No mandatory wall of controls. Recognize actions already completed, recover lost targets, explain blocked prerequisites. Hide forced-weather/cramp tools in a separate Demo Lab. Pause does not complete steps or lose guidance. |
| **Settings / session — Can I control and preserve this experience?** | Resume/save/load support; UI scale; input bindings; sound/motion/contrast; immediate preview and relevant limitations | Apply/revert a setting; restore defaults with visible changes; explicit save/load action | Return focus to the prior screen. A rebinding conflict offers a resolution, not silent replacement. Unsupported save behavior is stated before exit; loading validation preserves the current world on error. |

**Formatting rules to implement alongside the matrix:** use one labeled metric per row or a small aligned grid, right-align comparable quantities, use stable column widths, make units explicit and consistent, and avoid using a dot-separated sentence as a substitute for all information hierarchy. Put warning + reason + immediate action ahead of descriptive prose. A title and pinned footer survive overflow; details scroll, not the whole action out of reach. Numeric changes should not reorder the focused row unexpectedly. Optional diagnostics may retain raw values, but ordinary labels should express the player's actual decision.

**Specific proposed before/after copy.** “Before” strings are representative existing formatter output or source-documented examples, not all newly observed screenshots. Values in rewritten rows preserve that example's arithmetic; new job names/counts are illustrative UI specimens only. This is presentation design, not approval to change underlying balance.

| Existing readout / issue | Proposed operational readout | Detail retained on demand |
|---|---|---|
| `Moisture 6600 — good (2500–7000)` places the player on a 0–10000 internal scale. [farm_text.gd:134](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_text.gd:134) | **Soil moisture: Good · 66%** / “Suitable for this crop: 25–70%” with a banded meter and labeled limits | Exact value, last rain/water/drain change, why moisture affects growth. Use numerical values plus words; color is secondary. |
| `Loam · fertility 63% (yield ×0.81) · health 82%` mixes causes in one sentence. [farm_text.gd:140](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_text.gd:140) | **Soil: Loam** / **Fertility: 63%** / **Fertility effect on yield: −19%** / **Crop health: 82%** | Full combined yield breakdown, previous crop family and treatments. Do not imply the fertility effect alone equals final expected yield. |
| Crop row `%s · 120 h · 6 U · roots`, followed by rotation text. [farm_text.gd:77](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_text.gd:77) | **Carrot · Root crop** / “Matures in 5 game days” / “Base harvest: 6 U; this bed: [actual estimate]” / “Rotation effect: [actual reason]” | The shared roots-family rule and, once P3 is implemented, which current meal/stock target uses carrot. Avoid inventing distinct growth stats for otherwise equal root choices. |
| `Carrot — 5 U · 80% fresh, spoils in 190 h` requires unit conversion while acting. [farm_pantry_panel.gd:209](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:209) | Columns **Carrot / Available 5 U / Oldest lot expiry / Store**; show “7d 22h” only if the corrected calendar forecast really yields 190 hours, not by converting raw aging units; put endangered stock first | Freshness 80%, exact lots/age/quality, reservation and expiry assumptions. Never label all 5 U as expiring together if only the oldest lot is. |
| Raw experience is mixed into the active resident panel. [party status source](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:216) | **Felling · Level 3** with a labeled progress meter to the next level, shown when relevant | Exact accumulated XP, next threshold and the work-rate formula in Skills. Do not invent an arbitrary “expert” rank separate from existing levels. |
| Breath `1200/1200` while on land asks the user to interpret tick budget. [swim state owner](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/swim_state.gd) | On land, omit breath from the first page. Before a dive, **Air: full · planned return has reserve** only if the planner actually certifies it; submerged, show percentage and current return state | Exact budget/cost and remaining time when a valid deterministic conversion exists. Never guess safety from a full meter alone. |
| A raw crew multiplier or detailed rate is prominent. [tunnel crew model](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_crew_task.gd) | **Crew: [actual assigned count] · digging [current segment]**; status first, then **Work rate: 1.51× baseline** if the underlying rate is 1506 per mille | Which faces/helpers/skills contribute and why another helper cannot join. Multipliers are not percentages of completion. |
| The selected bridge's cost/refusal is a long sentence. [waterplay_text.gd:118](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/waterplay_text.gd:118) | **Plank footbridge** / “Planks: 0.0 available / 4.7 U needed” / **Blocked: 4.7 U planks missing** / primary action **Queue sawing…** | Deck/span/pier/work assumptions and legal alternatives; show “Build” only when it can commit. Do not auto-spend or auto-create unapproved orders from a tooltip. |
| `Demo stores: ... (shared with ... HUD...)` explains implementation separation to the player. [forest_text.gd:55](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_text.gd:55) | A coherent **Village materials** view with **Available / Reserved / In transit** rows, matching the HUD | Development ownership belongs in Demo Lab. If the integration is not complete, the ordinary demo should show only its real usable stores. |
| `Swimmers — 0 in water` is followed by every healthy resident's full meters. [waterplay_text.gd:162](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/waterplay_text.gd:162) | **Water: no active crossings or rescues**; next section **Selected bridge site** or **Selected resident** | Optional “All residents' water abilities” list, searchable/selectable and not ahead of the task the player opened. |

**Example inspector wireframes.** These are text prototypes with illustrative state, not screenshots or claims of current model values. The same hierarchy must survive a short window without hiding the selected-party identity or the primary action.

```text
BED 3 · CARROTS                            [Center] [Close]
READY TO HARVEST
Full yield for 2 more game days

Expected harvest        5.1 U
Assigned worker         None
Destination             Covered store

[Queue harvest for field crew]  [Assign selected resident…]

▸ Crop and soil details
▸ Work already queued
▸ Treatment / rotation history
```

```text
NORTH FOOTBRIDGE                           [Center] [Close]
AWAITING MATERIAL

                         Available    Required
Planks                    0.0 U       4.7 U
Wood for piers            0.0 U       0.0 U

Benefit                  A dry crossing for loaded residents
Builder                  Unassigned

[Queue sawing…]            [Change bridge type]
▸ Survey and route comparison
▸ Construction plan / eligibility

Footer: construction is paused with the village
```

**Crop-choice quality acceptance:** The current sixteen ingredients share four growth families; that is intentional arithmetic, not evidence of a faulty crop model. In the revised picker, an unfamiliar player should be able to distinguish “same growing rules, different ingredient use” from “different agronomic tradeoff.” If no implemented recipe/reserve/variety objective makes carrot preferable to a sibling root, acknowledge that the choice is currently aesthetic. Earn functional differentiation through P3's approved ingredient demand and P4's season/rotation context; do not manufacture unsupported bonuses to make every row appear unique.

### P2 — Explainable labor, work priorities and material delivery

**Priority:** P0 foundations, P1 playable integration. **Status:** adopted autonomy/jobs/logistics direction; a saved named “crew preset” is an optional extension requiring a small data/UI decision.

**Problem/evidence:** Fixed automatic crews and subsystem boards leave the player guessing who will respond. Direct work interrupts other tasks whose resume flow already has bugs. The GDD specifies eligibility, urgency, priorities and a limited manual-task queue; these must remain the common policy rather than inventing a second labor system. [GDD §5.3](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:335), [farm crew](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:6), [forest crew](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_crew.gd:7).

**Target journey:** The player raises harvest priority, allows two residents to cover farm work, then orders the forester to clear a path urgently. The queue says what was interrupted and what resumes. The player can see that planks are waiting for hauling, not conclude the saw has stopped producing. A bridge shortage appears as a material dependency with a legal source, not a vague worker failure.

**Screens/data:** Work overview with queued/assigned/travel/work/haul/blocked states; job → worker/source/destination links; resident priorities and schedule; selected worker current order and saved work; stock reservations; per-project delivered/remaining material. Read existing job state and reservation owners. Keep urgency and eligibility reasons structured so UI, logs and tests agree.

**Decisions to approve:** For the demo-to-production transition, use existing priority/urgency rules and name any deliberate demo simplification. Decide how direct orders expire/resume and how a multi-selection allocates one-worker versus cooperative work; this must not silently override safety/needs. Decide whether simple saved crews add value before exposing a full scheduling matrix at nine residents.

**Work packages:** (1) Repair and test ownership, arrival, cancellation, resume and segment handoffs from F02–F08. (2) Add a read-only unified work view over current boards. (3) Expose explicit automatic crew membership and assignment preview. (4) Integrate the adopted scheduling/eligibility model, preserving resource reservations and a single active job owner per resident. (5) Add stock-target orders for a small material chain and readable blocked causes; expand only after harvesting and one bridge can coexist correctly.

**Acceptance:** Queue six bed/wood/bridge tasks with no selected residents; the right eligible residents claim work and the player can explain remaining idle/blocked cases. Interrupt hauling with a rescue; conserve load, reservations and work, then resume exactly once. Cancel/reassign at every phase without remote delivery, duplicate credit or stranded residents. Run the same command schedule at equal ticks at 1× / 2× / 4× and compare outcomes. Profile the existing candidate/routing budget rather than adding an unbounded global scan.

**Dependencies/risks/tradeoffs:** Requires fixed route/job transitions and the production movement interfaces before claiming final autonomy. Over-automation can hide interesting choices; automate repeated execution, retain policy and urgent override. A large matrix too early makes a nine-resident demo feel like administration—offer task-oriented defaults and drill down.


**Lifecycle work detail:** preserve stable job identity, paid/reserved input state, source/destination, carried load and completion ownership through every rewind/reassignment. Distinguish desired production policy from its current resident task. Cancel production does not automatically discard or credit an in-transit load: expose Continue delivery or a recoverable local drop. Farm and forestry must share the same conservation rule even if their internal job tables remain separate. Integrate the read-only Work surface before replacing algorithms so the player and test harness can see every waiting cause. Individual Cancel/Pause must identify its scope; keep Cancel all work separate and explicit.

### P3 — Finish one harvest-to-table economy, then fishing and preservation

**Priority:** P1, highest new playable integration value. **Status:** cooking, preservation, consumption, sustainable fishing and feasts are adopted scope; specific fine-grained ingredient/recipe activation is a content/balance approval. Start narrow.

**Problem/evidence:** Harvest→Pantry is real; Pantry→meal→resident is not. Fishing returns candidate lots without delivery. The current dish list contains explicitly inactive research candidates. Consequently food quantity is not a satisfying survival or cultural payoff. [farm_pantry_panel.gd:9](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:9), [fishing_driver.gd:6](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:6), [GDD catalogs](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:509).

**Target journey:** Choose a crop for tomorrow's supper, see the kitchen's missing input, harvest and deliver it, watch a named cook prepare the approved dish, then see residents served and the food reserve update. Later the player chooses whether a seasonal catch becomes supper or preserved winter food. An optional small celebration visibly consumes a surplus and records the occasion.

**Scope/screens/data:** First slice: one approved staple recipe, one station, lots/reservation/quality, a producer and a real consumption endpoint. Stocks shows ready food, ingredients and seeds distinctly; Orders shows Once/Repeat/Maintain stock, inputs, output and blocker; Recipe detail shows stable recipe facts separately from available lots. Second slice: one safe bank-fishing gear/site/species workflow using the existing habitat stock and whitelist, then a preservation recipe. Third: one already legal feast theme when its staffing/serving/reserve prerequisites work. Root-cellar geometry/design is out of scope; consume its storage API later.

**Decisions to approve:** Which current fine-grained farm ingredients legally map into active recipe inputs—do not silently convert every vegetable to generic roots or activate all library dishes. Confirm the active item's quantity, nutrition, shelf life, work and unlock owner. Choose a narrow supported fishing method before boats/diving production. Use the existing raw-emergency-food and variety policies; any new cultural preferences or consumption restrictions need explicit rules.

**Work packages:** (1) Approve exact content and demo/production economy binding. (2) Add consume/reserve/return/output transactions and inventory conservation tests. (3) Wire a complete crop meal with believable carry/cook/serve presentation. (4) Add freshness-aware orders and actionable missing-input state. (5) Integrate one fishing cycle through arrival, effort/quota claim, catch, hauling and pantry intake; release claims safely on cancel. (6) Add one preservation and one feast flow, then expand the catalog through validated content batches.

**Acceptance:** A player can complete a meal without developer controls; ingredients disappear once, outputs appear once, diners consume actual lots and the displayed reserve derives from the same quantities. Interrupt/reload during reservation, cooking, delivery and serving without duplication or freshness reset. Fishing quota/closure/stock agree before and after landing a catch; unreachable bank or canceled expedition releases claims. A feast preview shows post-feast reserve and refuses invalid staffing/inputs. A content candidate with no approved quantities remains visibly inactive.

**Dependencies/risks/tradeoffs:** Depends on P1/P2 and stable actual resident/needs ownership. This is the largest cross-system integration, so do not start with the entire content library. If the demo remains presentation-only, explicitly choose a bounded demo economy and document what cannot yet be represented faithfully, rather than insinuate production readiness. Avoid making every dish a new percentage buff; cooking's first payoff is feeding and connecting people.

### P4 — A seasonal stewardship planner with meaningful environmental choices

**Priority:** P1 after truthful stocks/labor. **Status:** calendar/forecast/rotation/quota/reserve direction already adopted. New policy presets and before/after comparison views are proposed presentation extensions; no new ecology constants are supplied here.

**Problem/evidence:** The ingredients of seasonal play exist—wet beds, frost cover, drainage, crop family, conservation floors, regrowth, fish closures—but are exposed as local figures and transient warnings. The player must aggregate them by memory, and the compressed demo day can convert planning into alert chasing. [README farm threats](/Users/brendan/Developer/redwall-review/godot/demo/README.md:313), [woods policies](/Users/brendan/Developer/redwall-review/godot/demo/README.md:433), [GDD weather and reserves](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600).

**Target journey:** At season start, inspect a compact calendar: planting/harvest windows, known frost/rain and relevant closure dates. Compare labor and food needs; choose to drain one vulnerable bed and preserve another harvest. After the rain, the report explains which investment prevented loss and which shortage remains. The woodland continues to look and behave differently because of the player's policy.

**Screens/data:** Calendar timeline with table alternative; at-risk fields/stocks; next relevant deadline; reserve projection with assumptions; ecology detail for one habitat/zone with stock/floor/committed extraction/recovery; end-of-day or season review of produced/consumed/spoiled/missed work. Source forecasts from actual known state; distinguish certain scheduled events, current conditions and estimates.

**Decisions to approve:** Retain GDD bounded event scheduling. Decide tutorial time compression, warning lead time and pause-on-management options from playtests—not invented hidden difficulty. Decide whether automated tending/covering is a simple permission/priority choice under P2 or needs a new policy; avoid a large programmable automation system.

**Work packages:** (1) Define units and forecast semantics, including what cannot be predicted. (2) Connect the calendar to beds, weather and quotas with object links. (3) Add two counterfactual comparisons for supported choices: untreated versus drained bed, present stock versus planned consumption/reservations. (4) Add a compact after-action record based on committed outcomes. (5) Tune one season with labor/time telemetry and new-player sessions; only then add more ecological events or extra crops.

**Acceptance:** A player given a frost warning can locate affected beds, select a remedy and see the crew/deadline without searching unrelated panels. Rain shown in the world, soil response and calendar agree. A forestry order cannot count protected or already-reserved trees as freely available. Food projections label excluded/unreachable/spoiling stocks and update on an order change. Pausing never expires the only actionable warning. At least two viable preparedness approaches exist in the authored test scenario; they are not required to have identical outcomes.

**Dependencies/risks/tradeoffs:** P1/P2/P3 for meaningful food and labor projections. Avoid false precision: confidence/assumptions matter more than additional decimal places. Conservation should visibly affect recovery and options already supported by the model; do not invent biodiversity buffs merely to make a green number rise.


**Farm overview work detail:** begin with six comparable rows—bed/crop, stage, forecasted harvest and quantity, moisture condition, assigned task and next sowing plan—with Needs attention and Harvest soon views. Click a row for one focused inspector, not every model scalar. Normalize the raw 0–10000 moisture/fertility presentation, show percentage-point treatment effects, fix F27/F28 forecasts/totals, and rearm recurring alerts. Keep the crop picker current when the date changes while preserving focus and scroll. A next-crop queue and batch identical orders are useful bounded extensions once their season eligibility and worker budget are visible; never auto-spend for an impossible window. Sixteen ingredient names sharing four growth families should be grouped honestly, with distinct culinary demand earned through P3 rather than invented agronomic bonuses.

### P5 — Make bridges, tunnels and water safety understandable infrastructure

**Priority:** P1 after movement fixes. **Status:** connected movement and warned/preventable hazards are adopted. Benefit comparison/route-inspection screens are proposed UI work; new traversal types or hazard penalties require the existing movement gates and numerical owners.

**Problem/evidence:** The village has different viable routes, body/load fits, weather costs, mouth queues and rescue logic. The controls show many local facts but do not consistently answer why this project is worth building or why this resident cannot use it. F02–F08 expose correctness prerequisites. [Movement requirements](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md), [water/tunnel behavior](/Users/brendan/Developer/redwall-review/godot/demo/README.md), F02–F08.

**Target journey:** Choose a work destination and compare the current ford with a proposed footbridge: estimated loaded travel, who can use each, material/work cost and relevant hazard. Build it and see the actual haul use the new route. Before rain, inspect an unbraced wet bore, see the threatened route and brace or suspend it. A rescue alert selects the endangered resident, shows the actual responder and destination, and leaves an understandable recovery outcome.

**Screens/data:** Planning inspector: endpoints, length, clearance, material/work, eligibility, refusal and exit requirements. Route overlay: chosen path, surface/underground/water segments, queue/wait reason and load profile. Project list: planned/awaiting material/working/open/closed/repair; rescue panel pinned above ordinary water data. Use graph/profile revisions, real cost and reservation state; cache or budget comparison calculations.

**Decisions to approve:** Which route estimate is safe to expose before production routing gates close; how to state uncertainty and distinguish waiting from impossibility. Which surface-only bridge/tunnel milestones best serve the scenario. Retain current approved non-graphic injury/care direction; do not add random drowning/falling or remove demo safety fallback without the owning specification and testing.

**Work packages:** (1) Fix route invalidation, consent recheck, crew handoff and arrival ownership. (2) Add typed route refusal/status readouts. (3) Implement preview and cost/benefit comparison on one ford/bridge route and one useful tunnel, excluding chambers. (4) Connect job/material/rescue navigation. (5) Add visual route feedback and test loaded/mixed-species groups, hazard closure and evacuation. (6) Integrate injuries/recovery only through the adopted care contract.

**Acceptance:** Group comparison cannot claim a route fits because only its lead fits. Changing load or consent before entry causes safe revalidation. Closing a route does not cause empty-path access, remote work, erased cargo or a stranded occupant. A proposed route reports a blocker that the player can inspect spatially. Built travel benefits are observable in a repeatable haul fixture. Rescue identifies responder, victim and bank correctly through pause, cancellation and eventual recovery. Navigation profiling verifies no synchronous burst erases responsiveness.

**Dependencies/risks/tradeoffs:** P2 resource/job integrity; MOVE-G01–05 for production guarantees. Route comparison can itself become a performance problem, so cap work and show “calculating” honestly. Too many numeric overlays spoil readability; keep only the current question active and make the subject explicit.


**Water-safety work detail:** fix capability-aware rescue and threshold-latched notices before adding more danger. One persistent incident card owns victim, responder, landing, phase, approximate ETA or explicit blockage, and center/select actions. Test submerged victim with nearer nondiver/farther diver; rescuer interruption; second victim; no capable swimmer; blocked approach/landing; cold/high flow; and 1×/4× stepping. Record time to contact and minimum air/stamina, not only eventual rescued count. Re-evaluate fallback assignments and preserve the nonfatal safety net. An optional, clearly named practice scenario can teach consent, fords, a bridge and assistance; new boats/line equipment are later proposals, not prerequisites for fixing dispatch.

**Project/woodland connection:** expose a bridge’s delivered, reserved and missing materials and link to a saw/haul task. A bounded “keep N planks” order plus a protected woodland zone is enough to prove useful automation; no general factory-programming language is needed. Never count protected or already-committed timber as available. When the route opens, use a repeatable loaded-haul fixture to show that the investment actually improves that journey.

### P6 — Residents as recognizable contributors, with memories grounded in play

**Priority:** P1 minimum identity/status; P2 richer community expression. **Status:** identity, skills, relationships, needs and chronicle are adopted. Mentorship bonuses, new traits or mechanical social rewards are optional expansions and are not included without a separate approved rules packet.

**Problem/evidence:** The journal's residents differ from the demo cast, and trade labels/routine wandering do not create persistent personal context. Skilled work and rescues offer natural moments of attachment, but the interface cannot follow them coherently. [cast_routines.gd:2](/Users/brendan/Developer/redwall-review/godot/demo/cast/cast_routines.gd:2), F14, [GDD persistent identity/chronicle](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:110).

**Target journey:** The player notices a worker by name, sees “Hauling planks to the north bridge; then returning to the harvest,” learns their skill and legitimate movement limits, and follows them. Later the inspector records the completed bridge or assistance event with links to the place/person. Ordinary meals and social moments express the existing needs/relationships rather than exist as unrelated decorative loops.

**Screens/data:** One roster and one resident inspector: identity/portrait/role; current work and reason; immediate needs; skills and progress; relevant relationships; chronological notable events. Detail stays optional; selection does not show every statistic at once. Chronicle entries attach only to committed events and stable identity; presentation prose and source references remain separate from simulation storage.

**Decisions to approve:** Establish whether this demo cast is an original community or a specifically authored Rowan scenario; do not silently equate “Mouse keeper” with Rowan or combine literary eras. Approve individual names, interests and light dialect, without personality by species. Choose a small bounded set of notable event types. Family-stage mechanics remain dependent on PC-04 and are not a prerequisite for basic adult attachment.

**Work packages:** (1) Bind consistent identity, select/center and current job. (2) Show skills/needs from the actual playable owner. (3) Record assistance, skill achievement and completed communal project events. (4) Add a few ordinary-life animations and short authored contextual lines connected to real schedule/events. (5) Introduce richer relationships/family presentation only as existing rules become fully specified and integrated.

**Acceptance:** Rename, selection, work history and camera navigation refer to the same person across all screens and reload. A canceled job generates no “completed project” memory; a rescue records only actual successful assistance. Two residents of the same species can have different trades, interests and history. A novice can improve through real work. The UI distinguishes learned skill from physical clearance, consent and injury. Essential action information remains understandable with all flavor text hidden.

**Dependencies/risks/tradeoffs:** P1/P2/P3 identity and behavior. Personality text detached from events will feel synthetic; keep small truthful observations. Avoid frequent barks, long biographies or every ordinary action becoming a notification. Long-term social expansion is not needed to prove the first satisfying meal or skill milestone.

### P7 — A guided first village and a reason to continue

**Priority:** P1. **Status:** progressive disclosure/objectives are adopted; the exact demo scenario and milestones require design approval. This is not a new campaign or altered Charter victory rule.

**Problem/evidence:** Many controls and partially active surfaces appear at once, with no confirmed demo objective owner. Experimental controls compete with ordinary verbs. Players can learn a command without learning why it matters. [demo bootstrap](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:74), [GDD disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:824), [demo controls](/Users/brendan/Developer/redwall-review/godot/demo/README.md:111).

**Target journey:** A player starts with one local objective and a clear village view: inspect a resident, bring a ripe harvest into store, and learn how to see the actual outcome. In the next integrated slice, the objective becomes “serve the first supper.” The player then chooses one improvement—safe bridge, useful dry route, or better field preparation—before a foreseeable seasonal event. Completion acknowledges the community and offers continued free play.

**Scope/screens/data:** One tutorial card at a time; a compact objective list with current cause/blocker; a searchable help page; world target highlight; a scenario manifest identifying supported systems and starting conditions. A separate Demo Lab holds forced weather/events/cramp and diagnostics. Objective state must consume real outcomes and survive interrupted actions; progress is not a timer or a sequence of button presses.

**Decisions to approve:** Choose the single opening promise and which later systems are inspectable. Approve exact objective text and deterministic fixture conditions. First demo milestone should not pretend the three-year Charter is earned; the Charter remains the existing community-authored long-term goal. Let experienced users skip teaching without gaining resources or changing unlocks.

**Work packages:** (1) Map first-session tasks and record baseline player failure points. (2) Create a small interactive teach/try/confirm sequence using current working activities. (3) Unify contextual help and legal action prompts. (4) Replace the ending with the meal/season payoff when P3/P4 land. (5) Add one alternative preparedness choice and continued sandbox; use observations to adjust pacing before building more scenarios.

**Acceptance:** A new tester can select/inspect, issue/queue, pause, find the work result, recover from a refusal and locate help without the reviewer supplying controls. Destroyed/unavailable targets never softlock a step; completed-before-prompt objectives recognize real state. Skip/reopen works. A lesson on placing a bridge waits for actual usable completion, not clicking Build. Record task success, time spent searching and mistaken clicks as evaluation data; numerical thresholds should be set after baseline sessions, not fabricated in this report.

**Dependencies/risks/tradeoffs:** P1 truth and at least one complete economic loop. Over-scripted tutorials can hide autonomy and block creativity; allow alternate valid solutions and preserve ordinary controls. Avoid promising unfinished mechanics through attractive but unavailable buildings.

### P8 — World cohesion, action readability and a bounded sound pass

**Priority:** P1 acceptance gate for existing featured assets; P2 expanded content. **Status:** adopted grounded/expressive art and contextual sound direction; exact asset/cue briefs and budgets need approval. This plan is a production/acceptance approach, not a claim of specific unseen defects.

**Problem/evidence:** The README documents per-family sinking offsets, unchecked +Z authoring on props, card substitutions among crops, and staged-but-unused bridge models. These are concrete inspection targets. The targeted source scan found no demo audio playback owner. F16/F17 identify entrance/gait limitations. [Asset pass README](/Users/brendan/Developer/redwall-review/godot/demo/README.md:360), [forestry grounding](/Users/brendan/Developer/redwall-review/godot/demo/README.md:449), [visual direction](/Users/brendan/Developer/redwall-review/docs/art-reference/visual_direction_alignment.md), [DEC-021](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:591).

**Target journey:** From normal play height, the player recognizes a worker's job, a usable entrance, a harvested bed and a bridge stage. At a low inspection angle, roots/buildings meet the terrain without obvious gaps or buried doorsteps; hands hold tools/cargo plausibly. Water, footsteps and work have restrained positional sound; completion and danger have distinguishable cues that remain understandable when muted.

**Scope/screens/data:** A reviewed asset manifest records support/contact plane, gameplay anchor, facing, collision and selection footprint separately from decorative extents. Standard camera/lighting fixtures cover village overview, resident close-up, low ground angle, rain/night and relevant transitions. Audio event mapping consumes completed gameplay/presentation events with priority, range, rate limit, bus and fallback caption/icon; no animation event may award resources.

**Decisions to approve:** Set an explicit visual acceptance bar at the normal game camera and at supported zoom limits, following the approved world-art reference. Decide whether rough high-poly-derived textures/cards are temporary or acceptable by camera distance. Approve a small cue palette and practical stream/voice budgets before commissioning large music/voice content. Species scale changes remain separate from grounding fixes.

**Work packages:** (1) Capture and classify featured assets by contact, silhouette, material, texel consistency, scale and function; feed this report’s observed defects into the list. (2) Fix systemic anchors/terrain contact and verify authored sinks across all placements; do not simply sink everything until gaps disappear. (3) Match work/carry/transition poses and prop orientation; replace conspicuous repeated proxy crops as needed. (4) Create bounded ambience/work/water/notification cues with volume and reduced-stimulation options. (5) Run a full gameplay capture to test visual/audio density, clarity and memory/frame cost together.

**Acceptance:** At every featured asset and supported camera angle: no visible floating base, detached root mound, buried entrance, ground clipping through a usable floor or selection footprint unrelated to the target. At least one full start/work/carry/drop/return cycle per featured species has credible contact and consistent state. Crop stages read distinctly at game camera distance; comparison is by screenshot/animation, not triangle count alone. Sounds do not multiply uncontrollably at 4×, during rain or with many workers; muted play preserves all essential information. No budget is claimed without measurement.

**Dependencies/risks/tradeoffs:** This review’s visual evidence, approved art direction and performance profiling. Per-asset offsets are useful but fragile on varied terrain; support/contact metadata should explain them. Bigger textures and denser geometry can hide weak silhouette and increase memory cost without helping the RTS view. Favor conspicuous assets the player handles over distant decorative variety.


**Concrete asset/contact packets:** start with the mouse/otter, oak/beech, hall/store, weir/mill and one tool/load. Record pivot, scale, support/attachment anchors, door/use point, obstruction shape, root-height data, material family and LOD policy separately from decorative bounds. Integrate the weir with banks/bed and one water surface; use oriented cached support data for roots where useful. Verify the existing per-key sink fixes before altering them. Changing species scale or reviewing the excluded underground interiors is not part of this work.

**Material/camera/weather packets:** capture matched clear/rain/frost/snow views at close, normal and far distance, with overlays and selection. Replace the unsupported flat frost/snow treatment with surface-aware accumulation. Resolve the demonstrated canopy occlusion with scoped camera/cutaway/selection behavior, then check extra transparency cost. Assess ground/water against the approved world-art reference rather than the UI-only lock. Define graphics tiers and profile the 8192 atlas/ULTRA shadow choice on qualification hardware; its setting name alone is not a failure.

**Embodied-work packet:** storyboard fell → shape → carry → saw → stack → bridge, including refusals, interruption and recovery. Align tools to targets, hands to loads and feet to support; let confirmed work change the object and actual delivery change inventory. Animation events never award resources. Test the slice as a silent video, then add bounded surface footsteps, wood/saw strikes, pickup/drop, splashes, ambience and completion sounds with independent buses, falloff, voice/rate limits and visual equivalents. Only then generalize it to farming and the selected fishing method.

**Evidence to close P8:** matched captures at 720p/1080p; five-second work/turn/idle loops for featured species; root/bank/threshold paths; twenty complete fall/haul/regrowth cycles with bounded resources; measured p95/p99 and memory on representative hardware. Exact tolerances belong to the owning art/performance contracts. Avoid merely sinking every model or increasing texture/triangle density before RTS-scale silhouette and action are legible. Paid regeneration requires a separate itemized decision; this review approves no spending.

### P9 — Session continuity and accessible completion of core flows

**Priority:** P0 truthful limitation messaging and accessible controls; P1 persistence integration. **Status:** existing saves/settings/keyboard/accessibility requirements, not an optional late polish feature. Actual production save implementation must honor its owning versioned contract.

**Problem/evidence:** The current availability gate names a missing save codec, and the playable demo's state is separate from the settlement. UI text scale, key discoverability, focus, loss of guidance and warning expiry are already material concerns. [ui_availability.gd:219](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:219), [GDD save rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:812), [UI requirements](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:432).

**Target journey:** A player can enlarge text, rebind a conflicting key, perform core management without precise pointer aiming, save during a complex workday and return to the same village. If a demo does not support persistence yet, the session limitation is clear before substantial investment and exit never falsely implies a successful save.

**Scope/screens/data:** Menu and settings with working feedback; versioned save/load for the actual calendar, lots, cast/jobs, graph, crossing/rescue state, queues, reservations, policies and relevant tutorial/history state; preserve existing authoritative save owners and rebuild render caches. Keyboard world list and context actions need the same identity binding as the visible cast. Critical events have text+shape+sound options; UI scale must reflow whole workflows.

**Decisions to approve:** Whether to invest in a bounded demo-session format or move the playable systems under the production save contract first. A separate demo save must be clearly versioned and never masquerade as a normal settlement save. Decide supported input methods/reader qualification for this demo slice, while retaining the release accessibility obligations.

**Work packages:** (1) Audit current menu behavior with an actual quit/reload trial and document support honestly. (2) Fix key/focus/scale paths for selecting, ordering, building, reading a warning and closing a workspace. (3) Define a complete persistence-state inventory and version ownership. (4) Implement/load-validate the chosen contract with atomic commit and preserved incompatible files. (5) Test busy-state reloads plus whole keyboard/large-text workflows; profile save pause and restoration behavior.

**Acceptance:** Quit/reload while a worker carries goods, a helper changes segments, a resident queues at a mouth, a crossing is occupied and a crop is near spoilage. State/next action/resources match uninterrupted controls; no item duplication, unsafe repositioning or forgotten manual task. Corrupt/incompatible saves leave the current world and original file intact. Every core command is reachable with the agreed non-pointer input path; focus can leave every widget, disabled reasons can be read, and changed text scale preserves action access. Test actual assistive technology before claiming compliance.

**Dependencies/risks/tradeoffs:** Movement serialization gates and P1/P2 stable ownership. A throwaway save format can become a second architecture; keep its scope explicit or favor production integration. Accessibility helps expose information hierarchy problems early; it should not be postponed until every screen has been skinned.


## Acceptance must follow real player paths and real assets

Typed inference (`:=`) was treated as typed code. The targeted declaration/function scan did not establish additional missing types or functions over 30 executable lines after excluding comments/docstrings. No proven per-frame `get_node()` site was found in the traced paths. UI intent signals were not mislabeled as simulation signals. Presentation transforms and movement floats are explicitly allowed under decision 0196; the stores reviewed use integer milli-U. Sentinel-style APIs remain common, but F02/F15 identify concrete unsafe transitions instead of counting each `-1` as a separate bug. This is targeted coverage, not certification of every file.

The implementation has useful foundations: graph revision caching, integer capacity/resource checks, named refusals, body/load fit, cached resources, prewarmed tree splits, MultiMesh cover and separate UI/world clocks. Failures concentrate at lifecycle and ownership boundaries. A unit test can be useful yet unable to prove a handoff it manually performs itself. F09’s crew/resume/consent gaps need actual process-order integration cases; F24’s cancellation-credit tests need a revised behavior contract. Similarly, fake banded columns and radial-root tests cannot establish contact with an asymmetric shipped tree. Keep cheap synthetic cases, then add representative actual-asset acceptance. [Root tests](/Users/brendan/Developer/redwall-review/godot/test/test_demo_forestry.gd:1018), [mesh fixtures](/Users/brendan/Developer/redwall-review/godot/test/test_demo_forestry.gd:1098).

### The support survey also found real passes

All nine village building/prop instances sampled contact or intersect ground across all four footprint quadrants. Existing per-key sinks are applied, so repeating an older generic “all plinths float” complaint would be inaccurate. The survey transformed actual staged triangle vertices with their authored positions, yaw and scale, then compared them with terrain; the weir additionally used exact rendered-grid interpolation. This is stronger than AABB contact, but cannot automatically judge every semantic doorway, leg, usable floor or root. The central sun/rain views also looked coherent and grounded; the specific weir and camera problems should not become a blanket poor-asset verdict.

| Placement | Measured support | Limit |
|---|---|---|
| Hall `(0,-13)` | y-min 0; 287 vertices within 2 cm; 4 quadrants | Individual steps/thresholds still need close inspection. |
| Well `(0,0)` | y-min 0; 116 vertices within 2 cm; 4 quadrants | Grounded apron present. |
| Residences a/b/c | y-min −0.42; 578 touching/buried vertices each; 4 quadrants | Existing surface plinth sink works; no interior/home redesign reviewed. |
| Kitchen `(13.5,-6)` | y-min −0.11; 1,053 touching/buried; 4 quadrants | Base contacts datum. |
| Covered store `(14,6.2)` | y-min −0.12; 302 touching/buried; 4 quadrants | Check individual staddle/door semantics before changing offset. |
| Stockpile `(12.6,-15.2)` | y-min 0; 52 within 2 cm; 4 quadrants | Raised platform has ground-level support geometry. |
| Workbench `(8.6,12.6)` | y-min −0.07; 953 touching/buried; 4 quadrants | Border sunk; platform support exists. |
| Mill `(27.9,-19.5)` | 1,478 touching/buried; 4 quadrants | Bank contact exists; wheel/waterline function not accepted. |
| Boathouse `(22.9,23.4)` | 1,798 touching/buried; 4 quadrants | Some base points 1.077 m above bed can be over-water structure; not proof the whole building floats. |
| Fisher shelter `(22.9,7.3)` | 49 touching/buried; 3 quadrants | Some outer points ~0.42 m above bed require pier/support interpretation. |
| Weir `(23.8,-14)` | No bed/bank contact; bottom band 0.469–0.834 m above rendered bed | F41’s exact support defect; controlled view independently confirms detached diorama appearance. |

Actual L0 triangle counts: oak 5,829; beech 5,801; residence 29,665; hall 29,482; kitchen 29,963; covered store 29,804; workbench 15,399; fence 5,682. There are 173 tree placements. Counts alone do not prove overload: culling, imported LODs, materials and screen coverage determine cost. The demo uses an 8192 directional-shadow atlas and ULTRA soft filtering, which need a measured graphics-tier acceptance path on the GTX1660 floor. The short soak’s ~1.4735 GB static-memory value includes staged scene/resources and is not the <100 MB simulation-state budget. A flat short soak also does not override the targeted retained-node proof in F18. [Support log](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_building_support.log), [mesh/lifecycle log](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.log), [shadow setting](/Users/brendan/Developer/redwall-review/godot/demo/world/world_look.gd:37), [application](/Users/brendan/Developer/redwall-review/godot/demo/world/world_look.gd:110).

### Rendered sampling found inconsistent margin, not a qualified performance pass

The native game was measured at an actual **1920×1080** window and viewport using Godot 4.7.2, Metal/Forward+ on an Apple M5 Pro. VSync was disabled and `max_fps=0`. There was **one five-second warmup before the first sampled phase**, followed by three sequential twenty-second phases in the same evolving world. Only the change to the wide-forest camera received an additional **60 settling frames**; the village and group-order phases were not independently reset or warmed up. This is sequential observational sampling, not an isolated causal comparison of camera or speed effects. The focused repeat explicitly waited for a native click and F9 before that initial warmup; no other review game/editor ran alongside it. Other work on the shared host was not controlled. The earlier automatic-start sample is retained to expose the variability instead of selecting the most favorable run.

The reported metric is the **wall interval between SceneTree `process_frame` callbacks in the rendered native game**. It is useful responsiveness evidence but is not a GPU timestamp, display-present capture or exact simulation-tick duration. The log also records `Performance.TIME_PROCESS`; that engine monitor must not be equated with the <2 ms simulation-tick target. Nearest-rank p95 is correct; the probe’s upper-middle median implementation is not used for any conventional-median claim here.

| Scene/phase | Automatic-start sample count | Automatic-start p95 / max | Focused-repeat sample count | Focused-repeat p95 / p99 / max |
|---|---:|---:|---:|---:|
| Central village, 1× | 1,701 | 20.722 / 33.471 ms | 1,483 | **21.194 / 25.974 / 32.546 ms** |
| Periodic all-nine group moves, 4× | 2,415 | 8.769 / 23.957 ms | 1,555 | **17.587 / 19.742 / 25.418 ms** |
| Wide forest, 1× | 1,367 | 23.248 / 35.107 ms | 1,864 | **11.618 / 12.130 / 12.607 ms** |

Group orders ran every two seconds to four goals; ten commands were accepted in each twenty-second group phase. Their focused-repeat call costs were **10.865, 18.550, 3.308, 6.177, 7.754, 18.256, 2.847, 6.762, 6.601 and 13.056 ms**. The independent fixed-start 24-command microbenchmark in F06 provides a different controlled command fixture; do not combine its samples with this moving-world sequence into a synthetic percentile.

The central-village p95 was above 16.67 ms in both samples. Other phases changed substantially between runs, so this session does not demonstrate robust margin or identify the dominant cost. It also does not certify failure or success on the target hardware floor, at 256 residents, in a long session or under every camera/weather condition. The next candidate needs a repeatable focus/scene/input script, qualification hardware, process/GPU traces and simulation-tick instrumentation. Preserve both successes and misses. The rendered probe exited 0. Both rendered logs, the visual-harness log and the modal-input log each contain three existing Control anchor/size warnings, zero `ERROR` and zero `SCRIPT ERROR`. The soak, UI-functionality, asset-system/support and group-order logs are clean. [Probe](/Users/brendan/Developer/redwall-review/.review-artifacts/render_perf_probe.gd), [focused repeat](/Users/brendan/Developer/redwall-review/.review-artifacts/render-perf.log), [automatic-start sample](/Users/brendan/Developer/redwall-review/.review-artifacts/render-perf-exploratory.log).

### The next candidate needs a task-based UAT gate

These are proposed acceptance cases, not claims of tests already passed. Run them on the exact next candidate. Use actual input/process order where the issue depends on it, while retaining model probes for deterministic conservation assertions. Compare equal simulation progress across 1× / 2× / 4×, rather than equal wall time.

| Player task | Observable acceptance | Recovery and edge cases |
|---|---|---|
| Select/inspect/command 1 or 9 residents | Identity, count, order and primary actions persist; world/roster agree | 720p/1080p, long names, large scale, keyboard only, notices, mixed capabilities. |
| Read Pantry and return | Clear lots/capacity/actions; no accidental world order; focus restored | Outside right-click/drag, world keys, Escape/Enter, resize while open. |
| Harvest into storage | Quantity conserved across crop, carrier and destination; capacity explained | Full before cutting, fills en route, cancel/transfer, failed route, partial acceptance. |
| Plant and interrupt | Input charged once; progress/ownership explicit | Move after payment, assign another worker, no compost left, cancel/restart. |
| Manage concurrent jobs | Task, target, worker and dependency visible; saved job resumes once | Farm/fell/saw/bridge/rescue compete; full destination, no eligible hand, manual override. |
| Dig a useful multi-segment route | Helpers migrate; saved work resumes; no empty-path access | Both cast orders, multiple substeps, closure at entrance, queued pieces, full mouths but valid bore connection. |
| Clear spoil/build bridge | Actual arrival precedes work, credit or delivery | Exhaust retries, block source/site/drop, cancel carrying, missing material, invalid worker. |
| Cross changing water | Entry revalidates consent/fit/stamina; fallback understandable | Toggle before bank, load change, closure approaching/in water, mixed party. |
| Dive/rescue | Capable responder, one persistent incident, physical contact and safe resolution | Nearer nondiver, interrupted rescuer, second victim, no landing, threshold rearm. |
| Plan a season | Picker/expiry update; resolved conditions re-alert on recurrence | Date/season boundary with open picker, wet→good→wet, mixed storage rates, pause 60 real seconds. |
| Produce a meal, once P3 lands | Harvest→cook→carry→serve→consume produces real stock/need effects | Shortage, reserved-food spoilage, no cook, interrupted serving, no duplicate debit/credit. |
| Inspect world/action quality | Support and use points read correctly; selected worker remains findable | Weir low/east/west views, oak roots, canopy/roof occlusion, entrance/crouch/carry, weather. |
| Save and continue, before enabling it | State/next action match uninterrupted control | Carrying, segment boundary, occupied crossing/rescue, near spoilage; incompatible file preserves old world/save. |
| Qualify performance | Measured rendered p95 <16.67 ms and sim tick <2 ms in required scenarios | Group orders, closure replans, 4×, adopted cap 256, alert bursts, repeated forestry, minimum hardware. |

Fresh-player evaluation should ask for real outcomes without a narrated README: find a threatened bed, explain a waiting job, choose an affordable crossing, locate a resident, recover from a refusal and explain what the last successful action changed. Record completion, search time, wrong clicks, hesitation and explanations. Choose numerical usability targets after baseline sessions, not from invented success rates. Screen-reader/controller qualification, contrast ratios, full-cast animation, every rescue topology and a tuned seasonal difficulty curve remain outside the evidence obtained here.

### Sequence integration before multiplying content

Close F01/F18’s lifecycle/per-frame standards problems and the HIGH correctness failures, then make stocks, selection and task state truthful. Establish P1/P2’s minimum read/command surfaces before adding broad automation. Connect one P3 meal loop, P6’s minimal identity/contribution record and P7’s teaching while P8 accepts the exact assets they use. Prove one useful bridge/tunnel choice and one seasonal response through P5/P4. Qualify session continuity, focus, scaling and performance through P9 before large content batches.

The key review choice is an inhabited, manageable village versus an explicitly labeled systems laboratory. Either can be a useful development milestone, but the current interface mixes their promises. The next slice should let a player explain who did the work, what it cost, what changed and why it mattered. No new combat, diplomacy, livestock, hidden species production bonuses, broad factory automation or excluded phase-3 underground work is needed to prove that experience.

## Appendix A — Expanded probe recipes and results

These are review-only artifacts, not committed test additions. Source/log links expose fixture setup. Successful process exit alone does not mean a probe found correct behavior: compare its printed outcomes with the contract stated in the finding. The report gives the key setup/results so it can be reviewed without first reading the scripts.

Run commands below from `/Users/brendan/Developer/redwall-review`. The **headless** recipe applies to `ui_functionality_probes.gd`, `ui_modal_probe.gd`, `layout_probe.gd`, `assets_systems_probe.gd`, `assets_building_support_probe.gd`, `group_order_probe.gd` and `soak_probe.gd`. For example:

```sh
godot --headless --path godot --script /Users/brendan/Developer/redwall-review/.review-artifacts/ui_functionality_probes.gd
```

The **rendered performance** probe needs a native window. It waits for F9 before sampling, so do not launch it headlessly. Run:

```sh
godot --path godot --script /Users/brendan/Developer/redwall-review/.review-artifacts/render_perf_probe.gd
```

Click the opened game window to focus it, then press **F9**. After the single five-second warmup, it samples the three phases sequentially, inserts 60 settling frames after switching to the wide-forest camera, and exits on completion. Keep the native window focused and avoid interacting during sampling. Shared-host work remains an uncontrolled variable; use the same setup for a comparison run.

The **visual fixture** also needs a native window:

```sh
godot --path godot --script /Users/brendan/Developer/redwall-review/.review-artifacts/visual_probe.gd
```

It starts paused at the close weir view. Its **review-only controls**, added by the scratch harness and **not ordinary game controls**, are F1 close weir; F2 close NW oak; F3 wider weir context; F4 central building view; F5 inject the frost rendering fixture through the real weather/view methods; and F6 order/select mouse 0 at the root-test point and resume at 4×. F5 does not advance the calendar to winter or establish normal seasonal progression. Close the native window when inspection is finished.

| Probe | Production path and fixture | Observed result |
|---|---|---|
| [ui_functionality_probes.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/ui_functionality_probes.gd) | Real harvest orders/crew stepping; forest order → Move → reassign; pantry formatter/aging; Menu and scaling APIs | Store 399/400 U + crop 5.1 U → empty bed, 0 carried/stored carrot. Cancel 26.843 m from store → instant 5.1 U credit. One sapling costs 500 instead of 250 milli-U. Displayed 240 h expires after 160 summer hours. Sixteen × 900 milli-U shows a 0 U headline versus 14/400 U occupied. Menu page 103; shell scale 1.5 versus demo 1.0. |
| Same script, picker/condition cases | Open real bed-0 picker at Spring 1; advance calendar to day 5; refresh. Use actual moisture API for 9800 → 6000 → 9800 and collect alerts each time | Wheat remains enabled, pea disabled, title Spring 1 despite changed eligibility. First waterlogged warning appears; after recovery, recurrence emits none. |
| [ui_modal_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/ui_modal_probe.gd) | Loaded scene; Pantry frame (490,190,940,674); dispatch right-click (420,500) outside it through the real Viewport | Selected actor order 0 → MOVE 1; goal (0,0) → (−8.192686,−0.792207); Pantry remains visible. |
| [layout_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/layout_probe.gd) | Real staged Controls at 1920×1080 and 1280×720; select one/all; open Water, bed, picker, Pantry and Woods | Mouse inspector 631 visible characters → 45; nine-person party hidden at 720p. Water target height 29 px, font 13 px, roster 12 px. Picker Back only 76% exposed at 720p. [JSON](/Users/brendan/Developer/redwall-review/.review-artifacts/layout-results.json). |
| [assets_systems_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.gd) | Four staged-oak fell/haul/48-day-regrow cycles, with deferred frees allowed; valid DiveTask with 638 air; real dive SEARCH → cramp with nearer nondiver/farther diver; 216 actual root samples | Child counts 10, 12, 14, 16; original hidden lower part still parented. One dive posts 150 low-air notices; all 32 retained entries describe it. Victim air 1149 → 0; tow starts 40 s later. Root estimate gives 0.80 m at a sampled bare-ground point. |
| [assets_building_support_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_building_support_probe.gd) | Transform actual staged vertices and compare with terrain/rendered-grid triangles | Nine village instances contact all four quadrants; weir bottom-band gap 0.468706–0.834376 m, with no bank/bed contact. |
| [group_order_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/group_order_probe.gd) | After 12 startup frames, pause; call actual all-nine `cast.order_move` to eight goals, repeated three times with fixed starting positions | 24 accepted; minimum 4.792 ms; conventional median 17.3645 ms; nearest-rank p95 25.644 ms; maximum 26.079 ms; 12/24 >16.67 ms. The printed upper-middle p50 of 20.134 ms is not the conventional median. |
| [soak_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/soak_probe.gd) | Real staged scene, 30 startup frames, speed 4, max FPS 60; seven samples 30 real seconds apart; no automatic acknowledgment/unpausing | 210.095 s, Spring 1 → Summer 3; nodes 1914 → 1915 then flat; objects 7204 → 7214; static memory ~1.4735 GB largely flat; no ERROR/SCRIPT ERROR. |
| [render_perf_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/render_perf_probe.gd) | Native 1920×1080, VSync off, uncapped; one initial five-second warmup, then three sequential twenty-second phases in the same evolving world; 60 settling frames after the wide-forest camera change; focused repeat gated by click/F9 | Both runs and callback-interval p95/p99/max are in the rendered-sampling table above. No script error; shared-host variability and timing limitations retained. |
| [visual_probe.gd](/Users/brendan/Developer/redwall-review/.review-artifacts/visual_probe.gd) | Review-only camera/weather fixtures in the production scene, plus an actual move command for the mouse | Detached weir slab/water patch; supported oak view blocked by opaque canopy; flat frost treatment while the stream remains visibly watery. Injection/visibility limits are stated in F40–F42/F53. |

The group-routing destinations were `(-15,-15)`, `(15,-15)`, `(-15,15)`, `(15,15)`, `(0,14)`, `(-12,0)`, `(12,0)`, `(0,-12)`, repeated three times. These are command-latency samples, not a rendered frame stream. The near-full-store test and sapling-transfer test exercise ordinary production public orders and stepping. The original spoil probe deliberately calls `_abandon_trip()` after issuing its walk; it does not reproduce the physical obstruction that would lead to that state.

Raw logs: [farm/UI](/Users/brendan/Developer/redwall-review/.review-artifacts/ui_functionality_probes.log), [modal](/Users/brendan/Developer/redwall-review/.review-artifacts/ui_modal_probe.log), [layout](/Users/brendan/Developer/redwall-review/.review-artifacts/layout-probe.log), [asset/rescue](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_systems_probe.log), [support](/Users/brendan/Developer/redwall-review/.review-artifacts/assets_building_support.log), [routing](/Users/brendan/Developer/redwall-review/.review-artifacts/group-order.log), [soak](/Users/brendan/Developer/redwall-review/.review-artifacts/soak.log), [visual harness](/Users/brendan/Developer/redwall-review/.review-artifacts/visual-probe.log), [focused rendered sample](/Users/brendan/Developer/redwall-review/.review-artifacts/render-perf.log), [exploratory rendered sample](/Users/brendan/Developer/redwall-review/.review-artifacts/render-perf-exploratory.log).

## Appendix B — Limits that remain open

This is broad, evidence-based coverage, not a guarantee that every bug or weak feature was found. There are current rendered process-frame interval samples, including p95/p99, but no controlled frame/presentation qualification, direct simulation-tick profile, GPU-memory audit, maximum-population run or GTX1660-floor result. The separate order benchmark measures synchronous CPU time. The short idle soak does not cover repeated lifecycle replacement or multi-hour memory behavior. No sound quality claim comes from listening. Mesh contact does not accept every door, foot, hand, tail, tool or waterline. First-time player completion rates, assistive-technology behavior, all localized/large-text states and the proposed meal/save flows require future acceptance.

The excluded room/home/root-cellar rebuild and Windows export remain separate. New feature quantities, content IDs, care coefficients, art spending and rules changes need their owning approved specifications before implementation. The plans identify these decisions without silently making them. The suite’s zero-failure line is genuine evidence; its proper implication is that the existing assertions passed at this commit, not that the playable experience passed every scenario described here.

## Appendix C — Original six reproduction probes

These are narrowly scoped **probes**, not passing regression tests. They use existing test fixtures to construct real graph/brain/crew/water objects. The unreachable-route case is expected to log the script error described in F02. The spoil case deliberately injects `_abandon_trip()` rather than physically building an obstruction. The capacity case checks the model/tool gate predicates, not mouse input. No production-source patch was used.

To repeat, save the following as `.review-artifacts/review_probes.gd` under this worktree and run:

```sh
godot --headless --path godot --script ../.review-artifacts/review_probes.gd
```

```gdscript
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_probe_dig_resume()
	_probe_crossing_consent()
	_probe_spoil_arrival()
	_probe_crew_transition()
	_probe_network_capacity()
	_probe_unreachable_below()
	quit()

func _probe_dig_resume() -> void:
	var script: GDScript = load("res://test/test_demo_resume.gd")
	var fixture: RefCounted = script.new()
	var space: RefCounted = fixture._space()
	var brain: RefCounted = fixture._brain(space)
	var first_task: RefCounted = script.CountedTask.new("unfinished lanterns", 100000)
	brain.order_task(first_task)
	var ref: PackedInt32Array = PackedInt32Array([-1, 0, -1])
	var accepted: bool = space.tunnels.add_into(PackedInt32Array([4096, 2048, 16384, 2048]), 2, brain.index, ref)
	brain.order_dig(ref[0], ref[1])
	for f: int in 12000:
		brain.step(1.0 / 60.0)
	print("PROBE dig_resume ", {"accepted": accepted, "piece_done": space.tunnels.piece_done(ref[2]), "order": brain.order, "state": brain.state, "task_resumed": brain.task == first_task, "saved_jobs": brain.unfinished_labels(), "position": brain.position})
	brain.release()

func _probe_crossing_consent() -> void:
	var script: GDScript = load("res://test/test_demo_water_play.gd")
	var fixture: RefCounted = script.new()
	fixture.before_each()
	var rig: RefCounted = fixture._rig()
	fixture._swimmer(rig, 0, 1900)
	fixture._place(rig, 0, Vector2(18.5, 10.5))
	var brain: RefCounted = fixture._brain(rig, 0)
	brain.order_move(Vector2(30.5, 10.5))
	var route_codes: PackedInt32Array = brain.path_tunnel.duplicate()
	rig.play.toggle_consent(PackedInt32Array([0]))
	var entered: bool = false
	for f: int in 900:
		rig.cast.advance(0.1)
		rig.play.step(rig.cast.clock.frame_usec)
		if brain.in_water:
			entered = true
			break
	print("PROBE crossing_consent ", {"codes": route_codes, "consent": rig.play.state.consent[0], "swim_refusal": rig.play.state.swim_refusal(0, false), "entered_water": entered, "position": brain.position, "state": brain.state})
	fixture.after_each()

func _probe_spoil_arrival() -> void:
	var script: GDScript = load("res://test/test_demo_spoil.gd")
	var fixture: RefCounted = script.new()
	fixture.before_each()
	var tunnels: RefCounted = load("res://demo/farm/farm_tunnels.gd").new()
	var crew: RefCounted = fixture._crew(tunnels)
	var site: PackedInt32Array = fixture._open_tunnel(true)
	var brain: RefCounted = fixture._brain(1)
	var said: String = crew.order(site[0], PackedInt32Array([1]))
	crew.update(16667)
	var row: int = crew.row_of(1)
	var distance: float = brain.position.distance_to(crew.goal[row])
	# Exercise the production failure transition used after MAX_REPLANS; keep the failed walk's goal.
	brain._abandon_trip()
	for f: int in 500:
		brain.step(1.0 / 60.0)
		crew.update(16667)
		if crew.load_milli[row] > 0:
			break
	print("PROBE spoil_failed_arrival ", {"order_result": said, "distance_when_abandoned": distance, "row": row, "step": crew.step[row], "load_milli": crew.load_milli[row], "distance_from_heap": brain.position.distance_to(fixture._cast.space().tunnels.heap_at[site[0]])})
	fixture.after_each()

func _probe_crew_transition() -> void:
	var fixture: RefCounted = load("res://test/test_demo_tunnel_ext_world.gd").new()
	fixture.before_each()
	var obstacles: Array[Vector3] = []
	var space: RefCounted = fixture._space(obstacles)
	var spots: Array[Vector2] = [Vector2.ZERO, Vector2(-1.0, 0.0)]
	var species: PackedStringArray = PackedStringArray(["Mouse", "Mouse"])
	var brains: Array = fixture._cast_of(space, spots, species)
	var works: Node = fixture._works(space, brains, species)
	works.ground.cells.fill(0)
	var ref: PackedInt32Array = PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref)
	space.tunnels.start_dig(ref[0], ref[1], 0)
	brains[0].order_dig(ref[0], ref[1])
	works.crew.join(1, ref[0])
	var crew_task: RefCounted = load("res://demo/tunnel/tunnel_crew_task.gd").new(works.crew, space.tunnels, ref[0], true, spots[1], works.crew_active, works.crew_along)
	brains[1].order_task(crew_task)
	var initial: int = works.crew.member_site[1]
	for f: int in 12000:
		brains[0].step(1.0 / 60.0)
		brains[1].step(1.0 / 60.0)
		works.step(16667)
		if space.tunnels.is_open(ref[0]):
			break
	print("PROBE crew_transition ", {"initial_site": initial, "lead_digging": brains[0].dig_tunnel, "entry_open": space.tunnels.is_open(ref[0]), "helper_site": works.crew.member_site[1], "helper_task": brains[1].task_label(), "piece_done": space.tunnels.piece_done(ref[2])})
	fixture.after_each()

func _probe_network_capacity() -> void:
	var fixture: RefCounted = load("res://test/test_demo_tunnel_ext_world.gd").new()
	fixture.before_each()
	var obstacles: Array[Vector3] = []
	var space: RefCounted = fixture._space(obstacles)
	for k: int in 8:
		var points: Array[Vector2i] = [Vector2i(0, k * 8192), Vector2i(16384, k * 8192)]
		fixture._open_tunnel(space, points)
	var spec: RefCounted = load("res://demo/tunnel/piece_spec.gd").new()
	spec.start_kind = 2
	spec.start_ref = 1
	spec.end_kind = 2
	spec.end_ref = 4
	spec.set_route(PackedInt32Array([8192, 0, 8192, 8192]), 2)
	print("PROBE network_capacity ", {"free_mouths": space.tunnels.mouth_node.count(-1), "tool_can_open": space.tunnels.has_room(), "room_for_connection": space.tunnels.room_for(spec), "free_segments": space.tunnels.phase.count(0)})
	fixture.after_each()

func _probe_unreachable_below() -> void:
	var fixture: RefCounted = load("res://test/test_demo_tunnel_ext_world.gd").new()
	fixture.before_each()
	var obstacles: Array[Vector3] = []
	var space: RefCounted = fixture._space(obstacles)
	var points: Array[Vector2i] = [Vector2i(0, 0), Vector2i(12288, 0)]
	var chain: PackedInt32Array = fixture._open_tunnel(space, points)
	var brain: RefCounted = fixture._brain(space, Vector2(-3, 0), true)
	brain.task_walk_to_node(space.tunnels.node_a[chain[1]])
	var original_size: int = brain.path.size()
	space.tunnels.close(chain[0], 1, 0, 4096)
	space.tunnels.close(chain[2], 1, 0, 4096)
	for f: int in 900:
		brain.step(1.0 / 60.0)
		if brain.path.is_empty():
			break
	print("PROBE unreachable_below ", {"original_path_size": original_size, "new_path_size": brain.path.size(), "state": brain.state})
	fixture.after_each()
```

---

## Phase 2 — Player Experience & Game Design Review

**Frozen review point: 30 September 2026, commit `157a3a461c8cca0070ef1fb666d3c4bce5923951`.** This append-only phase evaluates fun, strategic depth, expression, clarity and a coherent full-game direction. The original technical findings F01–F53 and prerequisite plans P1–P9 remain intact above. They are not recounted as new design findings. The proposals here are a prioritized design review, not authorization to implement an entire catalogue at once.

The intended game is a **large, persistent woodland colony with anonymous ordinary residents, a limited focus on named heroes and villains, deep plant/fish/forage production, and single-player squad tactics**. “Large” describes the ambition, not a qualified performance result. The current living/admission policy is 256 residents; 512 reserved storage rows are not an admission limit. [Population policy](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780). A larger army needs its own ownership decision. No hunting, livestock or dairy expansion is proposed. Underground rooms, homes and cellars are assessed only as an experience and design; the concurrent implementation is outside this review.

This phase adds no test execution or new native/audio observations. Earlier evidence remains as qualified in Phase 1, including its recorded `ok: 6161 tests, 546171 assertions, 0 failures.` Every persona journey below is a mental simulation. Proposed costs, timing bands, success rates and acceptance targets are hypotheses for future prototypes and player testing, not measured outcomes.

<a id="phase2-summary"></a>

### A. Executive summary: build a community worth tending and defending

**The frozen demo is appealing and can be absorbing as a short garden-and-infrastructure playground. It is not yet a complete colony game or a tactical game.** Its strongest pleasure is physical consequence: someone carries a harvest, a tree becomes usable material, a passage changes access, and a crossing lets different bodies share a place. Its local choices have substance, especially where excavation, moisture, materials and travel meet. The missing depth is sustained purpose: what the harvest allows people to do, why prosperity changes the next decision, what makes a season worth returning for, and how an army belongs to the community. Readability is strongest at an individual work site and weakest when the player tries to understand the village as a whole. These judgments follow the [inventory](/Users/brendan/Developer/redwall-review/REVIEW.md:1382), [persona journeys](/Users/brendan/Developer/redwall-review/REVIEW.md:1917) and [loop map](/Users/brendan/Developer/redwall-review/REVIEW.md:1975); they are design assessments, not measured enjoyment scores.

The game’s most distinctive opportunity is **hospitality made possible by a working landscape, then defended through collective courage**. A good eventual session could begin with choosing a seasonal menu, continue with solving a real labor or route problem, culminate in an ordinary supper or meaningful gathering, and leave a chosen project for tomorrow. A later expedition would take people and provisions from that same community; its return would change care, relationships and local opportunity. That is a coherent identity for the requested large colony and squad RTS. More commodities, more survival meters or more anonymous battles would not create it by themselves.

The following ranking concerns expected player value and design risk. It is deliberately much smaller than the catalogue. The first three rows form one connected community-day prototype; row four is a separate tactical proof. Neither requires implementing every related item in full.

| Rank | Change with the largest expected effect on fun | Minimum meaningful scope and dependency | What should persuade us to continue |
|---|---|---|---|
| **1** | **Let useful production become lived community life.** Keep the pleasure of visible work, and give it an ordinary human-scale payoff. | Build on Phase 1’s food/labor/identity prerequisites: one approved staple, actual delivery and consumption, a serving window, and a real ending to the workday. Add the smallest daily-rhythm/menu/presentation slices from [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965) and [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614). A representative sound pass belongs here once real actions drive it ([UX-029](/Users/brendan/Developer/redwall-review/REVIEW.md:5679), [UX-031](/Users/brendan/Developer/redwall-review/REVIEW.md:5727)). | A new player can explain what the community ate, why a chosen intervention helped, and what they want to improve next. A complete meal matters more than a larger recipe browser. |
| **2** | **Make growth increase the player’s reach rather than their chores.** | Establish one crew commitment, one fallback and one temporary override: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [UX-002](/Users/brendan/Developer/redwall-review/REVIEW.md:4930). This depends on Phase 1’s trustworthy jobs and delivery. Start with shared farm/haul work before a universal staffing optimizer. | In a later 48-resident test case, players manage ordinary labor by intent and exceptions, without inspecting most anonymous residents. A named specialist remains easy to intervene with and release. |
| **3** | **Make the consequences of a decision easy to find.** | Prototype only Stores, Work and the selected-object inspector from the [six-home map](/Users/brendan/Developer/redwall-review/REVIEW.md:2122), preserving Back and context ([UX-005](/Users/brendan/Developer/redwall-review/REVIEW.md:5013)). Add a useful comparison of existing beds and one relevant map lens ([UX-008](/Users/brendan/Developer/redwall-review/REVIEW.md:5085), [UX-009](/Users/brendan/Developer/redwall-review/REVIEW.md:5124)). Pause, saving and usable input remain Phase 1 prerequisites; [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457) and [UX-022](/Users/brendan/Developer/redwall-review/REVIEW.md:5481) extend continuity and attention. | A player answers “what is short, why, and what will help?” through one short journey. The interface returns them to their original place and intention. Do not build all six homes before this works. |
| **4** | **Prove the promised squad tactics in one small encounter.** | Test coherent mixed-squad roles, three formations, reserves and an orderly withdrawal ([SOC-036](/Users/brendan/Developer/redwall-review/REVIEW.md:4632), [SOC-037](/Users/brendan/Developer/redwall-review/REVIEW.md:4656), [SOC-038](/Users/brendan/Developer/redwall-review/REVIEW.md:4680)). Use a crossing or escape objective ([SOC-040](/Users/brendan/Developer/redwall-review/REVIEW.md:4728)). This is future combat work; none is playable in the frozen demo. It can be a bounded independent prototype while the community day develops. | Players win through at least two understandable plans, explain why a squad wavers, and save a losing force by withdrawing. If this is not enjoyable, a campaign or larger model count will not rescue it. |
| **5** | **Give the player ownership of useful places.** | Complete one general building lifecycle, then a small sketched place with access and phased funding ([UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233)). Offer a kitchen garden and a useful warren endpoint ([ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250), [ECO-043](/Users/brendan/Developer/redwall-review/REVIEW.md:3371)), with restrained architectural composition later ([UX-014](/Users/brendan/Developer/redwall-review/REVIEW.md:5257)). Rooms/homes/cellars stay design-only until their implementation owner is ready. | Two players create different functional places, and ordinary activity uses them. Beauty should have viable choices, not one mandatory optimal grid or decoration score. |
| **6** | **Make a season ask for a different plan, then reward preparation with calm.** | After a full food loop, contrast a few crop roles, fresh versus preserved food, and two fishery rhythms; give reserves explicit purposes ([ECO-001](/Users/brendan/Developer/redwall-review/REVIEW.md:2180), [ECO-023](/Users/brendan/Developer/redwall-review/REVIEW.md:2806), [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080)). Test one pressure and a visible quieter interval ([ECO-036](/Users/brendan/Developer/redwall-review/REVIEW.md:3167)), rather than adding more disasters. | Several source mixes remain useful; labor, transport or processing becomes the next bottleneck for an understandable reason. Prepared players gain time for building and community life. |
| **7** | **Let competence unlock expression, with scale as a choice and accomplishment.** | Rework access timing in a scenario prototype ([SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497)); resolve the delayed orchard payoff ([ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380)); compare alternative Charter proofs only after a season is playable ([SOC-033](/Users/brendan/Developer/redwall-review/REVIEW.md:4543)). The current M3 gate plus 96/144-day fruit maturation deserves explicit reconsideration. | The next interesting choice arrives before the player has exhausted the current one. A small settled community can enjoy core expressive systems, while a large town gains real capacity and administrative challenges. |
| **8** | **Give prosperity memory and an occasion.** | First deliver one modest feast with an occasion and aftermath ([SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [SOC-024](/Users/brendan/Developer/redwall-review/REVIEW.md:4305)); connect a genuine deed to optional notability ([SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664)). Visitors and richer traditions follow functioning hospitality, not a compulsory population increase ([SOC-021](/Users/brendan/Developer/redwall-review/REVIEW.md:4218), [SOC-025](/Users/brendan/Developer/redwall-review/REVIEW.md:4327)). | Players remember a person, place and reason for the gathering. The occasion creates attachment without becoming a repeatable reputation exploit or a chore on every calendar. |
| **9** | **Join home and army through explicit costs and a meaningful return.** | Integrate only after both prototypes work: one muster, one mission and one reviewed homecoming. Decide population ownership and time first ([SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841)); then add a single legible adversary and a small persistent region ([SOC-043](/Users/brendan/Developer/redwall-review/REVIEW.md:4817), [SOC-045](/Users/brendan/Developer/redwall-review/REVIEW.md:4865)). | Every deployed person or allied company has a source; leaving changes real capacity; battle pause creates no hidden home punishment; returning creates care, relief, memory or changed access. The player wants another journey and still enjoys being home. |

**Recommended sequence and stopping gates.** First agree the governing contracts: civilian crew intent, the first edible production chain, information ownership, acceptable losses, and the eventual home/battle clock. Then finish one community day, including a safe saved return and understandable intervention. In a separate bounded tactical prototype, test group intent, terrain and withdrawal without building a campaign. Extend the community prototype through one complete season and a later larger-population scenario only when the daily loop is rewarding and manageable. Integrate one expedition and return only after both the settlement and battle have their own satisfying decisions. Wider content follows those gates. This sequence reuses [Phase 1 P2](/Users/brendan/Developer/redwall-review/REVIEW.md:865), [P3](/Users/brendan/Developer/redwall-review/REVIEW.md:886), [P5](/Users/brendan/Developer/redwall-review/REVIEW.md:925), [P7](/Users/brendan/Developer/redwall-review/REVIEW.md:966) and [P9](/Users/brendan/Developer/redwall-review/REVIEW.md:1011) as prerequisites; it does not count their basic integration or bug fixes as new proposals.

**The consequential choices still open are small in number.** For population, prefer a resident militia plus explicitly persistent allied companies when larger battles need more people; raising the civilian limit to match every army is a different scale commitment, and 512 allocated rows do not settle it. For time, prefer a chapter contract: stated preparation/travel costs, no hidden home simulation during tactical pause, then a reviewed return; fully parallel simulation remains a viable later alternative with stronger automation. For tone, prefer separate ecological pressure, consequence severity and conflict participation behind understandable presets ([SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567)); “cozy” must not conceal its loss rules. For progression, prefer access through demonstrated competence and growth through capacity, while retaining a demanding large-community scenario. For architecture, prefer authored cores with bounded additions before freeform construction. For story, an original local region is the most practical first test; canon-era content needs its own chronology and activation decisions.

**Defer scope that does not yet earn its place.** This includes a vast campaign map, unrestricted siege generation, fully simulated diplomacy, free sailing/ferries, full hydrology, unrestricted terrain deformation, broad canopy content, dozens of quality tiers, distinct numeric treatment for every named vegetable, and wholesale activation of the literary recipe library. Births, aging transitions, free flight and hunting are outside the retained direction. Do not make ordinary comfort depend on collecting every luxury, naming every citizen or attending every annual event. Preserve quiet stretches in which a successful village can simply be enjoyed.

**How to use the catalogue.** Item Impact is expected upside within its system after prerequisites; Effort is relative scope, not a delivery estimate. “Now” and “Next” are readiness-dependent local priorities. The ranked sequence above takes precedence over those labels: it does not schedule 73 large proposals or 74 “Next” items for immediate implementation. Select the smallest relevant slices, test their player outcomes, and leave the remaining catalogue as reviewed options.

<a id="phase2-navigation"></a>

#### Navigation and family index

Use [inventory](/Users/brendan/Developer/redwall-review/REVIEW.md:1382) for exact availability; [journeys](/Users/brendan/Developer/redwall-review/REVIEW.md:1917) for the three player motivations; [loops and gaps](/Users/brendan/Developer/redwall-review/REVIEW.md:1975) for missing connections; [information ownership](/Users/brendan/Developer/redwall-review/REVIEW.md:2122) for screen responsibilities; [individual feedback](/Users/brendan/Developer/redwall-review/REVIEW.md:2151) for reviewable proposals; and [research sources](/Users/brendan/Developer/redwall-review/REVIEW.md:5773) for comparison provenance. The family table provides direct access to every assessment and item range.

| Family | Design assessment | Stable proposal range |
|---|---|---|
| ECO-F01 | [Field crops and cultivation](/Users/brendan/Developer/redwall-review/REVIEW.md:2161) | [ECO-001](/Users/brendan/Developer/redwall-review/REVIEW.md:2180)–[ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250) (4) |
| ECO-F02 | [Soil improvement, irrigation and drainage](/Users/brendan/Developer/redwall-review/REVIEW.md:2274) | [ECO-005](/Users/brendan/Developer/redwall-review/REVIEW.md:2293)–[ECO-007](/Users/brendan/Developer/redwall-review/REVIEW.md:2339) (3) |
| ECO-F03 | [Orchards, nurseries and beekeeping](/Users/brendan/Developer/redwall-review/REVIEW.md:2361) | [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380)–[ECO-012](/Users/brendan/Developer/redwall-review/REVIEW.md:2474) (5) |
| ECO-F04 | [Foraging and habitat stewardship](/Users/brendan/Developer/redwall-review/REVIEW.md:2496) | [ECO-013](/Users/brendan/Developer/redwall-review/REVIEW.md:2515)–[ECO-015](/Users/brendan/Developer/redwall-review/REVIEW.md:2561) (3) |
| ECO-F05 | [Forestry and woodland stewardship](/Users/brendan/Developer/redwall-review/REVIEW.md:2585) | [ECO-016](/Users/brendan/Developer/redwall-review/REVIEW.md:2604)–[ECO-018](/Users/brendan/Developer/redwall-review/REVIEW.md:2652) (3) |
| ECO-F06 | [Raw materials, workshops and equipment](/Users/brendan/Developer/redwall-review/REVIEW.md:2674) | [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693)–[ECO-022](/Users/brendan/Developer/redwall-review/REVIEW.md:2765) (4) |
| ECO-F07 | [Fishing and aquatic food production](/Users/brendan/Developer/redwall-review/REVIEW.md:2787) | [ECO-023](/Users/brendan/Developer/redwall-review/REVIEW.md:2806)–[ECO-026](/Users/brendan/Developer/redwall-review/REVIEW.md:2876) (4) |
| ECO-F08 | [Cooking, milling, preservation and drinks](/Users/brendan/Developer/redwall-review/REVIEW.md:2898) | [ECO-027](/Users/brendan/Developer/redwall-review/REVIEW.md:2917)–[ECO-031](/Users/brendan/Developer/redwall-review/REVIEW.md:3013) (5) |
| ECO-F09 | [Storage, hauling and reserves](/Users/brendan/Developer/redwall-review/REVIEW.md:3037) | [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056)–[ECO-035](/Users/brendan/Developer/redwall-review/REVIEW.md:3126) (4) |
| ECO-F10 | [Seasons, weather, ecology and water landscape](/Users/brendan/Developer/redwall-review/REVIEW.md:3148) | [ECO-036](/Users/brendan/Developer/redwall-review/REVIEW.md:3167)–[ECO-038](/Users/brendan/Developer/redwall-review/REVIEW.md:3213) (3) |
| ECO-F11 | [Water travel, diving, bridges and canopy access](/Users/brendan/Developer/redwall-review/REVIEW.md:3237) | [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256)–[ECO-042](/Users/brendan/Developer/redwall-review/REVIEW.md:3328) (4) |
| ECO-F12 | [Excavation, tunnel network and discoveries](/Users/brendan/Developer/redwall-review/REVIEW.md:3352) | [ECO-043](/Users/brendan/Developer/redwall-review/REVIEW.md:3371)–[ECO-046](/Users/brendan/Developer/redwall-review/REVIEW.md:3443) (4) |
| ECO-F13 | [Excavated earth and material reuse](/Users/brendan/Developer/redwall-review/REVIEW.md:3465) | [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484)–[ECO-049](/Users/brendan/Developer/redwall-review/REVIEW.md:3532) (3) |
| ECO-F14 | [Underground homes, rooms and root cellars — design only](/Users/brendan/Developer/redwall-review/REVIEW.md:3556) | [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575)–[ECO-052](/Users/brendan/Developer/redwall-review/REVIEW.md:3623) (3) |
| SOC-F01 | [People, identity and species](/Users/brendan/Developer/redwall-review/REVIEW.md:3647) | [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664)–[SOC-003](/Users/brendan/Developer/redwall-review/REVIEW.md:3708) (3) |
| SOC-F02 | [Labor, autonomy and learning](/Users/brendan/Developer/redwall-review/REVIEW.md:3732) | [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749)–[SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795) (3) |
| SOC-F03 | [Needs, mood and ordinary life](/Users/brendan/Developer/redwall-review/REVIEW.md:3817) | [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834)–[SOC-009](/Users/brendan/Developer/redwall-review/REVIEW.md:3878) (3) |
| SOC-F04 | [Households, dependents and care](/Users/brendan/Developer/redwall-review/REVIEW.md:3900) | [SOC-010](/Users/brendan/Developer/redwall-review/REVIEW.md:3917)–[SOC-012](/Users/brendan/Developer/redwall-review/REVIEW.md:3963) (3) |
| SOC-F05 | [Relationships and leadership](/Users/brendan/Developer/redwall-review/REVIEW.md:3985) | [SOC-013](/Users/brendan/Developer/redwall-review/REVIEW.md:4002)–[SOC-015](/Users/brendan/Developer/redwall-review/REVIEW.md:4048) (3) |
| SOC-F06 | [Health, rescue and remembrance](/Users/brendan/Developer/redwall-review/REVIEW.md:4070) | [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087)–[SOC-019](/Users/brendan/Developer/redwall-review/REVIEW.md:4155) (4) |
| SOC-F07 | [Immigration and hospitality](/Users/brendan/Developer/redwall-review/REVIEW.md:4179) | [SOC-020](/Users/brendan/Developer/redwall-review/REVIEW.md:4196)–[SOC-022](/Users/brendan/Developer/redwall-review/REVIEW.md:4242) (3) |
| SOC-F08 | [Feasts, culture and music](/Users/brendan/Developer/redwall-review/REVIEW.md:4264) | [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281)–[SOC-026](/Users/brendan/Developer/redwall-review/REVIEW.md:4349) (4) |
| SOC-F09 | [Narrative, lore and wonder](/Users/brendan/Developer/redwall-review/REVIEW.md:4371) | [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388)–[SOC-030](/Users/brendan/Developer/redwall-review/REVIEW.md:4458) (4) |
| SOC-F10 | [Progression, scenarios and endings](/Users/brendan/Developer/redwall-review/REVIEW.md:4480) | [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497)–[SOC-035](/Users/brendan/Developer/redwall-review/REVIEW.md:4591) (5) |
| SOC-F11 | [Squads, defense and military lives](/Users/brendan/Developer/redwall-review/REVIEW.md:4615) | [SOC-036](/Users/brendan/Developer/redwall-review/REVIEW.md:4632)–[SOC-041](/Users/brendan/Developer/redwall-review/REVIEW.md:4752) (6) |
| SOC-F12 | [Campaign, trade and outside communities](/Users/brendan/Developer/redwall-review/REVIEW.md:4776) | [SOC-042](/Users/brendan/Developer/redwall-review/REVIEW.md:4793)–[SOC-045](/Users/brendan/Developer/redwall-review/REVIEW.md:4865) (4) |
| UX-F01 | [Controls, camera and selection](/Users/brendan/Developer/redwall-review/REVIEW.md:4889) | [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906)–[UX-004](/Users/brendan/Developer/redwall-review/REVIEW.md:4974) (4) |
| UX-F02 | [Information architecture and management screens](/Users/brendan/Developer/redwall-review/REVIEW.md:4996) | [UX-005](/Users/brendan/Developer/redwall-review/REVIEW.md:5013)–[UX-008](/Users/brendan/Developer/redwall-review/REVIEW.md:5085) (4) |
| UX-F03 | [World reading, overlays and explanations](/Users/brendan/Developer/redwall-review/REVIEW.md:5107) | [UX-009](/Users/brendan/Developer/redwall-review/REVIEW.md:5124)–[UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192) (4) |
| UX-F04 | [Construction, layout and architectural expression](/Users/brendan/Developer/redwall-review/REVIEW.md:5216) | [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233)–[UX-016](/Users/brendan/Developer/redwall-review/REVIEW.md:5305) (4) |
| UX-F05 | [Learning, discovery and objectives](/Users/brendan/Developer/redwall-review/REVIEW.md:5329) | [UX-017](/Users/brendan/Developer/redwall-review/REVIEW.md:5346)–[UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418) (4) |
| UX-F06 | [Session, time, settings and accessibility](/Users/brendan/Developer/redwall-review/REVIEW.md:5440) | [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457)–[UX-024](/Users/brendan/Developer/redwall-review/REVIEW.md:5525) (4) |
| UX-F07 | [Visual world, assets and action presentation](/Users/brendan/Developer/redwall-review/REVIEW.md:5549) | [UX-025](/Users/brendan/Developer/redwall-review/REVIEW.md:5566)–[UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638) (4) |
| UX-F08 | [Audio and multisensory identity](/Users/brendan/Developer/redwall-review/REVIEW.md:5662) | [UX-029](/Users/brendan/Developer/redwall-review/REVIEW.md:5679)–[UX-032](/Users/brendan/Developer/redwall-review/REVIEW.md:5749) (4) |

<a id="phase2-inventory"></a>

### B. System inventory: what the player can actually use

A local demo action, a callable rule kernel, an adopted specification and a staged model are different evidence. The village can be charming and locally functional while its promised community or military loop remains absent. **No whole family is rated polished.** “Functional” applies only to the identified local action or API; “basic” means a narrow connected purpose; “stub/specification only” means a declared or partial surface without its promised complete loop, not necessarily a dummy executable function. “Legacy” means retired code, and “dressing” means appearance without the corresponding production behavior.

The family IDs in the design section use `ECO-F01…ECO-F14`, `SOC-F01…SOC-F12` and `UX-F01…UX-F08` to avoid confusing families with numbered recommendations such as `ECO-001`. Inventory source labels ECO-01, SOC01 and UX1 map to those same families. The exact catalogues follow their owning families.

<a id="phase2-economy-inventory"></a>

#### B1. Production, landscape and underground inventory

##### Availability and completeness conventions

- **Demo / functional**: the frozen village exposes a real playable action and consequent state change, within its explicitly separate economy.
- **Kernel / functional**: calculations, stores and/or orchestration exist, but this does not imply a reachable live-demo interface or a complete physical production loop.
- **Basic**: some player-facing purpose exists, with important loop or expression limitations.
- **Stub / absent, design-only**: an adopted catalog or design exists but the player cannot currently use its intended feature. This phrase does not assert a dummy runtime function exists.
- The scene boots the settlement simulation alongside a presentation cast/economy; these are separate. The demo explicitly documents its own stores and calls its cast presentation-only. The production settlement dispatches needs, stock age, ecology, crops/weather, planning, job selection/work and presentation, while movement, batch completion, logistics completion, connected heat and other stages remain incomplete. Some source header gap comments are historical; this inventory favors actual exposed composition and task boundaries over assuming every old “no store exists” sentence is current. [Demo scope](/Users/brendan/Developer/redwall-review/godot/demo/README.md:1), [production stage inventory](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:19), [planned food work](/Users/brendan/Developer/redwall-review/docs/tasks/07_food_production_survival.md:18).

##### System families and every component within this domain

| Family | Components, interactions and player agency | Connections and completeness | Source references |
|---|---|---|---|
| **ECO-01 Field crops and cultivation** | Six fixed demo beds; choose one of 16 named ingredients; soil/window filtering; sow, water/tend, harvest, clear, rest fallow, cancel bed jobs; right-click chooses pressing work. Stages empty, sown, sprouting, growing, ripe, withered and blighted. Per-bed growth, moisture, fertility, health, crop-family history and expected yield. Automatic crew harvests ripe crops and clears withered crops; player queues other work or selects hands. Production crop catalog is five families including flax; field designations, three-entry rotation, seed reserve, seed separation and relief seed assistance are specified/partially modeled. | **Demo functional**, with four numerical crop rows for 16 identities, unlimited demo seed, fixed beds. **Kernel functional rules/basic integration**: retained soil history, crop arithmetic and FieldPolicy cycle ledger; no complete playable seed→field→recipe loop. Connects soil/water, weather, labor, storage, food, cloth/rope and pollination. | [16 items and mapping](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_catalog.gd:17); [seed boundary](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:39); [crew](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:6); [FieldPolicy](/Users/brendan/Developer/redwall-review/godot/scripts/core/field_policy.gd:1); [crop contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:457) |
| **ECO-02 Soil improvement, irrigation and drainage** | Loam/clay/sand compatibility; fertility depletion and legume/fallow restoration; compost once per season; moisture bands affect growth. Demo Cover protects frost; Raise uses spoil, sheds moisture and warms nights; Bank retains moisture; Drain cuts a permanent ditch; dry underground bores drain beds; bores connected to water-edge mouths irrigate beds. Blight may be cleared; covered/raised beds modify local temperature. Moisture/ripeness map overlays and bed panel explain state. | **Demo functional**, meaningful cross-system contact between farm and tunnels. **Kernel functional arithmetic**, some local demo measures depart from adopted production scope. No full terrain hydrology simulation; the network connection is a water service adapter. Connects excavation/spoil, labor, yield, forecast, frost/blight and seed investment. | [farm/tunnel water join](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_tunnels.gd:1); [local soil operations](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:501); [bed verbs](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:40); [soil formulas](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:469) |
| **ECO-03 Orchards, nurseries and beekeeping** | Apple/pear blocks, maturity age, health, seasonal care, drought water, winter chill, annual harvest flag, removal wood, sapling propagation; first saplings at M3. Hive strength, seasonal tending, honey/wax output, winter honey feed, abandonment/recolonization, one/two-hive bounded pollination for beans/fruit. Apiary and nursery specialist buildings and work slots. | **Kernel functional rules, absent as complete playable demo systems**. OrchardPlot/Hive and pollination links exist; the stores expose work/cost/output, and ecology/crop-weather orchestration updates them. Physical nursery production, hive feed delivery, orchard labor and full inventory closure remain part of planned food integration. Connects multiyear planning, food/culture, candles, drought, field siting and preservation. | [orchard/hive implementation scope](/Users/brendan/Developer/redwall-review/godot/scripts/core/orchard_hive.gd:1); [explicit no inventory/job completion boundary](/Users/brendan/Developer/redwall-review/godot/scripts/core/orchard_hive.gd:113); [design](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:477); [task integration](/Users/brendan/Developer/redwall-review/docs/tasks/07_food_production_survival.md:81) |
| **ECO-04 Foraging and habitat stewardship** | Berries, nuts, mushrooms, herbs and roots have distinct seasons, capacity, work and regrowth. Zones reference shared basins; daily aggregate quota, protection/enabled policies, sustainable/intensive floors, natural danger vs staffed-lookout risk, dangerous-work consent, exposure injury accounting. Repeated demand produces pending harvest jobs. No huntable mammal/bird stocks, hides, carcasses, hunting tools or hunter hut are active. | **Kernel functional stores/basic integration; no demonstrated complete live-demo forage production loop**. A “gatherer” actor helps the farm, which must not be mistaken for a functioning forage profession. Connects preserves, healing herbs, cooking, habitats, lookout staffing, winter fallback and wildlife fences. | [forage store and shared ownership](/Users/brendan/Developer/redwall-review/godot/scripts/core/forage.gd:1); [repeat demand and unresolved output/access](/Users/brendan/Developer/redwall-review/godot/scripts/core/job_planner.gd:23); [forage catalog](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:427); [hunting exclusion](/Users/brendan/Developer/redwall-review/docs/setting_rules_amendment.md:20) |
| **ECO-05 Forestry and woodland stewardship** | 173 demo oaks/beeches/saplings tied to ResourceNode rows. Fell; beaver gnaw presentation; wait/haul helpers; transport wood; gather deadfall; grub stump; plant sapling; stump regrowth and cleared-site replant; forestry/conservation rectangle zones; normal/intensive retention floors; auto-fell toggle; winter/storm labor changes; storm blowdown; daily deadfall; visible felling/sawing XP. Log stack, sawhorse, plank stack, chopping block and sapling baskets. | **Demo functional**, with 12 U mature trees, 48-day regrowth, 20% mature retention (10% intensive), 6 U haul loads and demo reach/crew constraints. **Kernel functional resource nodes**, production forest service not fully closed. Connects supports, lanterns, bridges, planks, tools, heat and habitat identity. | [live woods](/Users/brendan/Developer/redwall-review/godot/demo/README.md:403); [jobs](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_jobs.gd:1); [zones](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_zones.gd:1); [resource store](/Users/brendan/Developer/redwall-review/godot/scripts/core/resource_nodes.gd:1) |
| **ECO-06 Raw materials, workshops and equipment** | Demo wood→planks at sawhorse, shared wood/stone/plank stocks, stone recovered from rock digging, tools and gear presentation. Adopted stone/iron extraction, finite deposits plus inexhaustible bedrock quarry; flax→rope/cloth→outfit; wood/stone or wood/iron→tools; wax/flax→candles; net/trap/ice-kit crafting, gear repair and boat assembly; tool wear and durability; workshop tiers and specialized stations. | **Basic demo craft** (sawing) plus **functional catalog/gear/resource kernels**; most production recipes are design-only until batch/order integration. 30 buildings and 9 furniture definitions are compiled. Connects nearly every production system and transport/safety. | [demo plank stocks](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:1); [main/ancillary recipes](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140); [extraction and wear](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:674); [building definitions](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:91) |
| **ECO-07 Fishing and aquatic food production** | River trout/dace/salmon, lake perch/carp/whitefish, coast herring/mackerel/mussel; seasonal availability, spawning closures, salmon run, mussel blight closure, stock recovery, 30/40% restocking latch, sustainable daily quota, conservation/intensive floor, gear effort slots. Net/trap/weir/boat/ice-kit methods with different work, wait, worker, wear, access and hazard contracts. Demo map exposes stream/pond fishery readouts and fishing-driver preview/begin/complete/cancel APIs. Fisher shelter, weir, boathouse, jetty, boats, nets/traps/smoking rack are visibly staged. | **Kernel functional ecology; basic demo fishery presentation**. Catch results are returned as species/quantity lots by the driver but explicitly not delivered into pantry; decorative fishers/equipment do not prove an end-to-end food loop. Coast remains in generated fishery model/catalog though live village focuses stream and pond. Connects preserves, meals, seasons, skill, gear, rescue, transport and habitat stewardship. | [fishery contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:376); [fishing-driver separation](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:1); [gear/expedition boundaries](/Users/brendan/Developer/redwall-review/godot/scripts/core/fishing.gd:74); [water-side presentation](/Users/brendan/Developer/redwall-review/godot/demo/water/water_dressing.gd:1) |
| **ECO-08 Cooking, milling, preservation and drinks** | Active numerical design: 10 prepared dishes plus ration, flour, dried fish/fruit, salted fish, mead, compost, salt; batch work/passive stages; quality from cook/input/station/age; bounded dominant-ingredient effect; variety history and freshness-first vs variety-first policy; recipe mastery; once/repeat/maintain-stock orders; coastal brine provenance; communal feast menus (SOC owns social ceremony). Library has 1,755 recipe/serving candidates, with explicit inferred ingredients and non-runtime status. Demo Pantry shows ingredient-linked candidate dishes, not executable recipes. | **Absent as a complete playable cooking/preservation subsystem; stub/design-only interfaces**, despite extensive adopted recipe graph and live aging. Distinguish active numerical catalog from offline library candidates. Connects every food producer to hunger, social life, winter, expeditions, fuel, storage and mastery. | [numerical recipes/quality/orders](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:509); [demo candidate boundary](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_recipes.gd:1); [library counts/status](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/README.md:31); [food milestone](/Users/brendan/Developer/redwall-review/docs/tasks/07_food_production_survival.md:18) |
| **ECO-09 Storage, hauling and reserves** | Demo ingredient lots with per-item identity/age/location, spoilage, covered storage and root-cellar providers, physically carried harvest models, shelves filling, spoil→compost button; materials shared separately. Production lots track quantity/quality/recipe/provenance/effective age; container mass, incoming capacity claims, FEFO selection, filters/minimum reserves, ready food-days vs potential food, fuel-days, winter forecast, species payloads, overflow ground piles, WIP/reservations and cargo transfer semantics. | **Demo functional basic stores/hauling**, but no consumption demand or general logistics economy. **Kernel functional inventory/reservation/aging**, full physical producer-to-consumer logistics remains incomplete. Underground-cellar design is reviewed only as storage experience. Connects all sources/sinks, distances, worker budgets, building layout, winter and trade/battle provisions (future hybrid scope). | [demo lots](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:1); [storage-provider shape](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_storage.gd:1); [full contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600); [food integration boundary](/Users/brendan/Developer/redwall-review/docs/tasks/07_food_production_survival.md:22) |
| **ECO-10 Seasons, weather, ecology and water landscape** | Four 12-day seasons; daylight/temperature/rain; 48-day year; first spring Ideal spell; forecast major events: Ideal, storm, drought, blight, early frost, hard freeze, calm. Weather affects crops, walking, outdoor productivity, fishing access, food age, hunger/heat and tree blowdown. Demo adds frost nights and contagious neighboring-bed blight, three-day rain spells, visible rain/snow/frost/light, and fire/flood demonstration threats. Stream/pond depth, current, banks, ford, landings, water-edge queries and flood increase. | **Demo functional weather/environment services** and **functional kernel seasonal/ecology rules**, with demo compression (day/minute) and deliberate threat divergences from production bounded-event contract. Not freeform fluid simulation, player dam engineering or pollution industry. SOC owns narrative emergency/evacuation experience. | [weather contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:732); [demo one-calendar/weather/water](/Users/brendan/Developer/redwall-review/godot/demo/README.md:73); [farm demo threats](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_weather.gd:1); [water map](/Users/brendan/Developer/redwall-review/godot/demo/water/water_map.gd:1) |
| **ECO-11 Water travel, diving and bridges** | Body-dependent wading, consent/eligibility for swimming, flow/current, stamina/cold drain, loaded-swim restrictions, turn-back reserve, otter dive air plan, underwater search finds, bank landing and route selection. Automatic tow/shore-line rescue and wash-ashore fallback (SOC owns consequence/care review). Three bridge candidates or custom two-bank span; plank vs log bridge; price/material fetch; piers/beams/deck work stages; bridgewright skill, everyone walks completed bridges including loads/badger. | **Demo functional**, production connected-movement scope adopted but gates remain open. Six-bridge demo cap; structures not currently removed. Boats/raft are presentation assets, not functioning cargo ferry network. **Connected canopy/climbing is adopted but not playable:** ladders/trunks/branches must support orchard work, observation and safe return; per-resident body/posture/grip/load and landing compatibility apply. Specific canopy catalog/timing remain unresolved; free flight and arbitrary branch-gap jumping are excluded from this adoption, so a bird identity grants no flying bypass. This extension is grouped with transport infrastructure rather than excavation. Connects access, labor travel, forest/craft, fishing, rescue, discovery and future tactical terrain. | [bridge state and options](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/bridges.gd:1); [dive phases](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/dive_task.gd:1); [water gameplay](/Users/brendan/Developer/redwall-review/godot/demo/README.md:471); [connected movement](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:30) |
| **ECO-12 Excavation, tunnel network and discoveries** | B/T Dig; drag/bend/click route; snap branches/junctions/crossings; underground U view; mouth/ramp fit; live preview length/work/spoil/soil; queue pieces; pause/resume digs; lead/helper crews and digging XP; standard/wide bore; brace/lantern upgrades; automatic route use by body/load; costs/queues; groundwater/weak-ground pressure, warnings, pump/clear repairs; relic/flint/clay/root-store finds. Adopted multi-level connected burrows/planned rooms/free excavation exceed frozen demo. Adopted canopy access is accounted for under ECO-11, separately from underground construction. | **Demo functional**, level 1 only at this commit, 96 segment/node/piece limits and 16 mouths; level 2 named but later phase. Production underground economic/movement bindings are incomplete. Current bracing/hazard model explicitly differs from adopted supported-dry-tunnel production contract. Connects travel savings, bad-weather resilience, farm water, materials, shelter, discoveries and spatial expression. | [graph decision and limits](/Users/brendan/Developer/redwall-review/docs/decisions/0208-the-tunnels-are-one-network-graph.md:14); [orders/upgrades](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_actions.gd:1); [hazard boundaries](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_hazards.gd:1); [finds](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_finds.gd:1) |
| **ECO-13 Excavated earth and material reuse** | Demo growing spoil heap at each mouth, obstacle/picking, selecting heap, Clear/C/right-click; up to four carriers, 2 U baskets; Raise/Bank/Compost consume heap material; clearing shrinks/removes obstruction. Adopted excavated_earth is a distinct nonfood nonfertilizer material: brace/cut/finish quanta, delivered haul, tip preparation/compaction/reclaim/closure, backfill and support salvage; no delete button or automatic sale/fertility value. | **Demo functional basic reuse**, production distinct earth lifecycle **design-only/partial catalog**. Demo compost conversion is an intentional adaptation, not adopted fertility semantics. Connects dig throughput, storage land use, path blockage, support materials, terrain reconfiguration, future landscaping proposals. | [spoil clearing](/Users/brendan/Developer/redwall-review/godot/demo/spoil/spoil_crew.gd:1); [farm heap ledger](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_tunnels.gd:128); [earth definition/operations](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:50); [tips/haul](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:160) |
| **ECO-14 Underground homes, rooms and root cellars — design only** | Adopted direction: round 4 m burrow home with three tunnel sockets and own front door; 3×4 m barrel-vault root cellar with two sockets and hatch; turfed mound is room geometry; warm hearth/rug/table/beds vs cool shelves/jars; furnishing prices separate; night home routine; second level; later larger homes/pantry/workshop. Frozen demo offers chamber creation and cellar provider/basic mole-bed count; phase 3 is actively being rebuilt elsewhere and implementation is excluded from critique. | **Basic frozen demo representation / adopted richer design**, explicitly not a phase-3 implementation assessment. Connects home identity, mixed-body access, food longevity, work districts, shelter, warmth, community night rhythm and multilevel navigation. General surface construction/furniture validity reviewed by UI/architecture and SOC. | [approved experience](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:57); [templates/access](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:121); [user rulings](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:502); [existing cellar bridge](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_cellars.gd:1) |

##### Wildlife and connected movement availability supplement

- **No harvestable fauna/herd roster exists.** FaunaStockReserved has only empty allocation, including zero species IDs/populations; retired hunting is not an unfinished game-animal feature. Edible fish are the nine item/species keys listed below. Pike is a nonharvestable wildlife hazard; territorial eel encounters are nonharvestable sapient encounters. Pollination belongs to the hive store, not a simulated bee-creature population. [GDD categories](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:421), [reserved fauna](/Users/brendan/Developer/redwall-review/godot/scripts/core/world_init.gd:509).
- **Wildlife pressure, fences and lookouts have different completeness.** The adopted summer/autumn midnight pressure event removes bounded honey or forage and is halved by a complete enclosing fence/wall; it does not injure residents. Staffed lookouts reduce forager hazard exposure, not the pressure roll. These are design contracts, **not currently executed ecology behavior**: ecology has no wildlife-pressure event, while forage lacks enclosure/staffed-lookout joins. Fence, wall, gate and lookout building definitions exist, but their definitions alone do not make this loop playable. [Adopted event](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:672), [ecology boundary](/Users/brendan/Developer/redwall-review/godot/scripts/core/ecology.gd:95), [forage boundaries](/Users/brendan/Developer/redwall-review/godot/scripts/core/forage.gd:158), [lookout join](/Users/brendan/Developer/redwall-review/godot/scripts/core/forage.gd:200).
- **Canopy/perching scope:** connected trunk/ladder/branch access for work and observation is adopted, including a supported return route. A perched observation contact is a possible application of that direction; no autonomous free-flight, arbitrary branch jumping or blanket species permission is adopted or playable. Canopy structure catalog/height/capacity remains unspecified. [Movement scope](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:16), [requirements](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:34).

##### Complete production resource catalog

These are **definitions**, not a claim all 61 resources can be produced in the demo. The current generated JSON is the source for exact keys. [Item catalog](/Users/brendan/Developer/redwall-review/godot/data/item_definitions.json:1).

| Category | Exact current item keys |
|---|---|
| Raw food / ingredients (11) | beans, berries, cabbage, flour, fruit, grain, herb, honey, mushrooms, nuts, roots |
| Liquid (2) | brine, water |
| Gear (6) | candle, ice_kit, net, outfit_tier2, tool, trap |
| Raw fish (9) | carp, dace, herring, mackerel, mussel, perch, salmon, trout, whitefish |
| Materials (10) | cloth, compost, excavated_earth, flax, iron, rope, salt, stone, wax, wood |
| Preserved (3) | dried_fish, dried_fruit, salted_fish |
| Feast (1) | mead |
| Prepared (11) | meal_bean_hotpot, meal_crumble, meal_feast_fish, meal_fish_stew, meal_nut_roast, meal_nut_loaf, meal_pie, meal_porridge, meal_root_stew, meal_tart, ration |
| Saplings (2) | sapling_apple, sapling_pear |
| Seeds (5) | seed_beans, seed_cabbage, seed_flax, seed_grain, seed_roots |
| Waste (1) | spoiled_food |

Demo-specific inventory identities additionally include planks, 16 named crop ingredients, flint/clay/root-store/relic find tallies, and dive finds. These must not be conflated with new compiled production items. [Shared demo stores](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:1), [demo crop identity](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_catalog.gd:17), [find tallies](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_finds.gd:25).

##### Per-resource player use and availability — all 61 compiled items

**Reading this table.** **K/basic** means a real compiled identity with functional catalog/inventory/rule support, but no complete player-operated production→consumption loop in the demo. It does not mean the resource is already available in every running store. **D/local** identifies a usable separate demo counterpart, never an automatic link to kernel stock. **F/API** means the demo fishery can describe/return catch results through its driver; catches are not landed into the playable Pantry. **A/dressing** is appearance only. Every source/use below is an adopted design or implemented rule relationship unless a D/local action is explicitly stated.

Shared source groups: **R** = [exact 61 definitions](/Users/brendan/Developer/redwall-review/godot/data/item_definitions.json:4); **C** = [24 recipe transformations](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140); **A** = [ancillary seeds/gear/saplings/extraction](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:169); **F** = [fish habitat/method rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:376) and [demo-driver boundary](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:2); **P** = [farm identities](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_catalog.gd:17) and [demo lots](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:2); **M** = [materials/forestry](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:674) and [separate demo stores](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:1); **H** = [orchards/hives](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:477); **E** = [excavated-earth lifecycle](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:50); **S** = [food/gear use and storage](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:509), [equipment repair](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:670), [feast beverages](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:588). These grouped references support every row, as marked in its final column.

| Item key | Producer/source the player would manage | Uses and connected loop | Frozen availability / completeness; sources |
|---|---|---|---|
| beans | Bean fields | Hotpot/nut roast; separate seed; rotation/pollination | K/basic; demo peas/broad beans are separate named ingredient lots, not this compiled stock. R,C,A,P |
| berries | Seasonal forage patches | Raw fallback food, berry tart; seasonal variety | K/basic; no live gather-to-pantry loop. R,C,S |
| cabbage | Leaf fields | Hotpot; separate seed; rotation | K/basic; D/local same-name demo cabbage can be grown/hauled/stored, no cooking. R,C,A,P |
| flour | Mill processes grain | Pies/tarts/crumble/loaf/rations | K/basic; mill dressing does not produce flour. R,C |
| fruit | Apple/pear orchard harvest | Crumble, drying, nursery propagation | K/basic orchard rules; no playable orchard intake. R,C,A,H |
| grain | Grain fields | Porridge, flour, seed separation | K/basic; demo wheat/barley/oats are separate ingredient identities. R,C,A,P |
| herb | Forage patches | Nut roast, feast fish, Hearth infusion; care context | K/basic; not a demo farm crop. R,C,S |
| honey | Serviced hives | Tart/crumble, mead; winter hive feed/recolonization | K/basic hive output rules; no playable apiary feed/food chain. R,C,H |
| mushrooms | Forage patches | Woodland pie and raw food eligibility per catalog | K/basic; world mushroom props are A/dressing. R,C,S |
| nuts | Forage patches | Roast, loaf, rations; raw food | K/basic; no live gather-to-kitchen chain. R,C,S |
| roots | Fields and forage | Stews/roast/pie/feast fish, compost alternative, seeds | K/basic; six demo root identities are separately farmable D/local ingredients. R,C,A,P |
| brine | Bound coastal saltpan draw | Salt; never substitutes for drinking/cooking water | K/basic; no live freshwater-demo saltpan production. R,C,A |
| water | Bound well extraction | Cooking, nursery, hive/feast preparation where specified, irrigation care | K/basic lots; D/local watering changes bed state without a complete water-haul stock loop. R,C,A,P,S |
| candle | Wax/flax crafting | Lighting/service uses; consumes hive/fiber output | K/basic; demo lamps do not establish candle-item production/use. R,C,S |
| ice_kit | Wood/iron craft | Frozen-lake fishing, gear wear/repair; needs clothing | K/basic gear rules; no complete live ice-fishing production. R,A,F |
| net | Wood/rope craft | Bank fishing, durability/repair | K/basic; F/API method exists, visible net is not a fulfilled gear-production chain. R,A,F |
| outfit_tier2 | Cloth workshop | Cold protection, required ice-fishing clothing | K/basic equipment definition; no playable dress/equip production chain. R,C,F,S |
| tool | Wood/stone or wood/iron recipe, different durability metadata | Build/craft/farm/keep work; repair | K/basic gear/work rules; cast-held tools are A/presentation, not demo crafted stock. R,C,A,S |
| trap | Wood/rope craft | Set/soak/collect bank fishing and gear repair | K/basic; F/API method, staged trap is not live pantry production. R,A,F |
| carp | Lake fish stock | Legal fish-selector recipes, drying/salting; spawning rules | K/basic ecology; F/API catch-result identity, not landed pantry food. R,C,F |
| dace | River fish stock | Fish recipes/preservation; bank methods | K/basic ecology; F/API catch-result identity. R,C,F |
| herring | Coast fish stock | Fish recipes/preservation | K/basic ecology; coast catalog/model retained but live village has no coast site. R,C,F |
| mackerel | Coast/offshore stock | Fish recipes/preservation; boat access | K/basic ecology; absent as a playable offshore expedition. R,C,F |
| mussel | Coast stock | Fish-selector recipes/preservation; blight closure | K/basic ecology; no live coast gathering loop. R,C,F |
| perch | Lake stock | Fish recipes/preservation; net/trap/ice access as legal | K/basic ecology; F/API catch-result identity. R,C,F |
| salmon | River stock/run | Fish recipes/preservation; seasonal recruitment | K/basic ecology; F/API catch-result identity. R,C,F |
| trout | River stock | Fish recipes/preservation; species closure rules | K/basic ecology; F/API catch-result identity. R,C,F |
| whitefish | Lake stock | Fish recipes/preservation; winter access | K/basic ecology; F/API catch-result identity. R,C,F |
| cloth | Flax workshop | Outfits, buildings/furniture, boats | K/basic; no live flax-to-cloth delivery. R,C,A |
| compost | Spoiled food or roots processing; cleared crop waste | Soil fertility, saplings, forestry planting | K/basic; D/local demo counter/treatments and spoil conversions, with separate demo semantics. R,C,H,P,M |
| excavated_earth | Excavation quanta | Haul, tip, compact/reclaim, backfill; never fertilizer/food | K/catalog and adopted lifecycle; D/local spoil heaps are a different simplified representation. R,E |
| flax | Fiber crop | Rope, cloth, candle wick, seed separation | K/basic crop/recipes; explicitly absent from demo farm picker. R,C,A,P |
| iron | Surface deposits | Improved tools, gear, structural/station costs, boats | K/basic resource rules; no live quarry-to-workshop chain. R,C,A,M |
| rope | Flax workbench | Fishing gear, boats, dryer/apiary/structures, gear repair | K/basic; staged ropes are A/dressing. R,C,A,F |
| salt | Coastal brine saltpan | Salted fish | K/basic recipe; no active coastal production in demo. R,C,A |
| stone | Surface deposits, renewable bedrock quarry | Tools/buildings, supports, repairs | K/basic; D/local initial shared stock and dig finds/payments. R,C,A,M |
| wax | Serviced hives | Candles, decorations | K/basic hive arithmetic; no live wax craft loop. R,C,H |
| wood | Trees/deadfall and orchard removal | Construction/supports, fuel, tools/gear/boats, repairs | K/basic; D/local fell/gather/haul/saw/bridge/support payments, with separate demo plank stock. R,C,A,M |
| dried_fish | Dryer fish batches | Direct preserved food, rations | K/basic recipe; no playable preservation/consumption. R,C,S |
| dried_fruit | Dryer fruit batches | Direct preserved food, winter variety | K/basic recipe; no orchard-to-dryer chain. R,C,S |
| salted_fish | Fish plus salt | Direct preserved food, winter reserves | K/basic recipe; no live salt/preserver chain. R,C,S |
| mead | Honey/water fermentation | Harvest/Orchard feast beverage | K/basic recipe; no live brewing/service. R,C,S |
| meal_bean_hotpot | Beans/cabbage/water cooking | Ordinary meals and Hearth main course | K/basic approved recipe; absent live kitchen service. R,C,S |
| meal_crumble | Fruit/flour/honey cooking | Ordinary meals and Orchard second course | K/basic approved recipe; absent live service. R,C,S |
| meal_feast_fish | Legal fish/roots/herb/water cooking | Meals and Harvest main course | K/basic approved recipe; absent live service. R,C,S |
| meal_fish_stew | Legal fish/roots/water cooking | Everyday prepared nutrition/variety | K/basic approved recipe; absent live service. R,C,S |
| meal_nut_roast | Beans/roots/nuts/herb cooking | Meals and Orchard main course | K/basic approved plant-based recipe; absent live service. R,C,S |
| meal_nut_loaf | Flour/nuts/water cooking | Meals and Hearth second course | K/basic approved recipe; absent live service. R,C,S |
| meal_pie | Flour/mushrooms/roots/water cooking | Woodland dish, prepared variety | K/basic approved recipe; absent live service. R,C,S |
| meal_porridge | Grain/water cooking | Starter everyday meal | K/basic approved recipe; absent live crop-to-meal loop. R,C,S |
| meal_root_stew | Roots/water cooking | Starter everyday meal | K/basic approved recipe; absent live crop-to-meal loop. R,C,S |
| meal_tart | Flour/berries/honey/water cooking | Meals and Harvest second course | K/basic approved recipe; absent live service. R,C,S |
| ration | Flour/dried fish/nuts/water preparation | Long-lived prepared food; future journey supply | K/basic approved recipe; no departing-force consumer. R,C,S |
| sapling_apple | M3 grant; fruit/compost/water nursery propagation | Apple orchard establishment | K/basic rules; absent playable nursery/planting chain. R,A,H |
| sapling_pear | M3 grant; fruit/compost/water nursery propagation | Pear orchard establishment | K/basic rules; absent playable nursery/planting chain. R,A,H |
| seed_beans | Separate beans at workbench | Next bean sowing; reserve/expansion | K/basic definitions/policy; demo seeds unlimited. R,A,P |
| seed_cabbage | Separate cabbage | Next leaf crop sowing | K/basic definitions/policy; demo seeds unlimited. R,A,P |
| seed_flax | Separate flax | Next fiber crop sowing | K/basic definitions/policy; no demo flax. R,A,P |
| seed_grain | Separate grain | Next cereal sowing | K/basic definitions/policy; demo seeds unlimited. R,A,P |
| seed_roots | Separate roots | Next root crop sowing | K/basic definitions/policy; demo seeds unlimited. R,A,P |
| spoiled_food | Food aging and specified canceled food WIP | Compost input; inedible waste | K/basic aging/definition; D/local aged pantry waste and compost button. R,C,P,S |

Demo-only stock concepts remain outside these 61 rows: planks; named fine-grained vegetables/cereals; flint/clay/root-store/relic tallies; dive finds; and simplified heap/spoil material. A visible commodity model does not add a compiled item.

##### Per-building function and availability — all 30 definitions

All 30 have defined footprints/materials/slots/unlocks and kernel building/construction support; no general live surface construction palette is enabled. **K/basic** below describes those real definitions/stores with incomplete everyday service integration. **D/local** indicates a separate demo use; **A/dressing** marks a placed appearance, not a working industry. Source groups: **B** [building purpose table](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:633) and [exact definition keys](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:100); **L** [fixed village layout](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:48); **W** [water dressing](/Users/brendan/Developer/redwall-review/godot/demo/water/water_dressing.gd:1); **I** [incomplete general building/room/logistics integration](/Users/brendan/Developer/redwall-review/docs/tasks/06_buildings_rooms_logistics.md:21). Production rules use recipe groups C/A above; community service details belong to SOC.

| Building key | Player purpose/action and connections | Frozen availability / completeness; sources |
|---|---|---|
| hall | Create shared living/dining/common rooms; heat, seating, governance/community anchor; upgrade | K/basic starter/service rules; A/dressing central hall; no demo managed-hall service loop. B,L,I |
| residence | Provide furnished home/bed capacity; upgrade; connect paths/services | K/basic rooms/definition; three A/dressing houses, not three working household interiors. B,L,I |
| infirmary | Furnish patient beds/shelves; staff healers; connect care and warmth | K/basic definition/services incomplete; absent live building operation. B,I |
| kitchen | Staff two cooks; produce meals; receive ingredients/fuel, serve community | K/basic station definition; A/dressing kitchen/cauldron; no live meal production. B,L,C,I |
| open_stockpile | Place/filter open material storage; connect extraction/construction | K/basic container/building rules; A/dressing fixed pile, with separate demo material yard logic. B,L,I,M |
| covered_store | Store food/materials with better protection; staff hauling; tier-two expansion | K/basic; D/local farm storage destination plus visible shelves, not complete general logistics. B,L,P,I |
| cellar | Preserve food in cold storage; connect route and shelves | K/basic definition; D/local dug-root-cellar provider through farm adapter; richer rooms design-only review. B,I; [cellar adapter](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_cellars.gd:2) |
| well | Draw actual water lots for food/care/propagation | K/basic extraction definition; A/dressing central well with routines, no complete hauling producer. B,L,A,I |
| workbench | Basic rope/tools/gear/seed/candle crafts | K/basic station; A/dressing shelter; nearby D/local sawing yard is separate forestry behavior. B,L,C,A,I |
| workshop | Cloth/outfits/improved tools and general crafts; upgrade | K/basic definition; no live general workshop chain. B,C,I |
| mill | Turn grain into flour; connect fields to kitchen | K/basic recipe/station; A/dressing waterside mill. B,W,C,I |
| dryer | Four passive fish/fruit batches; manage preservation space | K/basic recipe/station; drying/smoking equipment is A/dressing, not actual completed batches. B,W,C,I |
| preserver | Salt fish/preservation station, four passive slots/two workers | K/basic recipe/station; no live preserver work loop. B,C,I |
| fisher_shelter | Store gear and staff bank fishing access | K/basic locker/access design; A/dressing shelter and F/API nearby fishing model. B,W,F,I |
| weir | Commit river structure/two effort slots; inspect/collect accumulated catch | K/basic fishing method; A/dressing weir; not a player-built landed-catch industry. B,W,F,I |
| boathouse | Store two boats; assemble/equip and staff expeditions | K/basic definition/assembly recipe; A/dressing shore building/boats; no live cargo ferry. B,W,F,A,I |
| composter | Convert spoiled food or roots with four passive batches | K/basic recipe/station; D/local pantry compost conversion is a simplified action, not this building chain. B,C,P,I |
| apiary | Tend hive; honey/wax and bounded nearby pollination | K/functional hive arithmetic but incomplete labor/inventory; absent live player-managed apiary. B,H,I |
| nursery | Four propagation slots, saplings from fruit/compost/water | K/basic propagation rules; absent live nursery production. B,A,H,I |
| brewery | Ferment honey/water to mead in four passive slots | K/basic recipe/station; absent live brewing/service. B,C,I |
| saltpan | Coastal brine extraction and salt evaporation | K/basic definition; deliberately not placed in freshwater demo. B,W,A,C,I |
| forester_lodge | Staff managed tree-zone work | K/basic definition; D/local forestry works through demo zones/yard, no operational lodge building. B,M,I |
| quarry_shed | Access stone/iron deposits and guaranteed renewable bedrock | K/basic extraction/definition; absent player-operated quarry building. B,M,I |
| lookout | Staff a 32 m low-danger service for trips | K/basic building definition; staffing/risk join absent, no live useful lookout. B,I; [join boundary](/Users/brendan/Developer/redwall-review/godot/scripts/core/forage.gd:200) |
| fence | Enclose forage/apiary to reduce adopted wildlife pressure | K/basic definition; A/dressing farm fences; loss event/enclosure effect not executed. B,L,I; [ecology boundary](/Users/brendan/Developer/redwall-review/godot/scripts/core/ecology.gd:95) |
| stone_wall | Enclosure/access/weather boundary; no adopted settlement attack command | K/basic definition; absent live player-built wall effect. B,I |
| gate | Passable enclosure access toggle | K/basic definition; no live placement/toggle loop found. B,I |
| dirt_path | Create +10% ground-speed route | K/basic definition; A/dressing authored paths, no live road-building tool. B,L,I |
| paved_path | Spend stone for +20% route replacing dirt | K/basic definition; absent live path upgrade tool. B,I |
| memorial_garden | Keep grave entries and remembrance place; connect grief/care | K/basic definition; absent live managed memorial place. B,I; SOC owns lifecycle meaning |

##### Per-furniture function and availability — all nine definitions

Shared evidence: [furniture functions and room validity](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:676), [exact keys](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:135), [starter furnished kernel layout](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:690), [room/home design](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:121). **Every furniture key has kernel definition/room support, but no general live player furnishing editor**. This table does not critique active phase-3 work.

| Furniture key | Action, use and connected service | Frozen availability / completeness |
|---|---|---|
| bed | Place/assign one sleeping place with adjacent access; connect household and warmth | K/basic; D/local burrow representation/basic mole-bed count, not a complete household routine |
| patient_bed | Provide accessible patient care place in infirmary | K/basic; no live furnished-infirmary loop |
| seat | Place dining/common seat, merged table appearance; connect meals/social service | K/basic; A/dressing table/stool groups and ambient routines, no live served-food service |
| kitchen_bench | Furnish one cooking work slot in valid kitchen | K/basic; no live furnishing or meal production |
| hearth | Fuel connected heat service for interior rooms | K/basic service contract; visual warmth/fire does not establish full fuel/heat integration |
| shelf | Add 50 kg pantry capacity; connects prepared/ingredient lots and room validity | K/basic; D/local filling-shelf presentation and cellar storage provider, no general shelf placement |
| decoration | Spend wood/wax on room expression and bounded comfort target | K/basic definition; staged props are A/dressing, no live decoration catalog |
| interior_partition | Divide room/heat/access layout using edge boundaries | K/basic room data; absent general live interior editor |
| interior_door | Connect partitioned rooms for access and heat | K/basic room data; absent general live door-placement editor |

##### Complete crop roster and production methods

| Numerical crop row | Demo identities using it | Production-only distinction |
|---|---|---|
| ROOT | radish, turnip, carrot, beetroot, parsnip, onion | seed_roots; spring/summer sowing; sandy/loam compatibility |
| LEAF | cabbage, lettuce, spinach, leek, celery | seed_cabbage; summer/autumn sowing; clay/loam |
| LEGUME | pea, broad bean | seed_beans; rotation fertility gain; hive pollination |
| CEREAL | wheat, barley, oats | seed_grain; spring sowing; flour/porridge chain |
| FIBER | absent in demo | flax and seed_flax; rope/cloth chain |

All identities on a row share its growth/soil/window/yield/frost arithmetic. Strawberry is staged as an asset but deliberately not farmable; fictional spice/cultivated counterparts have no approved field row; livestock/dairy/eggs are excluded. [Mapping and exclusions](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_catalog.gd:5).

##### Building capacity and recipe supplements

Hall/residence/infirmary are managed-interior buildings; production buildings are specified black boxes with work slots. Hall/residence/covered_store/workshop have tier-two upgrade definitions. Production/adopted availability does not mean the frozen demo can construct all of them. [Complete table](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:627), [compiled definitions](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:100).

| Specialist buildings | Intended function and capacities |
|---|---|
| Kitchen, workbench, workshop, mill | 2 cooking, 2 craft, 3 craft, 2 milling workers/slots respectively |
| Dryer, preserver/smokehouse, brewery, saltpan | Four passive batch slots each; 1/2/1/1 workers respectively; saltpan requires coast/brine |
| Fisher shelter, weir, boathouse | Gear locker/bank access, river harvest structure using 2 habitat effort slots, 2 stored boats and 4 fishers |
| Well | Water draw, 10 U per 10 WU; 2 haulers |
| Composter | 4 passive batches, 1 keeper |
| Apiary, nursery | One hive/keeper; 4 propagation slots and 2 tenders |
| Forester lodge, quarry shed | Managed woods access/3 keepers; stone/iron extraction/3 crafters |
| Open stockpile, covered store, cellar | 400 kg, 1500 kg, 1000 kg respectively in base specification; different effective aging factors |
| Lookout | 32 m low-risk radius while staffed |

##### Complete recipe and operation roster

- **24 main recipes:** porridge, root_stew, fish_stew, bean_hotpot, woodland_pie, nut_roast, berry_tart, orchard_crumble, nut_loaf, feast_fish, flour, dry_fish, dry_fruit, salt_fish, ration, mead, compost, cloth, rope, tool, iron_tool, outfit, salt, wax_candle. [Recipe table](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140).
- **12 tabulated ancillary recipes:** separate_seed_grain, separate_seed_roots, separate_seed_beans, separate_seed_cabbage, separate_seed_flax; craft_net, craft_trap, craft_ice_kit; propagate_apple, propagate_pear; draw_water, draw_brine. Additional explicitly described operations: assemble_boat, repair_tool, repair_fishing_gear, orchard planting/harvest, burial, haul loading/unloading and placed torch service. [Ancillary operations](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:169).
- **Excavation operations:** brace, cut, finish/support, remove support during safe closure, backfill, prepare spoil tip, compact, reclaim, close empty tip. [Earth table](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:68).
- **Fishing methods:** hand net, trap (set/soak/collect), weir (inspect/accumulate), boat expedition, ice-kit net modifier; habitat/species choices and intensive policy alter legal work. [Fishing methods](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:392).
- **Feast culinary menus:** Hearth bean hotpot/nut loaf/warm herb infusion; Harvest feast fish/berry tart/mead; Orchard nut roast/orchard crumble/mead. SOC owns feast ceremony, attendance and community effects. [Feasts](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:588).

<a id="phase2-society-inventory"></a>

#### B2. Population, community and tactical inventory

Availability labels: **D** live demo; **K** implemented kernel/helper (whether visibly wired is stated); **L** retired legacy; **S** adopted specification or content direction, not an implemented player loop; **P** proposed engineering package; **A** absent. A spec-only feature is called **stub / specification only**, not an executable stub. Production friends, eating, immigration, festivals and tactics must not be inferred from ambient demo animation or enum/catalog entries.

| Family | Individual system, mechanic, unit, interaction or content | What the player can do now / declared player action | Connects to | Completeness and availability | Exact source |
|---|---|---|---|---|---|
| **SOC01 People, identity and species** | Visible cast: Mouse keeper, Mouse fieldworker, Squirrel gatherer, Squirrel forester, Otter boatwright, Otter fisher, Mole digger, Badger quarryman, Beaver bridgewright | Select/direct nine independently presented workers; displayed names derive mechanically from manifest role keys | Demo work sites, farming, trees, excavation, water | Functional **D**; no personal biographies or hero arcs | [roles](/Users/brendan/Developer/redwall-review/godot/demo/cast/cast_routines.gd:17), [friendly names](/Users/brendan/Developer/redwall-review/godot/demo/cast/demo_actor.gd:211), staged `godot/demo/assets/manifest.json` (gitignored, observed JSON) |
| SOC01 | Separate kernel founder cohort: 6 mice, 2 moles, 2 otters, 2 squirrels; Warden Rowan + 11 anonymous residents | Inspect/name underlying residents through real resident UI; not identities of nine demo bodies | Needs, work, skills, stock demand, future immigration/history | Basic **K**; partial UI wiring, disconnected from demo bodies | [cohort contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:256), [names](/Users/brendan/Developer/redwall-review/godot/test/test_residents.gd:1250), [kernel composition](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:879) |
| SOC01 | Sixteen active species: mouse, shrew, mole, rat, squirrel, sparrow, otter, hare, ferret, weasel, hedgehog, kestrel, badger, fox, wildcat, wolverine; small/medium/large classes, size-dependent food/carry/speed, independent rig identities | Catalog supports all sixteen; initial Refuge normal candidates use eight; player does not currently recruit them | Admission profiles, food budgets, movement fit, equipment, presentation | Functional catalog/store **K**, broader recruiting **S**; beaver is demo addition and is **not** one of these sixteen kernel IDs | [species table](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:219), [live ID artifact](/Users/brendan/Developer/redwall-review/godot/data/catalog_ids.json), [species storage](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:116) |
| SOC01 | Persistent identity, anonymous species/role/ID display, naming/pinning, aliases; notable triggers skill 8/rescue/third-feast lead/warden; stable names, succession | NAME_RESIDENT command implemented; automatic notable-trigger loop largely specified | Hero emergence, skill progression, chronicle, future transfer | Basic **K** for identity/name; **S** for full earned notability | [naming rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:370), [command support](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:89), [resident naming](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:77) |
| **SOC02 Labor, autonomy and learning** | Eleven active jobs: HAUL, BUILD, FISH, FORAGE, FARM, COOK, PRESERVE, CRAFT, TEND, KEEP, HEAL; reserved hunter slot inactive | Set priorities 0–4 and fallback/danger permissions; planner/selector/work arithmetic exists | Every material chain, safety, schedules, skills | Functional subcomponents **K**; incomplete physical work/production loop; visible **D** uses different task controllers | [job domains](/Users/brendan/Developer/redwall-review/godot/data/catalog_ids.json), [priorities](/Users/brendan/Developer/redwall-review/godot/scripts/core/priorities.gd:68), [production call sequence](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:1631) |
| SOC02 | Default/night/flexible schedules; hourly SLEEP/ANYTHING/WORK/SOCIAL; safe interruption; urgency buckets; 6h manual preferred-work destination | Edit schedule/priority data; demo individual/group right-click Move/Work, Release, Hold, dig/farm/forestry orders | Need interruptions, emergency labor, travel and reservation | Functional data/selection **K**, basic demo task control **D**, full autonomy **S** | [schedule presets](/Users/brendan/Developer/redwall-review/godot/scripts/core/schedule.gd:112), [GDD selection/override](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:362), [brain orders](/Users/brendan/Developer/redwall-review/godot/demo/cast/resident_brain.gd:922) |
| SOC02 | Productive XP, levels 0–10, lead-skill quality snapshots, skill 8 notable trigger; mentoring by friends≥3 levels apart | Underlying skill/work calculations; demo dig skill progress separately | Quality, specialist identity, staffing, Charter | Functional arithmetic **K**; mentoring **S** | [skill curve](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:337), [mentoring](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:331), [skill tests](/Users/brendan/Developer/redwall-review/godot/test/test_residents.gd:366) |
| SOC02 | Body/skill affordances: everybeast farms/clears/fells, beaver gnaws, mole digs faster, badger breaks rock but needs widened tunnels, otters dive; carry animation gate | Choose who performs spatial tasks and right-click work | Species character, traversal, tools, work crews | Functional **D**; some gates presentation-dependent rather than future simulation rules | [ability list](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:2), [ability output](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:47) |
| **SOC03 Needs, mood and ordinary daily life** | Hunger/rest/comfort/social/purpose 0–10000, health 0–100; size/winter food demand; productive work factors | Inspect real kernel numbers; no visible demo feeding or sleep tied to those numbers | Food, housing/heat, social activity, labor efficiency | Functional integrator **K**, incomplete gameplay environment/service inputs | [needs owner](/Users/brendan/Developer/redwall-review/godot/scripts/core/needs.gd:2), [missing sources](/Users/brendan/Developer/redwall-review/godot/scripts/core/needs.gd:82), [rates](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:296) |
| SOC03 | Eating, emergency raw food excluding seeds, bed/floor sleep, heated comfort, dining comfort, cold exposure, clothing | Specified causal survival care; demo drink/work/social animations are ambience | Kitchens, raw food, beds, heat, tier2 clothing, weather | Mostly **S** services; some need/health arithmetic **K** | [survival clauses](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:313), [demo routines disclaimer](/Users/brendan/Developer/redwall-review/godot/demo/cast/cast_routines.gd:2) |
| SOC03 | Mood weighted needs + memories; departure warning at 2 bad midnights, leaving at 3; clearing at 3500; incapacitated residents cannot vanish | Need-derived mood exists; no normal producer for departure counter, memories not composed | Productivity, grief, meals, immigration reputation | Basic **K** mood; memories/departure **S** | [mood and memory rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:327), [explicit gaps](/Users/brendan/Developer/redwall-review/godot/scripts/core/needs.gd:103) |
| **SOC04 Households, dependents and family care** | Fixed life stages ADULT/CHILD/ELDER; 256 living cap shared by every stage; no births, aging transitions or age death | Stage store supports explicit creation but baseline founders remain adults | Admission, household composition, needs, rigs, safety | Basic **K** stage storage; full dependent gameplay **S/P** | [resident stage](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:135), [package status](/Users/brendan/Developer/redwall-review/docs/planning/family_execution_package.md:1) |
| SOC04 | Households up to8, up to 2 preferred caregivers, community fallback, care willingness, workload fairness; household membership separate from affinity | Proposed household management/care policy; no live household gameplay | Bed assignments, community care, service labor, migration, history | Stub / proposed contract **P** | [household proposal](/Users/brendan/Developer/redwall-review/docs/planning/family_execution_package.md:165), [household schema](/Users/brendan/Developer/redwall-review/docs/planning/family_state_schema.md:9) |
| SOC04 | Child care need, nonproductive learning/play schedule, no hazardous/ordinary productive work, safe contact; elders not penalized by age alone | Proposed household routines and warnings | Needs, care, paths, no hunting, safety | Stub **P**, hunger lookup helper functional **K** but unconsumed | [care/schedule](/Users/brendan/Developer/redwall-review/docs/planning/family_execution_package.md:105), [helper isolation](/Users/brendan/Developer/redwall-review/godot/scripts/core/family_rules.gd:2) |
| SOC04 | Proposed finite chill illness, separation/grief/departure rules, non-graphic survival consequences | No active disease epidemic or birth cycle; proposed causal care package only | Health, exposure, rescue, family history | **P**; serious but non-graphic child vulnerability adopted **S** | [illness proposal](/Users/brendan/Developer/redwall-review/docs/planning/family_lifecycle_contract.md:7), [adopted tone](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:649) |
| **SOC05 Relationships and community leadership** | Pair affinity−100..100, degree 8, social contact/feast/rescue gains, friendship 40/25 hysteresis, drift, low-mood arguments without combat | No integrated relationship owner or live relationship events; initial six affinity 20 pairs are specified, not already friends | Social rooms, mentoring, feasts, rescues, grief | Stub **S** | [social rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:353), [absence in runtime](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:157), [starter pairs clarification](/Users/brendan/Developer/redwall-review/docs/planning/family_execution_package.md:31) |
| SOC05 | Role varies by scenario: Warden/Abbot/Abbess/institution; any living adult successor after Warden loss; no universal embodied avatar | Rowan exists, naming works; APPOINT_WARDEN is catalogued but unsupported among remaining commands | Scenario identity, civic story, continuity, hero roster | Basic **K** Rowan; succession/other governance **S** | [roles policy](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:215), [Warden continuity](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:801), [unsupported commands](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:96) |
| SOC05 | Self-authored civic Hearth Charter; legitimacy, council, voting, refusal or laws not a defined runtime economy | Charter goal specified; council/law mechanics absent | Completion, values, community identity, scenario role | **S** civic meaning; governance mechanics **A** | [Charter meaning](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:937), [governance boundaries](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:207) |
| **SOC06 Health, rescue and remembrance** | Injury kinds cut/bite/fall/exposure/exhaustion, severity 1/2, aggregate injury, untreated drains, herb 1 + cloth 0.5 treatment, self-care, incapacity/death | Injury core API tested; not composed into full resident medical jobs; needs health rates run | Herbs/cloth, infirmary, rescue transport, weather, labor | Functional helper/store **K**, integrated care **S** | [injury owner](/Users/brendan/Developer/redwall-review/godot/scripts/core/injury.gd:2), [care constants](/Users/brendan/Developer/redwall-review/godot/scripts/core/injury.gd:144), [care rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:873) |
| SOC06 | Demo fatigue/air warning, automatic bank return, swimmer tow/line rescue, bank resting, rescue count, washed-ashore safety | Observe and trigger water difficulty/rescue demonstrations; no fatal demo consequence | Swimming/diving, flow, bridge/ford alternatives, resident commands | Functional **D**, deliberately nonfatal, separate from kernel injury | [rescue contract](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:2), [safety net](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:281) |
| SOC06 | Flood/fire demo threat disc, evacuation through usable tunnel or overground, shelter, return routines | Natural timed and manual Test event; no stock/building damage/injury | Underground escape connectivity, cast, notices | Basic **D** spectacle/route test | [demo threat](/Users/brendan/Developer/redwall-review/godot/demo/events/demo_events.gd:2), [escape task](/Users/brendan/Developer/redwall-review/godot/demo/events/evacuate_task.gd:2) |
| SOC06 | Death record, friend/stranger grief, rescued memory, burial/recoverable possessions, memorial garden 16 entries, visual grave reuse after 48 days | Needs records death; downstream burial/chronicle/possession cleanup not integrated; garden is specified catalog building | Social identity, land use, labor, history, emotion | **K** death arithmetic; memorial/lifecycle **S** | [death gap](/Users/brendan/Developer/redwall-review/godot/scripts/core/needs.gd:126), [memories](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:333), [garden catalog](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:662) |
| **SOC07 Immigration, hospitality and admission** | Candidates every third midnight from day 4, reputation count 2–8, spare beds,4 food-days gate/override, default auto off, expiry next midnight | No candidate queue or functioning admission event in frozen runtime | Housing, food, labor, feast reputation, population cap | Stub **S** | [immigration](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780), [missing stage](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:134), [UI state](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:132) |
| SOC07 | Refuge pool mouse/mole/otter/squirrel/shrew/hedgehog/hare/badger; authored rat petitionday10; explicit unusual-species acceptance, no species-triggered betrayal | Specified humane admission decisions; no currently rendered petition scene | Scenario identity, food forecast, outside world, distinct characters | Stub **S** | [pool and petition](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780), [admission policy](/Users/brendan/Developer/redwall-review/docs/setting_rules_amendment.md:82) |
| SOC07 | Reputation from mean mood, feast count, Charter, recent deaths; arrivals health/needs/equipment/skills, no food grant; migration/departures | Formulas specified; no implemented reputation/admission/lifecycle composition | Growth, specialization, stability, hospitality | Stub **S** | [reputation](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:782), [community task](/Users/brendan/Developer/redwall-review/docs/tasks/08_community_scenarios_progression.md:28) |
| **SOC08 Feasts, culture and sound** | Hearth/Harvest/Orchard feasts, two-course/beverage packages, staff 2 cooks + keeper, seating 3 waves, bedside service,80% coverage,72 h interval, costs/reserve check, finite buffs | Defined production-and-service festival loop; no live feast owner, queue or service | Food variety, preserved surplus, weather, social links, immigration | Stub **S** | [feast requirements](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:578), [themes](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:588), [missing progression/feasts](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:168) |
| SOC08 | Hospitality, gratitude, seasonal tradition, achievement, identity, alliances/obligations; warm humor/light dialect; blended acoustic/ambient/singing/quiet/orchestral direction | Literary/creative authoring direction and corpus, not implemented passive bonuses | Events, table service, work rhythms, visitors, player belonging | **S** direction; presentation execution incomplete/absent | [feast meanings](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:539), [voice](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:701), [sound](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:889) |
| SOC08 | Culture/institution candidate library: Abbey school/archive/infirmary, Long Patrol training/provisioning, shrew flotillas, otter holts, travelers/stories | Read-only source authoring corpus; no new active service buildings should be inferred | Scenario design, professions, meals, event writing | **S** source reference only, NOT_RUNTIME_ACTIVE | [institution evidence](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/shared/continuity.md:24), [authoring contract](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/authoring_handoff.md:5) |
| **SOC09 Narrative, lore and wonder** | Environmental storytelling, personal stories, chronicle/codex, optional descriptions, dialogue, authored events and scenario objectives | Demo notices/visual setting; full story surfaces specified but not populated | People, buildings, history, progression, source corpus | Basic **D** notices; **S** story design | [story direction](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:907), [task08.5](/Users/brendan/Developer/redwall-review/docs/tasks/08_community_scenarios_progression.md:34) |
| SOC09 | Rare meaningful uncertain wonder, dreams, remembered objects, fair riddles; no confirmed magic economy or objective supernatural powers | No implemented riddle, dream or lore/research tree; literary references and authoring policy | Hero moments, exploration, archives, spiritual interpretation | **S** direction; mechanics **A** | [wonder](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:591), [fair riddle boundary](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:605) |
| SOC09 | Source characters, factions, places, foods, ingredients, objects, cultures, ecologies, systems, themes:7,665 records, 1,755 recipe/serving candidates; twelve supplied books | Offline discovery only; preserves identity/era and source-vs-adaptation distinctions | Future content authoring, cuisines, original scenario specifics | Reference corpus, not playable content | [coverage](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/README.md:13), [era reconciliation](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/shared/continuity.md:5) |
| **SOC10 Scenarios, progression, difficulty and endings** | Original-community, Abbey and novel/era settings; founding/restoration/established premises; scenario-specific role, admission, architecture/map/init/objectives | Current one demo village and kernel Refuge baseline; multiple scenario families adopted but finite lineup unfilled | Entire game, source continuity, onboarding, replayability | Basic **D/K** start; scenario expansion **S** | [required first-release families](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:126), [scenario task](/Users/brendan/Developer/redwall-review/docs/tasks/08_community_scenarios_progression.md:15) |
| SOC10 | M0 Refuge; M1 day 4 / 12 residents / 200 portions; M2 population 48 / first winter / 3 mastered recipes; M3 population 80 / year 2 / 8 food-days; M4 year 3 / 120 residents / 8 named skilled residents / 6 skills / 10 mastered recipes / 12 feasts / warm beds / mood / reserves / no current-winter starvation or exposure death / 3 winter days | Unlock conditions documented; bit helper and continuous-window helper exist, no complete progression owner | All production, cooking mastery, specialists, immigration, warmth, feasts | Helpers **K**, real awards/rewards **S** | [milestones](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:795), [helper boundary](/Users/brendan/Developer/redwall-review/docs/planning/progression_execution_package.md:174) |
| SOC10 | Charter victory cosmetic and continue; extinction collapse; sandbox same survival rules/no deadline; first spring ideal spell; tutorial disclosure; relief seeds once/year | No end-to-end win/lose/tutorial/difficulty selector loop verified or composed; deterministic clocks and world baseline exist | Onboarding, recovery, stakes, long-term motivation, persistence | **S**, narrow helpers **K** | [continuation/collapse](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:801), [disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:826), [relief](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:872) |
| **SOC11 Tactical squads, defense and military people** | Move/Attack/Halt/formation/equipment commands; mixed-squad swords/spears/bows, facing, compression/cohesion, flanks/rear, projectiles, morale/rout/rally; per-model casualties under squad orders | No playable battle layer; detailed crowd/battle fixture only. Demo formation move is civilian placement, not tactical combat | Future recruitment, terrain, equipment, hero leadership, campaign | Specification fixture **S**; legacy damage/heal helper **L**, retired and not autoloaded | [battle orders](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:929), [formation](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:677), [combat/morale](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:742), [legacy exclusion](/Users/brendan/Developer/redwall-review/godot/scripts/legacy_battle/combat_system.gd:2) |
| SOC11 | Battle envelope10–16 squads/side; small 40–60 models, architectural 800/1600/1920 qualification targets;32-squad capacity | Architecture/profiling fixtures, not qualified delivered battle sizes; cannot confuse with256 settlement residents | Army scale, crowd visuals, command workload | **S** engineering intent only | [battle envelope](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:27) |
| SOC11 | Lookouts reduce hazard radius; fences/walls/gates manage access/wildlife/weather; no army raids, attack commands, siege/damage in settlementrelease 1 | Catalog/placement infrastructure; no combat defenses in live village | Safe resource zones, mobility, future tactical layouts | Basic catalog **K**; operational risks/defense mostly **S** | [building catalog](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:656), [release boundary](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:728), [no additional raid/fire model](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:672) |
| SOC11 | Recruitment, drill, barracks, muster, unit specializations, named captains and villains, wounded/veteran return | Not implemented army systems; no chosen canonical antagonist or recruitable hero lineup | Work force, equipment, food, medical care, stories | **A**, user-requested future vision to review explicitly | [current conflict scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:621), [no active antagonist](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:635), [future shared identity](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:905) |
| **SOC12 Campaign, trade and outside communities** | Future transfer manifests for residents/supplies, atomic prepare/commit/cancel/return, preserved identity/quality/age; shared world-clock policy not yet decided | No destination consumer; execution UI hidden by spec | Army expeditions, food reserves, home skills/relationships | **S** compatibility hooks, absent playable consumer | [transfer table](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:899), [hide unavailable transfers](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:912) |
| SOC12 | Campaign map, diplomacy, trade/tribute, caravans, scouting, multiple settlements, external faction motives/alliances | Wider product direction; no active state or commerce/currency economy in current release | Exploration, specialization, conflict motives, trade sinks, scenario relationships | **A** runtime; broad future **S** | [current technology/scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:567), [external-faction scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:621), [campaign open](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:1003) |

##### Every resident species, including the demo-only beaver

These are playable availability distinctions, not biological claims or profession restrictions. The **kernel** uses size classes: small/medium/large have food multipliers 1.0/1.2/1.6 and carry capacities 12/16/24 kg. There is explicitly no hidden species productivity multiplier. A catalog/rig identity does not prove a rendered model, completed traversal profile or recruitable individual. [Size rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:306), [logical rigs only](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:148). The Refuge's ordinary admission pool is a specification, not a working recruitment menu. [Admission](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780).

For current demo bodies, ordinary farming, felling/sawing and clearing are generally shared actions; actual carrying requires the staged carry capability. Bore access is body geometry, not a species profession; digging experience changes speed. Swim/dive entries below are demo rules, not approved production species powers. [Demo ability contract](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:2), [water table](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/swim_rules.gd:69).

| Species | Kernel class / admission / current representation | What the player can do, connections and completeness |
|---|---|---|
| Mouse | Small; six kernel founders including Rowan; ordinary Refuge pool; keeper and fieldworker demo bodies | **Functional D** selection/general work, unladen swim; **basic K** identity/needs/skills. Connects hall, fields, food and shared jobs. Demo labels do not force a keeper/farmer career. [Cast](/Users/brendan/Developer/redwall-review/godot/demo/cast/cast_routines.gd:17) |
| Shrew | Small; ordinary Refuge pool; no active demo body or founder | **Functional K** catalog/size identity; **S** prospective admission; no species-specific live interaction. Would use shared work/services when admitted. [Species](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:121) |
| Mole | Small; two kernel founders; ordinary pool; one demo digger | **Functional D** general work, swim and initial digging expertise; bore access still checks geometry. **Basic K** resident identity. Connects excavation, access and soil work. [Dig experience](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/dig_skills.gd:19) |
| Rat | Small; authored day-10 Refuge exception, explicit acceptance; no live demo/founder | **Functional K** identity; **S** petition/admission; no hidden betrayal or required occupation. Connects hospitality and scenario identity, not an active villain roster. [Petition](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780) |
| Squirrel | Small; two kernel founders; ordinary pool; gatherer and forester demo bodies | **Functional D** shared work/swim; forester begins with felling experience. No playable canopy ability inferred from species. **Basic K** identity. Connects forestry, carrying and planting. [Forestry skill](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_skills.gd:16) |
| Sparrow | Small; catalog and logical rig; outside ordinary Refuge pool; no live demo body | **Functional K** catalog/size; broader scenario eligibility **S**. No delivered flight or automatic water bypass. Connects future admission/equipment only through shared rules. [No anatomical bypass](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:273) |
| Otter | Medium; two kernel founders; ordinary pool; boatwright and fisher demo bodies | **Functional D** general work, fast swim and dive; rescue/water access are active. Fisher label is not evidence of delivered fish-to-pantry production. **Basic K** identity. [Water capabilities](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/swim_rules.gd:69) |
| Hare | Medium; ordinary Refuge pool; no active demo body/founder | **Functional K** catalog/size; **S** admission. No delivered Long Patrol recruitment or exclusive military profession. Connects shared labor, food demand and future scenario identity. [Pool](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780) |
| Ferret | Medium; catalog, outside ordinary Refuge pool; no demo/founder | **Functional K** identity, **S** validated other admission profiles; no current player-controlled unit or species-specific mechanic. Future role/morality depends on authored people and actions. [Catalog/profile boundary](/Users/brendan/Developer/redwall-review/docs/setting_rules_amendment.md:82) |
| Weasel | Medium; catalog, outside ordinary Refuge pool; no demo/founder | **Functional K** identity, **S** other profiles; shared jobs/services only, no active spy, saboteur or villain ability. [Catalog](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:124) |
| Hedgehog | Medium; ordinary Refuge pool; no demo/founder | **Functional K** catalog/size; **S** admission; no implemented spine/combat defense mechanic. Connects future shared settlement work and consumption. [Species](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:124) |
| Kestrel | Medium; catalog/logical rig, outside ordinary Refuge pool; no demo/founder | **Functional K** identity; broader profile **S**; no current controllable flyer, scouting unit or aerial combat. [Flight boundary](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:273) |
| Badger | Large; ordinary Refuge pool; demo quarryman, no kernel founder | **Functional D** general work and rock breaking; needs widened passages and wades rather than swims. **Functional K** large-size identity, **S** admission. Connects quarrying, wide infrastructure and higher food/carry scale; not inherently a general. [Abilities](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:59), [breaker](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_crew.gd:38) |
| Fox | Large; catalog, outside ordinary Refuge pool; no demo/founder | **Functional K** identity/size; broader profiles **S**; no implemented trickster, diplomacy or betrayal power. Shared potential roles only. [Species](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:127) |
| Wildcat | Large; catalog, outside ordinary Refuge pool; no demo/founder | **Functional K** identity/size; broader profiles **S**; no active lord, combat hero or recruitable specialist. [Species](/Users/brendan/Developer/redwall-review/godot/scripts/core/residents.gd:127) |
| Wolverine | Large; catalog, outside ordinary Refuge pool; no demo/founder | **Functional K** identity/size; broader profiles **S**; no active giant, boss or army unit. Catalog membership is not enemy content. [Species/giant boundary](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:219) |
| Beaver — demo only | Not one of the sixteen kernel species IDs; bridgewright demo body | **Functional D** shared work, gnawing, strong swimming and initial bridge expertise; no dive. Connects logs/planks/crossings. No production admission/needs profile inferred. [Gnawing](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_skills.gd:26), [bridge experience](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/swim_rules.gd:41) |

##### Every active job kind

All eleven active kinds have priority/skill representation; that does not make their complete jobs playable. Production worker selection, physical travel, consumption, output and service execution remain separate integration boundaries. The demo uses its own domain controllers. [Job kinds/priorities](/Users/brendan/Developer/redwall-review/godot/scripts/core/priorities.gd:68), [composition](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:1631).

| Job / player intent | Functions, connections and current completeness |
|---|---|
| **HAUL** — keep goods moving | Designated storage, input/output delivery, drawing water and equipment changes connect every chain to reachable supply. **Basic K** priority, capacity and inventory rules; physical end-to-end generic haul loop incomplete. **Functional D** domain-specific harvest/log/plank/spoil carrying when supported, not that generic kernel loop. [Haul mass](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:616), [water/equipment](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:640) |
| **BUILD** — construct planned works | Materials arrive before shared build work; connects blueprints, tool condition, access and future shelter/service. **Basic K/S** building stores/rules, incomplete integrated construction; **functional D** selected tunnel fixtures/bridges through demo controllers. [Build work](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:664) |
| **FISH** — harvest permitted aquatic food | Gear, crew skill, quotas, closures and risk govern catches; connects food, preservation, haul and rescue. **Functional K** ecology/catch arithmetic, **S** complete fishing work cycle; demo fishing driver is not a finished fish-to-kitchen loop. [Fishing](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:376) |
| **FORAGE** — gather replenishing plant foods/herbs | Designate a legal area, choose quotas/intensity; habitat stocks and safety determine eligible work. **Functional K** demand/claim producer and ecology, missing complete travel/output path; no broad active demo forage loop inferred from “gatherer” label. [Producer](/Users/brendan/Developer/redwall-review/godot/scripts/core/job_planner.gd:32) |
| **FARM** — sow, tend and harvest fields | Seed, water, soil/rotation, growth and weather connect production to kitchen stocks. **Functional K** bounded plot arithmetic and some job producers, incomplete full service/output loop; **functional D** real bed actions/harvest carrying through farm crew. Crop tending uses FARM, not the separately named TEND kind. [Producer](/Users/brendan/Developer/redwall-review/godot/scripts/core/job_planner.gd:3) |
| **COOK** — prepare meals/drinks and serve occasions | Orders, input lots, skill/quality, kitchen/brewery slots and fuel connect food to needs/feasts. **Basic K** catalog/order/skill foundations, **S** completed meal-production/service loop; cauldron animation is not proof of cooking. [Recipe graph](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:526), [kitchen/brewery](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:636) |
| **PRESERVE** — trade processing/time for shelf life | Dry/salt fish, dry fruit, make rations and salt; active work and passive occupancy differ. **Basic K** catalog/stock rules, **S** integrated processing. Connects season risk, storage space and expedition provisions. [Preservation recipes](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:546) |
| **CRAFT** — transform materials and maintain capability | Milling, cloth/rope/tools/clothes/candles/gear and quarry access are cataloged jobs/stations. **Basic K/S** skill/catalog/resources; full crafting/repair loop incomplete. **Functional D** sawing/plank use is a distinct demo chain. [Craft recipes](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:552), [quarry](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:655) |
| **TEND** — support nursery propagation | TEND exists in the skill/priority domain; the nursery is staffed by two Tenders and defines propagation slots. **Basic K** priority/skill representation; **S** nursery work, no complete dedicated executor. Orchard maintenance is specified, but do not infer that every operation named “tend” uses TEND: crop tending is FARM and hive service is KEEP. [Propagation](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:482), [nursery staffing](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:651) |
| **KEEP** — maintain common services and landscape | Hall/feast service, compost, apiary care, forestry, lookout and memorial staffing use keepers. **Functional K** hive-service producer plus priorities, wider service completion **S**; demo keeper routines are ambience. Connects comfort, ecology, safety, feasts and remembrance. [Hive producer](/Users/brendan/Developer/redwall-review/godot/scripts/core/job_planner.gd:45), [stations](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:649) |
| **HEAL** — care for the injured | Rescue to reachable bed/landing, treatment with herbs/cloth, infirmary capacity and self-care connect health to supply and labor. **Functional K** injury/treatment arithmetic, integrated medical jobs **S**; live swim rescue is a distinct **D** nonfatal system. [Medical contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:873) |

`RESERVED_3` is an inactive compatibility slot, not a twelfth available profession. There is no huntable mammal/bird job. Food/resource variants are listed in B1, and building/interior variants in B1 and B3; the table above records their labor connections without assigning them new implementations.

<a id="phase2-interface-inventory"></a>

#### B3. Interface, construction and presentation inventory

Scope: detached `157a3a4`; source reading only in this stage. Native observations are **previous Phase 1 observations**, not new hands-on testing. The frozen [demo scene](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.tscn:1) instances the [main application scene](/Users/brendan/Developer/redwall-review/godot/scenes/main.tscn:1); [composition](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:139) replaces its presentation but retains its HUD. The main scene has a fixed orthographic camera, ground plane and crowd stage; the demo uses its own perspective camera, nine staged actors, authored village and runtime panels. A registry saying a store is absent is evidence of **UI availability text**, not proof that the kernel store does not now exist.

Status vocabulary: **stub** = declared or partial surface without its promised player loop; **basic** = a narrow usable interaction or primitive; **functional** = a connected usable local loop; **polished** = coherent, scalable and validated presentation. Availability distinguishes **live demo**, **application/kernel only**, **spec/catalog only**, **asset/dressing only**. These are coverage categories, not recommendations.

| Family ID | Player-facing mechanics and what the player can do | Connections and current availability | Completeness and sources |
|---|---|---|---|
| UX1 Controls, camera and selection | Move orbit camera with WASD/arrows; Q/E yaw; wheel/PageUp/PageDown zoom; Alt+PageUp/PageDown pitch; middle drag yaw/pitch; Home reset. Select a resident or box group, Shift add/toggle, clear on empty ground/Esc; right-click context move/work; formation destination markers; R release to routines. Select trees, beds, tunnels, bridge sites, spoil heaps via domain pickers. | Live demo cast and order router; body eligibility and work/resume cues. Paused camera/selection/orders still usable. Main shell has separate roster selection. Control groups, double-click similar, queued tasks, follow and accessible tile list are specified but not all bound into demo. No controller-only release claim. | **functional local/basic complete controls**; [camera constants](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:39), [camera input](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:170), [demo input](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:377), [selection](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:443), [spec map](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:301). |
| UX2 Information architecture and management screens | Persistent resource/time/alert/map/action zones; expandable ledger/history/calendar; resident journal/roster; demo party inspector; Farm/Tunnels/Woods/Water side tabs; crop picker; Pantry. Hover tips, buttons, inline reasons, readouts, scroll areas, meters, icons and text. | Live demo domain surfaces coexist with application-shell data. Subsystems supply data to their own panels; only one domain side panel shows, yielding to resident journal. A separate demo news feed sits above command dock. This inventory does not repeat Phase 1 data/layout defects. | **basic**, with functional domain inspectors; [shell pages](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:251), [domain tabs](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_detail_zone.gd:44), [pantry](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:1), [party](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:41). |
| UX3 World reading, overlays and explanations | V cycles moisture, ripeness, water zones/fishery/bridges/landings/swim links, woods zoning, off. U switches top-down underground cutaway with strata, water no-dig band, foundations, roots, dug bores, junctions, lanterns and surface resident markers. Planning ghosts and accepted/refused order pulses; on-world soil/tunnel/fishery readouts. | Live farm/water/forestry/tunnel visualization; body-sensitive water overlay uses first selected actor. Main application minimap is generated-world tile inspection and an ecology-layer toggle, not a full spatial navigation map for the visible village. Forecast chart and most map layers are declared. | **functional overlays/basic navigation explanation**; [demo README overlay map](/Users/brendan/Developer/redwall-review/godot/demo/README.md:123), [water overlay](/Users/brendan/Developer/redwall-review/godot/demo/water/water_overlay.gd:1), [cutaway](/Users/brendan/Developer/redwall-review/godot/demo/README.md:228), [shell minimap](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3470). |
| UX4 Construction, layout and architectural expression | Live dig-route and bridge-span tools modify usable space; forestry/conservation rectangle tools alter land policy. Existing village buildings, paths and decorative props are authored, not player placed. General kernel supports building footprints/rotation/unlock masks; projects deliver materials, work, pause, complete, refund, upgrade, demolish; room/furniture rows exist. | General construction GUI is disabled/unbuilt despite kernel stores. Baseline BuildingDefinitions has 30 buildings and 9 furniture definitions, separately enumerated by economy researcher. Room/home/cellar feedback will be design-only per user. Paths/fences/walls/lookouts are settlement access/risk infrastructure in current GDD, not an implemented battle defense game. | **functional specialized demo tools/basic kernel/stub general player construction**; [building placement](/Users/brendan/Developer/redwall-review/godot/scripts/core/buildings.gd:549), [construction lifecycle](/Users/brendan/Developer/redwall-review/godot/scripts/core/construction.gd:20), [task integration](/Users/brendan/Developer/redwall-review/docs/tasks/06_buildings_rooms_logistics.md:21), [demo fixed layout](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:46). |
| UX5 Learning, discovery and objectives | HUD command hover text, demo party input paragraph and resident ability list, domain hints and refusal messages. External demo README teaches systems. Tutorial card, objective screen and milestone disclosure exist in specification/registry; no integrated tutorial state enabled by New Settlement. | Live instructions explain verbs; progression/Charter state belongs to society researcher. No guided first-session objective path established in Phase 1. The project explicitly specifies nonblocking tutorial steps, recoverable targets and optional skip. | **basic instructions/stub tutorial and objective UI**; [tips](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_command_tips.gd:29), [tutorial unavailable](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_world_session.gd:24), [disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:824), [tutorial registry](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:215). |
| UX6 Session, time, settings and accessibility | Pause, 1×/2×/4×; camera and UI operate on real time; compressed demo day one minute at 1×; F11 fullscreen toggle; stall recovery Resume banner. Main Menu button opens a basic New Settlement modal with Create/Back. Name/seed/architecture/mode/tutorial session model exists; only Abbey standard refuge supported. | Game clock shared by live presentation; demo calendar distinct from kernel tick/calendar. Save codecs/sections/replay/restore exist but save/load UI remains unfinished; settings catalog/rebinding/defaults/accessibility modes specified. Shell has semantics/focus/layout scaling primitives; demo controls are not a qualified complete accessible flow. | **functional time/basic session/stub save/settings experience**; [demo calendar and time](/Users/brendan/Developer/redwall-review/godot/demo/README.md:57), [session fields](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_world_session.gd:60), [Menu action](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3451), [persistence task](/Users/brendan/Developer/redwall-review/docs/tasks/09_persistence_replay_reliability.md:137), [settings specification](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:434). |
| UX7 Visual world, asset families and action presentation | Grounded expressive staged buildings/residents, dense forest ring, ground cover/debris, paths and work clusters, water/banks/boats, weather particles/light, tree falls/stumps/saplings, growing crop cards, held harvest/tools and stocked shelves, underground bores/lanterns/braces/finds. Missing staging falls back to shapes. | Live staged artwork with authored positions; some props imply future work but remain dressing. Nine cast rigs have gait-scaled motion/tails. UI applies wood/parchment/brass skin over the shell. Approved world style is dimensional/material-based; UI palette is not universal world-art instruction. | **functional presentation, heterogeneous finish**; [layout](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:46), [scatter](/Users/brendan/Developer/redwall-review/godot/demo/world/world_scatter.gd:1), [demo art pass](/Users/brendan/Developer/redwall-review/godot/demo/README.md:341), [world art direction](/Users/brendan/Developer/redwall-review/docs/art-reference/visual_direction_alignment.md:30), [UI skin](/Users/brendan/Developer/redwall-review/godot/demo/ui/woodland_skin.gd:1). |
| UX8 Audio and multisensory identity | Visual rain/snow/work, poses, particles and text provide existing feedback. No demo AudioStreamPlayer/audio buses/music/world sound integration was located by scoped source search. Master/effects/ambience/notice volume controls are specified. | **Absent integration** in live demo; no listening test conducted. Future audio can follow real actions, material contact, settlements/seasons and warning text. This is status inventory, not a repeated audio bug. | **stub/spec-only**; [settings audio fields](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:444), [demo composition](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:139), earlier F43. |

##### Every live or partially built screen/interaction surface

| Surface | Actual contents and interaction | Availability/status; source |
|---|---|---|
| Resource tray / expanded ledger | Ready-food/Fuel/Wood/Stone/Residents/Beds positions, click counters for exact expanded ledger; some cells unavailable. Demo overwrites food display from Pantry. | Live shell/basic; [shell resources](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:872), [farm HUD](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_hud.gd:50). |
| Alert stack / error panel / pause label | Up to two wide cards or one narrow summary, code/recovery detail; pause reasons. | Live shell/basic; [alerts](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:971). |
| Notification history | N or history button; up to 20 constructed visible rows from retained notice model; selected full notice expanded, close/Esc, focus return. | Live shell/functional limited view; [history](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3285). |
| Village news | Three fresh demo feed lines; notes 12 seconds, warnings 30, dated, noninteractive; feed is separate from shell history. | Live demo/basic; [news](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_news_strip.gd:1). |
| Time cluster / calendar expansion | Pause and speeds; date tooltip full time, date opens calendar surface. Built calendar is a text label surface, not full forecast tool. | Live shell/basic; [time build](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1129). |
| Minimap / ecology layer / tile inspector | Map rectangle picks 128×128 generated-world tile after creation; ecology-layer visibility toggle; tile details identify terrain/basin/danger. | Application shell/basic; [tile pick](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3467), [inspector](/Users/brendan/Developer/redwall-review/godot/scripts/systems/ui_manager.gd:496). |
| Command dock | Build, Zone, Jobs, Food, Residents, Feast, Objectives. Enabled actions answer shortcuts; missing implementations disabled with reasons. Demo Food opens Pantry; B used by Dig while Build unavailable. | Live shell with overrides/basic; [dock](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:204), [tips](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_command_tips.gd:39). |
| Resident roster / journal | Roster pool 12; rows select real kernel resident identity; journal identity/emblem/health/activity/note, five need rows and rate tracks, supporting skill text, close/center affordance. No claim that selecting kernel roster selects visible cast. | Application shell/basic; [roster](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1476), [journal](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1192). |
| Demo party inspector | Up to six text rows plus count; selected names/species/activity, single resident ability restrictions, work notices, skills, unfinished-job resume text; Dig button. | Live demo/basic; [party](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:41). |
| Domain tab rail | Farm/Tunnels/Woods/Water; explicit close collapses body, tab/intent reopens; all yield while shell journal opens. | Live demo/functional; [tabs](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_detail_zone.gd:44). |
| Farm inspector | Calendar, selected bed, priority need/reason, crop/stage/time, moisture/band, fertility/health/soil treatment/yield/jobs; Plant, Water, Drain, Harvest, Clear, Compost, Cover, Raise, Bank, Rest/Unrest, Cancel; close. | Live demo/functional local; [bed panel](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:1). |
| Crop picker | Sowable ingredients first; crop icon, growth time/yield/family/rotation, unavailable soil/window reasons. | Live demo/functional local; [picker](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:338). |
| Pantry | Two lists: owned ingredients/stock/freshness/store summary and selected ingredient's library dish relationships; spoiled food compost action; K/Esc/close. Recipes are reference candidates, not active kitchen production. | Live demo/basic; [pantry list](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:124), [dish links](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:228). |
| Tunnels & burrows inspector | Weather/stores/finds icons/news/selected bore status; Widen, Brace, Hang lanterns, Pump out/Clear fall via Repair, Burrow home, Root cellar, Next weather, Test event. | Live demo/functional local; underground rooms excluded from implementation critique; [tunnel panel](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_panel.gd:31). |
| Dig tool / pointer readout | Drag route or click points; Shift bend, Enter/right-click commit, Backspace undo point, Esc drops preview/closes, B/T toggles; snap and refusal ghost; length/quanta/labor-hours/spoil/terrain summary; underground auto-view. | Live demo/functional; [keys](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_control.gd:294), [readout](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/dig_readout.gd:1). |
| Woods inspector / zone tools | Selected tree state, forestry/conservation zone and floor, seasonal/work/store counts; fell/haul/grub/plant; intensive/auto-fell/unmark; mark two zone types via drag; gather deadfall/saw/cancel jobs/storm gust. | Live demo/functional local; [woods](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_panel.gd:25). |
| Water inspector / span tool | Conditions/alerts/swimmer stats/site cost/bridge/store/news; previous/next three sites, arbitrary two-bank span, log/plank bridge, dive pond, swim consent, cramp debug trigger. | Live demo/functional local; [water](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/water_panel.gd:23). |
| Spoil interaction | Click heap highlights/amount; C or right-click clearing with selected carriers; progress described in party panel. | Live demo/functional local; [spoil flow](/Users/brendan/Developer/redwall-review/godot/demo/README.md:514). |
| Zone brush (generic shell) | Brush 1/2/4/8, confirm/cancel; API records sorted tiles and submits FORAGE designations for a selected generated basin. This is distinct from demo forest rectangles. | Shell basic; [brush](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3778). |
| New Settlement | Menu opens centered page with Create and Back; session model supports name/seed validation and refused unsupported variants, but full settings form not constructed. | Shell basic; [workspace](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1396), [session](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_world_session.gd:1). |
| World access list / name editor / search / quick menu | Shell allocates pages/placeholder controls or context owner; usable full F6 navigation/filter/name editor absent. Selected-job cancel bridge exists, not a rich general right-click menu. | Partial shell/stub; [pages](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1396), [cancel API](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3696). |
| Tooltip / focus outline | Shell semantic names, descriptions, focus indication and on-focus explanations; demo command hover instructions; decorative pieces exclude input. | Live mixed/basic; [focus](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1569), [tips](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_command_tips.gd:1). |
| Stall banner | Dedicated paused diagnostic, real-time Resume button/Enter/Space; keeps player pause; suppresses duplicate clock card. | Live demo/functional recovery; [banner](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_stall_banner.gd:1). |
| UI specimen scene | A deliberate component/theme test scene; not player menu or gameplay. | Development-only; [scene](/Users/brendan/Developer/redwall-review/godot/scenes/ui/ui_specimen.tscn:1). |

##### General construction and expressive space inventory

General kernel building placement stores 0–3 quarter-turn rotations, tile footprint/nonoverlap and earned unlock mask; it does not itself validate terrain or real hall connectivity. Construction has BUILD/UPGRADE/FURNITURE/DEMOLISH purposes and awaiting-materials/ready/working/work-done/refunding phases; up to four builders, pause retaining progress, 100% cancellation before work, 80% after, base-cost 50% demolition returns after quarter build-work. These are implemented stores, not a working live construction interface. `request_demolition` in SettlementSystem is read-only evidence gathering and never starts the project at this snapshot. Roads are 1×1 building definitions; furniture/room designation stores support interior membership but no live general furnishing editor. Tier 2 packages cover hall/residence/store/workshop, not an unlimited tier ladder. [Placement implementation](/Users/brendan/Developer/redwall-review/godot/scripts/core/buildings.gd:549), [construction](/Users/brendan/Developer/redwall-review/godot/scripts/core/construction.gd:208), [demolition composition](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:2637), [upgrade specification](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:730).

Declared player construction tools: building catalog/cards, footprint ghost/cost strip, 90-degree rotate/repeat; room rectangle/free designation and furniture palette; floor/roof/cutaway modes; roads/paths, fence/gate/wall/lookout placement; explicit demolition refund/evacuation review. Most remain specified or kernel-only. Live specialized tools are tunnel strokes, burrow/cellar placement, bridge spans, forest zones and farm ground treatments. **No live surface-town layout editing, decorations catalog, copy-layout tool or road brush was located in the demo.** The last statement is scoped absence from the reviewed runtime, not an assertion that all design docs omit them. [Declared UI IDs 052–059](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:218), [input contract](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:301).

##### World asset and visible-building inventory

Nine authored central building instances: hall, well, three residences, kitchen, covered store, open stockpile and workbench. Water dressing adds boathouse, weir, fisher shelter and mill; crop area has six beds and fence runs; gameplay can add surface cellar dressing, underground rooms, bridge spans, tunnel mouths and heaps. Fixed material paths connect square/hall/homes/store/workbench/beds. Central props: cauldron tripod, two table-and-stool groups, log stack, two sack piles, two crates, three barrels, water bucket, wheelbarrow, handcart. Woodland: mature oak/beech/oak sapling, fresh/mossy stumps, boulders/rock clusters/fallen logs, grass tufts/mushrooms/reeds. [Authored placement tables](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:46), [scatter](/Users/brendan/Developer/redwall-review/godot/demo/world/world_scatter.gd:24), [water dressing](/Users/brendan/Developer/redwall-review/godot/demo/water/water_dressing.gd:1).

Staged manifest contains **102 world asset keys and 9 cast keys**, not 102 completed gameplay features. Item props, plants and icons are distinct from building functions. Boats/jetty/rod/net/eel trap/smoking rack/creels are placed dressing; interactive bridges use their staged models. Saltpan deliberately unplaced in freshwater setting. Staging is gitignored and was already completed by root; this stage read only manifest metadata. [Manifest reader](/Users/brendan/Developer/redwall-review/godot/demo/demo_manifest.gd:1), [asset mapping](/Users/brendan/Developer/redwall-review/godot/demo/README.md:341), [freshwater dressing scope](/Users/brendan/Developer/redwall-review/godot/demo/water/water_dressing.gd:37).

Cast keys: mouse_keeper, mouse_fieldworker, squirrel_gatherer, squirrel_forester, otter_boatwright, otter_fisher, mole_digger, badger_quarryman, beaver_bridgewright. The society inventory lists other species/catalog units. Gait matching, tail springs, carrying and work-held tools are live, but actor roles and visual props do not establish full corresponding production chains. [Demo cast composition](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:199), [asset pass](/Users/brendan/Developer/redwall-review/godot/demo/README.md:376).

<a id="phase2-ui-catalogue"></a>

#### B4. All 103 declared interface elements

The following compact catalogue is mechanically transcribed from [registry](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_registry.gd:126) and [availability](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:143). **Built** means present in RENDERED_IDS, not necessarily visible or interactive; **WIRED** means its static availability row uses that term. Actual demo override/screen details are above. All rows connect to UX2 unless classified below: controls/focus/world access→UX1; map/forecast→UX3; build/room/furniture/zone→UX4; tutorial/objectives/victory→UX5; settings/save/session/time→UX6.

| ID | Declared element | Built in shell | Static availability label (may be stale) |
|---|---|---|---|
| 001 | Resource cluster | yes | wired |
| 002 | Food counter | yes | wired |
| 003 | Fuel counter | yes | no heating demand |
| 004 | Wood counter | yes | wired |
| 005 | Stone counter | yes | wired |
| 006 | Population counter | yes | wired |
| 007 | Bed counter | yes | no building store |
| 008 | Expand resources | yes | wired |
| 009 | Resource ledger | yes | wired |
| 010 | Alert stack | yes | wired |
| 011 | Alert card | yes | wired |
| 012 | Notice history | yes | wired |
| 013 | Time cluster | yes | wired |
| 014 | Pause button | yes | wired |
| 015 | Speed 1 | yes | wired |
| 016 | Speed 2 | yes | wired |
| 017 | Speed 4 | yes | wired |
| 018 | Calendar | yes | wired |
| 019 | Menu button | yes | wired |
| 020 | Minimap frame | yes | wired |
| 021 | Minimap view | yes | wired |
| 022 | Map layers | yes | wired |
| 023 | World surface | yes | wired |
| 024 | Selection ring | no | no transform store |
| 025 | Box selection | no | no transform store |
| 026 | Command strip | yes | wired |
| 027 | Build command | yes | no building store |
| 028 | Zone command | yes | wired |
| 029 | Jobs command | yes | panel not built |
| 030 | Food command | yes | no recipe order store |
| 031 | Residents command | yes | wired |
| 032 | Feast command | yes | no milestone state |
| 033 | Objectives command | yes | no milestone state |
| 034 | Demolish command | no | no building store |
| 035 | Upgrade command | no | no building store |
| 036 | Context detail | yes | wired |
| 037 | Detail title | yes | wired |
| 038 | Detail tabs | yes | wired |
| 039 | Need row | yes | wired |
| 040 | Skill row | yes | wired |
| 041 | Priority cell | no | panel not built |
| 042 | Schedule grid | no | panel not built |
| 043 | Lot row | no | panel not built |
| 044 | Order row | no | no recipe order store |
| 045 | Fish stock row | no | panel not built |
| 046 | Crop stat row | no | panel not built |
| 047 | Room row | no | no building store |
| 048 | Relationship row | no | panel not built |
| 049 | Danger consent | no | panel not built |
| 050 | Quota slider | no | panel not built |
| 051 | Workspace frame | yes | wired |
| 052 | Build catalog | no | no building store |
| 053 | Building card | no | no building store |
| 054 | Placement ghost | no | no building store |
| 055 | Placement cost strip | no | no building store |
| 056 | Rotate placement | no | no building store |
| 057 | Room tool | no | no building store |
| 058 | Furniture palette | no | no building store |
| 059 | Zone brush | yes | wired |
| 060 | Recipe list | no | no recipe order store |
| 061 | Recipe card | no | no recipe order store |
| 062 | Number stepper | yes | wired |
| 063 | Feast planner | no | no milestone state |
| 064 | Feast theme picker | no | no milestone state |
| 065 | Reserve override | no | no milestone state |
| 066 | Confirm | yes | wired |
| 067 | Cancel | yes | wired |
| 068 | Immigration review | no | no immigration event |
| 069 | Resident row | yes | wired |
| 070 | Job matrix | no | panel not built |
| 071 | Forecast chart | no | no forecast model |
| 072 | Tutorial card | no | no tutorial state |
| 073 | Tooltip | yes | wired |
| 074 | Focus outline | yes | wired |
| 075 | Search filter | yes | panel not built |
| 076 | Save browser | no | no save codec |
| 077 | Save row | no | no save codec |
| 078 | Settings menu | no | no settings store |
| 079 | Setting control | no | no settings store |
| 080 | Key binding row | no | no settings store |
| 081 | Rebind capture | no | no settings store |
| 082 | Name editor | yes | panel not built |
| 083 | Victory panel | no | no milestone state |
| 084 | Collapse panel | no | no milestone state |
| 085 | Error panel | yes | wired |
| 086 | Pause label | yes | wired |
| 087 | World access list | yes | panel not built |
| 088 | Cycle selection | no | no transform store |
| 089 | Zoom buttons | yes | no world camera |
| 090 | Pitch slider | yes | no world camera |
| 091 | Schedule template | no | panel not built |
| 092 | Back menu action | yes | wired |
| 093 | Panel close | yes | wired |
| 094 | Scroll bar | yes | wired |
| 095 | Tab navigation | no | panel not built |
| 096 | Context quick menu | yes | wired |
| 097 | Relief seed action | no | panel not built |
| 098 | Pin resident | yes | panel not built |
| 099 | Ration reserve | no | no milestone state |
| 100 | Work policy | yes | wired |
| 101 | Date trigger | yes | wired |
| 102 | History trigger | yes | wired |
| 103 | New settlement | yes | wired |

**60 declared elements are in the shell render set**; 43 are registry-only there. Repeated rows, decorations and demo-added controls are not included in that count. Some built panels are placeholders.

Settings catalogue (all adopted specification; not a finished live Settings screen): display mode, resolution, UI scale 100/125/150%, master/effects/ambience/notice volumes, edge scroll, pan/zoom sensitivity, invert zoom, camera smoothing/pitch, reduced motion, high contrast, occluded selection, pause on management, critical autopause, screen-reader mode, tooltips, autosave frequency and context-checked keybindings. Accessibility specification includes F6 searchable world categories, keyboard tile coordinates/placement/room rectangles, keyboard job matrix/schedules, equivalent table forecasts and screen-reader announcements. [Settings and accessibility](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:434).

The full input map includes bound named actions for pan/yaw/zoom/pitch, click/box/toggle/similar/clear/cycle, assign/recall/center groups 0–9, context/queue/cancel preference, pause/speeds, Build/Zone/Harvest/Jobs/Food/Roster/Feast/Objectives/History/Calendar, minimap/home/follow/roof, place/rotate/repeat/brush/erase/interior, demolish/pin/world-list/quicksave/quickload/confirm/back/tab/undo/text/menu. **A project.godot action binding is not proof of a corresponding demo handler**. Live demo handlers implement the subset documented above; controller-only gameplay is explicitly not promised. [Complete action contract](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:301), [camera handler](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:170), [demo command handler](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:377).

<a id="phase2-assets"></a>

#### B5. The exact staged-art catalogue

The staged manifest is an art catalogue. These **102 exact world keys** and **nine cast keys** were present in the review copy; they do not add new edible species, production recipes or building services. In particular `item_eel`, `eel_trap`, `item_shrimp`, `item_hotroot`, `item_strawberry` and `plant_strawberry` are asset names, not permission to harvest eel, expand the edible-fish whitelist, or grow a strawberry field. Availability belongs to the component tables above. [Staged manifest](/Users/brendan/Developer/redwall-review/godot/demo/assets/manifest.json).

| Staged asset family | Exact keys | Player-facing status |
|---|---|---|
| Building, storage and enclosure models (14) | `residence`, `hall`, `kitchen`, `well`, `workbench`, `covered_store`, `open_stockpile`, `fence`, `boathouse`, `weir`, `fisher_shelter`, `mill`, `cellar`, `composter` | Visual assets; only the explicitly identified demo actions give them a functioning role. |
| Woodland, rock and ground cover (11) | `oak_mature`, `beech_mature`, `oak_sapling`, `stump_mossy`, `oak_stump_fresh`, `mossy_boulder`, `rock_cluster`, `fallen_log`, `grass_tuft`, `mushroom_cluster`, `reeds` | Visual assets; only the explicitly identified demo actions give them a functioning role. |
| Growing crop representations (15) | `crop_cabbage_ripe`, `crop_grain_ripe`, `crop_roots_ripe`, `plant_turnip`, `plant_radish`, `plant_onion`, `plant_leek`, `plant_carrot`, `plant_peas`, `plant_beetroot`, `plant_celery`, `plant_lettuce`, `plant_oats`, `plant_strawberry`, `plant_barley` | Visual assets; only the explicitly identified demo actions give them a functioning role. |
| Ingredient and food props (18) | `item_turnip`, `item_radish`, `item_beetroot`, `item_onion`, `item_carrot`, `item_peas`, `item_celery`, `item_trout`, `item_barley`, `item_perch`, `item_leek`, `item_lettuce`, `item_oats`, `item_shrimp`, `item_hotroot`, `item_mussels`, `item_eel`, `item_strawberry` | Visual assets; only the explicitly identified demo actions give them a functioning role. |
| Finds and remembered objects (5) | `find_flint`, `find_clay`, `relic_bell`, `relic_key`, `relic_banner` | Visual assets; only the explicitly identified demo actions give them a functioning role. |
| Transport and crossing components (9) | `handcart`, `wheelbarrow`, `boat_rowboat`, `boat_coracle`, `boat_raft`, `jetty`, `bridge_log`, `bridge_plank`, `bridge_pier` | Visual assets; only the explicitly identified demo actions give them a functioning role. |
| Tools, fixtures, containers and workplace props (30) | `barrel`, `crate`, `log_stack`, `water_bucket`, `sack_pile`, `table_stools`, `cauldron_tripod`, `fish_creel`, `mole_pick`, `fishing_rod`, `tunnel_brace`, `gnawed_log`, `tunnel_rubble`, `chopping_block`, `fishing_net`, `sapling_basket`, `sawhorse`, `spade`, `hoe`, `wall_lantern`, `sickle`, `axe`, `clay_jars`, `smoking_rack`, `felled_trunk`, `bed`, `plank_stack`, `pantry_shelf`, `eel_trap`, `basket` | Visual assets; only the explicitly identified demo actions give them a functioning role. |

Cast keys: `mouse_keeper`, `mouse_fieldworker`, `squirrel_gatherer`, `squirrel_forester`, `otter_boatwright`, `otter_fisher`, `mole_digger`, `badger_quarryman`, `beaver_bridgewright`. The species/job tables explain which actions these nine bodies actually support.

<a id="phase2-coverage"></a>

#### B6. Coverage ledger and boundaries

**Coverage means semantic coverage of player-facing systems, not a claim of reading every file line by line.** The combined inventory maps 34 meaningful families and every authored player-facing catalogue, screen family and exposed interaction identified by the researchers. The tracked manifest contains 6,124 paths, including generated, binary, import, validation and source-library material. Those records were not all manually read or visually inspected. The content library’s 7,665 records and 1,755 recipe/serving candidates remain authoring references; they are not activated mechanics. Twelve supplied narratives do not establish complete series coverage: full Eulalia text is absent and Salamandastron has a known gap.

| Coverage layer | What was examined | What that supports and excludes |
|---|---|---|
| Rules and authored design | Repository instructions; relevant GDD, setting/diet/movement, UI, food, underground, family/progression and battle-design sections; delivery task boundaries | Adopted intent and exclusions; not proof every proposal is implemented |
| Runtime ownership and composition | Main/demo scene composition; cast and command interfaces; farm/forest/water/tunnel/spoil controllers; settlement stages; relevant store/API bodies; actual UI registry and availability tables | Live versus kernel versus adopted distinctions; not a fresh correctness audit of every line |
| Exact component catalogues | 61 compiled items; 30 building definitions; nine furniture definitions; sixteen kernel species plus demo beaver; eleven active jobs; 103 UI IDs; staged world/cast metadata | Enumerated player-facing breadth, with per-component purpose and availability; catalog presence is not playable integration |
| Experience evidence | Earlier native Phase 1 observations and the completed inventory → mental journeys → loop map → 34 family assessments → gap analysis → proposals | Design hypotheses tied to evidence; no new native play, listening, battle, large-colony balance or accessibility qualification |
| Source corpus and excluded bulk | Library contracts/indexes and bounded relevant candidates; generated logs, repetitive schema internals, binaries, imports, historical duplicate dossiers and source books not wholly reread | Authoring opportunities and honest limits; no claim of a whole-project byte or line audit |

[Tracked coverage manifest](</Users/brendan/Developer/redwall-review/.review-artifacts/research_notes/Redwall player experience design/tracked_manifest.txt>); [Content-library scope](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/README.md:13); [Activation boundary](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/authoring_handoff.md:7).

<a id="phase2-journeys"></a>

### C. Simulated player journeys across four attention stages

**Time boundary.** The live demo advances one day per minute at 1×, while the adopted settlement calendar is ten real minutes per day at 1×. Both have pause / 1× / 2× / 4×. Accordingly an uninterrupted real hour in the demo can cross more than one 48-day year; the intended kernel calendar advances about six days. Pause, reading and speed changes make wall-clock milestones variable. The labels below describe attention stages, not guaranteed time-to-content. In particular a player cannot experience a real M3/M4 campaign just because the demo date has advanced far enough. [Demo calendar](/Users/brendan/Developer/redwall-review/godot/demo/README.md:64), [intended calendar](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:244).

**Evidence levels used inside every journey:** **Frozen demo** means an action/state found in the frozen inventory (supplemented where applicable by earlier native observations); **adopted design projection** means a mental playthrough assuming the documented release rules were connected; **hybrid-vision hypothesis** means the user’s future cozy settlement plus squad-battle vision, for which the current project has no complete playable design. These are not interchangeable.

##### First five minutes

| Persona | Goals and decisions | Satisfying moments available | Friction, emptiness and likely quit point | Adopted / future experience boundary |
|---|---|---|---|---|
| Cozy builder | **Frozen demo:** orient around hall, homes, fields and stream; select an appealing creature; try a bed and choose a crop that can be sown; inspect whether homes can be changed. Decisions include which bed needs attention, which crop fits its soil/window, where a short tunnel or bridge would feel useful. | A worker visibly pulls/holds/carries a crop; rain changes the atmosphere; different bodies and work props make the place feel inhabited; a short accepted dig leaves an actual passage. These are concrete pleasures already supported by demo actors, farm tasks and excavation. | The authored village looks further along than the player’s agency: many buildings cannot be rearranged or newly placed. Panels require learning several separate systems before there is an obvious personal goal. The player may stop at “it is a lovely scene, but which part is my village to create?” This refers to Phase 1 UI/onboarding issues as context, not new defects. | **Adopted projection:** the player would stabilize a new refuge, designate roots and learn food-days. **Hybrid hypothesis:** a visible promise of future defense may matter, but no battle decision is available now. [Fixed layout](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:48), [bed interactions](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:40), [first teaching goals](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:832). |
| Min-max optimizer | **Frozen demo:** pause, inspect resource accounting and worker abilities, locate highest-value output and likely bottleneck; examine planting windows, soil, water, forestry stock and tunnel distances. Real choices are available in bed treatment and terrain route planning. | Pausing preserves control while inspecting; numerical growth/moisture/fertility and geometric tunnel previews support hypothesis-making; a bridge or bore can visibly shorten movement. | At this point the optimizer may mistake separate displayed populations/stocks for one economy, then discover an action has no visible strategic payoff. The absence of a common demand/production objective is more demotivating than the lack of another statistic. Likely stop: cannot answer “what am I optimizing for?” rather than simply “which button works?” | **Adopted projection:** food-days, reserve policies and a shared labor budget would anchor opening priorities; those are not a completed demo economy. [Demo/kernel boundary](/Users/brendan/Developer/redwall-review/godot/demo/cast/demo_cast.gd:2), [soil water coupling](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_tunnels.gd:1), [daily loop](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:65). |
| Battle-focused player | **Frozen demo:** box-select a mixed group, right-click a destination, test body size and formation placement, look for enemy, muster or attack actions. The meaningful immediate choice is who can use a tunnel/water route, not weapon matchup. | Group movement, large badger versus small digger silhouettes, and crossings suggest spatial tactics. A tunnel bypass or rescue can feel like a small command problem. | There is no opponent, battle objective, attack order, tactical morale or army-building path in the live scene. A player expecting advertised Total War-style play will likely leave as soon as they establish that the dock and controls offer civilian activity only. | **Adopted settlement design:** attacks are deliberately absent, so this is not a defective existing battle. **Hybrid hypothesis:** training and future defense would need to become a player-visible prospect before a battle fan invests in colony management. [Civilian orders](/Users/brendan/Developer/redwall-review/godot/demo/cast/demo_cast.gd:118), [ability list](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:47), [settlement boundary](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:728). |

##### First real hour

| Persona | Goals and decisions | Satisfying moments available | Friction, emptiness and likely quit point | Adopted / future experience boundary |
|---|---|---|---|---|
| Cozy builder | **Frozen demo:** watch several crop cycles/seasons at compressed time, try a cellar or home concept, link places with tunnels/bridge, plant trees and see weather. Choices are local spatial expression and crop aesthetics, with some crop survival tradeoffs. | A small self-authored piece of underground network exists in the same scene as farms and water; harvest shelves and carried ingredients give work a visible destination. Seasonal light/rain makes revisiting the same place pleasant. | The family/community fantasy does not deepen with those cycles: no actual communal meal, visitors, relationships or named personal accomplishment follows the harvest. The fixed surface village and small number of beds constrain expansion. Likely stop after seeing the main motions once: “I collected food, but nobody needed or celebrated it.” | **Adopted projection:** this hour may still be first spring. Setting kitchen targets, a dryer and nets, reaching M1, making a warmth reserve and planning a first feast would occupy it. That path is specified, not currently playable end to end. [Pantry scope](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:1), [food task boundary](/Users/brendan/Developer/redwall-review/docs/tasks/07_food_production_survival.md:18), [intended disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:832). |
| Min-max optimizer | **Frozen demo:** vary crop family/soil treatment, route a bore to drain or water beds, compare log/plank crossings, fell within conservation floors, observe hauling and storage. This player can meaningfully optimize movement and local throughput. | The strongest existing experimentation is a multi-system chain: tree work supplies a crossing; excavation changes farm moisture and generates material; different body fit changes routes. There is a discoverable cause-and-effect toy here. | After a few experiments, food lacks consumer pressure, craft choices have few sustained sinks, expansion is bounded by fixed demo geography/cast, and long-term trade/specialization is absent. Repeatedly optimizing production cannot reveal a richer economic equilibrium. Likely stop when higher yield merely yields more aging inventory instead of unlocking a new decision. | **Adopted projection:** reserves, spoilage, seasonal closures, cooking, worker rest and immigration would expose true bottlenecks. No inference that those balancing decisions have been proven by a live one-hour trace. [Forest rules](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_rules.gd:1), [bridge choices](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/bridges.gd:1), [reserve semantics](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600). |
| Battle-focused player | **Frozen demo:** seek a challenge in fire/flood evacuation, deep-water rescue and rapidly ordering groups through limited openings. Maybe explore rock-breaking or otter dives as unit roles. | Seeing automatic rescue or creatures choose a usable escape route supplies a glimpse of a command-and-consequence game. Distinct mobility can support a tactical imagination. | The threats inflict no loss, auto-wash-ashore eventually returns victims safe, and there is no hostile intention to read or counter. Once the safety demonstration is understood, practicing it has little strategic consequence. Likely stop before an hour unless interested in terrain-engineering toys for their own sake. | **Hybrid hypothesis:** a first small encounter might provide a reason to care about provisions, terrain and squads, but no such encounter should be described as current or already specified. [Nonfatal rescue](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:2), [harmless threats](/Users/brendan/Developer/redwall-review/godot/demo/events/demo_events.gd:2), [battle fixture](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:742). |

##### Mid-game attention stage

There is **no delivered mid-game progression state** to reach in the frozen demo. The “frozen demo” column here describes what a persistent player can continue doing in the existing playground, not a hidden campaign stage. [Absent progression caller](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:168).

| Persona | Goals and decisions | Satisfying moments / projected strengths | Friction and likely quit point | Explicit projection boundary |
|---|---|---|---|---|
| Cozy builder | **Frozen demo:** refine a self-imposed layout of bores, crossings, woods and crops. **Adopted projection:** build a larger community, place homes and common spaces, admit residents, establish a seasonal feast and remember notable lives. | Growth from refuge to a personally arranged neighborhood could make every new warm bed and visitor meaningful; orchard maturation, home identity and a recurring feast could reward care over time. These are potential satisfactions grounded in the intended systems, not observed current play. | Current surface construction and community events do not supply that stage. In the adopted design, repeated survival chores and population thresholds could turn the cozy builder’s desired scale/style into a compliance task. A plausible quit point is feeling forced to grow to 48/80 residents to unlock cherished orchard/feast content despite preferring a small settlement. | Fixed-population thresholds are actual specifications; the emotional reaction is a playtest hypothesis. Underground homes/cellars are evaluated as design promise only while phase 3 is rebuilt. [M2/M3 gates](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:795), [home direction](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:57), [social culture](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:539). |
| Min-max optimizer | **Frozen demo:** exhaust route/soil combinations and push local stores, then lack a larger target. **Adopted projection:** plan winter food, skill development, tool maintenance, storage geography, master recipes and admission. | Seasonal production constraints, habitat closures, quality/variety, bounded pollination and worker needs could produce a rich portfolio-management problem with several viable source mixes. Improving a town’s resilience could become a satisfying measurable accomplishment. | Adopted milestone gates couple many accomplishments into a single next step. The optimizer may stockpile for a threshold, wait for a year/winter condition, or mass-produce a recipe for mastery rather than make a novel decision. The risk is an idle waiting phase or checklist optimization after the useful system is solved. | No multiyear balance run or strategic viability was established; this is pressure-testing the specified goals. [Maturation/mastery](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:574), [winter causal model](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:776), [progression package scope](/Users/brendan/Developer/redwall-review/docs/planning/progression_execution_package.md:174). |
| Battle-focused player | **Frozen demo:** no new military loop appears. **Hybrid-vision hypothesis:** staff an economy while choosing a field force, scouting threats and preparing a terrain plan; decide who stays home and what provisions to take. | The appealing promise is that the squad’s equipment, meals, leadership and rescue capacity came from a community the player knows. Terrain and body scale could give route-building a military meaning beyond generic attack orders. | Current battle architecture gives formations, weapons and morale fixtures, but not recruitment, mission sequencing, a strategic enemy or home consequences. An extended colony opening with no visible military decision risks losing this player before the hybrid loop begins. | This row intentionally cannot forecast battle balance or mission fun: no playable roster/opponent/campaign exists. [Battle formation fixture](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:677), [morale fixture](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:773), [future transfer](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:899). |

##### Late-game attention stage

| Persona | Goals and decisions | Satisfying moments / projected strengths | Friction and likely quit point | Explicit projection boundary |
|---|---|---|---|---|
| Cozy builder | **Frozen demo:** continue a self-imposed diorama project with fixed cast and limited surface expression. **Adopted projection:** finish a distinctive settlement, hold a Charter ceremony, preserve memories, and continue freely. | A community-written Charter and warm daily-life spectacle could make completion feel personal; a town’s physical history could be the reward rather than another stat tier. | The specification’s year 3 / 120 population / 18 winter-day reserves / 8 specialists / 10 recipes / 12 feasts demands can dominate a player who values beauty and belonging over large optimization. Once achieved there is no authored infinite progression. Likely quit is not necessarily failure: a satisfied player can finish, but a chore list could sour the final stretch before the emotional reward. | The Charter’s civic meaning is adopted; its final ceremony/material/emblem remain authoring work. This is not a criticism of an implemented victory screen. [Charter meaning](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:937), [end condition](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:801), [no infinite track](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:834). |
| Min-max optimizer | **Adopted projection:** sustain reliable reserves and specialists through the exact winter observation interval, then push 200–256 residents and resilient efficiency. Decisions should revolve around spare capacity, recovery and alternate economic arrangements. | The condition can reward designing slack rather than simply maximizing output. Several years of land stewardship and trained cooks/tenders could give the town a strong economic identity. | A long continuous all-conditions requirement risks checking every number for a single tick of failure. Late content may collapse into maintaining solved targets because no new regional demand or alternative specialization challenge is currently defined. Likely quit after solving the throughput bottleneck, or after missing an opaque maintenance threshold despite feeling successful. | Continuous54,000-tick interval is specified/tested only as a helper; player-facing feedback and real feasibility are not delivered. [Exact interval](/Users/brendan/Developer/redwall-review/docs/planning/progression_execution_package.md:9), [continued optimization](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:92). |
| Battle-focused player | **Hybrid-vision hypothesis:** lead experienced squads through consequential engagements, choose whether to risk treasured captains, heal/rebuild, resolve antagonist arcs, then enjoy a changed settlement. | A victory dinner for returned squads, a memorial for losses, a saved ally or opened route could make the army feel rooted in this game’s community identity. | The current project contains no campaign pacing, replenishment economy, hero arc, battle result transfer or persistent adversary response to assess. Potential failure modes therefore remain hypotheses: repeated disposable battles, irrelevant homebuilding, or oppressive attacks that destroy cozy agency. | These are not missing required settlement release 1 features falsely counted as existing bugs. They are gaps against the user’s newly reiterated full-game vision. [Future conflict scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:621), [return-state contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:905). |

The three motivations overlap: a bore is a personal place for the cozy builder, a labor/water intervention for the optimizer, and a possible future maneuver route for the battle player. Today the same route can satisfy curiosity without delivering any campaign. The distinction matters when describing the product: elapsed demo years do not create a mid-game, and a satisfied short building session is a valid outcome rather than evidence of a complete career.

##### A plausible successful session, with an explicit stopping point

**Frozen-demo successful trajectory, mentally simulated:**

1. Pause and choose a concrete place to improve: one crop bed plus its approach from a work area. Select a creature whose work capabilities suit the task. The player needs only a local goal rather than an imaginary campaign. [Abilities](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:47).
2. Inspect soil/moisture and choose an in-season crop. Sow, resume briefly, and watch a visible worker perform the action. Inspect the changing stage rather than infer growth from a resource counter. [Farm inspector/actions](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:40).
3. Try one useful connecting intervention: a dry bore under a wet bed, or a bank-connected network where water supply matters. This creates an observable reason for excavation in the same area. The exact safe route is site-dependent; this is not an assertion that every possible line irrigates or drains. [Water-network contact](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_tunnels.gd:1).
4. Clear/reuse the resulting spoil and watch the route become navigable; inspect what material/work the experiment required. Continue until a harvest is carried to visible storage. [Spoil actions](/Users/brendan/Developer/redwall-review/godot/demo/spoil/spoil_crew.gd:1), [pantry lots](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:1).
5. End on a small created place—crop, path connection, worked landscape and moving worker—with a screenshot-worthy result. This is a legitimate successful toy session, not a failed version of an unavailable campaign.

**Projected adopted-design continuation:** turn that harvest into a chosen meal, feed the people who built the route, host a modest occasion, and use remaining reserves to decide whether to admit a new household or invest in preservation. This sequence is grounded in documented food/feast/admission rules, but requires production, personal consumption, attendance and arrival integration absent from the frozen demo. It cannot be claimed to occur today. [Food milestone](/Users/brendan/Developer/redwall-review/docs/tasks/07_food_production_survival.md:18), [community milestone](/Users/brendan/Developer/redwall-review/docs/tasks/08_community_scenarios_progression.md:25).

**Projected hybrid continuation:** the improved route and food reserves later support an expedition or defensive squad, with consequences returning to the settlement. Only transfer concepts and tactical fixtures exist; no current mission makes this last step playable. [Transfer scope](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:899).

<a id="phase2-loops"></a>

### D. Core loops, missing connections and information ownership

**Edge labels:** `LIVE` = a playable demo action/state change; `KERNEL` = implemented rule/store, disconnected from this complete player path; `ADOPTED` = documented behavior whose integrated loop is incomplete; `VISION` = user-requested future colony+squad RTS direction, not an already adopted implementation plan. An arrow means causal connection, not that every intermediate technical defect has been resolved. Existing Phase 1 findings remain separate.

##### Current moment-to-moment loop

```text
[LIVE] Look at world / inspect actor or site / pause
   → [LIVE] Choose eligible actor, local action or route
   → [LIVE] Preview / accept or receive refusal
   → [LIVE] Travel → work / carry / cross
   → [LIVE] Visible state change, progress, stock or notice
   → [LIVE] Reinspect / choose next intervention

Feedback returns to local choice.
It does not yet return through a complete needs → productive community → growth loop.
```

The input path is in camera/control/domain tools; the crew controllers create visible labor; state feedback appears in beds, tree falls, shelves, bridge phases, tunnel geometry, particles and inspectors. Pause leaves inspection/orders available, so the player can alternate deliberate planning and observation. [Control path](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:377), [farm labor](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_crew.gd:1), [bridge lifecycle](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/bridges.gd:1), [time behavior](/Users/brendan/Developer/redwall-review/godot/demo/README.md:57).

##### Current session loop and source/sink ledger

| Local loop | Sources → transformations → sinks | Feedback/payoff available | Where the larger loop stops |
|---|---|---|---|
| Crops | LIVE unlimited demo seed → sow/tend + soil/weather time → named ingredient harvest → carried pantry lot → effective aging → spoiled stock → compost → fertility | Growth appearance, carrying, full shelves, higher/lower later yield; a partial material-reuse feedback loop | No delivered eating/cooking/feast sink for those named demo lots. More stock is chiefly more storage/expiry exposure, not more fed residents or new community capability. [Farm model](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:39), [Pantry](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:1), [candidate recipes](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_recipes.gd:1) |
| Woodland/building material | LIVE mature trees/deadfall → fell/gather → trunk/load → wood stack → saw planks → bridge or tunnel fixtures; retained stump/replant +48 days → tree | Visible changing woods and crafted infrastructure; infrastructure can shorten later work journeys | There is no complete expanding surface town, household heat or equipment-maintenance economy to sustain diverse ongoing demand. Finite improvements consume initial stock, then the incentive diminishes. [Forestry](/Users/brendan/Developer/redwall-review/godot/demo/README.md:403), [shared stocks](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:1) |
| Earthworks/farm water | LIVE dig labor + route choice → persistent passages + heaps → drain/irrigate beds or raise/bank them → altered crop growth; clear heaps → compost store | One action changes access, landscape obstruction and farming conditions; choices are genuinely connected | Demo spoil-as-compost is not the adopted production material loop. The real `excavated_earth` item has no fertilizer benefit; planned backfill/tip/reclaim economics are ADOPTED, not current equivalents. [Farm water](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_tunnels.gd:1), [earth identity](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:50) |
| Tunnel investment | LIVE excavation → standard bore → optional widen/brace/light → different usable bodies/loads, faster or weather-sheltered travel; strain/seep → warning → repair | Authored space, body-scale choice, route use, light, local hazard prevention | Benefits have limited repeat demand because the full household/production logistics layer is absent; relics end in a tally/story and no follow-up pursuit. Standard/wide choice is real; this is not a tactical flank yet. [Network and costs](/Users/brendan/Developer/redwall-review/docs/decisions/0208-the-tunnels-are-one-network-graph.md:72), [finds](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_finds.gd:1) |
| Water crossing | LIVE ford/swim detour or plank/log investment → completed crossing → usable loaded/large-body route → shorter future work trips | A visually legible infrastructure payoff; material and path decisions meet | No cargo ferry/boat route economy or multiple-settlement demand; decorative vessels are not alternate functioning transport methods. [Bridges](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/bridges.gd:1), [water dressing](/Users/brendan/Developer/redwall-review/godot/demo/water/water_dressing.gd:1) |
| Swim/dive/rescue | LIVE swimming spends stamina / diving spends air → bank return or difficulty → automatic tow/line/wash-ashore → rest → available actor; a dive may return a small find | Bodily variety, bubbles/ripples, a small rescue story and clear recovery cycle | Nonfatal demo safety means no persistent treatment, community memory or tactical consequence closes the experience. SOC owns the prospective medical/story connection. [Dive](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/dive_task.gd:1), [rescue](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:2) |
| Fish ecology | KERNEL seasonal recovery/closures/quota → legal catch calculation; demo displays stock/site state and returns API catch lots | Ecological model and informational change | No playable fish→haul→kitchen/pantry cycle. The fishery's internal recovery is a simulation loop, not a completed fishing-player loop. [Driver contract](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:1) |
| Skill | LIVE productive digging/felling/sawing → XP → faster work → more completed work | A visible progress number with practical local effect | Broad specialist identity, mentorship, quality, earned notability and succession remain KERNEL/ADOPTED. [Digging skill](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/dig_skills.gd:1), [forestry skill](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_skills.gd:1) |
| Weather/emergency | LIVE calendar → weather/soil/mobility change → local mitigation; demo fire/flood → evacuation/shelter → return | Mood/atmosphere and a reason to revise a local plan | No actual loss/repair/care/community aftermath from harmless demo threat discs; elapsed seasons do not award progression. [Weather](/Users/brendan/Developer/redwall-review/godot/demo/weather/demo_weather.gd:1), [events](/Users/brendan/Developer/redwall-review/godot/demo/events/demo_events.gd:2) |

**Current long-term loop:** revisit a self-authored place, maintain crops/woods, extend local infrastructure and try another experiment. There is no earned demo milestone career, active immigration, playable battle, authored antagonist response or Charter ending to close a longer arc. This is a scope boundary, not a newly discovered crash/logic defect. [Progression/caller boundary](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:168), [retired combat helper](/Users/brendan/Developer/redwall-review/godot/scripts/legacy_battle/combat_system.gd:2).

The current emotional feedback is strongest when **a place changes and creatures use it**. The harvest-to-compost cycle is mechanically circular but emotionally incomplete until useful food supports real people. Infrastructure demand is front-loaded: a bridge gains meaning from repeated travel, and that demand stops growing when the cast and destinations remain fixed.

##### The adopted settlement loop and its changing bottlenecks

```text
ADOPTED SETTLEMENT LOOP — integrated execution incomplete

Landscape/season [KERNEL rules]
  → harvest/fish/forage work [KERNEL planning + missing completion]
  → physical lots/haul/store [KERNEL inventory + missing connected logistics]
  → cooking/preservation [ADOPTED]
  → meals/heat/rest/care [ADOPTED services; KERNEL need arithmetic]
  → capable, content workers [KERNEL rates; missing complete lived loop]
  → harvest/build/craft/service capacity [ADOPTED integration]
  ↺ needs consume supplies again

Surplus → reserve decision → feast/hospitality [ADOPTED]
  → community benefit/reputation → immigration [ADOPTED]
  → more labor AND more food/bed/heat/care demand → rebalance production

Season forecast → source portfolio/seed and fuel reserves → winter pressure
  → recovery and retained soil/skill/community history → next season

Repeated competence + population/time/recipe/feast conditions
  → M1/M2/M3 catalog expansion → new choices → Charter/continue [ADOPTED]
```

The diagram preserves boundaries: a 61-item compiled catalog is not proof of 61 delivered chains; demo-named vegetables/planks/finds are separate identities. Food excludes hunting, dairy and livestock production under current rules. [Compiled resources](/Users/brendan/Developer/redwall-review/godot/data/item_definitions.json:4), [diet/material boundary](/Users/brendan/Developer/redwall-review/docs/setting_rules_amendment.md:20).

| Cadence | Player decision and changing bottleneck | Intended payoff / pressure | Availability and specific stall risk |
|---|---|---|---|
| Every local problem | Which priority/policy to change, who can safely reach/work, whether to interrupt a job | A small intervention restores a causal chain; autonomy handles routine repeats | KERNEL selection is not full travel/service completion; absent common job/production surfaces prevent observing this as one chain. [Planner](/Users/brendan/Developer/redwall-review/godot/scripts/core/job_planner.gd:1), [runtime stages](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:1631) |
| Daily | Maintain meal/gear stocks, manage work/rest/social time, tend crops/hives, haul to correct stores | Need satisfaction supplies productive labor; task choice shifts as urgency changes | ADOPTED service loop. Without consumer work/haul clocks, isolated rates cannot establish the balance of productive versus support labor. [Needs/jobs](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:296), [food task](/Users/brendan/Developer/redwall-review/docs/tasks/07_food_production_survival.md:18) |
| Seasonal | Crop/forage/fish mix, closures, seed reserve, preserved vs fresh food, heat/fuel, event mitigation | Different resources become limiting across spring labor, summer spoilage/dryness, autumn harvest and winter survival | KERNEL ecology/weather exists; integrated reserve decisions incomplete. Forecast must cover compound labor demand, not imply stock alone guarantees readiness. [Season rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:732), [reserve rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600) |
| Growth event | Admit residents versus reserve/bed/care headroom; specialize or retain fallback labor | More skills/capacity and a livelier community in exchange for durable obligations | ADOPTED arrival/reputation loop; current kernel lacks a working candidate/lifecycle stage. Population thresholds also make expansion a gate to new production toys. [Immigration and milestones](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:778) |
| Investment horizon | Tools, supported routes, specialized stores, rooms, orchard/hive placement | Travel/work savings, food longevity, warmer lives and future harvest | Core stores or ADOPTED design, not a proven economic return. Homes/cellars are discussed at design level only. [Building services](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:627), [underground living direction](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:57) |
| Multiple years | Recipe mastery, specialists, feasts, reserve resilience and Charter | Community accomplishment, then free continued settlement | ADOPTED sustained checklist; continuous conditions and calendar thresholds can create waiting after production is solved. No infinite unlock track is promised. [Milestones/disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:792) |

##### Progression bottlenecks and timing discontinuities

- **M1 combines calendar/population with 200 prepared portions.** Before it, the player must repeat the starter cooking repertoire; after it, many stations/recipes/services open at once. The contract therefore contains both a possible repetition interval and an information spike; neither has been playtested here. [Milestone table](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:795).
- **M2 bundles population 48, surviving first winter and three mastered recipes.** The first satisfied conditions do not award partial economic access. Small-community preference, winter wait or repeated GOOD/EXCELLENT production can each become the controlling gate. [Milestone/mastery rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:795), [mastery](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:574).
- **M3 gates orchards behind population 80, year 2 and eight food-days; then apple/pear maturation adds 96/144 days.** Those are two/three 48-day years of further care before the next legal autumn harvest. Thus long-investment fruit can arrive after the earliest possible year-3 Charter eligibility. This is an arithmetic timing observation, not proof any player can meet M3 at the earliest date or win in year 3. [Orchard timing](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:477), [M3/M4](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:795).
- **M4 combines current reserves/people/mood/heat with monotonic accomplishments and an exact continuous three-winter-day window.** Once the supply model is solved, attention can shift from interesting planning to watching every condition stay true. Conversely, a bad winter can make the whole improvement portfolio matter. Which experience dominates requires a connected prototype. [Continuous interval](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:801).
- **Ecological restraint is intended to close the extraction loop.** Depleted fish/forage stock, closures, rotation and retained trees create future consequences; the intended decision is source mix and timing, rather than endlessly adding workers. Current live forestry exposes some of that, while fish/forage remain incomplete player loops. [Fish quotas](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:376), [forage](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:427), [forestry floor](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_zones.gd:1).

The intended bottleneck progression is **source eligibility → seasonal labor → hauling/space → processing capacity → warmth/care → community growth → resilience and meaning**. The source inventory supports that intention; disconnected execution cannot demonstrate the balance. A good prototype must show the limiting decision changing as the player improves the village, rather than merely adding more maintenance obligations.

##### The future colony and squad loop

```text
USER VISION — causal map, not an approved implementation design

Civilian landscape/work/food/culture [ADOPTED settlement]
  → available supplies, skilled people and reasons to protect a place [VISION]
  → muster/equip/provision/scout [VISION; no delivered army producer]
  → squad orders, terrain, formation/cohesion/morale [tactical specification fixture]
  → mission outcome, losses/injuries, recovered people/knowledge/access [VISION]
  → return/medical care/remembrance/celebration/changed outside relations [VISION]
  → changed settlement demand, identity and next strategic choice [VISION]
  ↺ civilian life continues
```

| Connection | Present basis | Missing closure against the requested vision |
|---|---|---|
| Food → expedition | Rations and reserve accounting are specified; transfer concepts preserve supplies | No recruitment/muster or departing-force consumer, travel duration demand or mission supply policy. [Ration recipe](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:549), [future transfer direction](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:899) |
| Infrastructure → tactics | Actual demo passages/crossings; squad formation/terrain architecture fixture | No shared authored encounter where choosing a route changes a battle; bridge/tunnel payoff is currently civilian only. [Tunnel network](/Users/brendan/Developer/redwall-review/docs/decisions/0208-the-tunnels-are-one-network-graph.md:72), [formations](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:677) |
| Labor → army | Persistent ordinary residents, skills, named-notable concept | No enlistment/training/rotation/replenishment policy and no demonstrated choice between service at home and field deployment. [Identity/work](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:335), [military boundary](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:621) |
| Battle → community | Settlement care/grief/memorial/feast direction, future persistent identity | No live battle results causing home absence, healing labor, a shared celebration, memory or changed relationships. [Care/social rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:296), [story/community task](/Users/brendan/Developer/redwall-review/docs/tasks/08_community_scenarios_progression.md:25) |
| Surplus → wider purpose | Recipes/skills/Charter and world/story source library | No functioning trade, diplomacy, neighboring requests, campaign map or antagonist response that gives surplus a new context. [Outside-world boundary](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:621), [Charter](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:937) |

A battle scene alone does not close this loop. The resident or allied company must have a source, departure must remove real capacity or supplies, and return must create care, relief, remembrance or changed access. The first hybrid prototype should demonstrate this round trip before a large campaign map is justified. The army population model and chapter-versus-parallel clock remain explicit decisions.

<a id="phase2-gaps"></a>

#### D1. Gap matrix: where a promise still lacks a decision

These are design gaps after the family assessments, not new counted bugs. They identify the connective experience a proposal must deliver. A source kernel or content list is a useful prerequisite; neither establishes a satisfying player loop.

| Existing promise | Missing player-facing bridge, beyond Phase 1 integration | Why its absence matters | Related proposals |
|---|---|---|---|
| Sixteen crop identities and seasonal windows | A small set of distinct harvest/use profiles and a reason to choose between siblings | Names suggest agency before the economy rewards it | [ECO-001](/Users/brendan/Developer/redwall-review/REVIEW.md:2180)–[ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250) |
| Persistent soil and weather response | A readable choice between restoration, adaptation and infrastructure | Gardening becomes modifier repair | [ECO-005](/Users/brendan/Developer/redwall-review/REVIEW.md:2293)–[ECO-007](/Users/brendan/Developer/redwall-review/REVIEW.md:2339) |
| Multi-year fruit trees and honey/wax | Intermediate rewards, nursery choice and competing uses for the annual yield | A large commitment can feel empty until years later | [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380)–[ECO-012](/Users/brendan/Developer/redwall-review/REVIEW.md:2474) |
| Seasonal woodland foods and protected areas | Habitat-specific purposes and a reason to retain places | Foraging becomes obsolete; conservation only withholds food | [ECO-013](/Users/brendan/Developer/redwall-review/REVIEW.md:2515)–[ECO-018](/Users/brendan/Developer/redwall-review/REVIEW.md:2652) |
| Craft recipes and worn equipment | Serviceable equipment packages and an intelligible repair/replacement decision | More products would create stock clutter without interesting use | [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693)–[ECO-022](/Users/brendan/Developer/redwall-review/REVIEW.md:2765) |
| Several fishery methods and ecological stock | Distinct expedition rhythms and collection/reserve decisions | Methods read like increasingly large yield buttons | [ECO-023](/Users/brendan/Developer/redwall-review/REVIEW.md:2806)–[ECO-026](/Users/brendan/Developer/redwall-review/REVIEW.md:2876) |
| Recipe quality, preparation and shelf life | Menus, lawful substitution, timed processing and separate reserve/celebration demand | Food remains an anonymous fuel total even after P3 | [ECO-027](/Users/brendan/Developer/redwall-review/REVIEW.md:2917)–[ECO-031](/Users/brendan/Developer/redwall-review/REVIEW.md:3013) |
| Lots, physical travel and local storage | Limited local buffers, protected reserve purposes and simple transport policies | A stock-rich village can feel mysteriously poor | [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056)–[ECO-035](/Users/brendan/Developer/redwall-review/REVIEW.md:3126) |
| Forecasts and season changes | Calm periods earned by preparation and useful seasonal opportunities | Constant emergency response undermines the cozy half | [ECO-036](/Users/brendan/Developer/redwall-review/REVIEW.md:3167)–[ECO-038](/Users/brendan/Developer/redwall-review/REVIEW.md:3213) |
| Bridges, body/load profiles and canopy direction | Everyday access goals and equivalent safe participation | Mobility looks impressive but does not change a chosen way of life | [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256)–[ECO-042](/Users/brendan/Developer/redwall-review/REVIEW.md:3328) |
| Persistent connected underground space | Frequent useful endpoints, discoverable choices and meaningful upgrades | Digging becomes an expensive line-drawing hobby | [ECO-043](/Users/brendan/Developer/redwall-review/REVIEW.md:3371)–[ECO-046](/Users/brendan/Developer/redwall-review/REVIEW.md:3443) |
| Earth conservation and tips | Project-level material destinations and optional surface value | Spoil handling is a chore attached to every fun dig | [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484)–[ECO-049](/Users/brendan/Developer/redwall-review/REVIEW.md:3532) |
| Warm homes and cool cellars | Everyday occupation, furnishing expression and complementary storage purpose | Beautiful rooms risk becoming passive counters | [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575)–[ECO-052](/Users/brendan/Developer/redwall-review/REVIEW.md:3623) |

| Gap | Current evidence / availability | Player consequence | Proposal family and prerequisites |
|---|---|---|---|
| Community-scale control with personal significance | Persistent identities, priorities and notability are separate pieces. [Identity](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:370) | Either workers feel interchangeable or every citizen demands attention. | SOC01–02; integrated work and identity first. |
| Lived daily service | Need arithmetic exists; complete meals/rest/social service does not. [Need sources](/Users/brendan/Developer/redwall-review/godot/scripts/core/needs.gd:82) | Production has no visible human payoff. | SOC03; ECO owns physical food and housing service foundations. |
| Household/community care | Proposed contracts; no active household life. [Family package](/Users/brendan/Developer/redwall-review/docs/planning/family_execution_package.md:1) | A settlement lacks generations and care even without simulating births. | SOC04; fixed-stage family package and safe service routes. |
| Civic institutions | Affinity and Warden intent exist; council/custom mechanisms do not. [Social specification](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:353) | Social life remains numeric and leadership cosmetic. | SOC05; relationship and service events. |
| Emergency aftermath | Demo rescue is nonfatal and returns actors to routine. [Rescue](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:281) | Heroism and preparedness have little persistent meaning. | SOC06; explicit danger contract, care and history. |
| Welcome/integration | Admission formula exists without arrival play. [Immigration](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780) | Growth cannot feel like joining a community. | SOC07; food/bed/care forecast, then visitor identity. |
| Celebrations with content | Menus and coverage are specified; no authored occasion loop. [Feasts](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:578) | Deep food production has no signature social destination. | SOC08; ECO cuisine plus seating/service, SOC history. |
| Usable lore and fair riddles | Source corpus is offline, not runtime content. [Handoff](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/authoring_handoff.md:7) | Setting richness is unavailable to ordinary play. | SOC09; content activation, discoverable landmarks and contextual records. |
| Different starts, competence-based access, recovery | Progression helpers do not constitute a played career. [Progression boundary](/Users/brendan/Developer/redwall-review/docs/planning/progression_execution_package.md:174) | The current demo has a ceiling; the adopted career may over-rely on growth/time. | SOC10; connected settlement before multi-year balance claims. |
| Army lifecycle and tactical purpose | Formation/morale fixture; no playable squads or recruitment. [Battle scope](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:27) | The battle-focused persona has no current game to engage. | SOC11; bounded standalone tactical prototype, then home integration. |
| Regional consequence and shared time | Future transfers have no consumer or selected clock contract. [Transfer](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:899) | Future battles risk feeling separate from home or punishing it invisibly. | SOC12; mission clock, roster ownership, returns, authored neighbors. |

<a id="phase2-information"></a>

#### D2. Six information homes support one working village

| Home | The question it owns | Primary information/actions | Entry, scope and links |
|---|---|---|---|
| At-a-glance HUD | Is attention needed now? | Time/pause, food/fuel reserve outlook, people needing help, current tool, up to three pinned intentions, highest-priority incident. | Click any summary to its owner below. Do not put recipe libraries, all resident stats or detailed forecasts here. |
| Stores | What do we have, where is it, and what will consume it? | Stock by item/location/freshness, available versus committed, daily inflow/outflow, target reserve, predicted shortfall; batch policy tools. | Resource tray or selected shelf; settlement/district scope. Links to Work producer, Community consumer, Plan reservation, Almanac use. |
| Work | What is the community trying to accomplish, and why is it delayed? | Anonymous workforce by profession/crew, project queues, seasonal work pressure, assignments/availability, blocked causes, temporary interventions, saved policy presets. | Job/worker/site inspector or alert. Aggregate default; individual view for a named hero, specialist choice or exception. |
| Build & Plans | How will the village change? | Build catalogue, draft plans, project phases, future resource/work commitments, circulation, renovate/reclaim, saved layouts. | Build tool or project marker. Compare two drafts before commitment; links to Stores reserve and map access. |
| Community | How are people living together? | Need distributions, warm beds/households, health/care, visitors, named people, festivities and civic choices. | People summary or household/hero inspector. Anonymous population appears as cohorts and distributions; named stories retain identity. |
| Chronicle | What happened, and what did I decide? | Incident history, player notes, completed projects, notable lives/visits/feasts, seasonal review. | Notice or return journal. Active incidents remain actionable; archives do not keep firing alerts. Links back to surviving places/people. |
| Almanac & Goals | What is possible, how does it work, and what am I pursuing? | Searchable mechanics/recipes/uses, discovered lore, lessons, personal projects, adopted milestone/Charter requirements. | Help link from any object, objective pin or discovery. Requirements are distinct from optional goals and undiscovered lore. |
| Defense & Company — future | What can I commit, and what remains safe at home? | Squad readiness, supplies, leaders, training, muster, scouting/mission brief, return care needs. | Appears when an actual military loop exists; no permanent dead dock icon today. Links to Work labor withdrawal, Stores provisions, Community recovery, Chronicle outcomes. |
| Context inspector | What is this object doing right now? | Identity/status; current work or occupants; three to five relevant actions; top cause, route and recent change; open owner/compare/follow. | Selection opens it without discarding the strategic screen. Back restores previous scroll, scope and camera. Crosslinks must not erase a draft. |

This proposes six strategic management homes for the connected settlement, with Defense & Company as a future seventh. The HUD and context inspector are separate supporting surfaces, not extra management tabs. The six homes can be tabs in one workspace; they are not six modal windows to open during every task. A compact default view should expose a summary and exceptions; details expand by intent. Name choices can change in usability tests; ownership should remain stable.

##### The connected workflows these homes must support

1. **Delegation:** establish a work policy or crew, see current/next/blocked work, intervene briefly, then release it to community routines. It depends on genuine staffing and durable jobs; the interface is not their substitute.
2. **Comparison:** compare two production or layout interventions under the same horizon and assumptions. Forecast ranges must identify uncertain weather and missing inputs. This depends on production/consumption truth from ECO, not extrapolation from decorative animation.
3. **Construction ownership:** sketch a desired place, check circulation and commitments, fund a phase, watch it happen, renovate later. The kernel alone does not deliver this player flow.
4. **Causal explanation:** ask “why?” from a symptom; see a short chain of actual causes; go to an actionable remedy; return without losing context. It should not recommend infeasible actions merely because a recipe exists in a library.
5. **Learning by success and recovery:** serve a first real meal, handle an understandable setback, and repeat the lesson in a different layout. A mouse tutorial or text-only objective cannot close the missing food/community loop.
6. **Return and reflection:** resume a saved village paused, recover intentions and changes, choose the next meaningful project. This depends on end-to-end persistence and must never claim the simulation ran while closed unless that policy is explicitly chosen.
7. **Lived presentation:** material and place identity, purposeful work staging, season-responsive use of space, and sound that follows actual activity. Existing contact/occlusion/audio integration defects remain Phase 1 prerequisites.
8. **Future hybrid transition:** planning/muster should reveal home costs before departure and consequential care after return. Tactical UI should reuse navigation conventions without flooding the peaceful settlement HUD with combat state.

<a id="phase2-proposals"></a>

### E. Design feedback by all 34 system families

Each family is assessed through **feel, depth, expression, interconnection, progression, readability, theme and researched comparisons** before its individual proposals. The 129 items are alternatives and related layers of a coherent design, not 129 independent development commitments. The 84 reviewable plans retain prerequisites, two to four bounded slices, a minimum useful prototype, player acceptance criteria and a recommended scope tradeoff. An item sized M after a prerequisite does not make the absent underlying economy, service or military loop inexpensive.

**Priority vocabulary:** Now establishes a governing design choice or the first useful prototype; Next deepens the connected core; Later depends on a stable career or military loop; Stretch is optional scope beyond that. “Now” on a future military policy means decide it early, not claim its gameplay already exists. All acceptance targets are proposed tests. Source-backed comparison facts are compactly documented in the shared research ledger; every proposed Redwall mechanic and criticism is this review’s interpretation.

**Ownership prevents double-counting.** For example, [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749) defines the crew commitment; [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906) defines how the player gives that intent; [UX-007](/Users/brendan/Developer/redwall-review/REVIEW.md:5061) edits policies at scale. [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080) defines reserve precedence; [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037) compares its consequences. [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965) defines menu demand; [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834) defines the lived service and [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281) the special occasion; [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614) makes their real outcomes visible. Those are separate decisions with explicit dependencies. Their foundational bugs and basic integration remain in Phase 1.

<a id="eco-f01"></a>

#### ECO-F01 — Field crops and cultivation

Current grounding: [demo crop identities](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_catalog.gd:17), [seed boundary](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:39), [production fields](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:457).

| Lens | Assessment |
|---|---|
| Feel | Visible sowing, tending and carrying make hands-on work tangible; six fixed beds limit ownership of the farm. |
| Depth | Four numerical crop families support some agronomic choices; sixteen names have much less implemented culinary differentiation. |
| Expression | Players choose ingredients, but cannot yet compose a productive field layout or a village food identity. |
| Interconnection | Soil/weather/storage join locally; seed renewal and consumption do not close the demo loop. |
| Progression | Kernel rotation and seed policy provide a foundation; repeated clicking is not itself growing mastery. |
| Readability | Ingredient names imply distinctions that the current family arithmetic does not provide. |
| Theme | Kitchen gardens can be a defining abbey activity if crop choice relates to meals and the season. |
| Benchmark | Researched: [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/farming/), [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements). **Pitfall / transfer limit:** every named vegetable becoming a slightly different spreadsheet row with one best answer. |

**Related owners:** [ECO-027](/Users/brendan/Developer/redwall-review/REVIEW.md:2917), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795), [UX-008](/Users/brendan/Developer/redwall-review/REVIEW.md:5085).

<a id="eco-001"></a>

##### ECO-001 — Crop roles with clear uses

**Type:** Change.

**Current state:** Sixteen ingredients share four agronomic rows; [farm_catalog.gd:17](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_catalog.gd:17).

**Player problem:** “I can choose a carrot, but I cannot explain why I would choose it.”

**Recommendation:** Start with six role profiles across the existing ingredient set: quick fresh crop, reliable staple, long-storing root, rotation restorative, flour crop and fiber crop. Give each at most two consequential differences—harvest timing, storage, labor or recipe use. For example, radish can become a short fresh-harvest option while a parsnip profile invests longer for winter storage. Keep sibling ingredients explicitly equivalent until approved culinary use distinguishes them. Test 15–25% differences, not tiny hidden bonuses.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/farming/): rotation and harvest labor; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations.

**Connects to:** Menu demand, seasonal work, storage, flax crafts. Related designs: [ECO-027](/Users/brendan/Developer/redwall-review/REVIEW.md:2917), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795), [UX-008](/Users/brendan/Developer/redwall-review/REVIEW.md:5085).

**Impact:** High.

**Effort:** M, after P3 approved ingredient mapping; L if including the missing economy.

**Priority:** Now.

**Plan:** **Prerequisites:** working meals/reserves and a declared crop-content owner. **Implementation slices:** select six roles; prototype three contrasting crops; show two traits in the picker; tune a two-season scenario. **Minimum useful prototype:** one fresh crop, one storage crop and beans. **Player acceptance criteria:** unfamiliar players can justify two viable planting plans and no single crop dominates food, labor and longevity. **Recommended direction / tradeoff:** Recommend role-based profiles over unique arithmetic for every name; retain cosmetic variety honestly.

<a id="eco-002"></a>

##### ECO-002 — Protected seed and recovery

**Type:** Extension.

**Current state:** Demo seeds are unlimited; seed separation/reservation exists in adopted farming, [farm_sim.gd:39](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:39), [GDD:457](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:457).

**Player problem:** Harvest has no visible “keep enough to grow again” decision; a later strict seed economy could instead create a hidden dead end.

**Recommendation:** Reserve the next sowing plan's seed automatically. When more seed must be separated, show the raw-harvest opportunity cost and offer “expand next season” or “feed now” for that raw harvest only; seed items remain protected and inedible. Use the existing once-per-year relief pouch, requested explicitly and arriving next dawn, to recover a failed seed-producing harvest. Seed quality tiers are unnecessary initially. [Relief rule](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:852).

**Comparable reference:** Researched—[Going Medieval](https://store.steampowered.com/news/posts/?appids=1029780&enddate=1774038904&feed=steam_community_announcements): protected seed.

**Connects to:** Kitchen substitution rules, stock policies, expansion, relief. Related designs: [ECO-027](/Users/brendan/Developer/redwall-review/REVIEW.md:2917), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795), [UX-008](/Users/brendan/Developer/redwall-review/REVIEW.md:5085).

**Impact:** High.

**Effort:** M after integrated seeds, inventory and relief behavior; the complete seed chain is L.

**Priority:** Next.

**Plan:** **Prerequisites:** actual seed lots and sowing demand. **Implementation slices:** plan-based reserve; explicit override; one bounded recovery flow. **Minimum useful prototype:** one crop family. **Player acceptance criteria:** a first-time player recovers from consuming the last seed-producing crop input without restarting, while expansion still costs food and seed items themselves never become edible. **Recommended direction / tradeoff:** Recommend automatically protected future sowing over manually fencing seed shelves.

<a id="eco-003"></a>

##### ECO-003 — Harvest plans for available hands

**Type:** Extension.

**Current state:** FieldPolicy stores a three-entry cycle; the demo uses local bed orders, [field_policy.gd:1](/Users/brendan/Developer/redwall-review/godot/scripts/core/field_policy.gd:1).

**Player problem:** Planting everything at once is easy; discovering too late that all harvests need the same hands is frustrating.

**Recommendation:** Extend the P4 calendar with a chosen farm strategy: “steady table,” “one large preserving harvest,” or custom dates. Compare projected harvest work against scheduled hands and preserving capacity. A projected overload suggests a later sowing date or smaller area, never silently changes crops. Batch the chosen plan as one farm order.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/farming/): rotation and harvest labor.

**Connects to:** Society work schedules, cooking, preservation, festivals. Related designs: [ECO-027](/Users/brendan/Developer/redwall-review/REVIEW.md:2917), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795), [UX-008](/Users/brendan/Developer/redwall-review/REVIEW.md:5085).

**Impact:** High.

**Effort:** M after P2/P4 truthful forecasts and queue semantics.

**Priority:** Next.

<a id="eco-004"></a>

##### ECO-004 — Player-designed kitchen gardens

**Type:** Extension.

**Current state:** Six fixed demo beds contrast with production field designations, [farm_sim.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:1), [GDD:457](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:457).

**Player problem:** The player tends someone else's garden rather than making a place of their own.

**Recommendation:** Offer small bed modules, continuous fields and mixed garden groups that share a plan. Let paths, a work shelf and one water point form a functional group; show walking cost rather than imposing a rectangular “perfect farm” bonus. A player can compose a courtyard root garden while an optimizer uses larger fields; a productive herb bed would require separate crop-content approval because herbs are currently forage, not a demo field row.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/farming/): rotation and harvest labor; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations.

**Connects to:** General construction, irrigation, local storage, visual identity. Related designs: [ECO-027](/Users/brendan/Developer/redwall-review/REVIEW.md:2917), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795), [UX-008](/Users/brendan/Developer/redwall-review/REVIEW.md:5085).

**Impact:** High.

**Effort:** L: productive placement, new farm grouping and labor integration are prerequisites, not just decoration.

**Priority:** Next.

**Plan:** **Prerequisites:** general placement/field designation and P2/P3. **Implementation slices:** place one bed; group beds under one plan; add shared service points; validate irregular layouts. **Minimum useful prototype:** three player-placed beds around a path. **Player acceptance criteria:** courtyard and rectangular layouts both feed the same test household with intelligible travel differences. **Recommended direction / tradeoff:** Recommend bounded modules plus grouping before arbitrary polygon simulation.

<a id="eco-f02"></a>

#### ECO-F02 — Soil improvement, irrigation and drainage

Grounding: [bed treatments](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:501), [tunnel water](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_tunnels.gd:1), [soil contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:469).

| Lens | Assessment |
|---|---|
| Feel | Digging changes the farm, giving infrastructure an unusually direct reward. |
| Depth | Several treatments exist, but the player lacks a compact model of when a durable investment beats a temporary response. |
| Expression | Wet gardens, dry plots and prepared beds could support different settlement styles. |
| Interconnection | Water, earth, labor and yield connect; demo spoil-as-compost must not become the adopted earth economy. |
| Progression | Preventative works should reduce repeated tending while creating spatial commitments. |
| Readability | A list of moisture modifiers is harder to understand than “will stay too wet after tomorrow's rain.” |
| Theme | Stewarding a garden fits the fantasy better than treating soil as an abstract productivity boost. |
| Benchmark | Researched: [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/farming/), [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/). **Pitfall / transfer limit:** invisible environmental arithmetic requiring a wiki before a player can make a reasonable choice. |

**Related owners:** [ECO-043](/Users/brendan/Developer/redwall-review/REVIEW.md:3371), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-009](/Users/brendan/Developer/redwall-review/REVIEW.md:5124).

<a id="eco-005"></a>

##### ECO-005 — Three soil-recovery strategies

**Type:** Balance.

**Current state:** Compost, legumes and fallow alter fertility, [GDD:469](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:469).

**Player problem:** A fertility deficit can feel like a mandatory repair purchase rather than a farm strategy.

**Recommendation:** Make three plans legible over one season: compost to maintain output now, legumes to earn food while improving the next rotation, or fallow to save labor and inputs at the cost of area/time. Compare expected next harvest and staff-days, with uncertainty labeled. Keep ordinary soil viable without repeatedly applying every treatment.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/farming/): rotation and harvest labor.

**Connects to:** Compost supply, seed plans, seasonal labor, expansion. Related designs: [ECO-043](/Users/brendan/Developer/redwall-review/REVIEW.md:3371), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-009](/Users/brendan/Developer/redwall-review/REVIEW.md:5124).

**Impact:** High.

**Effort:** M after the P4 forecast foundation.

**Priority:** Next.

<a id="eco-006"></a>

##### ECO-006 — Explicit irrigation and drainage

**Type:** Extension.

**Current state:** Dry bores drain and water-connected bores irrigate nearby beds, [farm_tunnels.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_tunnels.gd:1).

**Player problem:** A transport project can change a garden's water condition without the player feeling they designed or controlled the service.

**Recommendation:** Separate deliberate water-service fittings from the existence of a travel tunnel: a drain outlet, a shallow feeder channel and a closable garden inlet. Use a small discrete wet/normal/dry model first. Show affected beds and preserve a transport-only choice. Give storage/route projects no automatic irrigation promise merely because they share a graph.

**Comparable reference:** Researched—[Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations.

**Connects to:** Tunnels, earth works, drought, garden placement. Related designs: [ECO-043](/Users/brendan/Developer/redwall-review/REVIEW.md:3371), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-009](/Users/brendan/Developer/redwall-review/REVIEW.md:5124).

**Impact:** High.

**Effort:** L: new service policy and authored controls; full fluid simulation is excluded.

**Priority:** Next.

**Plan:** **Prerequisites:** adopted water-service decision, route safety and P4. **Implementation slices:** one explicit drain; one feeder/inlet; affected-bed preview; seasonal tuning. **Minimum useful prototype:** two beds sharing a controllable inlet. **Player acceptance criteria:** players predict which bed improves under rain versus drought and can retain an unchanged travel tunnel. **Recommended direction / tradeoff:** Recommend bounded service zones; a full hydrology sandbox is a credible but much larger, genre-shifting alternative.

<a id="eco-007"></a>

##### ECO-007 — Tending policies with work budgets

**Type:** QoL.

**Current state:** Cover, raise, bank, drain and watering are individual bed operations, [farm_bed_panel.gd:40](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:40).

**Player problem:** Knowing the right response still means repeating the same maintenance commands as the garden expands.

**Recommendation:** A garden may permit “protect from forecast frost,” “water below suitable band” and “avoid waterlogging.” Show maximum materials/work this policy may spend during the next day; a player can cap it or reserve staff. Routine execution follows P2 priorities; structural changes still require a chosen project. Notify exceptions, not every successful cover.

**Comparable reference:** Researched—[Dwarf Fortress](https://www.bay12games.com/dwarves/?dfuhk=): conditional orders; [Against the Storm](https://eremitegames.com/rainpunk-update-1/): controllable operating burden.

**Connects to:** Labor, forecasts, stocks, attention budget. Related designs: [ECO-043](/Users/brendan/Developer/redwall-review/REVIEW.md:3371), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-009](/Users/brendan/Developer/redwall-review/REVIEW.md:5124).

**Impact:** High.

**Effort:** M after P2 ownership and P4 forecasts; not an additional job engine.

**Priority:** Next.

<a id="eco-f03"></a>

#### ECO-F03 — Orchards, nurseries and beekeeping

Grounding: [orchard/hive rules](/Users/brendan/Developer/redwall-review/godot/scripts/core/orchard_hive.gd:1), [maturity/feed/pollination](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:477).

| Lens | Assessment |
|---|---|
| Feel | Presently an absent playable promise; eventual blossom, harvest and honey should offer distinct rhythms. |
| Depth | Health, chill, propagation, winter feed and bounded pollination already imply more than another field. |
| Expression | Orchard lanes and kitchen gardens can become recognizable places instead of isolated production circles. |
| Interconnection | Fruit/honey/wax span food, drinks, candles, seedlings and field yields; spending the same surplus should matter. |
| Progression | M3 access followed by two/three-year maturation risks pushing the payoff beyond the earliest Charter horizon. |
| Readability | Years of commitment require clear first-yield and continuing-care expectations before planting. |
| Theme | This is one of the strongest opportunities for a settlement to feel lovingly established. |
| Benchmark | Researched: [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/), [Stardew Valley](https://stardewvalleywiki.com/Bee_House). **Pitfall / transfer limit:** long silent timers and mandatory honey layouts that erase beautiful gardens. |

**Related owners:** [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

<a id="eco-008"></a>

##### ECO-008 — Early orchard rewards

**Type:** Change.

**Current state:** Apple/pear maturation is 96/144 days and begins after M3 saplings, [GDD:477](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:477).

**Player problem:** The village can invest for years without a satisfying return during the main progression arc.

**Recommendation:** Keep long-lived mature trees, but prototype one earlier access route and staged rewards: establish a sapling early, see a tended/blossoming stage, receive a small first harvest before full yield. Compare an “inherited old orchard restored” start with earlier sapling access; recommend the restoration option for the first scenario because it shows the payoff without accelerating every tree. Small first yield might be 15–25% of mature output after one full seasonal cycle.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/): orchard care; [Stardew Valley](https://stardewvalleywiki.com/Fruit_Trees): delayed fruit rewards.

**Connects to:** Milestones, nursery, preserving, community place identity. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** High.

**Effort:** L for a new restoration journey and progression revision.

**Priority:** Next.

**Plan:** **Prerequisites:** playable orchard work/output, P3 fruit recipes, SOC progression agreement. **Implementation slices:** compare timelines; author one recoverable orchard; add staged appearance/rewards; test through first fruit. **Minimum useful prototype:** one existing apple tree requiring care. **Player acceptance criteria:** players identify a near-term reason to maintain it and a distinct long-term goal without waiting past the scenario's main payoff. **Recommended direction / tradeoff:** Favor the restoration start. Keep adult-tree productivity bounded; do not simply divide all maturity times by ten.

<a id="eco-009"></a>

##### ECO-009 — Nursery plans and planting commitments

**Type:** Extension.

**Current state:** Nursery propagation consumes fruit, compost, water and work before a wait; [GDD:482](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:482).

**Player problem:** Another waiting queue adds little agency if every sapling has the same destination and urgency.

**Recommendation:** Tie each propagated sapling to a visible planting plan or a small nursery reserve. Offer healthy orchard expansion versus keeping fruit for winter. Permit relocating a young sapling with an explicit growth delay; mature trees remain a meaningful place commitment. Show first expected producing season, not only propagation completion.

**Comparable reference:** Researched—[Stardew Valley](https://stardewvalleywiki.com/Fruit_Trees): delayed fruit rewards.

**Connects to:** Fruit reserves, land planning, climate, household projects. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** Med.

**Effort:** M after a playable nursery/planting loop, which is L overall.

**Priority:** Later.

<a id="eco-010"></a>

##### ECO-010 — Orchard harvest groups

**Type:** Extension.

**Current state:** One modeled fruit tree per 4×4 block, separate apple/pear harvest windows; [GDD:477](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:477).

**Player problem:** More trees can simply mean more simultaneous hauling and an oversized autumn pile.

**Recommendation:** Allow orchard groups with a shared gathering point, optional harvest carts/baskets and a chosen destination. Mix earlier apple and later pear harvests to trade concentrated festival abundance against manageable preserving labor. Display “fresh table / preserve / seedling” shares as desired priorities, not guaranteed allocations. Retain walking lanes as useful space.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/): orchard work areas; [Stardew Valley](https://stardewvalleywiki.com/Fruit_Trees): delayed fruit rewards.

**Connects to:** Local buffers, preservation, SOC harvest celebrations, nursery. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** High.

**Effort:** L including missing orchard harvest/haul integration.

**Priority:** Later.

**Plan:** **Prerequisites:** P2/P3, orchard output, local storage. **Implementation slices:** two-tree group; gathering point; seasonal destination policy; mixed-window scenario. **Minimum useful prototype:** one apple and one pear serving one preserver. **Player acceptance criteria:** both concentrated and staggered harvest plans are intelligible and useful; overflow has an understandable response. **Recommended direction / tradeoff:** Recommend group-level policy rather than per-tree staffing.

<a id="eco-011"></a>

##### ECO-011 — Seasonal apiary stewardship

**Type:** Extension.

**Current state:** Hives have strength, service, honey/wax, winter feed and bounded beans/fruit pollination, [orchard_hive.gd:1](/Users/brendan/Developer/redwall-review/godot/scripts/core/orchard_hive.gd:1).

**Player problem:** Hives risk becoming a passive output circle or an obscure health bar.

**Recommendation:** Give apiaries a seasonal work rhythm: spring service, summer honey harvest, autumn winter-feed reservation, winter rest. Show which nearby crops benefit and whether their bloom/work windows coincide. Begin with one supported flowering-garden cosmetic identity; a second honey identity should arrive only with a real recipe preference, not a random price tier. A low-strength hive asks for a specific response rather than constant attention.

**Comparable reference:** Researched—[Stardew Valley](https://stardewvalleywiki.com/Bee_House): flower honey; [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/): perennial care.

**Connects to:** Beans/orchards, menu identity, reserve policy, gardens. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** High.

**Effort:** L: seasonal tending, delivery and clear payoff need a complete playable apiary.

**Priority:** Next.

**Plan:** **Prerequisites:** hive work/output and P3 consumption, authored bloom semantics. **Implementation slices:** annual care loop; protected winter feed; recipient display; one optional garden variation. **Minimum useful prototype:** one hive beside beans. **Player acceptance criteria:** a player can explain why it helps and preserve enough honey for winter without manual daily commands. **Recommended direction / tradeoff:** Recommend a few visible seasonal choices rather than bee genetics, diseases and colony-splitting simulation.

<a id="eco-012"></a>

##### ECO-012 — Honey and wax commitments

**Type:** Balance.

**Current state:** Honey feeds hives and recipes/mead; wax makes candles, [GDD:485](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:484), [recipes](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140).

**Player problem:** Secondary products feel incidental when no visible village decision depends on them.

**Recommendation:** Protect hive winter feed first, then let players direct honey toward ordinary treats or a planned celebration. Let wax support a finite household/route lighting program, with long-lasting lights and low maintenance. Show one seasonal honey budget and one candle project demand; do not make every household require luxury candles to function.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/recipes-cookbook-update/): recipe alternatives; [Valheim](https://www.valheimgame.com/faq/): meaningful food choices.

**Connects to:** Community feast planning, kitchens, lighting, tunnels, reserves. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** Med.

**Effort:** M after complete apiary/cooking/candle consumers; L if those prerequisites are included.

**Priority:** Later.

<a id="eco-f04"></a>

#### ECO-F04 — Foraging and habitat stewardship

Grounding: [five patch kinds](/Users/brendan/Developer/redwall-review/godot/scripts/core/forage.gd:1), [season/danger rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:427).

| Lens | Assessment |
|---|---|
| Feel | Gathering should feel like knowing the surrounding woods; currently it is mainly rule data rather than a lived outing. |
| Depth | Seasonal availability, sustained extraction and deeper-wood exposure create genuine alternatives. |
| Expression | Protected groves and gathering routes can express values beyond maximizing harvested area. |
| Interconnection | Berries, nuts, mushrooms, roots and herbs should remain useful after fields mature. |
| Progression | Knowledge of places can grow without requiring escalating threat or constant farther travel. |
| Readability | Basin ownership, patch availability and risk must be understandable without abstract stock numbers alone. |
| Theme | A woodland community benefits from seasonal knowledge and care, without turning sapient neighbors into resources. |
| Benchmark | Researched: [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/), [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/). **Pitfall / transfer limit:** foraging becomes obsolete starter income, or protected habitat becomes entirely inert. |

**Related owners:** [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [SOC-029](/Users/brendan/Developer/redwall-review/REVIEW.md:4434), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

<a id="eco-013"></a>

##### ECO-013 — Lasting roles for foraged foods

**Type:** Extension.

**Current state:** Five seasonal patch types have stock/renewal rules, [forage.gd:1](/Users/brendan/Developer/redwall-review/godot/scripts/core/forage.gd:1).

**Player problem:** Once fields supply enough calories, walking into the woods can feel like an inefficient starter activity.

**Recommendation:** Give each existing forage category a continuing culinary/service role: herbs for infusions and care, nuts for durable loaves, mushrooms for woodland dishes, berries for preserves/tarts and wild roots for a reliable fallback. Keep cultivated staples competitive for quantity. Let a seasonal menu request a small amount of local forage without requiring every rare ingredient to avoid hunger.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/): gathered ingredients; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): mushroom-log production.

**Connects to:** Cuisine, care, preserving, locality, woodland routes. Related designs: [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [SOC-029](/Users/brendan/Developer/redwall-review/REVIEW.md:4434), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

**Impact:** High.

**Effort:** M for approved demand differentiation after L forage-to-kitchen integration.

**Priority:** Next.

<a id="eco-014"></a>

##### ECO-014 — Prepared gathering outings

**Type:** Extension.

**Current state:** Deeper basins offer richer forage with consent/risk and lookout rules, [GDD:439](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:439).

**Player problem:** Choosing a distant zone by a danger number does not feel like planning a woodland outing.

**Recommendation:** Offer “near-home daily gathering” and an optional prepared outing with a return-before-dark rule, known target patch, carry allowance and rest stop. A named hero can lead an occasional story outing; routine gatherers remain anonymous working groups. Show likely travel/work share and a safe turn-back rule. Successful visits record a place note useful next season, not an infinitely stacking skill bonus.

**Comparable reference:** Researched—[Deep Rock Galactic](https://www.deeprockgalactic.com/faq-test-page): purposeful traversal; [Dwarf Fortress](https://www.bay12games.com/dwarves/?dfuhk=): conditional orders.

**Connects to:** Lookouts, food variety, field guides, heroes, transport. Related designs: [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [SOC-029](/Users/brendan/Developer/redwall-review/REVIEW.md:4434), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

**Impact:** High.

**Effort:** L: group outings and return policy exceed existing patch arithmetic.

**Priority:** Later.

**Plan:** **Prerequisites:** forage delivery, group eligibility, SOC story/consent policy. **Implementation slices:** planned near/far trip; one rest/return rule; remembered seasonal place; optional hero-led variant. **Minimum useful prototype:** two destinations and one carry kit. **Player acceptance criteria:** players choose both depending on available time and ingredients; no resident must be individually shepherded home. **Recommended direction / tradeoff:** Recommend occasional planned outings over an expedition mini-game for every basket.

<a id="eco-015"></a>

##### ECO-015 — Protected groves as useful places

**Type:** New system.

**Current state:** Protected tiles are never auto-harvested; fauna rows are empty, [GDD:439](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:439), [world_init.gd:509](/Users/brendan/Developer/redwall-review/godot/scripts/core/world_init.gd:509).

**Player problem:** Protecting a grove can feel like clicking “stop receiving value.”

**Recommendation:** Establish a modest stewardship layer using existing patch recovery and scenery: protected areas maintain identifiable seasonal forage reserves, host observation/rest contacts and preserve mature canopy access. A yearly observation records recovery or a seasonal sighting. Any new regeneration benefit must be bounded, local and explicit; begin with no new yield buff. Non-sapient insect/fish ambience may express ecology; mammals/birds are never harvest targets or anonymous pest icons.

**Comparable reference:** Researched—[Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): tree-linked production; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain.

**Connects to:** Leisure, lore, conservation, canopy, reserve food. Related designs: [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [SOC-029](/Users/brendan/Developer/redwall-review/REVIEW.md:4434), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

**Impact:** Med.

**Effort:** L for a new observation/place loop; simple protection labels alone are S but not this proposal.

**Priority:** Later.

**Plan:** **Prerequisites:** seasonal patch presentation and SOC leisure/knowledge ownership. **Implementation slices:** one protected grove; visible seasonal change; observation contact; one annual record. **Minimum useful prototype:** one place that supports rest and retains resources. **Player acceptance criteria:** players can identify a reason to keep it beyond role-play without needing to cover the map in protected zones. **Recommended direction / tradeoff:** Recommend place utility before a biodiversity score or simulated animal food web.

<a id="eco-f05"></a>

#### ECO-F05 — Forestry and woodland stewardship

Grounding: [forest operations](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_jobs.gd:1), [zone policy](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_zones.gd:1), [renewal rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:674).

| Lens | Assessment |
|---|---|
| Feel | Felling, stumps, saplings and hauling visibly alter the place; this is already a strong local loop. |
| Depth | Deadfall, standing timber, conservation floors and replanting offer a sound start, but many tree identities are mechanically interchangeable. |
| Expression | A managed working wood should differ from a straight plantation or a protected village grove. |
| Interconnection | Wood is needed by heat, meals, bridges, supports and crafts; allocation can be interesting without artificial species bonuses. |
| Progression | Sustaining a mature wood is a better long-term reward than endlessly deleting trees. |
| Readability | An annual resource can be mistaken for a quick regrowth timer at demo speed. |
| Theme | Woodland stewardship should produce a place worth keeping, not merely renewable stacks. |
| Benchmark | Researched: [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements), [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/). **Pitfall / transfer limit:** dense monoculture becoming the single sensible strategy while beauty imposes only a penalty. |

**Related owners:** [ECO-042](/Users/brendan/Developer/redwall-review/REVIEW.md:3328), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-026](/Users/brendan/Developer/redwall-review/REVIEW.md:5590).

<a id="eco-016"></a>

##### ECO-016 — Woodland compartment rotations

**Type:** Extension.

**Current state:** Trees regrow over 48 days with mature-tree floors and deadfall options, [forest_rules.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_rules.gd:1), [GDD:674](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:674).

**Player problem:** A wood quota answers today's need but not whether the village will still have a wood next year.

**Recommendation:** Let a forestry zone be divided into two to four named compartments with “harvest this season / recover / protected” states. Show mature timber and renewal dates by compartment. Preserve a continuous mature canopy where the player marks it; do not require each tree to be scheduled. Give a starter sustainable sequence and allow custom rotation.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations; [Dwarf Fortress](https://www.bay12games.com/dwarves/?dfuhk=): conditional orders.

**Connects to:** Fuel, construction, understory forage, canopy routes. Related designs: [ECO-042](/Users/brendan/Developer/redwall-review/REVIEW.md:3328), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-026](/Users/brendan/Developer/redwall-review/REVIEW.md:5590).

**Impact:** High.

**Effort:** M after stable zone policy and physical wood delivery.

**Priority:** Next.

**Plan:** **Prerequisites:** P2 forestry ownership and truthful protected/committed stock. **Implementation slices:** compartment grouping; rotation policy; renewal outlook. **Minimum useful prototype:** two areas alternating harvest. **Player acceptance criteria:** players maintain a visible working wood over a full cycle with fewer orders than manual selection. **Recommended direction / tradeoff:** Recommend seasonal compartments over individual-tree age management.

<a id="eco-017"></a>

##### ECO-017 — Timber preparation choices

**Type:** Extension.

**Current state:** Demo wood and planks serve bridges/supports; production has one wood item, [tunnel_stores.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:1), [recipe catalog](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140).

**Player problem:** Different woodland work can collapse into one stack, while adding separate oak/beech commodities would multiply bookkeeping.

**Recommendation:** Begin with use-based preparation: readily available fuel/deadfall, structural timber and sawn components. Prefer a small processing state or recipe distinction over a new inventory species for every tree. Immediate log work builds quickly; prepared components save later repair/work or enable longer spans. Show where limited prepared stock will go before starting an ambitious project.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations; [Factorio](https://www.factorio.com/blog/post/fff-375): optional quality.

**Connects to:** Bridges, workshops, fuel, building upgrades. Related designs: [ECO-042](/Users/brendan/Developer/redwall-review/REVIEW.md:3328), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-026](/Users/brendan/Developer/redwall-review/REVIEW.md:5590).

**Impact:** Med.

**Effort:** L if adopting additional production materials/maintenance; current demo planks do not supply the full chain.

**Priority:** Later.

**Plan:** **Prerequisites:** approved wood/plank binding, useful consumers and P2 hauling. **Implementation slices:** one prepared component; two contrasting projects; destination reservation; tune labor cost. **Minimum useful prototype:** log versus plank bridge demand. **Player acceptance criteria:** basic timber stays useful and players can explain when processing is worthwhile. **Recommended direction / tradeoff:** Recommend three uses at most initially; species-specific timber is a later flavor option, not required depth.

<a id="eco-018"></a>

##### ECO-018 — Landmark trees and clearance plans

**Type:** QoL.

**Current state:** Fell, grub and plant operations plus conservation floors exist, [forest_jobs.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_jobs.gd:1).

**Player problem:** Clearing a useful path can accidentally erase the grove that made that part of the village attractive.

**Recommendation:** Add a “retain mature trees” option to clearance plans, with individually marked landmark trees and visible canopy/forage conflicts before confirmation. Give small saplings a relocation option with work and delay; do not let mature-tree movement be free. Show the difference between harvest-and-regrow and permanently clear. The plan should solve the route around retained trees when possible.

**Comparable reference:** Researched—[Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): tree-linked production; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain.

**Connects to:** Construction, garden identity, forage, canopy access. Related designs: [ECO-042](/Users/brendan/Developer/redwall-review/REVIEW.md:3328), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-026](/Users/brendan/Developer/redwall-review/REVIEW.md:5590).

**Impact:** Med.

**Effort:** M after construction previews can query forestry claims.

**Priority:** Next.

<a id="eco-f06"></a>

#### ECO-F06 — Raw materials, workshops and equipment

Grounding: [resource/building contracts](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:627), [main/ancillary recipes](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140), [demo material store](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:1).

| Lens | Assessment |
|---|---|
| Feel | Sawing and bridge delivery show craft purpose; many other declared crafts have no playable workshop routine. |
| Depth | Flax→rope/cloth, wood/iron tools, wax candles and salt support useful decisions if there are competing consumers. |
| Expression | A village could specialize its workshop equipment and output without choosing an industrial faction. |
| Interconnection | Fields, forest, fishery, winter clothing and route access naturally depend on crafts. |
| Progression | Better equipment needs a choice between quality, throughput and material availability, not automatic replacement of everything. |
| Readability | “Needs tool” should reveal which activity benefits and whether a basic alternative is sufficient. |
| Theme | Craft can show care and local identity while anonymous workers still operate at colony scale. |
| Benchmark | Researched: [Factorio](https://www.factorio.com/blog/post/fff-375), [Dwarf Fortress](https://www.bay12games.com/dwarves/?dfuhk=). **Pitfall / transfer limit:** combinatorial item tiers and maintenance clicks overshadow the people using them. |

**Related owners:** [SOC-005](/Users/brendan/Developer/redwall-review/REVIEW.md:3773), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370).

<a id="eco-019"></a>

##### ECO-019 — Practical equipment packages

**Type:** Extension.

**Current state:** Rope, cloth, tools, outfits, fishing gear and candles have recipes, [gameplay_balance.md:140](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140).

**Player problem:** A long list of intermediate products does not tell the player what new activity the workshop makes possible.

**Recommendation:** Present outcome packages such as “equip a bank fishery,” “prepare winter field clothes” and “fit out a long haul crew.” Each is a readable bill of goods using existing recipes, with basic and improved options. Keep the player in control of whether scarce flax becomes rope or clothing. Packages create orders; they do not mint resources or bypass crafting steps.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/recipes-cookbook-update/): recipe alternatives; [Factorio](https://www.factorio.com/blog/post/fff-382): shared supply policies.

**Connects to:** Flax fields, fishery, cold protection, work access. Related designs: [SOC-005](/Users/brendan/Developer/redwall-review/REVIEW.md:3773), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370).

**Impact:** High.

**Effort:** L for missing physical craft/equip integration, M for package authoring once it exists.

**Priority:** Next.

**Plan:** **Prerequisites:** P2/P3 shared inventory, craft completion, real equipment consumers. **Implementation slices:** one fishery package; fulfillment progress; alternative basic gear; second winter package. **Minimum useful prototype:** rope→net→equipped fisher. **Player acceptance criteria:** a new player understands the purpose and shortage at every step without opening each intermediate recipe. **Recommended direction / tradeoff:** Recommend outcome packages rather than hiding production behind a single “upgrade profession” button.

<a id="eco-020"></a>

##### ECO-020 — Automatic repair and selective quality

**Type:** Balance.

**Current state:** Tools and fishing gear have durability/repair contracts, [ancillary recipes](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:169).

**Player problem:** Unannounced gear breakage stops a livelihood; perfectly maintained everything can become a mandatory chore.

**Recommendation:** Workers exchange worn equipment at a local rack when finishing a shift; a workshop maintains a small spare target. Offer “serviceable” and “carefully made” output policies, trading work/materials for durability or a specific capability. A 20–30% durability difference is a first hypothesis; do not stack quality, rarity and enchantment tiers. Repair occurs automatically within a budget; special upgrades remain chosen.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-375): optional quality.

**Connects to:** Gear racks, crafts, labor continuity, resource scarcity. Related designs: [SOC-005](/Users/brendan/Developer/redwall-review/REVIEW.md:3773), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370).

**Impact:** High.

**Effort:** L for a complete equip/exchange/repair loop.

**Priority:** Next.

**Plan:** **Prerequisites:** actual gear ownership, usage wear, repair inputs and P2. **Implementation slices:** end-of-shift exchange; one repair queue; two service levels; shortage explanation. **Minimum useful prototype:** nets only. **Player acceptance criteria:** players run a fishery for a season with no repeated manual repair orders and deliberately choose which gear receives extra care. **Recommended direction / tradeoff:** Recommend predictable craftsmanship over randomized rare-item recycling.

<a id="eco-021"></a>

##### ECO-021 — Workshop fittings and specialization

**Type:** Extension.

**Current state:** Workbench/workshop slots and recipes are defined, [building definitions](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:100).

**Player problem:** Placing another generic workshop is an uninspiring answer to every production bottleneck.

**Recommendation:** Allow one or two specialist fittings: a ropewalk favors rope/net work but occupies length; a sheltered repair bench reduces interruption; a sawing yard needs a timber buffer. Make each fitting affect a specific process or service and visible space use, not every recipe by a flat percentage. Retain a generalist workshop for small settlements.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-375): optional quality; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations.

**Connects to:** Layout, local buffers, professions, equipment packages. Related designs: [SOC-005](/Users/brendan/Developer/redwall-review/REVIEW.md:3773), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370).

**Impact:** Med.

**Effort:** L: production-building customization and economic tradeoffs are new.

**Priority:** Later.

**Plan:** **Prerequisites:** productive workshop loop and general placement. **Implementation slices:** one rope fitting; compare generalist output; add one competing fitting; inspect space/service needs. **Minimum useful prototype:** generalist versus rope specialist on equal workers. **Player acceptance criteria:** either wins under a different village demand mix. **Recommended direction / tradeoff:** Recommend a few functional fittings over an expansive technology tree.

<a id="eco-022"></a>

##### ECO-022 — Craft provenance in durable objects

**Type:** Theme.

**Current state:** Inventory quality/recipe provenance is designed; finds currently include mostly tallies, [GDD:600](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600), [tunnel_finds.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_finds.gd:1).

**Player problem:** Craftsmanship loses its meaning when a made object is indistinguishable from a generic stock increase.

**Recommendation:** For a small number of durable objects, preserve workshop/local-source identity and show the result in the world: a bell stand, waymarker, furniture piece or hero's practical kit. A named master can author an occasional special commission; ordinary population output remains aggregated. Use appearance and a short provenance note before adding buffs.

**Comparable reference:** Researched—[Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): maker information.

**Connects to:** Workshops, finds, home furnishing, named heroes, lore. Related designs: [SOC-005](/Users/brendan/Developer/redwall-review/REVIEW.md:3773), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370).

**Impact:** Med.

**Effort:** M after craft outputs and source identity exist; no mass individual-artifact simulation.

**Priority:** Later.

<a id="eco-f07"></a>

#### ECO-F07 — Fishing and aquatic food production

Grounding: [method catalog](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:376), [demo driver](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:1).

| Lens | Assessment |
|---|---|
| Feel | Water has presence, but catching must become a planned livelihood rather than another one-click harvest. |
| Depth | Net/trap/weir/boat/ice already imply different labor, delay, equipment and habitat choices. |
| Expression | A small bank fishery, maintained river weir and seasonal expedition should remain viable identities. |
| Interconnection | Rope, tools, access, preservation and reserve targets can make every expedition purposeful. |
| Progression | More capacity must not simply erase the sustainable stock rules or make early methods worthless. |
| Readability | Stock/quota/effort/weather are different constraints; the player needs one intelligible decision at departure. |
| Theme | Otter and other trained fishers can lend character without species-exclusive work or new edible sapient creatures. |
| Benchmark | Researched: [Against the Storm](https://eremitegames.com/keepers-of-the-stone-dlc-update-1-4-available/), [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/). **Pitfall / transfer limit:** click-timing mini-games or hidden lottery yields competing with colony management. |

**Related owners:** [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037).

<a id="eco-023"></a>

##### ECO-023 — Distinct fishing livelihoods

**Type:** Balance.

**Current state:** Net, trap, weir, boat and ice access have different work/delay/effort contracts, [GDD:394](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:394).

**Player problem:** Players may assume each unlock simply replaces its predecessor with more fish per click.

**Recommendation:** Make their roles explicit: nets for flexible immediate work, traps for distributed low-attendance collection, weirs for a staffed predictable river commitment, boats for larger planned catches and ice access for a prepared winter option. Tune around total travel/set/collect/preserve work, not catch size alone. Display the next delivery time and labor commitment before choosing a method.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/keepers-of-the-stone-dlc-update-1-4-available/): collection timing; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): specialized bait.

**Connects to:** Gear, daily labor, kitchen demand, route reliability. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037).

**Impact:** High.

**Effort:** L for multi-method playable integration, following P3's first legal fishery.

**Priority:** Next.

**Plan:** **Prerequisites:** P3 catch-to-table and real gear/access. **Implementation slices:** net versus trap; integrate collection policy; add weir; compare seasonal boat option later. **Minimum useful prototype:** two methods with equal total player attention. **Player acceptance criteria:** each initial method is preferred in a different credible staffing/delivery scenario. **Recommended direction / tradeoff:** Recommend role preservation over a linear “best fishery” upgrade ladder.

<a id="eco-024"></a>

##### ECO-024 — Catch plans and selective gear

**Type:** Extension.

**Current state:** Nine edible species occupy river/lake/coast stocks; method filters already constrain catches, [fishing.gd:1](/Users/brendan/Developer/redwall-review/godot/scripts/core/fishing.gd:1).

**Player problem:** Species variety is decorative if the player cannot plan for the kitchen without repeatedly rerolling catches.

**Recommendation:** A trip targets a legal menu need: mixed supper catch, preserving catch or a particular available species. Allow a simple gear choice that trades selectivity against quantity/maintenance; the preview shows a likely range, never a guaranteed unavailable fish. Start with two profiles using the existing whitelist. Preserve pike/eel nonharvestability and shared basin limits.

**Comparable reference:** Researched—[Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): targeted bait; [Against the Storm](https://eremitegames.com/recipes-cookbook-update/): recipe alternatives.

**Connects to:** Recipes, gear repair, ecology, culinary identity. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037).

**Impact:** High.

**Effort:** L for new targeted production policy and gear balance.

**Priority:** Later.

**Plan:** **Prerequisites:** [ECO-023](/Users/brendan/Developer/redwall-review/REVIEW.md:2806) baseline, approved gear/content owner, kitchen demand. **Implementation slices:** two catch plans; gear costs; delivery preview; seasonal tuning. **Minimum useful prototype:** mixed versus selective bank fishing. **Player acceptance criteria:** both support meals, while selective trips meet a planned dish at a visible opportunity cost. **Recommended direction / tradeoff:** Recommend a small planning choice over a precision fishing mini-game or many bait commodities.

<a id="eco-025"></a>

##### ECO-025 — Seasonal fishery stewardship

**Type:** Extension.

**Current state:** Basin quotas, recovery, sustainable/intensive floors and restocking latch exist, [stock/quota rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:392).

**Player problem:** Closure can feel like an arbitrary disabled button, and “intensive” can look like free extra output until later.

**Recommendation:** Show a concise seasonal record per basin: recent landed catch, recovery trend, current commitment and expected return to the chosen safe band. Let the player alternate two fisheries or rest one while farming fills the gap. A temporary intensive order needs an explicit end condition and an estimated recovery consequence. Recovery should visibly reopen opportunities; avoid a permanent ecological punishment spiral.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/keepers-of-the-stone-dlc-update-1-4-available/): collection timing; [Against the Storm](https://eremitegames.com/rainpunk-update-1/): controllable operating burden.

**Connects to:** Seasonal menus, reserves, alternative food, stewardship. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037).

**Impact:** High.

**Effort:** M after P3 integration and P4 basin projection; not new stock simulation.

**Priority:** Next.

<a id="eco-026"></a>

##### ECO-026 — Demand-aware catch collection

**Type:** QoL.

**Current state:** Traps/weirs accumulate after passive intervals; demo completion returns candidate lots, [fishing_driver.gd:468](/Users/brendan/Developer/redwall-review/godot/demo/water/fishing_driver.gd:468).

**Player problem:** Fixed collection timing can dump a large perishable catch into an already busy kitchen.

**Recommendation:** After P3, set a collection policy: scheduled morning run, collect when the planned menu needs it, or collect before a warned closure. Show whether delaying preserves opportunity or risks losing access; do not copy one-way pond depletion into renewable Redwall basins. Allow one “land catch now” override with its actual labor/gear consequences.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/keepers-of-the-stone-dlc-update-1-4-available/): collection timing; [Factorio](https://www.factorio.com/blog/post/fff-382): shared supply policies.

**Connects to:** Preservers, weather, hauling, food timing. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037).

**Impact:** High.

**Effort:** M after complete passive fishery ownership and catch transport.

**Priority:** Next.

<a id="eco-f08"></a>

#### ECO-F08 — Cooking, milling, preservation and drinks

Grounding: [food recipes/quality](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:509), [demo inactive recipe candidates](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_recipes.gd:1).

| Lens | Assessment |
|---|---|
| Feel | The absence of a playable kitchen payoff is P3; the design challenge after it is a menu worth caring about. |
| Depth | Raw, milled, prepared, preserved and brewed forms offer different time, labor and storage commitments. |
| Expression | Seasonal dishes and permitted substitutions can produce distinctive village cuisine without activating thousands of research candidates. |
| Interconnection | Food links every land/water profession to ordinary life, celebrations and later journeys. |
| Progression | Techniques, reliable quality and a growing seasonal repertoire are richer than a stack of meal buffs. |
| Readability | Candidate lore, approved recipes, available ingredients and today's production need separate meanings. |
| Theme | Food is a major identity system, not a minor health consumable. |
| Benchmark | Researched: [Against the Storm](https://eremitegames.com/recipes-cookbook-update/), [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/), [Valheim](https://www.valheimgame.com/faq/). **Pitfall / transfer limit:** “optimal meal” buffs flatten cuisine into a single permanent ration. |

**Related owners:** [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

<a id="eco-027"></a>

##### ECO-027 — Bounded recipe substitutions

**Type:** Extension.

**Current state:** Production recipes have approved inputs; the demo lists inactive library candidates, [GDD:509](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:509), [farm_recipes.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_recipes.gd:1).

**Player problem:** Exact recipes can stall over one missing ingredient; unrestricted substitution would erase the reason to grow different foods.

**Recommendation:** Author a small recipe grammar: a staple base, one required character ingredient and one optional seasonal accent. A woodland pie could accept an approved mushroom/nut filling alternative while still requiring the same flour preparation; a named ceremonial dish keeps its defining ingredient. Show the actual resulting dish name and source lots. Restrict substitutions to explicitly approved sets and protect seeds, hive feed and event reservations.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/recipes-cookbook-update/): recipe alternatives.

**Connects to:** Crop roles, forage, recipes, stock policy, feast ingredients. Related designs: [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** High.

**Effort:** L for content rules and a playable substitution/production flow after P3.

**Priority:** Next.

**Plan:** **Prerequisites:** P3 recipe activation and common inventory. **Implementation slices:** three recipes with one choice each; output identity; reserve-aware selection; seasonal playtest. **Minimum useful prototype:** one staple stew with two approved vegetable options. **Player acceptance criteria:** cooks keep serving through one shortage without quietly consuming seed or making every ingredient equivalent. **Recommended direction / tradeoff:** Recommend bounded recipe families over a freeform ingredient combinator or thousands of individually authored recipes.

<a id="eco-028"></a>

##### ECO-028 — Preservation tradeoffs

**Type:** Extension.

**Current state:** Dry fish/fruit, salt fish, rations and passive processing are specified, [gameplay_balance.md:140](/Users/brendan/Developer/redwall-review/docs/gameplay_balance.md:140).

**Player problem:** If preserving is always a strictly better conversion, every fresh harvest becomes a mandatory factory input.

**Recommendation:** Differentiate three purposes: drying conserves labor after setup but ties up rack space/time; salting uses a scarce coastal salt supply to process a catch reliably; cooked travel rations spend more work for convenient portions. Fresh meals retain a place through quality/variety and lower preparation burden. Show edible portions retained, completion time and storage horizon. Weather-sensitive drying is optional later, not necessary for the first choice.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/): processing horizons; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): dedicated preservation processors.

**Connects to:** Salt/brine, fuel, fisheries, winter, later expeditions. Related designs: [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** High.

**Effort:** L for multiple completed preservation methods and balance.

**Priority:** Next.

**Plan:** **Prerequisites:** P3 one preservation chain, real aging/consumption. **Implementation slices:** compare fresh/dried; add salt tradeoff; reserve by intended use; tune a harvest peak. **Minimum useful prototype:** one fish catch split among supper and two preservation paths. **Player acceptance criteria:** no method wins on every axis; players can avert waste without processing all food. **Recommended direction / tradeoff:** Recommend explicit resource/time differences before spoilage hazards or dozens of containers.

<a id="eco-029"></a>

##### ECO-029 — Seasonal menus and daily service

**Type:** Extension.

**Current state:** Recipes and nutritional/variety policies exist, but no live menu loop, [GDD:509](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:509).

**Player problem:** Maintaining a number of meals is useful administration but gives the village little culinary identity.

**Recommendation:** Set a small menu with a daily staple, a seasonal second dish and optional special order. Plan two or three days ahead, automatically reducing variety ambition if actual staff/ingredients cannot deliver. Separate “today's service,” “winter stores” and “planned feast” demands. Show morning prep and evening serving visually; population eats by groups/services rather than requiring individual meal micromanagement. SOC owns social responses and feast ceremony.

**Comparable reference:** Researched—[Valheim](https://www.valheimgame.com/faq/): meaningful food choices; [Against the Storm](https://eremitegames.com/recipes-cookbook-update/): recipe alternatives.

**Connects to:** Farm plans, fish deliveries, ordinary needs, feasts, work schedules. Related designs: [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** High.

**Effort:** L: menu demand, service cadence and presentation are a new layer over P3.

**Priority:** Next.

**Plan:** **Prerequisites:** P3 functioning consumption and SOC meal service. **Implementation slices:** two-dish menu; two-day forecast; service presentation; separate special-order reservations. **Minimum useful prototype:** one 12-resident service with a forage alternative. **Player acceptance criteria:** players recognize what the village ate, change the menu for a real seasonal reason and recover from a missing dish without starvation. **Recommended direction / tradeoff:** Recommend a small menu over assigning favorite food to each anonymous resident.

<a id="eco-030"></a>

##### ECO-030 — Cooking preparation modes

**Type:** Extension.

**Current state:** Recipe quality/mastery is adopted and lot quality persists, [GDD:509](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:509).

**Player problem:** A better cook can feel like another opaque multiplier if the player has no influence beyond staffing.

**Recommendation:** Add one chosen service mode: everyday batch, careful small batch or emergency bulk. Use a modest labor/quality/throughput tradeoff, with known fresh inputs and sufficient station capacity. A careful batch can be reserved for visitors or celebration; ordinary food stays acceptable. Reveal one concrete quality reason on finished food—fresh ingredients, practiced recipe, or hurried preparation—rather than a long additive formula.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-375): optional quality; [Against the Storm](https://eremitegames.com/rainpunk-update-1/): controllable operating burden.

**Connects to:** Mastery, schedule, equipment, hospitality, food reserve. Related designs: [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** High.

**Effort:** M after quality-bearing cooked lots and real work slots; L if starting from the frozen demo.

**Priority:** Next.

**Plan:** **Prerequisites:** P3 and the existing quality rules' owner. **Implementation slices:** everyday/careful modes; one batch-size tradeoff; explanation; optional emergency mode only if needed. **Minimum useful prototype:** the same recipe in two modes. **Player acceptance criteria:** players choose each mode in a different situation and understand why a result changed. **Recommended direction / tradeoff:** Recommend deliberate preparation over random excellent/terrible cooking rolls.

<a id="eco-031"></a>

##### ECO-031 — A modest drink culture

**Type:** Extension.

**Current state:** Water, brine and mead exist; a warm herb infusion is named in the Hearth feast menu, [GDD:588](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:588), [item catalog](/Users/brendan/Developer/redwall-review/godot/data/item_definitions.json:1).

**Player problem:** A brewery alone would reduce the village's drink culture to alcohol production, while ordinary water service has little personality.

**Recommendation:** Start with water service, warm herb infusion and one seasonal fruit drink using approved plant ingredients. Mead remains optional celebration stock with a visible fermentation commitment. Give drinks service roles—warm shared break, ordinary table, travel water—before numerical buffs. No dehydration system or alcohol dependence is implied. Approve new drink recipes explicitly; literary mentions are not already active resources.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): dedicated processors.

**Connects to:** Herbs/fruit/honey, kitchen/brewery, community breaks, hospitality. Related designs: [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** Med.

**Effort:** L for new approved drink content, production and service.

**Priority:** Later.

**Plan:** **Prerequisites:** P3 serving, liquid ownership and SOC event design. **Implementation slices:** one nonalcoholic infusion; service animation; one timed mead batch; menu choice. **Minimum useful prototype:** an infusion with visible herb/water use. **Player acceptance criteria:** the nonalcoholic path supports the same ordinary communal experience, and mead never becomes obligatory survival fuel. **Recommended direction / tradeoff:** Recommend three or four well-supported drinks before a large brewing technology tree.

<a id="eco-f09"></a>

#### ECO-F09 — Storage, hauling and reserves

Grounding: [demo lots](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:1), [inventory/logistics rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600).

| Lens | Assessment |
|---|---|
| Feel | Carried baskets and filling shelves make stocks believable; numbers alone do not explain a working supply network. |
| Depth | Freshness, distance, load, containers and reservations create meaningful placement decisions when the player controls policy. |
| Expression | Central stores, nearby pantries and satellite work sites should support different layouts. |
| Interconnection | Every production chain, route and winter plan depends on actual accessible goods. |
| Progression | The player should graduate from moving one basket to managing a few reliable supply policies. |
| Readability | A full store can coexist with an empty kitchen; quantity is not readiness or throughput. |
| Theme | Stores should feel provisioned and orderly, without requiring an accountant for every shelf. |
| Benchmark | Researched: [Factorio](https://www.factorio.com/blog/post/fff-382), [Going Medieval](https://store.steampowered.com/news/posts/?appids=1029780&enddate=1774038904&feed=steam_community_announcements), [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements). **Pitfall / transfer limit:** a programmable logistics language becomes mandatory for basic comfort. |

**Related owners:** [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146).

<a id="eco-032"></a>

##### ECO-032 — Local supply buffers

**Type:** Extension.

**Current state:** Covered/cellar providers have different aging factors; demo chooses storage without a player distribution strategy, [farm_storage.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_storage.gd:1), [GDD:600](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600).

**Player problem:** The safest store may be far from the kitchen; the player cannot clearly trade food longevity against daily hauling.

**Recommendation:** Give kitchen shelves and workshop racks small local targets, backed by larger long-term stores. Refill in sensible batches; keep deep reserve in the best preservation space. A “daily pantry” needs roughly one service period's ingredients, not the entire harvest. Show the cost of central versus distributed storage as work/travel, not a hidden aura bonus.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations; [Going Medieval](https://store.steampowered.com/news/posts/?appids=1029780&enddate=1774038904&feed=steam_community_announcements): protected seed.

**Connects to:** Room layout, kitchen timing, hauling, cold storage. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146).

**Impact:** High.

**Effort:** L including the missing general physical distribution loop.

**Priority:** Next.

**Plan:** **Prerequisites:** P2 delivered cargo, P3 consumers, stable provider capacity. **Implementation slices:** one kitchen shelf; refill target; central-store priority; second worksite. **Minimum useful prototype:** a kitchen near/far from a cellar. **Player acceptance criteria:** both layouts function, and the player can reduce walking through one understandable storage change. **Recommended direction / tradeoff:** Recommend bounded service buffers over manual shelf-to-shelf routes.

<a id="eco-033"></a>

##### ECO-033 — Purpose-based reserves

**Type:** Extension.

**Current state:** Lots, reservation claims and minimum reserves are specified, [GDD:600](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600).

**Player problem:** “We have enough food” becomes misleading when seed, hive feed, a feast and daily meals all rely on the same stock.

**Recommendation:** Show a short purpose ledger: eat now, sow next, keep through winter, feed hives, committed event/project. Let players rank discretionary claims below essential daily needs and next crop viability. A deliberate emergency release of ordinary food commitments says which future promise will be missed; protected seed items remain protected under the adopted rule. Reserve intentions should be quantities with expiry and owners, not immutable piles that force extra hauling.

**Comparable reference:** Researched—[Going Medieval](https://store.steampowered.com/news/posts/?appids=1029780&enddate=1774038904&feed=steam_community_announcements): protected seed; [Factorio](https://www.factorio.com/blog/post/fff-382): shared supply policies.

**Connects to:** Menus, apiary, seeds, winter, events, future campaign provisioning. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146).

**Impact:** High.

**Effort:** M after reservation ownership and actual consumers; the shared economy remains L.

**Priority:** Next.

**Plan:** **Prerequisites:** P2/P3 purpose ownership and SOC event reservations. **Implementation slices:** two purposes; precedence preview; emergency release; add seasonal purposes. **Minimum useful prototype:** meals versus raw harvest earmarked for future seed separation, retaining protection of actual seed items. **Player acceptance criteria:** a player can predict who receives the last shared ingredient and reverse a noncritical commitment without hunting through buildings. **Recommended direction / tradeoff:** Recommend a small hierarchy over a general rules scripting language.

<a id="eco-034"></a>

##### ECO-034 — Shared storage policies

**Type:** QoL.

**Current state:** Filtering, reserves and capacity claims exist as contracts, [GDD:600](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600).

**Player problem:** Repeating slightly different settings on every store creates errors and makes expansion feel clerical.

**Recommendation:** Offer named policies such as Kitchen pantry, Winter reserve, Fishery locker and Building yard. A store may inherit one, with local overrides clearly marked. Changing a shared target previews affected stores; duplicating a policy produces a separate copy. Basic defaults work without opening the policy editor. This is stock distribution policy, not P2's worker crew preset.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-382): shared supply policies.

**Connects to:** Expansion, crafts, local buffers, seasonal reserve strategy. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146).

**Impact:** High.

**Effort:** M after [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056)/033; no new transport algorithm implied.

**Priority:** Next.

<a id="eco-035"></a>

##### ECO-035 — Decisions from production flow

**Type:** QoL.

**Current state:** Real lots coexist with separate demo stores and multiple work boards, [farm_pantry.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry.gd:1), [tunnel_stores.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_stores.gd:1).

**Player problem:** When meals arrive slowly, making another field can worsen the actual haul or cooking bottleneck.

**Recommendation:** Beyond P2's individual blocked jobs, provide a compact recent-flow view per chosen product: gathered → carried → processed → served/spoiled. Show the dominant time/stock accumulation and two relevant actions, such as move a pantry nearer or add a cooking shift. Use actual last-day results and label forecasts. Avoid a full-screen production graph by default.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/recipes-cookbook-update/): recipe alternatives; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements): processing destinations.

**Connects to:** Every chain, route investment, staffing, layout. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146).

**Impact:** High.

**Effort:** M after P2/P3 shared identities and actual throughput records.

**Priority:** Next.

<a id="eco-f10"></a>

#### ECO-F10 — Seasons, weather, ecology and water landscape

Grounding: [weather design](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:732), [demo calendar](/Users/brendan/Developer/redwall-review/godot/demo/README.md:73), [authored water](/Users/brendan/Developer/redwall-review/godot/demo/water/water_map.gd:1).

| Lens | Assessment |
|---|---|
| Feel | Changing light/rain/soil is evocative; compressed days can turn anticipation into incessant reaction. |
| Depth | Seasons ought to change plans and opportunities, not merely apply disadvantages. |
| Expression | The same village should support prepared, conservative and opportunistic seasonal strategies. |
| Interconnection | Weather touches food, comfort, travel and fish; coordination matters more than adding another disaster. |
| Progression | Better preparation should earn calmer time for building, leisure and stories. |
| Readability | Forecast confidence and warning lead time must match what the player can actually act on. |
| Theme | Warm kitchens and quiet winter work can make survival feel cozy without removing stakes. |
| Benchmark | Researched: [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/), [Against the Storm](https://eremitegames.com/rainpunk-update-1/). **Pitfall / transfer limit:** punishing surprises or optimal permanent shutdown replacing adaptation. |

**Related owners:** [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [UX-022](/Users/brendan/Developer/redwall-review/REVIEW.md:5481), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

<a id="eco-036"></a>

##### ECO-036 — Calm earned through preparation

**Type:** Balance.

**Current state:** Many crop/weather responses coexist with a compressed demo day, [demo calendar](/Users/brendan/Developer/redwall-review/godot/demo/README.md:73), [weather contract](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:732).

**Player problem:** Being well prepared can still feel like constant urgent maintenance if every season introduces another compulsory interruption.

**Recommendation:** Author a first-year cadence: learn one seasonal pressure, invest in one remedy, then visibly benefit from reduced work. A successful reserve/drain/cover plan should create discretionary time for building or community life. Test calm intervals spanning two or three ordinary work cycles. Difficulty changes warning slack and reserve pressure before adding more event types.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/rainpunk-update-1/): controllable operating burden; [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment.

**Connects to:** Onboarding, leisure, labor automation, scenario difficulty. Related designs: [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [UX-022](/Users/brendan/Developer/redwall-review/REVIEW.md:5481), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** High.

**Effort:** M after P4 and integrated food/needs; coordinated with SOC progression.

**Priority:** Now.

**Plan:** **Prerequisites:** a complete seasonal playable slice. **Implementation slices:** author one pressure; instrument response workload; add earned quiet interval; test cozy/optimizer variants. **Minimum useful prototype:** one rain→drain→quiet sequence. **Player acceptance criteria:** prepared players have visibly fewer mandatory interventions without making the season irrelevant. **Recommended direction / tradeoff:** Recommend predictable learning before compound crises.

<a id="eco-037"></a>

##### ECO-037 — Seasonal work opportunities

**Type:** Extension.

**Current state:** Weather alters agriculture, fish access, outdoor work and tree blowdown, [GDD:732](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:732).

**Player problem:** Rain, frost and winter can feel like periods when the game removes enjoyable options.

**Recommendation:** Pair a few ordinary conditions with optional plans: rain reduces watering demand and frees workers for repairs; a cleared storm offers bounded deadfall gathering; winter favors indoor craft and preservation preparation; a calm window enables a prepared fishing trip. Surface these as “good time for” suggestions sourced from actual rules, without magical bonuses or urgency banners. Add new opportunities only when the matching job exists.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/rainpunk-update-1/): controllable operating burden; [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment.

**Connects to:** Work plans, forestry, fishery, crafts, seasonal identity. Related designs: [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [UX-022](/Users/brendan/Developer/redwall-review/REVIEW.md:5481), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** High.

**Effort:** M for selecting/presenting existing opportunities; L for new weather production rules.

**Priority:** Next.

<a id="eco-038"></a>

##### ECO-038 — Bounded landscape risk

**Type:** Change.

**Current state:** Authored water queries and weather affect travel; abstract wildlife pressure is adopted but not executed, [water_map.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/water/water_map.gd:1), [GDD:672](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:672), [ecology.gd:95](/Users/brendan/Developer/redwall-review/godot/scripts/core/ecology.gd:95).

**Player problem:** A vague “wildlife” or “flood” warning can imply a rich simulation while giving no intelligible action.

**Recommendation:** Keep the initial model bounded: name the threatened stock/place, visible condition, maximum consequence and remedy. A fence protects a specific enclosure; a staffed lookout addresses travel exposure; these should not be interchangeable safety auras. Do not represent sapient woodland creatures as pest swarms. Prefer track/damage evidence and a small contextual notice to an invented predator population. If pressure cannot create a useful choice, defer it rather than adding random loss.

**Comparable reference:** Researched—[Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment; [Against the Storm](https://eremitegames.com/rainpunk-update-1/): controllable operating burden.

**Connects to:** Foraging, apiary, fencing, lookouts, notifications, trust. Related designs: [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [UX-022](/Users/brendan/Developer/redwall-review/REVIEW.md:5481), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638).

**Impact:** Med.

**Effort:** M for an already adopted bounded event plus feedback; L for any actual fauna population, which is not recommended.

**Priority:** Later.

**Plan:** **Prerequisites:** enclosure/staffing semantics, deliberate content treatment of wildlife. **Implementation slices:** one bounded honey/forage event; explain protection; compare protected/unprotected scenarios. **Minimum useful prototype:** no creature population. **Player acceptance criteria:** players distinguish fence benefit from lookout benefit and see an actionable consequence without interpreting it as a raid. **Recommended direction / tradeoff:** Recommend the small adopted abstraction over a new animal simulation.

<a id="eco-f11"></a>

#### ECO-F11 — Water travel, diving, bridges and canopy access

Grounding: [bridges](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/bridges.gd:1), [dives](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/dive_task.gd:1), [movement scope](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:16).

| Lens | Assessment |
|---|---|
| Feel | Bridges produce visible communal benefit; diving is promising but its repeated reward is thin. |
| Depth | Bridge, ford and permitted swimming should differ by reliability, loads and cost; capability never implies a forced risky route. |
| Expression | Multiple infrastructure choices can preserve banks, connect workshops and support interesting layered villages. |
| Interconnection | Route investment needs recurring users, including food/material deliveries and social trips. |
| Progression | Trunks/ladders/branches for orchard work and observation are adopted but not playable; free flight is not adopted. |
| Readability | A perch is an actual supported contact, not a visual shortcut granting any species access. |
| Theme | Distinct bodies and learned skill can enrich shared places while public routes remain inclusive. |
| Benchmark | Researched: [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements), [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/). **Pitfall / transfer limit:** expensive specialist movement that never beats the ordinary route, or mandatory individual path micromanagement. |

**Related owners:** [SOC-002](/Users/brendan/Developer/redwall-review/REVIEW.md:3686), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

<a id="eco-039"></a>

##### ECO-039 — Public routes and specialist shortcuts

**Type:** Change.

**Current state:** Bridges carry everyone; other passages depend on body/load/skill, [bridges.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/bridges.gd:1), [movement requirements](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:34).

**Player problem:** A species-specific shortcut is either essential and exclusionary or decorative and irrelevant.

**Recommendation:** Author ordinary work districts with one safe public route and optional trained/body-compatible shortcuts. Make a broad bridge valuable for shared cargo and community travel; a wade/swim route can serve light urgent trips when permitted. Compare recurring journey classes—loaded supplies, ordinary travel, specialist work—not just fastest movement. Never require the player to issue a risky swimming order for basic participation.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain; [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment.

**Connects to:** Species profiles, inclusive homes, supply networks, service access. Related designs: [SOC-002](/Users/brendan/Developer/redwall-review/REVIEW.md:3686), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

**Impact:** High.

**Effort:** M for scenario/layout design after P5 route correctness; expanded transport itself remains L.

**Priority:** Next.

**Plan:** **Prerequisites:** P5 trustworthy capability/load routes. **Implementation slices:** two-bank work district; public route; optional specialist shortcut; repeated-use observation. **Minimum useful prototype:** one bridge with a shorter light-load water crossing. **Player acceptance criteria:** both routes receive understandable use and no resident is structurally excluded from essentials. **Recommended direction / tradeoff:** Recommend shared infrastructure plus optional specialization over species-locked districts.

<a id="eco-040"></a>

##### ECO-040 — Purposeful diving surveys

**Type:** Extension.

**Current state:** An otter dive budgets air, searches and returns finds, [dive_task.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/dive_task.gd:1).

**Player problem:** Repeating a dive for another small random find quickly loses its sense of exploration.

**Recommendation:** Create a few authored underwater interests with visible clues from shore: a lost tool parcel, an old crossing footing, a submerged marker. A survey identifies depth/access/reward; recovery requires suitable gear and a safe return plan. Some discoveries inform a bridge landing or historical record rather than grant loot. Keep rescue and injury consequences with SOC; diving should not be mandatory to provision the village.

**Comparable reference:** Researched—[Deep Rock Galactic](https://www.deeprockgalactic.com/faq-test-page): purposeful traversal; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): specialized equipment.

**Connects to:** Bridges, lore, craft recovery, specialist training, shore landmarks. Related designs: [SOC-002](/Users/brendan/Developer/redwall-review/REVIEW.md:3686), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

**Impact:** Med.

**Effort:** L: authored sites, survey state and persistent rewards extend the current search action.

**Priority:** Later.

**Plan:** **Prerequisites:** P5 air/return safety, SOC discovery ownership, real recovered-item sinks. **Implementation slices:** one shore clue; survey; one recovery choice; persistent site record. **Minimum useful prototype:** one recoverable craft parcel and one informational find. **Player acceptance criteria:** the player plans for a known purpose and does not farm the same site indefinitely. **Recommended direction / tradeoff:** Recommend authored small sites over an underwater loot dungeon.

<a id="eco-041"></a>

##### ECO-041 — Fixed landing cargo ferries

**Type:** New system.

**Current state:** Boats/raft are presentation or fishery design; moving-vessel transport is outside current movement adoption, [movement scope](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:28), [fishery buildings](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:627).

**Player problem:** Later wide-water settlements may face “build an enormous bridge or ignore the far bank,” leaving the river disconnected from the colony economy.

**Recommendation:** As a future optional extension, prototype a fixed two-landing cargo ferry: worker, payload, departure threshold and a dependable timetable. Trade lower construction commitment for staffing, batch delay and weather closure. A bridge remains convenient for high continuous traffic. Do not add free sailing controls or mandatory ferries to the current demo; first establish a far-bank resource/service that earns the route.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain; [Factorio](https://www.factorio.com/blog/post/fff-382): shared supply policies.

**Connects to:** Remote production, district stores, future trade, landscape preservation. Related designs: [SOC-002](/Users/brendan/Developer/redwall-review/REVIEW.md:3686), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

**Impact:** Med.

**Effort:** L: new adopted scope would be required, including passengers/cargo/landing policies.

**Priority:** Stretch.

**Plan:** **Prerequisites:** integrated hauling, safe landing ownership, explicit future movement approval. **Implementation slices:** abstract fixed cargo service; queue/closure rules; actual loading/landing presentation; only then passengers. **Minimum useful prototype:** one boat between two fixed safe piers. **Player acceptance criteria:** ferry and bridge each win under different volumes; no routine manual dispatch is needed. **Recommended direction / tradeoff:** Recommend cargo-first fixed service over physical free-moving vessels.

<a id="eco-042"></a>

##### ECO-042 — Connected canopy work access

**Type:** Extension.

**Current state:** Ladders/trunks/branches with supported return are adopted, not playable; no free-flight adoption, [movement amendment:16](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:16).

**Player problem:** Climbing could become a species animation demonstration without a reason to build or use it.

**Recommendation:** Start with two purposes: an orchard work perch and a lookout contact reached by a declared trunk/ladder connection. A ground alternative remains available at a different work/space cost. Eligibility comes from actual grip/body/gear/training profiles, not “all birds fly” or “all squirrels may ignore routes.” Show the return route and preserve it when editing. Add one short connected branch walkway only after those purposes are enjoyable.

**Comparable reference:** Researched—[Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): working ladders; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain.

**Connects to:** Orchard care, lookouts, woodland retention, species expression, layer controls. Related designs: [SOC-002](/Users/brendan/Developer/redwall-review/REVIEW.md:3686), [SOC-016](/Users/brendan/Developer/redwall-review/REVIEW.md:4087), [UX-012](/Users/brendan/Developer/redwall-review/REVIEW.md:5192).

**Impact:** Med.

**Effort:** L: the movement catalog, controls, work contacts and presentation are missing prerequisites.

**Priority:** Later.

**Plan:** **Prerequisites:** movement gates, SOC eligibility/training, UX layer selection, productive orchard. **Implementation slices:** one ladder/perch; work with safe return; lookout use; connected branch extension. **Minimum useful prototype:** one worker servicing one tree from a perch. **Player acceptance criteria:** players understand access and can compare it with ground work without individual traversal commands. **Recommended direction / tradeoff:** Recommend connected practical access over unrestricted climbing or flight.

<a id="eco-f12"></a>

#### ECO-F12 — Excavation, tunnel network and discoveries

Grounding: [network scope](/Users/brendan/Developer/redwall-review/docs/decisions/0208-the-tunnels-are-one-network-graph.md:14), [tunnel actions](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_actions.gd:1), [finds](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_finds.gd:1).

| Lens | Assessment |
|---|---|
| Feel | Making a lasting route is intrinsically satisfying; repeated excavation needs more than a growing line. |
| Depth | Body/load fit, work, earth handling and service access offer real planning considerations. |
| Expression | Branches, junctions and future levels can create a personal warren if destinations justify the topology. |
| Interconnection | The best dig improves everyday routines or unlocks a place; discovery alone cannot carry the entire loop. |
| Progression | Expansion should alternate short useful cuts with optional larger undertakings, not force a vast perfect network first. |
| Readability | The player needs to know what a completed piece enables, not simply its completion percentage. |
| Theme | Warm, inhabited subterranean life is a differentiation opportunity; a mine full of penalties is a different fantasy. |
| Benchmark | Researched: [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements), [Deep Rock Galactic](https://www.deeprockgalactic.com/faq-test-page), [Dwarf Fortress](https://bay12games.com/dwarves/dev_2012.html). **Pitfall / transfer limit:** importing combat pressure or arbitrary collapse just to make digging “interesting.” |

**Related owners:** [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233).

<a id="eco-043"></a>

##### ECO-043 — Useful warren destinations

**Type:** Extension.

**Current state:** One persistent graph joins mouths and passages, [decision 0208](/Users/brendan/Developer/redwall-review/docs/decisions/0208-the-tunnels-are-one-network-graph.md:14).

**Player problem:** A tunnel network can grow geometrically without changing daily village life.

**Recommendation:** Design three useful endpoint patterns: a short weather-sheltered home-to-kitchen route, a cool-storage service spur and a cross-hill material connection. Let players choose a compact spine, branching neighborhoods or a loop with alternate access. Those patterns should differ through actual distance, congestion and excavation cost; do not award arbitrary topology bonuses. Combine surface and underground access so one level need not contain everything.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain; [Deep Rock Galactic](https://www.deeprockgalactic.com/faq-test-page): purposeful traversal.

**Connects to:** Homes, kitchens, cellars, workshops, weather and hauling. Related designs: [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233).

**Impact:** High.

**Effort:** L including destination integration and multi-domain daily routing.

**Priority:** Next.

**Plan:** **Prerequisites:** P5 correctness, P2/P3 work/service routing; phase-3 room interfaces only after their owner completes them. **Implementation slices:** one useful connection; second endpoint choice; alternative topology scenario; ordinary daily use. **Minimum useful prototype:** one cellar-to-kitchen spur. **Player acceptance criteria:** two different networks produce understandable advantages, and residents use them without manual orders. **Recommended direction / tradeoff:** Recommend a few purposeful destinations before expanding depth limits.

<a id="eco-044"></a>

##### ECO-044 — Consequential excavation discoveries

**Type:** Extension.

**Current state:** Finds use fixed physical cells/layers and brief stories/tallies, [tunnel_finds.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_finds.gd:1).

**Player problem:** A repeated trinket notification is a reward but not an exploration loop.

**Recommendation:** Author three discovery types: a useful material pocket, a place worth preserving and a clue that offers a new destination. Before committing further work, offer “continue the practical route,” “carefully investigate” or “leave marked for later.” Investigation spends crew time and may require a specialist, while a preserved site can become a small public alcove. SOC owns riddle/story content; ECO owns spatial cost and usable outcomes.

**Comparable reference:** Researched—[Deep Rock Galactic](https://www.deeprockgalactic.com/faq-test-page): purposeful traversal; [Dwarf Fortress](https://bay12games.com/dwarves/dev_2012.html): purposeful material simplification.

**Connects to:** Lore, workshop commissions, route choices, communal places. Related designs: [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233).

**Impact:** High.

**Effort:** L for persistent discovery choices and authored outcomes.

**Priority:** Later.

**Plan:** **Prerequisites:** stable find identity, meaningful material/lore sinks, SOC content coordination. **Implementation slices:** one clue; branching action; persistent marker; one preserved alcove. **Minimum useful prototype:** one discovery intersecting a needed tunnel. **Player acceptance criteria:** players sometimes postpone or bypass investigation and later remember why the site matters. **Recommended direction / tradeoff:** Recommend a handful of consequential sites over endless randomized collectible drops.

<a id="eco-045"></a>

##### ECO-045 — Useful stages in a larger dig

**Type:** Change.

**Current state:** Digging already proceeds through pieces and unfinished space blocks travel, [underground_graph.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/underground_graph.gd:1), [movement requirements](/Users/brendan/Developer/redwall-review/docs/movement_direction_amendment.md:34).

**Player problem:** An ambitious project can require a long wait before anything improves, encouraging all work to be rushed at once.

**Recommendation:** Let players stage a larger plan around useful completed endpoints: first a small storage spur, then a shared junction, then a further connection. Distinguish a finished usable stage from an unfinished dead-end heading. Pausing expansion should leave a sensible, safe partial village. Show the next payoff, not just the final project's total length. This extends P5 project readability with deliberate incremental utility.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain; [Dwarf Fortress](https://www.bay12games.com/dwarves/?dfuhk=): conditional orders.

**Connects to:** Labor budgets, earth handling, storage, player session goals. Related designs: [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233).

**Impact:** High.

**Effort:** M after P5 and stable usable endpoint types.

**Priority:** Next.

**Plan:** **Prerequisites:** functional endpoints and safe completion boundaries. **Implementation slices:** tag two useful stages; allow independent commitments; show next benefit. **Minimum useful prototype:** a two-stage cellar/service plan. **Player acceptance criteria:** stopping after stage one is a deliberate viable choice, not a broken network. **Recommended direction / tradeoff:** Recommend player-selected useful stages over auto-generated arbitrary length milestones.

<a id="eco-046"></a>

##### ECO-046 — Passage upgrades for different traffic

**Type:** Balance.

**Current state:** Width, body/load fit, bracing and lamps exist in the demo; production support rules differ, [tunnel_actions.gd:1](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_actions.gd:1), [adopted economy](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:68).

**Player problem:** If every upgrade is always good, improving the warren is just paying a checklist on every segment.

**Recommendation:** Keep mandatory structural safety in construction, then make optional improvements purpose-specific: a broad freight artery, a pleasant well-lit shared route and a compact lightly used spur. Use actual clearance, throughput and upkeep costs, not invented comfort bonuses for every meter. A narrow route can stay valid for appropriate trips; a public essential route needs inclusive access. Never add surprise collapse to force upgrades.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain; [Factorio](https://www.factorio.com/blog/post/fff-375): optional quality.

**Connects to:** Traffic, mixed bodies, candles, workshop output, home access. Related designs: [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388), [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233).

**Impact:** High.

**Effort:** M for tuning existing options after adoption/implementation semantics agree; L for new corridor traffic rules.

**Priority:** Next.

<a id="eco-f13"></a>

#### ECO-F13 — Excavated earth and material reuse

Grounding: [adopted earth definition](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:50), [tips/handling](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:160), [demo clearing](/Users/brendan/Developer/redwall-review/godot/demo/spoil/spoil_crew.gd:1).

| Lens | Assessment |
|---|---|
| Feel | A mouth's growing heap makes the work physical; endless cleanup can dominate the pleasure of excavation. |
| Depth | Land, transport and re-use commitments are useful choices, provided earth has a legible planned destination. |
| Expression | Earth can help shape the settlement, subject to adopted backfill/tip rules and any separately approved landscaping. |
| Interconnection | Dig crews, haul capacity, surface projects and future closures share one material lifecycle. |
| Progression | Better organization should handle bigger projects, not unlock magical deletion or fertilizer conversion. |
| Readability | “Excavated earth” is not compost; usefulness depends on a legal earth-consuming project. |
| Theme | Reusing what the village removes supports stewardship without a moral tax on ordinary building. |
| Benchmark | Researched: [Dwarf Fortress](https://bay12games.com/dwarves/dev_2012.html), [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements). **Pitfall / transfer limit:** maximum physical realism with no added player decision. |

**Related owners:** [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-016](/Users/brendan/Developer/redwall-review/REVIEW.md:5305), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056).

<a id="eco-047"></a>

##### ECO-047 — Earth destinations in dig plans

**Type:** Extension.

**Current state:** Adopted earth must be hauled to tips or legal reuse; demo heap clearing differs, [earth amendment:50](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:50).

**Player problem:** Excavation appears to be one job and then surprises the player with a second, larger cleanup obligation.

**Recommendation:** Add a project earth budget with a chosen destination: nearby temporary tip, existing compacted tip or a committed backfill/use. Compare work and land occupied before digging. Reserve a destination capacity, but allow a deliberate reroute. The default proposes the shortest legal temporary option and clearly shows the cost of later reclaim; it does not make earth disappear.

**Comparable reference:** Researched—[Dwarf Fortress](https://bay12games.com/dwarves/dev_2012.html): purposeful material simplification; [Factorio](https://www.factorio.com/blog/post/fff-382): shared supply policies.

**Connects to:** Excavation stages, hauling, land use, future closures. Related designs: [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-016](/Users/brendan/Developer/redwall-review/REVIEW.md:5305), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056).

**Impact:** High.

**Effort:** L including the adopted earth/tip/haul loop, not just a preview label.

**Priority:** Next.

**Plan:** **Prerequisites:** distinct earth item, real tip capacity and P2 hauling. **Implementation slices:** one legal tip; project allocation; reroute/reclaim; linked backfill. **Minimum useful prototype:** a single dig with two destinations. **Player acceptance criteria:** players can explain why a farther compact tip might be preferable and complete a project without repeated heap clicks. **Recommended direction / tradeoff:** Recommend project-level destinations over individually selecting spoil baskets.

<a id="eco-048"></a>

##### ECO-048 — Scheduled tip reclamation

**Type:** Extension.

**Current state:** Tip preparation, compaction, reclaim and closure are adopted operations, [earth operations](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:68), [tip capacity](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:160).

**Player problem:** A temporary spoil site can become a permanent ugly nuisance because reclaiming it is easy to forget.

**Recommendation:** Let a tip carry an intended later use and a “reclaim when project finishes” policy. Offer loose nearby staging for quick work versus compact remote staging for smaller land occupation. Show the restoration work as part of the original project estimate. After closure, let ordinary planting/paths return through normal placement rules; earth itself never creates fertility.

**Comparable reference:** Researched—[Dwarf Fortress](https://www.bay12games.com/dwarves/?dfuhk=): conditional orders; [Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain.

**Connects to:** Land planning, forestry restoration, garden expansion, project completion. Related designs: [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-016](/Users/brendan/Developer/redwall-review/REVIEW.md:5305), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056).

**Impact:** Med.

**Effort:** M after [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484)'s L earth lifecycle.

**Priority:** Next.

**Plan:** **Prerequisites:** legal reclaim/closure and a real destination for removed earth. **Implementation slices:** intended-use marker; reclamation dependency; normal post-closure land use. **Minimum useful prototype:** one temporary tip on a future path. **Player acceptance criteria:** the player gets the promised path without manually chasing leftovers, and capacity/haul costs remain visible. **Recommended direction / tradeoff:** Recommend scheduled restoration over automatic free deletion.

<a id="eco-049"></a>

##### ECO-049 — Approved earth landscaping uses

**Type:** New system.

**Current state:** Excavated earth is a nonfertilizer material with backfill/tip uses; demo raised/banked beds have separate semantics, [earth definition](/Users/brendan/Developer/redwall-review/docs/underground_economy_hazard_amendment.md:50), [bed treatments](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_sim.gd:529).

**Player problem:** Even well-managed digging may feel purely subtractive if surplus earth only waits for another hole.

**Recommendation:** Consider a small authored catalog—garden terrace foundation, dry path embankment and turfed seating bank—using earth plus appropriate surface/retaining materials. Each has a real spatial purpose and a reversible cost. Soil/fertility for a garden remains a separate requirement. Exclude arbitrary terrain brushes, dams and defensive siegeworks from the first slice.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain; [Dwarf Fortress](https://bay12games.com/dwarves/dev_2012.html): purposeful material simplification.

**Connects to:** Garden layout, paths, cozy gathering places, earth reserves. Related designs: [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), [UX-016](/Users/brendan/Developer/redwall-review/REVIEW.md:5305), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056).

**Impact:** Med.

**Effort:** L: new legal earth consumers and landscape construction scope.

**Priority:** Later.

**Plan:** **Prerequisites:** [ECO-047](/Users/brendan/Developer/redwall-review/REVIEW.md:3484), ground/route validation and approval of each material recipe. **Implementation slices:** one embankment module; one garden foundation; placement/cost preview; optional seating bank. **Minimum useful prototype:** a dry path crossing a damp authored patch. **Player acceptance criteria:** surplus earth solves a real chosen project without being mandatory or convertible into free food value. **Recommended direction / tradeoff:** Recommend bounded modules over full terrain deformation.

<a id="eco-f14"></a>

#### ECO-F14 — Underground homes, rooms and root cellars — design only

Grounding: [intended experience](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:57), [templates](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:121), [rulings](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:502).

| Lens | Assessment |
|---|---|
| Feel | Entering a warm lit home and seeing a provisioned cellar should be the emotional reward for digging. |
| Depth | Access, warmth, cool storage, floor use and furnishing already give rooms a reason to differ. |
| Expression | Templates need bounded adaptation so a village does not become identical repeated mounds. |
| Interconnection | Homes belong to daily routes and community services; cellars belong to active food decisions. |
| Progression | Improving an established room should compete with excavating another, while simple rooms remain useful. |
| Readability | Every room should communicate its purpose and service condition without opening a diagnostics panel. |
| Theme | Cozy warrens are a strong fit; homes should welcome different residents instead of being a mole-only subsystem. |
| Benchmark | Researched: [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/), [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/). **Pitfall / transfer limit:** room-rating optimization crowds out understandable comfort and personal expression. |

**Related owners:** [SOC-011](/Users/brendan/Developer/redwall-review/REVIEW.md:3941), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

<a id="eco-050"></a>

##### ECO-050 — Inhabited, adaptable rooms

**Type:** Extension.

**Current state:** The approved design specifies warm burrow homes, separate furnishings and night return, [underground_revamp.md:57](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:57), [templates:121](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:121).

**Player problem:** An attractive chamber can still feel like an unused asset if its layout has no everyday meaning.

**Recommendation:** Offer a few editable furnishing intentions—compact sleeping room, family hearth room, shared guest room—using real beds, table, hearth and walkable access. Show resident groups returning, lights dimming and a small visible personal object, while SOC owns household identity. Keep service equivalence across cosmetic styles. The templates guide players without forcing identical interiors or grading every decoration.

**Comparable reference:** Researched—[Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): home renovations.

**Connects to:** Household routines, furnishing crafts, route access, cozy identity. Related designs: [SOC-011](/Users/brendan/Developer/redwall-review/REVIEW.md:3941), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

**Impact:** High.

**Effort:** L for editable furnishing intentions plus daily occupation; no assertion about phase-3 implementation.

**Priority:** Next.

**Plan:** **Prerequisites:** phase-3 owner's room/access completion, SOC home use, UX placement. **Implementation slices:** one usable furnishing plan; visible night occupation; editable equivalent variant; mixed-body accessibility check. **Minimum useful prototype:** two differently arranged rooms serving the same household size. **Player acceptance criteria:** players recognize the room's purpose in-world and successfully personalize it without breaking access. **Recommended direction / tradeoff:** Recommend bounded editable plans over freeform geometry in the first experience.

<a id="eco-051"></a>

##### ECO-051 — Cellars for different service needs

**Type:** Extension.

**Current state:** Root cellars have shelves, sockets/hatch and colder storage identity, [underground_revamp.md:121](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:121).

**Player problem:** If every cellar is simply “best storage,” the only question is how many to excavate.

**Recommendation:** Give cellar layouts complementary intentions: reserve shelves favor capacity and fewer visits; a service cellar has a broad working aisle and convenient kitchen route; a small harvest cellar prioritizes nearby intake. Show access distance, working capacity and preservation suitability. Avoid adjacent warm hearths becoming a hidden penalty; any chosen warm/cool separation must be inspectable and forgiving. Do not add a full thermodynamics puzzle merely because the room is underground.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/food/): processing horizons; [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment.

**Connects to:** Local pantries, preserve batches, tunnel width, seasonal stock. Related designs: [SOC-011](/Users/brendan/Developer/redwall-review/REVIEW.md:3941), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

**Impact:** High.

**Effort:** L for purposeful storage/furnishing integration; M once rooms and P2/P3 logistics exist.

**Priority:** Next.

**Plan:** **Prerequisites:** completed cellar interface, actual aging/throughput and [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056) buffers. **Implementation slices:** reserve/service plans; working aisle behavior; clear preservation readout; harvest-flow scenario. **Minimum useful prototype:** one cellar with two furnishing layouts. **Player acceptance criteria:** both arrangements have a credible use and players can explain the difference without temperature micromanagement. **Recommended direction / tradeoff:** Recommend service/capacity choices over a universal deeper-is-better bonus.

<a id="eco-052"></a>

##### ECO-052 — Connected underground neighborhoods

**Type:** Extension.

**Current state:** Homes have independent front doors and tunnel sockets; larger homes/pantry/workshop are later directions, [underground_revamp.md:121](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:121), [rulings:502](/Users/brendan/Developer/redwall-review/docs/design/underground_revamp.md:502).

**Player problem:** Repeating disconnected house/cellar units can miss the appeal of a lived-in underground community.

**Recommendation:** Provide one shared junction place—a lit nook with a seat/notice space—joining a few homes, storage and a public route. Keep private front doors meaningful, and allow surface-only households to use the same services. Neighborhood identity comes from paths, shared routines and player naming, not a new happiness aura. A later workshop alcove must have its own genuine work/access purpose.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements): connected terrain; [Going Medieval](https://foxyvoxel.io/2023/06/01/update-9/): inspectable room environment.

**Connects to:** Community life, wayfinding, inclusive access, furnishing, tunnel topology. Related designs: [SOC-011](/Users/brendan/Developer/redwall-review/REVIEW.md:3941), [ECO-032](/Users/brendan/Developer/redwall-review/REVIEW.md:3056), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

**Impact:** High.

**Effort:** L for a shared functional underground place and routine use.

**Priority:** Later.

**Plan:** **Prerequisites:** phase-3 rooms/access, SOC leisure/household schedules and UX layers. **Implementation slices:** one shared nook; routes from two homes; optional surface entrance; player naming/signage. **Minimum useful prototype:** two homes and a cellar sharing a junction. **Player acceptance criteria:** ordinary activity makes the neighborhood legible without manually ordering gatherings, and no essential service is species-locked. **Recommended direction / tradeoff:** Recommend one modest shared place before a full underground civic building roster.

<a id="soc-f01"></a>

#### SOC-F01 — People, identity and species

| Lens | Assessment |
|---|---|
| Feel | Recognizable bodies and professions create immediate charm, but role labels alone give little reason to remember a particular worker. |
| Depth | Size, carrying and access can create choices; species should not dictate a career or virtue. |
| Expression | Naming is useful, but earned identity should remain optional attention. |
| Interconnection | Deeds should connect workers to places, teachers and rescues. |
| Progression | Competence needs a legible path from anonymous contributor to respected notable, without a naming stat bonus. |
| Readability | Show current role and a small number of distinctive facts, with individual detail on demand. |
| Theme | Ordinary hospitality and courage matter as much as martial heroism. |
| Benchmark | Researched: [RimWorld](https://rimworldgame.com/), [Anno 1800](https://www.anno-union.com/devblog-residential-tiers/), [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/). **Pitfall / transfer limit:** The borrowing risk is making hundreds of biographies compulsory reading. |

**Related owners:** [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [SOC-028](/Users/brendan/Developer/redwall-review/REVIEW.md:4412).

<a id="soc-001"></a>

##### SOC-001 — Optional earned notability

**Type:** Extension

**Current state:** Naming/pinning and earned notable triggers are specified; the demo uses profession labels. [GDD](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:370), [demo names](/Users/brendan/Developer/redwall-review/godot/demo/cast/demo_actor.gd:211).

**Player problem:** I either remember nobody or feel expected to inspect every worker.

**Recommendation:** Keep the ordinary population in crew summaries. Offer an optional spotlight when a resident completes a distinctive deed: a difficult rescue, a first excellent craft or reliable service through a winter. The card states the deed, place and people involved; accepting pins a name, declining preserves the history. Keep a suggested focus roster of 6–10, with unlimited manual pins and no numerical naming benefit.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): personal causes; [Anno 1800](https://www.anno-union.com/devblog-residential-tiers/): aggregate services.

**Connects to:** Labor, rescue, feast hosts, chronicle, captains. Related designs: [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [SOC-028](/Users/brendan/Developer/redwall-review/REVIEW.md:4412).

**Impact:** High.

**Effort:** M after persistent event/notability foundations.

**Priority:** Now.

<a id="soc-002"></a>

##### SOC-002 — Physical affordances and learned roles

**Type:** Balance

**Current state:** The demo has bodily abilities; the kernel has sixteen species and size-based demand/access. [Abilities](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:2), [species](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:219).

**Player problem:** A charming species can become the wrong choice, or a profession becomes a species stereotype.

**Recommendation:** Distinguish physical limits from training. Keep genuine width/depth constraints; let equipment, teamwork or infrastructure provide alternatives where plausible. For a job, explain “faster with digging experience” separately from “requires a wide passage.” Prototype a mixed crew with two viable solutions to one difficult task; do not offer flying transport or other unimplemented powers just because a species is avian.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/devblog-residential-tiers/): aggregate services; [Timberborn](https://store.steampowered.com/app/1062090/Timberborn/): faction capabilities.

**Connects to:** ECO access/tools, training, admission, squad composition. Related designs: [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [SOC-028](/Users/brendan/Developer/redwall-review/REVIEW.md:4412).

**Impact:** High.

**Effort:** M after common job/tool rules.

**Priority:** Next.

<a id="soc-003"></a>

##### SOC-003 — Short earned hero arcs

**Type:** New system

**Current state:** Rowan is an active kernel founder; notability and future shared identities exist, but personal arcs do not. [Founder](/Users/brendan/Developer/redwall-review/godot/test/test_residents.gd:251), [identity direction](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:374).

**Player problem:** Naming a hero does not yet make their life develop.

**Recommendation:** Author three-stage arcs for a few notables: an expressed intention, a community-supported undertaking, then a changed responsibility. A rescuer might request a trainee, lead a supervised exercise, then become the rescue captain. Permit postponement and retirement; failure changes the next opportunity rather than deleting the character. Avoid generic combat stat rewards.

**Comparable reference:** Researched—[Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation; [RimWorld](https://rimworldgame.com/): personal causes.

**Connects to:** Mentoring, rescue, civic offices, squads, chronicle. Related designs: [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [SOC-028](/Users/brendan/Developer/redwall-review/REVIEW.md:4412).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** identity, event history and relevant service loop. **Implementation slices:** one authored civilian arc → two alternate outcomes → later military variant. **Minimum useful prototype:** one rescuer and one trainee. **Player acceptance criteria:** players explain why this resident matters and can ignore the arc without economic punishment. **Recommended direction / tradeoff:** recommend short systemic arcs; a fully scripted protagonist campaign is a credible later scenario, but narrows settlement expression.

<a id="soc-f02"></a>

#### SOC-F02 — Labor, autonomy and learning

| Lens | Assessment |
|---|---|
| Feel | Giving intent once and watching a capable crew execute it is satisfying; repeated worker redirection is not a long-term substitute. |
| Depth | Priorities, rest, skill and safety offer real trade-offs if their costs are visible. |
| Expression | Players need generalists, specialists and seasonal crews to remain viable. |
| Interconnection | Learning must cost current productive capacity and later ease a real bottleneck. |
| Progression | Mentorship is promising, but shouldn't demand friendship grinding before basic training. |
| Readability | Communicate the crew's capacity and current limiting job rather than only numerical priorities. |
| Theme | Apprenticeships and shared craft fit the setting. |
| Benchmark | Researched: [Anno 1800](https://www.anno-union.com/devblog-residential-tiers/), [RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/), [Against the Storm](https://eremitegames.com/favoring-update/). **Pitfall / transfer limit:** Free instant switching can turn work policy into constant toggling; specialization should have visible commitments. |

**Related owners:** [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [UX-007](/Users/brendan/Developer/redwall-review/REVIEW.md:5061), [ECO-034](/Users/brendan/Developer/redwall-review/REVIEW.md:3104).

<a id="soc-004"></a>

##### SOC-004 — Crew commitments and capacity

**Type:** Extension

**Current state:** Eleven jobs, per-resident priorities and schedules exist without a complete physical labor loop. [Priorities](/Users/brendan/Developer/redwall-review/godot/scripts/core/priorities.gd:68), [stages](/Users/brendan/Developer/redwall-review/godot/scripts/systems/settlement_system.gd:1631).

**Player problem:** A large settlement cannot remain enjoyable if every shortage requires editing individual priorities.

**Recommendation:** Define named crews with a preferred activity, eligible fallback activities, minimum staffed capacity and safety policy. Example: “Orchard crew, four preferred, lend two to harvest when idle.” Show available, occupied, resting and absent members; allow an optional named lead without requiring one. Keep exceptions possible, but let policies handle repeat work.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/devblog-residential-tiers/): aggregate services; [RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/): roles and gatherings.

**Connects to:** All ECO chains, schedules, care, military muster. Related designs: [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [UX-007](/Users/brendan/Developer/redwall-review/REVIEW.md:5061), [ECO-034](/Users/brendan/Developer/redwall-review/REVIEW.md:3104).

**Impact:** High.

**Effort:** L.

**Priority:** Now.

**Plan:** **Prerequisites:** common jobs and service completion. **Implementation slices:** one farm/haul crew → borrowing/fallback → absence and seasonal presets. **Minimum useful prototype:** two crews sharing spare workers. **Player acceptance criteria:** sustain a 48-person test settlement without opening most individual priority panels. **Recommended direction / tradeoff:** recommend crew intent with individual overrides; a fully automatic allocator offers less player authorship.

<a id="soc-005"></a>

##### SOC-005 — Visible apprenticeship

**Type:** Extension

**Current state:** Skill XP and a friendship-dependent mentoring rule are specified. [Mentoring](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:331).

**Player problem:** Training risks being either invisible passive leveling or a friendship prerequisite grind.

**Recommendation:** Offer a crew training slot with one competent lead and up to two adult apprentices. A scheduled lesson consumes perhaps 10–20% of that crew's work time; it grants experience only when tied to productive supervised tasks. Friendship improves comfort or retention of lessons, but is not required for introductory instruction. A completion ceremony recognizes competence, not merely XP accumulation.

**Comparable reference:** Researched—[RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/): roles and gatherings; [RimWorld: Biotech](https://ludeon.com/blog/2022/10/biotech-preview-3-reproduction-children-genetic-modification-release-date/): care and learning.

**Connects to:** Crew resilience, quality, notability, care, military drill. Related designs: [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [UX-007](/Users/brendan/Developer/redwall-review/REVIEW.md:5061), [ECO-034](/Users/brendan/Developer/redwall-review/REVIEW.md:3104).

**Impact:** High.

**Effort:** M after crews and skill events.

**Priority:** Next.

<a id="soc-006"></a>

##### SOC-006 — Seasonal schedules with recovery

**Type:** QoL

**Current state:** Default/night/flexible schedules and manual work preference exist. [Schedules](/Users/brendan/Developer/redwall-review/godot/scripts/core/schedule.gd:112).

**Player problem:** Harvest urgency can become repetitive schedule editing, and free instant switching invites optimization by constant toggling.

**Recommendation:** Save crew plans such as ordinary day, harvest effort and winter upkeep. Preview lost rest/social time and reassigned capacity. Activate at the next work period, with emergency override visible immediately; emergency overtime must be paid back in recovery time. Keep short-term emergency policies from silently becoming permanent defaults.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/devblog-happiness/): work conditions; [Against the Storm](https://eremitegames.com/favoring-update/): switching costs.

**Connects to:** Farming, needs, care, training, feast preparation. Related designs: [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [UX-007](/Users/brendan/Developer/redwall-review/REVIEW.md:5061), [ECO-034](/Users/brendan/Developer/redwall-review/REVIEW.md:3104).

**Impact:** High.

**Effort:** M after integrated schedules.

**Priority:** Now.

<a id="soc-f03"></a>

#### SOC-F03 — Needs, mood and ordinary life

| Lens | Assessment |
|---|---|
| Feel | An evening meal or sheltered rest must be visible as a payoff, not just five improving meters. |
| Depth | Access, time and capacity should matter alongside stock totals. |
| Expression | Courtyard life, compact shared facilities and dispersed comfortable homes should be different viable arrangements. |
| Interconnection | Service labor, travel, rest and morale must constrain one another. |
| Progression | Move from survival to chosen comforts without constantly inventing mandatory consumption. |
| Readability | Separate a worsening unmet need from a missed aspiration. |
| Theme | Warmth, fellowship and useful work should make prosperity feel humane. |
| Benchmark | Researched: [RimWorld](https://rimworldgame.com/), [Timberborn](https://store.steampowered.com/app/1062090/Timberborn/), [Anno 1800](https://www.anno-union.com/devblog-happiness/). **Pitfall / transfer limit:** Avoid converting every decorative choice into compulsory efficiency infrastructure. |

**Related owners:** [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

<a id="soc-007"></a>

##### SOC-007 — Daily service as the reward

**Type:** Extension

**Current state:** Eating, rest and social service are adopted but disconnected from the demo cast. [Needs/service rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:313).

**Player problem:** I can build stocks and routes without seeing a community benefit from them.

**Recommendation:** Once ECO's meal and housing loops exist, stage a readable daily rhythm: staggered meals, a period of social activity, then homes settling for the night. Player choices concern serving windows and capacity, not directing every diner. A distant field crew can use packed plant/fish meals at the cost of fewer communal contacts; a central hall earns contact but costs travel. Neither option should be universally superior.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/app/1062090/Timberborn/): communal amenities; [Anno 1800](https://www.anno-union.com/devblog-residential-tiers/): aggregate services.

**Connects to:** ECO meals/logistics/homes, relationships, shifts. Related designs: [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** High.

**Effort:** M for the rhythm layer; underlying service loop is L.

**Priority:** Now.

<a id="soc-008"></a>

##### SOC-008 — Chosen community aspirations

**Type:** New system

**Current state:** Five needs and mood are defined, but no explicit optional aspiration portfolio. [Needs](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:296).

**Player problem:** After survival, improvement can feel empty; alternatively, every unlock can become another demand I must satisfy.

**Recommendation:** Offer community aspirations such as a sheltered reading evening, a varied harvest table or a pleasant riverside gathering. Let players pursue two or three at a time, with several equivalent means. Completion gives a tradition, visible practice or decorative variation; ignoring one does not reduce baseline contentment. Keep essential warmth/food separate from optional excellence.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/app/1062090/Timberborn/): communal amenities; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation.

**Connects to:** Culture, surroundings, cuisine, Charter. Related designs: [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** High.

**Effort:** M after reliable need/service state.

**Priority:** Next.

<a id="soc-009"></a>

##### SOC-009 — Actionable community concerns

**Type:** QoL

**Current state:** Mood aggregates needs, while cause memories and departure production are incomplete. [Mood gap](/Users/brendan/Developer/redwall-review/godot/scripts/core/needs.gd:103).

**Player problem:** “Low comfort” does not tell me whether I lack warmth, seating, time or access.

**Recommendation:** Group an issue by its real cause: “Six evening workers miss the hall before closing.” Show one representative journey, affected count and two available remedies, such as shifting service or providing a nearer stop. Allow observing the next day to see whether that cause improves. This is service diagnosis content inside UX's community screen, not another dashboard.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): personal causes; [Anno 1800](https://www.anno-union.com/devblog-happiness/): local well-being.

**Connects to:** Service windows, routes, crew schedules, UI explanation. Related designs: [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-010](/Users/brendan/Developer/redwall-review/REVIEW.md:5146), [UX-027](/Users/brendan/Developer/redwall-review/REVIEW.md:5614).

**Impact:** High.

**Effort:** M after service-cause events.

**Priority:** Now.

<a id="soc-f04"></a>

#### SOC-F04 — Households, dependents and care

| Lens | Assessment |
|---|---|
| Feel | Households should add belonging, play and care rather than a stream of urgent chores. |
| Depth | Allocate community care and safe space, not optimal child labor. |
| Expression | Chosen households, kin and mixed-species neighbors should coexist. |
| Interconnection | Housing, admission, teaching and safe social access are the relevant links. |
| Progression | A fixed-stage child can discover interests and form attachments without aging into an adult. |
| Readability | A household's unmet service and its cause should be clearer than a large affinity matrix. |
| Theme | Protecting and teaching dependents makes the settlement worth defending. |
| Benchmark | Researched: [RimWorld: Biotech](https://ludeon.com/blog/2022/10/biotech-preview-3-reproduction-children-genetic-modification-release-date/), [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/), [Timberborn](https://store.steampowered.com/app/1062090/Timberborn/). **Pitfall / transfer limit:** Avoid importing generational simulation or treating elders as a production penalty. |

**Related owners:** [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-020](/Users/brendan/Developer/redwall-review/REVIEW.md:4196), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

<a id="soc-010"></a>

##### SOC-010 — Shared community care

**Type:** New system

**Current state:** Fixed life stages and preferred caregivers are proposed; no household care loop is live. [Care package](/Users/brendan/Developer/redwall-review/docs/planning/family_execution_package.md:165).

**Player problem:** Dependents could arrive as fragile chores rather than beloved community members.

**Recommendation:** Add a neighborhood care circle with a sheltered meeting/play space and rotating adult availability. Families state preferences, but communal care covers normal gaps. Choose between a dedicated caregiver and shared rota; the first is predictable, the second preserves flexible labor but needs spare capacity. Capacity and safe access matter; no productive child jobs or births are introduced.

**Comparable reference:** Researched—[RimWorld: Biotech](https://ludeon.com/blog/2022/10/biotech-preview-3-reproduction-children-genetic-modification-release-date/): care and learning; [Timberborn](https://store.steampowered.com/app/1062090/Timberborn/): communal amenities.

**Connects to:** Household package, admission, schedules, safe routes. Related designs: [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-020](/Users/brendan/Developer/redwall-review/REVIEW.md:4196), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

**Impact:** High.

**Effort:** L including absent care services.

**Priority:** Next.

**Plan:** **Prerequisites:** fixed-stage family ownership, safety and meals. **Implementation slices:** one care circle → rota/fallback → household preferences. **Minimum useful prototype:** two households and one shared service. **Player acceptance criteria:** care runs without daily child commands; a staffing gap has an understandable remedy. **Recommended direction / tradeoff:** recommend shared care; household-only babysitting preserves intimacy but scales poorly.

<a id="soc-011"></a>

##### SOC-011 — Households and belonging

**Type:** Extension

**Current state:** Household membership is separate from affinity and proposed up to eight members. [Household schema](/Users/brendan/Developer/redwall-review/docs/planning/family_state_schema.md:9).

**Player problem:** A home label is shallow if it only groups beds, while automatic romantic or species sorting would constrain expression.

**Recommendation:** Support chosen households and kin households with a shared name, preferred meeting place and optional meal window. Household bonds do not imply romance; membership changes need an understandable move/welcome event. Let a household favor proximity to work, relatives or a social place, with the player deciding the compromise. ECO owns rooms and capacity; this adds preferences and meaning.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): personal causes; [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): social identity.

**Connects to:** Housing design, social access, welcome, chronicle. Related designs: [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-020](/Users/brendan/Developer/redwall-review/REVIEW.md:4196), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

**Impact:** Med.

**Effort:** M after the L family package.

**Priority:** Next.

<a id="soc-012"></a>

##### SOC-012 — Peaceful participation across life stages

**Type:** Theme

**Current state:** Child play/learning and age-neutral elder treatment are proposed; birth/aging transitions are excluded. [Family activities](/Users/brendan/Developer/redwall-review/docs/planning/family_execution_package.md:105).

**Player problem:** Nonworkers can look idle or become an implicit burden without a visible place in society.

**Recommendation:** Add a small activity set: supervised nature sketches, listening to a craft story, making harmless feast decorations, tending a personal decorative patch. Elders may choose ordinary work, teaching or leisure on the same capability rules as adults; do not force teaching or reduce ability because of the label. Children gain interests and friendships, not productive labor output or future-adult stats.

**Comparable reference:** Researched—[RimWorld: Biotech](https://ludeon.com/blog/2022/10/biotech-preview-3-reproduction-children-genetic-modification-release-date/): care and learning; [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): arts.

**Connects to:** Care circle, festivals, education, personal history. Related designs: [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-020](/Users/brendan/Developer/redwall-review/REVIEW.md:4196), [UX-015](/Users/brendan/Developer/redwall-review/REVIEW.md:5281).

**Impact:** Med.

**Effort:** M after family routines.

**Priority:** Next.

<a id="soc-f05"></a>

#### SOC-F05 — Relationships and leadership

| Lens | Assessment |
|---|---|
| Feel | Bonds earned through shared experience are stronger than clicking social points. |
| Depth | Institutions should allocate attention and effort, with visible opportunity costs. |
| Expression | Leadership can suit a refuge, Abbey or established community rather than one universal ruler. |
| Interconnection | Friendships should influence mentoring, hospitality and resilience without overriding ordinary safety. |
| Progression | A community should acquire customs and reliable institutions, not merely larger friendship numbers. |
| Readability | Expose significant connections and commitments; hide routine pair drift. |
| Theme | Stewardship and mutual obligation suit the civic Charter. |
| Benchmark | Researched: [RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/), [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/), [Anno 1800](https://www.anno-union.com/devblog-happiness/). **Pitfall / transfer limit:** Avoid coercive law trees, faction spreadsheets or a mandatory charismatic avatar. |

**Related owners:** [SOC-033](/Users/brendan/Developer/redwall-review/REVIEW.md:4543), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795).

<a id="soc-013"></a>

##### SOC-013 — Practical civic commitments

**Type:** New system

**Current state:** Scenario-specific leadership and a civic Charter exist as direction; no council mechanics are defined. [Governance](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:207).

**Player problem:** A Warden or institution has little reason to exist if it only supplies a title.

**Recommendation:** Once per season, offer two or three concrete community requests, such as a public shelter, restored gathering place or mentor program. Commit to one, defer another, and explain capacity cost. Residents or institutions bring the request; it changes actual service, not a global buff. Abbey and refuge scenarios can present the same decision through different institutions without a universal mayor avatar.

**Comparable reference:** Researched—[RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/): roles and gatherings; [Against the Storm](https://eremitegames.com/explorers-choice-update/): alternative approaches.

**Connects to:** Construction, care, culture, progression. Related designs: [SOC-033](/Users/brendan/Developer/redwall-review/REVIEW.md:4543), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** institutions, event history and service outputs. **Implementation slices:** three requests → commitment/result → scenario-specific presentation. **Minimum useful prototype:** shelter versus teaching with finite labor. **Player acceptance criteria:** players can explain both valid choices. **Recommended direction / tradeoff:** recommend practical stewardship; voting/law simulation is a possible later direction with much greater social scope.

<a id="soc-014"></a>

##### SOC-014 — Relationships from shared experience

**Type:** Extension

**Current state:** Affinity gains from contact, feasts and rescues are specified, not integrated. [Relationship rules](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:353).

**Player problem:** Friendship risks becoming a hidden meter or a puzzle of forcing pairs into rooms.

**Recommendation:** Record a few meaningful shared experiences per person: learning together, working through a difficult season, receiving help or hosting. Let these favor voluntary social contact and mentorship. Players may create opportunities through crew and gathering arrangements; friendship should not require manual conversation orders. Serious disagreement may yield a request or changed preference, not random violence.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): personal causes; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation.

**Connects to:** Crews, care, households, feasts, hero arcs. Related designs: [SOC-033](/Users/brendan/Developer/redwall-review/REVIEW.md:4543), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795).

**Impact:** High.

**Effort:** M after relationship/event foundations.

**Priority:** Next.

<a id="soc-015"></a>

##### SOC-015 — Customs with real obligations

**Type:** Extension

**Current state:** The Hearth Charter expresses community identity, but no ordinary custom system exists. [Charter meaning](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:937).

**Player problem:** Communities can look different while making all the same social decisions.

**Recommendation:** After repeating a meaningful practice, offer to adopt a custom: a weekly open table, a winter teaching afternoon or a rescue watch. It reserves real time/resources and unlocks related stories or visual rituals. Keep perhaps three active customs initially; retire one respectfully at the next season, preserving history. Do not reward rapid switching or make neglect create an instant universal penalty.

**Comparable reference:** Researched—[Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): history and culture; [Against the Storm](https://eremitegames.com/favoring-update/): switching costs.

**Connects to:** Schedules, service budgets, music, Charter. Related designs: [SOC-033](/Users/brendan/Developer/redwall-review/REVIEW.md:4543), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418), [SOC-006](/Users/brendan/Developer/redwall-review/REVIEW.md:3795).

**Impact:** High.

**Effort:** M after culture/events and service commitments.

**Priority:** Later.

<a id="soc-f06"></a>

#### SOC-F06 — Health, rescue and remembrance

| Lens | Assessment |
|---|---|
| Feel | Timely aid should be intelligible and hopeful; recovery should leave a trace of what happened. |
| Depth | Prevention, a rescue response and care capacity provide different decisions. |
| Expression | Cautious infrastructure and a capable rescue crew should both work. |
| Interconnection | Herbs, cloth, rest, lost labor and relationships give danger consequences beyond a health bar. |
| Progression | Improve preparedness and community expertise, rather than escalate injuries to maintain pressure. |
| Readability | Distinguish distress, safety, treatment and return to work. |
| Theme | Courage includes rescue and nursing; remembrance need not be grim spectacle. |
| Benchmark | Researched: [RimWorld](https://rimworldgame.com/), [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/), [Total War: ROME II](https://r2enc.totalwar.com/en/manual/single-player/0087_enc_page_battle_play_phase_conflict_morale/). **Pitfall / transfer limit:** Do not carry combat lethality into the currently harmless demo implicitly. |

**Related owners:** [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704).

<a id="soc-016"></a>

##### SOC-016 — Rescue preparedness

**Type:** Extension

**Current state:** Swimmer/line rescue and safe wash-ashore recovery work in the demo; no player rescue doctrine exists. [Rescue](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/rescue.gd:2).

**Player problem:** A rescue can happen without my understanding what preparation made it possible.

**Recommendation:** Let a crew nominate a trained buddy and a safe muster bank before risky work. A shore supply point holds the usable line and warm recovery supplies; emergency response uses designated capacity, with a clear “responder occupied” reason. Offer an early Return order before distress. Reward safe completion and training, not repeated staged near-drownings. ECO still owns crossing routes and bridges.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): bounded defeat losses.

**Connects to:** Water work, care, crews, notable deeds. Related designs: [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704).

**Impact:** High.

**Effort:** M after rescue supplies/training support.

**Priority:** Next.

<a id="soc-017"></a>

##### SOC-017 — Community recovery and care

**Type:** New system

**Current state:** Injury/treatment arithmetic exists without a complete care loop. [Injury](/Users/brendan/Developer/redwall-review/godot/scripts/core/injury.gd:2).

**Player problem:** Injury could reduce a worker to a timer, or require constant personal intervention.

**Recommendation:** Use clear stable, needs-care and recovering states with a predicted range. Provide an automatic convalescent work policy: rest by default; later optional seated/light duties only when safe. Compare a central infirmary with local first aid plus home rest. A caregiver's time, ordinary meals, warmth, herbs and cloth have distinct roles; expensive supplies should not instantly erase all recovery. Avoid anatomical micromanagement.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): personal causes; [Timberborn](https://store.steampowered.com/app/1062090/Timberborn/): communal amenities.

**Connects to:** Herbs/textiles, homes, families, rescue, returning troops. Related designs: [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** need service and safe hauling/care ownership. **Implementation slices:** one exhaustion recovery → triage/resource choices → light-duty return. **Minimum useful prototype:** one injured worker and two care arrangements. **Player acceptance criteria:** players predict labor loss and recovery without babysitting. **Recommended direction / tradeoff:** recommend service-level medicine; detailed organ simulation adds little to this game's scale or tone.

<a id="soc-018"></a>

##### SOC-018 — Remembrance in places and practices

**Type:** Theme

**Current state:** Death records and memorial garden rules exist; downstream remembrance is not integrated. [Memories](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:333), [garden](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:662).

**Player problem:** Losing a meaningful resident could erase their contribution or feel like a resource debuff.

**Recommendation:** Offer a modest memorial tied to one true deed: a named bench by the rescued crossing, a recipe inscription or a garden marker. Preserve the history if physical markers are reused. Friends may attend a quiet optional remembrance; no compulsory expensive funeral and no combat bonus from death. Retirement or departure can receive a gentler farewell, keeping the same history continuity.

**Comparable reference:** Researched—[Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): persistent history; [RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/): roles and gatherings.

**Connects to:** Chronicle, friendships, hero arcs, landscape. Related designs: [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704).

**Impact:** Med.

**Effort:** M after history/lifecycle integration.

**Priority:** Later.

<a id="soc-019"></a>

##### SOC-019 — An emergency recovery chapter

**Type:** Extension

**Current state:** Fire/flood demo events are harmless evacuation demonstrations with return to routine. [Events](/Users/brendan/Developer/redwall-review/godot/demo/events/demo_events.gd:2).

**Player problem:** An emergency is spectacle if nothing needs doing afterward; pure punishment is also unsatisfying.

**Recommendation:** In a future consequential event mode, follow evacuation with a small recovery choice: restore access, open communal shelter or request neighbor assistance. Each uses different capacity and leaves a visible improvement or obligation. One incident should produce a short, understandable recovery plan, not simultaneous unrelated disasters. Keep the demo's current nonfatal behavior until a separate difficulty contract authorizes consequential hazards.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/explorers-choice-update/): alternative approaches; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): bounded defeat losses.

**Connects to:** ECO repair/weather, care, hospitality, chronicle. Related designs: [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704).

**Impact:** High.

**Effort:** L.

**Priority:** Later.

**Plan:** **Prerequisites:** consequential hazard scope, damage/care services and recovery resources. **Implementation slices:** one bounded flood aftermath → two recovery choices → aid obligation. **Minimum useful prototype:** damaged path plus temporary shelter. **Player acceptance criteria:** an uninformed player recovers without restarting and understands what preparation helped. **Recommended direction / tradeoff:** recommend bounded recoverable events; frequent escalating catastrophe conflicts with the cozy contract.

<a id="soc-f07"></a>

#### SOC-F07 — Immigration and hospitality

| Lens | Assessment |
|---|---|
| Feel | Arrivals should be an occasion and a commitment, not an unexplained population delivery. |
| Depth | Shelter, skills, service capacity and reserves should inform admission. |
| Expression | A small welcoming community, a growing town or a specialist refuge should all be valid. |
| Interconnection | Arrivals affect labor, care, meals and community knowledge. |
| Progression | Hospitality should reveal the outside world and broaden capabilities. |
| Readability | Explain what accepting or postponing a group means; avoid labeling a person an efficiency score. |
| Theme | Generosity has practical effort without a hidden species-betrayal test. |
| Benchmark | Researched: [RimWorld](https://rimworldgame.com/), [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/), [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/). **Pitfall / transfer limit:** Avoid making vulnerable residents punishments. |

**Related owners:** [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [SOC-010](/Users/brendan/Developer/redwall-review/REVIEW.md:3917).

<a id="soc-020"></a>

##### SOC-020 — Admission as a service commitment

**Type:** Extension

**Current state:** Candidates, food/bed admission checks and an authored rat petition are specified, but no live arrival queue exists. [Admission](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780).

**Player problem:** I cannot judge whether welcoming a group is sustainable without reducing people to skill scores.

**Recommendation:** Present a group with a reason for arrival, capabilities and explicit service needs. Preview the next few days of beds, meals, care and labor both with and without acceptance. Offer Welcome, Offer temporary hospitality, or Invite later when the scenario permits. Avoid a universal moral penalty for postponement and never hide betrayal behind species. Household separation is not a default optimization action.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): personal causes; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys.

**Connects to:** Food forecasts, homes, care, crews, UI petition surface. Related designs: [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [SOC-010](/Users/brendan/Developer/redwall-review/REVIEW.md:3917).

**Impact:** High.

**Effort:** M after the L immigration loop.

**Priority:** Next.

<a id="soc-021"></a>

##### SOC-021 — Visitors without compulsory growth

**Type:** New system

**Current state:** Hospitality is thematic direction; permanent admission is the only detailed arrival contract. [Feast/hospitality meaning](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:539).

**Player problem:** I must grow the population to gain social novelty, even if my settlement is the size I want.

**Recommendation:** Introduce a limited guest stay: a storyteller, traveling craftsperson or delegation uses guest beds and meals for perhaps one to three days. Choose an optional exchange—teach, share local knowledge or attend a feast. Visitors depart visibly; permanent joining requires a separate invitation. Start with adults and no dependents until family services are ready.

**Comparable reference:** Researched—[Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): cultural venues; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys.

**Connects to:** Guest accommodation, knowledge, menus, regional relations. Related designs: [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [SOC-010](/Users/brendan/Developer/redwall-review/REVIEW.md:3917).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** temporary identity, hospitality service and reliable departure. **Implementation slices:** one visitor → optional activity → return visit with memory. **Minimum useful prototype:** a storyteller at a guest table. **Player acceptance criteria:** visitors create novelty without compulsory population growth or exploitably free labor. **Recommended direction / tradeoff:** recommend bounded visits before a fully simulated traveler economy.

<a id="soc-022"></a>

##### SOC-022 — A visible welcome period

**Type:** Extension

**Current state:** Arrival health, needs and skills are specified; social integration is not a delivered flow. [Community task](/Users/brendan/Developer/redwall-review/docs/tasks/08_community_scenarios_progression.md:28).

**Player problem:** A welcomed group could instantly become more generic workers.

**Recommendation:** Give the new group a short orientation period: settle possessions, meet the relevant crew and choose a familiar shared place. Assign a host crew rather than one compulsory personal handler. A welcome meal is optional and small; a full feast is not required. A few days later show what changed—useful work, a new contact or an unmet concern—with an action only if needed.

**Comparable reference:** Researched—[Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation; [RimWorld](https://rimworldgame.com/): personal causes.

**Connects to:** Households, crews, relationships, hospitality. Related designs: [ECO-033](/Users/brendan/Developer/redwall-review/REVIEW.md:3080), [UX-006](/Users/brendan/Developer/redwall-review/REVIEW.md:5037), [SOC-010](/Users/brendan/Developer/redwall-review/REVIEW.md:3917).

**Impact:** Med.

**Effort:** M after admission and social events.

**Priority:** Next.

<a id="soc-f08"></a>

#### SOC-F08 — Feasts, culture and music

| Lens | Assessment |
|---|---|
| Feel | The settlement should visibly pause, gather and remember an occasion. |
| Depth | Surplus, service coverage, menu and occasion make better decisions than buff stacking. |
| Expression | Traditions need variations, not three fixed perfect recipes forever. |
| Interconnection | Preparation connects farms, kitchens, care, visitors and history; guests should have reasons to attend. |
| Progression | Later celebrations should be richer, not required to be larger. |
| Readability | Explain who can attend and the reserve cost before commitment. |
| Theme | This should be a signature Redwall experience, including humor and song, with original authored text distinguished from canon. |
| Benchmark | Researched: [RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/), [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/), [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/). **Pitfall / transfer limit:** Avoid guaranteed recruit farming, mandatory annual chores or uninterrupted festival music. |

**Related owners:** [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638), [UX-030](/Users/brendan/Developer/redwall-review/REVIEW.md:5703).

<a id="soc-023"></a>

##### SOC-023 — Feasts with an occasion and memory

**Type:** Extension

**Current state:** Three feast packages, staffing, seating waves and coverage are specified, but the occasion is not playable. [Feasts](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:578).

**Player problem:** The signature Redwall activity risks becoming “spend food, receive buff.”

**Recommendation:** Structure a feast as preparation, gathering, shared courses, a short chosen moment and a visible aftermath. Choose an occasion—harvest gratitude, welcome or homecoming—and a host. The moment can recognize a true deed, hear an original song or welcome a guest. Retain the table/menu/place in a brief memory; let ordinary life continue around service waves and bedside meals. Watching is optional, planning has the real cost.

**Comparable reference:** Researched—[RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/): roles and gatherings; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation.

**Connects to:** ECO cuisine, service staff, care, heroes, history. Related designs: [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638), [UX-030](/Users/brendan/Developer/redwall-review/REVIEW.md:5703).

**Impact:** High.

**Effort:** L.

**Priority:** Now.

**Plan:** **Prerequisites:** food lots, cooking, service and attendance. **Implementation slices:** one modest feast → occasion/host moment → remembered return occasion. **Minimum useful prototype:** eight diners and bedside delivery. **Player acceptance criteria:** players recall the occasion and one person, not only the reward. **Recommended direction / tradeoff:** recommend systemic gatherings with a short authored highlight; full cutscenes make repetition expensive and interrupt control.

<a id="soc-024"></a>

##### SOC-024 — Several forms of a good feast

**Type:** Change

**Current state:** Fixed two-course/beverage bundles, 80% coverage and reserve checks define success. [Requirements](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:578).

**Player problem:** There may be one cheapest optimal package, while a beautiful small feast counts as failure.

**Recommendation:** Keep a nourishing core, then choose a menu accent and serving scale. A hearth supper can celebrate a crew; a settlement feast demands more staffing and reserves. Display reserve-days consumed and likely coverage before committing. Distinguish hospitality success, culinary distinction and attendance instead of one binary verdict. Prevent repeating the cheapest event from farming reputation; recurring gatherings maintain tradition rather than stack rewards.

**Comparable reference:** Researched—[RimWorld: Ideology](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/): roles and gatherings; [Against the Storm](https://eremitegames.com/favoring-update/): switching costs.

**Connects to:** Food variety, preservation, service logistics, immigration. Related designs: [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638), [UX-030](/Users/brendan/Developer/redwall-review/REVIEW.md:5703).

**Impact:** High.

**Effort:** M after the L feast loop.

**Priority:** Now.

<a id="soc-025"></a>

##### SOC-025 — Traditions with annual variation

**Type:** Extension

**Current state:** Hearth, Harvest and Orchard feast themes exist; a living festival calendar does not. [Themes](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:588).

**Player problem:** Repeating the same menu and animations turns anticipation into a chore.

**Recommendation:** Let each community choose a seasonal tradition with one variable focus: a crop display, harmless craft contest, communal planting or an original riddle trail. In the next year, a guest, recent achievement or changed landmark alters the content. Offer advance preparation and a graceful skip. Keep rewards mainly expression, connections and memories; no exclusive yearly power item that punishes missed attendance.

**Comparable reference:** Researched—[Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation; [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): cultural forms.

**Connects to:** ECO seasons/crafts, lore, households, customs. Related designs: [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638), [UX-030](/Users/brendan/Developer/redwall-review/REVIEW.md:5703).

**Impact:** High.

**Effort:** M per tradition after event/feast infrastructure.

**Priority:** Next.

<a id="soc-026"></a>

##### SOC-026 — A community repertoire

**Type:** Theme

**Current state:** Acoustic, ambient and singing direction exists, but culture has no playable ownership or repertoire. [Sound intent](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:889), [voice](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:701).

**Player problem:** A pleasant soundtrack alone does not make the settlement feel culturally alive.

**Recommendation:** Start with three original short pieces associated with work, gathering and remembrance. A visitor or local host introduces a piece; later it appears in an appropriate communal occasion. Let players prefer or mute a repertoire without economic punishment. A milestone can add a verse referencing a verified local deed through authored slots, never fabricated canon text. UX owns mixing and audio accessibility; this owns meaning and occasion.

**Comparable reference:** Researched—[Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): music and poetry; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation.

**Connects to:** Visitors, festivals, heroes, chronicle, audio presentation. Related designs: [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [UX-028](/Users/brendan/Developer/redwall-review/REVIEW.md:5638), [UX-030](/Users/brendan/Developer/redwall-review/REVIEW.md:5703).

**Impact:** Med.

**Effort:** M for a bounded repertoire after events/audio foundations.

**Priority:** Next.

<a id="soc-f09"></a>

#### SOC-F09 — Narrative, lore and wonder

| Lens | Assessment |
|---|---|
| Feel | Finding something should provoke curiosity and change a later choice. |
| Depth | Observation and interpretation should matter more than clicking a collectible. |
| Expression | Players can investigate, preserve or quietly leave a place. |
| Interconnection | Local discoveries should inform routes, craft, hospitality or a hero's obligation. |
| Progression | Understanding a place is an alternative to bigger numbers. |
| Readability | Clues must be solvable in the game; the books are not required homework. |
| Theme | Ambiguous wonder and practical riddles fit better than spell unlocks. |
| Benchmark | Researched: [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/), [Against the Storm](https://eremitegames.com/explorers-choice-update/), [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/). **Pitfall / transfer limit:** Avoid substituting long lore dumps or random loot for interpretation. |

**Related owners:** [ECO-044](/Users/brendan/Developer/redwall-review/REVIEW.md:3395), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418).

<a id="soc-027"></a>

##### SOC-027 — Fair optional investigations

**Type:** New system

**Current state:** Rare wonder and fair riddles are direction, while current finds largely stop at a tally. [Riddle boundary](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:605), [demo finds](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_finds.gd:1).

**Player problem:** Discovery has little curiosity beyond collecting another object.

**Recommendation:** Build a three-clue local investigation: an inscription, a physical landmark and an oral account. Any two narrow the answer; the third confirms it. Players can preserve, investigate or leave it. Supply optional staged hints from an archive/visitor. The result may reveal a safe route, an object's story or a decorative practice, never a required combat spell. No book trivia or pixel hunting.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/explorers-choice-update/): alternative approaches; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys.

**Connects to:** Underground exploration, landmarks, visitors, archives. Related designs: [ECO-044](/Users/brendan/Developer/redwall-review/REVIEW.md:3395), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** discoverable world objects, clue record and authoring rules. **Implementation slices:** one investigation → two resolutions → reusable clue/hint pattern. **Minimum useful prototype:** one small map with three clues. **Player acceptance criteria:** unfamiliar players solve it using only game evidence; uninterested players retain full ordinary progression. **Recommended direction / tradeoff:** recommend grounded local riddles before procedural mysteries.

<a id="soc-028"></a>

##### SOC-028 — Player-curated visible history

**Type:** Extension

**Current state:** Chronicle/codex direction exists; current notices are not an authored settlement history. [Story direction](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:907).

**Player problem:** Important experiences disappear into a log, while preserving every event creates unreadable noise.

**Recommendation:** Offer three candidate moments at a seasonal reflection: a meaningful achievement, a relationship/deed and a setback overcome. Pin any, dismiss all or keep private. A chosen moment can name a crossing, illustrate a hall panel or be retold at a feast. Every entry retains its real participants and outcome; chronological detail remains available underneath. This extends Phase 1's history prerequisite with player authorship.

**Comparable reference:** Researched—[Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): history and culture; [Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): event variation.

**Connects to:** Rescue, milestones, hero arcs, buildings, feasts. Related designs: [ECO-044](/Users/brendan/Developer/redwall-review/REVIEW.md:3395), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418).

**Impact:** High.

**Effort:** M after persistent event history.

**Priority:** Next.

<a id="soc-029"></a>

##### SOC-029 — Knowledge through practice and people

**Type:** New system

**Current state:** Skills/mastery and a large offline content corpus exist; no active lore/research progression connects them. [Content activation](/Users/brendan/Developer/redwall-review/docs/redwall-content-library/authoring_handoff.md:7).

**Player problem:** A generic research meter would waste the setting's craft traditions, while hidden recipe lotteries would obscure progress.

**Recommendation:** Use an archive/workshop knowledge board with visible leads: demonstrate a technique, host someone who knows it, or study a found record. Two routes should usually reach the same practical knowledge. Investigation costs skilled time and sometimes trial materials; a failed trial produces information. ECO owns recipe-chain balance; the archive connects knowledge sources and preserves teaching access after an expert leaves.

**Comparable reference:** Researched—[Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): libraries; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys.

**Connects to:** Craft/farm knowledge, visitors, mentors, riddles. Related designs: [ECO-044](/Users/brendan/Developer/redwall-review/REVIEW.md:3395), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418).

**Impact:** High.

**Effort:** L.

**Priority:** Later.

**Plan:** **Prerequisites:** activated content, skill/mastery and service jobs. **Implementation slices:** one technique/two learning routes → record/teach → small knowledge collection. **Minimum useful prototype:** practice versus visiting instructor. **Player acceptance criteria:** players explain where knowledge came from and do not lose all progress with one departure. **Recommended direction / tradeoff:** recommend tangible learning; a universal science currency is easier but less distinctive.

<a id="soc-030"></a>

##### SOC-030 — Rare, interpretable wonder

**Type:** Theme

**Current state:** Wonder is explicitly rare and uncertain; no supernatural economy exists. [Tone boundary](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:591).

**Player problem:** Explaining every strange event as a stat reward would flatten the fantasy; constant ambiguity without payoff would also frustrate.

**Recommendation:** Author a few optional moments whose ordinary meaning is clear but cause remains open: a remembered dream draws attention to a real landmark; a song seems apt after a rescue. Give a practical clue or emotional recollection, not proof of magic. Different residents can interpret the same event differently without a theological faction system. Avoid repeatable triggers that players farm.

**Comparable reference:** Researched—[Stardew Valley](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/): environmental events; [Dwarf Fortress](https://store.steampowered.com/app/975370/Dwarf_Fortress/): history and culture.

**Connects to:** Riddles, hero arcs, songs, quiet seasonal life. Related designs: [ECO-044](/Users/brendan/Developer/redwall-review/REVIEW.md:3395), [UX-018](/Users/brendan/Developer/redwall-review/REVIEW.md:5370), [UX-020](/Users/brendan/Developer/redwall-review/REVIEW.md:5418).

**Impact:** Med.

**Effort:** M for a few authored moments after narrative infrastructure.

**Priority:** Later.

<a id="soc-f10"></a>

#### SOC-F10 — Progression, scenarios and endings

| Lens | Assessment |
|---|---|
| Feel | A session needs an achievable accomplishment and a new possibility. |
| Depth | Goals should permit different resilient settlements, not one compulsory growth route. |
| Expression | Cozy small towns need access to expressive systems even when large settlements remain the main scale. |
| Interconnection | Milestones should reward competence across systems without making every system a checklist. |
| Progression | Current adopted population/calendar gates risk withholding the next interesting toy after the player understands the preceding one. |
| Readability | Distinguish achieved accomplishments from live conditions. |
| Theme | A Charter should affirm a community's story. |
| Benchmark | Researched: [Anno 1800](https://www.anno-union.com/devblog-residential-tiers/), [Against the Storm](https://eremitegames.com/quality-of-life-update-3/), [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th). **Pitfall / transfer limit:** Avoid mandatory restart cycles or long population waits. |

**Related owners:** [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380), [UX-017](/Users/brendan/Developer/redwall-review/REVIEW.md:5346), [UX-024](/Users/brendan/Developer/redwall-review/REVIEW.md:5525).

<a id="soc-031"></a>

##### SOC-031 — Competence before scale gates

**Type:** Change

**Current state:** M1–M3 bundle calendar, population and accomplishments; many capabilities wait for those bundles. [Milestones](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:795).

**Player problem:** Understanding a system does not necessarily let me try its interesting extension; I may need to expand or wait first.

**Recommendation:** Separate the first useful form of a system from its large-scale form. A functioning meal service can permit a modest feast; one trained mentor can teach before a population threshold. Growth should unlock capacity, specialization and administrative convenience. Retain visible milestone celebrations, but release two or three related options at a time. Coordinate food-specific thresholds with ECO's chain proposals.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/devblog-residential-tiers/): aggregate services; [Against the Storm](https://eremitegames.com/quality-of-life-update-3/): developed-town pacing.

**Connects to:** Feasts, mentoring, production, small-town expression. Related designs: [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380), [UX-017](/Users/brendan/Developer/redwall-review/REVIEW.md:5346), [UX-024](/Users/brendan/Developer/redwall-review/REVIEW.md:5525).

**Impact:** High.

**Effort:** M for a redesigned unlock schedule after progression ownership.

**Priority:** Now.

<a id="soc-032"></a>

##### SOC-032 — Three distinct settlement premises

**Type:** Extension

**Current state:** Founding, restoration and established-community premises are adopted, but the finite playable lineup is unfilled. [Scenario direction](/Users/brendan/Developer/redwall-review/docs/setting_decisions.md:126).

**Player problem:** A new map alone may repeat the same opening and same optimal build order.

**Recommendation:** Prototype three original scenarios: a new refuge with limited infrastructure; restoration of a damaged but culturally established place; stewardship of a functioning large community facing a seasonal obligation. Give each different initial assets, one real constraint and an identifiable accomplishment. An Abbey or novel-era adaptation needs separate corpus/chronology validation. Do not rely on shuffled resource scarcity alone.

**Comparable reference:** Researched—[Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): campaign formats; [Against the Storm](https://eremitegames.com/explorers-choice-update/): alternative approaches.

**Connects to:** Onboarding, production, institutions, environment, story. Related designs: [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380), [UX-017](/Users/brendan/Developer/redwall-review/REVIEW.md:5346), [UX-024](/Users/brendan/Developer/redwall-review/REVIEW.md:5525).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** stable settlement loop and scenario data. **Implementation slices:** founding benchmark → restoration reuse → established stewardship. **Minimum useful prototype:** two openings with different first three decisions. **Player acceptance criteria:** players describe their goals differently without reading a long briefing. **Recommended direction / tradeoff:** recommend few authored premises before a large procedural scenario generator.

<a id="soc-033"></a>

##### SOC-033 — Charter proofs of a way of life

**Type:** Change

**Current state:** M4 requires a large combined checklist and a continuous three-winter-day interval; victory permits continuation. [M4](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:801).

**Player problem:** The ending can become waiting for every meter to remain correct rather than deciding what kind of community I built.

**Recommendation:** Replace the single universal qualification with scenario-scaled proofs under resilience, knowledge and fellowship. Each pillar offers two or three equivalent accomplishments; completed historical proofs remain earned, while an explicit final readiness check covers current essentials. Retain 120 residents as a large-community scenario goal where appropriate, not a universal gate to all civic recognition. After signing, choose one ongoing commitment and continue freely.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/quality-of-life-update-3/): developed-town pacing; [Timberborn](https://store.steampowered.com/app/1062090/Timberborn/): civic monuments.

**Connects to:** Milestones, customs, food resilience, training, feasts. Related designs: [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380), [UX-017](/Users/brendan/Developer/redwall-review/REVIEW.md:5346), [UX-024](/Users/brendan/Developer/redwall-review/REVIEW.md:5525).

**Impact:** High.

**Effort:** L for authored alternative proofs and ending.

**Priority:** Next.

**Plan:** **Prerequisites:** reliable accomplishment evidence and scenario goals. **Implementation slices:** one alternative per pillar → readiness ceremony → continued-life commitment. **Minimum useful prototype:** two differently built communities can qualify. **Player acceptance criteria:** players can identify earned progress and the one remaining decision. **Recommended direction / tradeoff:** recommend equivalent proofs; retaining the exact checklist is simpler but rewards less expression.

<a id="soc-034"></a>

##### SOC-034 — An explicit cozy contract

**Type:** Change

**Current state:** Sandbox retains survival rules; current demo hazards are harmless, while future combat is outside release-one settlement scope. [Sandbox/disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:826), [release boundary](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:728).

**Player problem:** “Cozy” can mean different things, and a player should not discover the game's loss rules through a beloved resident's death.

**Recommendation:** Offer named presets backed by three understandable axes: ecological pressure, consequence severity, and conflict involvement. Gentle can preserve injury, recovery and setbacks while protecting lives; standard retains the adopted survival consequences; tactical participation can be elective until a campaign explicitly declares otherwise. Difficulty changes disclose future effects and never retroactively revive or remove people. Pause and planning tools remain available across presets.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): personal causes; [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): deliberate tactical orders.

**Connects to:** Hazards, recovery, scenario setup, military campaigns. Related designs: [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380), [UX-017](/Users/brendan/Developer/redwall-review/REVIEW.md:5346), [UX-024](/Users/brendan/Developer/redwall-review/REVIEW.md:5525).

**Impact:** High.

**Effort:** L because these are behavior contracts, not just settings labels.

**Priority:** Now for design; implementation follows real consequence systems.

**Plan:** **Prerequisites:** enumerated outcomes and event ownership. **Implementation slices:** survival presets → event preview/recovery → separate future conflict choice. **Minimum useful prototype:** the same failure has understandable gentle/standard outcomes. **Player acceptance criteria:** players accurately predict who/what can be lost from setup text. **Recommended direction / tradeoff:** recommend explicit axes behind presets; a single difficulty multiplier cannot express these preferences.

<a id="soc-035"></a>

##### SOC-035 — Two routes into the hybrid game

**Type:** Extension

**Current state:** No current battle or complete campaign exists; adopted scenario premises permit established starts. [Scenario task](/Users/brendan/Developer/redwall-review/docs/tasks/08_community_scenarios_progression.md:15), [tactical scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:621).

**Player problem:** Cozy players may not want early military pressure, while battle-focused players may leave before an army is available.

**Recommendation:** Keep a settlement-first career and add an established-home tactical prologue once battles work. The latter begins with a supplied small force and a readable mission, then returns to a functioning home with one care/supply decision. Both enter the same larger systems. A standalone practice battle should teach orders without affecting a save; it is not evidence of an integrated campaign.

**Comparable reference:** Researched—[Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): campaign formats; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys.

**Connects to:** Onboarding, squads, home care, scenario variants. Related designs: [ECO-008](/Users/brendan/Developer/redwall-review/REVIEW.md:2380), [UX-017](/Users/brendan/Developer/redwall-review/REVIEW.md:5346), [UX-024](/Users/brendan/Developer/redwall-review/REVIEW.md:5525).

**Impact:** High.

**Effort:** L.

**Priority:** Later, after a good tactical slice.

**Plan:** **Prerequisites:** [SOC-036](/Users/brendan/Developer/redwall-review/REVIEW.md:4632)–[SOC-040](/Users/brendan/Developer/redwall-review/REVIEW.md:4728) mission and return loop. **Implementation slices:** practice encounter → established-home prologue → merge into career. **Minimum useful prototype:** one battle and one consequential homecoming. **Player acceptance criteria:** battle players reach a meaningful order decision quickly; cozy players can postpone this path. **Recommended direction / tradeoff:** recommend alternate starts over forcing every player through the same military unlock grind.

<a id="soc-f11"></a>

#### SOC-F11 — Squads, defense and military lives

| Lens | Assessment |
|---|---|
| Feel | The target is understandable group intent, weight and recoverable pressure; there is no current combat feel to judge. |
| Depth | Terrain, formation, fatigue, reserves and morale should decide encounters. |
| Expression | Squad doctrines and deployment should support different commanders. |
| Interconnection | People, equipment, supplies, care and returning veterans connect battle to home. |
| Progression | Experience should broaden reliable options, not make heroes solo armies. |
| Readability | Show the cause of wavering and the limits of an order before catastrophic commitment. |
| Theme | Collective courage and protection fit better than endless extermination. |
| Benchmark | Researched: [Total War: ROME II](https://r2encv2.totalwar.com/en/manual/single-player/0081_enc_page_battle_play_phase_conflict_army_formations/index.html), [Total War: ROME II](https://r2enc.totalwar.com/en/manual/single-player/0087_enc_page_battle_play_phase_conflict_morale/), [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th). **Pitfall / transfer limit:** Avoid importing cavalry, firearms or magical abilities simply because a benchmark has them. |

**Related owners:** [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841).

<a id="soc-036"></a>

##### SOC-036 — Readable mixed-squad doctrines

**Type:** New system

**Current state:** A battle architecture fixture specifies mixed sword/spear/bow squads; it is not a playable army. [Squad/contact design](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:742).

**Player problem:** If every squad does everything, composition becomes cosmetic and tactical counters disappear.

**Recommendation:** Prototype three doctrines: line defenders, ranged support and mobile flankers. A squad may contain support weapons, but its training and majority equipment establish a readable primary role and weakness. Preserve species diversity within doctrine. Let players save a template and replace missing equipment with an explicitly weaker substitute; do not require per-model outfitting. Start without a vast weapon tier tree.

**Comparable reference:** Researched—[Total War: ROME II](https://r2encv2.totalwar.com/en/manual/single-player/0081_enc_page_battle_play_phase_conflict_army_formations/index.html): formation intent; [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): deliberate tactical orders.

**Connects to:** Equipment, training, body affordances, formations, muster. Related designs: [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841).

**Impact:** High.

**Effort:** L; future tactical scope.

**Priority:** Next as a standalone design prototype.

**Plan:** **Prerequisites:** playable movement/contact combat and a basic opponent. **Implementation slices:** three fixed doctrines → one constrained composition choice → equipment shortages. **Minimum useful prototype:** a small battle where all three roles matter. **Player acceptance criteria:** players identify each squad's job and two viable compositions win by different plans. **Recommended direction / tradeoff:** recommend coherent mixed squads; completely homogeneous units are clearer but lose some community texture.

<a id="soc-037"></a>

##### SOC-037 — Formations shaped by terrain

**Type:** New system

**Current state:** Facing, compression and cohesion are specified; no battle-order interaction is delivered. [Formation fixture](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:677), [orders](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:929).

**Player problem:** Formation tools can feel decorative or punish me with hidden movement failures.

**Recommendation:** Begin with line, column and loose order. A dragged frontage previews facing, occupied width and fit; queued waypoints preserve intent through a narrow crossing and re-form at a chosen safe point. Show the time/space needed to form up. Dense order protects a front but maneuvers poorly; loose order sacrifices local concentration for movement and projectile resilience. Exact advantages require combat testing.

**Comparable reference:** Researched—[Total War: ROME II](https://r2encv2.totalwar.com/en/manual/single-player/0081_enc_page_battle_play_phase_conflict_army_formations/index.html): formation intent; [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): deliberate tactical orders.

**Connects to:** Bridges/tunnels as future battle terrain, missile roles, morale. Related designs: [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841).

**Impact:** High.

**Effort:** L; future tactical scope.

**Priority:** Next with the first battle slice.

**Plan:** **Prerequisites:** [SOC-036](/Users/brendan/Developer/redwall-review/REVIEW.md:4632) and trustworthy group movement. **Implementation slices:** frontage/facing → three formations → planned constriction crossing. **Minimum useful prototype:** one bridge and one wooded flank. **Player acceptance criteria:** players predict where formation breaks and can recover without selecting individuals. **Recommended direction / tradeoff:** recommend three consequential formations before a large historical preset catalog.

<a id="soc-038"></a>

##### SOC-038 — Morale, reserves and withdrawal

**Type:** New system

**Current state:** Morale/rout/rally are architecture-level intentions only. [Morale fixture](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:773).

**Player problem:** Fighting until every model dies removes tension around commitment and recovery.

**Recommendation:** Show steady, pressured, wavering and routing with two dominant causes, such as exposed flank or exhaustion. A fresh reserve can relieve a tired line; an orderly withdrawal preserves more people but yields ground. A captain helps nearby organization through position and time, not a spammable magical reset. Regroup requires a reasonably safe destination; repeated immediate re-entry should retain fatigue and confidence consequences.

**Comparable reference:** Researched—[Total War: ROME II](https://r2enc.totalwar.com/en/manual/single-player/0087_enc_page_battle_play_phase_conflict_morale/): morale and rally; [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): deliberate tactical orders.

**Connects to:** Formation, training, captains, casualty policy, return care. Related designs: [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841).

**Impact:** High.

**Effort:** L; future tactical scope.

**Priority:** Next with contact combat.

**Plan:** **Prerequisites:** clear combat roles and retreat movement. **Implementation slices:** visible morale causes → ordered withdrawal → reserve relief and captain recovery. **Minimum useful prototype:** win by routing rather than annihilation. **Player acceptance criteria:** players explain a break and successfully preserve a losing squad. **Recommended direction / tradeoff:** recommend morale-led resolution; hit-point-only combat is simpler but less tactical and more attritional.

<a id="soc-039"></a>

##### SOC-039 — Persistent people and army scale

**Type:** New system

**Current state:** The adopted living/admission ceiling is 256, while the battle fixture targets much larger forces; no recruitment/muster exists. [Living population ceiling](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:780), [battle envelope](/Users/brendan/Developer/redwall-review/docs/crowd_rendering_architecture.md:27), [shared identity](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:905).

**Player problem:** Armies must not appear from nowhere, duplicate citizens or leave the economy inexplicably short-staffed.

**Recommendation:** Start with a small resident militia, perhaps four squads of 12–20 for the prototype. Muster previews lost civilian capacity, equipment, training and food reserve impact. In the later large-battle design, distinguish resident companies from persistent allied/external companies with their own recruitment source and supply obligations; do not silently map hundreds of models onto 256 residents. Named captains and veterans cross layers as real identities. Demobilization returns people through care and rest.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/devblog-residential-tiers/): aggregate services; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys; [Total War: ROME II](https://r2enc.totalwar.com/en/manual/single-player/0087_enc_page_battle_play_phase_conflict_morale/): morale and rally.

**Connects to:** Crews, craft chains, food, care, diplomacy, hero arcs. Related designs: [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841).

**Impact:** High.

**Effort:** L; future tactical/campaign scope.

**Priority:** Next after standalone combat is engaging.

**Plan:** **Prerequisites:** population ownership, supplies and [SOC-036](/Users/brendan/Developer/redwall-review/REVIEW.md:4632)–[SOC-038](/Users/brendan/Developer/redwall-review/REVIEW.md:4680). **Implementation slices:** local muster/return → drill/equipment → allied-company contract. **Minimum useful prototype:** leaving four workers visibly affects one home service, then they return correctly. **Player acceptance criteria:** every deployed person/company has an explainable source and consequence. **Recommended direction / tradeoff:** recommend local militia plus explicit allies for larger battles; expanding civilian population to match every army is plausible but requires a separate scale decision and performance qualification.

<a id="soc-040"></a>

##### SOC-040 — Protection and maneuver missions

**Type:** New system

**Current state:** No authored tactical objectives or opponents are active. [Conflict scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:621).

**Player problem:** Repeated annihilation battles would flatten heroism and make peace-time preparation feel unrelated.

**Recommendation:** Prototype a crossing held until a group escapes, a supply escort with two routes, and a withdrawal that preserves a wounded company. Add optional objectives with known trade-offs: rescue extra adults, save supplies or deny a route. Success can be partial and still move the story. Aim initially for encounters of roughly 10–20 minutes including pauses; validate that pacing instead of promising it. No civilian-cruelty spectacle or hunting objective.

**Comparable reference:** Researched—[Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): campaign formats; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys.

**Connects to:** Terrain, logistics, rescue, antagonists, returning stories. Related designs: [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841).

**Impact:** High.

**Effort:** L; future tactical scope.

**Priority:** Next after basic tactics.

**Plan:** **Prerequisites:** [SOC-036](/Users/brendan/Developer/redwall-review/REVIEW.md:4632)–[SOC-038](/Users/brendan/Developer/redwall-review/REVIEW.md:4680), objective state and fair enemy behavior. **Implementation slices:** one hold/escape mission → alternate route → partial-success return. **Minimum useful prototype:** win while withdrawing. **Player acceptance criteria:** at least two plans succeed, and casualties are not the only measure of performance. **Recommended direction / tradeoff:** recommend few systemic objectives before a long sequence of bespoke scripted battles.

<a id="soc-041"></a>

##### SOC-041 — Defensible lived-in places

**Type:** Extension

**Current state:** Lookouts/fences/walls are settlement catalog or hazard concepts; release-one settlement does not include raids or siege. [Defense catalog](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:656), [boundary](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:728).

**Player problem:** A later defense game could turn every attractive settlement into the same exploitative choke point.

**Recommendation:** In a future conflict scenario, preview approach corridors, rally points and safe evacuation destinations. Walls buy time and redirect movement; gates and civilian access remain useful between battles. Limit defense by staffing, sightlines and access, not arbitrary build caps. Offer fallback positions and an evacuation victory so losing an outer line need not destroy a beloved town. ECO owns ordinary route infrastructure.

**Comparable reference:** Researched—[Total War: ROME II](https://r2encv2.totalwar.com/en/manual/single-player/0081_enc_page_battle_play_phase_conflict_army_formations/index.html): formation intent; [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): deliberate tactical orders.

**Connects to:** Construction, route design, lookouts, squads, care. Related designs: [ECO-019](/Users/brendan/Developer/redwall-review/REVIEW.md:2693), [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841).

**Impact:** High.

**Effort:** L; new conflict scope.

**Priority:** Later.

**Plan:** **Prerequisites:** tactical terrain and damage/evacuation contract. **Implementation slices:** one defensive map → civilian fallback → persistent repair choice. **Minimum useful prototype:** outer defense and inner refuge with two approaches. **Player acceptance criteria:** two attractive layouts remain defensible and retreat preserves meaningful assets. **Recommended direction / tradeoff:** recommend authored early defenses; unrestricted procedural siege is a much larger commitment.

<a id="soc-f12"></a>

#### SOC-F12 — Campaign, trade and outside communities

| Lens | Assessment |
|---|---|
| Feel | Leaving should make returning home meaningful, while the home player retains control over pacing. |
| Depth | Commitments, routes, preparation and diplomacy should create alternatives to fighting. |
| Expression | Protect, trade, aid or withdraw as circumstances permit. |
| Interconnection | Regional relationships must alter real local opportunities and obligations. |
| Progression | A small persistent region can deepen before a vast map is justified. |
| Readability | Communicate elapsed home time, return costs and hostile intent. |
| Theme | Places and adversaries need motives rather than species-based alignment. |
| Benchmark | Researched: [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/), [RimWorld](https://rimworldgame.com/), [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th). **Pitfall / transfer limit:** Avoid copying a full 4X game or making every friendship an exchange-rate buff. |

**Related owners:** [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457).

<a id="soc-042"></a>

##### SOC-042 — Seasonal barter and trust

**Type:** New system

**Current state:** No active trade/currency economy exists; outside-community scope is open. [Economy/world boundary](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:567), [campaign opening](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:1003).

**Player problem:** A self-sufficient settlement can exhaust meaningful surplus uses; a generic sell-everything market would also flatten local character.

**Recommendation:** Start with two authored neighbors and seasonal contracts: offer preserved plant/fish food or craft goods in exchange for a scarce material, knowledge or reciprocal aid. State quantities, travel time and the next likely need. Allow partial fulfillment or renegotiation with understandable relationship consequences. Keep core survival recoverable without trade and cap demand to prevent an infinite profitable loop. Neighbors have production identities, not species monopolies.

**Comparable reference:** Researched—[RimWorld](https://rimworldgame.com/): caravans; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys.

**Connects to:** ECO surplus/preservation/logistics, visitors, diplomacy. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457).

**Impact:** High.

**Effort:** L.

**Priority:** Later.

**Plan:** **Prerequisites:** real surplus, transport costs and neighbor identity. **Implementation slices:** one barter → seasonal demand → aid contract. **Minimum useful prototype:** two locally sensible exchanges. **Player acceptance criteria:** players can explain why each side wants the goods and choose to decline. **Recommended direction / tradeoff:** recommend bounded barter first; a universal price market is broader but less distinctive and harder to balance.

<a id="soc-043"></a>

##### SOC-043 — An antagonist with legible intent

**Type:** New system

**Current state:** No active named villain is selected; motives and future conflict are direction only. [Antagonist scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:635).

**Player problem:** Random attacks would feel like a timer imposed on a cozy town, while an abstract villain has no personal meaning.

**Recommendation:** Author one original adversary with a concrete objective, such as control of a crossing or tribute from an outlying community. Reveal intention through scouts, visitors and visible preparations. Offer at least two responses—protect a route, aid an ally, bargain where credible or evacuate threatened assets. Successful counterplay changes the next move; do not instantly scale enemy strength to erase preparation. Morality follows deeds, not species.

**Comparable reference:** Researched—[Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): narrative campaign; [Against the Storm](https://eremitegames.com/explorers-choice-update/): alternative approaches.

**Connects to:** Scouting, diplomacy, missions, feasts/homecoming, hero arcs. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457).

**Impact:** High.

**Effort:** L.

**Priority:** Later.

**Plan:** **Prerequisites:** missions, regional state and conflict opt-in. **Implementation slices:** one intention → two responses → persistent reaction. **Minimum useful prototype:** a threatened crossing with a negotiable or defensive response. **Player acceptance criteria:** players explain the adversary's goal and can anticipate the next risk. **Recommended direction / tradeoff:** recommend authored intent before a procedural political simulator.

<a id="soc-044"></a>

##### SOC-044 — A clear mission clock

**Type:** Change

**Current state:** Future transfers preserve identities and supplies, but no destination consumer or shared-clock policy is chosen. [Transfers](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:899).

**Player problem:** Tactical pauses might secretly starve the settlement, or expeditions might have no opportunity cost at all.

**Recommendation:** Recommend a chapter clock for the first hybrid version: preparation and travel consume stated world time; tactical play/pause does not run hidden home production; the mission then applies its declared time window before a reviewed return. Preview home reserves and absent labor before departure. Return shows people, injuries, equipment and supplies together, with care priorities available before normal simulation resumes. Campaign-time uncertainty should be explicit, bounded and forecast.

**Comparable reference:** Researched—[Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): tactical pause; [Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): preparation and recall.

**Connects to:** Muster, schedules, food age, recovery, saves, campaign. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457).

**Impact:** High.

**Effort:** M for policy/prototype after L mission and transfer foundations.

**Priority:** Now as a design decision; later as gameplay.

**Plan:** **Prerequisites:** one outbound/return mission. **Implementation slices:** declared travel window → paused tactical clock → reviewed return. **Minimum useful prototype:** one journey with an identical home outcome regardless of battle-pause duration. **Player acceptance criteria:** players predict reserve cost and can cancel before departure. **Recommended direction / tradeoff:** recommend chapter time initially; fully parallel simulation is immersive but demands stronger automation and crisis handling.

<a id="soc-045"></a>

##### SOC-045 — A small persistent region

**Type:** New system

**Current state:** No active campaign, diplomacy or multiple-settlement loop exists. [Open campaign scope](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:1003).

**Player problem:** Isolated battles lack lasting meaning, while a huge campaign could bury the home colony under map maintenance.

**Recommendation:** Begin with one home and roughly six to eight persistent regional places: two neighbors, a contested crossing, an old site, a safe haven and one hostile stronghold. Travel, aid, trade and missions change access and relationships. Revisit a place in a different season or after a decision, rather than fill the map with disposable fights. Conclude an authored arc with a peace/settlement consequence and allow continued home life; no compulsory conquest of every node.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/im-going-on-an-adventure/): prepared journeys; [Company of Heroes 3](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th): campaign formats.

**Connects to:** Trade, antagonist, lore, tactical missions, Charter. Related designs: [ECO-028](/Users/brendan/Developer/redwall-review/REVIEW.md:2941), [SOC-039](/Users/brendan/Developer/redwall-review/REVIEW.md:4704), [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457).

**Impact:** High.

**Effort:** L.

**Priority:** Later.

**Plan:** **Prerequisites:** missions, return consequences and two reliable neighbors. **Implementation slices:** three linked places → branching consequence → full small-region arc. **Minimum useful prototype:** revisit one place after helping or declining it. **Player acceptance criteria:** players remember local people and can explain how an earlier choice changed access. **Recommended direction / tradeoff:** recommend a dense region first; a large procedural map should follow proven variety rather than supply empty scale.

<a id="ux-f01"></a>

#### UX-F01 — Controls, camera and selection

| Lens | Assessment |
|---|---|
| Feel | Orbiting, selecting and issuing local work orders already provide the promising pleasure of directing a small working party. The camera and control surface are tuned for that scale; they do not yet establish a comfortable rhythm of delegating a district, checking a named hero, and returning to a distant project. [Camera](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:39), [orders](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:595). |
| Depth | Body/load-sensitive travel can make choosing a crew interesting. Repeated individual selection is a cost of expressing a choice, not additional strategic depth. The proposed game needs persistent intentions, safe interruption and visible delegation so choices survive more than one click. [Ability descriptions](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:40). |
| Expression | Box selection and formation destinations allow local grouping; saved crews, camera places and reusable orders are not an integrated live workflow. Later squad commands should share selection conventions while remaining distinct from civilian staffing. [Selection](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:443), [adopted group/queue controls](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:301). |
| Interconnection | Selection should link to Work, routes, safety, carried cargo and named-character journals. Selection currently favors individual domain panels and the small party inspector. [Party entries](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:732). |
| Progression | Early direct commands can teach work; later players should govern policies and intervene in exceptions. Requiring the same number of clicks per anonymous resident at population 120 would make growth a punishment. This is an inference against the intended scale, not a measured late-game failure. [Population target](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:799). |
| Readability | A player needs to distinguish selected, assigned, currently doing and queued next. These are different relationships; a single list of names/activity prose cannot carry all four at scale. [Party rows](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:194). |
| Theme | Asking a forester crew to open a safe route fits stewardship; permanently puppeteering every woodland resident weakens the feeling of a self-directed community. Retain expressive exceptions for heroes and rescue. |
| Benchmark | Researched: [Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/), [Factorio](https://www.factorio.com/blog/post/fff-380). **Pitfall / transfer limit:** The useful lesson is command continuity, not competitive clicking speed or instantaneous Redwall labor. |

**Related owners:** [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [SOC-037](/Users/brendan/Developer/redwall-review/REVIEW.md:4656).

<a id="ux-001"></a>

##### UX-001 — Commands at three management scales

**Type:** Change

**Current state:** The live party supports direct orders for nine actors and displays up to six rows; later policy/queue controls are adopted but not a connected large-colony workflow. [Commands](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:595), [party](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:66), [control specification](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:301).

**Player problem:** “I want this crossing finished, but I have to keep telling particular people what to do. Growing the village will multiply my chores.”

**Recommendation:** Offer three explicit selection scopes: **place/project**, **work crew**, **named person**. Project orders request a result and eligible labor; saved crews request a role mix; named-person orders are temporary exceptions with a visible return-to-routine condition. A bridge plan could request “one builder, two carriers, safe routes only,” then show 2/3 staff available. A mixed selected group previews eligibility without silently assigning unsuitable residents. Ordinary anonymous labor remains aggregated; future battle selection targets whole squads.

**Comparable reference:** Researched—[Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): command continuity; [Factorio](https://www.factorio.com/blog/post/fff-380): remote continuity.

**Connects to:** SOC labor and squad design; ECO hauling/body access; [UX-007](/Users/brendan/Developer/redwall-review/REVIEW.md:5061) Work policies. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [SOC-037](/Users/brendan/Developer/redwall-review/REVIEW.md:4656).

**Impact:** High.

**Effort:** L.

**Priority:** Now.

**Plan:** **Prerequisites:** truthful selection/job state and safe resume from Phase 1, one connected staffing loop. **Implementation slices:** (1) project intent and eligibility preview; (2) saved crew with replacement policy; (3) temporary named-person override and clear release; (4) expose the same intent in Work. **Minimum useful prototype:** one bridge and one harvest crew, no autonomous cross-system optimizer. **Player acceptance criteria:** in a 48-resident scenario, four of five testers complete two projects and release an intervention without opening individual anonymous journals; all can identify why a requested slot is unfilled. **Recommended direction / tradeoff:** recommend role-based crews before persistent individually rostered labor teams; reserve individual rosters for heroes and squads.

<a id="ux-002"></a>

##### UX-002 — An editable order sequence

**Type:** QoL

**Current state:** Direct contextual commands and job-resume descriptions exist; the control spec describes an eight-task queue. There is no live, general queue ribbon the player can inspect and rearrange. [Party fill](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:194), [adopted queue](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:301).

**Player problem:** “Did that click replace the harvest, add a trip, or strand the carried food? I cannot see what I have asked for.”

**Recommendation:** Show **Now → Next → Return** for the selected crew/person, with up to eight deliberate orders. Shift adds; ordinary command previews replacement; drag reorders pending entries; remove cancels only the chosen pending task. Completed work stays completed. An undo chip names the recent command, its target and any irreversible work already done: undo can restore intent or cancel remaining work, never resurrect consumed materials. A safety interruption appears above the queue and explicitly preserves or cancels affected work.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-412): reviewable undo.

**Connects to:** Job resume, safe interruption, construction cancellation, rescue, future squad waypoints. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [SOC-037](/Users/brendan/Developer/redwall-review/REVIEW.md:4656).

**Impact:** High.

**Effort:** M **after** durable queues/resume are connected; integrating those underlying behaviors remains larger work.

**Priority:** Now.

<a id="ux-003"></a>

##### UX-003 — Camera places and return paths

**Type:** QoL

**Current state:** Orbit/pan/zoom/pitch/Home work, while follow and saved-place controls are not a complete live flow. [Camera input](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:170), [camera step](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:246).

**Player problem:** “Checking a warning makes me lose the garden I was arranging. I spend more effort finding the place again than deciding what to do.”

**Recommendation:** Introduce **Peek**, **Go to**, **Follow** and **Back** as separate actions. Hovering a notice offers a small spatial preview; Go to records the previous camera/layer; Back restores it. Save six named views with thumbnail and layer (Hall, West fields, Lower passage), and allow one-key cycling through active projects. Selection does not move the camera by default. Following a worker can hand off to the correct layer at an entrance, with reduced-motion snapping as an option. F53 occlusion repair is a prerequisite, not this feature.

**Comparable reference:** Researched—[Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): camera locations; [Factorio](https://www.factorio.com/blog/post/fff-380): remote continuity.

**Connects to:** Layered atlas, incident handling, named heroes, construction, accessibility. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [SOC-037](/Users/brendan/Developer/redwall-review/REVIEW.md:4656).

**Impact:** Med.

**Effort:** M; persistent bookmarks require the save flow in [UX-021](/Users/brendan/Developer/redwall-review/REVIEW.md:5457).

**Priority:** Next.

<a id="ux-004"></a>

##### UX-004 — A shared command vocabulary

**Type:** QoL

**Current state:** Several domain-specific tool handlers and keys coexist with shell commands and hover instructions. [Demo command input](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_command.gd:377), [tunnel keys](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_control.gd:294), [tips](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_command_tips.gd:29).

**Player problem:** “I remember what I want to accomplish, but not which tab or letter does it.”

**Recommendation:** A searchable action palette lists verbs valid for the current scope: “water selected beds,” “show blocked work,” “find warm beds,” “release crew.” Each result displays scope, consequence and the current rebound shortcut. Mouse context menus, dock buttons and keyboard invoke those same named actions. Add sticky tool choice for repeated painting and a plainly visible **Done** exit. Hold modifiers accelerate expert work but never provide the only route to an action. Keep diagnostic event/weather triggers in a separately named developer surface, following Phase 1 cleanup.

**Comparable reference:** Researched—[Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): remapping categories; [Factorio](https://www.factorio.com/blog/post/fff-397): linked knowledge.

**Connects to:** Onboarding, accessible world list, bulk actions, controls remapping. Related designs: [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749), [ECO-039](/Users/brendan/Developer/redwall-review/REVIEW.md:3256), [SOC-037](/Users/brendan/Developer/redwall-review/REVIEW.md:4656).

**Impact:** Med.

**Effort:** M after F30/F35 keyboard/scale primitives and each underlying action work.

**Priority:** Next.

<a id="ux-f02"></a>

#### UX-F02 — Information architecture and management screens

| Lens | Assessment |
|---|---|
| Feel | Domain tabs offer accessible local experiments, but switching between them asks the player to remember a comparison. Pantry, roster, world list and general shell are separate partial concepts, not one management model. [Tabs](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_detail_zone.gd:44), [workspace](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1396). |
| Depth | There is substantial underlying state to interpret, yet no connected decision surface for “make a feast while preserving winter reserves.” Raw values are ingredients of a decision; they are not the decision interface. [Pantry relationships](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:228), [intended reserves](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:600). |
| Expression | Players cannot establish personal watchlists, district scopes, comparison columns or household/work policies through a unified surface. A cozy builder should be able to watch community comfort while an optimizer watches throughput without separate game modes. [Resource build](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:872). |
| Interconnection | Stock, production demand, worker availability, planned commitments and community needs should cross-link. A stored ingredient should link to its uses and consumers, a blocked job to its input, and that input to actual stock locations. |
| Progression | Information should expand in analytical power as the village grows while retaining the same homes for data. Replacing the early layout at every population tier would force relearning. |
| Readability | Distinguish “this object,” “all objects like it,” “settlement totals,” “future commitments,” and “historical change.” These are five scopes presently mixed in dense textual surfaces. [Farm inspector](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:1), [tunnel inspector](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_panel.gd:31). |
| Theme | A steward's ledger can be warm and tactile while having a clear grid. The parchment treatment should frame information rather than turn every number into ornamental prose. [Woodland skin](/Users/brendan/Developer/redwall-review/godot/demo/ui/woodland_skin.gd:1). |
| Benchmark | Researched: [Against the Storm](https://eremitegames.com/1-2-update/), [Farthest Frontier](https://www.farthestfrontier.com/guide/information/annual-report/), [Factorio](https://www.factorio.com/blog/post/fff-397). **Pitfall / transfer limit:** Their lesson is navigable relationships. The pitfall is borrowing every graph before the corresponding Redwall decision exists. |

**Related owners:** [ECO-035](/Users/brendan/Developer/redwall-review/REVIEW.md:3126), [SOC-009](/Users/brendan/Developer/redwall-review/REVIEW.md:3878), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749).

<a id="ux-005"></a>

##### UX-005 — Stable information homes

**Type:** Change

**Current state:** The shell command dock and workspace coexist with four domain tabs and Pantry; registry breadth exceeds reachable workflows. [Dock](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:204), [workspace pages](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:251), [tabs](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_detail_zone.gd:44).

**Player problem:** “I can find many numbers but not the place that answers my question. Closing one screen makes me forget what I was comparing.”

**Recommendation:** Adopt the information-ownership table above: Stores; Work; Build & Plans; Community; Chronicle; Almanac & Goals; contextual inspector, with future Defense & Company only when functional. Keep the strategic workspace and a selected-object inspector independently visible at wide sizes; switch between them with preserved state at narrow sizes. Every crosslink has Back, saved scope and scroll position. Example: low meal outlook → Stores Meals → consumption/production → kitchen inspector → blocked flour → mill → return to the original meals comparison. Rename or merge existing domain tabs around these tasks rather than building 103 separate destinations.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/1-2-update/): resource history; [Factorio](https://www.factorio.com/blog/post/fff-380): remote continuity.

**Connects to:** Every management system; future army; Phase 1 P1/F45 are prerequisites, not duplicate work. Related designs: [ECO-035](/Users/brendan/Developer/redwall-review/REVIEW.md:3126), [SOC-009](/Users/brendan/Developer/redwall-review/REVIEW.md:3878), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749).

**Impact:** High.

**Effort:** L.

**Priority:** Now.

**Plan:** **Prerequisites:** unified authoritative village data and clear runtime scope from Phase 1. **Implementation slices:** (1) paper/tree-test navigation with ten real tasks; (2) Stores/Work plus context/Back; (3) Community/Plans; (4) Chronicle/Almanac and future-defense boundary. **Minimum useful prototype:** one resource → producer → blocked job → resource round trip. **Player acceptance criteria:** new players find seven of eight nominated facts in their intended home within 20 seconds; returning players recover the originating comparison without reopening menus. **Recommended direction / tradeoff:** recommend one tabbed workspace, not freely floating draggable windows or a mandatory full-screen ledger.

<a id="ux-006"></a>

##### UX-006 — Demand-based plan comparisons

**Type:** Extension

**Current state:** Pantry exposes current ingredient stock, age and library dish relationships; shell food/fuel summaries describe aggregate reserves. Neither delivers a connected comparative budget. [Pantry totals](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:192), [HUD aggregation](/Users/brendan/Developer/redwall-review/godot/scripts/systems/ui_manager.gd:624).

**Player problem:** “Thirty roots sounds useful, but can I host twelve guests and still feed the village? Would another field or a dryer help more?”

**Recommendation:** Stores should distinguish **on hand / available / committed / expected**, show recent net flow and the next meaningful horizon (tomorrow, next season, selected event). A **Compare plan** drawer contrasts two interventions using the same assumptions: another bed versus preserving surplus, or bridge versus nearer store. Show meal-days, labor-hours, spoilage exposure and capital cost, with ranges and a “not enough evidence” state. Let players apply a chosen production target or pin a plan; never automatically commission the whole chain. No fake certainty from linear extrapolation over seasons.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/1-2-update/): resource history; [Farthest Frontier](https://www.farthestfrontier.com/guide/information/annual-report/): retrospective flows.

**Connects to:** ECO food/logistics/seasonality, feast planning, construction budgets, future provisions. Related designs: [ECO-035](/Users/brendan/Developer/redwall-review/REVIEW.md:3126), [SOC-009](/Users/brendan/Developer/redwall-review/REVIEW.md:3878), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** actual eating/cooking/storage/reservation loops and a documented forecast model. **Implementation slices:** (1) observed flow and commitments; (2) one-day meal projection; (3) two-option comparison; (4) seasonal uncertainty and future-event reservations. **Minimum useful prototype:** twelve diners and one kitchen, comparing two meal targets. **Player acceptance criteria:** testers predict whether a feast jeopardizes tomorrow's meals and identify the biggest assumption; projected ranges contain outcomes in representative weather cases. **Recommended direction / tradeoff:** start with food and labor; avoid an all-resource optimizing calculator that chooses the strategy for players.

<a id="ux-007"></a>

##### UX-007 — Batch work policies and exceptions

**Type:** Extension

**Current state:** Direct orders and domain cancellation exist; general Jobs management is unbuilt. Kernel labor rules are broader than the live party. [Party work status](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:194), [Jobs dock](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:204), [jobs availability](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:172).

**Player problem:** “Before winter I need to change a policy across several places, not edit every worker and bed. Afterwards I need to know what is still overridden.”

**Recommendation:** Work defaults to projects and professions, with district/category filters, workload, staffing, blocked counts and next due need. Offer editable **Harvest week**, **Winter stores**, **Recovery**, and **Normal** presets after their underlying policies exist. Applying a preset previews affected places, people withdrawn, reserve conflicts and manual exceptions. Temporary overrides have an expiry or finish condition and a clear return policy. A single “show deviations” view catches the two sites still using an old rule. Do not make presets hidden bonuses or automatic optimal play.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/buildings/): building workflow; [Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): global queue.

**Connects to:** SOC staffing/schedules; ECO seasonal production; [UX-001](/Users/brendan/Developer/redwall-review/REVIEW.md:4906) crews; crisis recovery. Related designs: [ECO-035](/Users/brendan/Developer/redwall-review/REVIEW.md:3126), [SOC-009](/Users/brendan/Developer/redwall-review/REVIEW.md:3878), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** real labor demand and domain policies, not merely assigned labels. **Implementation slices:** (1) read-only workload/blocked board; (2) selected-site batch editing with preview; (3) named presets and exceptions; (4) expiry/restore flow. **Minimum useful prototype:** three fields and one store, changing harvest/haul emphasis. **Player acceptance criteria:** a player reallocates seasonal effort across ten sites in under a minute and correctly names what the preset leaves overridden. **Recommended direction / tradeoff:** curated editable presets first; no scripting language or opaque automatic workforce governor.

<a id="ux-008"></a>

##### UX-008 — Compare repeated objects

**Type:** QoL

**Current state:** Most live domain panels describe a single bed/tree/bore or a small party. [Bed panel](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:1), [forest panel](/Users/brendan/Developer/redwall-review/godot/demo/forestry/forest_panel.gd:25), [party panel](/Users/brendan/Developer/redwall-review/godot/demo/control/demo_party_panel.gd:41).

**Player problem:** “Which beds actually need help, and why is this store worse than the other one? I keep selecting objects and remembering numbers.”

**Recommendation:** Every repeatable object inspector offers **Compare similar**. A table starts with three decision-relevant columns, sortable exceptions and a map highlight: fields show next action/yield outlook/labor; stores show available capacity/spoilage/haul burden; households show warmth/access/occupancy. Player-added columns and filters persist. Select rows for a previewed bulk action; mixed values show “mixed,” not an arbitrary first value. Anonymous residents appear as need/role cohorts; named people can be pinned individually. This is a scalable extension, not a request to put every stat on the HUD.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/information/annual-report/): retrospective flows; [Factorio](https://www.factorio.com/blog/post/fff-397): linked knowledge.

**Connects to:** All repeated buildings/zones, household needs, Work policies, accessible world list. Related designs: [ECO-035](/Users/brendan/Developer/redwall-review/REVIEW.md:3126), [SOC-009](/Users/brendan/Developer/redwall-review/REVIEW.md:3878), [SOC-004](/Users/brendan/Developer/redwall-review/REVIEW.md:3749).

**Impact:** High.

**Effort:** M for one connected object type; broader household/store comparisons depend on their substantial underlying systems.

**Priority:** Now for beds, Next for connected families.

<a id="ux-f03"></a>

#### UX-F03 — World reading, overlays and explanations

| Lens | Assessment |
|---|---|
| Feel | Moisture, crop, forestry, water and cutaway views can reveal hidden causes directly on the land. Cycling unrelated layers and reading scattered labels is less satisfying than opening the lens relevant to a chosen question. [Overlay controls](/Users/brendan/Developer/redwall-review/godot/demo/README.md:123), [cutaway](/Users/brendan/Developer/redwall-review/godot/demo/README.md:228). |
| Depth | Access, body fit, load, soil and water make spatial planning meaningful. The missing player tool is comparative diagnosis: which of two interventions changes the limiting factor, for whom, under what condition? [Water overlay](/Users/brendan/Developer/redwall-review/godot/demo/water/water_overlay.gd:1), [dig estimate](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/dig_readout.gd:1). |
| Expression | A player's own named places, route annotations and saved lenses could externalize a personal village plan. Current overlays are developer-selected categories, and the generic minimap is not a full atlas of the visible settlement. [Minimap](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1151). |
| Interconnection | A single event can concern weather, access, work, stores and residents. A useful incident must preserve those links instead of becoming an isolated line in a news feed. [News](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_news_strip.gd:1). |
| Progression | Early overlays should answer concrete questions (“which bed needs water?”). Later they should expose distribution and resilience across districts, without hiding the place behind permanent heatmaps. |
| Readability | Every lens needs its scope, legend, time basis and unknown state. Surface and underground are navigable places, not merely display toggles. Adopted navigation already requires explicit layer, destination and travel-mode meaning. [Navigation contract](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:530). |
| Theme | An annotated survey map and practical field explanations fit a literate abbey. Omniscient exact future weather and unrestricted underground knowledge would weaken discovery; show certainty separately from estimates. |
| Benchmark | Researched: [Farthest Frontier](https://www.farthestfrontier.com/guide/information/overlays/), [Timberborn](https://store.steampowered.com/news/posts/?appgroupname=Timberborn&appids=1062090&enddate=1738766030&feed=steam_community_announcements), [Factorio](https://www.factorio.com/blog/post/fff-380). **Pitfall / transfer limit:** Avoid creating so many mandatory overlays that the attractive world becomes a menu background. |

**Related owners:** [ECO-006](/Users/brendan/Developer/redwall-review/REVIEW.md:2315), [ECO-046](/Users/brendan/Developer/redwall-review/REVIEW.md:3443), [SOC-019](/Users/brendan/Developer/redwall-review/REVIEW.md:4155).

<a id="ux-009"></a>

##### UX-009 — Map lenses by planning question

**Type:** Change

**Current state:** V cycles several overlays; underground is a separate cutaway; domain panels contain relevant state. [Overlay cycle](/Users/brendan/Developer/redwall-review/godot/demo/README.md:123), [water layer](/Users/brendan/Developer/redwall-review/godot/demo/water/water_overlay.gd:1).

**Player problem:** “I want a good field site or a safe hauling route, but I have to translate several unrelated colors and remember which layer comes next.”

**Recommendation:** Use named lens presets: **Growing**, **Getting there**, **Home & comfort**, **Work & supply**, **Underground**. Each has one primary heatmap plus optional symbols, a visible legend and an explicit scope. Selecting a build tool chooses its most relevant lens; leaving the tool restores the prior view. Growing can compare moisture/fertility without stacking opaque colors; Getting there can show unloaded, loaded and mixed-crew eligibility separately. Hold a key to temporarily peek a lens, with toggle alternatives. Phase 1 F47 is a prerequisite; this change adds intent and comparison.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/information/overlays/): spatial lenses; [Timberborn](https://store.steampowered.com/news/posts/?appgroupname=Timberborn&appids=1062090&enddate=1738766030&feed=steam_community_announcements): layered space.

**Connects to:** Agriculture, route/body fit, building placement, underground living design, future tactical sightlines. Related designs: [ECO-006](/Users/brendan/Developer/redwall-review/REVIEW.md:2315), [ECO-046](/Users/brendan/Developer/redwall-review/REVIEW.md:3443), [SOC-019](/Users/brendan/Developer/redwall-review/REVIEW.md:4155).

**Impact:** High.

**Effort:** M for existing data; comfort and future defense lenses require their own simulation.

**Priority:** Now.

<a id="ux-010"></a>

##### UX-010 — Explorable causal explanations

**Type:** New system

**Current state:** Local panels have useful reasons and status text; news/history record events, but no common explorable chain relates a symptom to work and resources. [Bed causes](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_bed_panel.gd:1), [history](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3400).

**Player problem:** “The kitchen is idle, yet people are working. I cannot tell whether I need more food, a hauler, fuel or a route.”

**Recommendation:** A **Why?** link opens a short evidence chain: “No meal output → waiting for flour → flour at east store → route unavailable to assigned loaded carrier.” Show observed state separately from estimated effect; expose at most three highest-impact causes initially. Remedies link to the exact stock, worker policy or route, with costs and limitations. A recent-change strip answers “what changed?” and avoids blaming a worker for an impossible route. For future community needs, show distributions and contributing factors without claiming one mechanical cause explains a person's whole story.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/1-2-update/): resource history; [Factorio](https://www.factorio.com/blog/post/fff-397): linked knowledge.

**Connects to:** Work, Stores, all production, access, community care, learning. Related designs: [ECO-006](/Users/brendan/Developer/redwall-review/REVIEW.md:2315), [ECO-046](/Users/brendan/Developer/redwall-review/REVIEW.md:3443), [SOC-019](/Users/brendan/Developer/redwall-review/REVIEW.md:4155).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** trustworthy domain refusal/block reasons and connected economy. **Implementation slices:** (1) one status-to-cause link; (2) two-system cause chains; (3) recent changes; (4) actionable remedies and Back. **Minimum useful prototype:** crop ready but uncollected, with blocked hauling as the real cause. **Player acceptance criteria:** four of five uncoached testers fix the cause without issuing repeated ineffective orders; every displayed causal link can be traced to actual state. **Recommended direction / tradeoff:** explicit domain-authored reasons before a generalized inference engine; “cause not yet explained” is preferable to confident guesswork.

<a id="ux-011"></a>

##### UX-011 — Persistent incident cases

**Type:** Extension

**Current state:** The demo presents three ephemeral news lines and the shell has a separate history. [News](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_news_strip.gd:1), [history open](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3285).

**Player problem:** “A warning disappeared. Did someone solve it, or did I just miss it? Repeated notices drown out the one that matters.”

**Recommendation:** Give each real incident a persistent card with **needs decision / assigned / recovering / resolved**, location, affected scope and next useful action. Coalesce repeated messages into its timeline. Let players acknowledge, assign, pin, or snooze until a meaningful state change; never equate acknowledgement with resolution. Critical cards remain in a compact attention queue; routine completions join a daily digest. A flood case should link water, blocked deliveries and displaced households rather than create three unrelated crises. Ambient village news stays separate and pleasant.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/1-2-update/): resource history; [Farthest Frontier](https://www.farthestfrontier.com/guide/information/annual-report/): retrospective flows.

**Connects to:** Hazards/rescue, care, construction delays, Chronicle, session return. Related designs: [ECO-006](/Users/brendan/Developer/redwall-review/REVIEW.md:2315), [ECO-046](/Users/brendan/Developer/redwall-review/REVIEW.md:3443), [SOC-019](/Users/brendan/Developer/redwall-review/REVIEW.md:4155).

**Impact:** High.

**Effort:** M for notices backed by stable incidents; new event/resolution logic remains ECO/SOC work.

**Priority:** Next.

<a id="ux-012"></a>

##### UX-012 — An annotated layered atlas

**Type:** Extension

**Current state:** Live underground cutaway and routes exist; the general minimap reports generated tile data rather than a full annotated map of the visible village. [Cutaway](/Users/brendan/Developer/redwall-review/godot/demo/README.md:228), [minimap inspection](/Users/brendan/Developer/redwall-review/godot/scripts/systems/ui_manager.gd:496).

**Player problem:** “I remember a useful passage and a safer bank, but not which entrance or depth leads there. A growing village becomes hard to hold in my head.”

**Recommendation:** One atlas represents surface, canopy/water where relevant, and underground layers with matching landmarks. Name places and entrances; pin planned connections; display selected route segments with level changes and eligible body/load classes. A route comparison shows distance/travel estimate, risky segments and known seasonal closures, with uncertain information labelled. Clicking a place uses [UX-003](/Users/brendan/Developer/redwall-review/REVIEW.md:4952) Peek/Go to; selecting an entrance reveals its paired access, not an unrelated panel. Player notes are distinct from discovered world facts. Homes/cellars enter only as destination/access design, not rebuild critique.

**Comparable reference:** Researched—[Timberborn](https://store.steampowered.com/news/posts/?appgroupname=Timberborn&appids=1062090&enddate=1738766030&feed=steam_community_announcements): layered space; [Factorio](https://www.factorio.com/blog/post/fff-380): remote continuity.

**Connects to:** Tunnels, bridges, logistics, place identity, future squad planning. Related designs: [ECO-006](/Users/brendan/Developer/redwall-review/REVIEW.md:2315), [ECO-046](/Users/brendan/Developer/redwall-review/REVIEW.md:3443), [SOC-019](/Users/brendan/Developer/redwall-review/REVIEW.md:4155).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** trustworthy route/level model and real visible-world mapping. **Implementation slices:** (1) surface/underground landmarks and entrance pairing; (2) player names/pins; (3) selected route explanation; (4) alternate-route comparisons. **Minimum useful prototype:** two entrances, a surface crossing and a loaded carrier. **Player acceptance criteria:** testers correctly trace the carrier's complete journey and return to the right layer without trial-and-error selection; annotations survive save/load. **Recommended direction / tradeoff:** a readable topological route diagram is acceptable initially; do not require a photoreal miniature 3D world map.

<a id="ux-f04"></a>

#### UX-F04 — Construction, layout and architectural expression

| Lens | Assessment |
|---|---|
| Feel | Digging and crossings let players author useful space, but the surface village is largely prearranged. A cozy builder currently reaches the edge of agency as soon as they want to move a home or define a square. [Fixed layout](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:46). |
| Depth | Kernel material/work/refund stages support consequential building choices. Those choices need a project-level view so a beautiful plan competes honestly with food, labor and reserve commitments. [Construction lifecycle](/Users/brendan/Developer/redwall-review/godot/scripts/core/construction.gd:20). |
| Expression | The catalogue provides a promising set of buildings/furniture, but type selection alone cannot yield a distinctive abbey, riverside hamlet or woodland refuge. Modular additions, frontage, path character and commons could create identity without freeform construction of every wall. [Definitions](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:91). |
| Interconnection | A place should accommodate hauling, meals, meetings, refuge and future defense, with several possible layouts. Decoration should interact with use and memory, rather than becoming an unlimited numerical buff. [Path access](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:711), [bounded decoration](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:730). |
| Progression | Renovating and adapting existing neighborhoods can be as valuable as continuous outward expansion. Fixed Tier 2 packages are a base for change, not a complete architectural progression. [Upgrade definitions](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:149). |
| Readability | Before committing, players need entrances, circulation, eligible users, material stages, closure effects and replacement dependencies. For underground homes/cellars this is a design requirement only; no claim about the active rebuild. |
| Theme | Supported timber/stone, service yards, sheltered commons and accumulated repairs make a believable woodland settlement. A generic castle kit or optimal grid repeated indefinitely would squander the animal-scale setting. [Approved direction](/Users/brendan/Developer/redwall-review/docs/art-reference/visual_direction_alignment.md:30). |
| Benchmark | Researched: [Anno 1800](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/), [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/buildings/), [Timberborn](https://store.steampowered.com/news/posts/?appgroupname=Timberborn&appids=1062090&enddate=1738766030&feed=steam_community_announcements). **Pitfall / transfer limit:** Borrow planning and expressive composition, but avoid unrestricted voxel complexity or compulsory ornament-radius optimization. |

**Related owners:** [ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834).

<a id="ux-013"></a>

##### UX-013 — Sketch, fund and build

**Type:** Extension

**Current state:** Specialized dig/bridge previews are live; general footprints, material delivery, work and cancellation exist in the kernel without a complete player construction flow. [Placement](/Users/brendan/Developer/redwall-review/godot/scripts/core/buildings.gd:549), [construction phases](/Users/brendan/Developer/redwall-review/godot/scripts/core/construction.gd:216), [integration tasks](/Users/brendan/Developer/redwall-review/docs/tasks/06_buildings_rooms_logistics.md:21).

**Player problem:** “I want to see whether this square works before spending the winter's wood. I should not have to finish one building to discover the next will not fit.”

**Recommendation:** Separate **Sketch**, **Fund**, **Build**. Sketch places editable ghosts for buildings, paths, access and common space without reserving resources. A named plan displays material/work totals and circulation conflicts. Fund commits a chosen phase and shows reserve consequences; Build recruits available builders according to Work policy. Players can fund “store first, path second, homes later,” pause a phase and retain the unbuilt sketch. Planned geometry looks clearly distinct from usable geometry. Preview/undo follows [UX-002](/Users/brendan/Developer/redwall-review/REVIEW.md:4930); no free restoration of completed work.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/): reusable layouts; [Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/buildings/): building workflow; [Factorio](https://www.factorio.com/blog/post/fff-412): reviewable undo.

**Connects to:** Construction kernel, Stores commitments, Work staffing, path/access, aesthetic expression. Related designs: [ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834).

**Impact:** High.

**Effort:** L, including the absent end-to-end general construction flow.

**Priority:** Now.

**Plan:** **Prerequisites:** real build jobs, material delivery, usable finished structures and validated cancellation. **Implementation slices:** (1) one-building lifecycle; (2) multi-object sketch with access; (3) phase funding and reorder; (4) saved plan variants. **Minimum useful prototype:** store plus approach path and one furnishing. **Player acceptance criteria:** players correctly distinguish unbuilt from usable space, preserve their reserve while funding a phase, and cancel an unfunded alternative without resource loss. **Recommended direction / tradeoff:** recommend a few named phases and clear dependencies before a general project-management graph or fully automated scheduling.

<a id="ux-014"></a>

##### UX-014 — Composable authored architecture

**Type:** Extension

**Current state:** The village uses fixed building instances; general definitions include tiers and furniture, and session architecture variants are mostly unsupported. [Layout](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:46), [Tier 2 definitions](/Users/brendan/Developer/redwall-review/godot/scripts/core/building_definitions.gd:149), [architecture options](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_world_session.gd:60).

**Player problem:** “My village can get bigger, but can it look like a place I designed rather than the same kit placed repeatedly?”

**Recommendation:** Prefer a **hybrid kit**: strong authored building cores, with limited attachable porches, covered walks, service sheds, chimneys, entrances, signboards and compatible roof forms. Keep gameplay capacity readable and cosmetic variation separate from mechanical modules. Let players compose a sheltered courtyard, riverside row or woodland cluster using the same functional buildings. Save arrangements as local patterns that respect terrain, access and material costs when reused. Underground homes/cellars should offer frontage/threshold/common-space choices at design level, not arbitrary excavation of every interior detail.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/): reusable layouts; [Timberborn](https://store.steampowered.com/news/posts/?appgroupname=Timberborn&appids=1062090&enddate=1738766030&feed=steam_community_announcements): layered space.

**Connects to:** Construction plans, craft materials, paths, communal spaces, animal-scale identity. Related designs: [ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834).

**Impact:** High.

**Effort:** L.

**Priority:** Next.

**Plan:** **Prerequisites:** [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233) build lifecycle and approved material/silhouette kit. **Implementation slices:** (1) one core with three compatible attachments; (2) frontage/roof variation without stat ambiguity; (3) two neighborhood patterns; (4) pattern save/placement validation. **Minimum useful prototype:** residence plus porch, store shed and covered link around a shared space. **Player acceptance criteria:** five players produce recognizably different layouts while another player still identifies building functions at default zoom. **Recommended direction / tradeoff:** recommend authored cores plus constrained modules; full voxel freedom is expressive but expands art, navigation, usability and content scope dramatically.

<a id="ux-015"></a>

##### UX-015 — Useful communal places

**Type:** New system

**Current state:** Paths, tables, stools, a hall and decorative props are authored; the GDD permits bounded decoration comfort, but live players cannot create a functioning communal place. [Props](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:59), [comfort direction](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:730).

**Player problem:** “I want a lovely village green where people actually gather. If decoration is only a number, I will either ignore it or spam the best item.”

**Recommendation:** Let players designate **commons** around paths, seating, shelter and a focal object: garden meal area, well court, riverside rest, or quiet memorial grove. Benefits arise from real use and access: a nearby seat/shelter helps an existing rest/social routine; sufficient clear space supports a gathering. Keep any numerical comfort bonus modest and capped; duplicates do not stack indefinitely. Provide equivalent aesthetic choices so “best comfort” does not mandate identical statues. Show expected users and circulation conflicts before placement; do not count an inaccessible bench as a working service. Memorial/feast meaning remains SOC's system, with this item supplying physical expression.

**Comparable reference:** Researched—[Farthest Frontier](https://forums.crateentertainment.com/t/journey-log-09-happily-ever-after/115491): neighborhood decoration.

**Connects to:** Rest/social needs, feast venues, household design, paths, craft, memorials. Related designs: [ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834).

**Impact:** High.

**Effort:** L; this includes use of place, not merely a decoration picker.

**Priority:** Next.

**Plan:** **Prerequisites:** connected rest/social/meal routines and path-access evaluation. **Implementation slices:** (1) seat/shelter use; (2) commons designation and access readout; (3) compatible aesthetic sets; (4) feast/memory links. **Minimum useful prototype:** one table garden and one sheltered alternative that residents genuinely use. **Player acceptance criteria:** testers explain why a commons succeeds without reading a hidden score; both layouts satisfy equivalent needs; screenshots show activity that reflects actual schedules. **Recommended direction / tradeoff:** start with proximity and capacity plus real attendance, not a complex beauty-rating simulation.

<a id="ux-016"></a>

##### UX-016 — Renovation with service continuity

**Type:** Extension

**Current state:** Kernel construction has upgrade, demolition, refund and pause states; the live village cannot yet be rearranged through a complete general player flow. [Purposes](/Users/brendan/Developer/redwall-review/godot/scripts/core/construction.gd:208), [refund](/Users/brendan/Developer/redwall-review/godot/scripts/core/construction.gd:940), [pause](/Users/brendan/Developer/redwall-review/godot/scripts/core/construction.gd:1037).

**Player problem:** “My early layout was reasonable then. Improving it now should be a project, not a reason to abandon the save or accidentally strand everyone.”

**Recommendation:** A renovation order previews who loses beds/service/access, where contents go and which materials are recovered. Allow **replace after alternative ready** and **move contents first** dependencies. Preserve a building's name/history when extending or relocating appropriate structures. Heavy buildings require rebuilding; light furnishings can move for labor. Show salvage explicitly rather than teaching players that demolition is a magical refund. Seasonal maintenance should bundle into a reviewable work plan, not require repetitive clicking on each cracked wall. Existing refund percentages are a starting rule, not a recommendation to change them here.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/gameplay/buildings/): building workflow; [Factorio](https://www.factorio.com/blog/post/fff-412): reviewable undo.

**Connects to:** Hauling, housing, construction phases, reserves, village history, future fortification. Related designs: [ECO-004](/Users/brendan/Developer/redwall-review/REVIEW.md:2250), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575), [SOC-007](/Users/brendan/Developer/redwall-review/REVIEW.md:3834).

**Impact:** Med.

**Effort:** L because safe decanting/dependencies are new connected behavior.

**Priority:** Next.

**Plan:** **Prerequisites:** [UX-013](/Users/brendan/Developer/redwall-review/REVIEW.md:5233), actual occupants/storage and interruption rules. **Implementation slices:** (1) effect/salvage preview; (2) contents relocation; (3) replacement dependencies and service checks; (4) identity/history preservation. **Minimum useful prototype:** replace one occupied store without losing cargo access. **Player acceptance criteria:** players can improve a constrained layout without inaccessible goods or unintended homelessness and can state the cost before confirming. **Recommended direction / tradeoff:** offer a short supported dependency chain; avoid a general-purpose construction scheduler in the first iteration.

<a id="ux-f05"></a>

#### UX-F05 — Learning, discovery and objectives

| Lens | Assessment |
|---|---|
| Feel | Present hints describe controls; they do not yet create the relief of understanding a problem, choosing a remedy and seeing the community benefit. [Command tips](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_command_tips.gd:29). |
| Depth | The most teachable moments are causal: a shorter route changes a delivery, drainage changes a bed, preservation changes a winter plan. A fixed click sequence would teach obedience while leaving the player unable to diagnose a different village. |
| Expression | Players need to learn through their own priorities: garden, kitchen, safe crossing or communal place. Optional projects should share foundational lessons while producing different early layouts. |
| Interconnection | Guidance must connect fields to meals and people, rather than teaching farming, water and forestry as unrelated demos. The integrated food loop is a prerequisite, not something an instructional panel can manufacture. [Intended early sequence](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:830). |
| Progression | Learning continues when new tools combine, not only when a building unlocks. Familiarity should unlock richer explanation; known information should remain searchable without requiring a remembered hotkey. |
| Readability | Separate actionable next step, optional personal goal, objective requirement and reference knowledge. Showing every recipe/library relation as an immediate objective would produce anxiety and false promises. [Pantry reference](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:228). |
| Theme | A warden's practical advice and a field journal fit the world. Recipes and riddles should still be discoveries, so the guide needs spoiler boundaries without concealing basic mechanical rules. |
| Benchmark | Researched: [Factorio](https://www.factorio.com/blog/post/fff-361), [Against the Storm](https://eremitegames.com/custom-mode-update/), [Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/). **Pitfall / transfer limit:** Use practice to teach transferable decisions. Avoid gating accessibility/help behind progression or presenting a simulation lesson as mandatory homework. |

**Related owners:** [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388).

<a id="ux-017"></a>

##### UX-017 — Learning through chosen accomplishments

**Type:** Extension

**Current state:** External instructions and hints teach verbs; integrated tutorial/objective surfaces are unfinished. The adopted first-session design includes gathering, porridge, fishing/drying and a field. [Tutorial direction](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:830), [tutorial unavailable](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_world_session.gd:24). Phase 1 P7/F49 establish the missing basic onboarding prerequisite.

**Player problem:** “I can follow a click instruction without learning why the village needs it. A different map would leave me stuck again.”

**Recommendation:** After basic select/pause teaching, let the player choose a small promise: **supper for everyone**, **a safe connection**, or **a sheltered meeting place**. Each teaches a shared set of skills—inspect demand, plan work, observe delivery, verify use—through its own place. The first real meal closes the food lesson with people eating, not just inventory increasing. A mild, recoverable setback teaches one cause and two valid remedies; completed actions are recognized even if done out of order. Warden advice asks what outcome matters and explains consequences, without prescribing every tile. All paths converge on enough understanding to plan the next day.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-361): contextual teaching; [Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): focused practice challenges.

**Connects to:** ECO closed food/logistics loop, SOC community goals, construction, Work, causal help. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388).

**Impact:** High.

**Effort:** L; a first-meal lesson requires the actual meal loop.

**Priority:** Now.

**Plan:** **Prerequisites:** one complete produce/deliver/use loop and Phase 1 onboarding controls. **Implementation slices:** (1) author one outcome-driven lesson; (2) recognize alternate order and recovery; (3) offer a second path; (4) contextual follow-up lessons. **Minimum useful prototype:** supper plus one optional crossing lesson. **Player acceptance criteria:** after guidance disappears, four of five beginners solve a similar shortage in a changed layout and explain why the remedy works. **Recommended direction / tradeoff:** two strong paths before three; avoid elaborate cinematic tutorials or a compulsory hour-long prologue.

<a id="ux-018"></a>

##### UX-018 — A connected field guide

**Type:** Extension

**Current state:** Pantry links ingredients to candidate dishes, while recipes and broad mechanics live in documents/data; no general live encyclopedia is declared in the shell registry, and objective surfaces are incomplete. [Dish relationships](/Users/brendan/Developer/redwall-review/godot/demo/farm/farm_pantry_panel.gd:228), [screen registry](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_registry.gd:126), [Objectives availability](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_availability.gd:176).

**Player problem:** “I discovered an ingredient but do not know whether it is useful now, how to prepare it, or what I would need next.”

**Recommendation:** The Almanac has linked entries for item, process, building and condition, with **uses**, **requires**, **alternatives**, **available here**, and **not yet learned**. Clicking a rule opens a short visual example; clicking a current shortage opens the live causal inspector instead. Search synonyms in plain player language (“wet field,” “food going bad,” “bridge too narrow”). Keep story discoveries and recipes whose acquisition matters behind deliberate spoiler controls; basic safety/access rules are never hidden. Show the current playable recipe subset before the larger authored library, preserving the distinction already identified in Phase 1.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-397): linked knowledge; [Against the Storm](https://eremitegames.com/1-2-update/): resource history.

**Connects to:** Cooking/crafting, discovery/lore, onboarding, route safety, UI search. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388).

**Impact:** High.

**Effort:** L for linked authoring and playable-content scope, not just a text search box.

**Priority:** Next.

**Plan:** **Prerequisites:** authoritative current content subset and readable terms. **Implementation slices:** (1) ten linked core entries; (2) contextual help and search; (3) live-status versus reference distinction; (4) discovery/spoiler policy. **Minimum useful prototype:** roots → root stew → kitchen/water → meal, plus one access rule. **Player acceptance criteria:** novices find both a needed input and an item's purpose without leaving the game; no entry suggests an unavailable production command. **Recommended direction / tradeoff:** concise authored examples plus links before an encyclopedia page for every library recipe.

<a id="ux-019"></a>

##### UX-019 — Optional practice stories

**Type:** New system

**Current state:** The demo exposes manual hazard/weather triggers useful for testing, but lacks a player-facing practice flow. [Tunnel test controls](/Users/brendan/Developer/redwall-review/godot/demo/tunnel/tunnel_panel.gd:31), [water scenario controls](/Users/brendan/Developer/redwall-review/godot/demo/waterplay/water_panel.gd:23).

**Player problem:** “I want to try a risky crossing or learn winter planning without jeopardizing a village I have spent hours caring for.”

**Recommendation:** Provide short **Practice stories** outside the career save: move a loaded crew across a stream, restore a blocked delivery, prepare a small winter pantry, and later coordinate two squads. Each starts from a comprehensible situation, offers optional hints and a debrief showing decisions and consequences. Let the player restart, change one parameter and compare the outcome. No completion is required for core controls, accessibility or campaign progress. These are authored lessons, not developer buttons exposed on the main HUD.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/custom-mode-update/): controlled practice; [Factorio](https://www.factorio.com/blog/post/fff-361): contextual teaching.

**Connects to:** Rescue/access, seasonal survival, UI literacy, future tactics. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388).

**Impact:** Med.

**Effort:** L because reproducible scenario state, debrief and safe career isolation are required.

**Priority:** Next.

**Plan:** **Prerequisites:** stable scenario/save boundaries and actual mechanics. **Implementation slices:** (1) one crossing story; (2) decision debrief and repeat; (3) two alternate starting conditions; (4) food and later battle lessons. **Minimum useful prototype:** one short route/rescue situation with two valid solutions. **Player acceptance criteria:** learners transfer the lesson to a different career layout; nobody mistakes a practice outcome for an event in their saved village. **Recommended direction / tradeoff:** authored small scenarios before a full custom-world editor or leaderboard.

<a id="ux-020"></a>

##### UX-020 — Player-named projects

**Type:** QoL

**Current state:** Milestones and Charter requirements are adopted, but objective UI is incomplete; live players mainly choose isolated domain experiments. [Progression/disclosure](/Users/brendan/Developer/redwall-review/docs/game_gdd.md:793), [Objectives dock](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:204).

**Player problem:** “I know the game has a large future goal, but I want to remember my own smaller intention without turning my village into a checklist.”

**Recommendation:** Permit up to three pinned **personal projects**, chosen from contextual templates or free notes: “supper from our own fields,” “all-weather west path,” “finish the herb court.” A project links places and relevant measures, with optional reminders rather than default deadlines. Present adopted milestones as **new possibilities** and their requirements; personal projects neither replace those rules nor secretly become mandatory unlock gates. Completing one records a small Chronicle entry and before/after image if desired. Suggested goals respond to current opportunity without continually issuing demands.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/information/annual-report/): retrospective flows; [Factorio](https://www.factorio.com/blog/post/fff-361): contextual teaching.

**Connects to:** SOC progression/Charter, construction plans, Almanac, session return, visual history. Related designs: [SOC-031](/Users/brendan/Developer/redwall-review/REVIEW.md:4497), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [SOC-027](/Users/brendan/Developer/redwall-review/REVIEW.md:4388).

**Impact:** Med.

**Effort:** M after goals, persistence and referenced metrics exist; underlying milestone design stays with SOC.

**Priority:** Next.

<a id="ux-f06"></a>

#### UX-F06 — Session, time, settings and accessibility

| Lens | Assessment |
|---|---|
| Feel | Pause and speed already support thought and waiting, but the compressed demo clock makes observation a different experience from the intended settlement career. The missing session loop is “leave confidently, return understanding what I meant to do.” [Time](/Users/brendan/Developer/redwall-review/godot/demo/README.md:57), [persistence boundary](/Users/brendan/Developer/redwall-review/docs/tasks/09_persistence_replay_reliability.md:137). |
| Depth | Speed should compress waiting, not conceal irreversible changes. Pause policy, seasonal stop points and explicit queued intentions let careful planning coexist with tactile real-time activity. |
| Expression | Settings should support play styles and capabilities independently: quiet builder, keyboard-focused planner, visual observer or battle commander. Lower sensory load should not silently reduce strategic rules. [Settings scope](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:434). |
| Interconnection | Session return must restore project intent, camera context, unresolved incidents and goals alongside world state. Future away battles need an explicit home-time rule so the cozy player is not surprised by unattended collapse. That rule remains a SOC/campaign design dependency. |
| Progression | A two-hour learning session and a ten-minute return need different entry points into the same village. Late players benefit from a concise change summary, not the first-time tutorial again. |
| Readability | Show the consequences of scenario and pause settings with examples. “Standard” and “Sandbox” labels alone cannot communicate supply pressure, injury permanence, or whether a session can be stopped at any time. [Session fields](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_world_session.gd:60). |
| Theme | A return journal can feel like opening the steward's desk; it should contain real player plans and events, not invented flattering narration. |
| Benchmark | Researched: [Anno 1800](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/), [Against the Storm](https://eremitegames.com/custom-mode-update/), [Age of Empires IV](https://support.ageofempires.com/hc/en-us/articles/42701478818836-Narration-options-Age-of-Empires-IV). **Pitfall / transfer limit:** Borrow clear options and control, but do not copy reward exclusions or assume a comparable's narration covers every in-game surface. |

**Related owners:** [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170).

<a id="ux-021"></a>

##### UX-021 — A paused return journal

**Type:** New system

**Current state:** Save codecs and restore work exist in the wider project, but the live player lacks a complete save/load experience; news/history and local camera state do not form a return workflow. [Persistence task](/Users/brendan/Developer/redwall-review/docs/tasks/09_persistence_replay_reliability.md:137), [history](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:3285).

**Player problem:** “After a few days away I remember caring about this village, but not what I was doing. Resuming at speed makes that uncertainty stressful.”

**Recommendation:** Resume paused with a dismissible journal: last player note, three pinned projects, unresolved incidents, next seasonal deadline and last viewed place. Show what was true at save and what happened in the last played period; do not invent offline progress. Each line can Peek or open its owner, with Back to journal. The save browser shows village/date/population/mode and a representative thumbnail, with manual milestones alongside rolling autosaves. Allow a short **leave a note** field when exiting, never require it. A seasonal recap can later provide a satisfying return ritual.

**Comparable reference:** Researched—[Farthest Frontier](https://www.farthestfrontier.com/guide/information/annual-report/): retrospective flows; [Factorio](https://www.factorio.com/blog/post/fff-397): linked knowledge.

**Connects to:** Full persistence, Chronicle, projects, incidents, camera places. Related designs: [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170).

**Impact:** High.

**Effort:** L, explicitly including end-to-end playable persistence prerequisites.

**Priority:** Now for saving/paused return, Next for rich recap.

**Plan:** **Prerequisites:** consistent saved world/runtime and reliable restoration. **Implementation slices:** (1) save/load with paused return; (2) project/note/camera restoration; (3) concise return journal; (4) seasonal recap/archive. **Minimum useful prototype:** resume one village with a saved active project and one unresolved incident. **Player acceptance criteria:** after a 48-hour break, testers identify their intended next action within a minute and resume without accidental time advance. **Recommended direction / tradeoff:** store real facts and player notes; avoid auto-generated narrative that invents events or long recaps that obstruct returning players.

<a id="ux-022"></a>

##### UX-022 — Time controls for attention

**Type:** QoL

**Current state:** Pause, 1×/2×/4× and a stall banner exist; many panels expose actions while time passes. The demo uses a shorter day than the intended career. [Time rules](/Users/brendan/Developer/redwall-review/godot/demo/README.md:57), [stall pause](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_stall_banner.gd:1).

**Player problem:** “I sped through hauling and missed the moment I needed to decide. Or I closed a panel and do not know whether I am still paused.”

**Recommendation:** Distinguish **player pause**, **planning pause**, **critical pause**, with visible reasons and a single explicit Resume. Offer “run until” a selected project completes, a harvest window opens, dawn arrives, or the next relevant warning occurs, returning to pause when reached. A management panel remembers whether the player chose to pause; closing it never overrides an independent pause. Let auto-pause categories be tuned without changing hazard rules. Use actual game-calendar units everywhere, and explain demo acceleration in the session label rather than pretending it represents release pacing.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/custom-mode-update/): controlled practice; [Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): command continuity.

**Connects to:** Season planning, jobs, forecast, onboarding, accessibility, later battles. Related designs: [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170).

**Impact:** High.

**Effort:** M after real event/goal predicates and truthful clocks; future battle/home time policy is a separate L design dependency.

**Priority:** Now.

<a id="ux-023"></a>

##### UX-023 — Previewable capability presets

**Type:** QoL

**Current state:** The specification lists substantial accessibility/settings intentions; existing focus, scaling and demo control issues are already Phase 1 findings. [Settings](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:434), [world access](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:463).

**Player problem:** “I do not know which combination of small settings will make this readable and comfortable for me, and changing one may make another task harder.”

**Recommendation:** Offer editable profiles such as **Large readable**, **Keyboard planner**, **Reduced motion**, and **Quiet focus**. A live preview includes an actual inspector, map symbol, incident and placement task; it tests the chosen scale/contrast/input method without altering the save. Settings remain independent of difficulty. Profiles expose what they change and never overwrite unrelated custom keys. A persistent **show interactive targets** mode and an accessible place/object list reduce reliance on tiny world picking. This extends the Phase 1 primitives into a coherent user flow; it does not count those repairs again.

**Comparable reference:** Researched—[Age of Empires IV](https://support.ageofempires.com/hc/en-us/articles/42701478818836-Narration-options-Age-of-Empires-IV): configurable narration; [Age of Empires IV](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/): command continuity; [Against the Storm](https://eremitegames.com/rationing-update/): warm readable structure.

**Connects to:** Every screen, controls, audio priority, tutorial, session settings. Related designs: [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170).

**Impact:** High.

**Effort:** M for profile/preview UX **after** accessible primitives and action coverage are complete; full accessibility delivery is a larger cross-project effort.

**Priority:** Now.

<a id="ux-024"></a>

##### UX-024 — Truthful experience selection

**Type:** Change

**Current state:** New Settlement has name/seed/architecture/mode/tutorial fields, but only the Abbey standard path is supported and the full setup screen is incomplete. [Session model](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_world_session.gd:60), [workspace construction](/Users/brendan/Developer/redwall-review/godot/scripts/ui/ui_shell.gd:1396).

**Player problem:** “Does this game offer a peaceful village, a demanding survival run or tactical fighting? A vague mode name does not tell me what I am committing to.”

**Recommendation:** Present a recommended **Refuge** opening with a short truthful promise of the connected loop, estimated attention demands, and optional teaching. Keep a separate **Free building** experience once unlimited building actually works, and a future **Company campaign** only when its battle/home loop exists. Advanced setup describes consequences with concrete examples: a gentler winter changes reserve pressure; fewer raids changes conflict frequency; reminders do not change simulation. Show unsupported features as absent from the selected experience, not enticing disabled controls scattered through play. SOC owns the actual difficulty parameters; this is their understandable selection and review flow.

**Comparable reference:** Researched—[Anno 1800](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/): distinct Creative Mode; [Against the Storm](https://eremitegames.com/custom-mode-update/): controlled practice.

**Connects to:** SOC difficulty/progression, onboarding, persistence, future campaign, expressive building. Related designs: [SOC-034](/Users/brendan/Developer/redwall-review/REVIEW.md:4567), [SOC-044](/Users/brendan/Developer/redwall-review/REVIEW.md:4841), [UX-011](/Users/brendan/Developer/redwall-review/REVIEW.md:5170).

**Impact:** High.

**Effort:** L because truthful experience choices require corresponding playable scenario loops.

**Priority:** Now for honest Refuge scope, Later for additional experiences.

**Plan:** **Prerequisites:** a connected default loop and agreed SOC difficulty rules. **Implementation slices:** (1) one honest default setup; (2) consequence previews and teaching choice; (3) saved custom presets; (4) additional modes only after playable validation. **Minimum useful prototype:** default Refuge plus an explanation of its time/pressure rules. **Player acceptance criteria:** players can accurately describe whether combat, failure, pause and free building are present before starting; chosen assistance persists after loading. **Recommended direction / tradeoff:** one excellent recommended opening before a large matrix of subtly incompatible settings.

<a id="ux-f07"></a>

#### UX-F07 — Visual world, assets and action presentation

| Lens | Assessment |
|---|---|
| Feel | Previous Phase 1 observations found a recognizable central village and appealing working creatures, alongside ground/contact, water-dressing and sightline problems already reported. This pass does not reclassify those fixes as new design ideas. The deeper opportunity is seeing a place become more inhabited through the player's decisions. [Prior visual evidence](/Users/brendan/Developer/redwall-review/REVIEW.md), [world layout](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:46). |
| Depth | Visual changes can carry useful state: an active kitchen, a prepared building site, a well-used route, a cared-for grove. Present assets provide many ingredients, but authored dressing is not proof of those underlying activities. [Props](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:59). |
| Expression | The same building family should support several credible compositions and signs of stewardship. Variation should preserve function recognition and animal-scale proportions. [Art alignment](/Users/brendan/Developer/redwall-review/docs/art-reference/visual_direction_alignment.md:30). |
| Interconnection | Actual material stock, labor phase, weather and communal schedules should drive the visible world. Art should not advertise abundant food or active craft when the economy says otherwise. |
| Progression | A growing village needs visible memory beyond larger numbers: repairs, worn approaches, memorials, orchards and meaningful extensions. Cosmetic aging must not imply unimplemented deterioration penalties. |
| Readability | Prioritize silhouettes at the real gameplay camera before adding close-up detail. Separate permanent identity, temporary work state and selected/actionable state. Do not make every building a bright competing focal point. [Camera](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:39), [world light](/Users/brendan/Developer/redwall-review/godot/demo/world/world_look.gd:32). |
| Theme | Material-specific warmth, supported construction and purposeful props fit the approved adult woodland tone. UI pigments and world materials serve different purposes. [World/UI distinction](/Users/brendan/Developer/redwall-review/docs/art-reference/visual_direction_alignment.md:61). |
| Benchmark | Researched: [Farthest Frontier](https://forums.crateentertainment.com/t/journey-log-08-how-the-art-is-made/115296), [Anno 1800](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/), [Against the Storm](https://eremitegames.com/rationing-update/). **Pitfall / transfer limit:** Avoid transplanting human-city monumental scale or decorating every surface equally. |

**Related owners:** [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575).

<a id="ux-025"></a>

##### UX-025 — Visual hierarchy at play distance

**Type:** Change

**Current state:** The staged world contains detailed buildings, trees, crops, props and nine expressive cast rigs; the approved direction calls for material clarity and grounded animal anatomy. Previous Phase 1 material/occlusion findings remain separate prerequisites. [Art direction](/Users/brendan/Developer/redwall-review/docs/art-reference/visual_direction_alignment.md:30), [art pass](/Users/brendan/Developer/redwall-review/godot/demo/README.md:341), [camera](/Users/brendan/Developer/redwall-review/godot/demo/camera/demo_camera.gd:39).

**Player problem:** “The village is attractive close up, but when I actually play I need to recognize the kitchen, a busy work site and a person who needs help without hovering everything.”

**Recommendation:** Give each family a three-level hierarchy: **silhouette/function**, **material/identity**, **temporary state**. A kitchen reads from chimney/hearth/service frontage; a store from loading opening and stack form; a hall from a communal roof/entry shape. Within that hierarchy, timber, stone, cloth and foliage have different value/roughness patterns; small props do not all compete with residents. Named heroes get a restrained emblem or clothing accent, ordinary professions a held-tool/work silhouette, and selection remains a separate overlay. Evaluate approved art at default and overview zoom first, then close-up craft detail. Avoid a single saturated UI-palette treatment across the world.

**Comparable reference:** Researched—[Farthest Frontier](https://forums.crateentertainment.com/t/journey-log-08-how-the-art-is-made/115296): material-led art; [Against the Storm](https://eremitegames.com/rationing-update/): warm readable structure.

**Connects to:** Building recognition, anonymous/named identity, contextual actions, future squad readability. Related designs: [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575).

**Impact:** High.

**Effort:** L for a coherent family pass and variants.

**Priority:** Now for the representative kit, Next for full coverage.

**Plan:** **Prerequisites:** Phase 1 contact/material/sightline fixes and agreed default camera. **Implementation slices:** (1) five building silhouettes and three material swatches in context; (2) worker/tool and named-hero hierarchy; (3) temporary-state cues; (4) extend the approved kit. **Minimum useful prototype:** hall, home, kitchen, store and workshop at three zooms/daylight conditions. **Player acceptance criteria:** unfamiliar testers identify function and active/inactive state correctly in at least 80% of untitled images, without color alone; heroes remain findable in a mixed crowd. **Recommended direction / tradeoff:** spend first on large forms and controlled contrast, not higher polygon counts or unique trim on every prop.

<a id="ux-026"></a>

##### UX-026 — Ground shaped by use

**Type:** Extension

**Current state:** Buildings and scatter sit on a broad authored ground plane, with paths/props and per-asset sink offsets. Phase 1 contact flaws are already reported; correcting them alone does not create a lived-in settlement. [Ground](/Users/brendan/Developer/redwall-review/godot/demo/world/world_look.gd:26), [contact offsets](/Users/brendan/Developer/redwall-review/godot/demo/world/world_sizes.gd:84), [paths and props](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:59).

**Player problem:** “Buildings feel placed on a display surface rather than rooted in a place that people have built and used.”

**Recommendation:** Add a restrained **foundation and ground details**: foundation/plinth or earth bank, doorstep and apron, loading/service yard, then transition into path/vegetation. Material and activity determine the form: store approaches show cart wear; kitchens a swept service patch; trees leaf/root zones; riverside work uses supported banks/platforms. Cosmetic wear can reflect actual route use and seasonal moisture without inventing a new maintenance tax. Preserve clean negative space around busy action areas and protect wild patches from automatic clutter. When terrain variation later exists, entrances and supports must visibly meet it rather than merely lowering whole assets.

**Comparable reference:** Researched—[Farthest Frontier](https://forums.crateentertainment.com/t/journey-log-08-how-the-art-is-made/115296): material-led art; [Timberborn](https://store.steampowered.com/news/posts/?appgroupname=Timberborn&appids=1062090&enddate=1738766030&feed=steam_community_announcements): layered space.

**Connects to:** Paths, hauling, drainage, construction, ecology, place recognition. Related designs: [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575).

**Impact:** Med.

**Effort:** L for a reusable foundation and ground kit plus activity-dependent appearance.

**Priority:** Next.

**Plan:** **Prerequisites:** fixed contact geometry, validated footprint/access and material identity. **Implementation slices:** (1) authored foundation/apron sets; (2) path transition kit; (3) restrained traffic/weather variants; (4) apply to water/underground thresholds. **Minimum useful prototype:** kitchen/store/tree cluster connected by two paths. **Player acceptance criteria:** testers perceive continuous support/contact in orbit views and distinguish the heavily used approach without an overlay; wear never suggests blocked terrain when it is passable. **Recommended direction / tradeoff:** authored variants driven by a few meaningful states before fully procedural erosion or deformable terrain.

<a id="ux-027"></a>

##### UX-027 — Complete, visible work sequences

**Type:** Extension

**Current state:** Crop handling, tree felling, carrying and stocked shelves already give some work a visible arc; many fixed props and professional routines do not deliver production. [Held harvest/art pass](/Users/brendan/Developer/redwall-review/godot/demo/README.md:341), [work props](/Users/brendan/Developer/redwall-review/godot/demo/world/world_layout.gd:59), [cast build](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:199).

**Player problem:** “I can see people moving, but not whether the village is accomplishing anything or merely acting busy.”

**Recommendation:** For each connected job, stage a readable sequence: arrive with purpose → prepare tool/material → work → tangible changed object/product → carry or hand off → return/rest. Waiting has a distinct quiet posture and a contextual cause; completion has a brief satisfying gesture, not a permanent particle fountain. Focus first on harvest-to-meal, timber-to-bridge and excavation-to-usable-route. At overview distance retain a small set of recognizable motions and stock shapes; close views can show animal-specific reach, gait and cooperation. Use actual participants and cargo; do not add decorative workers that inflate apparent staffing. This extends F48's truthfulness into a full emotional payoff.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-396): causal sound; [Farthest Frontier](https://forums.crateentertainment.com/t/journey-log-08-how-the-art-is-made/115296): material-led art.

**Connects to:** Production, logistics, species scale, meals, construction, audio, tutorial. Related designs: [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575).

**Impact:** High.

**Effort:** L, including job-specific animation/staging and connected outcome state.

**Priority:** Now for one complete loop, Next for others.

**Plan:** **Prerequisites:** real job/cargo/output lifecycle and Phase 1 truthful state. **Implementation slices:** (1) one job's start/wait/end; (2) handoff to storage/consumer; (3) cooperative/body-size variants; (4) apply the visual vocabulary to two more loops. **Minimum useful prototype:** harvest carried to kitchen, cooked, then served to a real eater. **Player acceptance criteria:** observers explain the activity and its result from a 20-second clip without UI; an interrupted job looks different from productive work. **Recommended direction / tradeoff:** three complete sequences beat twenty attractive but disconnected loops.

<a id="ux-028"></a>

##### UX-028 — Seasonal occupation and memory

**Type:** Theme

**Current state:** Weather/light, foliage/scatter, crops and underground lighting already change presentation; communal schedules and persistent commemorative scenes are not delivered. [Weather/calendar linkage](/Users/brendan/Developer/redwall-review/godot/demo/README.md:68), [scatter](/Users/brendan/Developer/redwall-review/godot/demo/world/world_scatter.gd:24), [world look](/Users/brendan/Developer/redwall-review/godot/demo/world/world_look.gd:32).

**Player problem:** “Another year passes, but my village has little visual memory of what we did together.”

**Recommendation:** Design a small set of **lived seasonal scenes** tied to real systems: spring preparation near fields, summer outdoor meals, autumn drying/storage activity, winter gatherings under warm shelter. Feast preparation temporarily changes tableware/banners/lighting according to the chosen venue and actual food. Completed projects can retain a date plaque, repaired timber or player-chosen commemorative object, with an optional seasonal album in Chronicle. Keep weather/material fixes from Phase 1 separate; the point is changing use and memory, not a global color filter. Do not imply children work or hunt sapient creatures; their visible participation can be safe play or learning from SOC's rules.

**Comparable reference:** Researched—[Farthest Frontier](https://forums.crateentertainment.com/t/journey-log-08-how-the-art-is-made/115296): material-led art; [Stardew Valley](https://www.stardewvalley.net/dev-update-16/): seasonal musical identity.

**Connects to:** Seasons, feasts, household routines, lore/memory, personal projects, music. Related designs: [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664), [ECO-029](/Users/brendan/Developer/redwall-review/REVIEW.md:2965), [ECO-050](/Users/brendan/Developer/redwall-review/REVIEW.md:3575).

**Impact:** High.

**Effort:** L; actual gatherings/schedules and persistence are prerequisites, not implied by props.

**Priority:** Next.

**Plan:** **Prerequisites:** one communal routine and weather/season truth. **Implementation slices:** (1) summer/winter use of one commons; (2) real feast preparation/cleanup; (3) one persistent project memory; (4) extend seasonal art/audio. **Minimum useful prototype:** the same court during an ordinary meal, rain sheltering and a first feast. **Player acceptance criteria:** players recognize both season and occasion without date labels, and every represented gathering has actual participants/reasons. **Recommended direction / tradeoff:** a few authored places with stateful use before a unique seasonal asset set for every building.

<a id="ux-f08"></a>

#### UX-F08 — Audio and multisensory identity

| Lens | Assessment |
|---|---|
| Feel | Integration is absent by scoped source search, not a new listening finding. Beyond that Phase 1 prerequisite, sound can let players sense productive activity and the difference between a peaceful morning and an interrupted day. [Composition](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:139), [audio settings design](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:444). |
| Depth | Audio should communicate material, work completion, danger and collective rhythm. It must not convey unique strategic information that is unavailable visually or through text. |
| Expression | Players can choose prominence of ambience, music, voices and notices. A distinctive community motif and a few earned performances could make their particular village memorable without a huge soundtrack customization system. |
| Interconnection | Production, weather, feast attendance, rescue and later squad morale provide meaningful causes. Do not attach cheerful loops to inactive props or use random barks to imply nonexistent relationships. |
| Progression | Repetition fatigue matters across many hours. Add layers of communal performance at meaningful milestones; retain silence and modest arrangements for ordinary work. |
| Readability | The desired hierarchy is player command feedback and danger above nearby work, then distant life and music. Zoom changes what one should hear; hundreds of residents should not produce hundreds of equally prominent sounds. |
| Theme | Acoustic timber, water, tools, cloth, bells and communal song can carry Redwall warmth. Avoid constant battle orchestration, infantilized squeaks or human industrial machinery applied indiscriminately to woodland crafts. |
| Benchmark | Researched: [Factorio](https://www.factorio.com/blog/post/fff-396), [Stardew Valley](https://www.stardewvalley.net/dev-update-16/), [Against the Storm](https://eremitegames.com/1-2-update/), [Factorio](https://www.factorio.com/blog/post/fff-406). **Pitfall / transfer limit:** Borrow causality and musical place identity, not synthetic factory timbres. Factorio's cited music design is landscape-led, explicitly **not** battle-reactive. |

**Related owners:** [SOC-026](/Users/brendan/Developer/redwall-review/REVIEW.md:4349), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664).

<a id="ux-029"></a>

##### UX-029 — Sound that reveals work and place

**Type:** New system

**Current state:** The live composition has no located audio integration; settings specify several volume categories. F43/P8 cover the basic absence. [Composition](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:139), [audio settings](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:444). No listening claim is made.

**Player problem:** “I can only tell whether a place is alive by staring at it. A working kitchen, quiet grove and busy bridge feel acoustically indistinguishable.”

**Recommendation:** Build an audible **set of place-specific sounds**: nearby material contacts (wood/stone/soil/water), purposeful work accents, then broader forest/river/settlement ambience. Sound follows actual tool contact, cargo handoff and running processes; waiting goes quiet. Zoom out to a calm activity bed rather than a pile of individual footsteps. Underground changes acoustic space and filters the surface presence, while entrances provide a recognizable transition. Nearby water flow should reflect actual water conditions where those states exist. Use small randomized variations and rests; do not accelerate every sample's pitch at 4×.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-396): causal sound; [Stardew Valley](https://www.stardewvalley.net/dev-update-16/): seasonal musical identity.

**Connects to:** Actual work stages, weather/water, terrain materials, underground travel, camera. Related designs: [SOC-026](/Users/brendan/Developer/redwall-review/REVIEW.md:4349), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664).

**Impact:** High.

**Effort:** L, including authored assets, spatial integration and mix validation beyond Phase 1's basic wiring.

**Priority:** Now for one representative area, Next for breadth.

**Plan:** **Prerequisites:** F43/P8 integration and reliable action-state events. **Implementation slices:** (1) wood/crop/cargo action set; (2) forest/river/commons ambience; (3) zoom/underground perspective; (4) time-speed and repetition tuning. **Minimum useful prototype:** harvest beside a stream and delivery into a kitchen, all driven by real activity. **Player acceptance criteria:** listeners identify work starting/stopping and distinguish three places, while visual/text-only play retains all necessary information. **Recommended direction / tradeoff:** a coherent small library with well-timed accents before many loud loops or expensive full environmental acoustics.

<a id="ux-030"></a>

##### UX-030 — An earned community motif

**Type:** Theme

**Current state:** No live music system or communal performance is located; the setting and future feast loop provide musical opportunities, and basic audio integration is a Phase 1 prerequisite. [Composition](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:139), [approved musical direction](/Users/brendan/Developer/redwall-review/docs/setting_bible.md:889).

**Player problem:** “I want the place to have an emotional identity, and a feast or homecoming to feel different from ordinary production.”

**Recommendation:** Commission one memorable village motif with restrained variations for spring work, winter shelter and underground wonder. Use original acoustic instrumentation consistent with the woodland setting; leave intentional silence. At the first genuinely attended feast, reveal a fuller communal arrangement; later a named character or ceremony may add an earned phrase. Keep diegetic singing at the venue distinct from score. For future battle/homecoming, transform the same motif only at real narrative state changes; do not trigger dramatic music for every low-stock warning. Let players lower music while preserving the world soundscape.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-406): landscape motif; [Stardew Valley](https://www.stardewvalley.net/dev-update-16/): seasonal musical identity.

**Connects to:** Feasts, seasonal identity, named heroes, Chronicle milestones, later return from battle. Related designs: [SOC-026](/Users/brendan/Developer/redwall-review/REVIEW.md:4349), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664).

**Impact:** High.

**Effort:** L for composition, performance variants and event staging.

**Priority:** Next.

**Plan:** **Prerequisites:** stable audio mix plus actual feast/season/milestone triggers. **Implementation slices:** (1) motif and three understated arrangements; (2) silence/ambience pacing; (3) one diegetic celebration; (4) later milestone/hero variations. **Minimum useful prototype:** ordinary day, winter evening and first feast sharing one motif. **Player acceptance criteria:** listeners recognize community identity across variants without finding ordinary work over-scored; the feast is identifiable even without a popup. **Recommended direction / tradeoff:** a compact composed score before procedural composition or hours of unrelated tracks.

<a id="ux-031"></a>

##### UX-031 — Intelligible, adjustable sound

**Type:** QoL

**Current state:** Separate master/effects/ambience/notice settings are specified, but there is no live mix to evaluate. [Audio categories](/Users/brendan/Developer/redwall-review/docs/ui_ux_controls.md:444), [notice presentation](/Users/brendan/Developer/redwall-review/godot/demo/ui/demo_news_strip.gd:1).

**Player problem:** “A busy village could become tiring, and I might miss danger unless I play loudly. Muting ambience should not make management harder.”

**Recommendation:** Set a player-facing hierarchy: immediate command acknowledgement and critical incident cue; selected/nearby work; distant life; score. Aggregate repeated minor sounds, cap identical callouts and briefly duck competing layers for genuine urgent cues. Offer **Balanced**, **Quiet focus** and **Atmosphere** mixes, with individual controls and an audition. Critical information always has a matching named visual/text event; optional spatial captions identify off-screen direction without endless footstep transcripts. Test mono, small speakers, low volume and hearing differences. No mix preset should change simulation difficulty or secretly silence a category the player expects.

**Comparable reference:** Researched—[Factorio](https://www.factorio.com/blog/post/fff-396): causal sound; [Age of Empires IV](https://support.ageofempires.com/hc/en-us/articles/42701478818836-Narration-options-Age-of-Empires-IV): configurable narration.

**Connects to:** Incidents, accessibility profiles, camera, work soundscape, future squad orders. Related designs: [SOC-026](/Users/brendan/Developer/redwall-review/REVIEW.md:4349), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664).

**Impact:** High.

**Effort:** M after [UX-029](/Users/brendan/Developer/redwall-review/REVIEW.md:5679)'s audio foundation and actual incident signals; it is not a substitute for that L work.

**Priority:** Now as part of the first audio prototype.

<a id="ux-032"></a>

##### UX-032 — Selective named voices

**Type:** Theme

**Current state:** Visible cast have profession identities/ability descriptions; future named heroes and a larger anonymous population are the user vision, while the live demo has no located voice integration. [Cast composition](/Users/brendan/Developer/redwall-review/godot/demo/demo_village.gd:199), [ability identity](/Users/brendan/Developer/redwall-review/godot/demo/control/resident_abilities.gd:40).

**Player problem:** “A crowd of identical acknowledgements would turn the village into noisy units. Complete silence would leave important characters without presence.”

**Recommendation:** Use low, nonverbal communal activity for ordinary groups and a deliberately small voiced line set for important characters. A captain/warden acknowledges a new intention, a meaningful obstacle or a completed promise; repeated clicks do not repeat a catchphrase. Initial tuning hypothesis: one selected-character acknowledgement within an 8–12-second window, with urgent states exempted sparingly. Subtitles identify the speaker and actual intent, and visual response remains sufficient. Reserve longer performances for lore, feasts and consequential returns. Distinct voices should express personality, not reduce species or “vermin” identity to a moral caricature.

**Comparable reference:** Researched—[Against the Storm](https://eremitegames.com/1-2-update/): dialogue and event audio; [Stardew Valley](https://www.stardewvalley.net/dev-update-16/): character-event music.

**Connects to:** SOC named heroes, community identity, command intentions, lore, feast/music, future squad leadership. Related designs: [SOC-026](/Users/brendan/Developer/redwall-review/REVIEW.md:4349), [SOC-023](/Users/brendan/Developer/redwall-review/REVIEW.md:4281), [SOC-001](/Users/brendan/Developer/redwall-review/REVIEW.md:3664).

**Impact:** Med.

**Effort:** L for writing/casting/performance/localization and honest state-dependent presentation.

**Priority:** Later.

**Plan:** **Prerequisites:** actual named-character role, audio hierarchy and stable command/obstacle vocabulary. **Implementation slices:** (1) one character's written/subtitled lines; (2) a small performed set and suppression rules; (3) one consequential scene; (4) expand only after repetition testing. **Minimum useful prototype:** warden acknowledges three intentions and one completed communal project. **Player acceptance criteria:** an hour-long session does not produce distracting repeated lines; testers identify whose line it is and whether an order was accepted; muted play remains fully understandable. **Recommended direction / tradeoff:** one memorable role before fully voicing the population or recording exposition for unstable mechanics.

<a id="phase2-research"></a>

### F. Researched comparisons and evidence limits

All comparison sources were researched on 30 September 2026 by the completed research pass. **51 distinct web pages support the review: 49 developer, publisher or official-support sources and two official community-wiki pages.** The Stardew wiki pages are not primary developer statements. Historical posts are used only for their stated mechanism or design rationale, never as a claim that every old constant is current. No comparable-game hands-on test was performed, and no unlabeled recollection supplies a factual mechanic here.

The same source is reused as a compact pointer across families. These sources establish patterns; they do not prove that copying a pattern improves Redwall’s retention or that another game has the proposed Redwall system. Specific prescriptions, tuning and pitfalls belong to this review. No long quotations are reproduced.

| Researched source | Specific factual basis | Provenance and limit |
|---|---|---|
| [Farthest Frontier — farming guide](https://www.farthestfrontier.com/guide/gameplay/farming/) | Crop rotation, soil choices and staggered harvests share a labor budget. | Primary developer source |
| [Farthest Frontier — food guide](https://www.farthestfrontier.com/guide/gameplay/food/) | Orchards require care; processing changes how long food can be stored. | Primary developer source |
| [Factorio — FFF 375: quality](https://www.factorio.com/blog/post/fff-375) | Optional quality investment offers an alternative to expanding production. | Primary developer design post; historical |
| [Factorio — FFF 382: logistics groups](https://www.factorio.com/blog/post/fff-382) | Named request groups synchronize repeated logistics settings. | Primary developer design post; historical |
| [Against the Storm — cookbook update](https://eremitegames.com/recipes-cookbook-update/) | Product and ingredient views connect recipe alternatives, limits and efficiency. | Primary developer update; historical |
| [Against the Storm — Rainpunk Part 1](https://eremitegames.com/rainpunk-update-1/) | Adjustable rain engines trade productive benefits for an optional operating burden. | Primary developer update; historical |
| [Against the Storm — fishing update](https://eremitegames.com/keepers-of-the-stone-dlc-update-1-4-available/) | Catch accumulates before collection; early collection sacrifices the remaining pond. | Primary developer update; historical |
| [Stardew Valley — official 1.6 changelog](https://www.stardewvalley.net/stardew-valley-1-6-update-full-changelog/) | Dedicated processors, targeted bait, tree-linked mushroom logs, renovations, new neighbors, event-responsive content and varying festivals connect activities; some defeat losses are bounded. | Primary developer changelog |
| [Stardew Valley — Bee House](https://stardewvalleywiki.com/Bee_House) | Nearby flowers affect honey identity; hives stop producing in winter. | Official community wiki; not a primary developer statement |
| [Stardew Valley — Fruit Trees](https://stardewvalleywiki.com/Fruit_Trees) | Maturation and tree age create delayed fruit rewards. | Official community wiki; not a primary developer statement |
| [Timberborn — Update 4 announcement](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1681387121&feed=steam_community_announcements) | Distinct crop processing destinations and distribution defaults support settlement planning. | Primary developer experimental announcement; historical |
| [Timberborn — released Update 7 notes](https://store.steampowered.com/news/posts/?appids=1062090&enddate=1748436181&feed=steam_community_announcements) | Connected transport, tunnels and three-dimensional terrain broaden layouts. | Primary released developer notes |
| [Going Medieval — Update 9](https://foxyvoxel.io/2023/06/01/update-9/) | Heat, sunlight, storage, ladders and rooms interact; heat and item maker information are inspectable. | Primary released developer notes; historical |
| [Going Medieval — seed storage announcement](https://store.steampowered.com/news/posts/?appids=1029780&enddate=1774038904&feed=steam_community_announcements) | Production can be forbidden from consuming protected stored seed. | Primary released developer notes |
| [Dwarf Fortress — 2012 development log](https://bay12games.com/dwarves/dev_2012.html) | Mining leaves boulders; finer rubble was rejected when it added no worthwhile decision. | Primary historical developer rationale |
| [Dwarf Fortress — work-order development coverage](https://www.bay12games.com/dwarves/?dfuhk=) | Conditional standing orders support repeated workshop production. | Primary historical developer coverage |
| [Deep Rock Galactic — developer FAQ](https://www.deeprockgalactic.com/faq-test-page) | Destructible caves and traversal tools enable route improvisation. | Primary developer source |
| [Valheim — developer FAQ](https://www.valheimgame.com/faq/) | Food choices affect health and stamina capacity; this review imports no animal-food chain. | Primary developer source |
| [RimWorld — official description](https://rimworldgame.com/) | Backgrounds, relationships, needs and injuries supply personal causes; storytellers vary event pacing, and caravans and quests connect travel. | Primary developer source |
| [RimWorld: Ideology — roles and rituals](https://ludeon.com/blog/2021/07/ideology-adds-social-roles-and-rituals/) | Roles have obligations and work restrictions; ritual venue, participants and circumstances affect outcomes. | Primary developer preview, 2021; historical |
| [RimWorld: Biotech — children preview](https://ludeon.com/blog/2022/10/biotech-preview-3-reproduction-children-genetic-modification-release-date/) | Varied learning and adult attention influence children’s opportunities. Reproduction, genetics and child labor are outside this review’s proposals. | Primary developer preview, 2022; historical |
| [Dwarf Fortress — official store description](https://store.steampowered.com/app/975370/Dwarf_Fortress/) | Individual thoughts, needs, histories and cultures accompany music, poetry, dance, libraries and taverns. | Primary developer/publisher description |
| [Anno 1800 — residential tiers](https://www.anno-union.com/devblog-residential-tiers/) | Services, workforce types, access and visible neighborhood character connect aggregate management. | Primary developer explanation, 2018; historical |
| [Anno 1800 — expeditions](https://www.anno-union.com/im-going-on-an-adventure/) | Goods and specialists prepare branching encounters with risks, return rewards and recall. | Primary developer explanation, 2018; historical |
| [Anno 1800 — happiness](https://www.anno-union.com/devblog-happiness/) | Local needs and happiness are distinct; work conditions affect happiness. | Primary developer explanation; historical |
| [Timberborn — official description](https://store.steampowered.com/app/1062090/Timberborn/) | Efficient production coexists with diet, entertainment, decorations, monuments and distinct faction capabilities. | Primary developer description |
| [Against the Storm — Favoring redesign](https://eremitegames.com/favoring-update/) | Developers replaced consequence-free instant switching because it weakened decisions. | Primary developer explanation, 2023; historical |
| [Against the Storm — Explorer’s Choice](https://eremitegames.com/explorers-choice-update/) | Event approaches gained different costs, work effects and rewards. | Primary developer explanation, 2023; historical |
| [Against the Storm — Quality of Life 3](https://eremitegames.com/quality-of-life-update-3/) | Developers lengthened games and redistributed rewards so players could enjoy developed towns. | Primary developer explanation, 2022; historical |
| [Total War: ROME II — formations manual](https://r2encv2.totalwar.com/en/manual/single-player/0081_enc_page_battle_play_phase_conflict_army_formations/index.html) | Formation groups preserve shape and spacing, with arrangements reflecting unit roles. | Primary official manual |
| [Total War: ROME II — morale manual](https://r2enc.totalwar.com/en/manual/single-player/0087_enc_page_battle_play_phase_conflict_morale/) | Fatigue, casualties and pressure can break morale; some routers rally, but shattered troops do not. | Primary official manual |
| [Company of Heroes 3 — SEGA overview](https://sega.prezly.com/company-of-heroes-3-is-coming-to-consoles-may-30th) | Full Tactical Pause permits coordinated orders; dynamic and narrative campaigns offer different structures. | Primary publisher overview |
| [Factorio — FFF 380: remote view](https://www.factorio.com/blog/post/fff-380) | Consistent remote/local actions preserve navigable context. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Factorio — FFF 412: undo/redo](https://www.factorio.com/blog/post/fff-412) | Undo previews expose affected actions and warn about old history. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Factorio — FFF 361: tips](https://www.factorio.com/blog/post/fff-361) | Context-sensitive tips connect to mini-tutorials; searchable help preserves basic information. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Factorio — FFF 397: Factoriopedia](https://www.factorio.com/blog/post/fff-397) | Ingredients, uses, unlocks and browsing history connect reference information. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Factorio — FFF 396: sound](https://www.factorio.com/blog/post/fff-396) | Action accents, contextual ambience, aggregation and priorities organize activity sound. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Factorio — FFF 406: music](https://www.factorio.com/blog/post/fff-406) | A shared motif varies by landscape; the described system is explicitly not aware of battle versus factory planning. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Against the Storm — Update 1.2](https://eremitegames.com/1-2-update/) | Trends expose resource operations; the update includes encyclopedia search, character dialogue and event audio. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Against the Storm — Rationing Update](https://eremitegames.com/rationing-update/) | Warm decorative presentation returned while improved information structure remained. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Against the Storm — Training Expeditions](https://eremitegames.com/custom-mode-update/) | Practice parameters are configurable; its progression/reward restrictions are not proposed for Redwall. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Anno 1800 — Update 17](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/) | Stamps reuse layouts including blueprints; Creative Mode is a distinct experience. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Farthest Frontier — buildings guide](https://www.farthestfrontier.com/guide/gameplay/buildings/) | Placement, delivery, construction, staffing, relocation, salvage and upgrades form a building workflow. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Farthest Frontier — Annual Report](https://www.farthestfrontier.com/guide/information/annual-report/) | Retrospective food, material and population categories show production and consumption. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Farthest Frontier — overlays guide](https://www.farthestfrontier.com/guide/information/overlays/) | Separate crop/tree fertility, water-table and resource views answer spatial questions. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Farthest Frontier — Journey Log 09](https://forums.crateentertainment.com/t/journey-log-09-happily-ever-after/115491) | Decoration and neighborhood desirability interact; only the developer’s post informs this comparison. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Farthest Frontier — Journey Log 08](https://forums.crateentertainment.com/t/journey-log-08-how-the-art-is-made/115296) | Purpose and material guide art; ground decals, seasonal maps and upgrades make change visible. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Timberborn — Update 7 experimental announcement](https://store.steampowered.com/news/posts/?appgroupname=Timberborn&appids=1062090&enddate=1738766030&feed=steam_community_announcements) | A layer tool exposes terrain, buildings and water in three-dimensional settlements. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Age of Empires IV — Season One notes](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/) | Global queues, group/camera controls, remapping categories and an Art of War addition support command and learning. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Age of Empires IV — narration support](https://support.ageofempires.com/hc/en-us/articles/42701478818836-Narration-options-Age-of-Empires-IV) | Narration settings are configurable; this is not evidence every HUD action is narrated. | Primary developer/publisher/support source; dated feature descriptions are historical |
| [Stardew Valley — Dev Update 16](https://www.stardewvalley.net/dev-update-16/) | Seasonal songs alternate with ambience; character events and festivals have musical identity. | Primary developer/publisher/support source; dated feature descriptions are historical |

The four web sources also cited in Phase 1 are reused with the existing discussion in mind: RimWorld’s official description, Timberborn’s official description, Against the Storm’s Rationing Update and Factorio FFF 361. The new comparison descriptions deliberately remain brief. The cited proposals do not turn this project into a factory automation game, a survival horror colony, a procedural dynasty simulator or a grand-strategy conquest game. The useful common principle is that a decision changes something the player can understand, use and remember.

**Phase 2 completion boundary.** No implementation was changed, no new tests or native/audio sessions were run, and no proposal is approved for construction by this review. The result is a design catalogue and sequence for review. The next evidence needed is a small connected community day and a separately bounded tactical encounter, assessed through real player decisions and consequences.
