# Redwall RTS — Claude Code Project Instructions

## Overview
A Redwall-inspired RTS colony-builder built in Godot 4.x with GDScript.
All development is orchestrated through Claude Code using sub-agents for
parallel work. No external APIs or tooling needed.

## Project Structure
```
redwall-rts/
├── docs/                        ← Design specs & task checklists
│   ├── game_gdd.md               (Game Design Document — EARS notation)
│   ├── ui_ux_controls.md         (Screen zones, input mapping, HUD specs)
│   ├── gameplay_balance.md       (Production rates, cost curves, stress tests)
│   ├── systems_architecture.md   (ECS layout, data flow, perf budgets)
│   └── tasks/                    (Sequential implementation checklists)
├── godot/                       ← Godot 4.x project
│   ├── project.godot
│   ├── scripts/
│   │   ├── systems/              (Autoloaded ECS singletons)
│   │   ├── components/           (Component data classes)
│   │   ├── entities/             (Entity scenes + controllers)
│   │   ├── ui/                   (HUD + menu scripts)
│   │   └── utils/                (Shared helpers)
│   └── test/                    (GUT unit tests)
├── chatgpt-prompts/             ← Optional: paste into ChatGPT Pro for Astra planning
└── CLAUDE.md                    ← You are here
```

## The Pipeline

When implementing a feature, run these phases in order. Use the Agent tool
to parallelize independent work within each phase.

### Phase 1: Planning & Architecture

**If planning docs already exist in `docs/`**: Read them and proceed to Phase 2.

**If starting fresh**: Generate all four planning documents before writing any code.

#### 1A — Game Design & UX Architect
Generate `docs/game_gdd.md` and `docs/ui_ux_controls.md`:

**GDD requirements:**
- Use EARS notation for every requirement:
  - Ubiquitous: "The system shall [action]"
  - Event-driven: "When [trigger], the system shall [action]"
  - State-driven: "While [state], the system shall [action]"
- ID every requirement: `REQ-[FEATURE]-001`
- Map progressive disclosure: minute 1 → minute 30 → hour 2+
- Define entities with typed properties (int, float, enum)
- Cover edge cases and failure states

**UI/UX requirements:**
- Screen zone anchoring:
  - Top-left: Resource counters
  - Top-center: Alerts/notifications
  - Top-right: Game speed, menu
  - Bottom-left: Minimap
  - Bottom-center: Selected unit/building commands
  - Bottom-right: Context info panel
- Every UI element needs: position, size constraints, font size, color tokens, states (default/hover/pressed/disabled), animations
- Input mapping table: mouse, keyboard, gamepad
- ID every element: `UI-[FEATURE]-001`
- Responsive behavior: 1280x720 to 3840x2160

#### 1B — Economy Mathematician
Generate `docs/gameplay_balance.md`:

- Resource production/consumption rates (units/sec, 2 decimal places)
- Building cost curves with formula: `cost(level) = base * (factor ^ (level-1))`
  - Growth factors must NOT be clean numbers (use 1.47, not 1.5)
- Asymmetric timing ratios (1 mill feeds 2.3 workshops, not 2 or 3)
- Population scaling: `wealth(n) = base * ln(n+1) * multiplier`
- Tables at population: 10, 25, 50, 100, 200, 500, 1000
- Stress tests: rush, boom, balanced, starvation cascade
- Anti-exploit constraints: storage caps, diminishing returns, trade limits

#### 1C — Systems Architect
Generate `docs/systems_architecture.md`:

- ECS design: entities, components (typed), systems (read/write deps)
- System execution order table with frequency (every frame / fixed / timer)
- ASCII data flow diagrams
- Pathfinding: A* for <20 units, flow-field for 20-200, flow-field+LOD for >200
- Memory budget table per component (target: <50MB at 1000 entities)
- Godot patterns: autoload vs node, PackedFloat32Array vs Array, signal rules
- Performance targets: 60 FPS / 200 units / <2ms economy tick / <1ms GC

### Phase 2: Development & Execution

Read all `docs/` specs first. Then fan out parallel agents:

