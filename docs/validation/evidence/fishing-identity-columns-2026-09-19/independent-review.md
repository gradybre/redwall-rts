# Independent source review — FISH-ID-R01 v2 / ADR 0167

2026-09-19. Reviewer read the integrated `fishing.gd`, `save_section_inventories.gd`,
`save_resource_claims_restore.gd`, the four supplied test files, the contract, the ADR and
`docs/persistence_state_registry.md`. No test was run by this reviewer; the parent's focused
256/7923/0 is taken as reported, not re-derived.

## Verdict

The behavioural repair is correct as integrated. Three defects below are documentation/ledger
facts that ship inside this change's declared scope and contradict artifacts in the same change.

## Confirmed against the contract

* Old alias reproduced and closed. `_refuse_effort_owner` (fishing.gd) reports CLAIM_PRESENT only
  on exact slot AND generation, CLAIM_STALE otherwise; `effort_claim_row_into` compares both
  fields after Directory validation and row lookup; `effort_claim_expedition_ref_of` returns the
  stored pair and NULL_REF only for inactive/out-of-range. `purge_stale_effort_claims` and
  `_refuse_stored_effort_claim` read that stored pair, so A=(2,1) is detected dead in both the
  different-slot/equal-generation and same-slot/new-generation cases.
* Slot/gen/capture/restore/atomicity. `_allocate_effort_claim_columns`, `_clear_effort_claim_columns`,
  `_clear_effort_claim_row`, `_write_effort_claim`, `copy_effort_claim_columns_into` and
  `restore_effort_claim_columns` all carry the eighth array; both shape predicates check eight
  arrays before any indexing; restore duplicates all eight privately before publication.
* Blank/shapes. Constructor fills `effort_claim_expedition_slot` with `CLAIM_COLUMN_BLANK_SLOT`
  (-1); `_effort_claim_payload_code` includes it in the inactive-blank condition and validates its
  active range `0..CLAIM_COLUMN_DIRECTORY_SLOT_MAX` (352417), never 512, with no live lookup.
  Parent's move of that check to after ordinal 6 matches the contract's appended-position rule and
  is pinned by `test_appended_owner_slot_validates_after_existing_quantity_field`.
* Ordinal 7. `KEYS_FISHING`/`TYPES_FISHING`/`EXTENTS_FISHING`/`COUNT_FIELDS_FISHING` append at 7
  and renumber nothing; `NEGATIVE_ONE_FILL_KEYS` and `BLANK_ORDINALS_FISHING` include it; active
  slot checks are `[2,4,7]`; `canonical_fill_of` yields -1.
* Byte arithmetic. `effort_claim_payload_bytes()` = 512 + 7x2048 = 14848. Fishing payload
  4 + 520 + 7x2056 = 14916, block 31 + 14916 = 14947, delta 2056 (2048 + one 8-byte count word).
  Section total 4 + 14947 + 434298 + 688256 + 7481637 + 1212520 + 608353 = 10440015, matching the
  pinned vector and `INVENTORY_BLOCK_OFFSET` 449713. Forage block 434298 unchanged.
* Versions/new decoder. Fishing owner 2 read from `CANONICAL_OWNER_SCHEMA_VERSION`; section 4;
  `decode_into` delegates with the current version; `decode_into_versioned` gate order is
  extent -> byte order -> section schema -> null out -> existing reader flow, ending in one
  `out.copy_from`. Stale section beats stale owner; invalid extent beats schema; both new codes
  carry nonempty details. The hand-framed owner-1 fixture is internally consistent (12895 bytes,
  declared payload 12860) and refuses at the wrapper before any missing later owner matters.
* Adapter. `FISHING_I32_COLUMNS` 7, `FISH_ORDINAL_EXPEDITION_SLOT` 7, mapped both ways through
  `Codec.storage_index_of`; Forage constants and ordinals untouched.
* Mutants. Remove slot equality -> `test_different_directory_slot_equal_generation_cannot_inherit_claim`
  and the PRESENT/STALE assertion fail. Reconstruct from Directory -> stored-ref assertion fails.
  Omit publication/restore -> `test_defaults_sparse_last_row_and_independent_arrays_are_exact`
  and the stored-ref assertion fail. Omit canonical declaration ->
  `test_full_expedition_slot_is_eighth_hashed_fishing_field` plus the 603/611/6 pins fail.

## Blockers

