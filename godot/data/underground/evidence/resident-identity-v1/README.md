# Actual resident profile identity prerequisite

The additive `Residents.spatial_profile_identity_into` reads the exact current species,
life stage and logical rig for a full Directory Resident reference into caller-owned
three-element integer scratch. Every refusal preserves the output. Missing child and
elder rigs remain missing; no adult substitution or movement permission is introduced.
A contact or movement owner must still check that the resident is alive and eligible.

Independent root source review accepted the two hashes in `source-sha256.json`.
The invocation records the temporary executable shim that changes suite selection only;
`./tools/run_tests.sh` and its strict registry, summary, diagnostics and leak gates were
unmodified. Assets were moved aside, `godot/.godot` deleted, and the exact editor import
run first; assets were restored in `finally`.

```
98 test(s), 2019 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 98 tests, 2019 assertions, 0 failures.
0 GDScript warning(s) in 0 of 2 file(s)
```

The clean import exited 0 and contains no error/warning lines. These results qualify
only the identity reader, not a physical profile, contact, connector or playable lane.