#### 2A — Coder Agent
Writes production GDScript into `godot/scripts/`. **Never stubs or TODOs.**

File organization:
- `scripts/systems/` — Autoloaded singletons (GameManager, EconomySystem, etc.)
- `scripts/components/` — Component data (Resource subclasses or typed dicts)
- `scripts/entities/` — Entity scenes + scripts
- `scripts/ui/` — HUD, menus, panels
- `scripts/utils/` — Shared helpers

#### 2B — QA Tester Agent
Writes GUT test files into `godot/test/`:
- One file per module: `test_<module>.gd`
- Every public function gets at least one test
- Boundary tests for balance table values
- Stress tests for performance systems
- Resource conservation checks

### Phase 3: Review & Commit

#### 3A — PR Code Reviewer (separate agent for independent review)
Adversarial review of all code from Phase 2. Flags:
- **CRITICAL**: Memory leaks, orphaned nodes, hot-loop allocations
- **HIGH**: Missing type hints, `get_node()` in `_process`, unmanaged signals
- **MEDIUM**: DRY violations, functions >30 lines
- **LOW**: Style, missing docstrings

#### 3B — Fix critical/high issues from the review

#### 3C — Release Manager
- Update task checklist in `docs/tasks/` (mark items `[x]`)
- Stage specific files (never `git add .`)
- Semantic commit (Conventional Commits format):
  ```
  feat(economy): implement resource gathering and stockpile system
  ```

---

## GDScript Standards

### Required Patterns
```gdscript
# Full static typing — ALWAYS
var _health: int = 100
var _position: Vector2 = Vector2.ZERO
func take_damage(amount: int) -> void:

# @onready for node references
@onready var _resource_label: Label = $HUD/ResourceLabel

# @export for inspector values
@export var max_health: int = 100
@export var move_speed: float = 150.0

# Constants in SCREAMING_SNAKE_CASE
const MAX_UNITS: int = 200
const ECONOMY_TICK_RATE: float = 1.0

# Signals prefixed with context
signal unit_selected(unit_id: int)
signal resource_depleted(resource_type: StringName)

# Docstrings on every function
func gather_resource(worker_id: int, target_id: int) -> bool:
    """Assign a worker to gather from a resource node. Returns false if target is depleted."""
```

### Banned Patterns
```gdscript
# NEVER: get_node in _process
func _process(delta: float) -> void:
    var label = get_node("HUD/Label")  # ← NO

# NEVER: await in _physics_process
func _physics_process(delta: float) -> void:
    await get_tree().create_timer(1.0).timeout  # ← NO

# NEVER: object creation in hot loops
func _process(delta: float) -> void:
    var pos = Vector2(x, y)  # ← NO (use cached var)

# NEVER: string concat in hot paths
for unit in units:
    var key = "unit_" + str(unit.id)  # ← NO (use StringName)

# NEVER: untyped variables or functions
var health = 100        # ← NO (missing type)
func do_thing():        # ← NO (missing return type)
```

### Architecture Constraints
- **ECS over node hierarchy**: Entities are IDs, components are data arrays
- **Object pooling**: Projectiles, particles, transient entities
- **Spatial partitioning**: Grid-based hash maps for broad-phase
- **Autoloads**: Max 6 singletons (GameManager, EconomySystem, CombatSystem, UIManager, EntityManager, AudioManager)
- **Signal connections**: UI updates only — game logic uses direct system calls
- **Max function length**: 30 lines. Decompose if longer.

## Performance Targets
| Metric | Target | How to measure |
|--------|--------|----------------|
| Frame time (200 units) | < 16.6ms | Godot profiler |
| Economy tick | < 2ms | `Time.get_ticks_usec()` delta |
| Entity data memory | < 50 MB at 1000 | Godot memory monitor |
| GC pauses | < 1ms | Frame time spike detection |

## Optional: ChatGPT Pro for Planning
For features that need frontier-level reasoning (complex combat systems,
deep economic modeling), prompt templates in `chatgpt-prompts/` can be
pasted into ChatGPT Pro (GPT-6 Astra). Save outputs to `docs/`.
This is optional — Claude Code handles planning for most features.
