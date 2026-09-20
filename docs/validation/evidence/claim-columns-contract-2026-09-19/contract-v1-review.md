# Independent review: exact Fishing and Forage claim columns (SAVE-CLAIMS-R01 v1)

Reviewer lane: independent contract review, 2026-09-19. Bounded, documentary. No tools were
run, nothing was executed, nothing was implemented, and no runtime acceptance is claimed. Every
statement below is a comparison of the contract text against the supplied module sources,
codec, census and registry. Scope is the claim boundary only; unrelated owner functionality was
not reviewed.

## 1. What checks out

**Records and counts.** Fishing's seven columns and Forage's eleven match `fishing.gd`'s
`_effort_claim_*` members and `forage.gd`'s `_claim_*` members exactly, in the same order as
REG-R01's section 7 ordinals and as `save_section_inventories.gd`'s `KEYS_FISHING` /
`KEYS_FORAGE`. No metadata or count field is added to either record, which is correct: the
registry declares seven and eleven fields respectively, and adding one would change
`record_count` and the section body.

**Fixed extents.** 512 is `FISHING_EFFORT_CLAIM_CAPACITY`, asserted in `_init()` against
`KIND_CAPACITY[KIND_EXPEDITION]`; 8192 is `FORAGE_CLAIM_CAPACITY`, asserted against
`KIND_CAPACITY[KIND_JOB]`. Both owners are `PRIMARY_COUNT_IS_FIXED` in the codec, so
"cannot be reconfigured by records" is enforceable and not merely asserted.

**Exact blanks.** Fishing: active 0, both slots -1, three generations 0, slot_count 0 — matches
`_clear_effort_claim_row()` and `_clear_effort_claim_columns()`. Forage: active 0, three slots
and kind -1, three generations 0, three i64 zero — matches `_clear_claim_row()`. Both also
agree with the codec's `canonical_fill_of()` over `BLANK_ORDINALS_FISHING` and
`BLANK_ORDINALS_FORAGE`, so the owner gate and the defensive codec gate cannot disagree about a
released row. That agreement is load-bearing and worth pinning in a test.

**Packed arithmetic.** Fishing 512 + 6x512x4 = 12800, matching `effort_claim_payload_bytes()`.
Forage 8192 + 7x8192x4 + 3x8192x8 = 434176, matching `claim_payload_bytes()`.

**Wire framing.** Fishing wrapper 4 + 7 + 4 + 8 + 8 = 31; payload 4 + 7x8 + 12800 = 12860;
block 12891. Forage wrapper 4 + 6 + 4 + 8 + 8 = 30; payload 4 + 11x8 + 434176 = 434268; block
434298. All six figures recompute correctly from `wrapper_bytes_of`, `extent_block_bytes_of` and
`payload_bytes_of`. Owner schema 1 for both and section schema 3 match `OWNER_SCHEMA_VERSIONS`
and `SECTION_SCHEMA_VERSION`. Zero child extents is right: only `inventory` declares one.

**Group shapes.** Fishing 1 u8 / 6 i32 / 0 i64 and Forage 1 u8 / 7 i32 / 3 i64 match
`TYPES_FISHING` and `TYPES_FORAGE`. Insisting on named wire ordinals plus
`Codec.storage_index_of` rather than assumed group positions is correct and matches the
`save_gear_restore.gd` precedent, where ordinals 0 and 9 are u8 at storage positions 0 and 1.

**Identity.** Fishing's row index is the Expedition typed row and its owning slot is recovered
through `EntityDirectory.owner_slot_of_typed_row()`, so storing only the generation is correct.
Forage's row index is the owning Job's typed row while `_claim_job_slot` is a *directory* slot
taken from `job_ref.x` in `_write_claim()`. The contract states both correctly and forbids
compaction, which is the only safe reading.

**Domain bounds.** Directory slots 0..352417 match `DIRECTORY_CAPACITY` = 352418 and the
codec's own `_slot_refusal(..., DIRECTORY_CAPACITY, ...)` for fishing ordinals 2 and 4 and
forage 1/3/5.

**Fishing slot_count 1..6.** Sound. `_write_created_habitat` is the sole positive writer of
`_habitat_effort_slots`, from `EFFORT_SLOTS_BY_TYPE` = coast 6, lake 6, river 4; the census
agrees and lists only resize/fill/read sites otherwise. `reserve_effort_slots()` bounds a claim
by free capacity and `restore_effort_claim()` bounds it by `_habitat_effort_slots[slot]`, so no
healthy public state exceeds 6. Deriving the bound by scanning the three compiled constants
costs no allocation. Accepting 5 or 6 on a river claim is a deliberate over-approximation and is
correctly deferred to the reconciler.

