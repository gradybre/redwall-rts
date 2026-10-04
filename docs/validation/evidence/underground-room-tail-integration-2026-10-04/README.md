# Ordinary Room publication integration — 2026-10-04

The ordinary Room path now separates observing validation from its final
identity/claim/geometry publication. The final tail uses the concrete Directory
and static Buildings, Sites and Space leaves. It creates neither a free
excavated room nor an approach permission. Real approach admission remains
the separate 1150 composition.

Independent review found an overridable private Sites/Buildings callback after
the first identity write. The corrected static transitive tail and adversarial
regressions were accepted in review commit `8dd07e6f`, retained under
`../underground-ordinary-room-publication-review-2026-10-04/`. The final small
follow-up preserves the original SpatialAuthority type constraint.

## Executed checks

`diagnostic-1/` ran eleven actual strict singleton shards: **389 tests / 17,880
assertions / zero failures**. Despite the directory's historical name, it used
`tools/run_tests.sh`, its original registry and normal diagnostic/leak gates.
It did not use the optional diagnostic bypass mode in the reproducer.

After the type-parity correction and its added regression, `focused-2/` reran
RoomOrders, claim batches and spatial Buildings: **69 tests / 2,568 assertions /
zero failures**. The complete earlier run is pinned to its earlier bytes;
the final three-suite run is not represented as a repeat of all eleven suites.
Both analyzers report:

```text
0 GDScript warning(s) in 0 of 11 file(s)
```

Every executed suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Both runs parked any demo assets, deleted `godot/.godot`, performed a clean
headless editor import, then ran the unchanged strict suite and zero-warning
analyzer. Raw imports had no errors, warnings or leaks. Isolated userdata,
source hashes, commands, timings and restoration checks are retained in each
`invocation.json` and `source-sha256.json`. Source, registry, project settings
and original asset presence were preserved/restored.

## Logical storage and limits

No retained field, bank or capacity was added. The independent conservative
root-tail numeric census is **1,582 / 2,048 bytes** including caller packets
and expression allowance. The complete 1150/1151 caller coexistence census
remains a separate integration gate.

`generated-provenance-delta.json` records 75 changes to generated SHA/line
provenance only. Existing generators and checkers were unchanged. The memory
suite passed **225 tests**; capacity audit passed **190 checks / zero failures**.
The logical global reserve remains **99,998,782 bytes**, with **1,218 bytes**
headroom; this is source accounting, not a runtime memory qualification.

This component does not close D20, room excavation, demo input, save/resume or
256-resident qualification. Full-suite evidence remains the separately pinned
checkpoint and CI records.
