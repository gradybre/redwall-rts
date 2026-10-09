# Actual room confirmation adapter — 2026-10-04

ADR1146 / UG24. The adapter connects the actual in-world drawing to the real
RoomOrders command boundary. It retains the selected permanent purpose, exact
integer cells, source-authored floor and full Room identity. It does not own a
clock, create a second settlement, charge resources, or invoke the legacy graph.
The production scene host and successful approach/room phase still remain open;
the actual physical provider currently refuses the missing completed entry.
These are component tests, not the playable empty Kitchen milestone.

Independent review found three issues in the first candidate: stale view changes
inside owner observers, owner lifetime across submission, and falsely successful
binding while the editor was submitting. The second pass found the same lifetime
issue for the provider and a final modal callback changing the draft. All are
corrected with strong command-lifetime owner borrows, safe provider/Space reborrow,
pure checks after view callbacks and truthful callback binding. Exact rejected
sources are archived under source-review-1 and source-review-2. Original and final
fingerprints and review correspondence are retained in the independent review.

Final affected suite (focused-v6):

```text
16 test(s), 227 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 4 file(s)
```

The unchanged Editor and WorldTool suites in focused-v5 add19 tests and253
assertions, with the same zero strict/raw diagnostics/leaks. Together the current
code has35 relevant tests/480 assertions. Each run parked any demo assets, removed
.godot, imported cleanly, invoked the official strict singleton shards and ran the
zero-warning analyzer. Actual shared registry, project and source restoration are
recorded in invocation.json. No temporary registry substitute was used. The v4
attempt stopped at the missing Motion registry prerequisite before any test ran;
its refusal is preserved. v1/v2 retain bring-up compile/analyzer failures.

Presentation snapshots are finite UI/command inputs, not another authoritative
footprint. The later complete host must count its total presentation peak; the
RoomPlan cold allowance alone is not a claim to cover every editor copy.
