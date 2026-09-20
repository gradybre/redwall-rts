# 0173 — Validate Transform history and binding uniqueness

Date:2026-09-20. Status:Accepted. Contract:TRANSFORMS-S4-VALIDATE-R01v1.

Validate owner15's nine exact i32[87552] columns through a static owner predicate and a framed bridge. Check shapes, binding nonnegativity, uniqueness of positive bindings and exact zero poses for zero-bound rows, in globalgateorder. Pose values and yaw retain the full signedint32 domain; current/previous remain independent canonical history. Stale positive bindings survive Directory destruction and are not required to name a currentliveentity.

Uniqueness is local data, despite requiring temporary storage for an efficient scan. Duplicate/sort exactlyone87552element binding copy (350208bytes), never caller data. Framed3151872+scratch350208+three65536streamwindows=3698688logicalpackedbytes, belowexisting6417408oneownerbound; no newresidentallocation, secondworld or measurednativepeakclaim. This bound assumes the caller releases previousownerrecords under the streamingcontract.

The canonical order places bindingfirst; diagnostic state_bytes places itlast. Preserve both existingorders and remap explicit testfixtures. Do not introduce a mutable diagnostic, liveDirectory access or gameplaypathchange.

Correct the registry's suggestion that load may collapse canonical previousposes after digestverification. ARCH-HASH-001 hashes current/previous and excludes first-frameoverrides; ARCH-SAVE-004 verifies before andafterinstallation; movement_contracts specifies presentation-onlyoverride. Preserve canonical poses throughout; loadfirstframeprevious=current changespresentationonly.

TRANSFORMS-SAVED-IDENTITY separately owns savedcursor upperbound and samefileDirectoryassociation/provenance, including legitimatehistoricalstamps. Localuniqueness doesnotdetecteverycrossworldcontamination. BulkAPI/countrebuild and fullsavepublication remainincomplete. Approval follows sourceanalysis, actualpublichistoryprobe and twoindependentplanningreviews, dispositioned under transforms-validation-planning-2026-09-20.
