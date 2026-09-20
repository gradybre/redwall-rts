# Starter refuge preparation evidence

`layout-reference.json` is a required headless test fixture, frozen from the authored GDD layout. `godot/test/test_starter_structures.gd` loads it through `res://../docs/validation/evidence/starter-integration-planning-2026-09-20/layout-reference.json` and checks its diagram, furnishings, edges, exit and walk tiles against independent literals. Preserve this file when archiving or pruning evidence. Any move or intentional update must update its consumer and provenance atomically and pass the full suite. This repository-only test fixture is not a runtime exported-game dependency.

Candidate source copies are snapshots for delivery identity. Earlier reviewed source, patches, failed attempts and logs are retained separately; later evidence does not retroactively validate earlier files. See the review dispositions and integrated regression records for scope and limits.