**Forage 1..1180000.** Sound. `claim_forage()` requires a positive amount bounded by stock
availability, which is itself bounded by a single patch capacity; `restore_claim()` already
refuses `remaining_milli <= 0` or `> MANUAL_QUOTA_MAX_MILLI`. `_apply_collection()` clears a
claim the moment remaining reaches zero, so "active zero refuses" is accurate rather than
asserted.

**Gate ordering.** Table-wide occupancy before per-row fields matches both owners' own habits
and the codec, which runs `_occupancy_refusal` over the whole active column before its row loop.
Per-row REF before KIND before QUANTITY before ORDER_KEY is exactly wire order for Forage, and
REF before SLOT_COUNT is wire order for Fishing. Deterministic first-gate-wins is stated.

**Forbidden calls.** The list is correct where it matters most. `rebuild_effort_aggregates()`
writes `_habitat_effort_used` (a section 4 field). `validate_effort_aggregates()` is not
read-only: through `_accumulate_effort_totals()` it fills `_effort_total_scratch` and assigns
`_effort_claim_count`, and it refuses outright when `_jobs` is null.
`rebuild_reservation_aggregates()` rewrites `_zone_quota_reserved_milli` and calls
`_refresh_claim_order_key()`, which overwrites the saved `created_tick` and `persistent_id` from
live Jobs. Forbidding all four, and naming `_refresh_claim_order_key` explicitly, is the single
most important thing this contract does.

**Memory envelope.** Against the gear precedent the conservative counts are right. Capture: one
private Columns (P), the OwnerRecord constructor's own allocation (P), the target block's
replaced arrays (P), the live claim arrays (P) and the owner's publication duplicate (P) = 5P.
Apply: local Columns constructor (P), borrowed block arrays (P), live (P), owner duplicate (P) =
4P. Owner-only 3P each. Forage 5P = 2170880 and Fishing 5P = 64000 are arithmetically correct,
and the caveat that these are slice bounds rather than process peak is properly stated.

**Ungrouped sums.** 512 x 6 = 3072 fits i32; 8192 x 1180000 = 9666560000 fits i64. Both correct,
and the contract correctly refuses to let them substitute for checked arithmetic in the
reconciler.

**No Inventory gate.** Correct and materially different from gear. Neither owner holds an
Inventory, and neither claim table references an inventory lot, so the gear adapter's
`INVENTORY_MISMATCH` / `BUSY` gates have no analogue here. Refusing to invent one is right.

## 2. Findings

None of these is a contract blocker. All are ordinary Astra-level resolutions.

**F1 — the post-restore reconciler for both derived aggregates is unnamed.** The contract
correctly forbids every existing rebuilder, but the two derived values those rebuilders exist to
maintain — `_habitat_effort_used` and `_zone_quota_reserved_milli` — are left in a state the
contract does not say who repairs. `_zone_quota_reserved_milli` is declared category 1 at
section 4 forage ordinal 12, so a verbatim section 4 restore supplies it; but the only existing
routine that *checks* it is destructive to order keys, and the only existing checker on the
fishing side mutates the claim count and needs a Jobs store. The coordinator paragraph should
say explicitly that verification of both aggregates must be a new read-only computation, not a
call to `rebuild_reservation_aggregates()` or `validate_effort_aggregates()`.

**F2 — SOURCE_COUNT and SHAPE are unreachable through the healthy public API.** Both owners
maintain their counts symmetrically (`_write_claim` / `_clear_claim_row` /
`_apply_collection`; `_write_effort_claim` / `_clear_effort_claim_row`), so a mismatch cannot be
produced by any public sequence. Likewise, a no-argument Columns constructor always produces
correctly sized arrays, so SHAPE is reachable only when a caller replaces an array — which is
precisely what the adapter's apply path does when it borrows block arrays. The contract should
state the exercise route for each (a test subclass or a deliberately reshaped record), following
the precedent decision 0036 set for `forage.gd`'s `P > K` guard and the duplicate-habitat branch.
Without that, the mutants deleting either gate will survive and be mistaken for untested gaps.

**F3 — the owner and codec validators deliberately diverge, and this is not said.** The owner's
Fishing slot_count upper bound of 6 and Forage quantity bound of 1..1180000 are strictly
stronger than the codec, which requires only `< 1` and `< 0` respectively, and the codec has no
SOURCE_COUNT concept at all. The staged `Codec.owner_refusal` in capture therefore cannot fire
after a successful owner capture. The gear adapter documents exactly this divergence; this
contract should repeat it, so the staged gate is not later read as a promised reachable failure.

