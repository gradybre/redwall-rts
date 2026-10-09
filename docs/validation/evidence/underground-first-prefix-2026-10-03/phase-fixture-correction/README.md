# Contacts fixture generation correction

The integrated `ca622` checkpoint exposed two Contacts fixture failures in
`test_phase_productive_leaf_follows_real_payment_and_rechecks_current_worker`
and `test_phase_cut_output_is_current_exact_spatial_storage_after_real_bracing`.
Their inherited synthetic final payment leaves still assumed Room generation
1, although the fixture now admits an actual generation-checked Room.

This isolated test-only correction overrides those two leaves with the actual
Directory full Room identity check already used by the fixture's ordinary
`room_refusal`. Pending-stage and injected negative checks remain intact. The
fixture's geometric authority remains explicitly synthetic. Actual Sites,
Funding, Inventory and Work still execute the guarded payment path; no
production source, permission or paid state is changed.

The exact official singleton run passed **30 tests / 7,422 assertions / 0
failures**. All strict and raw unexpected diagnostic and object/resource leak
counts are zero. Fresh editor import succeeded, and the analyzer reports **0
warnings in 1 file**. `invocation.json` records the isolated user directory,
source preservation, and project/assets restoration. `source-sha256.json`
pins the corrected test and actual source dependencies. The pending 1119
Contacts reflection change is deliberately absent from this isolated commit.

Independent root review accepted the exact 15-line test diff at SHA-256
`899c91b9002f999fc469f1203fd7a855bb5d94ed6506cc545a8c105619cc6081`:
all inherited pending-stage and negative guard checks are retained, and only
the hardcoded generation assumption is replaced by actual full Room validity.

Reproduce from the repository root with:

```sh
python3 docs/validation/evidence/underground-first-prefix-2026-10-03/reproduce_phase_fixture.py --out docs/validation/evidence/underground-first-prefix-2026-10-03/phase-fixture-correction --port 6165 --suite test_underground_connector_contacts.gd --dependency godot/scripts/core/underground_connector_contacts.gd --dependency godot/scripts/core/excavation_sites.gd --dependency godot/scripts/core/excavation_contract.gd --dependency godot/test/test_excavation_physical.gd
```
