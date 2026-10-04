# Paid underground Furniture / sole Room authority — 2026-10-03

Decision1081's bounded actual-owner increment. Source was independently reviewed
at the four hashes in `source-sha256.json`; those exact bytes were checked again
after the final clean import, strict suites and analyzer. Dependency checkpoint
is a2b562ba in the own `codex/underground-furniture-work` branch: assembled
3ab3f46f, own1079 spatial output and the reviewed dff55e50 sparse Furniture
source transition. Only additive decision1075 context required resolution.

## Final checks

The own worktree had no `godot/demo/assets` directory. Its `godot/.godot` was
deleted, then `godot --headless --path godot --editor --quit` completed with
zero error/warning lines in `clean-import.log`. Tests used the unchanged
`./tools/run_tests.sh` and deterministic singleton shard inventory (326 test
files). `strict-invocations.json` records the exact five commands. No test
file, diagnostic guard, output gate or analyzer strictness was changed.

| Actual strict suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| `test_underground_furniture_work.gd` | 15 | 4628 | 0 |
| `test_underground_room_orders.gd` | 6 | 229 | 0 |
| `test_underground_space_owner.gd` | 39 | 570 | 0 |
| `test_modular_projects.gd` | 19 | 1816 | 0 |
| `test_buildings_spatial.gd` | 15 | 287 | 0 |
| Total | **94** | **7530** | **0** |

Each raw suite and `strict-summary.log` contains both strict footers:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The actual Godot editor analyzer command was:

```sh
python3 tools/gdscript_warnings.py godot/scripts/core/underground_room_orders.gd godot/scripts/core/underground_furniture_work.gd godot/test/test_underground_room_orders.gd godot/test/test_underground_furniture_work.gd --max 0 --port 6156 --json /tmp/ug1081-analyzer-final.json
```

`analyzer.log` reports `0 GDScript warning(s) in 0 of 4 file(s)`;
`analyzer.json` retains the machine result. `registry-coverage.log` reports
111 modules, 532 rows and 925 packed columns checked. Production functions
also satisfy the repository's 30-line executable-function limit.

## Scope and rejected iterations

The actual paid path uses real Catalog/Directory/Buildings, Construction,
shared Funding, Inventory/Reservations, Jobs/Work/Gear and SpaceOwner. Test-only
subclasses supply explicit initial Room/Furniture registration permissions,
physical shell/profile/contact/service proof and cold-arena qualification.
These are not production terrain or service adapters. No final live room
confirmation, entire-game save/load, all-source analyzer, full-suite or
target-hardware performance qualification is claimed.

`historical-rejected-parse.log` and `historical-rejected-analyzer.log` retain
the initial three missing arguments in refused-result construction. They were
fixed before the reviewed final candidate; no rejection was tolerated. The
independent review also found cold allocation preceding shared admission.
The accepted source acquires the typed lease before the first real sparse
bank/domain/survey copy and releases after exact companion/geometry cleanup.
Adversarial tests cover denied-before-copy, nested/busy ownership, acquired
lease cleanup before a spatial token exists, and balanced release.
