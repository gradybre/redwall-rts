# 1051 — Underground implementation lanes and integration

Date: 2026-10-02

Status: active engineering plan; no gameplay requirements are waived.

## Authority and scope

Brendan explicitly requested concurrent subagents and automatic release of
queued work until the approved underground design is built. The approved
decisions remain D01–D28 in `docs/design/underground-planning/README.md` and
the 107 requirements in its three requirement documents. The earlier
review-only file restrictions were superseded for this implementation by the
later build instructions. Main and Claude's checkouts remain untouched.

All four initial branches were created from `origin/master` at
`82d60ba86dcecf6e7c6184eeaf77a389e8b2b5c2`, then fast-forwarded to our own
PR #229 foundation at `09beda25a93f29da15b3b761f3b41bdfc4ea9faa`.
Each worker has a separate worktree and explicitly assigned files. The
integration owner alone changes shared demo entry points, state registration,
the build queue and integrated acceptance evidence. Workers may prepare
isolated registry append commits; the integrator reconciles their stanzas.

## Scheduling and completion

`docs/tasks/underground-build-queue.json` is the durable dependency/ownership
queue. `tools/underground_build_queue.py` checks dependency cycles, requirement
coverage and concurrent file conflicts. Its `ready` output identifies work
whose prerequisites are integrated and independently reviewed. It does not
execute model instructions or launch shell commands from queue data.

A current-thread heartbeat may resume agents and release ready work. A task
already running is resumed, not duplicated. A blocked lane releases its file
lease only after the worker stops writing; other independent lanes continue.
File leases are explicit and independent of task status: changing a lane to
`blocked` does not release its files. A recorded worker-stop acknowledgement
is required for release. Ownership paths must use canonical repository-relative
POSIX spelling. A lane cannot become running, implemented or verified before
its prerequisites are verified; final qualification is excluded from the
implementation-coverage calculation. These guards were added after independent
review reproduced alias, premature lease-release and dependency-bypass cases.

One integration owner serializes shared-file changes. A worker finishing a
helper is not equivalent to completion of a player-facing requirement.

The UG08 independent geometry increment was released after UG01 while UG06
continued. Inspection showed no required source dependency: the two owners
exchange immutable datum geometry and versioned admission/publication facts;
UG09 remains the composition gate. This removes an unnecessary implementation
dependency, not the requirement for actual support/contact/profile bindings.
Unmeasured connector numbers remain proposals until their contracts close.

UG06 additionally owns narrow Reservations consumption and Inventory ground
pile publication changes. Inventory currently refuses an empty ground pile
with only reserved mass. The selected solution uses a real finite World-owned
staging container, then publishes that same container as a ground pile only
when its first actual output lot and policy/map change commit together.
No empty-pile invariant or diagnostics allowance is weakened. Cancellation,
capacity refusal, journal exhaustion and generation changes require conservation
tests. The spatial owner must reserve its real output contact.

The first playable checkpoint remains D20: reviewed blueprint through worker
construction to an empty Kitchen. Kitchen/Bedroom furnishing, two-level
access, replacement, renovation and the expanded catalog follow under their
own gates. No editor-only milestone closes the full build.

## Owner gaps found at dispatch

The production Construction owner documents excavation but currently exposes
building/furniture/removal subjects, not physical paid-cut site phases. A
separate physical-site and Construction integration lane is required; elapsed
demo time or a graph segment cannot substitute for ECON-001's immutable
physical history. Room revision ownership can be implemented independently.

The existing furniture footprint table uses 2 m tiles. Fine planning grids
must represent those footprints exactly, not shrink a bed to one paint cell.
The new layout validator takes explicit equipment envelopes and access facts;
it cannot infer service validity or install furniture for free. The catalog
and real order coordinator remain explicit integration work.

## Evidence

Each lane records a commit, focused test summary and diagnostics, review and
integration evidence before its status becomes `verified`. The final lane
requires the clean-import/no-argument full suite, zero-warning analyzer,
native 1280×720 input/visual checks, save/resume and resource-conservation
checks, and measured 256-resident results. Qualification hardware limits are
reported honestly; local timing cannot certify an untested target machine.
No diagnostic/leak allowance is increased and no paid generation is authorized.
