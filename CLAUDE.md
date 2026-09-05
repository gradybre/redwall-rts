# Redwall RTS — Project Instructions

## Overview
A Redwall-inspired RTS colony-builder built in Godot 4.x with GDScript.

Development uses a hybrid multi-agent workflow:
- **Planning** (Phase 1): Done manually in ChatGPT Pro using GPT-6 Astra. Prompt templates are in `chatgpt-prompts/`. Outputs are saved to `docs/`.
- **Development & Review** (Phases 2-3): Done here in Claude Code under Pro Max. Claude reads the planning docs and orchestrates all coding, testing, and review.

## Project Structure
```
redwall-rts/
├── chatgpt-prompts/        ← Prompt templates to paste into ChatGPT Pro
│   ├── 01_architect.md      (GDD + UI/UX specs → docs/game_gdd.md, docs/ui_ux_controls.md)
│   ├── 02_economist.md      (Balance tables → docs/gameplay_balance.md)
│   └── 03_systems_architect.md  (ECS architecture → docs/systems_architecture.md)
├── docs/                    ← Planning outputs (from ChatGPT) + task checklists
│   ├── game_gdd.md
│   ├── ui_ux_controls.md
│   ├── gameplay_balance.md
│   ├── systems_architecture.md
│   └── tasks/               ← Sequential implementation checklists
├── godot/                   ← Godot 4.x project
│   ├── project.godot
│   └── scripts/
│       ├── systems/         ← ECS system managers (autoloaded singletons)
│       ├── components/      ← Component data classes
│       ├── entities/        ← Entity scenes and controllers
│       ├── ui/              ← HUD and menu scripts
│       └── utils/           ← Shared utilities
├── orchestrator/            ← LangGraph pipeline (optional, for future API-based runs)
└── CLAUDE.md                ← You are here
```

## Development Workflow (How Claude Code Should Operate)

When the user says "implement [feature]" or "run dev pipeline for [feature]":

### Step 1: Read Planning Docs
Read all docs in `docs/` to understand the feature:
- `docs/game_gdd.md` — What to build (requirements, entities, game loops)
- `docs/ui_ux_controls.md` — How the UI should look and behave
- `docs/gameplay_balance.md` — Exact numbers for production rates, costs, ratios
- `docs/systems_architecture.md` — HOW to build it (ECS layout, performance targets)
- `docs/tasks/` — Current task checklist for sequential implementation

### Step 2: Code (Coder Agent)
Write production-ready GDScript into `godot/scripts/`:
- Follow the Systems Architecture spec exactly
- Full static typing on every variable and function signature
- Every function gets a docstring
- Max function length: 30 lines — decompose if longer
- Use ECS patterns: entities are IDs, components are data arrays, systems iterate linearly
- Object pooling for projectiles, particles, and transient entities
- No `await` in `_physics_process()`
- `@onready` for node references, `@export` for inspector values
- Constants in `SCREAMING_SNAKE_CASE`
- Signals prefixed with context: `unit_selected`, `resource_depleted`

File organization:
- `scripts/systems/` — Autoloaded singleton managers (GameManager, EconomySystem, etc.)
- `scripts/components/` — Component data (Resource subclasses or typed dictionaries)
- `scripts/entities/` — Entity scenes and their scripts
- `scripts/ui/` — HUD, menus, panels
- `scripts/utils/` — Shared helpers

### Step 3: Test (QA Agent)
Generate GUT (Godot Unit Testing) test files in `godot/test/`:
- One test file per system/module: `test_<module_name>.gd`
- Every public function gets at least one test
- Boundary tests for all balance table values
- Stress tests for performance-sensitive systems
- Test resource conservation (nothing created from nothing)
- Use `assert_eq`, `assert_true`, `assert_almost_eq` (for floats with epsilon)

### Step 4: Review (PR Reviewer Agent)
Audit all code written in this session. Use a separate agent for independent review.
Flag with severity levels:
- **CRITICAL**: Memory leaks (orphaned nodes, circular refs), operations in `_process` that should be event-driven
- **HIGH**: Missing type hints, `get_node()` in hot loops, signals connected but never disconnected
- **MEDIUM**: DRY violations, functions > 30 lines, unclear naming
- **LOW**: Style inconsistencies, missing docstrings

Godot anti-patterns to flag:
- `get_node()` in `_process()` or `_physics_process()` — use `@onready`
- `await` in `_physics_process()`
- Creating new objects in `_process()` — use object pooling
- String concatenation in hot loops — use `StringName`
- Node tree queries replaceable by direct references

### Step 5: Fix & Commit
- Fix any CRITICAL or HIGH issues from the review
- Update the task checklist in `docs/tasks/` (mark completed items `[x]`)
- Stage only the files that changed — never `git add .`
- Semantic commit message (Conventional Commits):
  ```
  feat(economy): implement resource gathering and stockpile system

  - Added WoodcutterSystem, StockpileComponent, ResourceFlowManager
  - GUT tests for production rates and storage overflow
  - Reviewed: no critical issues

  Refs: docs/tasks/01_initial_setup.md
  ```

## GDScript Anti-Pattern Reference
These patterns MUST be avoided in all generated code:

```gdscript
# BAD: get_node in _process
func _process(delta: float) -> void:
    var label = get_node("HUD/ResourceLabel")  # ← NEVER do this

# GOOD: cache with @onready
@onready var _resource_label: Label = $HUD/ResourceLabel
func _process(delta: float) -> void:
    _resource_label.text = str(_resources)

# BAD: creating objects in hot loop
func _process(delta: float) -> void:
    var pos = Vector2(x, y)  # ← Creates garbage every frame

# GOOD: reuse pre-allocated
var _cached_pos: Vector2 = Vector2.ZERO
func _process(delta: float) -> void:
    _cached_pos.x = x
    _cached_pos.y = y

# BAD: string concat in loop
for unit in units:
    var key = "unit_" + str(unit.id)  # ← String allocation

# GOOD: StringName for dictionary keys
for unit in units:
    var key := StringName("unit_%d" % unit.id)
```

## Performance Targets
- 60 FPS with 200 active units on M1/M2 MacBook
- Economy tick: < 2ms per update
- Entity data memory: < 50 MB at 1000 entities
- No GC pauses > 1ms
