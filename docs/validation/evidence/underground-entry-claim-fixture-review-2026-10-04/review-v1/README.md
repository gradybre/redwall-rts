# Independent entry-claim fixture migration review

Accepted test-only migration at
`d08b51779faf59038d138898c4ec74309d83d1bc9dfa891dad569e8d2ea01e33`.
All context pins are in `source-sha256.json`. No production source change or
permission relaxation is included. No high or medium finding remains.

The former fixture submitted a nonflat EntryClaimInput through `confirm_room`
and overrode its final proof. The actual ordinary Room final kernel now correctly
rejects that combination. The replacement builds a typed EntryPlan and calls real
`confirm_entry`, supplies the real `_entry_claim_input`, and removes the synthetic
`_room_claims_final_refusal` override. Only the established prospective geometric,
Terrain, Frontier, and Placement proof remains synthetic and is labeled so.

All previous purpose, history, capacity, sorted full-ref merge, input/candidate,
original-lease, foreign-budget, and Domain-observer negatives remain. The one
changed expectation now records that the complete EntryPlan rejects an oversized
request before claim preparation (`attempted_private_bytes == -1`), instead of
claiming the later Sites copy boundary ran. Direct cold-byte arithmetic assertions
remain. The ordinary flat control remains `confirm_room`. A new negative submits
the nonflat batch through that flat API and proves the actual complete state image
is unchanged on refusal.

The reviewer read the complete changed suite and inherited EntryBindings context,
verified all eight pins, and inspected the parent's four-suite `focused-1` raw
footers and restoration record. The exact counts, log hashes, and zero-warning
analysis are retained in `review.json`. The reviewer did not run Godot or write
in the integration worktree. This fixture proves claim/admission behavior only;
it does not qualify paid stairs or playable entry geometry.
