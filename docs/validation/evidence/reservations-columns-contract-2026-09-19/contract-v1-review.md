# Independent contract review — SAVE-RES-R01 v1

2026-09-19 · reviewer session, separate from the audit and from the contract author.
Scope: implementability of the proposed contract only. No whole-world correctness is
inferred, nothing was implemented, executed or applied.

**Verdict: ACCEPT WITH CORRECTIONS.** No blocking contradiction. Seven precision gaps
(F1–F7) are recorded, each with an exact resolution that can be applied to v2 without
changing the admission domain or any wire byte.

## 1. Independently verified claims

**V1 — admission domain is source-derived.** `_check_job_ref` bounds job slot by the
owner's `_job_capacity` and requires `job_ref.y > 0`; `_preflight_claim_fields` bounds lot
slot by `_lot_capacity`, requires `quantity > 0`, `expiry >= 0`, and purpose within int32.
The contract's step 3 restates exactly these, with J/L taken from the target's clamped
constructor extents. Nothing narrower and nothing invented.

**V2 — one generation per slot is a real invariant, not an assumption.** A second
generation cannot enter a job slot (`_check_job_ref` → `JOB_GENERATION_CONFLICT`) or a lot
slot (`_preflight_claim_fields` → `LOT_GENERATION_CONFLICT`), both checked against the
list head, which is sound inductively because the list is homogeneous. `drop_retired_lot_claims`
drops only matching generations, which is total given homogeneity. Steps 4 and 5 are therefore
derived, not stipulated.

**V3 — the full key is the coalescing key.** `_upsert_row`/`_find_row` make
`(job_slot, job_generation, lot_slot, lot_generation, purpose)` unique among active rows.
The duplicate rule matches the runtime rule exactly.

**V4 — chain keys match the live comparators.** Proposed job order
`(job_slot, lot_slot, lot_generation, purpose)` is `_compare_lot_key` under `_link_job`;
lot order `(lot_slot, job_slot, job_generation, purpose)` is `_compare_job_key` under
`_link_lot`. Keys are unique inside a list, so the stable row tie-break is unreachable but
harmless. The registry-prose correction (semantic key order, not ascending row append) is
correct and necessary.

**V5 — non-unique min-heap acceptance is required, not permissive.** `_pop_min` moves the
last prefix entry to index 0 and sifts down over `[0, last)`, leaving a *stale duplicate* of
a still-live free row at index `last`, i.e. in the tail. Any capture check that scanned the
whole array, or compared the array to the ascending rebuild, would refuse healthy owners.
The contract's prefix-only membership check plus tail-irrelevance is the only correct rule.
The live prefix is genuinely a min-heap after both `_pop_min` and `_push_free`.

**V6 — restore's ascending free prefix is a valid min-heap** and reproduces lowest-free-index
allocation, matching `_allocate_row`. Row identities are preserved, and there is indeed no
reservation row generation (confirmed by REG-R01 prose in the codec header).

**V7 — owner-accepted ⊆ codec-accepted.** Codec `_reservation_row_refusal` bounds job slot
by the compiled 8192 and lot slot by 16384; the owner's clamped J/L never exceed those.
Codec live-generation, quantity `> 0`, expiry `>= 0`, occupancy `0/1`, and the blank ordinals
1..7 (with `-1` for `_r_job_slot`/`_r_lot_slot` via `NEGATIVE_ONE_FILL_KEYS`, `0` elsewhere)
all match `clear()`/`_free_row`. Purpose is unchecked by the codec. Therefore the staged codec
gate in `capture_into` is defensive only and cannot refuse a healthy source; the asymmetry is
strictly one-directional, as claimed. Keeping the returned Refusal authoritative in that
unreachable case follows the accepted stock_age precedent.

**V8 — overflow split is correct.** Per-lot sums are bounded by `lot_available_milli` through
`_preflight_quantities`' checked addition, so per-lot i64 overflow is unreachable in a healthy
world and refusing it narrows nothing. The recorded public probe proves cross-lot job totals
above i64 are admitted by `claim_batch`; `_sum_list` is unchecked. Preserving that payload and
repairing the accessor separately is the only option that neither rejects a reachable admitted
state nor conceals the defect. Confirmed.

**V9 — arithmetic.** 1+20+16 = 37 B/row; 37·32768 = 1 212 416. Derived 4R+16R = 20R = 655 360,
+4J = 32 768, +4L = 65 536 → 753 664. Merge 2·4R = 262 144. Bitmap R = 32 768. Payload
4 + 8·8 + 37R = 68+37R. Wrapper 4+12+4+8+8 = 36. Block 104+37R; at R=32768 → 1 212 520 and at
R=8 → 400, matching all four `wire-baseline.json` entries. Every figure re-derives.

**V10 — hostile-shape ordering.** Refusing to call `audit()` on malformed derived arrays is
correct: `_audit_one_list` calls `_is_row`, then indexes `_job_prev`/`_lot_prev` at row indices
taken from the arrays under test, and `_audit_lot_totals` dereferences Inventory. It is not a
total validator over hostile input. Bounds-before-membership and the local R-byte buffer close
the remaining indexing hazards.

