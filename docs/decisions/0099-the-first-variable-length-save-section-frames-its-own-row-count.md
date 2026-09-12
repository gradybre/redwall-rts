# 0099 — The first variable-length save section frames its own row count

Date: 2026-09-12 · Status: **Accepted**

Section 14 NAME_POOL is implemented in
`godot/scripts/core/save_section_name_pool.gd`. It is one column of 512 strings
and it is the **first variable-length section in the save format**, so the
framing it establishes is what sections 3, 4, 5, 7, 8 and 13 will copy. This
record fixes the judgements that implementation required and names what it did
not build. It closes no 09.2 acceptance gate and produces no release save.

## Decision

1. **The section carries an explicit `row_count:u32`, checked against the
   compiled capacity.** The two sections already written
   (`save_section_rng.gd`, `save_section_world_runtime.gd`) are fixed-length, so
   for them "the length is the validation" and a count field would be
   redundant. That reasoning dies here: a section 14 whose length is short is a
   perfectly plausible length for a *different, shorter* pool, so length alone
   can no longer tell a truncation from a valid file. The count is written, and
   `decode_into()` refuses anything but `ROW_COUNT` (512, taken from
   `residents.gd::RESIDENT_CAPACITY`, not restated).
2. **Each row is `utf8_byte_count:u32 LE` then exactly that many UTF-8 bytes**,
   no terminator, no alignment, no padding — SAVE-R09-002 verbatim. The encoder
   reproduces the ruling's pinned fixtures: empty `00000000`, `Oak` =
   `030000004f616b`, `Móle` = `050000004dc3b36c65`, and `01000000c0` /
   `02000000c080` both fail UTF-8.
3. **`decode_into()` takes the descriptor's `length` as well as its `offset`,
   and every row is bounded against the section end, not the buffer end.**
   SAVE-R09-004 makes the layout gapless, so the bytes after section 14 are
   section 15's — not absent. A decoder bounded by `bytes.size()`, which is what
   `save_codec.gd`'s `Reader.read_utf8_u32_into()` gives you, would let an
   over-long length prefix on the last row consume the next section's bytes and
   decode them as a valid name. That helper is therefore deliberately **not**
   used; the row reader checks `section_end - position` twice per row, once
   before the prefix and once before the payload. Exact consumption is required
   at the end: leftover bytes are `SAVE_NAMES_TRAILING_BYTES`, not a short valid
   pool.
4. **The empty name is a present row with a zero-length name, never an absent
   row, and every one of the 512 rows is written.** GDD REQ-SET-040 makes naming
   trigger-based and REQ-SET-041 keeps anonymous residents in full persistent
   state, so in the starter settlement exactly one row of twelve is named and
   511 of 512 rows are `00000000`. The empty case is the common case. Dropping
   empty rows would shorten the section and make the row index stop meaning the
   slot index, which is why `apply()` refuses a **nonempty** name on a slot the
   store has no resident in (`SAVE_NAMES_ABSENT_ROW_NAMED`) while accepting an
   empty one silently: those two are different facts.
5. **Validation is real, not implied by the length, and every failure has its
   own code.** Over-long encoded bytes, a scalar count outside 2–32, a control
   character, a bad row count, a truncation, trailing bytes, a malformed UTF-8
   sequence and an arena overrun are eight distinguishable refusals. A load
   report that could only say "bad section" would be useless at exactly the
   moment it is needed.
6. **`canonical_bytes_of()` is NOT this section's payload**, which is the second
   thing that does not transfer from section 10. SAVE-R09's canonical field
   record is `section_id, owner_key, field_key, type, value_count:u64, values`,
   so the walker supplies the count itself; emitting the section's own
   `row_count:u32` inside the digest input would hash 512 twice and disagree
   with any walker that followed the grammar. The canonical contribution is the
   512 values and nothing else. Persistence obligation and digest membership are
   separate axes (decision 0063): section 14 is **both** — category 1 in the
   registry, and inside ARCH-HASH-001, whose exclusion list names selection
   flags, camera, UI and derived indexes but not `name_key`.
