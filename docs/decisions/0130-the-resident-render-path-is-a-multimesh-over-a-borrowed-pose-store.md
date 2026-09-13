# 0130 — The resident render path is a MultiMesh over a borrowed pose store

Date: 2026-09-12 · Status: **Accepted**

## Decision

1. **The crowd tier is one `MultiMeshInstance3D`.** `godot/scripts/presentation/resident_crowd.gd`
   holds one instance per resident **row** (512), preallocated in `_init()`, and expresses the
   living count through `visible_instance_count`. No node, no physics body, no navigation agent
   and no `AnimationTree` exists per resident. REQ-SET-163's 24 skeletal actors are **not built**
   and nothing here reserves or anticipates a slot for them.

2. **Positions come from `transforms.gd`, not from `presentation_extract.gd`.** The brief for this
   work named `presentation_extract.gd` as the position source. It is not one, and says so in its
   own header: *"this milestone has no Transform store (ARCH-SYS-001), no per-resident position,
   no MultiMesh and no camera, so there is nothing to page and nothing to interpolate SPATIALLY."*
   Its fourteen captured fields are settlement scalars. The spatial half of the same boundary is
   `transforms.gd`'s `presentation_interpolate_into()` — same discipline, same integer endpoints,
   same caller-owned float record — and that is what the renderer reads.

3. **The render alpha is the scheduler's integer debt remainder.** `sim_clock.gd` charges
   `TICK_COST` = 1000000 debt units per tick and keeps the remainder; that remainder, over
   `TICK_COST`, is handed to `transforms.gd` as the integer fraction it demands. No `float` is
   computed on the simulation side of the boundary, and the renderer reads `debt()` without
   being able to change it.

4. **Facing is not applied.** Every instance keeps the identity basis and the interpolated yaw is
   discarded. `transforms.gd` records that ARCH-AUTH-002 fixes the yaw *scale* and nothing else,
   and names the zero reference and handedness as MOVE-G01/G04 blockers. Turning a yaw integer
   into a basis needs exactly the two facts that are missing.

5. **A presentation-private pose scaffold stands the cohort up, and is named as scaffolding.**
   `resident_pose_scaffold.gd` owns its own `transforms.gd` instance over the settlement's
   directory and places living residents on GDD §5.9's hall apron. It is not composed into
   `settlement_system.gd`, is read by nothing but the renderer, is in no save section, and decides
   no gameplay outcome. See the blocker below.

## Why

### The blocker: no resident in the running game has a position

Two separate gaps, and neither is closed here.

* `settlement_system.gd` composes fourteen core stores and `transforms.gd` is not among them.
  `grep -rn "transforms\.gd" godot/scripts` finds `movement.gd`'s preload and two prose mentions;
  nothing in the boot path ever calls `place()`. ARCH-SYS-001 storage exists and is tested, and is
  wired to nothing.
* **GDD §5.1 authors no resident spawn coordinates.** It authors the twelve-resident cohort, the
  starting inventory and (§5.9) seven building footprints, and says only that *"initial room
  assignments follow resident ID ascending and bed ID ascending"*. Beds live in a Furniture store
  that does not exist; `world_init.gd`'s own header records the starter buildings, beds and
  containers as BLOCKED.

So a renderer bound to the real settlement draws nothing, and the position each resident *should*
hold is not merely unimplemented — it is unauthored.

Three options were considered.

* **Compose `transforms.gd` into `settlement_system.gd` and place the cohort there.** Rejected:
  `settlement_system.gd` is outside this lane's file allowlist, and writing an unauthored spawn
  layout into authoritative state is exactly the invented constant AGENTS.md forbids.
* **Ship an invisible renderer and report the blocker.** Rejected: the crowd path would then have
  no visual evidence at all, and a renderer that has never drawn anything is not verified.
* **Confine the guess to presentation.** Taken. The scaffold's `transforms.gd` instance is created
  by the renderer's own stage, handed only to the renderer, and reachable from no tick stage, no
  command and no save section. The one unauthored decision — *which* cleared tile a given resident
  stands on — is isolated in two static functions and marked there. When movement composes the
  real ARCH-SYS-001 store, `ResidentStage.attach()` takes that store instead and this file is
  deleted whole.

### Why the geometry is derived and only the assignment is chosen

Every number the scaffold uses is read from `world_init.gd`: the hall footprint origin (58,59) and
extent 12×10 from §5.9, the 2048-unit tile pitch and 1024-unit tile centre from §5.1, and §5.1's
512-unit land elevation. The muster block is §5.1's own one-tile apron, south of the hall, and it
is twelve tiles wide because §5.9's hall is — so §5.1's twelve residents fill exactly one row.
Residents do **not** move: nothing in this repository may decide that they walk, and `place()`
writes previous = current, so interpolation draws a standing resident exactly where it stands.

### Why 512 instances and not 256

GDD §4.1 caps *living* residents at 256, but `residents.gd` holds 512 **rows** and a dead row keeps
its slot until it is despawned. Sizing the buffer on the row capacity means a slot can always
address an instance; `visible_instance_count` is what follows the living. `MultiMesh.instance_count`
is written exactly once, because changing it at runtime reallocates the server-side buffer.

## Consequences

* **Forbidden later:** deriving a rotation from yaw until MOVE-G01/G04 settle the zero reference
  and handedness; resizing the instance buffer in a frame; any write from the presentation layer
  into a store the simulation reads.
* **Owed by a later lane:** when `settlement_system.gd` composes `transforms.gd`, delete
  `resident_pose_scaffold.gd` and its suite, and pass the settlement's own store to
  `ResidentStage.attach()`. The renderer needs no change: it already takes the store as an argument.
* **Known and out of scope.** The MultiMesh AABB spans the world origin, because the 500 instances
  above the living count are parked there by `_reset_buffer()`. They are not drawn — the bound is
  conservative, not a ghost — but a culling or shadow lane will want to tighten it. No LOD
  selection, no animation, no material and no lighting work is done here, and the shipped GLB draws
  untextured white in its bind pose.
* **Claims no qualification.** Task 10.4's performance qualification requires measurement that this
  work does not do. Nothing here is evidence for a frame-time or memory gate.

## Source

GDD §5.1, §5.9 (REQ-SET-009, the authored estuary and starter footprints); REQ-SET-163 (crowd tier
and the 24-actor ceiling); ARCH-SYS-001 (`transforms.gd`); ARCH-SYS-023 and
`presentation_extract.gd`'s header (the float boundary); ARCH-CLOCK-001/002 and `sim_clock.gd`'s
`TICK_COST`; ARCH-AUTH-002 and the MOVE-G01/G04 facing blockers named in `transforms.gd`;
crowd doc §9.1 (the 1.0 m mouse scale anchor); ARCH-MEM-001 (allocate once).