1. `godot/scripts/core/save_section_inventories.gd`, module docstring, section
   "## Size: chunked, because ARCH-SAVE-003 says large sections are": "At the compiled maxima with
   every slot free this section is 10437959 bytes". That is the pre-repair figure (fishing block
   12891). The same commit pins 10440015 in
   `test_save_section_inventories.gd::test_default_capacity_section_has_the_declared_byte_vector`.
   A shipped header that contradicts a passing pin in its own suite is exactly the stale-comment
   class the parent set out to clear. Replace with 10440015.

2. `docs/persistence_state_registry.md`, row "### godot/scripts/core/save_section_inventories.gd",
   four stale facts in one cell: (a) `4 + 12891 + 434298 + ... = 10437959 bytes` -> must read
   14947 and 10440015; (b) "`owner_schema_version:u32` (**3 for inventory** ..., 1 for the other
   five)" -> fishing is now 2; (c) "The descriptor schema is 3 and the `inventory` owner schema is
   3" -> descriptor schema is 4; (d) "`fishing` and `forage` still lack owner capture" -> fishing
   publishes `copy_effort_claim_columns_into`/`restore_effort_claim_columns` and has a block
   adapter. (d) predates this repair but is now unambiguously false in the same file that already
   carries a `save_resource_claims_restore.gd` row.

3. `docs/persistence_state_registry.md`, row "### godot/scripts/core/canonical_state_hash.gd":
   the declaration table is still described as "52 owners / 607 fields", "607 x 3 x u8 = 1821",
   "607 x i64 ... = 4856", "607 x i32 ... = 2428", "8987 bytes of key text (485 owner-key +
   8502 field-key)", "**18924 bytes resident**", and "grew from 50 owners / 590 fields / 18384
   bytes". The contract requires the corrected census at 611 listed fields and a 19048-byte
   declaration (52x16 + 611x15 + 9051 key bytes, after the explicit 179-byte prior omission and
   the 29+15 = 44-byte append). Leaving 18924 here ships a THIRD declaration-table figure beside
   the ledger's 18825 and the corrected 19048, which is the drift the reconciliation exists to
   end. `state_registry_coverage.py` checks columns and widths, not these prose totals, so nothing
   fails the build on this.

## Bounded missing tests and notes (not blockers)

4. Owner-vs-codec precedence asymmetry. `fishing._effort_claim_payload_code` validates ordinal 6
   then 7; `save_section_inventories._fishing_row_refusal` validates generations [1,3,5], slots
   [2,4,7], then ordinal 6. Grouping is sanctioned by "active slot checks[2,4,7]", but
   `apply_fishing` runs `Codec.owner_refusal` BEFORE the owner call, so the precedence pinned by
   `test_appended_owner_slot_validates_after_existing_quantity_field` is not observable through the
   adapter: a block bad in both fields reports SAVE_INV_SLOT_RANGE there and
   COLUMN_FISH_CLAIM_SLOT_COUNT on the direct owner path. Add one adapter-level assertion or a
   comment stating the two orders are deliberately different.

5. Slot 0 acceptance untested for the new column. The contract says "slot0/MAX accepted
   structurally". MAX 352417 is covered on both paths
   (`test_maximum_ref_and_quantity_fields_are_preserved_without_typed_row_clamp`,
   `test_eighth_fishing_column_has_independent_blank_and_slot_gates`); 0 is covered on neither —
   the owner seed uses `200000+row` and the codec fixture uses 352417. Both validators do accept 0
   by inspection; one assertion would pin it.

6. `test_structural_restore_keeps_stale_full_pair_before_normal_cleanup` proves the stale pair
   survives capture/restore and then re-runs the behavioural checks, but does not compare the
   restored world byte-for-byte against an uninterrupted one after the purge. The existing
   two-world comparison (`test_real_stale_claims_survive_slice_restore_until_normal_purge`)
   destroys the owner without a row-reusing replacement, so the aliasing case has no
   count/aggregate/reuse equality witness.

7. `godot/test/test_resource_claim_columns.gd::test_six_complete_literal_owner_wire_goldens` cites
   `docs/validation/evidence/fishing-identity-contract-2026-09-19/literal_wire_goldens.py` and
   `.json`. This lane's evidence directory is `fishing-identity-columns-2026-09-19`. Confirm the
   cited generator and digest artifact exist at the cited path; if they were produced in the
   contract lane, say so in the comment so the three new fishing goldens remain traceable.

8. `purge_stale_effort_claims` and `_refuse_stored_effort_claim` retain the extra
   `get_typed_row(expedition_ref) == row` guard. With the full pair stored, a restored claim whose
   live owner maps to a different typed row is released by the ordinary purge rather than refused.
   That is consistent with deferring row association to the reconciliation contract, but nothing
   pins the intended behaviour in either direction; record it in the contract-deferred list.
