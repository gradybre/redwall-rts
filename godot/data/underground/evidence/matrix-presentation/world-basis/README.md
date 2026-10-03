# Complete finite native heading source

This is source evidence only, with **zero qualified profiles**. Independent root
review accepted the baker/test source at the hashes in `source-evidence.json`.

The baker records all 65,536 native pure-Y headings as two binary32 coefficients
per entry. The test reconstructs and compares all nine components of every
actual native Basis, including noncardinal headings. The table uses the actual
Godot 4.7.2 official desktop OpenGL source, with 0 facing -Z and a positive quarter
turn facing -X. It does not round the small native quarter-turn cosine to zero.

`checks-v1/` used assets moved outside the Godot scan, a deleted `.godot` cache,
clean editor import and the unchanged strict runner with the existing CI selector:

```text
6 test(s), 35 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The analyzer reports zero warnings in two files. Its tool mirror is byte-identical
to the source outside `godot/`. `native-v1/` records the actual invocation, renderer
and complete output hash: 525,013 bytes including metadata/footer, 524,288 bytes
of coefficients, zero unexpected native diagnostics or leaks. The derived binary
stays in the own-worktree ignored assets at
`godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw`.

The diagnostic maximum squared norm is approximately 1.00000008311477. A
conservative consumer must derive its rational norm bound from every stored
coefficient and include composition/shader residuals; an ideal unit-circle bound
is insufficient. Native world placement, profile binding and contact/clearance
qualification remain separate work. The planned one-image presentation reservation
is 544,768 bytes, including a 16 KiB native allowance that has not been measured.

The native command in `native-v1/invocation.json` can be rerun with new raw/report
paths; existing outputs refuse before writing. `run_checks.py` likewise requires
a fresh evidence directory and restores the own-worktree assets on completion.
