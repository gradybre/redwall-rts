"""Systems Architect agent — powered by Claude Opus.

Enforces Data-Oriented Design, ECS patterns, and performance-conscious
architecture for Godot 4.x on constrained hardware (MacBook).
"""

from __future__ import annotations

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState
from .base import invoke_agent, load_prompt, write_doc


async def systems_node(state: PipelineState) -> dict:
    """LangGraph node: run the Systems Architect agent."""
    system_prompt = load_prompt("systems")
    if not system_prompt:
        system_prompt = SYSTEMS_SYSTEM_PROMPT

    user_prompt = f"""## Feature Context
{state.task_description}

## GDD Reference
{state.gdd_content or "(Pending)"}

## Balance Constraints
{state.balance_tables or "(Pending)"}

## Existing Systems Spec
{state.systems_spec or "(None yet)"}

Generate `systems_architecture.md` covering:
1. Entity Component System design for this feature's entities
2. Data flow diagrams (which systems read/write which components)
3. Pathfinding approach (flow-field vs A* — justify for unit count)
4. Memory budget estimates
5. Performance targets (target FPS, max entity count before degradation)
6. Godot-specific patterns (when to use nodes vs resources vs pure data)

Wrap in `---DOC:systems_architecture.md---` delimiters.
"""

    result = await invoke_agent(
        role=ModelRole.SYSTEMS,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="systems_architect",
    )

    if result.output:
        content = result.output
        if "---DOC:systems_architecture.md---" in content:
            start = content.index("---DOC:systems_architecture.md---") + len("---DOC:systems_architecture.md---")
            content = content[start:].strip()

        path = write_doc("systems_architecture.md", content)
        result.files_created = [path]

        return {
            "results": state.results + [result],
            "systems_spec": content,
        }

    return {"results": state.results + [result]}


SYSTEMS_SYSTEM_PROMPT = """You are the Systems Architect for a Redwall-inspired RTS colony-builder in Godot 4.x.

Your mandate: protect the MacBook's CPU. Every architectural decision must prioritize
data-oriented patterns over heavy OOP node trees.

## Core Principles
1. **ECS over node hierarchy**: Entities are IDs, components are data arrays, systems iterate linearly
2. **Flow-field pathfinding** for large unit counts (>50), A* only for boss/hero units
3. **Object pooling** for projectiles, particles, and transient entities
4. **Spatial partitioning** via grid-based hash maps, not Godot's built-in physics
5. **Budget**: Target 60 FPS with 200 units on M1/M2 MacBook Pro

## GDScript Constraints
- Prefer typed arrays and dictionaries over custom Resource subclasses where possible
- Use `@export` for inspector-editable values, but keep runtime data in plain arrays
- Signal connections for UI updates only — game logic uses direct system calls
- Autoload singletons for system managers (EconomySystem, CombatSystem, etc.)

## Output Format
Wrap in `---DOC:systems_architecture.md---`. Use diagrams described in ASCII where helpful.
"""
