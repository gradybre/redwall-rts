# Full-size room admission preflight

This follow-up removes the temporary 477-cell engineering allowance while
preserving the existing 16,384-cell footprint ceiling and exact shapes. The
maximum logical envelope is 722,944 bytes: one full actual retained snapshot,
or sequential packed validation scratch, plus incoming and both possible
protected plan images and 2,048 helper/control bytes. All allocation remains
under the same actual 1,048,960-byte World cold lease. No new field, geometry
permission, paid history row or separate arena is introduced.

Actual Terrain checks cover each whole paid-cut run and exact painted footing
and protected-above bands through clipped windows of at most 8×8 real tiles.
The full unfiltered SpaceOwner snapshot retains every claim, wall, item, cavity
and other blocker. All previous source, World, input, reentry and exact lease
checks remain. Existing Sites history is explicitly refused in the virgin path.
Clear plans still end at `PROSPECTIVE_ENTRY_CONTACT_UNBOUND`: no target Room,
entry, excavation, materials, support or work is published by this component.

| Strict suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| Actual Room admission | 21 | 689 | 0 |
| RoomOrders | 28 | 1457 | 0 |
| RoomBindings masks | 17 | 604 | 0 |
| Total | 66 | 2750 | 0 |

The final run moved demo assets aside if present, removed this worktree's
`godot/.godot`, ran `godot --headless --path godot --editor --quit`, then selected
the complete suites through the unchanged strict `tools/run_tests.sh --shard`
path. Full manifests, machine-readable summaries and raw logs are retained.
Assets were restored in `finally`. The import has no errors or warnings.
Every suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The final analyzer command was:

```sh
python3 tools/gdscript_warnings.py godot/scripts/core/underground_room_bindings.gd godot/test/test_underground_room_admission.gd --max 0 --port 6156 --json /tmp/ug1092-scale-analyzer.json
```

It reports `0 GDScript warning(s) in 0 of 2 file(s)`. Independent root review
accepted the exact hashes in `source-sha256.json` after tracing one-image
coverage, the full memory calculation, both loop endpoints pinned before
callbacks, whole cuts versus exact painted bands, all source/lease checks and
the adversarial tests. No high or medium finding remained. No source changed
after review. This does not claim full-suite, target-hardware or native-memory
qualification, or completed productive/entry admission.
