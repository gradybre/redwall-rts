# 1079 — Paid output dispatch through actual spatial Inventory endpoints

2026-10-03. UG07/UG09 implementation decision. Extends the shared paid receipt
owner from 1073 through Inventory's actual multilevel endpoints from 1076.
Actual world contact/profile qualification remains owned by 1075; explicitly
synthetic geometry in these transaction tests does not qualify gameplay.

## Boundary and representation

The paid owner does not accept XYZ, a floor index, a substitute surface tile,
or a caller assertion that an underground pile is safe. Its retained output
is the full actual Inventory container identity. Inventory already owns the
complete location reference, immutable payload revision, World binding and
finite 400000g staging/pile contract. The existing `promotion_tile=-1` is used
for spatial endpoints; any supplied surface promotion tile refuses there.

The refusal-carrying flat-anchor reader distinguishes a valid surface or
unplaced container from `SPATIAL_REQUIRED`. The latter requires fresh full
location and positive revision readers. An unavailable spatial location never
falls back to a surface address or an ordinary unlimited container. Private
negative anchor encodings are neither decoded nor treated as spatial proof.

## Atomic output and cancellation

The existing Funding arena consumes real claimed inputs and reserves actual
output mass. On completion its existing Inventory transaction releases only
that project's reservation, creates the adopted output lots, then promotes the
same nonempty spatial staging container through the actual Inventory API.
Any location, source, capacity or promotion refusal rolls the whole transaction
back and retains WIP, earned work and physical source history for retry.
An already published spatial ground pile needs no second promotion.

Refunds use the same transaction. A positive return into a spatial staging
destination promotes that destination after the exact metadata-preserving
refund is created. A zero-material cancellation requires no refund destination.
The old pending output is retired only when empty and unreserved; another
project's remaining output reservation keeps its real staging row and endpoint
alive. Existing loose goods remain real goods and are never destroyed by
cancellation. The zero-lot ground-pile invariant is unchanged.

Sites and the modular router recheck actual output placement before productive
start and completion, in addition to their independently required physical
contact authority. Unstarted Sites cancellation also retains shared staging;
only its actual bound empty, unreserved staging is eligible for retirement.
The router has no retained output before successful paid start, so a caller's
unaccepted staging remains owned by its spatial admission lifecycle.
Cancellation's material transaction is atomic, but the complete cancellation
operation is deliberately retryable: it may first freeze Construction and
release actual workers or unconsumed input claims. A later endpoint refusal
does not restore those safely released claims or pretend the whole collection
of owners was unchanged. WIP, loose goods, output reservations and physical
source state remain retained until their actual settlement succeeds.

## State, memory and remaining work

This increment adds no persistent columns, numeric component controls, packed
scratch, Quote, IntResult, per-worker state or receipt arena. It reuses each
component's existing result scratch. Cold calls retain temporary full refs,
integer/boolean controls and existing Inventory operation results on the
stack. The deepest new helper chain has at most90 bytes of additional logical
numeric arguments/locals (full refs, integers and booleans), conservatively
counting the whole chain rather than subtracting replaced frames. This is
transient call-stack use, not another persistent/candidate/load image. Existing
Inventory APIs allocate at most one locally retained operation result in a
new helper at a time. StringName/Variant frame and native engine overhead are
not equated with logical payload bytes; the joint native/runtime qualification
remains open in 1072. No new component-level allocation is hidden as zero.
Surface output behavior and the unchanged Inventory transaction journal remain
in force. The versioned composed spatial save codec remains UG16 work.

Required verification covers actual paid first cuts, spatial source/endpoint
staleness before and during commit, retry and duplicate prevention, stacked
locations, positive spatial refunds, zero-input cancellation, shared actual
project reservations and preservation of unrelated material claims. Final
strict test/analyzer evidence is recorded below.

## Verified bounded increment

The exact five-source candidate was independently reviewed by the root
integration owner with no remaining high/medium correctness blocker. A fresh
CI-style own-worktree import produced zero error/warning lines. Six unchanged
strict singleton shards passed **124 tests / 29770 assertions / 0 failures**.
Every runner and raw-log footer reported zero unexpected errors/warnings and
zero leaked objects/resources. The five-file actual editor analyzer with
`--max 0 --port 6156` reported zero warnings. Markdown registry source coverage
remains104 modules /490 rows /833 packed columns; no source state declaration
changed in this increment.

The new tests use actual paid Sites and Router/Construction/Work/Gear/Inventory
owners, including two actual paid cut projects retaining independent output
reservations in one staging container. Geometry and the modular reclaim source
permission are explicitly synthetic. Real-world support, active hauling,
Furniture installation and composed save/load are not claimed by these tests.
An initial test omitted the real mandatory tool declaration; another omitted
accepted worker registration before cancellation. Both correctly failed the
strict suite, and only those fixture setup omissions were corrected.

Source hashes, full final logs, analyzer output and initial failure evidence
are retained in
`docs/validation/evidence/underground-paid-spatial-outputs-2026-10-03/README.md`.
