# Independent source review — SAVE-J2-R01 v2

Date: 2026-09-19. Acknowledged: **SAVE-J2-R01 v2**, Astra implementation after author
timeout (no worker source applied). Reviewer input set: the accepted contract, the full
`save_section_job_indexes.gd` source, both test files, the exact `implementation.patch`,
the SHA-pinned planner mark/pop excerpt (`577c9e97…`), `wire-vectors.json` and the
integration notes.

**Disposition: no blocking findings.** Four non-blocking recommendations and the
evidence limits are recorded below.

## 1. Independently recomputed field metadata (35 fields)

Extents were re-derived from the declared table assignment, not read back from the
module's totals:

| Group | Ordinals | Rows | Bytes/row | Bytes |
|---|---|---:|---:|---:|
| service | 0–10 (11 fields) | 8192 | 35 | 286720 |
| per-plot cycle | 11–12 | 4096 | 8 | 32768 |
| zone | 13–15 | 128 | 9 | 1152 |
| demand | 16–20 | 640 | 18 | 11520 |
| hive | 21–28 | 1024 | 30 | 30720 |
| **original subtotal** | 29 fields | | | **362880** |
| `_dirty_rows` (29) | i32 | 4096 | 4 | 16384 |
| `_dirty_count` (30) | i32 scalar | 1 | 4 | 4 |
| `_dirty_zone_rows` (31) | i32 | 128 | 4 | 512 |
| `_dirty_zone_count` (32) | i32 scalar | 1 | 4 | 4 |
| `_dirty_hive_rows` (33) | i32 | 1024 | 4 | 4096 |
| `_dirty_hive_count` (34) | i32 scalar | 1 | 4 | 4 |
| **appended subtotal** | 6 fields | | | **21004** |

- Canonical values 362880 + 21004 = **383884** — matches `CANONICAL_VALUE_BYTES`.
- Payload 383884 + 35 × 8 = **384164** — matches `PAYLOAD_BYTES`.
- Section 384164 + 39 = **384203** — matches `SECTION_BYTES` and `wire-vectors.json`.
- The original 29 ordinals, their types, widths and extents are byte-for-byte unchanged
  in the diff; the appended six are strictly appended, nothing renumbered.

## 2. Storage indices and type groups

Counting by type over ordinals 0–28 yields 19 i32 columns (indices 0–18), 8 u8, 2 i64.
The six appended i32 fields therefore take **19, 20, 21, 22, 23, 24**, exactly as
`FIELD_STORAGE` states and as the contract requires. Resulting group sizes 8 / 25 / 2
agree with `test_field_tables_agree_with_each_other`. `storage_index_of()` recomputes the
table, so drift is caught. `Record._init()` allocates each column at its own extent and
`clear()` fills the declared unused value (0 for all six new fields).

FIELD_STORAGE is exercised only through `FIELD_TYPES`-routed accessors; the extent-1
count columns are genuine i32 columns, not bare scalar words, and carry their own 8-byte
element-count prefix — matching the contract's explicit prohibition on new primary-count
interpretations.

## 3. Wire offsets — recomputed, then compared

`offset(29) = 39 + 29×8 + 362880 = 363151`. Successive offsets recomputed by adding
`8 + width×extent`:

| Ordinal | Count offset | Value offset |
|---:|---:|---:|
| 29 | 363151 | 363159 |
| 30 | 379543 | 379551 |
| 31 | 379555 | 379563 |
| 32 | 380075 | 380083 |
| 33 | 380087 | 380095 |
| 34 | 384191 | 384199 |

End of ordinal 34 = 384199 + 4 = **384203**, i.e. the payload tiles with no gaps and the
last column lands exactly on the section end. Every value above equals the sidecar and
the literal slice offsets in `test_appended_wire_offsets_are_literal_independent_pins`,
which pins the hex forms (`0010…`/`8000…`/`0004…` extents and the `0100…0001000000`
scalar pattern) as literals rather than through module arithmetic. This is a genuine
independent pin, not a self-referential one.

The 39-byte wrapper vector now encodes owner schema `02000000` and payload
`a4dc050000000000` = 384164; both are pinned literally.

## 4. Schema-2 dispatch and refusal precedence

`decode_section_with_schema_into()` calls `_preamble_refusal()` before `extent_refusal()`
and before any `Record` allocation. Verified order inside the preamble:

