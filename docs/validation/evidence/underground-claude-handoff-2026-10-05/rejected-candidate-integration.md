# Rejected combined WIP candidate — 2026-10-05

This is a disposable staging result, not a qualification receipt. The construction, geometry, and root contact-retirement WIP patches from the handoff were applied together in a temporary clone, with the untracked source bundle copied from the geometry worktree.

Preparation:

- Godot: `4.7.2.stable.official.ed1daf0bf`.
- `godot --headless --path godot --editor --quit` reached the script scan after the missing `source_program.gd`, `physical_certificate.gd`, and `handling_clock.gd` snapshots were supplied. It emitted only the macOS certificate/editor-settings environment errors; no GDScript parse error remained.
- Focused runner command used the existing CI runner with these eight suites: `test_underground_locations.gd`, `test_modular_projects.gd`, `test_underground_connector_work.gd`, `test_underground_connector_workpieces.gd`, `test_underground_connector_contacts.gd`, `test_underground_profiles.gd`, `test_underground_world_routes.gd`, and `test_underground_paid_assembly_handling.gd`.

Result:

- **266 tests, 16,522 assertions, 153 failures**.
- **107 unexpected errors**, zero unexpected warnings, and no acceptance claim.
- `test_underground_world_routes.gd` alone ended at 48 tests / 3,007 assertions / 32 failures.
- Representative refusals were `PROFILE_SOURCE_IDENTITY`, `CONNECTOR_CATALOG_SOURCE`, `ROUTE_PROFILE_EXTENT_STALE`, and `WORLD_ROUTE_CERTIFICATE_STALE`; fixture creation also hit null `store_buffer` calls.
- The candidate did not run the no-argument full suite, analyzer, memory census, visual acceptance, or resident soak.

Interpretation: the three WIP lanes are not a mergeable candidate. Their source revisions and fixture contracts must be renewed against one common root before code is integrated. The actual paid positive remains independently blocked at `LOCATION_ENVELOPE_BLOCKED`, as recorded by `source-snapshots/construction/paid-12-README.md`.
