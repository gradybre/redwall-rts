"""Coder Agent — powered by Claude Opus.

Reads task checklists and specs, then writes production-ready GDScript
directly into the Godot project directory.
"""

from __future__ import annotations

import re
from pathlib import Path

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState
from .base import invoke_agent, load_prompt, write_code, read_doc


async def coder_node(state: PipelineState) -> dict:
    """LangGraph node: run the Coder agent."""
    system_prompt = load_prompt("coder")
    if not system_prompt:
        system_prompt = CODER_SYSTEM_PROMPT

    # Gather all planning docs as context
    planning_context = f"""## Game Design Document
{state.gdd_content}

## UI/UX Specification
{state.ui_ux_spec}

## Balance Tables
{state.balance_tables}

## Systems Architecture
{state.systems_spec}
"""

    user_prompt = f"""## Task
{state.task_description}

## Feature
{state.feature_name}

{planning_context}

## Instructions
Based on the specifications above, write all GDScript files needed to implement
this feature. For each file, use the delimiter format:

```gdscript
# ---FILE:res://path/to/file.gd---
<code here>
```

Follow the Systems Architecture exactly. Use ECS patterns where specified.
Include type hints on every variable and function signature.
Include inline documentation for complex logic.
"""

    result = await invoke_agent(
        role=ModelRole.CODER,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="coder",
    )

    code_files = {}
    files_created = []

    if result.output:
        parsed = _parse_code_files(result.output)
        for filepath, content in parsed.items():
            full_path = write_code(filepath, content, project_root="./godot")
            code_files[filepath] = content
            files_created.append(full_path)

        result.files_created = files_created

        return {
            "results": state.results + [result],
            "code_files": {**state.code_files, **code_files},
        }

    return {"results": state.results + [result]}


def _parse_code_files(output: str) -> dict[str, str]:
    """Extract file paths and contents from delimited code blocks."""
    files = {}
    pattern = r"#\s*---FILE:(.*?)---\s*\n(.*?)(?=#\s*---FILE:|$)"
    matches = re.findall(pattern, output, re.DOTALL)

    for filepath, content in matches:
        filepath = filepath.strip()
        # Strip the res:// prefix for local filesystem
        if filepath.startswith("res://"):
            filepath = filepath[6:]
        files[filepath] = content.strip()

    # Also try matching within ```gdscript blocks
    if not files:
        block_pattern = r"```gdscript\s*\n#\s*---FILE:(.*?)---\s*\n(.*?)```"
        matches = re.findall(block_pattern, output, re.DOTALL)
        for filepath, content in matches:
            filepath = filepath.strip()
            if filepath.startswith("res://"):
                filepath = filepath[6:]
            files[filepath] = content.strip()

    return files


CODER_SYSTEM_PROMPT = """You are the Coder Agent for a Redwall-inspired RTS colony-builder in Godot 4.x.

You write production-ready GDScript. You do NOT prototype or stub.

## Code Standards
- GDScript 2.0 with full static typing (`var x: int = 0`, `func foo() -> void:`)
- Every function has a docstring
- Constants in SCREAMING_SNAKE_CASE
- Signals prefixed with context: `unit_selected`, `resource_depleted`
- Max function length: 30 lines. If longer, decompose.
- No `await` in physics processing functions
- Use `@onready` for node references, `@export` for inspector values

## File Organization
- `scripts/systems/` — ECS system managers (autoloaded singletons)
- `scripts/components/` — Component data classes (Resource subclasses)
- `scripts/entities/` — Entity scenes and controllers
- `scripts/ui/` — HUD and menu scripts
- `scripts/utils/` — Shared utilities

## Output Format
For each file, use: `# ---FILE:res://path/to/file.gd---` followed by the complete code.
Never use placeholder comments like "# TODO: implement this".
"""
