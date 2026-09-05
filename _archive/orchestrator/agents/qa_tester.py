"""QA Tester agent — powered by Claude Sonnet.

Generates unit tests and runs headless validation against Godot.
"""

from __future__ import annotations

import re

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState
from .base import invoke_agent, load_prompt, write_code


async def qa_tester_node(state: PipelineState) -> dict:
    """LangGraph node: run the QA Tester agent."""
    system_prompt = load_prompt("qa_tester")
    if not system_prompt:
        system_prompt = QA_SYSTEM_PROMPT

    # Build a summary of all code files for the tester to review
    code_summary = "\n\n".join(
        f"### {path}\n```gdscript\n{content}\n```"
        for path, content in state.code_files.items()
    )

    user_prompt = f"""## Feature Under Test
{state.feature_name}: {state.task_description}

## Systems Architecture
{state.systems_spec}

## Balance Constraints
{state.balance_tables}

## Code to Test
{code_summary}

Generate GUT (Godot Unit Testing) test files for all code above.
Use `# ---FILE:res://test/path/test_name.gd---` delimiters.

Focus on:
1. Boundary conditions from the balance tables
2. ECS component data integrity
3. System update order dependencies
4. Resource production/consumption rate accuracy
5. Edge cases: zero population, max capacity, negative values
"""

    result = await invoke_agent(
        role=ModelRole.QA_TESTER,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="qa_tester",
    )

    test_files = {}
    files_created = []

    if result.output:
        pattern = r"#\s*---FILE:(.*?)---\s*\n(.*?)(?=#\s*---FILE:|$)"
        matches = re.findall(pattern, result.output, re.DOTALL)
        for filepath, content in matches:
            filepath = filepath.strip()
            if filepath.startswith("res://"):
                filepath = filepath[6:]
            test_files[filepath] = content.strip()
            full_path = write_code(filepath, content.strip(), project_root="./godot")
            files_created.append(full_path)

        result.files_created = files_created

        return {
            "results": state.results + [result],
            "test_files": {**state.test_files, **test_files},
        }

    return {"results": state.results + [result]}


QA_SYSTEM_PROMPT = """You are the QA Tester for a Redwall-inspired RTS colony-builder in Godot 4.x.

You write tests using the GUT (Godot Unit Test) framework.

## Test Standards
- One test file per system/module
- Test file naming: `test_<module_name>.gd`
- Every test function starts with `test_`
- Use `assert_eq`, `assert_true`, `assert_almost_eq` (for floats, with epsilon)
- Test setup in `before_each()`, teardown in `after_each()`
- Include stress tests for performance-sensitive systems

## Coverage Requirements
- Every public function must have at least one test
- Balance table values must have boundary tests
- ECS systems must test component queries return correct entities
- Resource flows must verify conservation (nothing created from nothing)

## Output Format
Use `# ---FILE:res://test/path/test_name.gd---` delimiters.
"""
