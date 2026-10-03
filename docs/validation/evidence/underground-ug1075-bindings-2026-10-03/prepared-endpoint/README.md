# Sealed prepared endpoint reader

`prepared_location_into` copies an exact endpoint from a sealed current candidate.
It does not publish it, expose bank aliases or bypass current Inventory retention.
Tests cover stale/foreign/unsealed/aborted tokens, generation checks and unchanged
caller output on refusal. The component geometry remains synthetic; these checks
do not qualify traversal, profile content or terrain. Independent source review
accepted the exact pinned source and test.

```text
18 test(s), 420 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```
