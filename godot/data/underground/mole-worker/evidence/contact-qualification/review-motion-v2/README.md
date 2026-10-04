# Corrected source motion/contact component

This supersedes `review-motion-v1` for the exact renderer-interval proof. It is
still **source-local / exact yaw 0 evidence and zero production qualifications**.
The original rejected source bytes are retained in v1's `rejected-sources/`.

Independent review found one medium defect: `ActorContent` closes a looping
clip from its penultimate stored frame to its **first** frame, whereas the old
proof always checked the next stored frame. Unequal first/last poses therefore
left an actual rendered edge unproved. The corrected decoder retains exact loop
mode and outward Q16 duration. One shared edge function now follows Content's
loop/nonloop/ping-pong rules; the same rules govern primitive/floor and
self-contact proofs. Exact-array proof reuse also checks timing and refuses
reverse reuse for a linear loop. The adversarial regression has three clear
stored-adjacent motions but a colliding real loop-closing motion.

`analysis-carry-arm-v7/result/` has exactly the same mesh tables, clip timing,
matrices and grounding as v6. `loop-correction-identical-motion.json` compares
those full byte regions. Only provenance and corrected proof identity change.
`body-clearance-loop-v6.json` passes all 386 exact rendered intervals across
nine clips, with the same complete body/pick primitive census and intentional
palm-only self-contact exclusion described in v1. Every unresolved pair or
check-budget exhaustion still refuses. World numerical error is used in local
axes only at yaw 0; this is **not** a certificate of self-clearance at other
headings. Cross-clip handoffs remain separately unqualified.

The new native work run checks the actual closing endpoint pair and native
application for all seven looping clips, including the one-Q16-unit final
intervals in clips 1–3. It reports **2,335 poses, 5,349 assertions, 0 failures**.
The refreshed actual tip run reports **9 poses, 61 assertions, 0 failures**.
The current topology-capture runner reports **2 parts, 34,077 indices, 34,119
assertions, 0 failures**; geometry/rig output equals the earlier pinned proof
input. Every run has zero raw diagnostics/leaks and matching pre/post source
pins. The runner now rejects empty, partial, failed or wrong-census reports even
if the engine exits zero.

Python tests: **30 compiler + 10 self-clearance + 3 tip + 4 runner = 47 passed**.
The changed native helpers and the separate high-wall helper have **0 GDScript
warnings in 4 files**. The first analyzer command accidentally named paths
outside `godot/`, found zero files and is retained as rejected evidence; only
the four-file retry counts. A synthetic decoder test initially omitted its
required mesh AABB; that fixture error was corrected before the final run.
These native authoring checks use actual assets and are not a full CI suite.

Open gates remain the actual source/manufacture/state driver, permitted
cross-clip and interruption transitions, complete role unions and authored
stance, actual route/paid target qualification, other-yaw source error mapping,
and isolated presentation/native/loading memory. The high-wall candidate is a
separate work-in-progress, not part of this source freeze. All source and output
pins in this directory are independently reviewable; no gameplay flag is set.

Independent root re-review accepted the corrected component after checking all
11 frozen source and 50 output pins, tracing actual Content interval semantics,
and rerunning all 47 Python tests. The unchanged historical `capture_motion.gd`
helper was then read and accepted separately so the runner's preserved `motion`
mode has its complete in-repository implementation. The final source manifest
therefore has 12 entries. This acceptance closes the loop/census defect only;
the open production gates above remain open.
