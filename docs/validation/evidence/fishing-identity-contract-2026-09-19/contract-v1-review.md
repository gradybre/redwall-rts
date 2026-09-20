# FISH-ID-R01 v1 — independent engineering contract review

2026-09-19 · reviewing **version 1** of `docs/planning/fishing_claim_identity_contract.md`
and decision 0167. Planning only; no source was edited and nothing was executed here.

## A. Confirmed without qualification

- The alias is a **real live ownership defect**, not a save-path artefact. The public witness
  and its log show A=(2,1) destroyed, HarvestZone (2,2) taking slot 2, B=(3,1) reusing typed
  row 0, `reconstructed_claim_owner=(3, 1)`, `purged_count=0`, `unrelated_expedition_can_release=true`.
  The cause is visible in `effort_claim_expedition_ref_of()`, which rebuilds the slot from
  `owner_slot_of_typed_row()`. No bound check can recover a slot that was never stored.
- Storing the full pair is the minimal repair. `purge_stale_effort_claims()` and
  `_refuse_stored_effort_claim()` already compare `is_valid_of_kind(...KIND_EXPEDITION)` and
  `get_typed_row(ref) == row`; with a stored A=(2,1) the first test fails (slot 2 is a zone),
  so the purge releases once through the existing path with no new sweep logic.
- Appending at ordinal 7 keeps every i32 storage index stable (new column lands at i32 index 6),
  so `storage_index_of()` callers and ordinals 0..6 need no renumbering.

## B. Blockers

**B1 — the immutable-exclusion basis is not self-consistent.** §2.3 derives
`candidate = payload − 3670016 − 2097152 − 262144 − 131072 − 55200` and 6215584 is exactly that
sum; the 18825-byte declaration table is *not* one of those terms, so it is presently charged
to candidate mutable state in full. Moving 6215584→6215807 excludes 223 bytes of that row while
leaving 18825 bytes of the same row charged. The printed derivation would then no longer
reproduce its own number, and `ready07_arithmetic.py`'s literal `payload-6215584` would have to
become an unexplained 6215807. Two self-consistent options, both requiring the derivation text
and the script literal to change together:
  - (a) *recommended* — exclude the whole row, printing it as a sixth subtracted term:
    exclusion 6234632, candidate `70005291 − 6234632 = 63770659`, peak `78393899 + 63770659 =
    142164558`, transactional headroom −42164558.
  - (b) exclude nothing new: exclusion stays 6215584, candidate 63789707, peak 142183606.
  The contract's 63789484 / 142183383 is neither. Pick one and print the enumerated terms.

**B2 — `docs/validation/ready07_arithmetic.py` will fail at four independent asserts and the
contract names none of them.** `assert len(fields)==144 and sum(fields)==25036642` (→ 25038690),
`assert payload==70003020`, `assert live==78391628 and candidate==63787436 and
live+candidate==142179064`, and `DECISION_0127_ADDED=(52*4*4)+(604*3*1)+(604*8)+(604*4)+8933`
with `assert DECISION_0127_ADDED==18825`. The contract's "replace the hardcoded 604/8933
arithmetic with actual registry-derived census" must land in *this* file, and the 223 must enter
as a single revision of that term (→ 19048), never as a second row, or the 179 is double-counted.
No new allocation row: the 2048 arrives through the existing "Fixed registry payload" row, so
`len(allocations)==33` is unchanged.

**B3 — `godot/tools/memory_ledger_rows.gd` is already stale and the contract does not say who
owns it.** It transcribes 24 rows against a 33-row table, `Fixed registry payload` 25028962
(table: 25036642), `Auxiliary payload` 17234780 (table: 25293280), and `declared_total()`
promises 60823126. It cannot be "updated together" with this change without first being
reconciled to the current table. Decide explicitly: reconcile it in this patch, or record the
pre-existing drift as out of scope with a dated note. Do not silently leave a transcription test
that disagrees with the row it transcribes.

**B4 — two codec tables the contract never mentions must change or the new column is unchecked.**
`BLANK_ORDINALS_FISHING: Array[int] = [1, 2, 3, 4, 5, 6]` must become `[1, ..., 7]`, otherwise a
released row may carry a residual expedition slot and two observably identical worlds encode
differently. `_fishing_row_refusal()` iterates slots over `[2, 4]`; that must become `[2, 4, 7]`
so the new field gets `_slot_refusal(..., DIRECTORY_CAPACITY, ...)`. Generations `[1, 3, 5]` are
unchanged. `canonical_fill_of(OWNER_FISHING, 7)` must return −1 for both the blank constructor and
`_blank_row_refusal()`'s expectation (see E4).

