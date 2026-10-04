# Actual Room identity consumer

This isolated change consumes the independently accepted Buildings helper from
16359f0c. CoreSources reuses one six-I32 (24-byte) packet instead of allocating
OpResult objects for Room identity. SourceFacts, wire state and gameplay behavior
are unchanged. Actual surface, underground, invalid-domain, stale-source and
publication tests run through the existing complete Owner suite. Bounded linear
source lookup still exists; this is not a whole-query timing qualification.

Clean assets-aside import, own cache deleted, unchanged strict singleton runner:

```text
88 test(s), 5024 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1 file(s)
```

Root independently accepted frozen source d2e30c49… after checking the exact facts,
cleared refusal output, mirrored actual Room identity and surface/underground
mapping. This source review did not duplicate the engine run. The fixed24 bytes
are noncanonical, unsaved scratch inside the existing bindings reservation.
