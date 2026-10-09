# 1086 — Observe and publish mixed-kind Directory identity batches

Date: 2026-10-03. Status: increment A independently reviewed and verified.
This is an engineering prerequisite for UG07's accepted
furniture-layout orders, not playable layout acceptance or a new gameplay rule.

## Why a batch observation is needed

Decision 1083 proves and publishes one planned Room identity. A layout in one
already completed Room instead needs a pending Furniture identity and a real
Construction project for each accepted item. Looping the existing creation APIs
can consume generations and PIDs before a later allocation refuses. Destroying
those partial rows cannot restore the original identity history and is not an
atomic admission protocol.

The Directory now exposes `CreateBatch`, `peek_create_batch_into(kinds, out)`,
`batch_candidate_refusal(batch)` and `create_batch(batch)`. The first two methods
observe/revalidate actual allocator choices without reserving either heap. The
last revalidates every tuple before its first owner write, then publishes through
the existing min-heap and row-initialization primitives in one callback-free,
non-yielding call. It returns a refusal code; the packet retains the ordered
full references for receipts, so success does not allocate another result array.
The single-identity APIs and every lifetime/capacity rule remain unchanged.

## Exact mutable observation, not an authorization token

The caller supplies the explicit maximum tuple capacity K. Each successful
observation records slots, generations, kinds, typed rows and PIDs, plus the
actual weak Directory owner. Validation checks the whole ordered prefix against
the current free sets, full generations, PID cursor and current per-kind/living
limits. A numerically identical foreign Directory, stale suffix or malformed
storage refuses before any Directory column, heap, counter or diagnostic changes.
An intervening allocation spends history even if it is immediately destroyed.
Unrelated retirement that leaves all observed choices unchanged need not fail.

This packet is mutable caller scratch, just like 1083's single candidate. It is
not a sealed proof of the caller's original purpose: a consuming Buildings,
Construction or spatial coordinator must separately pin its expected tuples,
actual World and typed authority, then enforce its own exact same-call-stack
publication window. Validly editing the request into another actual allocation
does not grant geometry, recipe, service or room permission. Do not carry packets
across reset/restore; no epoch or serialization has been added to imply that is
safe. A failed peek/reset invalidates count and weak owner; retained array tails
are scratch and cannot be read as receipts via `ref_at`.

## Bounded read-only heap traversal

The source free windows are already min-heaps. A second, caller-owned frontier
stores indices into an unchanged source window, ordered by the values at those
indices. Visit the minimum node, remove it from the frontier, and add its existing
children. The next frontier minimum is the next allocator choice. At most K+1
indices coexist for K visits. Reuse the same frontier first for global slots,
then for each requested kind's typed-row window. A fixed eighteen-kind scan maps
typed rows back into the original mixed request order.

This costs O(K log K + 18K) work and O(K) bounded scratch. It never copies, sorts,
reserves or edits a live allocator heap. There are no new Directory columns,
global epoch, per-identity objects, generation rollback or historical recycling.
The API is cold admission work, never a productive worker-tick query.

## Memory, lifetime and save accounting

Construct the packet only **after** its actual caller has admitted the complete
cold lifetime. `CreateBatch.packed_bytes(K)` provides the allocation envelope
without constructing a packet. Valid engineering capacity is 1..352418, derived
from the existing Directory capacity; invalid requests allocate no packed data.
This upper bound is neither a default allocation nor a room/furniture policy.

| Packet storage | Packed bytes |
|---|---:|
| Five I32 tuple columns | 20K |
| I32 frontier indices | 4(K+1) |
| Eighteen I32 requested-kind counters | 72 |
| **Total** | **24K+76** |

Capacity and observed count add **16 logical numeric control bytes**. WeakRef,
RefCounted/packed-array headers, runtime native allocation/growth, helper frames,
the separate input kinds and any consuming owner's pinned copy are additional
real lifetimes. They must be admitted by the actual shared cold owner; this
component does not pretend that an allocation formula alone grants a Budget
lease. For N Furniture+Construction pairs K=2N, packet payload is 48N+76; there is
no extra 8K receipt-result copy. The Directory adds no long-lived state or save
bytes. The entire packet is category 3, discarded before load/save composition.

## Remaining integration

Atomic layout acceptance still requires the real Buildings/Construction future
row publication, sealed future Furniture source/claim geometry, complete fit and
contact proof and actual RoomLayout receipts. Those owners must finish every
fallible preflight before the Directory batch publishes. The RoomLayout cold
lease must begin before snapshot/dictionary allocation and remain held until
copied validation/receipt/companion scratch is dropped. Provider callback entry
must become exclusive before the first callback. Increment B remains queued
until that concrete owner packet is reviewed; this API does not claim it done.

## Verification

Evidence is retained under
`docs/validation/evidence/underground-identity-batches-2026-10-03/`.
Own demo assets were absent; the own worktree's `godot/.godot` was deleted before
`godot --headless --path godot --editor --quit`. The final clean import emitted
zero error/warning lines, then three singleton CI shards ran through the
unchanged strict `tools/run_tests.sh`:

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| Mixed-kind batch | 21 | 7971 | 0 |
| Existing single candidate | 11 | 358 | 0 |
| Existing Directory | 61 | 638 | 0 |
| **Total** | **93** | **8967** | **0** |

Every suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports `0 GDScript warning(s) in 0 of 2 file(s)`. Registry coverage
passes with no added persistent or derived Directory fields. Independent parent
source review accepted the frozen Directory and batch-test hashes, checking
frontier ordering/K+1 maximum, all-tuple preflight, lifetime limits, mutable
observation semantics and the complete memory formula. It reported no remaining
high/medium finding and did not claim to rerun the engine suites.

Tests use actual Directory columns, ordinary allocation/destruction and raw full
byte images, including heap order/tails, counters and diagnostic names. Coverage
includes all eighteen kinds, repeated mixed kinds, fragmented heaps, exact K=1
scratch, single/batch interleaving, changed final tuples, foreign/expired owners,
malformed storage, full singleton/fish capacities, the real 256 living limit,
generation-safe reuse, final PID exhaustion and permanent retirement. Synthetic
cursor/generation/retired-column setup is explicitly named where it reaches
int32 lifetime/global exhaustion without billions of operations. It does not
pretend to be a populated gameplay world.

The final cold 2048-identity (1024 Furniture+Construction pair) fixture measured
5998 µs observation, 6134 µs revalidation and 14050 µs commit **including its own
revalidation**, with a 49228-byte packet. Timing assertions are deliberately
absent. These are one local Apple Silicon debug/headless sample, not percentile,
target-hardware, whole-layout or productive-tick qualification. An earlier
expanded-suite pass measured 6122/6044/14228 µs and remains in the evidence
history. These measurements reinforce the cold-only contract; they do not close
the composed UI/runtime budget or actual shared cold-memory admission.
