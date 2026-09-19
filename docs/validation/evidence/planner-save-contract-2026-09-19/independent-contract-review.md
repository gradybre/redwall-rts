# Independent review — SAVE-J2-R01 planner dirty-state format repair

2026-09-19 · reviewer: independent contract review · subject: `docs/planning/planner_dirty_state_contract.md`
version 1 and `docs/decisions/0157-persist-planner-dirty-order-and-membership.md`.
Scope: the proposed bounded format repair only. Inputs were the two documents, the
source-excerpt bundle, `registry-owner-before.json`, the probe script and its log.
I did not run, build or test anything; every number below is re-derived arithmetically
from those inputs.

## Verdict

The semantic inference is sound and the proposed 35-field shape is internally
consistent. I find **two small concrete blockers**, both documentary/declarative
rather than structural, and several required precisions that are not blockers but
must be fixed in the same change or the pinned byte total will not hold.

## Semantic inference — confirmed

The excerpts support the claim directly. `_pop_dirty`, `_pop_dirty_zone` and
`_pop_dirty_hive` each decrement then read `rows[count]`: LIFO, so mark order is
read order. `reconcile_dirty_into()` drains that stack before `run_idle_sweep_into()`,
and the sweep visits `tick % STAGGER_MODULUS` strided slices, so membership decides
*whether* an owner reconciles now or at its stagger slot. Reconciliation creates
Jobs, so both order and membership can move identity allocation. The probe's
`created` values (2, 2, 1) show membership changing the number of jobs produced on
the tick, not merely their ids; ids [4,3] / [3,4] / [3,0] show order changing
allocation. The registry's current justification — "a load that marks every owner
dirty produces the same evaluations in the same order" — is therefore false as
written, and sorting the same membership cannot reproduce a LIFO read order either.
The proposal is right to refuse both substitutes and to refuse disguising the gap
by changing normal scheduling.

## Arithmetic — confirmed

* 29 declared columns: 8x4x8192 + 3x8192 + 2x4x4096 + 128 + 2x4x128 + 2x640 +
  2x4x640 + 8x640 + 5x4x1024 + 8x1024 + 2x1024 = **362880 B**, equal to the probe's
  `canonical_bytes`.
* New six: 16384 + 4 + 512 + 4 + 4096 + 4 = **21004 B**; 362880 + 21004 = **383884 B**.
* 383884 + 35x8 = **384164 B**; + 39 B wrapper = **384203 B**. Consistent.
* Extents match the allocator: `_dirty_rows` OWNER_CAPACITY 4096, `_dirty_zone_rows`
  ZONE_OWNER_CAPACITY 128, `_dirty_hive_rows` HIVE_OWNER_CAPACITY 1024. Row index
  domains 0..extent-1 are exactly the owner-class slot domains the mark paths gate on.
* Record scratch growth +21004 per Record, +42008 for two live Records. Correctly
  declined as a peak-budget proof.

## Blocking findings (smallest form)

**B1. Two version numbers, one unstated dispatch rule.** The proposal advances the
`job_planner` owner schema 1->2 *and* section 8 schema 1->2 (the before-artifact's
`section_schema_versions[7] == 1` confirms the section baseline), but never says
which value the known-section dispatch reads, nor what happens to a mismatched pair
(owner 2 with section 1, or the reverse). State that the wrapper preamble is decoded
first, that both versions are checked jointly before the column body is interpreted,
and that any unsupported or inconsistent pair yields an unsupported-schema refusal
distinct from the shape/truncation refusal code. The lengths differ (old section is
362880 + 29x8 + 39 = 363151 B, new 384203 B) so no valid old section can be mistaken
for a truncated new one, but only if the schema is compared before the length.

**B2. Registry totals and missing registry rows.** `registry-owner-before.json`
publishes `record_count` 596 and `packed_source_field_count` 550, so 602 canonical
and 553 persisted packed follow from +6 and +3. The third figure, "610 listed", has
no baseline anywhere in the supplied evidence and cannot be checked; either source it
or drop it and let the generated artifact assert it. Separately, the registry excerpt
contains rows for the three row arrays and the three bit arrays only — `_dirty_count`,
`_dirty_zone_count` and `_dirty_hive_count` appear in no ledger row at all. This change
must *add* three rows, not merely reclassify existing ones, and must rewrite the shared
note on all six dirty rows, whose stated argument is now disproved.

