# Task 01: Initial Project Setup

## Objective
Bootstrap the Godot 4.x project with ECS-ready architecture, autoload singletons,
and the base scene tree structure.

## Checklist
- [x] Create `project.godot` with correct settings (rendering, physics, input map)
- [x] Set up autoload singletons: GameManager, EconomySystem, CombatSystem, UIManager
- [x] Create base scene tree: Main → World → Entities, UI → HUD
- [x] Implement EntityManager (ECS core: create/destroy entities, component storage)
- [x] Add component base class (Resource subclass with typed data)
- [x] Set up input actions in project settings (select, move, build, cancel)
- [x] Create placeholder HUD scene with resource bar, minimap zone, command panel zone
- [x] Write unit tests for EntityManager CRUD operations
- [x] Verify headless test run: `godot --headless --script test/run_tests.gd`

## Constraints
- Target: Godot 4.3+
- Rendering: Forward+ (for MacBook GPU compatibility)
- Physics: Godot 4 physics (not Jolt) for initial setup
- Max autoload singletons: 6 (to keep boot time fast)

## Dependencies
- None (this is the first task)

## Acceptance Criteria
- Project opens in Godot editor without errors
- All autoloads initialize and print ready messages
- EntityManager can create, query, and destroy 1000 entities in < 16ms
- Headless test runner exits with code 0

## Status: complete

Verified on Godot **4.7.2** (installed via `brew install --cask godot`; the
project targets 4.3+ and 4.7 satisfies it, but 4.7 is the only version this was
actually run against).

| Acceptance criterion | Result |
|---|---|
| Project opens without errors | `godot --headless --editor --quit` — exit 0, no errors or warnings |
| Autoloads initialise and print ready | All 5 print on boot, in dependency order |
| 1000 entities created, queried and destroyed < 16ms | **2.09 ms** measured |
| Headless test runner exits 0 | 52 tests, 106 assertions, 0 failures |

Run the suite from `godot/`:

```
godot --headless --script test/run_tests.gd
```

### Deviations from the original plan
- **No GUT.** GUT is not vendored into the repo and adding it means committing a
  third-party addon. Tests use `test/framework/test_case.gd`, a dependency-free
  base with the same `test_<module>.gd` layout, driven by `test/run_tests.gd`.
  Swapping to GUT later is mechanical.
- **Physics engine** is `GodotPhysics3D`, not `GodotPhysics`. The Godot 3 name is
  silently ignored on Godot 4 and falls back to DEFAULT, which is Jolt on 4.4+ —
  the opposite of this task's constraint.
- **5 autoloads, not 4.** EntityManager is registered first so the systems that
  depend on it can bind in `_ready()`. AudioManager is not registered; there is
  no audio to manage yet.

### Known follow-ups (not blocking)
- Components are `Resource` objects (AoS), while `CLAUDE.md` calls for component
  data arrays (SoA). Memory measured at 2.94 MB per 1000 entities against a
  50 MB budget, so this is a cache-locality question, not a memory one — but it
  is cheaper to change before unit counts grow.
- `query()` allocates a fresh `PackedInt64Array` per call (0.28 ms at 1000
  entities). Add a caller-owned buffer variant when a per-frame caller exists.
- The input actions `select`, `move_command` and `build` are configured but not
  yet read; only `cancel` is wired, to the pause toggle. Selection and building
  belong to the next task.
