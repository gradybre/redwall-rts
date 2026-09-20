# FieldPolicy component validation — independent source review
Read-only review of the applied owner predicate, the owner-3 bridge and the focused suite
against the accepted contract and ADR 0179. Nothing was edited, run or re-measured here; the
only execution evidence considered is the supplied focused log (8 tests, 42353 assertions, 0
failures) and the original public probe (76/0). No fault, mutation or CI result is asserted.
## Owner predicate (field_policy.gd)
The 20 typed `Columns` accessors carry the declared 128/384/4096 extents and `Columns.new()`
reproduces `clear()` exactly: -1 for zone_slot, rotation_ids, requested_crop, plot_field_slot,
1 for seed_reserve, zero elsewhere. No new gameplay default is introduced and no public
declaration array is duplicated for the bridge.
Observable order matches the contract: null/all-20 extents, then the global byte scans, then
the global rotation/cursor/requested-crop domains, then ascending field rows in zone → counters
→ state → request order, then the ascending plot ledger, then exact OPEN counts. The global
cursor domain precedes the per-row rotation index read, so `field * 3 + cursor` and the ledger's
`cycle_ordinal[field]` are both bounded before use; I found no unguarded index.
Domains agree with source: bytes are unsigned so upper bounds alone are exhaustive; the history
sum uses GDScript int arithmetic and cannot wrap at i32; inactive rows retain settings, close
reason, durable counts and withdrawals while requiring IDLE with zero participants/resolved;
present IDLE may keep a positive ordinal after recreation; CLOSED shapes follow `_close_cycle`
for COMPLETED, CANCELLED (empty or partially resolved) and ABANDONED. Retained-history
relations are applied on every row, and no closed count is reconstructed. A retained request is
accepted with auto_rotation off, all six declared states are admitted including defensive
NO_LEGAL_WINDOW, and ENTRY_NOT_CONFIGURED is tied to the empty crop by an exact iff. Stale and
IDLE- or inactive-linked ledger rows are retained; the OPEN scan counts non-WITHDRAWN as
participant, HARVESTED/CLEARED as resolved, and filters on present+OPEN with a matching stamp.
The no-OPEN early return sits after the scalar and ledger passes, as required.

The predicate is argument-only: static, no instance construction, no live Directory, Farming or
Forage lookup, no callback, no calendar decode, no input mutation or normalization.

## Bridge (save_owner_field_policy.gd)

Gate order is null → wrong owner → schema (forwarded unchanged) → metadata → section owner shape
(forwarded unchanged) → explicit assignment of all 20 typed accessors → exact column code.
Details use the required `FieldPolicy owner3 metadata:` and `FieldPolicy owner 3 ` prefixes and
carry the raw code; success is empty/empty. Preloads are the four permitted scripts, and the
Farming and EntityDirectory constants are reached through FieldPolicy's own preload chain —
legal constant access, not a live instance. The parent repair is present: the five actual crop
ordinals (beans 0, cabbage 1, flax 2, grain 3, roots 4) are pinned beside CROP_NONE/CROP_COUNT,
and the earlier unrelated default-rotation pin is gone. The owner comment now qualifies its
claim as no *live* reads, which matches the code.

Two accepted redundancies, not defects: the bridge's FIELD_COUNTS literals are not derived from
FieldPolicy capacities, but `_source_refusal` pins those capacities first; and the four owner
identity/extent terms share one detail string, so the individual failing pin is distinguished
only by the planned bypass harness, not by the code itself.

## Tests and oracles

The frozen cases cover the 20 projection omissions with malformed and legitimate non-default
tails, all seven byte and thirteen i32 cardinalities, shape-before-domain pairs, every physical
address across 128/384/4096, both zone shapes, the counter bounds and MAX endpoints, the state
and retained-history table, all request relations, the ledger clauses and the three exact OPEN
mismatches plus older-stamp, closed and inactive filters. Inputs are snapshotted and compared
after each call, so acceptance and refusal are both proven byte-identical. The added
CLOSED-with-NONE fixture is a genuine independent witness for the no-reason guard; the
admitted equivalence of the shared OPEN filter versus a tally-only removal is dispositioned
rather than claimed as a kill. The runner's assertion-count oracle correctly excludes parser and
runtime errors from counting as kills.

## Memory

90112 bytes is conservative logical packed arithmetic (44288 caller + 44288 default image + 1536
scratch); the projection shares input buffers read-only and the default buffers are released at
assignment, so the true peak is lower. Native allocation and RSS remain unmeasured.

## Disposition

No production defect found in the reviewed predicate, bridge or fixtures. Blockers before any
acceptance claim: the 69 required mutation units and the 20 metadata cases are not executed in
this review; cross-owner Directory/Forage zone identity, unique policy-zone ownership and
FarmPlot join rules are unbound; FieldPolicy bulk capture/apply does not exist; REQ-SET-088 seed
reservation and field orchestration remain separate gameplay work. Optional coverage only:
deriving the bridge's count literals from source constants, and splitting the metadata identity
detail per pin.
