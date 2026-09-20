# FieldPolicy component validation — FIELD-POLICY-S4-VALIDATE-R01 v1

Status: accepted by Astra for bounded implementation after independent review and contract-disposition.md closure of B1–B3. ADR0179 records the choice under the authorized settlement outcome. No complete-file restore or first-playable acceptance is implied.

## Layout and scope

Owner3 field_policy version1, primary128, one child extent4096, global field begin60/count20, values44288, payload44460, block44496, offset8458852. Preserve canonical schema and all public gameplay behavior. Add one cold typed Columns image plus static columns_refusal; no new capture/restore, live constructor shortcut, private-state getter or gameplay mutation. ADR0132 favors typed Columns for this large owner.

|Local|Columns property / canonical key|Type|Count|
|---|---|---|---|
|0|field_present / _field_present|u8|128|
|1|zone_slot / _zone_slot|i32|128|
|2|zone_generation / _zone_generation|i32|128|
|3|rotation_ids / _rotation_ids|i32|384|
|4|rotation_cursor / _rotation_cursor|i32|128|
|5|auto_rotation / _auto_rotation|u8|128|
|6|seed_reserve / _seed_reserve|u8|128|
|7|cycle_ordinal / _cycle_ordinal|i32|128|
|8|participants / _participants|i32|128|
|9|resolved / _resolved|i32|128|
|10|withdrawn / _withdrawn|i32|128|
|11|completed_cycles / _completed_cycles|i32|128|
|12|cancelled_cycles / _cancelled_cycles|i32|128|
|13|requested_crop / _requested_crop|i32|128|
|14|cycle_state / _cycle_state|u8|128|
|15|close_reason / _close_reason|u8|128|
|16|request_state / _request_state|u8|128|
|17|plot_field_slot / _plot_field_slot|i32|4096|
|18|plot_cycle / _plot_cycle|i32|4096|
|19|plot_outcome / _plot_outcome|u8|4096|

Columns.new defaults exactly mirror clear: all zero except zone_slot, rotation_ids, requested_crop and plot_field_slot are -1; seed_reserve is1. These are clear defaults, not newly created policy defaults. Add no duplicate public declaration arrays merely for this bridge. Use source capacity/constants and explicit typed sizes.

## Pure local predicate and refusal order

Success REFUSE_NONE. New code constants REFUSE_COLUMN_SHAPE, _FLAGS, _ROTATION, _ZONE_REF, _COUNTERS, _STATE, _REQUEST, _PLOT_LEDGER, _OPEN_COUNTS with exact string values COLUMN_SHAPE, COLUMN_FLAGS, COLUMN_ROTATION, COLUMN_ZONE_REF, COLUMN_COUNTERS, COLUMN_STATE, COLUMN_REQUEST, COLUMN_PLOT_LEDGER, COLUMN_OPEN_COUNTS. No instance construction, mutable diagnostics, callbacks, live Directory/Farming/Forage lookups, calendar computation, input mutation or normalization.

1. Null/all20 extents checked before indexing: COLUMN_SHAPE.
2. Global byte scans in canonical column order: field_present, auto_rotation, seed_reserve in0..1; cycle_state0..2; close_reason0..3; request_state0..5; plot_outcome0..3. Any violation COLUMN_FLAGS.
3. Global rotation_ids each -1..4, all cursors0..2, all requested_crop -1..4: COLUMN_ROTATION. Read fixed crop domain from Farming source constants, pin it in bridge. Do not instantiate catalog or Farming.
4. Ascending field rows, within each row zone, counters, state, request in that order:
   - Present zone ref: slot0..EntityDirectory.DIRECTORY_CAPACITY-1 and generation>0; inactive exact(-1,0). This is structural only; positive generation may be stale. COLUMN_ZONE_REF.
   - ordinal/completed/cancelled nonnegative; completed+cancelled<=ordinal using int64 expression. participants/resolved/withdrawn each0..4096; resolved<=participants; participants+withdrawn<=4096. COLUMN_COUNTERS. Values have packed i32 bounds already.
   - Inactive: cycleIDLE, participants/resolved0. Other counters/settings/close reason may retain history. PresentIDLE: participants/resolved/withdrawn/completed/cancelled0 and closeNONE; ordinal may be positive after recreation. PresentOPEN: ordinal>0, closeNONE; participants0 requires resolved/withdrawn0; participants>0 requires resolved<participants. PresentCLOSED: ordinal>0 and close1..3; COMPLETED requires participants>0,resolved==participants,completed>0; CANCELLED requires cancelled>0 and former OPEN unresolved shape (empty0/0/withdrawn0 or resolved<participants); ABANDONED requires participants/resolved0,withdrawn>0. COLUMN_STATE.
   - Retained close reason is never recomputed. Across all rows: nonNONE close requires positive ordinal; COMPLETED requires completed>0; CANCELLED requires cancelled>0; ABANDONED requires withdrawn>0; withdrawn>0 requires positive ordinal. These follow clear/create/open/close/destroy writers even on inactive rows. COLUMN_STATE.
   - Inactive or cycle not CLOSED must have requestNONE/cropNONE. Any requestNONE implies cropNONE. NonNONE request requires presentCLOSED, closeCOMPLETED, crop equal rotation at cursor. ENTRY_NOT_CONFIGURED4 iff cropNONE; other nonNONE states require crop0..4. COLUMN_REQUEST. Do not require auto_rotation1 for a retained request. Accept defensive NO_LEGAL_WINDOW5 without recomputing current calendar.
