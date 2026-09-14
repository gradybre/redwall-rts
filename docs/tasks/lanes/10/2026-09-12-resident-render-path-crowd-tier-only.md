# 2026-09-12 — Resident render path (crowd tier only)

Task: 10_presentation_qualification.md
Date: 2026-09-12


Residents are on screen for the first time. `godot/scripts/presentation/` holds a
`MultiMeshInstance3D` crowd drawing one instance per living resident, interpolated
between committed ticks; `main.tscn`'s `World/Entities` is no longer empty.
[Decision 0130](../decisions/0130-the-resident-render-path-is-a-multimesh-over-a-borrowed-pose-store.md)
records the design and the blocker.

**This closes no checklist item above, and 10.4 is untouched.** No frame time,
tick time, route latency or memory figure was measured, and none is claimed.

| Item | Effect of this work |
| --- | --- |
| 10.1 UI definitions/flows | none |
| 10.2 Species/age/culture briefs | none. `species_mouse_body_a_lod0.glb` is now *instanced*; it is not reviewed, textured or approved |
| 10.3 Clip/LOD mappings | **unstarted, deliberately.** No clip name, no LOD distance and no rig is referenced anywhere in this work |
| 10.4 Release qualification | none. No measurement was taken |
| 10.5 Movement gates, save/replay | none |

## What a later lane inherits

* **No resident in the running game has an authoritative position.**
  `settlement_system.gd` does not compose `transforms.gd`, and GDD §5.1 authors no
  resident spawn coordinates — beds, which would decide them, need a Furniture
  store that does not exist. A presentation-private scaffold stands the cohort on
  §5.9's hall apron so the crowd has something to draw; it is read by nothing but
  the renderer and is deleted when movement composes the real store.
* **Facing is unverified and probably backwards.** The renderer applies no
  rotation at all (MOVE-G01/G04 have not settled the yaw zero reference or
  handedness), and in the captures the GLB faces the camera — i.e. **+Z**, against
  this project's −Z-forward convention. Needs a human eye, not an automated check.
* **The crowd draws untextured white in its bind pose.** No material, lighting or
  animation work was in scope.
* Ledger and registry rows for the two new presentation columns are reported in
  decision 0130's lane report; neither `docs/systems_architecture.md` §2.3 nor
  `docs/persistence_state_registry.md` was on this lane's allowlist.

Evidence: [`docs/validation/evidence/resident-render-path/`](../validation/evidence/resident-render-path/README.md).
