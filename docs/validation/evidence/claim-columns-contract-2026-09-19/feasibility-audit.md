# Claim-columns owner boundary — feasibility audit (read-only)

Scope: audit only. Nothing here is implemented, run, or tested. Conclusions rest on the four
packet inputs; every dependency outside them is named in §11 rather than assumed silently.

## 1. What the scoped API may and may not touch

The two stores audited each own exactly one section-7 claim table, and each module also owns
fields belonging to sections 1, 4 and 5. A claim-only boundary therefore restores:

* Fishing: 7 arrays — `_effort_claim_active` (u8) plus `_effort_claim_expedition_generation`,
  `_effort_claim_habitat_slot`, `_effort_claim_habitat_generation`, `_effort_claim_job_slot`,
  `_effort_claim_job_generation`, `_effort_claim_slot_count` (i32).
* Forage: 11 arrays — `_claim_active` (u8); `_claim_job_slot`, `_claim_job_generation`,
  `_claim_designation_slot`, `_claim_designation_generation`, `_claim_basin_slot`,
  `_claim_basin_generation`, `_claim_patch_kind` (i32); `_claim_remaining_milli`,
  `_claim_created_tick`, `_claim_persistent_id` (i64).

plus the derived live count (`_effort_claim_count`, `_claim_count`). Everything else in both
modules — habitat/stock rows, zone rows, the link arena, patches, `_habitat_effort_used`,
`_zone_quota_reserved_milli`, `_live_*` lists, `_math*`, `_pending_*`, `_owns_directory`, and
the borrowed `_directory` / `_jobs` / `_zones` bindings — must be byte-identical across a
capture/restore round trip. This is feasible: the 18 columns are disjoint from every other
field, and both modules already have blanket clearers (`_clear_effort_claim_columns`,
`_clear_claim_columns`) that touch only the claim slice plus `_effort_total_scratch`.

## 2. Fixed capacity, and why nothing is variable

`FISHING_EFFORT_CLAIM_CAPACITY = 512` and `FORAGE_CLAIM_CAPACITY = 8192` are compile-time
constants, and `save_section_inventories.gd` marks both owners `PRIMARY_COUNT_IS_FIXED = true`,
refusing any other primary count. Neither owner declares a child extent. So the contract is a
fixed-shape one: capture and restore always move exactly 512 and 8192 rows, no count-governed
prefixes, no compaction, no reindexing.

## 3. Blank form and domains versus the codec

Per-row blank values agree exactly between the stores' clearers and the codec's
`canonical_fill_of()` / `BLANK_ORDINALS_*`:

* Fishing free row: active 0; both slot columns `NULL_SLOT`; three generation columns
  `NULL_GENERATION`; slot_count 0. Codec ordinals 1..6 checked; `NEGATIVE_ONE_FILL_KEYS`
  covers `_effort_claim_habitat_slot`, `_effort_claim_job_slot`.
* Forage free row: active 0; three slot columns `NULL_SLOT`; three generations
  `NULL_GENERATION`; `_claim_patch_kind` −1; `remaining/created_tick/persistent_id` 0. Codec
  ordinals 1..10 checked, with `_claim_patch_kind` in `NEGATIVE_ONE_FILL_KEYS`.

That last equivalence holds **only if `EntityDirectory.NULL_SLOT == -1` and
`NULL_GENERATION == 0`**; the codec reaches those through `InventoryScript`, the stores through
`EntityDirectory`. Neither constant is in the packet (§11).

Live-row domains diverge from the runtime APIs in three places:

| Column | Codec admits | Real public/legacy path |
|---|---|---|
| `_claim_remaining_milli` | `>= 0`, up to I64 max | `restore_claim`: `1..1180000` |
| `_claim_created_tick`, `_claim_persistent_id` | `>= 0` | written from Jobs/Directory |
| `_effort_claim_slot_count` | `>= 1`, up to i32 max | `<= _habitat_effort_slots[slot]` |

The codec is broader than the world. The new owner restore must apply the narrower structural
rule (§7), because a codec-legal-but-world-illegal payload is precisely the forged input the
arithmetic hazards in §8 need.

## 4. Typed-row identity and directory refs

Fishing claim rows are indexed by the owning **Expedition's typed row**; Forage claim rows by
the owning **Job's typed row**. The row index *is* identity, so restore is positional: whole
columns land at the same offsets, and no row may be moved, sorted or compacted. Fishing stores
no expedition slot column at all — `effort_claim_expedition_ref_of()` rebuilds the slot from
`owner_slot_of_typed_row()` and pairs it with the saved generation. That is a reconstruction
from the live directory, not an omitted packed field, and a claim-only restore neither needs
nor may supply it.

The stored `habitat_slot`, `job_slot`, `designation_slot`, `basin_slot` columns are
**directory** slots (written from `*_ref.x`), not typed rows of their own stores; the codec
already bounds them by `DIRECTORY_CAPACITY`. Reservations' `_r_job_slot` is the counterexample
(a job typed row) and must not be used as precedent here.

