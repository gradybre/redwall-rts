"""Release Manager agent — powered by Gemini Flash.

Generates semantic commit messages, updates task checklists,
and prepares git operations.
"""

from __future__ import annotations

from orchestrator.config import ModelRole
from orchestrator.state import PipelineState
from .base import invoke_agent, load_prompt


async def release_manager_node(state: PipelineState) -> dict:
    """LangGraph node: run the Release Manager agent."""
    system_prompt = load_prompt("release_manager")
    if not system_prompt:
        system_prompt = RELEASE_MANAGER_SYSTEM_PROMPT

    # Collect all files that were created or modified
    all_files_created = []
    all_files_modified = []
    for r in state.results:
        all_files_created.extend(r.files_created)
        all_files_modified.extend(r.files_modified)

    # Gather review summaries
    reviews = f"""## UI Review Summary
{state.ui_review or "(No UI review)"}

## Code Review Summary
{state.code_review or "(No code review)"}
"""

    user_prompt = f"""## Feature
{state.feature_name}: {state.task_description}

## Files Created
{chr(10).join(f"- {f}" for f in all_files_created) or "None"}

## Files Modified
{chr(10).join(f"- {f}" for f in all_files_modified) or "None"}

{reviews}

Generate:
1. A semantic commit message following Conventional Commits format
   (feat/fix/refactor/docs/test scope)
2. A list of git commands to stage and commit these changes
3. Updated task checklist entries (mark completed items with [x])

Output in this exact format:
---COMMIT_MESSAGE---
<the commit message>
---GIT_COMMANDS---
<git add/commit commands, one per line>
---TASK_UPDATES---
<checklist updates>
"""

    result = await invoke_agent(
        role=ModelRole.RELEASE_MANAGER,
        system_prompt=system_prompt,
        user_prompt=user_prompt,
        agent_name="release_manager",
    )

    commit_message = ""
    if result.output and "---COMMIT_MESSAGE---" in result.output:
        parts = result.output.split("---COMMIT_MESSAGE---")
        if len(parts) > 1:
            msg_part = parts[1].split("---GIT_COMMANDS---")[0] if "---GIT_COMMANDS---" in parts[1] else parts[1]
            commit_message = msg_part.strip()

    return {
        "results": state.results + [result],
        "commit_message": commit_message,
    }


RELEASE_MANAGER_SYSTEM_PROMPT = """You are the Release Manager for a Redwall-inspired RTS colony-builder.

You handle git operations and task tracking. You are precise and mechanical.

## Commit Message Format (Conventional Commits)
```
<type>(<scope>): <short summary>

<body — what changed and why>

Refs: <task checklist reference>
```

Types: feat, fix, refactor, docs, test, chore, perf
Scope: the game system affected (economy, combat, ui, pathfinding, etc.)

## Rules
- One commit per feature/task (squash if multiple files)
- Never commit files with review CRITICAL issues unresolved
- Stage only the files listed — never `git add .`
- Include file count in commit body: "Added N files, modified M files"
"""
