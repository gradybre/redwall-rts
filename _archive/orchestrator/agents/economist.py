"""Economy Mathematician agent — powered by GPT-6 Astra.

Generates strict balance tables governing production chains, asymmetric
timing ratios, and logarithmic wealth scaling.
"""

from __future__ import annotations

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState, AgentResult
from .base import invoke_agent, load_prompt, write_doc


async def economist_node(state: PipelineState) -> dict:
    """LangGraph node: run the Economy Mathematician agent."""
    system_prompt = load_prompt("economist")
    if not system_prompt:
        system_prompt = ECONOMIST_SYSTEM_PROMPT

    user_prompt = f"""## Feature Context
{state.task_description}

## GDD Reference
{state.gdd_content or "(Pending — design general balance tables)"}

## Existing Balance Data
{state.balance_tables or "(None yet)"}

Generate a comprehensive `gameplay_balance.md` with:
1. Resource production/consumption rates as Markdown tables
2. Building cost curves (linear, logarithmic, or exponential — justify the choice)
3. Unit timing ratios (e.g., 1 mill feeds N workshops)
4. Population scaling formulas
5. Combat balance ratios (if applicable to this feature)

Wrap the entire output in `---DOC:gameplay_balance.md---` delimiters.
"""

    result = await invoke_agent(
        role=ModelRole.ECONOMIST,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="economist",
    )

    files_created = []
    if result.output:
        # Extract document content
        content = result.output
        if "---DOC:gameplay_balance.md---" in content:
            start = content.index("---DOC:gameplay_balance.md---") + len("---DOC:gameplay_balance.md---")
            end = content.rfind("---DOC:") if content.rfind("---DOC:") > start else len(content)
            content = content[start:end].strip()

        path = write_doc("gameplay_balance.md", content)
        files_created.append(path)
        result.files_created = files_created

        return {
            "results": state.results + [result],
            "balance_tables": content,
        }

    return {"results": state.results + [result]}


ECONOMIST_SYSTEM_PROMPT = """You are the Economy Mathematician for a Redwall-inspired RTS colony-builder.

Your role is to generate mathematically rigorous balance tables and economic formulas
that govern every resource flow in the game. You prevent "infinite money" exploits
and ensure the economy creates meaningful strategic choices.

## Output Standards
- All production rates in units-per-second with 2 decimal precision
- Cost curves must include the formula AND a table of the first 10 levels
- Timing ratios must be asymmetric (not clean 1:1 ratios — use values like 1:2.3)
- Include a "stress test" section showing what happens at 100, 500, 1000 population
- Use logarithmic wealth scaling: wealth_at_level = base * ln(level + 1) * multiplier
- Every table must have a "Design Intent" column explaining WHY that value was chosen

## Format
Wrap all output in `---DOC:gameplay_balance.md---` delimiters.
Use Markdown tables. Include formulas in LaTeX-style notation where helpful.
"""