## 5. Stale refs

`effort_claim_row_into()` and `claim_row_of_into()` both refuse a generation mismatch
(`EFFORT_CLAIM_STALE`, `CLAIM_STALE_JOB`), and `purge_stale_effort_claims()` releases claims
whose expedition is gone. A structural restore must do **none** of that: it preserves stale
generations verbatim. Liveness, world association and row-mapping agreement are the
coordinator's obligations after all sections are present; refusing them at the owner boundary
would refuse a save that is internally consistent and only looks stale because sections 4/7
have not both been applied yet.

## 6. Order keys are canonical, not caches — and the aggregate methods are poison

The registry lists `_claim_created_tick` and `_claim_persistent_id` as category-1 ForageClaim
i64 columns in §7. `_write_claim`'s docstring calls them "a cache of the Job's own fields" and
asserts "both are rebuilt on load". **The registry governs**: they are canonical, preserve-exact,
and the discrepancy is recorded here rather than resolved by recomputation. The new restore must
not call `_refresh_claim_order_key()`.

The four existing bulk methods are all unusable from a claim-only boundary:

* `rebuild_effort_aggregates()` writes `_habitat_effort_used` — canonical **section 4**.
* `validate_effort_aggregates()` is not pure: `_accumulate_effort_totals()` fills
  `_effort_total_scratch` and reassigns `_effort_claim_count`.
* `rebuild_reservation_aggregates()` zeroes and rewrites `_zone_quota_reserved_milli` (section 4)
  **and** refreshes the canonical order keys.
* Per-row `restore_effort_claim()` / `restore_claim()` depend on live Jobs/Directory/zone/habitat
  state, mutate `_pending_*` scratch, and Forage's re-reads `created_tick`/`persistent_id` from
  Jobs — so they cannot be replayed as an exact bulk load.

Also correct one registry entry: Fishing bundles `_effort_claim_count` into its category-3
scratch row, while the identical Forage `_claim_count` is category 2. `_effort_claim_count` is
derived from `_effort_claim_active` and belongs in category 2.

## 7. Proposed finite contract

Per store, one adapter pair over a **single owner block**, mirroring the Inventory precedent but
without requiring a full `Record` and without any new Inventory dependency (no author need is
visible in the packet):

* `copy_claim_columns_into(columns) -> bool` / `restore_claim_columns(columns) -> bool`, with
  `claim_detail()` for refusal text; `columns` is a caller-owned fixed-shape struct holding the
  7 (resp. 11) arrays plus `claim_count`.
* Codec side: `capture_fishing_claims_into(block, store, columns)` and
  `apply_fishing_claims(block, store, columns)` taking `OwnerRecord` only, so neither store
  forces the other five section-7 owners to exist. A five-sixths *Record* is still not a section;
  a one-owner *block* is a legitimate unit.
* **Held clock**: no `SimClock` read, no tick derivation, no lease renewal. `created_tick` is
  transported, never minted.
* Structural admission (ordinary Astra ruling proposed): active row requires
  `slot_count >= 1`; `remaining_milli` in `1..MANUAL_QUOTA_MAX_MILLI` (1180000) — zero is
  refused, because a zero-remaining claim is a row `_apply_collection()` would have closed, and
  clamping structural input is forbidden; `patch_kind` in `0..PATCHES_PER_ZONE-1`; slots/
  generations non-null and in directory range; order keys `>= 0`. Inactive row must be exactly
  blank per §3. **Source count**: the caller supplies the expected active-row count; the owner
  counts actives and refuses on disagreement, then publishes the accepted count as the derived
  field and as the return value. No aggregate rebuild, no collaborator call, no scratch write
  beyond the claim slice.
* Deferred to the coordinator: expedition/job liveness, `get_typed_row(ref) == row`, habitat and
  zone existence, `slot_count <= _habitat_effort_slots`, per-habitat occupancy totals,
  `quota_reserved` reconstruction, cross-section digest agreement.

### Tests

1. Round trip on a fully blank table; bytes identical.
2. Round trip with mixed active/free rows incl. stale generations; every non-claim field of both
   modules compared before/after (guards the section-1/4/5 preservation claim).
3. Refusal leaves the store byte-identical: bad `patch_kind`, `remaining_milli` 0, 1180001,
   `slot_count` 0, non-blank inactive row, source-count mismatch.
4. Restore does **not** change `_habitat_effort_used`, `_zone_quota_reserved_milli`,
   `_effort_total_scratch`, `_pending_*`, or the order keys — asserted positively.
5. Order-key preservation: restore, then assert `created_tick`/`persistent_id` equal the saved
   values even where the owning Job's current values differ.
6. Blank-form parity with `save_section_inventories.gd`: a captured block passes
   `owner_refusal()` for both owner ordinals.
7. Boundary rows 0 and 511 / 0 and 8191 exercised for positional identity.

## 8. Checked arithmetic at the loader

