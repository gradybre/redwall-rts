# Preserve full Expedition identity on fishing claims

FISH-ID-R01 · version2 · 2026-09-19 · Astra accepted after independent review disposition

A public runtime witness disproves the current typed-row/generation-only identity.
Expedition A=(2,1) claims row0, is destroyed, and a valid new HarvestZone consumes
slot2 at generation2. Expedition B=(3,1) then reuses Expedition row0. The existing
claim getter reconstructs B, the stale sweep releases0, and B can release A's
claim. Evidence: claim-reconciliation-planning-2026-09-19/fishing_identity_probe.gd
and its log. This is an existing live ownership bug, not caused by PR157 and not
limited to save/load. A bound checker cannot recover a slot that was never stored.

## Selected repair and invariants

Add `_effort_claim_expedition_slot: PackedInt32Array[512]`, canonical category1,
blank−1, to Fishing. Store the full Directory pair at claim publication. Clear
both slot/generation on release/clear. The typed row remains the claim's address,
not its complete owner identity. No new allocator, Directory generation policy,
Expedition store, scratch column, gameplay quota or save-time repair.

`_refuse_effort_owner` reports CLAIM_PRESENT only for the exact saved slot AND
generation; a different pair on an occupied typed row reports existing CLAIM_STALE.
`effort_claim_row_into` compares both fields after live Directory validation and
row lookup. `effort_claim_expedition_ref_of` returns the stored pair for an active
claim, even if stale; no reverse-map reconstruction. It returns NULL_REF only for
an inactive/out-of-range row. Existing stale purge then detects A's dead pair even
when B has the same generation. Purge releases A's effort once through the normal
public release path. B cannot release/query/inherit the claim before that sweep;
B can make its own new claim after cleanup. Same-slot newer-generation behavior
must continue to work. No hidden purge during capture/restore/reconciliation.

Owner exact APIs introduced by PR157 now carry EIGHT arrays: append
`effort_claim_expedition_slot` to EffortClaimColumns. Constructor blank−1, exact512
shape, capture duplicate, restore private duplicate/publication, all failure
atomicity unchanged. Active slot0..352417; inactive−1. Validate the new field at
its appended wire position, after the existing seven fields; no live lookup.
Forage behavior, columns, schema and all other Fishing sections remain unchanged.

## Versioned wire / canonical classification

Append `_effort_claim_expedition_slot` at fishing ordinal7, i32/code2,
EXT_PRIMARY/512, countfield−1; do not renumber ordinals0..6. Update codec exact
blank rules, slot validation and the owner adapter's named ordinal7 mapping.
Keep codec's existing quantity semantics and owner's stronger quantity gate.

Fishing owner schema1→2, section7 schema3→4, registry version5→6. Outer format2
and all other owner versions unchanged. Canonical record_count602→603,
packed_source_field_count553→554, total listed610→611, owners52unchanged.
Generate declaration table and capacity fingerprint using repository tools.
Explicitly reject owner schema1 and section schema3 before reading new-layout
column bodies. Do not guess the missing slot from the current reverse map or
migrate ambiguous old development saves. Add `decode_into_versioned(bytes:PackedByteArray, offset:int, byte_length:int,
section_schema_version:int, out:Record)->SaveHeader.Refusal`. Existing decode_into
delegates with current SECTION_SCHEMA_VERSION. Future coordinator passes the
actual descriptor version; no defaulted version argument or old-layout fallback.
Gates: extent_refusal, byte_order_refusal, section schema, nullout, then the
existing reader/storecount/key/owner-schema/primary/length/body-validation flow,
ending in one out.copy_from. New codes SAVE_INV_SECTION_SCHEMA_VERSION and
SAVE_INV_NULL_RECORD with nonempty details. Stale section wins over stale owner;
invalid extent still wins over schema. No staging before these new gates.
Existing owner wrapper schema check already precedes primary/body parsing.
Hand-frame the old seven-column owner1 fixture from the pre-repair independent
generator; do not rely on a removed old-layout encoder to test refusal.

The codec's appended ordinal is canonically signed−1 when inactive. Its general
blank constructor must produce that value. Tests must pin complete declaration,
full framing and old-schema refusal, not just an owner round trip.

## Allocation and byte evidence

New runtime array=512×4=2048bytes. Claim payload25R→29R=14848bytes atR512;
8countwords+4child-count bytes give14916payload, wrapper31 gives14947block.
Delta2056wirebytes=2048payload+8newcountword. Forage434298block unchanged.
Owner3P, adaptercapture5P/apply4P use newP14848; native overhead/other sections and
external snapshots stay outside these conservative call bounds, not RSS claims.