5. Ascending plot rows: fieldNO_FIELD(-1) requires cycle0/outcomeUNRESOLVED0. Otherwise field0..127 and cycle>0 and cycle<=linked field ordinal. COLUMN_PLOT_LEDGER. Linked field may be inactive, IDLE, CLOSED, or an OPEN row with an older stamp; retain all valid stale outcomes. No FarmPlot liveness check here.
6. For presentOPEN field rows only, exact current-stamp ledger counts must equal participants/resolved/withdrawn. One4096-row pass with three zeroed PackedInt32Array[128] scratch columns: for a presentOPEN field and matching ordinal, count outcome!=WITHDRAWN as participant, HARVESTED/CLEARED as resolved, WITHDRAWN as withdrawn. Compare all presentOPEN rows ascending; COLUMN_OPEN_COUNTS. CLOSED counts are history and never reconstructed. A no-OPEN early return before scratch allocation is permitted only after all scalar/ledger checks.

No stronger reachability normalization is implied (for example completed+cancelled is a bound, not reconstruction). Duplicate zone identity belongs to saved cross-owner binding, not this local predicate. Synthetic MAX ordinal/history endpoints prove scalar domains, not billions of public cycles.

## Framed bridge and memory

Add save_owner_field_policy.gd. Gate order: null; wrongowner3; Schema.schema_refusal unchanged; metadata/source pins; Section.owner_shape_refusal unchanged; construct one FieldPolicy.Columns and explicitly assign all20 typed canonical local accessors; invoke columns_refusal and wrap exact code with owner-qualified detail. Preloads only FieldPolicy/Schema/Section/SaveHeader. Metadata detail starts `FieldPolicy owner3 metadata:`; column detail contains `FieldPolicy owner 3 ` and raw code. Owner/framing refusal constants follow existing bridges.

Pin key field_policy/version1/primary128/childcount1/childextent0=4096/fieldcount20 and all20 key/type/count declarations. Pin source FIELD_CAPACITY128/PLOT_CAPACITY4096/ROTATION_LENGTH3, NO_FIELD=-1, NO_CROP=-1, NO_CYCLE0/FIRST_CYCLE1/MAX_CYCLE2147483647, all cycle/close/outcome/request enum ordinals and counts, Farming CROP_NONE=-1/CROP_COUNT5 and five crop IDs0..4, EntityDirectory NULL_SLOT=-1/NULL_GENERATION0/DIRECTORY_CAPACITY352418. These refer to preloaded source constants, not live instances. Null generation and global capacity are required by the structural zone pair rule. Do not pin unrelated gameplay defaults or replace existing runtime producers.

Caller44288 + default Columns44288 + three128i32 scratch arrays1536 =90112 conservative logical packed bytes, below stream allowance6417408. No per-row object, duplicate world or new live instance buffers. Projection shares input packed buffers read-only; discard cold Columns/scratch at return. Native allocation/RSS remains unmeasured.

## Source/public-history evidence and scope

Original-source public-history-probe.log reports76 assertions/0 failures, clean process. It exercises abandonment, automatic completion/request retained after auto off, edited empty rotation entry, empty cancellation, destroy/recreate retained ordinal and stale outcome, closed plot ledger overwritten by another field, and stale-zone policy reclaim. Only public readers/writers are used; no complete public capture exists. Static can_open_cycle MAX/MAX-1 is a boundary helper test, not history reaching MAX.

