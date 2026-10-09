# 1053 — Room revisions hold the actual construction project

Date: 2026-10-02 · Status: Accepted engineering increment; excavation integration remains queued

## Scope and authority

The user approved underground construction D01–D28 and requested concurrent implementation.
This increment implements the project control prerequisite for D26–D28. It does not claim a
completed room-building lifecycle. D18 remains the immutable room-purpose rule; a project
records the protected GDD RoomType ID and exposes no type mutation. The eventual completed
room owner must preserve that purpose after this Construction project retires.

## Existing owner deficit

`construction.gd` describes excavation phases in its header but only opens building,
upgrade, furniture, demolition, and furniture-removal subjects. It has no generic site phase
API and no canonical physical-quantum ledger. `buildings.gd` designates managed-building
interiors, not arbitrary underground volumes. Instantiating an existing building project as
if it were a paid room cut would create the wrong recipe and is not an integration strategy.

The new `room_projects.gd` therefore binds existing Construction references for real pause
and job-release behavior. Tests use an explicitly named stockpile Construction fixture;
that fixture is never exposed as a Kitchen construction recipe. The module has no pretend
excavation progress, completion, backfill, or unconditional safety callback.

A following lane must implement ECON-001's immutable 1m³ physical ledger and generic
Construction phase subjects, then bind actual dry/support/contact and output-reservation
owners. Room completion/retirement, backfill history, material delivery, tool settlement,
room topology, accepted footprint amendments, and completed-room type ownership remain
queued integration work. The current adapter neither duplicates those accounts nor invents
prices, timings, room capacities, or paid-volume rounding.

## Implemented contract

- A record uses a live Construction EntityRef and its existing typed row, with no new
  entity allocator. A reused slot cannot inherit its prior record or type. Retirement
  requires the old Construction identity to be dead and all child Job bindings resolved.
- Registration preserves an existing Construction pause as an independent player hold.
  Player and revision holds are separate bits; leaving revision releases only its own bit.
- Requesting revision pauses the actual Construction store, preserving its delivered/WIP
  ledger and remaining work. The request is distinct from acknowledgement.
- Revision acknowledgement reads the real Jobs and Reservations stores. Workers, active
  work/travel/output phases, pending claims, stale bindings, and late owned but unbound Jobs
  prevent acknowledgement. No caller-supplied `workers_are_safe` boolean can enable it.
- Job binding requires the live Job's requester (or its actual party coordinator's requester) to equal this exact Construction identity. Conflicting member/coordinator ownership refuses.
  Retired Jobs with surviving claims cannot be forgotten. An acknowledged-state read checks
  again, so late work or reservations do not turn a stale acknowledgement into permission.
- Each edit session has a monotonic int32 token. A delayed discard or acknowledgement from
  an earlier session cannot release a newer hold. Overflow refuses rather than wrapping.
- Unrelated projects remain active. Refused commands preserve all owning stores byte for byte.

Construction's pause flag only clears its aggregate assigned count; it does not safely
withdraw a worker or release Inventory claims. The dispatcher must inspect
`can_dispatch_work` before deliveries, productive ticks and assignments; movement must
perform safe withdrawal before releasing the actual Job worker. The adapter acknowledges
owner release, **not** an evacuated volume or geometry-edit transaction. These call-site
bindings must land before a player-facing Revise command uses this owner. Geometry drafts,
Apply/Discard/Keep editing UI, and authoritative Apply remain later integrations.

All pause writes for registered projects must flow through this adapter. It detects
observable disagreement with Construction's flag and refuses with
`ROOM_PROJECT_UNOWNED_PAUSE_WRITE`. The existing single boolean cannot distinguish an
external `set_paused(true)` while it already holds true. Complete detection requires a
Construction pause-revision/reason API or exclusive routing of those call sites. This is
recorded as an owner limitation, not falsely asserted as a solved concurrency guarantee.

Reservations indexes its Job keys by slot within its declared capacity, while the Entity
Directory can allocate larger global slots. A binding whose key cannot be represented is
refused explicitly; querying an out-of-range key must not be mistaken for proof of zero
claims. Resolving that existing namespace/capacity boundary belongs to the shared owner
integration, not a silent remapping to typed rows.

## Storage, save, and deterministic continuation

All per-project/per-job state is packed integer columns. Existing Construction/Jobs capacities
bound storage; there is no new room-size or active-room policy limit. Allocation is
`82944 * 19 + 8192 * 16 = 1707008` payload bytes (plus owner references and one small scratch
result). This is new memory, not evidence that the overall 100MB qualification is satisfied.
The canonical local `state_bytes` image covers every packed column for refusal/determinism
tests. It is not a save codec. The persistence registry explicitly marks these columns as
required. Save orchestration and canonical hash bindings must include them before activating
this owner in a persisted game; they may not reconstruct an edit pause from a visible panel.

## Validation

The focused suite uses real Construction, Jobs, Residents, Inventory and Reservations owners.
It exercises partial paid work, job/claim release, late work, stale generations, pause ownership,
revision token reuse, refusal atomicity, independent projects, retirement, and the exact payload
byte count. After moving this worktree's demo assets aside if present, removing its `.godot`
cache and running `godot --headless --path godot --editor --quit`, the strict shell runner's
single-suite shard ran `test_room_projects.gd` (149/299 in this exact corpus):

```text
20 test(s), 301 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

`state_registry_coverage` passed with 93 modules, 441 rows, 758 packed columns.
The zero-warning analyzer on both changed GDScript files reported:
`0 GDScript warning(s) in 0 of 2 file(s)`.
This is focused module evidence; the integration branch still owes the complete no-argument
suite and all-source analyzer after composing the other lanes.

The suite also measures actual 256-resident/8192-Job owner stores with four bound construction
jobs. Sixteen safe-stop acknowledgements measured mean **5550 µs**, maximum **5673 µs** on the
Mac development host. This exceeds the 2ms simulation-tick target if polled as part of each
simulation tick. The API is therefore explicitly a cold command/owner-change check, never a
per-frame HUD query. Future UI caches need invalidation from the real owners; full production
qualification requires an owner revision/index or bounded continuation. This local measurement
is not qualification on the minimum hardware, and no timing test invents a new allowed budget.