Registry growth exposes an already-stale declaration-table ledger: current610
listedfields/52owners/9022UTF8keybytes give52×16+610×15+9022=19004bytes, versus
ledger18825 (old604fields/8933keys). Correct that179-byte prior omission explicitly,
then append the29-byte new field key+15bytes metadata=44. New declaration19048.
Do not describe the whole223-byte correction as this field's metadata alone.
New total resident ledger delta2048+179+44=2271; no other permanent columns.
Fixed-field printed sum25036642→25038690,144field-group rows unchanged (I32group
6→7). Allocation rows33unchanged; total70003020→70005291; reserve8388608 yields
live78393899/headroom21606101. The prior candidate figure63787436 incorrectly charges the entire18825-byte
immutable declaration to a second world. Exclude the WHOLE new19048-byte static
production declaration (canonical_state_hash._production is shared): print all six
terms3670016+2097152+262144+131072+55200+19048=6234632. Candidate is
70005291−6234632=63770659; two-world rejected peak142164558, headroom−42164558.
This corrects the prior overcount explicitly; do not exclude only the223-byte growth.
These are reproducible planned payloads; expanded movement/unmeasured overhead
and other existing qualification limits remain open.
Update architecture and ready07 arithmetic together, preserving explicit expected
field/payload/live/candidate totals and historical trail. The old24-row
`godot/tools/memory_ledger_rows.gd` is already a stale60823126-byte diagnostic
transcription, versus the live33-row ledger. Label its header and test as a dated
historical snapshot; retain its fixture numbers. A named follow-up owns full
probe refresh; it is not current budget acceptance for this repair.
Replace the hardcoded604/8933 declaration arithmetic with actual registry-derived
census and explicit expected totals, so future registry growth fails if unledgered.
Do not rewrite historical evidence/snapshots to conceal their old counts.

## Required tests / ownership

Astra owns parent regression tests, metadata, generated declarations, ledger and
source-preservation evidence. Claude authors bounded runtime/codec/adapter patch,
then an independent reviewer checks final integrated source and tests.

- Actual public witness must turn green for the repaired semantics: storedref=A,
  B lookup/release refuses, purge1, exact effortdebit, secondpurge0, B newclaim works.
- Same directory slot/newgeneration, different slot/equalgeneration, two live
  samegeneration Expeditions and exact original owner success; wrong row association
  remains a full-world check. No claim is reattributed by restore.
- Exact eight-array blank/sparse/full shape, null/extent/refusal/alias tests;
  slot0/MAX accepted structurally,−1/352418 refused foractive. Other sections,
  ordering, caches and callers unchanged on refusal; all old source-count rules.
- Public destroyed-owner capture/restore preserves full stale pair, followed by
  normal purge matching uninterrupted state. Compare count, aggregate and reuse.
- Canonical hash/projection differs when only owner slot differs, exact allfield
  mapping, independent literal empty/sparse/full goldens for new schema; unchanged
  Forage goldens. Existing section7 encode/decode and canonical fixtures updated.
- Old owner1/section3 refused explicitly with caller Record/output unchanged.
- Mutants: remove slot equality, reconstruct owner from Directory again, omit
  slot publication/restore, omit canonical slot declaration; meaningful distinct
  failures and exact-source restoration. No equivalent COW mutant claim.
- Full tests, editor, all static gates, independent source review, exact-head CI.

No first playable, full save/load, completed section7 assembly or cross-section
reconciliation acceptance follows. The new field must land before the claim
reconciliation contract is finalized. Ordinary engineering correctness repair
within the existing approved game; no spend or product-scope change.

## Resolved review details

Declare Fishing.CANONICAL_OWNER_SCHEMA_VERSION=2 beside exact columns; codec reads
it just as it reads Inventory's version. Append codec NEGATIVE_ONE_FILL_KEYS entry,
BLANK_ORDINALS_FISHING ordinal7 and active slot checks[2,4,7]. Both record/live
owner shape predicates, typed validator signature, capture duplicate and private
restore phase must include the eighth array before any indexing/publication.
Adapter i32group6→7, namedordinal7 mapping both ways; Forage remains untouched.

Parent source census confirms Directory capacities Expedition512/Job8192 and
DIRECTORY_CAPACITY352418; no speculative bounds bug in healthy typed-row access.
The only _accumulate_effort_totals callers are rebuild_effort_aggregates and
validate_effort_aggregates. These LEGACY APIs now correctly refuse a stale A
rather than falsely accepting reconstructedB; they may be used only after normal
purge for a successful live audit. New capture/restore never call them, so stale
structural snapshots remain admissible without hidden cleanup. Test this refusal
and later success. Do not change legacy aggregate implementation otherwise.

New slot validator checks Directory bound, never512. Complete old live methods
and codec tables will be supplied to the author; historical input excerpts were
review context, not a source-edit allowlist. Registry metadata is at
`docs/planning/canonical_state_registry.json`, tests at `godot/test/` (some reviewer
suggested paths were inaccurate). No existing coordinator sketch or Expedition
component store is claimed; future coordinator gate remains explicit.

Parent regression-before-repair:4tests/79assertions,2failures, no script errors.
The failures are the different-slot/equal-generation case and that same state
through structural capture/restore; same-slot/newgeneration and independent live
owners pass. These pin the demonstrated defect, not only a forged codec case.

## Final review clarifications

The direct owner validates active fields in wire order; the pre-existing codec
validates generations, then slots, then quantity. The adapter deliberately runs
that codec gate first, followed by the stronger owner gate. A two-defect test pins
this distinction; no refusal-order unification is part of this repair.

A structurally restored full pair whose live owner occupies a different typed row
is still released by the existing normal stale purge. Capture/restore never calls
that purge. Admitting or refusing that association at whole-world activation is
explicitly owned by PLAN-CLAIM-RECONCILIATION, before any activation implementation.
