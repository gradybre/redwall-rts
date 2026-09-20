# Transform saved-column validation: feasibility review of the source note

2026-09-20. Read-only. Independent re-derivation from `godot/scripts/core/transforms.gd`,
`godot/scripts/core/entity_directory.gd`, `godot/test/test_transforms.gd` and the compiled
section-4 schema. No production edit is authorized by this review, and nothing here was run.

## 1. Are the proposed rules proven, and is there a counterexample?

**Nonnegative binding: proven for every current public writer.** `place()` is the only writer
that stamps `_bound_persistent_id`, and it reaches the stamp only after `_row_of()` returned a
row, which requires `_directory.is_valid(ref)`. `get_persistent_id()` on a valid ref returns the
stored column value, which `entity_directory.gd` holds at or above `PERSISTENT_ID_MIN` = 1 for
every live slot; the exhausted cursor 2147483648 is a §1 ledger value and never a live column
value. So a public stamp is always positive, never 0 and never negative. `unbind()`, `reset()`
and `_init()` write 0 and nothing else.

**Zero-bound exact defaults: proven, in both directions.** The three zeroing paths each zero all
eight poses together with the stamp. `advance()` and `set_yaw()` refuse unless `_bound_row_of()`
succeeds, which requires a nonzero stamp matching the current owner, so neither can leave a pose
nonzero under a zero stamp. `place()` writes stamp and eight poses in one call and cannot write a
zero stamp at all. A refused `place()` (`REFUSE_OUT_OF_INT32`) writes nothing.

**No reachable nonzero unbound default found.** The scan covered `_init`, `reset`, `place`,
`advance`, `set_yaw`, `unbind` and every refusal path. There is no bulk restore or copy entry
point in the source, so there is no fourth writer to check — and that absence is itself why the
local predicate is worth having: it is what will hold the invariant when a restore path lands.

**Unrestricted signed pose/yaw domain: confirmed.** `_fields_fit_int32` is the only pose
constraint. There is no map bound, no normalization to 0..65535, no ground-only y, no speed
delta, and no current==previous invariant: `advance()` exists precisely to break the last one.
`YAW_UNITS_PER_TURN` fixes a scale only; the header names zero and handedness as MOVE-G01/G04
blockers. **Do not tighten any of these from an assumed map or yaw validity.**

**Stale positive stamps and retained poses are reachable public states.**
`test_a_typed_row_inherited_from_another_slot_reads_as_unbound` destroys a placed resident
through the Directory; the stamp and pose survive until reuse. A local predicate must therefore
never consult a live Directory and must not reject a positive stamp the Directory no longer
contains. `bound_count` is a derived scalar, not a column, and is outside this predicate.

## 2. Which constraints are local, and how is deferral named?

**Local (decidable from the nine columns alone):** exact extents; binding-ID sign; the
zero-bound residue rule.

**Not local:**
- *Binding uniqueness.* One entity owns one derived row for its whole life and persistent IDs are
  never reused, so the public API cannot produce a duplicate. But it also cannot be checked in the
  local predicate without a duplicate-and-sort over 87552 values — 350208 bytes of scratch, which
  the owner-free, allocation-free shape forbids.
- *Cursor agreement.* Every positive stamp must be below section 1's `_next_persistent_id`. That
  value belongs to `entity_directory`, not to this image.
- *Directory reconciliation.* Whether a stamp names a live entity, and provenance of a whole save.

**Recommended naming.** Have the local predicate return **`locally admissible image`** — never
"valid", never "accepted". State the three deferred obligations as a named list
(`TRANSFORM_CROSS_SECTION_OBLIGATIONS`) in the predicate's own docstring, so a caller that accepts
the local result cannot believe it has accepted a world. This mirrors `entity_directory.gd`, where
`cursor_refusal()` is a separate public predicate precisely because the cursor is a §1 value the
column restore must not silently repair.

## 3. Predicate shape and gate order

A nine-argument static predicate over `PackedInt32Array` is the right owner-free shape: it
constructs no Transform and no Directory, and it is reusable by a future bulk restore and by a
save bridge without either owning the other.

Proposed gate order, each with its own raw distinct code:

1. **Shape.** All nine arrays exactly `TRANSFORM_CAPACITY` = 87552. First, because every later
   gate indexes.
2. **Global binding domain.** No negative stamp anywhere.
3. **Global zero-bound residue.** Every row whose stamp is 0 has all eight poses 0.

Gate 2 precedes gate 3 so that an image failing both reports deterministically on the domain,
matching `_restore_refusal()`'s domain-before-rows order in `entity_directory.gd`.

