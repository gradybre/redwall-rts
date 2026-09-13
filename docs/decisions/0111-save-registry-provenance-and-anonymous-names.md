# 0111 — Save registry, provenance and anonymous names
Date: 2026-09-12 · Status: Accepted for implementation; release validation incomplete

## Decision
Adopt [REG-R01, PROV-R01, NAME-R02 and PLAN-CMD-R01](../rulings/2026-09-12_save_registry_answers.md).
Publish exact logical owner/field declarations for executor197472b, six protected
provenance values, the separate WORLD allocator block and the NAME_POOL wrapper.
Confirm live anonymous empty names; use one owner validator.

## Why
Codec grammar without a registry leaves independent lanes inventing incompatible
keys. The allocator also reaches2147483648 after its final signed identity, so
its saved cursor must be u32. The former universal empty-name prohibition
contradicted REQ-SET-041. A mutable movement profile revision was assigned to §2
but absent from its opaque catalog-only framing.

## Consequences
Rules/catalog identities and affected versions change; development incompatibility
is explicitly refused until migrated. Existing runtime branches remain intact.
Source reconciliation, value adapters, complete bodies and continuation parity
remain required. No movement fit, paid asset generation, release qualification
or Brendan visual approval is claimed. This planning checkout uses0111; reconcile
decision numbering if a concurrent implementation branch has allocated it too.

## Source
GDD §4.3, §5.1, §5.7, REQ-SET-040/041; SAVE-R09; SAVE-LAYOUT-R01;
RESTORE-R01; executor registry request and code at197472b; DEC-040/ECON.
New numbering, framing and payload choices are authored rulings, not measurements.
