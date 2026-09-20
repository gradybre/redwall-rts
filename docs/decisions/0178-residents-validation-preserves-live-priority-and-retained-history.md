# 0178 — Residents validation preserves live refusal priority and retained history

Date: 2026-09-20. Status: Accepted for bounded implementation.

RESIDENTS-S4-VALIDATE-R01v1 adds a pure static Columns predicate and owner12 framed bridge, retaining the existing19-column/version2 wire layout and ADR0132 bulk API. A shared prefix validates shape, byte domains, skills, reference/equipment shapes, inactive rows and presentcount. Shared scalar helpers validate present species range and arrival. The saved predicate uses only explicit columns; the existing live restore keeps catalog-error first and its per-row species,size,arrival,Directory order, avoiding accidental diagnostic changes from hoisting all savedscalar checks ahead of live checks.

Original probes recorded39assertions/0failures: publicnegativearrival was captured and rejected by present-row restore; after departure the negative tick survived legally. The setter now refuses negative ticks with INVALID_ARRIVAL_TICK after NOT_PRESENT and before any write. Existing COLUMN_ARRIVAL_TICK remains the column diagnostic. Inactive signedarrival/species history is preserved without normalization. Genericreference shapes retain the fullnonnegativei32slot/positivegeneration domain; targetidentity remains savedbindings.

Both nullcapture and nullrestore originally returnedfalse/COLUMN_SHAPE but emitted a Nil.skill_xp SCRIPT ERROR. A shared shape nullguard removes that error. Exit0 alone did not qualify the originalcalls. Mutation evidence distinguishes47assertion-basedsites from the dedicatedknown-runtime-error oracle; eightmetadata bypasses are additional. Exhaustive original skill-address probe24578/0 took3.838seconds and informs boundedtests, notreleaseperformance.

The public skill-level method delegates to one static boundedintegercurve helper. Existing sorted-copy XPvalidation remains and is budgeted:102912caller +102912transient Columns defaults +49152scratch =254976logicalpackedbytes, below6417408stream allowance. Native/wrapper overhead remainsunmeasured. No liveResidents/catalog/Directoryconstructor is used by bridge, and no packedstate/schema allocation is added.

Localacceptance defers verifiedcatalogsize, savedDirectoryselfidentity/uniqueness, home/bedtargets, Needs/deathbarrier, section14names, equipmentownership and commonfileprovenance to RESIDENTS-SAVED-BINDINGS. Current256present cap is retained with512storage; lifecycle/cap reconciliation is not redesigned here. Fullfile restore/publication remains separately gated.

Evidence and review dispositions: docs/validation/evidence/residents-validation-planning-2026-09-20/. Contract: docs/planning/residents_component_validation_contract.md.
