# ResourceNodes owner 13 — independent final contract review

2026-09-20. Read-only review of the draft 1 contract before production author dispatch. Nothing
was run, imported or edited. Disposition: **approve with two corrections and one verification**.

## Re-derived geometry and metadata

Owner 13 `resource_nodes`, version 1, primary 4096, zero children, field begin 255, count 10 —
all confirmed against the compiled tables, and distinct from the section 1 `resource_nodes`
block at version 2. Types in ordinal order u8, i32, i64, i64, i32, i32, u8, i32, i32, i32, each
column exactly 4096. Values `2*4096 + 6*4096*4 + 2*4096*8 = 172032`; payload
`4 + 10*8 + 172032 = 172116`; block `24 + 14 + 172116 = 172154`; offset 9550427, so owner 14
begins at 9722581. All six figures agree.

Metadata fault 5 re-derived: Schedule (owner 14) declares six fields beginning at global 265
with `_present` u8[512] first, so moving that descriptor transfers `512 + 8 = 520` bytes — owner
13 payload 172636 and block 172674, owner 14 payload 17452, owner 14 offset 9723101. Because all
ten pinned fields stay first, the field-count bypass is isolated exactly as claimed. Fault 7's
`4096*(4-1) = 12288` delta and fault 8's single-element delta also re-derive.

Bounds are right and not interchangeable: refs are the **global** Directory capacity 352418 with
generation > 0, tiles the 16384-tile grid, typed rows 4096. Capacity is full positive i64 to
INT64_MAX with no float conversion and no `planted_day + regrow_days` sum-fit — the public probe
shows that sum answered by an explicit runtime OVERFLOW, which is a reachable valid state, not
malformed data. Retained inactive resource_id/capacity/regrow/planted_day with mandatory
quantity 0, exhausted 0, tile -1 and ref (-1,0) matches `clear()` and `destroy()` exactly.
Global gate priority (each gate scans the whole image before the next) is stated unambiguously.

## Mutant assessment — one required clause is redundant

Twenty-nine of the thirty required mutants have genuine acceptance witnesses. **Clause 6
(`COLUMN_CAPACITY`, all capacities nonnegative) does not.** On a present row, clause 9 already
demands capacity > 0; on an inactive row, clause 14 forces quantity 0 and clause 9's
`quantity <= capacity` then forces capacity >= 0. No image exists that clause 6 alone rejects.
Its omission is still detectable, but only as a **code-identity** witness: an inactive row with
capacity -1 must refuse `COLUMN_CAPACITY`, and the mutant returns `COLUMN_STOCK`. That is a real
exact-code kill and no fabrication, but the contract must say so rather than imply acceptance.
Correction 1: record clause 6's witness class explicitly, keep the clause (it preserves the
intended code for a negative capacity), and do not let any suite assert that the mutant accepts.

Two further clauses are only witnessable once their comparison form is pinned. Correction 2: fix
in the contract that later gates test `present == 1` (so a present byte of 2 is judged as an
inactive row and clause 2's omission has an acceptance witness), and that clause 11 compares
`(exhausted == 1) == (quantity == 0)` (so exhausted 2 on a stocked present row passes the
remaining gates and clause 3's omission has an acceptance witness). Without these, both witnesses
collapse into other gates. Clause 8's witness must sit on an **inactive** row, since clause 10
masks a present-row negative planting date; clause 5's must sit on a **present** row, since
clause 14 masks an inactive negative quantity. Both are already flagged in the draft.

## Feasibility and source

The main `resource_nodes.gd` header is **already correct** — it states the settled compiled
`ItemDefinition` domain and cites decision 0052. Only `resource_id_of()`'s "unstated domain"
docstring and the old suite's domain comments are stale; the feasibility disposition supersedes
the raw review's contrary wording. Scalar-domain-only scope with a mandatory same-file
RESOURCE-NODES-SAVED-BINDINGS follow-up (section 1 inverse both directions, Directory
kind/typed-row/ref, unique placement, verified catalog membership) is the correct split; no local
duplicate or scratch is warranted, and local acceptance authorizes no publication.

The proposed preload closure is 20 nodes with only self-edges reported — existing supported
self-preloads, not new cycles; `resource_nodes.gd` reaches only int_math and entity_directory, so
no catalog or live store is constructed. Constant chains pin without instantiation.

One verification is required before author dispatch, and it is technical, not permissional: owner
13 is the first bridge needing **two i64 typed accessors**, and the Work precedent exercises only
`i32_column`/`u8_column`. Confirm `Section.FramedOwner` already exposes an i64 accessor; if it
does not, the ten-accessor bridge cannot be authored as written and the contract needs revision
rather than a new API invented inside this slice.

The public probe stands as 24 assertions, 0 failures, clean shutdown, with no private-column
capture claimed. Metadata arithmetic (18 cases / 162 assertions) must still be re-derived by the
author. With corrections 1 and 2 applied and the i64 accessor confirmed, the contract is ready to
freeze.
