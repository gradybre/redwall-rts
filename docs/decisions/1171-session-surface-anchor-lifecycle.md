# 1171 — Session surface-anchor lifetime

Status: independently accepted lifecycle component, 2026-10-05. Activation,
current shared-ledger integration and native memory qualification remain open.

## Original owner and public API

After the accepted Room and route owners are complete, the actual Session may
call `compose_surface_anchor() -> StringName`. The host exposes the matching
`compose_underground_surface_anchor() -> bool`. A successful checked
`Session.surface_anchor()` borrow returns the original actual SurfaceAnchor;
its existing `create` and `create_in_section` APIs remain the only publication
path. Callers supply real integer point, clearance and support geometry. No
endpoint, actor, route, excavation, Room or work permission is fabricated by
composition. Main/demo wiring remains root-owned.

One typed `Retirement.Owners.surface_anchor` strongly retains the receiver
behind Locations' existing one-way weak WorldScope. The private retirement
Scope copies that same field. There is no second permanent owner packet, new
bank or per-entity field. Exact null, expired, foreign and original weak
backlinks remain distinct. New prefix 9 is meaningful only in this actual
Session's constructor state; it cannot be declared by an external caller.

The constructor first proves the complete original route tuple and no existing
WorldScope. A private candidate may be dropped only before its one-way weak
binding exists. Once bound, any late source/owner/reentry refusal retains that
candidate and stops the Session until complete World reset. SurfaceAnchor's
own failed-configure handling must preserve an already-bound original receiver
instead of erasing the pins behind a live weak link. A refused private attempt
can restore route-ready state only after current source and pure original-owner
closure. Successful composition is idempotent and creates no surface record.

## Whole-World retirement

The owner-owned static anchor leaf proves all original stored collaborators,
the exact Locations weak backlink and quiescent publication/cold fields. It
uses no World, Directory, source or other observing getter, so it remains
valid after canonical stores retire the old World. Existing full-World and
empty-store retirement leaves still govern release. A captured anchor cannot
be replaced or omitted during repeated prepare/release. The host drops its
Scope cycle before dropping Session. A retained external Anchor must not keep
the old private arenas alive after this release. A narrow static owner-owned
release leaf runs only after complete original-World preflight and canonical
clear, after the existing four owner releases. It drops only the Anchor's own
21 borrowed owners and four fixed scratch payloads. Its original nonnull full
World reference remains an irreversible tombstone: the same handle cannot be
configured against the remounted World. A refused preflight or partial clear
retains every original pin and keeps the host stopped where required.

The prior implementation refused operations from old handles but retained their
heavy owner graph. This is a HIGH resource-lifecycle defect, not an unmeasured
native-header caveat. Its exact source and successful narrower tests remain
historical. New actual host tests must retain the old Anchor strongly across
reset/remount while weak references prove the old private owners and banks die;
they also cover live-World direct-release refusal and partial-clear retention.

## Bounded storage and verification

The new field costs two 32-byte provisional reference slots across
the permanent Owners and private Scope copy. Controls become 6,131 of
6,144 bytes. The prior route constructor has only 31 bytes free: the permanent
32-byte slot alone would exceed its unchanged 8,192-byte envelope by one byte.
The Host's existing post-construction result check moves into its own helper,
so the constructor frame no longer contains that later 8-byte local. Count
both real frame chains, every anchor helper and its existing 2,048-byte reserve;
no null slot is counted as free and no temporary reuse is assumed. The complete
source census reports 6,131/6,144 controls, 1,919/2,048 reset/UI helpers and
4,034 + 4,151 = 8,185/8,192 constructor coexistence. The independent Anchor
configure chain is 2,362 within that same maximum. Its existing separately
charged logical reservation remains 329 fixed numeric/packed/result + 1,024
helpers within 2,048. All 21 borrowed references, two retained packet objects
and four buffer headers are enumerated; native reference/header/allocator
costs remain provisional and unmeasured. No whole-native fit is claimed.

Evidence lives in
`docs/validation/evidence/underground-surface-anchor-lifecycle-2026-10-05/`.
Historical candidate2 passes 129 tests/3,566 assertions but omitted old-owner
collection. The retained new regression fails against its exact runtime bytes:
30 tests/451 assertions/one failed test, zero diagnostics/leaks. Corrected
candidate3 passes 97 tests/2,995 assertions in the four affected suites, zero
strict/raw diagnostics/leaks and analyzer 0/8 with full source/project/registry/
assets restoration. All 20 weakly observed private owners/banks die while the
old Anchor remains held across actual remount. Root's
first review found an offline census guard omitted packed literal payloads;
the exact rejected scripts/report are retained. The corrected source census
and its 25 mutation tests preserve the same arithmetic while refusing that
growth. The current 30 tests also require complete own-pin release, immutable
retired World tombstone, static full-World-empty proof and exact release order.
Root independently accepted exact source-review-3: all 11 source, six input,
45 output and 145 history pins plus 140 historical locator rows verified;
all 30 census tests independently passed. Both the MEDIUM allocation-guard
finding and HIGH retained-Anchor lifecycle finding are closed. The exact review
receipt is retained as `accepted-review-3/root-acceptance-review3.json` with SHA
`8d689dfa42847f7a243d78fe73f0b0373926bec220fc0b073266729658723bd0`.
The reviewed source/manifests remain unchanged; earlier ADR/README bytes are
preserved through explicit locators. Implementation success is not a movement,
profile, demo or native-memory qualification.

Tests must use the current real publication, actual generated Host and actual
SurfaceAnchor. Cover real natural support publication, unchanged economic
stores, idempotency, each original owner/backlink refusal, reentry, pre/post
binding failure, active publication retirement refusal, populated reset and
remount, captured-Scope replacement, and stale handles. Preserve all rejected
runs; require strict diagnostics/leaks zero and changed-file analyzer zero.
No new reserve, capacity, geometric tolerance, gameplay timing or paid action
is adopted. Existing source, profile, terrain, access and playable-room gates
remain separate.