7. **`extent_refusal()` is public**, as it is in `save_section_rng.gd`, for the
   reason learned there: `save_codec.gd`'s reader is bounded too, so a slack
   extent check would still end in *some* refusal one layer down and hide. It is
   tested on its own, and it separates four causes — negative offset, negative
   length, an illegal declared length, and an extent the buffer cannot supply.
8. **Control character means Unicode general category Cc**: U+0000–U+001F and
   U+007F–U+009F. That is the only defined meaning of the phrase in
   ARCH-SAVE-005, so the bounds are a citation, not a set someone chose.
   `is_control_scalar()` is public and tested at all six boundaries, including
   U+00A0, which is *not* a control character and which a naive `< 0xA0` test
   would reject.

## Why

The three things that could be undone by accident here are the count field, the
section-end bound and the canonical/payload split, and each of them looks like
redundancy to a reader who has only seen the two fixed sections.

The count field looks redundant because `ROW_COUNT` is a compile-time constant:
if it is always 512, why write it? Because the *file* is not the code. A file
written by a build whose capacity differed, or a file whose first four bytes
were corrupted, is exactly the case the field exists to catch, and without it
the only symptom is a decode that ends early or late and blames a name.

The section-end bound looks redundant because `save_codec.gd`'s reader already
refuses to walk off the buffer. It is not redundant, because the buffer is the
whole save file. SAVE-R09-004 forbids gaps, so section 15's 32 digest bytes sit
immediately after section 14's last name, and a length prefix that overruns by
fewer than 32 bytes reads them as UTF-8 and usually succeeds. The test for this
builds the section plus 64 plausible trailing bytes and confirms the refusal.

The canonical/payload split looks redundant because for section 10 the two are
byte-identical. They are identical there because section 10 has no framing at
all. Section 14 does, and framing is not state. Keeping this a function rather
than a comment is what makes the difference testable, and the test asserts the
two differ by exactly the four prefix bytes rather than asserting they are equal.

`apply()` follows ADR 0059 allocate-before-consume: the record is validated, the
store's occupancy is checked against it, the store's own current names are
captured, and only then is the first `set_name()` issued. The test that proves
this uses a record whose slot 0 is valid and whose slot 200 is not, so a
commit-as-you-go implementation would already have overwritten slot 0 by the
time it refused, and compares a store image built from `residents.gd`'s **own**
public readers — not from this codec's capture, which would make the comparison
vacuous if capture were the broken thing.

## Consequences

- **The next twelve variable-length sections copy this shape**: explicit count,
  `u32` UTF-8 byte prefixes, decode bounded by the descriptor length, exact
  consumption, validate-then-commit, a public `extent_refusal()`, and a
  `canonical_bytes_of()` that is a function of the record rather than an alias
  for the payload.
- **Column-major is satisfied trivially here and must not be read as
  precedent.** SAVE-LAYOUT-R01 rules that packed stores are column-major: field
  order outer, ascending slot inner. Section 14 has exactly one member, so
  column-major and record-major produce identical bytes and no choice is being
  made. A later section with two variable-length columns owes a full pass of
  column A over all 512 slots before column B begins, and this file says so in
  its header so that it cannot be cited the other way.
- **Section 14 must be applied after section 4.** `residents.gd::set_name()`
  derives `_named` from the key's emptiness, so section 14 applied last is what
  makes the two columns agree. ARCH-SAVE-002 orders section *IDs*; it states no
  intra-load apply order, and no load orchestrator exists to hold one.
- Byte arithmetic, fixed: all-empty section = `4 + 512*4` = **2052 bytes**;
  starter settlement = 2052 + 12 = **2064**; theoretical maximum = `2052 +
  512*128` = **67588**, which is under SAVE-R09-002's 131072-byte arena limit,
  enforced independently anyway because the two caps are two rules.

## Not built, and not pretended

