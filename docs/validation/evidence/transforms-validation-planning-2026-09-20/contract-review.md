# Independent contract review — TRANSFORMS-S4-VALIDATE-R01 draft1

2026-09-20. Read-only review of the draft contract against the supplied sources
(`transforms.gd`, `entity_directory.gd`, `save_section_component_columns.gd`,
`save_component_columns_schema.gd`, `save_owner_schedule.gd`, `test_transforms.gd`, the stream
contract, and the two prior planning notes). Nothing here was run, applied or measured.

**Verdict: the contract is internally consistent and implementable as written.** Two testability
corrections below are required before the mutation list can be believed. Neither is a blocker.

## 1. Exact domain and the uniqueness reclassification

Re-derived independently, and Astra's correction stands: **duplicate positive binding IDs are a
function of the supplied binding column alone.** The feasibility note conflated "needs scratch"
with "needs another section". Those are different properties; only the second would justify
deferral. Cursor agreement and Directory reconciliation remain genuinely cross-section.

The eight pose fields admit every signed int32 at any positively bound row. `_fields_fit_int32` is
the only constraint any writer applies; there is no map bound, no yaw normalisation, no
current==previous invariant (`advance()` exists to break it), and yaw zero/handedness are named
MOVE-G01/G04 blockers. The contract's refusal to invent any of these is correct and load-bearing.

## 2. Uniqueness is not a valid public complete-world state

The row is `POSITIONED_BASE[kind] + typed_row` — a pure function of the directory row, with no
second allocator — so one entity owns one row for its whole life. `place()` is the only stamp
writer and stores `_directory.get_persistent_id(ref)`, which is at least `PERSISTENT_ID_MIN` for a
live slot. Persistent IDs are never reused while `_next_persistent_id` only rises. Two rows can
therefore carry one positive value only if one identity was stamped into two rows, which no public
sequence produces. Refusing duplicates rejects nothing legitimate.

**The one collision producer, named explicitly.** `EntityDirectory.clear()` returns the cursor to
1; `Transforms.reset()` zeroes all nine columns. `transforms.gd` documents the reset as GUARDED —
the settlement is the only caller and runs both together. A caller that clears or restores the
Directory *without* the paired Transform reset re-issues identity 1 over surviving stamps and can
manufacture a duplicate. That caller is already violating the reset contract. The predicate must
not be documented as detecting, licensing or repairing it: a stale stamp that happens **not** to
collide is locally indistinguishable from a legitimate one, so refusing collisions is not
cross-world contamination detection. No reuse semantics may be inferred from this gate.

## 3. Memory bound and existing lifetimes

Arithmetic checks: 3151872 framed values + 350208 binding scratch = 3502080; with three 65536
windows, 3698688, inside the 6417408 single-owner allowance. `i32_column()` returns the stored
column **without duplicating**, and packed arguments are copy-on-write, so the nine accessor reads
add nothing; only `duplicate()` on the binding column allocates, and only that copy is sorted.
That must be an actual `duplicate()` — sorting the argument would mutate the caller's record.

Precedent exists in-tree at a larger size: `entity_directory.cursor_refusal()` and
`_column_domain_refusal()` both duplicate-and-sort a 352418-element column (1409672 bytes) on the
same restore path. A 350208-byte copy is the smaller instance of an accepted pattern. It is a
transient allocation, not a resident one, and no second owner or world is constructed. The bound
holds only under the stream contract's take-before-next-input rule; validating owner 15 while an
adjacent owner record is still retained is the already-excluded misuse case, not headroom. The
allowance remains logical packed arithmetic; native and wrapper overhead stay unmeasured.

## 4. Stamp-first canonical versus stamp-last diagnostic

Confirmed from source. `FIELD_KEYS` for owner 15 is `_bound_persistent_id, _x, _y, _z, _yaw,
_prev_x, _prev_y, _prev_z, _prev_yaw`; `state_bytes()` appends `_x .. _prev_yaw` then the stamp.
Both are correct in role. The contract's rules — do not change the diagnostic, remap explicitly in
fixtures, never assume agreement — are the right ones, and the remap is where a plausible,
stable, wrong byte stream would otherwise be born.

## 5. Gates, mutants and two required corrections

Gate order (shape, binding sign, duplicate, free-row residue) is a defensible global-before-global
ordering matching `_restore_refusal()`'s domain-before-rows precedent; the choice is Astra's.
After gate 2 the duplicate scan sees only non-negative values, so "adjacent equal and positive" on
the sorted copy is exact and repeated zeros are ignored without a special case. `find(0, from)` for
gate 4 touches only zero-bound rows, which is right: positive rows admit every signed value.

**Correction A — the two order mutants are equivalent as specified.** `check duplicate before
binding domain` is only distinguishable on an image that fails both with different codes; a
repeated *negative* value is ignored by gate 3, so the witness must carry a negative stamp **and**
a repeated positive one. Likewise `check free before duplicate` needs a repeated positive stamp
**and** a zero-bound row with a nonzero pose. Without those paired witnesses both must be reported
unkilled rather than killed.

**Correction B — the all-zero substitution of the binding accessor is killed by a positive
fixture, not a negative one.** An all-zero stamp column passes sign and duplicate gates and makes
every row zero-bound, so it is caught only when a legitimate image with a positive stamp and a
nonzero pose is wrongly refused `COLUMN_FREE_ROW`. That positive fixture is therefore load-bearing
for the mutation claim and must be named as such, not left implicit among the acceptance cases.

The contract is right that pose-field swaps are equivalent under symmetric rules and must not be
reported killed; canonical mapping is fixed by the bridge and by source review.

## 6. History, stale stamps, deferral and `bound_count`

All signed pose history is preserved: no gate reads a positively bound row. The public stale case
is real — the existing inherited-row test and the probe both leave a destroyed entity's stamp and
pose in place with `bound_count()` at 1 — so consulting a live Directory would reject legitimate
state. The contract forbids it correctly.

`bound_count` is confirmed as the count of nonzero stored stamps: `place()` increments only when
the stamp was 0, `unbind()` decrements, `destroy()` touches neither. It is derived, absent from the
nine-field schema, and must be recomputed on restore by the separate owner-binding task.

The cross-section defer is correctly explicit. One downstream note: `cursor_refusal()` cannot be
reused for this column — it requires `DIRECTORY_CAPACITY`-sized input and would return
`COLUMN_SHAPE` on 87552 values. TRANSFORMS-SAVED-IDENTITY needs its own comparison. The local
result must be worded as a locally admissible image, never as an accepted world.

## 7. Bridge, schema pins and scope

Owner 15 is `transforms`, version 1, primary 87552, zero child extents, nine `TYPE_I32` fields of
87552; payload 3151948 and block 3151982 reproduce from the framing rules. The gate sequence and
the distinct `Transforms owner15 metadata:` prefix mirror `save_owner_schedule.gd` and keep gate 3
forwarding unchanged. Preloads introduce no cycle. Minor, non-blocking: the raw `COLUMN_*` codes
are not owner-qualified and already collide with `entity_directory`'s and Schedule's spellings;
the detail string is what disambiguates, exactly as today.

Scope is bounded and testable. The author owns `transforms.gd` and the new bridge; everything else
is parent-owned. A zero frame remains a valid empty Transform image, unlike Schedule's.

## Blockers

None. The registry previous-pose prose correction and the incomplete TRANSFORMS-SAVED-IDENTITY
coupling are carried forward unchanged as known-open items, not as objections to this contract.
