# 0053 — The movement ground slice's identity, storage and three new ledger rows

Date: 2026-09-11 · Status: Accepted for the implemented baseline fixture only.
**No MOVE gate is closed by this record**, and no production profile, clearance,
facing or turn-cost value is approved by it.

Scope: task 05.1a's permitted work, under
[READY_07 §1.1–§1.3](../rulings/2026-09-11_ready07_open_item_answers.md) and
[ADR0020](0020-movement-gates-close-in-dependency-order.md). Entry artifact:
[movement ground slice entry](../planning/movement_ground_slice_entry.md).

## Decision

Implement ARCH-PATH-001–005 for the authored surface fixture exactly as written,
plus integer Transform storage with previous state and 30 Hz remainder-retaining
motion, in four modules that no other lane owns:

| Module | Owns |
|---|---|
| `godot/scripts/core/spatial_world.gd` | The 512×512 static navigation map and the ground `Location` record |
| `godot/scripts/core/navigation.gd` | A* with the octile heuristic, the macro bucket cache, request phases, the Dijkstra reference |
| `godot/scripts/core/transforms.gd` | The eight I32 Transform columns and the one presentation float boundary |
| `godot/scripts/core/movement.gd` | ResidentMotion, the retained remainder, route following |

`RESERVED → TRAVEL → WORK` is **not** wired and `JOB_STATE_WORK` is written
nowhere; READY_07 §1.2 places that after starter profiles, real services and
work-unit context.

## The identity decision

A ground location ID is a **baseline cell index qualified by a declared domain, a
declared layer and the map revision it was minted against, carried together with
a generation-safe contact owner**. It is not a universal multi-level location.
Concretely, `spatial_world.Location` holds `(domain, layer, revision, cell,
owner_slot, owner_generation)` and no routing entry point accepts a bare X/Z
pair. `DOMAIN_GROUND` and `LAYER_SURFACE` are the only contracted values; every
other domain or layer refuses `DOMAIN_NOT_CONTRACTED` / `LAYER_NOT_CONTRACTED`
rather than defaulting, because their depth, elevation and cell budgets are
MOVE-G01 parameter-pack outputs. The record's field shape is deliberately the one
SET-MOVE-001 §2 proposes for dynamic Location/Connection kinds, so later domains
extend this boundary instead of replacing it.

## The binding stamp is a persistent ID, not a generation

A Transform row is **derived**, not allocated: `base(kind) + typed_row` over the
four positioned kinds whose capacities systems_architecture §2.1 already sums to
P=87552. That removes a second allocator, and leaves exactly one hazard — a typed
row is reused, so a successor can read its predecessor's coordinates.

The stamp closing that hazard is the owner's **persistent ID**, not its
generation. A generation belongs to a directory *slot*, and every slot's first
use carries generation 1; directory slots and typed rows come from separate free
heaps, so a successor can inherit a typed row from a predecessor that lived in a
different slot with the same generation, and a generation stamp would match.
Persistent IDs are never reused. `test_transforms.gd`'s
`test_a_typed_row_inherited_from_another_slot_reads_as_unbound` constructs that
exact case.

## Three new ledger rows, +520192 bytes

Everything else this slice allocates is an existing §2.3 row: the static
navigation map (3670016), the A* builder (5505024), the route cell arena
(4194304), route descriptors (16384), path request records (524288), the resident
motion scratch (32768) and the budgeted §2.2 Transform payload (2801664). No
duplicate world and no `resize()` outside `_init()`.

| New §3 table | Columns | Bytes | Why ARCH-MEM-008 has nowhere to put it |
|---|---|---:|---|
| TransformBinding[87552] | bound_persistent_id | 350208 | The eight Transform columns are all position/facing; none records who placed the row |
| PathRequestContact[8192] | start/goal owner slot and generation, requester persistent ID | 163840 | PathRequest's sixteen columns carry no contact owner, and READY_07 §1.2 requires one at both endpoints |
| ResidentRouteCursor[512] | request_row, route_generation, route_cell_index | 6144 | ResidentMotion names neither the route a body follows nor its progress along it |

Ledger effect, applied to `systems_architecture.md` and pinned in
`docs/validation/ready07_arithmetic.py`: auxiliary payload 16712540 → **17232732**;
planned payload 60256806 → **60776998**; one world plus reserve **69165606**;
headroom **30834394**; second mutable candidate **54561414**; rejected two-world
peak **123727020**, over the gate by **23727020**. Decision 0050's 437632
reconciliation is reproduced from its own constants in that script and is **not**
re-applied to the live payload.

## Values this slice refused to invent

- **Body, posture and gear clearance.** `spatial_world.gd` publishes map geometry
  only; a clearance class is a caller input. READY_07 §1.2: reference routing
  with synthetic clearance is unblocked, ordinary resident travel is not correct
  until starter profiles and contact clearances exist.
- **Yaw zero and handedness.** ARCH-AUTH-002 fixes the scale at 65536 units per
  turn and nothing else. `movement.gd` therefore derives no facing at all and
  carries yaw through untouched; `desired_yaw`/`next_yaw` stay zero.
- **Turn and segment entry/exit costs.** Per-tick budget that a turn leaves
  unusable on one axis is dropped rather than absorbed by an invented turn cost.
- **Body radius and separation strength.** `radius_u` and `correction_*` stay
  zero; bounded soft separation needs the G01 profiles.
- **A short-trip threshold for the anchor detour.** See below.

## Finding for the ARCH-PATH-003 owner: the macro anchor detour

Implemented literally, ARCH-PATH-003 routes **every** start through its macro's
anchor, because the bucket stores the anchor's route and a different start
reaches it by a macro-local entry segment. Measured on the authored map, cell
(100,100) to (104,102) composes to cost **160** against a true optimum of **48**,
and a start whose goal lies back past the anchor retraces its own cells. The
detour is bounded by the macro (16 cells) so it is negligible on a long journey
and dominant on a short one.

This slice does **not** fix it, because every available fix is an invented
policy: joining the entry segment to the bucket at its nearest point, or falling
back to an exact-start search below some distance, both need a decision and a
number this slice may not choose. It is asserted and measured in
`test_navigation.gd`'s `test_the_macro_anchor_detour_is_measured_not_hidden` so
it cannot be rediscovered as a bug, and it is raised for ARCH-PATH-003's owner.

## What remains blocked

- **Save/load round trip: BLOCKED.** ARCH-PATH-006 requires the in-progress heap,
  parents, g-scores, stamps, cursors, quota and cache eviction decisions to be
  serialized. There is no canonical serializer to add a versioned section to, so
  no next-tick parity claim is made or attempted.
- **Topology edits.** `override_static_legality()` is the fixture's single,
  whole-map, non-transactional legality mutator. The bounded-overlay, reserve,
  stage, publish-together protocol with occupied-exit refusal is task 05.6.
- **Nonlocal connections.** None exist. `reference_cost_into()` is the Dijkstra
  comparison that must precede enabling one; no transition cost is mixed into the
  octile heuristic.
- **FP-01–12.** A headless routing fixture is not first-playable acceptance and
  is not described as one anywhere in this work.

## Astra response — 2026-09-12

[PATH-R02 and MOVE-DEP-R01–05](../rulings/2026-09-12_movement_dependency_rulings.md)
supply the exact-start detour fix and explicitly assign the five omitted
profile/life-stage/rig/graph/contact dependencies. Original observations above
remain historical measurements, not a current absence-of-ruling claim. Runtime
changes and full movement qualification remain separate work.