**B5 — the owner shape gates must reach eight arrays before anything indexes.**
`_effort_claim_record_shape_ok()` and `_effort_claim_live_shape_ok()` each test seven sizes, and
`_effort_claim_payload_code()` takes seven typed arrays. If the eighth array is added to
`EffortClaimColumns` but not to both predicates and the validator signature, a caller record
holding a short or default-empty eighth column reaches an indexed read and *crashes* instead of
refusing — which silently converts the contract's refusal-atomicity guarantee into an abort.
The eighth duplicate must also be taken in the private-duplicate phase of
`restore_effort_claim_columns()`, before the first publication assignment, and published in the
same all-or-nothing block. Adapter: `FISHING_I32_COLUMNS: int = 6` → 7, plus the named
`FISH_ORDINAL_EXPEDITION_SLOT: int = 7` mapping in both `capture_fishing_into()` and
`apply_fishing()`.

**B6 — dropping reconstruction changes `_accumulate_effort_totals()` behaviour and the contract
does not say so.** Today a stale claim on a reused row reconstructs to the *live* B, passes
`is_valid_of_kind` and `get_typed_row(ref) == row`, and is silently totalled. With the stored
pair it returns `REFUSE_EXPEDITION_NOT_PRESENT` and the whole aggregate refuses until a purge
runs. That is more correct, but it is a public behaviour change on every caller of that
aggregate, and it interacts directly with the required test "destroyed-owner capture/restore
preserves the full stale pair, followed by normal purge matching uninterrupted state": if any
capture or reconciliation path calls the aggregate before the purge, that test cannot pass
without the hidden purge the contract forbids. Enumerate every caller of
`_accumulate_effort_totals()` and state the intended order (purge, then aggregate) in the
contract before implementation. Source needed: E1.

**B7 — the owner schema version should be read, not restated.** `OWNER_SCHEMA_VERSIONS` takes
`inventory` from `InventoryScript.CANONICAL_OWNER_SCHEMA_VERSION` precisely because "two modules
naming the version independently is two numbers that can disagree". Writing a bare `2` for
`fishing` reintroduces exactly that. Declare `FishingScript.CANONICAL_OWNER_SCHEMA_VERSION = 2`
beside the columns and read it in the codec. The codec already preloads an owner
(`InventoryScript`), so this adds no new edge class; the owner still preloads no save module, so
`save_resource_claims_restore.gd`'s no-cycle rule is untouched.

**B8 — the old-schema refusal fixture cannot be produced by the encoder.** The contract forbids a
silent old-layout fallback, so nothing in the tree can emit an owner-schema-1 fishing block after
the change. The refusal test must hand-frame a literal byte buffer (store_count, `"fishing"` key,
schema word `1`, primary count, payload length, 7 columns) and assert
`REFUSE_OWNER_SCHEMA_VERSION` with the caller's `Record` byte-identical. Write that into the
contract; otherwise the test is likely to be written as an unreachable round-trip and pass vacuously.

## C. Schema-aware decoder: concrete signature and gate precedence

The supplied `decode_into(bytes, offset, byte_length, out)` carries no descriptor version, and the
section schema number is **not in the section 7 body** — `save_header.gd` carries it and does not
interpret it. So the section-schema gate is an *argument* check, not a read. Proposed API:

```
static func decode_into_versioned(bytes: PackedByteArray, offset: int, byte_length: int,
        section_schema_version: int, out: Record) -> SaveHeader.Refusal
static func decode_into(bytes: PackedByteArray, offset: int, byte_length: int,
        out: Record) -> SaveHeader.Refusal   # delegates with SECTION_SCHEMA_VERSION
```

The existing entry point keeps its signature and every current caller, and the future coordinator
calls the versioned form with the descriptor's number. Do not add a defaulted parameter: a
default silently accepts a caller that forgot to pass the descriptor value.

Precedence inside `decode_into_versioned`, first gate wins:
1. `extent_refusal()` — offset/length/truncation (unchanged, first).
2. `byte_order_refusal()` (unchanged).
3. **new**: `section_schema_version != SECTION_SCHEMA_VERSION` → a dedicated
   `REFUSE_SECTION_SCHEMA_VERSION`, *before* `Reader.new()` and before any seek. A section-3 file
   therefore never reaches a column body, satisfying "reject before reading new-layout bodies".
4. `reader.seek(offset)`; 5. `store_count`; 6. per-owner key and ASCII order;
7. owner schema equality in `_read_wrapper()` — already the first wrapper field read, ahead of
   `primary_count`, `_read_extents()` and `_read_columns()`, so **owner schema 1 is refused before
   any new-layout body is consumed with no new gate needed**; 8. primary-count bound;
9. declared/consumed payload length, both comparisons; 10. `record_refusal()` on the local;
11. `out.copy_from(parsed)`.

Atomicity is preserved because gate 3 precedes allocation and gates 1–10 all run against the
local `parsed`. When both the section and owner schemas are stale, gate 3 wins deterministically;
pin that ordering in a test so the code is not later reordered into an owner-level message.