- **BLOCKER N1 — section 14 has no registered owner-block framing.**
  SAVE-LAYOUT-R01 defines the `owner_key / owner_schema_version / primary_count
  / payload_byte_length` store wrapper for sections 3, 4 and 5 **only**, and
  says in terms that "sections 6/7/8/9/14 still require registered owner schemas
  and exact bounded framing". The wrapper is not applied here: doing so would
  require an `owner_key` spelling and an `owner_schema_version` that no ruling
  has issued, and a wrong guess at either is a silently incompatible fixture.
  If the registry later extends the wrapper to section 14, the payload below
  gains a prefix and the section version increments. What is implemented is the
  single-column body the wrapper would wrap unchanged.
- **BLOCKER N2 — SAVE-R09-002's "a live resident cannot load an empty name"
  cannot be read literally against GDD REQ-SET-041.** Taken literally it refuses
  every anonymous resident, which is most of the settlement. The reading applied
  is that the sentence governs a row the owning schema has flagged **named**:
  `residents.gd` carries `_named` beside `_name_key`, so `_named == 1` with an
  empty key is an inconsistent store and `capture_into()` refuses it, while
  `_named == 0` with an empty key is the registry's own declared unused value.
  This needs confirming by the ruling's author; it is a reading, not a quotation.
- **BLOCKER N3 — `residents.gd::set_name()` enforces none of ARCH-SAVE-005's
  name rules.** It stores any `StringName` and derives `_named` from emptiness,
  so a live store can hold a 40-character name with control characters that this
  codec must refuse to write. `encode_store()` refuses rather than truncating,
  which is correct at this layer, but the validation belongs at the setter too.
  `residents.gd` was read-only for this task and was not changed.
- **BLOCKER N4 — no load orchestrator exists**, so nothing enforces the
  section-4-then-section-14 apply order described above. `apply()` documents its
  precondition and reads occupancy from the live store; it cannot check that
  section 4 has already run.
- No section version number is written. `schema_version` lives in the 64-byte
  descriptor, which `save_header.gd` carries opaquely, and this module names no
  version — exactly as `save_section_rng.gd` does not.
- The section CRC-32 and the body SHA-256 are `save_header.gd`'s. This module
  produces the payload those protect and computes neither.
- `docs/systems_architecture.md` §2.2 budgets `name_key` as an **I32 column** —
  an intern id — while `residents.gd` implements it as a `PackedStringArray`.
  That divergence predates this work, is not this file's to resolve, and is
  reported to the integration owner with the byte arithmetic rather than papered
  over here.

## Source

- [SAVE-R09-001–005](../rulings/2026-09-11_save_codec_contract.md) — u32 UTF-8
  prefixes, the 128-byte name cap, the 131072-byte arena limit, the pinned byte
  fixtures, gapless layout, and the `RWL-STATE-1` canonical field-record grammar.
- [SAVE-LAYOUT-R01](../rulings/2026-09-12_clock_restore_and_layout_followup.md) —
  column-major packed stores, canonical unused values, and the explicit statement
  that section 14's framing is still unregistered.
- `docs/game_gdd.md` REQ-SET-040–042 and §5.1 — trigger-based naming, anonymous
  residents in full persistent state, the 2–32-character alias, and "ID 1 named
  Warden Rowan".
- `docs/systems_architecture.md` ARCH-SAVE-005 (2–32 Unicode characters, control
  characters rejected, illegal negative lengths, malformed UTF-8) and
  ARCH-HASH-001 (typed fields in schema order; exclusions that do not name
  `name_key`).
- `docs/persistence_state_registry.md` — "§14 NAME_POOL has exactly one member,
  `residents.gd`'s `_name_key`", category 1, 512 rows, "Empty string for an
  unnamed row".
- [Decision 0059](0059-allocate-before-consume-is-a-repository-wide-rule.md) and
  [decision 0063](0063-save-classification-naming-and-responsive-ui.md)
  — allocate before consume, and persistence versus digest membership as
  separate axes.