## Required precisions (not blockers)

1. **Extent-1 encoding is load-bearing.** 384203 B holds only if each count is encoded
   as a one-element i32 column carrying its own 8-byte element-count word. Encoded as a
   bare scalar the payload would be 383884 + 32x8 and the section 384179 B. Say
   "extent-1 column" explicitly, and confirm `descriptor_row_count()` still returns the
   8192 pending-service primary count and is not influenced by the extent-1 fields.
2. **Generic Record grouping.** Ordinals 29–34 are all i32, so they append to the i32
   storage group after its current maximum index 18 (19 i32, 8 u8, 2 i64 across the 29
   fields), giving `FIELD_STORAGE` entries 19..24 in ordinal order. `_shape_refusal`
   then covers the counts for free, since `column_size(field) == 1` is the declared extent.
3. **Domain tables.** All six new ordinals belong in `NON_NEGATIVE_FIELDS`. None belongs
   in `SLOT_FIELDS`: these are owner-class row indices, not directory slots, and -1 is
   never legal for them. Count-vs-extent and prefix-vs-membership are cross-field rules,
   so add a fourth validation stage after the existing three and leave all 29 rules intact.
4. **Row 0 and the empty queue.** Zero is both the canonical unused fill and a legal
   queued index, so the count must be the sole authority for prefix length; a queue holding
   only row 0 differs from an empty queue only in the count word. The proposed tests already
   name this case; keep it explicit in the validator's comment so a later reader does not
   "tighten" the tail rule into rejecting a queued row 0.
5. **Pop-zeroing is the one live-code mutation.** Today `_pop_dirty` does not zero the
   popped cell. Zeroing it is safe: `mark_*_dirty` writes `rows[count]` unconditionally and
   nothing ever reads at or above `count`, so no live order, budget, counter or lookup can
   observe the change. It is still a change to a simulation module and needs the
   no-new-jobs / no-counter-movement assertion the acceptance list already requires.
   Idempotent-mark position retention and remark-after-pop already hold in the excerpts.
6. **Uniqueness scratch.** 4096 B suffices because it equals the largest queue extent,
   but derive it from the maximum of the three declared extents rather than a literal, and
   keep it function-local: a module-level static buffer in a `static func` validator would
   be shared mutable state across callers and would be exactly the unclassified permanent
   column the proposal forbids. Note that a per-call local allocation is acceptable only
   because validation is a load/save-time path, not a per-tick one; say so, since
   ARCH-MEM-001 otherwise reads against it. A seen-bit buffer plus explicit clear is
   preferable to a dictionary, as proposed.
7. **Counter classification.** Correcting the codec comment is right: the registry already
   places the counters in category 3. The registry's "Twenty-eight `_*_count` diagnostics"
   wording is imprecise against the source list (two of the 28 members are `_*_milli`, not
   `_count`); worth fixing while that row is being edited, not worth blocking on.

## Proof boundaries — correctly drawn

The probe concatenates the 29 `FIELD_KEYS` columns via `get()`. That is a *projection*
of the declared canonical fields, not the section codec's byte image: it omits the
element-count words, the 39-byte wrapper and the codec's type-group ordering. It is
valid for its one claim — the 29 declared columns are byte-identical across the three
cases — and the documents label it source/runtime evidence rather than a round-trip or
world-hash proof. Acceptance item 4 correctly demands that the *new* separation be shown
from production compiled fields rather than a hand-built buffer; item 5 should add that
the new projection fixture uses the same projection method as the retained probe, so the
before/after comparison is like-for-like. The proposal also correctly keeps
`revalidate_after_load()` out of canonical restore, keeps `mark_all_*_dirty()` out of the
future adapter, and does not claim to close J2, supply `capture_into`/`apply`, or prove
the full-world load peak.

No other blocking findings.