Two unchecked additions exist in code the loader will reach:

* `_stock_reserved_milli()` sums `remaining_milli` over 8192 rows into an i64. Public-legal
  maximum is `8192 * 1180000 = 9 666 560 000`, ~9.7e9 — no overflow. A codec-only payload
  (i64-max per row) overflows.
* `_accumulate_effort_totals()` accumulates `slot_count` into `_effort_total_scratch`, a
  **PackedInt32Array**, and compares against capacity *after* the add; per-row i32-max values
  can wrap before the comparison. Public paths cap `slot_count` at the habitat's free slots
  (4–6 per `EFFORT_SLOTS_BY_TYPE`), so no public witness exists.

**No public-API bug is claimed here.** Neither is a Reservations-style real-API overflow
witness; both are loader/reconciliation hazards arising strictly from the codec domain being
wider than the world's. The remedy is checked addition (`IntMath`) in the reconciliation pass
plus the §7 structural bounds — not clamping, and not widening `_effort_total_scratch` in place.

## 9. Exact bytes and peak memory at the fixed caps

No compression, no index compaction; column-major, tightly packed little-endian.

* Fishing payload: `512 × (1 + 6×4) = 12 800` value bytes, `7 × 8 = 56` element-count bytes,
  `4` child-extent-count bytes → **12 860**. Wrapper `4 + 7 + 4 + 8 + 8 = 31` → block **12 891**.
* Forage payload: `8192 × (1 + 7×4 + 3×8) = 8192 × 53 = 434 176`, `11 × 8 = 88`, `4` →
  **434 268**. Wrapper `4 + 6 + 4 + 8 + 8 = 30` → block **434 298**.
* Two blocks: **447 189 bytes** (excluding the section's 4-byte `store_count`, which belongs to
  the six-owner section, not to a claim-only pair).

Memory: an `OwnerRecord` holds every column at full extent — 12 800 B (fishing) + 434 176 B
(forage) = 446 976 B of column payload. Allocate-before-consume means a decoded local plus the
caller's record coexist at peak: ~894 KB, plus one ≤65 536 B chunk buffer and per-array header
overhead (~20 packed arrays). Under 1 MB, cold path, bounded, no per-tick allocation. Chunking
is already field-aligned: the largest single column, forage i64 at 8192×8, is exactly one
65 536-byte chunk; i32 columns are 32 768 B.

## 10. Verdict

Feasible as specified, with one narrow and fully-bounded contract per store, provided the owner
boundary (a) restores only the 18 columns and the derived count, (b) calls none of the four
existing aggregate/per-row methods, (c) preserves order keys and stale generations exactly, and
(d) enforces the narrower structural domain rather than the codec's. Nothing here admits a full
save-section or full-world acceptance: two independent block adapters are two block adapters.

## 11. Missing excerpt dependencies (precise)

Not in the packet; each blocks a specific assertion above.

1. `entity_directory.gd`: `NULL_SLOT`, `NULL_GENERATION`, `DIRECTORY_CAPACITY`, `KIND_*`,
   `get_typed_row()`, `owner_slot_of_typed_row()`, `get_persistent_id()`. Blocks §3's blank-form
   equality and §4's ref-range claim.
2. `fishing.gd`: `_init`/`clear()`, the writer of `_habitat_effort_slots` (habitat creation), and
   `habitat_slot_of_into()`. Blocks naming an exact constant upper bound for `slot_count` at the
   owner boundary; §7 therefore bounds only `>= 1` and defers the capacity test.
3. `forage.gd`: `_release_closed_claims()`, `_claim_is_over_allowance()`,
   `available_quota_milli_into()`, `_may_reserve_quota()`/`_reserve_quota()`,
   `stock_available_milli_into()`, `_typed_zone_row_of()`. Blocks a complete statement of which
   reconciliation reads touch claim columns.
4. `jobs.gd`: `created_tick_of()`, `is_member()`, `is_job_present()`, `JOB_CAPACITY`. Blocks the
   order-key provenance argument in §6 beyond the docstring.
5. `OpResult`, `_succeed()`, `_refuse()` definitions (both modules). Blocks the exact return
   shape proposed in §7.
6. `inventory.gd` `CanonicalColumns`, `copy_canonical_columns_into()`, `canonical_detail()`.
   Blocks confirming adapter-shape parity; the proposal deliberately does not depend on it.
7. `canonical_state_hash.gd` `Walker`, `FieldValues`, `Refusal`. Blocks any claim about section-15
   registration for these two owners.
8. `save_codec.gd` `Reader`/`Writer`/`Scalar` and `save_header.gd` `Refusal`. Inferable from use,
   not witnessed.
9. `docs/planning/canonical_state_registry.json` itself — only the two Markdown tables were
   supplied, so declared ordinals are taken from `save_section_inventories.gd`'s `KEYS_*` order.
10. `test_save_section_inventories.gd`. Blocks stating which of §7's tests already exist.
