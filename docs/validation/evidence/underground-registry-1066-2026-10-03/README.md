# Excavation canonical state and memory evidence

Decision 1066 declares the reviewed UG06 physical owners. Source dependencies are
integration commits `0172e808` (UG06 `a84b55ad`) and `8e542e98` (registry `d1caab84`).
The source hashes identify the exact declaration, generated table, checker,
physical owners and memory ledger evaluated here.

All 32 specification CI commands passed on the assembled source. Each exact
command, status, duration and retained output is listed in `spec-gates.json`.
The source capacity audit proved 494 equalities and 73 upper bounds with no
quarantine, contradiction or unexplained census drift. Its 190 self-checks also
passed. Source coverage checked 101 modules, 475 rows and 821 packed columns;
602 persisted packed source fields match the canonical registry.

The focused canonical suite and analyzer were run on the same two changed
GDScript files before the physical dependency commits were integrated. Those
files remained unchanged; this is focused evidence, not a full assembled run.

```text
54 test(s), 4070 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

Independent read-only review by `ug_furnishing` found no blocking issue. It
compared all previous owners by section/key (unchanged), recounted new packed,
control, domain and transient members from source, and independently reproduced
the 13,603,020-byte numeric mutable addition, 21,103-byte declaration,
94,662,614-byte live-plus-reserve ledger and rejected 174,689,397-byte two-world
peak. The capacity proof grammar and eight hash exclusions remain unchanged.

These checks establish declarations and logical payload arithmetic. They do not
establish actual process memory, production save/load parity, a completed
playable underground workflow or qualification-floor performance. The next
full integration checkpoint covers the assembled source separately.