## D. Arithmetic checked

Reproduced and **agreed**: 512×4 = 2048 resident; 25→29 bytes/row, 29×512 = 14848; 14848 + 8×8
count words + 4 child-count = 14916; wrapper 11+4+8+8 = 31 → 14947 block; wire delta 2048+8 = 2056;
current ledger 52×16 + 604×15 + 8933 = 18825; true census 52×16 + 610×15 + 9022 = 19004, so the
prior omission is 179; `_effort_claim_expedition_slot` is 29 bytes of key + 15 metadata = 44;
19004 + 44 = 19048 = 832 + 611×15 + 9051; field sum 25036642 + 2048 = 25038690; allocation total
70003020 + 2048 + 179 + 44 = 70005291; live 70005291 + 8388608 = 78393899; headroom 21606101.
**Disputed**: candidate mutable 63789484 and peak 142183383 — see B1.
**Unverified for lack of source**: 602→603, 553→554, 610→611, 9022 key bytes (see E3);
352417/352418 as `DIRECTORY_CAPACITY − 1` (see E2).

## E. Missing sources — required before this contract is accepted as complete

These are gaps in the supplied bundle, not defects asserted against the code.
1. Full `godot/scripts/core/fishing.gd`: `is_effort_claim_active()` (does it bounds-check, which
   the contract's "NULL_REF only for inactive/out-of-range" depends on), `NULL_REF`,
   `_release_effort_claim_row()`, and **all callers of `_accumulate_effort_totals()`** (B6).
2. `godot/scripts/core/entity_directory.gd`: `DIRECTORY_CAPACITY`, `NULL_SLOT`, `NULL_GENERATION`,
   `KIND_CAPACITY`, `owner_slot_of_typed_row()`.
3. `godot/data/canonical_state_registry.json` and `godot/scripts/core/canonical_state_hash.gd`:
   the 602/553/610 census, the two `PackedStringArray` key totals, and whether the new ordinal is
   inside the hashed projection (`packed_source_field_count` 553→554 implies yes; confirm).
4. Remainder of `save_section_inventories.gd`: `canonical_fill_of()`, `field_count_of()`,
   `storage_index_of()`, `backing_extent_of()`, `owner_refusal()`, `record_refusal()`,
   `payload_bytes_of()`, `PRIMARY_COUNT_MAXIMA`, `DIRECTORY_CAPACITY`, and the refusal-code list.
5. `godot/scripts/core/save_header.gd`: the 64-byte descriptor's schema field and `Refusal`.
6. `godot/tests/test_save_section_inventories.gd` and the section 7 canonical fixtures/goldens:
   the literal wire offsets the new ordinal shifts.
7. `docs/systems_architecture.md` §2.2 `FishingEffortClaim` rows (the 6-column I32 row must become
   7 and 12288→14336; the 12800 slice note becomes 14848).
8. `scripts/state_registry_coverage.py` and `merge_gate.py`: which gate fails if a new core column
   is unledgered.
9. Any test pinning `effort_claim_payload_bytes() == 12800` (the docstring and value both move).
10. The PR157 parent tests for capture/restore/destroy-before-purge.
11. `forage.gd` claim block (unchanged, but its shape constants sit beside the edited ones).
12. The SAVE-CLAIM-RECONCILIATION coordinator sketch, to confirm it is the descriptor-version
    supplier named in §C.

## F. Test gaps beyond the contract's list

- Pin gate precedence: section schema 3 **and** owner schema 1 in one buffer returns the section code.
- Pin that a released row with a non-blank ordinal 7 is refused by `_blank_row_refusal()` (B4) and
  that the blank constructor fills −1, as two separate assertions on two different tables.
- Pin the eight-array shape refusal with a *seven*-array caller record (B5), asserting a refusal
  code rather than relying on absence of a crash.
- Pin `_refuse_effort_owner` returning CLAIM_PRESENT for exact (slot, generation) and CLAIM_STALE
  for equal generation with a different slot — the witness's exact case.
- Add a ledger test that recomputes the declaration census from the registry and fails on any
  unledgered field, per the contract; without it B2's literals rot again.

## G. Non-blocking

- `effort_claim_row_into()` should reuse `REFUSE_EFFORT_CLAIM_STALE` for a slot mismatch; a new
  code would change public refusal strings for no semantic gain.
- The owner's `expedition_slot` gate should mirror the habitat/job form
  (`< 0 or > CLAIM_COLUMN_DIRECTORY_SLOT_MAX`), not a 512 bound: the stored value is a Directory
  slot, as the codec's `_fishing_refusal()` docstring already states for ordinals 2 and 4.
- Contract wording "claim payload 25R→29R" is per-row bytes, not rows; worth disambiguating.
- Agreed with the contract: do not rewrite historical snapshots, and do not migrate ambiguous
  old development saves.
