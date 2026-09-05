"""PR Code Reviewer agent — powered by Claude Opus.

Audits code diffs for security issues, Godot anti-patterns, and memory leaks.
"""

from __future__ import annotations

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState
from .base import invoke_agent, load_prompt


async def pr_reviewer_node(state: PipelineState) -> dict:
    """LangGraph node: run the PR Code Reviewer agent."""
    system_prompt = load_prompt("pr_reviewer")
    if not system_prompt:
        system_prompt = PR_REVIEWER_SYSTEM_PROMPT

    # Build full code listing for review
    all_code = "\n\n".join(
        f"### {path}\n```gdscript\n{content}\n```"
        for path, content in {**state.code_files, **state.test_files}.items()
    )

    user_prompt = f"""## Feature
{state.feature_name}: {state.task_description}

## Systems Architecture (constraints to enforce)
{state.systems_spec}

## Code to Review
{all_code}

Perform a thorough code review. For each issue found, provide:
- **Severity**: CRITICAL / HIGH / MEDIUM / LOW
- **File**: exact file path
- **Line**: approximate line number or function name
- **Issue**: what's wrong
- **Fix**: exact code change needed

Also flag:
- Any deviation from the Systems Architecture spec
- Potential memory leaks (unfreed resources, orphaned nodes)
- GDScript anti-patterns (using `get_node()` in `_process`, etc.)
- Missing null checks on node references
- Signals connected but never disconnected (potential memory leak)
"""

    result = await invoke_agent(
        role=ModelRole.PR_REVIEWER,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="pr_reviewer",
    )

    return {
        "results": state.results + [result],
        "code_review": result.output if result.output else "",
    }


PR_REVIEWER_SYSTEM_PROMPT = """You are the PR Code Reviewer for a Redwall-inspired RTS colony-builder in Godot 4.x.

You are adversarial. Your job is to FIND PROBLEMS, not approve code.

## Review Priorities (in order)
1. **Memory safety**: Orphaned nodes, circular references, unfreed Resources
2. **Performance**: Operations in _process that should be event-driven, O(n^2) loops
3. **Architecture compliance**: Does the code follow the ECS/DOD spec?
4. **Type safety**: Missing type hints, implicit Any types, unsafe casts
5. **Error handling**: Unguarded node access, missing null checks
6. **Code quality**: DRY violations, functions > 30 lines, unclear naming

## Godot-Specific Anti-Patterns to Flag
- `get_node()` calls in `_process()` or `_physics_process()` (use @onready)
- `await` in `_physics_process()`
- Connecting signals without disconnecting on `_exit_tree()`
- Using `String` concatenation in hot loops (use StringName)
- Creating new objects in `_process()` (use object pooling)
- Node tree queries that could be replaced by direct references

## Output Format
If no issues found, say "LGTM" with a brief summary of what you checked.
Otherwise, list all issues with severity/file/line/issue/fix structure.
"""
