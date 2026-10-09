# ADR1141 guarded hauling evidence

This is a lower-owner correctness component. The tests use actual Inventory,
Reservations, generations, journals, conservation, satchels, and claims. Their
handling/location guard is explicitly synthetic. The separate 1140 Delivery
component must supply actual endpoint, pose, phase, Job and source permission;
these tests grant none of those permissions.

The source base is 2542a860 (accepted root ledger 54b7932b on b518ca1f). The
accepted component is pinned by `source-review-3/source-sha256.json`. Root's
independent source review and exact rerun are recorded below. Composed Delivery
evidence remains pending.

| Attempt | Result | Scope |
|---|---|---|
| candidate-1 |10tests/505assertions/0; analyzer2warnings | First actual lower-owner run; retained naming-warning refusal |
| candidate-2 |313tests/4111assertions/0; analyzer0/4 | Guard, Reservations, reservation columns/carry, HaulCarry, HaulPlanner, Inventory and spatial Inventory |
| return-tail-rejected |12tests/555assertions/1 | New override probe catches ordinary `_ok` dispatch after Inventory commit; diagnostics/leaks0 |
| candidate-3 |40tests/895assertions/0; analyzer0/4 | Final direct-result correction; guard, reservation carry and spatial Inventory |
| candidate-4 |68tests/1105assertions/0; analyzer0/4 | Exact Pool lot-namespace check before the journal; guard, Reservations and reservation carry |
| inventory-tail-rejected |15tests/593assertions/2 | Actual reclamation/closure override invalidates handling after the guard; second failing test also had an invalid pile setup, recorded separately below |
| candidate-5 |216tests/2181assertions/0; analyzer0/4 | Concrete reclamation/closure and nested endpoint/allocator kernels; corrected actual spatial pile fixture |
| outer-commit-rejected |16tests/603assertions/3 | Successful Inventory commit/attestation overrides invalidate handling after `super`; all diagnostics/leaks0 |
| candidate-6 |346tests/4392assertions/0; analyzer1warning | Complete static successful boundary; nine strict suites; retained false-positive private-field analyzer refusal |
| candidate-7 |16tests/603assertions/0; analyzer0/4 | Only the exact static-field usage annotation changes; final focused suite and analyzer |
| independent-root-1 |16tests/603assertions/0; analyzer0/4 | Independent exact-source clean import, guard run and analyzer; all diagnostics/leaks0, temporary inputs restored |

Every passing strict/raw footer reports zero unexpected errors, warnings,
expected/tolerated diagnostics and leaked objects/resources. Each invocation
records exact source pins, commands, output, and source/project/assets/registry
restoration. The runner uses its own `Redwall-ug-haul-transfer` user directory
and analyzer port6303. Its temporary registry appendix is explicitly diagnostic
and is restored; this lane changes no shared registry or capacity artifact.

The final production changes close the entire successful call boundary: Pool
calls its concrete continuation, which explicitly calls Inventory's static
commit and static attestation. The original barrier stays raised through the
last observation and all direct final proofs. Concrete reclamation, closure,
row/list/heap publication and result construction follow. Ordinary APIs retain
their state algorithms. `census.py` compares ten Inventory and twelve Pool
extracted kernels against their original bodies after mechanically removing
only explicit receiver/static names; they match exactly.

The retained `inventory-tail-rejected` first failure is a valid actual subclass
reproducer: two reclamation/closure callbacks run after the successful guard
and invalidate its handling fact. That attempt's second test incorrectly
promoted a pile outside an Inventory journal, so its setup failure is not
additional source evidence. The corrected real pile is created, promoted and
committed through the actual Inventory transaction in candidate-5 onward.
The later outer-commit witness uses that corrected fixture and exposes two
override-after-super callbacks; candidate-6 closes both.

The exact final source differs from candidate-6 only by the documented
`unused_private_class_variable` annotation on `_haul_view`, which the static
continuation reads through its actual receiver. The warning limit remains zero.
The nine shared suites are not mislabelled as rerun at the annotation's hash;
candidate-7 is the final focused run. A valid Inventory lot outside the smaller
Pool namespace also refuses before either owner mutates, with a real-store
capacity-mismatch regression.

## Lifetime and source census

`python3 -B docs/validation/evidence/guarded-spatial-haul-2026-10-04/census.py`
reproduces `source-review-3/helper-census.json` from actual source.

The 216-byte Transfer contains eight full references and nineteen integer
scalars. Two reused packets plus the active bit occupy 433/512 logical bytes.
No Inventory or Pool packed column, per-Job state, claim epoch, quantity/WU
ledger, variable scratch buffer, or save schema is added. References to the
exact active Inventory/guard are released on every normal success/refusal.

The largest lower-owner path retains 347 numeric bytes. Conservatively counting
all seven typed OpResult local/parameter aliases as separate 17-byte numeric
payloads raises that to 466/512. Alias payloads count even before assignment, so
the estimate does not rely on interpreter liveness optimization. Native object
wrappers, reference slots, StringName/Variant headers and interpreter frame
overheads remain within a provisional 2048-byte allowance, not a native
measurement. Total newly reserved bytes remain 3072.

At the concrete Delivery callback, the lower stack accounts for 115 bytes in
the same 512 helper allowance. Delivery borrows the 216-byte view rather than
allocating another packet. Its own source/control/callback lifetime belongs
once to its separate 4096-byte reservation; final paired review must verify
that composition. This component does not authorize allocating a new arena.

## Original transaction boundary

The bound actual Pool holds its private original Transfer and a separate view
before economic observations. Public Pool mutations, including clear/restore,
refuse and poison that scope. Staging changes only the original Inventory
journal. The final concrete observer runs with Inventory `_attesting` raised.
Direct original owner/scope, all 27 packet fields, claim and staged source/
destination/satchel facts follow it. The barrier remains raised through direct
Inventory cleanup; Pool invokes the static entry rather than an overridable
successful instance boundary. Successful Inventory commit is followed by
concrete Pool row/list/heap publication and direct result construction.

ADMIT combines destination grams and source claims. LOAD stages a new satchel;
REPOST changes only the claim key; UNLOAD accounts for the original satchel's
possible retirement. CANCEL releases the original claims and destination grams
together, preserving goods and allowing cleanup after productive identity has
ended. Existing seeds/spatial callbacks cannot close the journal or mutate
original Pool rows at any of these final boundaries.

Diagnostic-source directories are immutable snapshots for the concurrently
owned 1140 worktree; they are not separate accepted implementations. The first
snapshots remain as historical locators after diagnostic-source-5 supersedes them.

## Independent acceptance

Root independently read the complete static successful boundary and extracted
algorithms, reran the source census (433 fixed, 466 maximum helper, 115 lower
callback bytes), and reproduced original-body equality. The independent exact
guard run in `independent-root-1` passed 16 tests and 603 assertions with zero
strict/raw unexpected, expected or tolerated diagnostics and zero leaks;
analyzer 0/4 and clean import also passed. The invocation confirms unchanged
source and restored registry/project/assets. Root accepted `source-review-3`
for lower-owner correctness and source census on 2026-10-04. No actual Delivery,
production motion or native/runtime memory qualification follows from this
component acceptance.
