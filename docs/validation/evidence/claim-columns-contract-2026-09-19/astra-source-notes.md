# Fishing/Forage claim columns — source audit notes, not accepted contract

Section7 stores only7Fishing claim arrays (1u8+6i32, fixed512,25R) and
11Forage claim arrays (1u8+7i32+3i64, fixed8192,53R). Other fields in the same
modules belong to sections1/4/5 and must not be rewritten by claim-only restore.
Rows are expedition/job TYPED ROW respectively; stored habitat/job/designation/
basin refs are DIRECTORY refs. Fishing expedition slot is rebuilt from typedrow
reverseowner + savedgeneration, not an omitted packed slot field.

Existing per-row restore depends on live Jobs/Directory/zone/habitat state, changes
scratch, and Forage refreshes saved creationtick/persistentID from Jobs. Do not
replay it as exactbulkload. Fishing aggregate rebuild changes canonical section4
_habitat_effort_used; Forage rebuild zeroes and changes canonical section4 zone
quota_reserved totals and overwrites canonical claim order keys. Neither can be
called by a pure claim-only boundary. Fishing validate_effort_aggregates is not
pure: it writes scratch and may recompute claimcount.

Likely owner boundary: exact fixed-shape canonical claim arrays; private payload
validation/count, sourcecount compare, restorecountpublication; preserve every
other module field, including allothersections and scratch/borrowed identities.
Stale generations structurally preserved, world association/liveness/rowmapping
and checked aggregate reconciliation are later coordinator obligations. Need
explicit structuraldomain ruling, not silent hotquery safety assumptions.

Codec permits Forage active remaining0 and all3i64nonnegative up toI64MAX; real
claim and legacyrestore require1..1180000. Query _stock_reserved_milli and existing
aggregate rebuild have unchecked additions. Publiclegal max8192*1180000 fits,
but a broad codec-only payload can overflow. Fishing positive claimslotcount
i32MAX may overflow its packed i32 aggregate before capacitycomparison on
forgeddata. This is a loader/reconciliation hazard; audit must distinguish it
from the prior real-public-API Reservations overflow witness. Do not invent a
new publicbug without witness, or silently clamp structural input.

Forage createdtick/persistentID are canonical per registry despite older source
comments calling them caches. Preserveexact and record discrepancy; do not
recompute order keys in new ownerrestore. Claimcountcategory2 derived; Fishing
registry currently bundles itscountwithcategory3scratch, which needs correction.
No fullworld/save-section acceptance follows from two separate block adapters.
