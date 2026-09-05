# Task 01: Initial Project Setup

## Objective
Bootstrap the Godot 4.x project with ECS-ready architecture, autoload singletons,
and the base scene tree structure.

## Checklist
- [ ] Create `project.godot` with correct settings (rendering, physics, input map)
- [ ] Set up autoload singletons: GameManager, EconomySystem, CombatSystem, UIManager
- [ ] Create base scene tree: Main → World → Entities, UI → HUD
- [ ] Implement EntityManager (ECS core: create/destroy entities, component storage)
- [ ] Add component base class (Resource subclass with typed data)
- [ ] Set up input actions in project settings (select, move, build, cancel)
- [ ] Create placeholder HUD scene with resource bar, minimap zone, command panel zone
- [ ] Write unit tests for EntityManager CRUD operations
- [ ] Verify headless test run: `godot --headless --script test/run_tests.gd`

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
