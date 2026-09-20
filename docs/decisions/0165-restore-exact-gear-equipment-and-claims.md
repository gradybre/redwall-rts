# 0165 — Restore exact Gear equipment and claims

Date:2026-09-19 · Status:Implemented; independent review resolved; exact-head CI pending

SAVE-GEAR-R01v2 preserves all12canonical arrays and bare row identities, including
equipped flags lost by legacy row replay. Validate complete payloads privately;
capture rejects malformed source heap/count/cache state. Restore installs exact
independent columns, ascending heap, three derived counts and five catalog IDs
only after all checks. Preserve seed/wear scratch and borrowed collaborators.
Bind equipment before restoring equipped rows; do not mutate collaborators here.

The owner deliberately rejects nonexact null pairs and claim slots>=8192 that the
existing codec admits. It never clamps/remaps them. This mirrors the current live
Gear API; separate job-generation/domain integration remains a coordinator gate.
Structural item/manufacture/cap validation does not claim catalog/world validity.

A separate total-shape single-block adapter requires a held clock barrier on
apply and the supplied nonbusy Inventory, rejecting foreign Inventory when Gear
is already bound. Full-world identity, mirrors, catalog provenance, save rollback
and playable settlement remain unclosed. Independent contract review corrections
and acceptance tests are in the version2 contract and evidence disposition.