## 2. Findings and exact resolutions

**F1 — two refusal codes are unassigned (underdefined).** Step 3 checks per-row slot range and
per-row generation positivity, but the code list only clearly binds `JOB_GENERATION`/
`LOT_GENERATION` to the step 4/5 *mixed generation per slot* rule, leaving per-row failures
unmapped. *Resolution:* state literally — `COLUMN_RESERVATION_REF` for any active row whose job
slot is outside `[0,J)` or lot slot outside `[0,L)`; `COLUMN_RESERVATION_JOB_GENERATION` for a
non-positive job generation **and** for a job slot carrying two generations;
`COLUMN_RESERVATION_LOT_GENERATION` symmetrically; and fix precedence as the ascending-row scan
(step 3) before the group scans (steps 4–5), so the row-order code always wins.

**F2 — `SAVE_RES_BUSY` is declared but bound to no step.** The apply/capture orders name an
"open/poisoned Inventory" step with no code, while `SAVE_RES_BUSY` appears only in the code
list. *Resolution:* bind `SAVE_RES_BUSY` to a supplied Inventory with an open transaction, and
add `SAVE_RES_INVENTORY_POISONED` for the poisoned flag, checked in that order with distinct
details. A single code for two distinct caller faults costs a diagnosis and is avoidable.

**F3 — the Inventory predicate identifiers are not verifiable from the supplied sources.**
`is_transaction_open()` is used by `reservations.gd` and is safe to name. No public poisoned
predicate is visible in any supplied file. *Resolution:* v2 must name both methods by exact
identifier and add an import/static check asserting `has_method` on both. If no public poisoned
accessor exists, either drop that check from this packet or raise adding one to `inventory.gd`
as a separate packet — the adapter must not reach into private state to obtain it.

**F4 — the heap property is stated in prose only.** *Resolution:* write the exact predicate:
for `i` in `1..free_count-1`, `heap[(i-1)/2] <= heap[i]`, with `heap[i]` first bounds-checked
into `[0,R)` and marked in the membership buffer, and `free_count` first checked to equal
`R - active_count`. Nothing at index `>= free_count` is read.

**F5 — `canonical_detail()` carries no diagnostic.** Returning `String(last_column_refusal())`
makes the adapter's "forward owner code/detail verbatim" produce the code twice. This is *forced*
by the rule that `_last_column_refusal` is the only field written on failure, and is the right
trade. *Resolution:* say so explicitly, and state that tests assert codes only, never detail
text, so no future detail buffer is implied.

**F6 — `_pending_new_rows` after restore is unstated.** The contract says existing scratch is
untouched on success and failure, but `clear()` zeroes `_pending_new_rows` while restore does
not, leaving stale scratch from an earlier `claim_batch`. It is harmless because
`_preflight_rows` recomputes before every read. *Resolution:* record that reasoning in v2 and
add a test asserting a post-restore `claim_batch` reports the correct fresh-row count after a
prior batch left a non-zero value.

**F7 — restore's `-1` heap tail must be marked non-canonical.** The contract says the tail is
`-1` in restored owners; after a single allocate/free cycle `_pop_min` will leave a stale
duplicate there. *Resolution:* state that the tail is an implementation residue, is never
captured, never compared and never hashed, so restore→capture→encode stays byte-identical
regardless of subsequent runtime activity.

## 3. Test additions (beyond the v1 list)

1. Heap whose **tail** duplicates a live prefix entry (accept) versus a duplicate **inside**
   the prefix (refuse `SOURCE_DERIVED`) — the exact `_pop_min` residue shape.
2. `_active_count` disagreeing with the occupancy column while both chains are well formed.
3. A caller record whose two i32 arrays are the **same** instance: refusal leaves it unchanged,
   and a successful export de-aliases all eight.
4. Restore over an owner whose current canonical payload is deliberately malformed, proving the
   old payload is never validated.
5. One block accepted by a full-extent owner and refused by a reduced-J/L owner, with the exact
   code, proving target extents are the interpretation context.
6. A precedence table test for every adapter refusal, each earlier condition masking all later
   ones, on both entry points.
7. A generated-row property test asserting owner-accept ⊆ codec-accept (V7), so the defensive
   gate stays unreachable.
8. `state_bytes()` equality across capture → restore → capture, plus the four literal wire
   hashes re-encoded from a restored owner.

## 4. Checked and cleared

Unclamped metadata with clamped allocation cannot admit anything: any such record fails the
"eight arrays exactly `row_capacity`" shape check, so the storage bound and the refusal are
consistent. Expired-lease preservation with no clock read is consistent with
`release_expired_for_job` being a separate public sweep. Private-stage ownership and direct
transfer match the accepted stock_age adapter, including the refusal to use `set_i32_column`
for any counted ordinal. `O(R log R + J + L)` is achievable with two packed buffers and no
Dictionary. The registry zero-quantity correction matches `_preflight_claim_fields`.
