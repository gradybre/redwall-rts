# 1080 — Source-bound underground profile catalog

Date: 2026-10-03
Status: implementation in progress; only the exact Residents identity prerequisite is reviewed and verified.

## Decision

Profile selection will use actual full Resident/Job identities and the current
Residents species, life stage and existing logical rig. It will not accept a cast name
or caller-proposed species as proof. The additive allocation-free
`spatial_profile_identity_into(ref, scratch)` requires exactly three integer outputs,
validates the Directory kind and both owner mirror fields, and writes only after all
checks pass. It deliberately refuses absent child/elder rig bindings, preserving the
existing catalog rather than substituting an adult body. The movement/contact owner
separately checks life and eligibility.

The forthcoming physical catalog remains immutable integer content, with a finite
per-selection box bound and streamed replacement. Source extraction, mathematical
continuous enclosure, runtime numerical enclosure, setting permissions and real
world contact are separate evidence obligations. Existing sampled captures cannot
be relabeled as clearance certificates. Exact level spacing and local offsets are
engineering content choices authorized by the approved levels-and-connections plan;
new grip/load permissions or economic recipes are not implied by geometry.

## Verified prerequisite

The independent root review accepted the two source hashes recorded under
`godot/data/underground/evidence/resident-identity-v1/`. The clean CI-style focused
Residents suite reports 98 tests, 2,019 assertions, zero failures, zero unexpected
diagnostics and zero leaks. The analyzer reports zero warnings in two files.
No persistent columns, memory schema or balance rules changed.

The rest of decision1080 is still being implemented. This record does not mark UG08,
production profiles or the five connector families complete.
