# 1048 — The root field cache keys a model by its path

Date: 2026-10-02 · Status: Accepted

## The +2 objects per Restart (decision 0921; soak note "Open")

The soak test found that after each Restart demo the engine's object count was
exactly 2 higher than after the one before. The `--verbose` exit report was
empty and the leak watch could not see the objects, so the owner was not found
(`docs/performance/2026-10-01-soak-test.md`).

**The owner:** `godot/demo/forestry/forest_root_field.gd`, `static var _baked`.
This is the cache of root-support fields, one baked per tree model. The woods'
obstacles and the tree view share it. It keyed each model by
`mesh.get_instance_id()`.

- A Restart frees the old village.
- With the village go the last references to the staged oak and beech meshes,
  so the resource cache lets them go.
- The new village loads them again as **new** mesh objects with the **same**
  resource path (`res://demo/assets/world/oak_mature.glb::ArrayMesh_k7m36`, and
  the beech's).
- Their new ids missed the cache, so two new fields were baked and kept.
- The two old fields stayed in the static Dictionary forever, keyed by ids no
  longer alive.

## How it was found

A scratch probe restarted the live village five times and counted, after each
restart, every object reachable from outside the village: the autoloads, and the
static members of every script under `demo/` and `scripts/`. It counted them by
script. Only `forest_root_field.gd` objects grew, 4 → 6 → 8, matching the engine
count's +2. The probe then printed the cache's keys: two dead mesh ids for each
earlier village, and two live ones whose meshes carry those paths.

An empty scene reloaded five times holds its object count flat. The engine's
own `reload_current_scene` is not the cause.

## Decision

`_cache_key` names the model by its mesh's **resource path**, which a reload
keeps. A mesh with no path, one made in code, falls back to its instance id as
before. A restarted village now finds its fields already baked, so the cache
stops growing, and the restart also skips two bakes.

## Verification

- The probe after the fix: 17890 objects at the first open, then **17900 after
  each of five restarts**. Before the fix it was 17904, 17906, 17908, 17910 and
  17912. The one-off rise at the first restart is the same either way.
- `test_forest_root_field.gd`'s new test
  `test_a_model_reloaded_from_its_file_is_not_baked_again`: two mesh objects
  with the same path (`set_path_cache`) share one field, and the cache does not
  grow. Another path gets its own field. The existing "baked once" test still
  passes; the meshes it builds in code keep their instance-id keys.
- In CI, without staged assets, there are no staged trees, so the cache was
  never filled and the growth was never seen. It needs the staged assets.
