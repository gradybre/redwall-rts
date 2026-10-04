# 1087 — Admit the full cold room-layout operation before copying

Date: 2026-10-03

Status: Implemented, independently reviewed component; live UI/actual batch composition remains open.

## Problem and scope

Decision1054 implemented permanent room-bound furnishing modes, draft layouts,
footprint/contact checks and atomic coordinator submission. Its three independent
Callables could read geometry before any shared cold-memory admission, and its
returned guide arrays and raw placement-list copies had no lifetime contract.
Protecting only the submission callback did not protect earlier room/snapshot
callbacks from reentry. These omissions would let a composed layout operation
exceed the joint1072 allocation pack or hold its worker arena after a hover ended.

This increment replaces that binding and makes its entire cold lifetime explicit.
It adds no paid recipe, geometry permission, room policy, authoritative packed
column or installation behavior. Multi-item actual Furniture/Construction
publication and its sealed future-source bridge remain the next increment.

## One typed, exact provider

`RoomLayout.bind_sources(Sources)` replaces the three-Callable interface. There
are no production consumers of the removed signature; the existing semantic test
fixture is migrated. The base typed provider refuses every permission. A concrete
provider must bind the actual world/owners and their one shared Budget, with no
coincident-number substitute. An existing planner can explicitly reconcile the
same provider object, but cannot switch to another or revive an expired provider.
Persistent wiring is weak; only the active synchronous scope retains its provider.

The planner sets its exclusive guard before its first binding/acquisition callback.
`binding_refusal` is an allocation-free composition check; `begin_operation` must
acquire the actual complete simultaneous cold peak before any room-liveness,
snapshot or submission callback. It receives the exact Room ref, configured
geometry/placement limits and the planner's conservative packed bound. Its
`scope_refusal` must validate the exact live token, actual world/owner and retained
charge, without allocating another image. `end_operation` drops provider
companions before releasing only that token. Acquisition refusal starts no
copying/liveness read and never releases another owner's lease.

Every room read, draft operation, mode read/change, placement-list copy and
receipt identity/cleanup operation uses the scope. Discarding a local draft needs
no world image, but still rejects reentry or an outstanding result. The planner
borrows one Snapshot per operation rather than rereading for both open-room and
layout validation. A returned owner callback cannot expire/reacquire the shared
arena and then authorize more planner copying under the original token.

Malformed coordinator success still quarantines submission until explicit
same-provider reconciliation. Every successful local/world mutation sets the
Result's `mutation_committed` flag. A subsequent scope or release contract failure
preserves its truthful `ok`, reference and value, reports `cleanup_error` separately,
and quarantines the provider from further automatic commands. Read-only operations
may still refuse. Explicit reconciliation with the same actual provider is required
before another operation; cleanup failure never advertises rollback or authorizes
resubmission of an already accepted project. The planner cannot roll back unknown external
writes and does not claim to. The production provider must be the reviewed actual
atomic owner; this increment's geometry/project fixture is explicitly synthetic.

## Results end within the same input call

`preview`, draft `place`/`edit_draft`, and `placements` may return packed views.
`placements` now returns `Result.placement_rows` instead of a raw packed array.
Any nonempty guide or row result retains its exact admitted lease, including a
failed placement's affected-cell highlight. A Result exposes `requires_release()`
as a display hint; the planner separately pins the actual object and actual token.
Copying those mutable fields into another Result grants no release permission.

The display must consume the views and call `release_result(result)` synchronously
before returning control to simulation, frame processing or input dispatch. It
may write into its already admitted presentation buffers; it must not retain an
alias or make an unaccounted copy of these arrays. This is not an asynchronous or
frame-lived preview API. The unchanged authoritative drafts/receipts persist in
packed planner columns independently of the views.

Release clears all five packed Result arrays, its lease hint, and the planner's
borrowed snapshot before provider companion/arena cleanup. It cannot release a
foreign Result, forged token or a later operation through duplicate release.
Scalar receipts and command results auto-release. `confirm_layout` deliberately
clears validation guides before returning its scalar project receipt.

Every display/input integration must also call `finish_input()` before yielding
back to the frame. A missed release returns `ROOM_LAYOUT_RESULT_ABANDONED`, clears
the exact pinned result and releases its operation. This cleanup still works if
the caller corrupted mutable result metadata. A dropped result is weakly detected
and diagnosed before another operation can begin; it does not silently start a
new copying operation. `quiescence_refusal` exposes an in-progress/retained-result
violation for input, simulation and save boundaries. These boundary calls are
required integration work; this component is not yet connected to the live UI.

## Storage and admission ledger

The thirteen authoritative RoomLayout columns and their three saved capacity
scalars remain unchanged. Section6/schema1 obligations from1072 still apply; this
is not a new codec or a waiver of UG16's composed restore checks.

