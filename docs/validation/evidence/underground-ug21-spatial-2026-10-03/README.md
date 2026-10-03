# UG21 sparse owner and paid phase adapter — component evidence

Date: 2026-10-03. Godot 4.7.2 stable, development Mac. This packet records
component validation, not production activation or the complete underground
feature's acceptance. See [decision 1064](../../../decisions/1064-underground-spatial-owner.md).

`owner-increment/` preserves the original accepted sparse-owner commit
`1c6853a73a27655e6e243012cfbd6e9a6a03e7d5`, its exact source hashes, raw clean
import, strict runner and analyzer logs. It ran 28 tests and 377 assertions.
The later narrow owner changes distinguish actual underground Room identities
and pending/installed Furniture, expose exact source binding, and detect no-op
prepared images. They add no packed columns.

`authority-increment/` contains the final source hashes, raw import, both
focused runner logs and analyzer output. The source was independently reviewed
before the final added direct phase-guard regression. That test proves missing
materials, unfunded work and incomplete actual labor cannot prepare a paid
publication. The reviewer did not rerun a duplicate suite.

The final procedure moved `godot/demo/assets` aside if present (it was absent
in this isolated worktree), deleted this worktree's `godot/.godot`, then ran
`godot --headless --path godot --editor --quit`. The import exited 0 with zero
error/warning lines. Each focused test file was selected through the existing
strict shard runner using freshly discovered singleton shards; the exact
commands and exits are in `authority-increment/execution.json`. No gate or
diagnostic allowance changed. The analyzer used `--max 0 --port 6152` over the
two source files and their two test files.

```text
31 test(s), 418 assertion(s), 0 failure(s)
19 test(s), 2621 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 4 file(s)
```

Each suite individually emitted the zero diagnostic/leak footers. The paid
adapter fixture uses actual underground Room/World/Job/Resident generations,
Construction, Work, Gear, Inventory, Reservations and physical Sites. Its
profile, movement, structure and service provider is explicitly synthetic.
All five physical operations, cancellation, retained work, exact coverage,
output refusal/retry, closing claims, stale identities/floors, finite cache
capacity and cold static-proof refresh are exercised.

The final raw test log includes `UG21_SINGLE_SITE_PROOF_BATCH`: 256 static plus
dynamic proof pairs in 7,485 microseconds for **one** actual Site and worker.
It is a component probe with synthetic dynamic profile checks, not 256 distinct
workers, no Work ticks, and no whole-world performance qualification.

`rejected-native-import.log` preserves an earlier failed attempt: the editor
emitted a native thread `propagate_notification()` error during font import
and exited with signal 11. It is not successful import evidence. Repeating
the exact clean procedure on unchanged source passed; the final procedure
passed again after the added direct phase test. No engine settings, processes
owned by another agent, diagnostics or test expectations were changed to
obtain that pass.

Production profile/contact/structural/service bindings, staged Furniture
source publication, joint capacity and native peak measurement, and full
composed save/load/hash integration remain open. The base binding refuses;
these component fixtures cannot activate a demo or production world.