**Allocation-free implementation.** Two passes, no duplicate and no sort. Pass one is a linear
walk of the stamp column checking sign only. Pass two uses `_bound_persistent_id.find(0, from)`
to jump from one zero-bound row to the next in C++, touching only unbound rows — the same
technique `_live_column_refusal()` uses with `active.find(1, ...)`. Positive rows are never read,
which is exactly right: every positive row admits all signed int32 poses including extrema and a
current differing from previous.

**Codes are proposals, not quotations.** ARCH-ID-004 numbers `create()` codes and publishes no
registry for column operations. Decision 0105's precedent is a module-owned namespace, prefixed
and kept separate from the per-call refusal field. Proposed: `TRANSFORM_COLUMN_SHAPE`,
`TRANSFORM_COLUMN_BINDING_NEGATIVE`, `TRANSFORM_COLUMN_UNBOUND_POSE_RESIDUE`, reported through a
`_last_column_refusal`-style field distinct from `REFUSE_*`, so a save cannot clobber a `place()`
refusal a caller has not read. Ordinary writers are unchanged.

## 4. Positive, negative and argument-omission tests

- **Positive.** A fresh image; an image with a positive stamp and signed extrema in all eight
  poses; an image whose current and previous differ; an image with a stale positive stamp no
  Directory contains. All admissible.
- **Negative.** One negative stamp; one zero-bound row with one nonzero pose; each of the nine
  arrays short by one and long by one (eighteen shape cases, not one).
- **Argument omission.** A negative stamp kills a substitute that ignores the binding column. For
  each of the eight pose fields, an image with stamp 0 and only that field nonzero kills a
  substitute that reads a subset of poses.
- **Explicitly not claimed.** Swapping two pose fields is semantically equivalent under this
  predicate, which treats all eight identically. Do not report swap mutants as killed. Exact
  canonical mapping is fixed by gate 5 below and by source review, not by this predicate.

## 5. Owner metadata, and one order discrepancy to resolve first

The compiled section-4 table already pins this owner: index 15, key `transforms`, owner version 1,
primary count 87552, child extent count 0, nine fields, all `TYPE_I32`, each element count 87552.
The arithmetic reproduces: payload `4 + 9*(8 + 87552*4)` = 3151948, block `24 + 10 + 3151948` =
3151982, both matching the generated constants. No new array or projection is required to pin any
of this.

**Discrepancy, and it matters.** The compiled canonical field order is
`_bound_persistent_id, _x, _y, _z, _yaw, _prev_x, _prev_y, _prev_z, _prev_yaw` — stamp **first**.
`state_bytes()` emits `_x .. _prev_yaw` then `_bound_persistent_id` — stamp **last**. Both are
correct in their own role; conflating them produces a byte stream that is stable, plausible and
wrong. Tests reading actual public histories from `state_bytes()` must use its documented
diagnostic order; anything canonical must use the schema's ordinal order.

**Proposed bridge gate order**, following `save_owner_schedule.gd`: null record → owner index 15 →
`Schema.schema_refusal()` forwarded unchanged → owner metadata (key, version, extents, and the
nine per-field key/type/count literals) → `owner_shape_refusal()` → typed accessors → the column
predicate's raw code. Schema before metadata before shape, exactly as asked.

**Boundary rows.** 1023/1024, 82943/82944, 83455/83456 and 87551 are derived-row boundaries from
`POSITIONED_BASE`. The column predicate has no concept of kind, so these are *identity-mapping*
fixtures for the bridge and for `transform_row_into()`, not domain fixtures for the predicate. No
further bounded proof is required by the capacity itself: 87552 is `_assert_bases_tile_the_capacity()`'s
own invariant and is already asserted at construction.

## Blockers and authorities

1. **Previous-pose authority conflict — documentation, not code.** The registry row's prose says a
   loader may collapse canonical previous values after digest verification. ARCH-HASH-001 hashes
   current *and* previous and excludes first-frame presentation overrides;
   `docs/planning/movement_contracts.md` §6 calls load previous=current a presentation override
   only; ARCH-SAVE-004 recomputes the digest after installation. The proposed correction — preserve
   all eight canonical fields, override only in presentation — is an ordinary correction owned
   jointly by the registry row's author and the §4 loader owner. It is not taken here.
2. **No ruling names column-refusal codes.** Every code above is a module proposal and moves if a
   ruling lands.
3. **Uniqueness and cursor acceptance are blocked on section 1.** They cannot be discharged until
   the `entity_directory` cursor block and the §4 loader are wired together.
4. **`bound_count` is derived.** It is not a column, is not validated here, and must be recomputed
   from the stamp column by whoever restores.
