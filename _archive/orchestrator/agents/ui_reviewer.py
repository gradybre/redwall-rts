"""UI/UX Vision Reviewer agent — powered by Gemini Pro.

Evaluates HUD contrast, layout spacing, and visual hierarchy
against the UI/UX specification.
"""

from __future__ import annotations

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState
from .base import invoke_agent, load_prompt


async def ui_reviewer_node(state: PipelineState) -> dict:
    """LangGraph node: run the UI/UX Reviewer agent."""
    system_prompt = load_prompt("ui_reviewer")
    if not system_prompt:
        system_prompt = UI_REVIEWER_SYSTEM_PROMPT

    # Gather UI-related code
    ui_code = "\n\n".join(
        f"### {path}\n```gdscript\n{content}\n```"
        for path, content in state.code_files.items()
        if "ui/" in path or "hud" in path.lower() or "menu" in path.lower()
    )

    user_prompt = f"""## UI/UX Specification
{state.ui_ux_spec}

## UI Code Files
{ui_code or "(No UI code files found in this feature)"}

## All Code Files
{', '.join(state.code_files.keys())}

Review the UI implementation against the specification. Report:
1. **PASS** items that correctly implement the spec
2. **FAIL** items with specific violations and fix instructions
3. **WARN** items that technically pass but could be improved

Format as a structured report with severity levels.
"""

    result = await invoke_agent(
        role=ModelRole.UI_REVIEWER,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="ui_reviewer",
    )

    return {
        "results": state.results + [result],
        "ui_review": result.output if result.output else "",
    }


UI_REVIEWER_SYSTEM_PROMPT = """You are the UI/UX Vision Reviewer for a Redwall-inspired RTS colony-builder.

You verify that implemented UI code matches the UI/UX specification exactly.

## Review Checklist
- Screen zone anchoring matches spec (top-left resources, bottom-center commands)
- Font sizes meet minimum readability (14px base, 12px minimum for secondary)
- Color contrast ratios meet WCAG AA (4.5:1 for text, 3:1 for large text)
- Touch/click targets are minimum 44x44px
- HUD elements don't overlap at any supported resolution (1280x720 to 3840x2160)
- Progressive disclosure layers are correctly gated
- Hover/press/disabled states are all implemented
- Keyboard navigation order is logical

## Output Format
Structured report with PASS/FAIL/WARN per item. Each FAIL must include
the specific line of code and exact fix needed.
"""
