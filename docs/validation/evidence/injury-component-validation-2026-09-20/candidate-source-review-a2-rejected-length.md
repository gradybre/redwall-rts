# Candidate source review — injury owner 6 (INJURY-S4-VALIDATE-R01 v1)

2026-09-20. Independent reading of `candidate-injury.gd` and `candidate-save-owner-injury.gd`
against the accepted contract and ADR 0177, with the original `injury.gd` as diff base.

**Scope.** Reading only. Nothing was executed, imported or applied, and no suite is claimed to
have passed. Production intake still waits on the PR167 merge; the hashes in
`candidate-reconstruction.json` must be compared against the actual intake. `parent-test-draft.gd`
has not been run. The recorded 47/0 and 12/0 logs characterize public producer history and the
original overflow bug only — neither is reachability or restore evidence.

## Static predicate

The eleven arguments match the owner-local table: five bytes, three i32, three i64, canonical
order. All eleven shapes are proved before any indexed read; the thirteen gates run in contract
order, each completing its own full 512-row scan, each with a distinct `REFUSE_COLUMN_*` code.
The three i64 columns admit the full nonnegative signed range — no recipe ceiling, no elapsed-time
ceiling, no float. The history gate binds an active kind and either latch but not the care-context
byte, and never forces a latched row to a current kind, so treated rows keep ordinal and latches.
Healthy bindings and stale references survive; both halves of the pair are compared, so two
generations on one global slot stay distinct; the slot is bounded against directory capacity and
never compared to the patient row. No packed scratch, sort or map is allocated.

The range helpers use bounded loops rather than the Needs duplicate-and-sort pattern, and the
shape check is a direct size comparison. Both divergences are correct here: the framed shape has
its own separate code path in the bridge.

## Runtime repair

The preflight's eligibility filter is character-for-character the sweep's own, runs after the
diagnostic reset and null-`Needs` refusal and before any increment, reports the first blocked row
ascending, and returns the existing overflow code with value 0. Dead, uninjured and inactive rows
stay skipped; the null path still leaves the diagnostic at -1; the successful advanced count is
unchanged. No new column, public mutator, health clock or second rate path.

## Bridge

Seven gates, correctly ordered: null, wrong owner, forwarded schema refusal, metadata and source
pins, forwarded owner shape refusal, eleven explicit typed accessors, raw unwrapped column code.
Only Injury, Schema, Section and SaveHeader are preloaded; every source pin is a constant chain
that instantiates no owner. Prefixes, empty success code and empty detail all match. No new const
array or publication table.

## Blockers

1. **False public-reachability claim.** The predicate's header block states the three i64 domains
   are full "because existing public writers reach it". That holds for care progress and the
   incident ordinal; it does **not** hold for `_untreated_ticks`, whose maximum is reached only by
   the labelled test-only injection. ADR 0177 explicitly forbids claiming public history reaches
   MAX. The sentence must be corrected before intake.
2. **Count-loop contract mismatch.** `_column_rescuer_duplicate_refusal()` uses
   `range(row + 1, RESIDENT_CAPACITY)` while its docstring claims it is "the same bounded nested
   ascending scan `_rescuer_patient_count()` already uses" and "allocating nothing". That helper
   uses the count-loop form. Either adopt the count-loop with an explicit skip, or drop the
   sameness and no-allocation assertion; as written the comment asserts a property of a different
   construct.

## Optional clarifications

- The sweep now asks `Needs` for liveness twice per eligible row per tick. Correct for atomicity,
  but a real per-tick cost worth stating.
- `FramedOwner.new()` leaves an invalid index at -1, so the test draft's -1 and 18 wrong-owner
  cases exercise one path; only 5 and 7 are distinct witnesses.
- Bridge per-field type comparison is unambiguous only because the key and field-count checks run
  first (an invalid ordinal yields type code 0, the u8 code). Safe as ordered, fragile if reordered.
- Raw column spellings are shared across owner namespaces; only the detail names owner 6. The raw
  shape code is unreachable through the bridge, reachable through the static predicate alone.

## Corrections to the earlier reading

The per-position snapshot is taken **after** deliberate fixture construction and **before** the
predicate: that is the correct nonmutation check, not a defect. The inactive gate's redundant
sub-clauses are not a gap — the required mutant is the whole-gate removal, which the context-byte
case kills. The 18-case/162-assertion metadata arithmetic re-derives as stated.

## Allocation and residual

The predicate and both scan helpers allocate no packed array. The only bridge-path allocations are
the ordinary cold-path refusal and accept wrappers — the existing pattern, not new packed pressure.
Native and wrapper overhead remains unmeasured. Saved Needs/resident agreement, Directory identity,
movement care context, same-file provenance, bulk capture/restore and derived counts stay out of
scope; the generator, source-capacity and preload-closure audits and exact-head CI remain required.
