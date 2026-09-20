# Reservations feasibility disposition

The audit is useful but is not the contract. SAVE-RES-R01v1 resolves its eight
questions for independent review; no production implementation is released yet.

- B1/B3: target constructor J/L extents define the interpretation context, with
  actual target bounds checked by the owner. They are absent from the wire.
  Preserve the existing schema and state that limitation directly.
- B2: correct the registry's zero-quantity prose. Existing mutator and codec
  require positive occupied quantities; no new gameplay rule is introduced.
- B4: full coordinator must validate every Inventory lot, including one with no
  reservation chain. Existing audit skips such lots and cannot be the sole
  invariant proof. No Inventory mutations occur here.
- B5: separate adapter requires a supplied Inventory (null defaults refuse),
  checking both open and poisoned flags. Owner APIs remain unbound and require
  caller quiescence. Flags do not prove world association or attestation.
- B6: apply requires a supplied held clock barrier; it never reads a tick or
  sweeps expired leases. These are independent responsibilities.
- B7: deliberately retain stronger owner cross-row/runtime-extent validation
  after the unchanged codec's structural validation, with distinct codes.
- B8: validate live derived indexes safely and refuse corrupt source. Do not
  call the existing traversal audit on hostile arrays or refactor its API.

Corrections to other audit suggestions:

There are six section7 owners, not seven; Inventory and StockAge boundaries
already exist. Use a separate adapter, as requested, rather than editing the
large section codec. Keep two merge buffers and arithmetic scratch local, not
in caller input records that must remain unchanged on refusal. Build derived
outputs privately before publication, then transfer them. This permits complete
failure atomicity and simple source-index comparison at bounded cold-path cost.
Source minheap need only be valid over the free set; do not require its array
permutation to equal the ascending reconstruction. Ignore its unused tail.

The current _sum_list is unchecked for job totals. Cross-lot sums above i64 can
be admitted by public claim operations; do not silently expand this save change
to reject those sets. Track the arithmetic issue separately. Per-lot overflow
cannot satisfy the existing i64 Inventory invariant and is rejected. The new
validator uses local checked arithmetic without mutating owner math scratch.

Memory statements must include private derived outputs, not claim they are
merely the preexisting owner buffers. Record explicit phases rather than a
single process peak or an RSS qualification.
