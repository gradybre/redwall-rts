# Authority survey lifetime prerequisite

This evidence covers only decision1093's early survey-payload release. It adds no
physical support provider, work contact or production permission.

The own isolated checkout moved demo assets aside when present, deleted
`godot/.godot`, imported with `godot --headless --path godot --editor --quit`, then
ran the unchanged strict runner's singleton shard for the Authority suite. Assets
were restored in `finally`. The first invocation used a path instead of the
shard planner's basename and never ran a suite; that refusal is retained.

Corrected command: `python3 reproduce.py test_underground_space_authority.gd`
from the repository root (the reproducer prints its temporary evidence path).
Analyzer: `python3 tools/gdscript_warnings.py --port 6153 --max 0
godot/scripts/core/underground_space_authority.gd
godot/test/test_underground_space_authority.gd`.

```text
36 test(s), 4991 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

The new regression uses actual Inventory, Sites, Work and SpaceOwner publication.
Synthetic contact/companion permissions remain explicitly fixtures. It observes
that old survey arrays are gone before companion allocation, then independently
revokes qualification, lease, staged Owner or companion proof. Each failed actual
paid completion preserves live bytes; a fresh valid retry emits earth exactly
once. The separate construction agent reviewed the frozen source/test and found
no high/medium issue; that source review did not duplicate the engine run.
