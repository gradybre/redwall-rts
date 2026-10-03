# Mandatory spatial Buildings state reconciliation

Decision1071 adds actual Room spatial domain and Furniture installed state as a mandatory section6 Buildings extension, preserving the existing surface layouts. This is a registry and logical-memory checkpoint, not a composed codec or full-suite qualification.

The changed-source manifest pins the exact thirteen reviewed files over `7c9d4118`. The independent UG07 reviewer verified the field-order/schema delta, source-derived allocation arithmetic, historical trail correction and regression gates; no remaining blocker was found. The original eleven-file manifest is retained because all32 specification commands ran before the review correction. The eight affected gates then passed on the final thirteen-file manifest; see `final-checks/checks.json`. The reviewer separately reran the arithmetic, merge-gate self-tests and190 capacity-audit checks.

The canonical GDScript sources are unchanged between those manifests. The registry-only final changes refresh the reviewed Sites/Gear provenance hashes; no field, value contract, ordinal or generated table changed.

The own-worktree demo assets were absent. Its `.godot` cache was deleted before the clean editor import, which exited0 with no error/warning lines. The strict singleton uses the ordinary CI runner and unchanged diagnostics gates:

```text
55 test(s), 4100 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

No unqualified sparse owner, tip, profile, contact, support, save or runtime allocation is counted as zero. The remaining whole-composition budget must still be admitted before production activation.
