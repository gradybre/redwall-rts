# 0163 — Restore reservation row identities and semantic indexes

Date:2026-09-19 · Status:Merged PR154 at1798854; independent review resolved; CI4752tests/186571assertions/0failures

SAVE-RES-R01v2 preserves the existing eight canonical arrays without compacting
row indices. Derived minheap and intrusive lists are reconstructed from the
free set and semantic keys using bounded packed merge sorting. Capture refuses
malformed source indexes instead of silently repairing them.

The target's constructor extents supply job/lot bounds absent from the wire.
Keep schema1/section7schema3 unchanged; admit the structural field domain and
add owner-level cross-row validation. A separate single-block adapter requires
a held clock barrier on apply and a supplied nonbusy Inventory on both paths,
without binding or changing it. Full-world identity, every-lot reserved totals
and rollback remain coordinator obligations.

Correct the registry's zero-quantity/chain-order prose to match existing runtime
rules. Preserve expired leases and opaque signed purposes. A public probe found
unchecked overflow in job_reserved_total_milli across different lots; record it
as separate runtime arithmetic work rather than silently narrowing save input.
