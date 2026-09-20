# Parent review of owner-a2 candidate before production intake

237actual patchlines, rawgitapply--recount--check passed; frozen inputhashes andtarget/mode allowlist verified, workerstopped. Candidate reconstructed without executing or applying to product. Pending PR168merge.

Required clarification: candidate reference-helper docstring says no home/bed liveness check exists anywhere in Residents and no building/furniture store exists. This is false: existing home_is_live/bed_is_live delegate to _is_live_directory_ref. Only the COLUMN validation path defers home/bed resolution and its live-row walker resolves SELF. Replace the comment with that scoped distinction, without changing behavior or deleting existing readers.

Keep the newly factored static curve helper private by naming it _skill_level_curve; public instance skill_level_for_xp remains the existing entry point. This is a naming adjustment, not a new policy or changed curve.

Clarify predicate comment: existing live restore checks its own compiled size and Directory self identity; remaining saved cross-owner obligations belong to RESIDENTS-SAVED-BINDINGS. Do not imply live restore already certifies all saved cross-owner agreement.

Apply these after rawcandidate identity is verified on actualintake. Preserve originalcandidate and patch; final independent review must examine repaired actualsource. No implementation defect beyond these sourceclarity/API-surface corrections found in parentread; runtime stillpending.
