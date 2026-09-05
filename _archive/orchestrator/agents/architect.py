"""Game Design & UX Architect agent — powered by GPT-6 Astra.

Translates high-level concepts into structured GDD specs, UI/UX control
schemes, and progressive disclosure maps using EARS notation.
"""

from __future__ import annotations

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState, AgentResult
from .base import invoke_agent, load_prompt, write_doc


async def architect_node(state: PipelineState) -> dict:
    """LangGraph node: run the Architect agent."""
    system_prompt = load_prompt("architect")
    if not system_prompt:
        system_prompt = ARCHITECT_SYSTEM_PROMPT

    user_prompt = f"""## Feature Request
{state.task_description}

## Feature Name
{state.feature_name}

## Existing GDD Context
{state.gdd_content or "(No existing GDD — create from scratch)"}

Generate the following documents:
1. **Game Design Document section** (EARS notation, progressive disclosure)
2. **UI/UX Controls specification** (screen zones, input mapping, HUD layout)

Output each document in a clearly delimited section with `---DOC:filename.md---` headers.
"""

    result = await invoke_agent(
        role=ModelRole.ARCHITECT,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="architect",
    )

    # Parse and save documents from the response
    files_created = []
    if result.output:
        sections = _parse_doc_sections(result.output)
        for filename, content in sections.items():
            path = write_doc(filename, content)
            files_created.append(path)
        result.files_created = files_created

        # Update state with document contents
        updates = {"results": state.results + [result]}
        if "game_gdd.md" in sections:
            updates["gdd_content"] = sections["game_gdd.md"]
        if "ui_ux_controls.md" in sections:
            updates["ui_ux_spec"] = sections["ui_ux_controls.md"]
        return updates

    return {"results": state.results + [result]}


def _parse_doc_sections(output: str) -> dict[str, str]:
    """Parse agent output into named document sections."""
    sections = {}
    current_file = None
    current_lines = []

    for line in output.split("\n"):
        if line.startswith("---DOC:") and line.endswith("---"):
            if current_file and current_lines:
                sections[current_file] = "\n".join(current_lines).strip()
            current_file = line.replace("---DOC:", "").replace("---", "").strip()
            current_lines = []
        elif current_file is not None:
            current_lines.append(line)

    if current_file and current_lines:
        sections[current_file] = "\n".join(current_lines).strip()

    return sections


ARCHITECT_SYSTEM_PROMPT = """You are the Game Design & UX Architect for a Redwall-inspired RTS colony-builder.

Your role is to translate high-level game concepts into exhaustive, structured specifications
that leave ZERO room for ambiguity or "handwaving" by downstream coding agents.

## Output Standards
- Use EARS (Easy Approach to Requirements Syntax) notation for all requirements
- Define progressive disclosure layers (what the player sees at minute 1 vs hour 10)
- Map screen zone anchoring (top-left = resources, bottom-center = unit commands, etc.)
- Specify control schemes for mouse, keyboard, and gamepad
- All measurements in Godot-native units (pixels for UI, world units for gameplay)

## Document Format
Output each document with a `---DOC:filename.md---` header. You must produce:
1. `game_gdd.md` — The Game Design Document section for this feature
2. `ui_ux_controls.md` — UI/UX controls and layout specification

Be exhaustive. Every UI element needs: position, size constraints, font sizes,
color tokens, hover/press states, and accessibility considerations.
"""
