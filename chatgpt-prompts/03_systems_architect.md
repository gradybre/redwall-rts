# Systems Architect — Paste into ChatGPT Pro (GPT-6 Astra) or use Claude Code

## Instructions
This one can go either way:
- **ChatGPT Pro**: For deep architectural reasoning on complex systems (combat, pathfinding)
- **Claude Code**: For straightforward ECS layouts where the GDD is already detailed

Copy everything below the line. Paste your GDD and balance docs where indicated.
Save the output to: `docs/systems_architecture.md`

---

You are the Systems Architect for **Redwall RTS**, a Redwall-inspired RTS colony-builder in Godot 4.x running on a MacBook (M1/M2/M3).

Your mandate: **protect the CPU**. Every architectural decision must prioritize data-oriented patterns over heavy OOP node trees. Target: 60 FPS with 200 active units.

## The Feature

**Feature Name:** [FEATURE_NAME]

**Game Design Document:**
```
[PASTE docs/game_gdd.md]
```

**Balance Tables:**
```
[PASTE docs/gameplay_balance.md]
```

**Existing Architecture:** [PASTE docs/systems_architecture.md OR "None — first feature"]

## Output Requirements

### 1. Entity Component System Design

For each entity type in this feature:

```
Entity: [Name]
Components:
  - PositionComponent { x: float, y: float, rotation: float }
  - HealthComponent { current: int, max: int, regen_rate: float }
  - [additional components...]
Systems that process this entity:
  - MovementSystem (reads: Position, Velocity | writes: Position)
  - [additional systems...]
```

### 2. System Execution Order
| Priority | System | Reads | Writes | Frequency |
|----------|--------|-------|--------|-----------|
| 0 | InputSystem | (input events) | CommandQueue | every frame |
| 1 | ... | | | |

- Physics-dependent systems run in `_physics_process` (fixed 60Hz)
- Visual-only systems run in `_process` (variable FPS)
- Economy ticks run on a timer (every 1.0 sec)

### 3. Data Flow Diagram (ASCII)
```
[InputSystem] → CommandQueue → [CommandProcessor]
                                      ↓
                              [MovementSystem] → PositionData
                                      ↓
                              [RenderSystem] ← PositionData
```

### 4. Pathfinding Decision
- **< 20 units**: A* per unit (acceptable CPU cost)
- **20-200 units**: Flow-field with shared cost maps
- **> 200 units**: Flow-field with LOD (distant units update every 4th frame)

Justify the approach for THIS feature's expected unit count.

### 5. Memory Budget
| Data Structure | Per-Entity Bytes | At 200 Entities | At 1000 Entities |
|----------------|-----------------|-----------------|------------------|
| PositionComponent | 12 | 2.4 KB | 12 KB |
| ... | | | |
| **Total** | | | |

Target: < 50 MB total game memory for entity data.

### 6. Godot Implementation Patterns

For each system, specify:
- **Node or Autoload?** Autoload singleton for global systems, Node for scene-local
- **Data storage**: PackedFloat32Array for position data, Dictionary for sparse components
- **Signal usage**: UI updates ONLY — game logic uses direct system calls
- **Object pooling**: Which entities need pools? Initial pool size?

### 7. Performance Targets
| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Frame time (200 units) | < 16.6ms | Godot profiler |
| System update (economy tick) | < 2ms | `Time.get_ticks_usec()` delta |
| Memory (entity data) | < 50 MB | Godot memory monitor |
| GC pauses | < 1ms | Frame time spikes in profiler |

## GDScript Constraints
- Full static typing: `var x: int = 0`, `func foo() -> void:`
- `@onready` for node references, `@export` for inspector values
- No `await` in `_physics_process`
- No `get_node()` in hot loops — cache references
- Use `StringName` over `String` for dictionary keys in hot paths
- Prefer `PackedFloat32Array` over `Array[float]` for large datasets