For configured geometry capacity G and placement capacity P, the new public
`cold_packed_bytes` bound is **336G + 64P + 512** logical bytes. Invalid source
ranges return zero. This is conservative simultaneous payload, not measured RAM:

- One Snapshot: at most208G bytes for floor/masks/links and all nine bounded
  profile contact pairs, plus28min(G,P) for existing object columns.
- Geometry validation/guide payload: at most96G plus fixed tiny transformed/
  affected-cell buffers. This covers three masks, aggregate contacts, adjacency
  values, reached/queue state and occupied/install/use guides. The other temporary
  phases have smaller simultaneous packed payloads.
- Draft rows, copied entry packets, Batch and submitted project receipts fit
  within64P. The placement-list path needs24P for its six-I32 rows plus its finite
  selected-row list; it does not run geometry validation simultaneously.
- The512 fixed allowance covers the bounded numeric/frame scratch coexisting
  with those payloads. Native object, Variant/container headers, retained profile
  banks, append/copy-on-write allocation growth and all provider-owned images and
  companions are **additional actual admission obligations**.

Native dictionary entry count is separately bounded by **max(6G, 2P)**: the
largest validation peak is cells + link deduplication + adjacency maps; receipt
validation includes retained and new project references. This count is not a
native byte-size measurement and does not itself grant permission. A concrete
provider must reserve/qualify the native/growth envelope as part of the joint pack
before allocation, and must reject a request that cannot fit. No independent
maximum automatically becomes a production configuration or gameplay room limit.

The planner adds17 logical numeric runtime-control bytes (one I64 token, one
Vector2i room and one submission-quarantine bool); the existing exclusive bool
was already present. A single escaped Result adds an I64 lease hint, plus one committed-outcome bool, for **26 new
logical numeric bytes** across the possible retained lifetimes. Weak/strong
references, cached Snapshot reference, pending-result WeakRef and StringName
error references have separately admitted native overhead. No persistent owner
column, per-resident allocation, additional authoritative receipt arena or paid
work record is added.

For the semantic fixture G128/P16, packed admission is44544 bytes. At inherited
G16384/P81920 maxima it is10748416 bytes, which the actual shared Budget refuses
before copying. Those maxima are technical bounds, not an assertion that the
joint production pack admits that simultaneous workload. Fine room cells and
painted boundaries are preserved; there is no snapping, shape inflation or new
room-size rule. Actual production operation sizing, composed provider image
lifetimes, native allocation measurement and frame-time qualification remain open.

## Verification

The existing39 furnishing semantic cases retain their original legality, mode,
identity, receipt and atomic-refusal checks. Their fixture now explicitly uses
the actual shared Budget for scoped payload admission and consumes results within
one test input call. Fixture world geometry/profile/atomic-project permission
remains synthetic; its long-lived assertion copies are test-owned evidence,
not a production provider or memory-qualification claim.

Additional cases cover exact typed provider identity, base refusal, expired weak
binding, initial-binding/begin/read/release reentry, actual busy/capacity refusal
before reads, single-snapshot reuse, failed guided previews, exact release order,
forged/foreign/duplicate release, dropped/live/corrupted abandoned results,
expired/replaced snapshot leases, scoped placement lists and scalar confirmation.
Independent review found and corrected a late-outcome bug: final scope/release
checks originally replaced committed success with ordinary refusal. New adversarial
cases fail the exact final scope check after project receipt publication, fail
end-operation cleanup after acceptance, and fail the final check after a local
draft write. Each preserves the actual committed outcome and quarantines further
automatic commands; explicit same-provider reconciliation retains the original
project/draft. Earlier rejected diagnostic evidence is retained with the final run.
No full-suite, live UI, composed acceptance or performance pass is claimed here.

Final own-worktree CI-style verification used absent demo assets, removed the
own `.godot` cache, and ran `godot --headless --path godot --editor --quit` before
the unchanged strict runner's complete-manifest singleton shards:

```text
57 test(s), 563 assertion(s), 0 failure(s)
6 test(s), 58 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

The quoted diagnostic/log footer applies to each suite, not an exit-code inference.
Aggregate63 tests/621 assertions/0 failures. Frozen hashes, clean import, exact
manifests, raw accepted logs and the rejected intermediate diagnostic assertion
are retained under `docs/validation/evidence/underground-layout-cold-2026-10-03/`.
The independent furnishing agent reviewed the complete initial diff and its
narrow correction, accepted source `ef3d922da5eb324bbca8523b31a51b3d2b9cd90a310b3e6422f7f0700171b6b2`
and test `7790b62c048edecb36779a5c7a65355291ca305b3bc5511bae15ff7d44e267d5`,
and found no remaining high/medium blocker in this bounded contract. They did not
duplicate the engine run. No full-suite pass is claimed.