**F4 — `_claim_count` registration is asymmetric.** The registry section requires "Registry
Fishingclaimcount category2" but says nothing about Forage's `_claim_count`, which is the same
kind of derived scalar and is equally absent from REG-R01's declared fields. Register both, or
state why one is registered and the other is not. The contract should also say that
`record_count` and `section_schema_versions` are unchanged, since the new diagnostics are
category 3 and belong outside the canonical `owners` array.

**F5 — group publication must come only from a private staged record.** In GDScript a
`PackedInt32Array` is a value with copy-on-write, but `Array[PackedInt32Array]` is a reference
container. Assigning the three group arrays wholesale (the gear pattern) makes the target block
and the source share one container object. That is safe only because the source is function-local.
The contract's "Output/input may alias existing arrays; later mutation cannot leak" understates
this: it should state the value/reference premise and require that the published containers come
from the private staged record, never from a caller-visible one.

**F6 — code-echo detail loses row diagnosability.** `claim_column_detail()` as an exact code
echo is weaker than every existing precedent: `forage.gd`'s section 1 helpers build
`"%s: %s"` with tile, link and zone indices, and the codec's refusals name the offending row and
value. Requiring detail to be non-empty but content-free means a rejected save says which gate
fired but not which of 8192 rows. Recommend the owner detail carry the failing row index; the
"exact code echo" assertion can then be dropped rather than tested for.

**F7 — three diagnostic naming conventions.** `gear.gd` uses `last_column_refusal()` /
`canonical_detail()`, `inventory.gd` uses `canonical_detail()`, `forage.gd` already has
`section_1_code()` / `section_1_detail()`, and this contract adds
`last_claim_column_refusal()` / `claim_column_detail()`. Forage will carry two independent
diagnostic pairs. Acceptable, but record the divergence deliberately rather than by accretion.

**F8 — the barrier is an adapter invariant only.** `restore_effort_claim_columns()` and
`restore_forage_claim_columns()` take no clock, so a direct owner call bypasses the barrier
entirely. Gear has the same shape, so this is precedent-consistent, but the owner section should
say so explicitly instead of leaving it implied by the adapter section.

**F9 — capture has no executable quiescence predicate.** Gear could prove a quiet boundary via
Inventory's transaction flags. Here there is none, and the contract falls back on "Capture caller
guarantees completed quiescent boundary". That is honest, and the `_pending_*` scratch in both
owners is written and consumed inside one public call with no re-entry, so it is stale rather
than live at a boundary. Say that reasoning out loud rather than asserting the conclusion.

**F10 — the forbidden list should enumerate the tempting helpers.** "All claim clearers/writers"
and "all hot mutators" are catch-alls that cover them, but `purge_stale_effort_claims`,
`release_cancelled_effort_claims`, `purge_stale_claims`, `release_cancelled_claims`,
`release_claims_of_zone`, `reconcile_claims`, `run_midnight`, `collect_claim` and `release_claim`
are the specific methods an implementer will reach for, and several silently touch
`_zone_quota_reserved_milli` or the live counts. Name them.

**F11 — the full-Forage literal golden is impractical.** A committed literal wire golden of
434298 bytes is not reviewable. Recommend committing empty and sparse goldens literally, and
proving the full case against an independently authored encoder plus a pinned digest, with the
limit stated in the test title as the contract already requires elsewhere.

## 3. Cross-world obligations the contract should keep listing

Already named and correct: row/Directory/Job association, reference liveness, habitat and zone
presence, per-habitat effort capacity, checked aggregates against saved section 4 columns, and
Forage order-key provenance. Two to add explicitly:

- A Fishing claim can legitimately survive its habitat's destruction, because
  `restore_effort_claim()` never increments `_habitat_effort_used` and `destroy_habitat()` only
  refuses while that counter is positive. Such a claim passes every structural gate here. The
  reconciler must catch it.
- A Forage `persistent_id` of 0 is structurally accepted but is not producible by
  `_write_claim()` for a live Job, since directory persistent ids begin at 1. Treat 0 as a
  provenance signal at reconciliation rather than as a normal key.

## 4. Mutants worth adding

The four named mutants are well chosen. Add: dropping the SOURCE_COUNT comparison; sorting or
compacting rows on restore; publishing the source arrays without duplication; clearing the new
diagnostic on refusal; and reading Forage's stored job slot as a typed row rather than a
directory slot. The last of these is the defect the contract spends a paragraph preventing and
currently has no mutant.

## 5. Disposition

No contract blockers. The arithmetic, constants, blanks, identity model, gate ordering, purity
list and memory envelope are internally consistent and consistent with the supplied modules.
F1, F2 and F4 should be resolved in the contract text before implementation; F3, F5, F6, F8, F9,
F10 and F11 are wording and evidence-plan resolutions. F7 is a recorded divergence. Nothing here
requires a user preference or a new ruling.