1. `offset < 0` → `SAVE_JOB_NEGATIVE_OFFSET`
2. fewer than 23 readable bytes → `SAVE_JOB_TRUNCATED`
3. store count, owner key length, owner key bytes
4. owner schema ≠ 2 → `SAVE_JOB_OWNER_SCHEMA_VERSION`
5. only then section schema ≠ 2 → `SAVE_JOB_SECTION_SCHEMA_VERSION`

This yields the contract's pair outcomes: (1,2) owner, (2,1) section, (1,1) owner, and
any non-2 value including 0 and future values follows the same order. The 23-byte bound
makes every `decode_u32`/`slice` in the preamble in-range. `decode_section_into()`
delegates with the compiled `SECTION_SCHEMA_VERSION` and makes no descriptor claim.

The old-schema test constructs a **real** 363151-byte schema-1 image (`slice(0, 363151)`
is exactly 39 + 29 prefixed columns) with owner schema patched to 1 and payload length to
363112; it receives an owner-schema refusal under both descriptor values, never a
truncation. This is the exact confusion the contract required to be ruled out, and the
implementation orders it correctly.

## 5. Original 29 validators retained

The diff touches `record_refusal()` only to convert the terminal `return
_hive_table_refusal(record)` into a guarded call followed by `_dirty_lists_refusal()`.
No other validator hunk appears in the diff: shape, the eight u8 domains, the six slot
domains, non-negative, crop, both quantity columns, the three clear-table predicates with
their deliberate exclusions (`_serviced_day`, blocker bytes, winter feed), tend/sow
operation split, sow-cycle-versus-cursor, cycle history, both reference-shape/binding
rules, zone reference and the two `REQUESTED`-elsewhere rules are all intact and still
run ahead of the queue checks.

## 6. Dirty-queue validation

Order inside `_dirty_lists_refusal` is farm → zone → hive, after shape/domain/
service/demand/hive, as specified. Per queue:

- **Negative** counts and negative prefix or tail entries are caught earlier by
  `_non_negative_refusal`, because all six new ordinals are in `NON_NEGATIVE_FIELDS` and
  `_domain_refusal` precedes the table passes. `SAVE_JOB_NEGATIVE_VALUE` therefore has
  precedence over `SAVE_JOB_DIRTY_COUNT`/`_INDEX`, matching the contract and the tests.
- **Count** `count > rows.size()` → `SAVE_JOB_DIRTY_COUNT`. `count == extent` is accepted,
  so the full-prefix case is legal; `count == 0` with a zero tail is legal. Count is the
  sole prefix boundary, so a single queued row 0 and an empty queue are distinguished by
  count alone — both valid, and both are exercised.
- **Index** `row >= rows.size()` → `SAVE_JOB_DIRTY_INDEX`, checked against each queue's own
  extent, never a shared cap.
- **Duplicate** via the seen array → `SAVE_JOB_DIRTY_DUPLICATE`, checked after index so an
  out-of-range row can never index the scratch.
- **Tail** any nonzero in `[count, extent)` → `SAVE_JOB_DIRTY_TAIL`, checked last.

No membership-bit column is serialized anywhere, and nothing in the codec marks owners.

## 7. Seen scratch

`seen.resize(maxi(OWNER_ROWS, maxi(ZONE_ROWS, HIVE_ROWS)))` = **4096 bytes**, allocated
once per validation call, `fill(0)` at the head of each queue iteration, reused for all
three. It is function-local, cold-path, not a member, not a dictionary, and cannot become
an unclassified permanent column. Index bound: every `seen[row]` write happens only after
`row < rows.size() ≤ 4096`, so the scratch is never over-indexed by the 128- or 1024-row
queues.

## 8. Live LIFO, idempotence and zero popped tails

Against the pinned excerpt (`577c9e97…`) and the diff, the only live scheduling change is
three added lines, one per queue: `_dirty_rows[_dirty_count] = 0`,
`_dirty_zone_rows[_dirty_zone_count] = 0`, `_dirty_hive_rows[_dirty_hive_count] = 0`,
each inserted after the decrement-and-read and before the membership clear.

- Read-then-zero-then-clear preserves the returned row exactly; no reordering.
- `mark_*_dirty` returns early when the membership bit is already set, so a duplicate mark
  neither appends nor moves an existing entry — idempotence with original position holds
  for all three queues.
- A remark after a pop pushes once at the new tail, because `_*_count` was decremented and
  the bit cleared.