Private inactive bytes and full projection images require exact writer-source reasoning plus synthetic Columns fixtures. Do not introduce a capture API or claim public proof of unobservable bytes. Earlier feasibility report factual corrections are in feasibility-disposition.md. Stale metadata in the large source header is not authority to deny newer implemented subsystems; narrow saved-validation documentation may be corrected without rewriting gameplay.

## Required verification

- Null and each20 zero/short/long extents; all7byte/13i32 bucket cardinalities; shape-before-domain paired faults; all20 independent projection omission witnesses using malformed and legitimate nondefault fields. Accepted/refused inputs remain byte-identical with each packed buffer duplicated for snapshots.
- Every128field/384rotation/4096plot physical address, including tails and inactive rows, gets relevant domain/fault coverage. All flags/enums/crop/cursor edges; structural ref half-null/negative/out-of-cap/maxgeneration; all counters negative/4096bounds/MAX endpoint and overflow-safe sum; present/inactive history defaults.
- State table accepted/refused fixtures for IDLE positiveordinal, emptyOPEN/CANCELLED, partial resolution/withdrawal, COMPLETED/ABANDONED, inactive retained close/settings/counters, request after auto off, all declared request states and crop/cursor relations. No closed-ledger count reconstruction; stale/inactive/IDLE-linked ledgers remain accepted.
- OPEN count fixtures include unresolved/harvested/cleared/withdrawn, multiple fields, older-stamp ignored, inactive/closed ignored, zero-OPEN fast path does not skip bad ledger, and all three exact mismatches. Live public gameplay suites stay unchanged.
- Required mutation families: all20 projection omissions; each7byte scan, 3rotation/cursor/request crop rules, present and inactive zone shape, ordinal/history and participant counter clauses, every nonredundant state/retained-history/request clause, every plot-link/stamp/null clause, each exactOPEN counter and outcome contribution/filter, shape priority and per-row priority. Frozen concrete fixtures and equivalent/subsumed-rule disposition are in frozen-witnesses.json and mutation-witness-plan.md. Parser errors never qualify as kills.
- Metadata fault matrix:9 coherent schema faults covering key/version/primary/childcount/childextent/fieldcount/fieldkey/type/extent;9 independent pin bypasses, baseline, schema forwarding. Exact internally coherent table arithmetic must be recorded before dispatch. Exercise source constant drift where useful without schema drift. No claim of execution until actual logs exist.
- Required final gates:17static checks, capacity source-hash audit, unchanged schema generator parity, import/preload closure, focused/full Godot, metadata faults, required mutants, independent actual-source review, exact-head CI. Existing full-suite shutdown baseline remains separate.

## Remaining saved bindings and gameplay

Same-file saved Directory/Forage zone kind and typed-row identity, unique policy-zone ownership, FarmPlot row lifetime and enrollment joins, loaded-world phase/lifecycle consistency and provenance require later cross-owner bindings. Component validation cannot authorize complete world publication. FieldPolicy bulk capture/apply remains missing. REQ-SET-088 seed reservation and field lifecycle command/orchestrator integration remain separate gameplay tasks; never fabricate GATE_SATISFIED.

### Frozen metadata and mutation plans

metadata-arithmetic-check.json records nine coherent counterfactual schema images plus control. Key field_policz; version2; primary3+1/4-1 preserves descriptor total; childcount owner3=2/owner7=0 with childbegin4..7+1, payload/block3+8/7-8 and offset4..7+8 preserves original first child4096; childextent index2=4097; fieldcount owner3=21/owner4=21, begin4=81, payload/block3+40/4-40 and offset4+40; fieldkey60 changed; fieldtype60u8->i32 delta384; extent60+1 delta1. Type/extent update owner3 payload/block, all later offsets and both section-byte constants. Fields298/children5/primaries193184 stay unchanged. Fieldkey/type/extent are representative ordinal60 metadata faults; all20 actual projection mappings are separately tested. Childcount removal would redundantly fail childextent, so use the increase-to2 case to independently expose the count gate. Nine original metadata expectations must fail when their individual pins are bypassed; type/extent may then refuse COLUMN_SHAPE later, which is an exact-refusal-identity witness, not acceptance. Twenty engine cases/180assertions including nine faults/nine bypasses/control/schema-forward are required.

frozen-witnesses.json supplies138 explicit planned cases with clear/present/OPEN/CLOSED/inactive/request bases and physical-tail modifications. fixture-arithmetic-check.json is a Python consistency check only, not engine acceptance. mutation-witness-plan.md identifies logically redundant clauses so no equivalent single-clause omission is falsely called a killed mutant. Parent implements and executes tests; no worker may substitute model results for actual Godot or fault runs.
