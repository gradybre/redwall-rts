# Candidate source review — injury owner 6 validation (INJURY-S4-VALIDATE-R01 v1)

2026-09-20. Independent source-only review of the reconstructed review artifacts
`candidate-injury.gd` and `candidate-save-owner-injury.gd` against the accepted contract and
ADR 0177, with the original `godot/scripts/core/injury.gd` as the diff base.

**Scope and status.** Reading only. Nothing here was executed, applied or imported. Production
intake still waits on the PR167 merge; the candidate hashes in `candidate-reconstruction.json`
must be compared against the actual intake before any of this transfers. No runtime claim is
made, and no statement below is evidence that any suite passed. The `parent-test-draft.gd`
reviewed here has not been run; the recorded 47/0 and 12/0 logs characterize public producer
history and the original overflow bug respectively, and neither is reachability or restore
evidence.

## Static predicate — accepted as written

The eleven arguments match the owner-local table exactly: five bytes, three i32, three i64, in
canonical order. All eleven shapes are proved before any indexed read, and the thirteen gates
run in contract order with each completing its own full 512-row scan — shape, flags, kind,
severity, rescuer pair, the three i64 floors, kind/severity equivalence, the no-injury reset,
positive incident history, the inactive rule, then exact pair uniqueness. Each of the thirteen
codes is a distinct `REFUSE_COLUMN_*` constant.

The saved domains are right. Untreated ticks, care progress and the incident ordinal admit the
full nonnegative signed-int64 range with no recipe ceiling, no elapsed-time ceiling and no
float. The history gate constrains an active kind and either episode latch but deliberately not
the care-context byte, and never forces a latched row to a current kind, so a treated row
retaining its ordinal and both latches is accepted. A healthy present row may bind a rescuer;
stale references survive; two different generations on one global directory slot stay distinct
because both halves are compared. The rescuer slot is bounded against the directory capacity and
is never compared to the patient's own typed row.

The i32 and i64 range helpers use plain bounded loops rather than the duplicate-and-sort pattern
the Needs bulk validator uses. That is the correct divergence here: it honours the no-extra-
packed-scratch requirement, and the uniqueness scan is likewise a nested bounded integer-count
scan with no temporary array, sort or map.

## Runtime repair — accepted as written

The preflight's eligibility filter is character-for-character the sweep's own — present,
carrying an aggregate injury, living by the Needs store's judgement — so the preflight cannot
refuse a sweep that would not have touched the row. It runs after the diagnostic reset and the
null-collaborator refusal and before any increment, records the first blocked row in ascending
order, and returns the existing overflow code with value 0. Dead, uninjured and inactive rows
remain skipped; the null path still leaves the diagnostic at -1; the successful advanced-row
count is unchanged. No new column, public mutator, health clock or second rate path appears.

**Cost to record, not to assert away:** the sweep now asks the Needs store for liveness twice
per eligible row per tick. That is the price of whole-sweep atomicity and is permitted, but it
is a real per-tick change and should be stated rather than absorbed.

## Bridge — accepted, with two notes

The seven gates are present and correctly ordered: null, wrong owner, unchanged forwarded schema
refusal, metadata and source pins, unchanged forwarded owner shape refusal, the eleven explicit
typed accessors, then the raw unwrapped column code. Only Injury, Schema, Section and SaveHeader
are preloaded; all source pins are read as constant chains and instantiate no owner. The metadata
prefix and the column detail prefix match the contract spellings, and success carries an empty
code and empty detail. No new const array or publication table is introduced.

1. The per-field type comparison is only unambiguous because the key check and the pinned field
   count run first: an invalid ordinal yields type code 0, which is the u8 code. The current
   ordering makes this safe; a future edit that reorders the three per-field checks would not.
2. The raw column spellings are shared with other owners' column namespaces. A caller switching
   on the code alone cannot tell owner 6's shape refusal from another owner's. Only the detail
   disambiguates. Separately, the raw shape code is unreachable through the bridge, because the
   framing shape gate already guarantees exact extents; it is reachable only through the static
   predicate.

## Test draft — real weaknesses found

- **Inactive sub-clause witnesses are overstated.** The draft comments claim each non-default
  column is witnessed with only the relationships it needs. That is false for severity, untreated
  ticks and care progress, which are masked inside the inactive gate by its own kind clause, and
  for the two latch bytes, which are masked by its ordinal clause. Those standalone cases cannot
  be constructed, because the kind/severity, no-injury and history gates catch them first. This
  is not a contract breach — the required mutant set treats the inactive gate as one clause, and
  the whole-gate removal is killed by the context-byte case — but the comment must be corrected
  and the redundancy recorded.
- **Two of the four wrong-owner cases are illusory.** The frame constructor leaves an invalid
  index as -1, so the -1 and 18 cases exercise the same path. Only owners 5 and 7 are distinct
  witnesses. Constructing owners 5 and 7 also allocates their full column sets.
- **A comparison copy is taken after mutation** in the 512-position loop, so the accompanying
  message overstates it: it proves the predicate does not mutate caller buffers, not that the
  fixture survived. Keep the check, fix the message.
- The public diagnostic remap is correct. The eleven emitted values are row, kind, severity,
  ticks, care, ordinal, rescuer slot and generation, then the three flag bytes; the draft's
  remap table restores canonical order and seeds absent rows with source-owned defaults rather
  than raw zeros, and the raw-zero frame is separately asserted to refuse on the rescuer pair.
  Explicit packed writeback is used throughout, and the single injected counter column is
  labelled test-only with no claim of public reachability or restore.
- The metadata harness arithmetic re-derives as 18 cases at 9 assertions each, 162 total: eight
  schema faults, eight gate bypasses, one positive control and one schema-first forwarding case.
  The eight counterfactual rebalances each preserve the field total, the child extent total, the
  descriptor row total and the compiled section length, so they reach the metadata gate with a
  self-consistent schema.

## Allocation

The predicate and both scan helpers allocate no packed array and no scratch of any kind. The only
per-call allocations on the bridge path are the ordinary cold-path refusal and accept wrappers,
which are the existing pattern and not new packed pressure. Native and wrapper overhead remains
unmeasured.

## Residual

Everything the accepted contract already lists as out of scope stays out of scope: saved Needs
and resident presence, health and injury-state agreement, Directory patient and rescuer identity,
movement care context, same-file provenance, bulk capture and restore, and derived counts. The
independent generator and source-capacity audit, the preload closure audit and the exact-head CI
run remain required and are not satisfied by this reading.