- Only the formerly stale tail cell is affected, so order, counts, budgets, jobs,
  ordinary counters and lookup semantics are unchanged.
- Pop of row 0 zeroes the cell it read and still returns 0; count, not the cell value,
  distinguishes an empty queue.

## 9. Refusal atomicity, emission paths and input safety

`_decode_columns_into()` reads into a local `Record`, validates, and publishes with a
single `copy_from()` — so every refusal, including a full-length structurally valid body
with a bad queue, leaves the caller's Record byte-identical. Decoding never writes into
the input buffer (`slice()` copies). All three emission paths (`encode_section`,
`encode_payload`, `canonical_bytes_of`) call `record_refusal()` first and, on refusal,
`EncodeResult.refuse()` resets `bytes` to empty, so no stale successful buffer survives.
Validation never repairs the caller's Record. `capture_into`/`apply` remain explicit
`SAVE_JOB_STORE_NO_COLUMN_API` refusals, with `apply` reporting an invalid Record first.

## 10. Outcome regression and canonical separation

`test_order_and_membership_distinguish_real_future_outcomes` runs the real planner, marks
`[0,1]`, `[1,0]` and `[]`, ticks to 600 and asserts job IDs `[[4,3],[3,4],[3,0]]` while
asserting the 29-field projection collides (362880 bytes, all three equal) and the
35-field projection separates (383884 bytes, pairwise different). The projection sizes it
asserts are exactly the two totals recomputed in §1, so the old probe remains the failing
counterexample and the new fixture is the revised declared image over the same method.
Canonical separation using production compiled fields is additionally covered by
`test_canonical_bytes_exclude_the_framing` (now correctly subtracting `35 * 8`).

## 11. Non-blocking recommendations (bounded)

1. **Ordinal-adjacency coupling.** `_dirty_lists_refusal` obtains each count via
   `record.value_of(field + 1, 0)`. Correct today and pinned by tests, but it silently
   misreads if ordinals are ever reordered. Bounded fix: iterate an explicit pair table
   `[[FIELD_DIRTY_ROWS, FIELD_DIRTY_COUNT], [FIELD_DIRTY_ZONE_ROWS, FIELD_DIRTY_ZONE_COUNT],
   [FIELD_DIRTY_HIVE_ROWS, FIELD_DIRTY_HIVE_COUNT]]`.
2. **Refusal details omit the offending value.** The four new refusals name the column but
   not the index or the value, unlike every other refusal in the module. Bounded fix: add
   `index`/`row`/`count` to the four format strings.
3. **Registry scalar assertion is weak.** In `test_declared_ordinals_match_the_registry_artifact`,
   a scalar entry missing the `scalar` key falls through to
   `declared_capacity.contains("1")`, which many capacity strings satisfy incidentally.
   Bounded fix: assert `field.has("scalar")` for ordinals 30/32/34 before the branch.
4. **Lost rationale in the rewritten header.** The diff replaces ~200 lines of module
   documentation with an 8-line header. The removed text included the correct directory
   generation-namespace finding and the primary-count reasoning, which are still live and
   are not restated elsewhere in the module. Bounded fix: reinstate the namespace and
   primary-count paragraphs alongside the new schema-2 summary.

None of these changes behaviour; none blocks merge.

## 12. Pre-existing, out of scope

`_pop_dirty*` still assumes a caller has checked the count; popping an empty queue would
index `-1`. This is unchanged by the patch (the prior code read the same index) and is not
introduced by SAVE-J2-R01.

## 13. Evidence limits

- **Nothing was executed.** No test run, no build, no static check, no CI, no capture or
  apply, no file written or applied. All findings are by source reading and arithmetic.
- The canonical registry artifact, the capacity sidecar and the generated declaration
  table are not in this packet; the 610/602/553 totals and the 604/596/550 baseline are
  **unverified here** and remain Astra's to confirm against the complete artifact.
- The `[4,3]`/`[3,4]`/`[3,0]` outcomes, the 293-test/6431-assertion first-focus result and
  the repeat-focus run are reported, not reproduced. The stale `29 * 8` subtraction is
  corrected in the snapshot reviewed here; no other stale count was found in either test
  file.
- This review confirms a **structural codec and format repair only**. It makes no claim
  about full-world round trip, cross-owner reference validity, release-save completeness,
  hash equality, first playable, native art or Windows validation. BLOCKER J2 remains open
  and capture/apply remain refusals until the separate bulk-API packet.
