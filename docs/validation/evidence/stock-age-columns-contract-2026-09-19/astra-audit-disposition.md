# StockAge feasibility disposition

The read-only audit is useful, with the following corrections before contract authoring.

- Preserve latch domain>=NO_HOUR_RUN (-1), matching existing section7 structural validation. Do not adopt the proposed stronger hour alignment gate in this packet. A narrower adapter would change admitted restore values even if bytes were unchanged; the audit's assertion that it changes no accepted stream is incorrect. Runtime probe corrected my initial calendar inference: tick0 is explicitly excluded by the shared boundary predicate even though the modular expression alone is aligned. The existing wire still admits0; retain that structural compatibility and record stronger runtime-validity as coordinator work. Full clock/latch/fault consistency remains coordinator work.
- Preserve stale declarations and exact dense order. Being outside a small Inventory's runtime capacity is not proven naturally reachable; accept structurally and leave world-capacity legality to coordinator without claiming every such row is naturally produced.
- Require -1unused tails at the owner boundary because that is the owner's existing invariant. Wire omits the unused tail, so junk tails do not necessarily re-encode differently as the audit claimed.
- Existing section7 owner_refusal is not shape-total. Add local total shape gate in the separate StockAge adapter, without expanding this packet into all6owner codec repairs.
- Use separate _last_column_refusal; canonical_detail()->String returns its string code, matching Inventory's return type. Leave existing _last_refusal unchanged.
- A fresh bound owner may capture/restore; unbound/busy owner refuses. Tests use independent reflection of all value fields/scratch to prove atomicity even when an invalid source cannot capture.
- Four duplicate() calls, not an assumed COW property, guarantee owner/output independence. More buffers coexist than the audit's2.03MB estimate; document per-object payload and actual phase allocations, no false peak/RSS claim.
- Sorting counterexample must be nonascending: declareA,B,C then withdrawA =>[C,B], not withdrawB =>[A,C]. Actual waste expiry and next-lot allocation must distinguish the two orders.
- Use a separate adapter accepting one OwnerRecord, with local Columns scratch owned by the adapter. Avoid a caller scratch parameter whose partial mutation would weaken refusal atomicity. No full6owner Record allocation.

Source schema evidence: StockAge owner1, section7schema3. No canonical field/schema/registry-version change. Pending stock-integrity retry/hold policy remains a full-save prerequisite.
