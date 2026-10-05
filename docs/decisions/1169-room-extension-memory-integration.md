# 1169 — Replay current Room allocation lifetimes before historical accounting

Date: 2026-10-05 · Status: independently accepted logical accounting; native qualification open

## Decision

The joint memory pack now replays the reviewed 1161 frontier publication,
1163 actual Room-owner composition, 1165 itinerary and 1166 ground Catalog
censuses against current source. Verify the immutable producer, witness and
predecessor closure before executing any producer. Check supplied module text
and identity rather than trusting a caller's cached hash or parsed constants.
The build needs neither Git nor subprocess access to reconstruct old inputs.

Only after those current lifetimes agree may the pack project the unchanged
1152/1156/1158/1160 contributions from their exact archived source. This is a
decomposition of accounting, never a substitution of historical runtime code.
Keep the old and current provenance explicit in the generated pack.

The Room constructor proof checks unchanged Locations constructor functions,
their local call closure, nested classes and initializers. Provider construction
likewise remains unchanged outside the separately counted itinerary path.
Sixteen retained Session bytes plus eight constructor Scope bytes are charged
once inside the existing retirement reservation. Existing original owners are
borrowed; no duplicate Buildings definitions or owner tuple is admitted.

## Bounds and review correction

The frontier publisher uses 8,050 logical bytes inside its 8,192-byte cold
reservation. UI retirement controls plus helper allowance use 6,019 + 1,903
= 7,922 bytes; Room construction uses 3,954 + 3,539 = 7,493 bytes within that
same sequential reservation. The ground Catalog fixed contribution is 1,468
within its original 2,048-byte reserve. The 1165 local helper closure is
432/512 bytes; Provider and Frontier remain within 986/1,024 and 1,966/2,048.

Independent review found that Movement was absent from the new current-source
closure even though Catalog loading calls its `profile_speed_into`. A mutation
adding a 4,096-byte temporary there initially escaped this adapter. The corrected
manifest pins the complete Movement source, and a reached-method mutation test
requires rejection before any producer executes. The original finding and the
corrected acceptance are retained, rather than relabeling the first review.

The resulting joint logical allocation remains **99,999,806 bytes**, with
194 bytes of headroom. This is neither measured Godot allocation nor proof of
the 256-resident performance requirement. Every runtime qualification flag stays
false, and the 100 MB limit and existing reservations remain unchanged.

## Evidence

`docs/validation/evidence/underground-room-memory-integration-2026-10-05/`
contains the immutable 51-module source manifest, 29 witness pins, twelve
6da6deb9 predecessor sources and five 8373d146 publisher predecessors. The
CI-invoked memory test module includes the new adversarial tests. Independent
review and the original composition source-drift failure are recorded separately
under `underground-room-integration-check-2026-10-05/`.

The next owner-composition or runtime change must renew its own current-source
closure and lifetime evidence. It cannot silently inherit this acceptance.
