# Native underground matrix adapter component

The immutable palette and original-mesh renderer are independently reviewed.
This evidence does not qualify a production clearance profile or supply authored
connector permissions. All numerical fixture geometry is synthetic.

The final clean focused command in `../run_checks.py` moves this worktree’s demo
assets aside, deletes `.godot`, imports, and runs the unchanged strict test
wrapper through its existing suite selector. It restores assets on every exit.
`../checks-v3/` records the final source candidate:

```text
21 test(s), 2713 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

The native OpenGL run uses the exact command and source hashes in
`source-evidence.json`. It reports 11 component tests and 106 assertions with
zero failures, then 117 total assertions after actual rendered-pixel checks.
Each entry/re-entry cycle renders 2,016 green pixels with centroid X=84.6667;
the unchanged mesh would have a centroid near X=149. This tests the mesh’s real
skin attachment, not merely the contents of an unattached skeleton buffer.
There are no error/warning or resource-leak diagnostics in the raw native log.

Independent review found that configuring before SceneTree entry could lose
the manual skeleton attachment when MeshInstance3D resolved its empty skeleton
path. The final adapter refuses configuration outside the tree before allocating
native state; removing it retires its owned RIDs and parts, and re-entry requires
fresh configuration. The corrected source and two-cycle native evidence were
accepted in a separate read-only review. The earlier checks-v1/v2 logs are retained
as historical component iterations; checks-v3 identifies the final candidate.

Original Mesh and Material resources are retained. A material override remains
its original resource, while unsupported custom displacement, later passes and
blend shapes refuse. The renderer does not change simulation progress, cargo
identity, movement permission, or the existing surface Actor path. Finite palettes
and their later source-enclosure proof are a separate content increment.
