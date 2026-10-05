# Actual settlement room inspector —1176

Final source: `modular_room_mode.gd` SHA256
`6485e0cb02816bc92d6858ba2632cd9e66c2bebe4a2c3db976823301f64f3261`;
test SHA256 `c60b0ee7e5031345476446459e057bd74ccbad807371fd61784c9fd6502a0dca`.

Candidate4 used the CI clean-assets/cache/import procedure, official exact
singleton shard and `tools/gdscript_warnings.py --max 0`. Its recorded output:

```text
10 test(s), 148 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 2 file(s)
```

The raw editor log is also clean. Source pins, original project, assets and
preexisting sidecars were restored. This is a component run, not the full
no-argument suite or a completed playable room.

Furnishing independently accepted these exact source/test pins in
`../underground-actual-world-view-2026-10-05/room-mode-review-2/review.json`.
The preceding review found fallible getter and callback-driven floor-change
cases; both were corrected with regressions. Candidate3 passed the tests but
failed one shadowed-variable analyzer warning; Candidate4 renames that local
without changing behavior. Earlier foundation/candidate failures remain
recorded, including stale published consumer pins before1173 was integrated.

The inspector uses the actual original World and selected LevelCatalog floor.
Tests verify purpose/floor preservation, draft history, original command
owners, missing-access conservation, stale-session refusal and callback
interruption.1179 still owns actual demo entry, camera/input handover and
native1280×720 checks. Real access, movement and construction remain open.
