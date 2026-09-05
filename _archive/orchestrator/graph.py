"""
LangGraph orchestration graph for the Redwall RTS pipeline.

Three phases:
  Phase 1 (Planning):    Architect → Economist → Systems Architect
  Phase 2 (Development): Coder → QA Tester
  Phase 3 (Review):      UI Reviewer + PR Reviewer → Release Manager
"""

from __future__ import annotations

from langgraph.graph import StateGraph, START, END

from orchestrator.state import PipelineState, Phase, TaskStatus
from orchestrator.agents import (
    architect_node,
    economist_node,
    systems_node,
    coder_node,
    qa_tester_node,
    ui_reviewer_node,
    pr_reviewer_node,
    release_manager_node,
)


# ── Routing functions ──────────────────────────────────────────────

def route_after_planning(state: PipelineState) -> str:
    """Check if planning phase produced viable specs before moving to dev."""
    planning_results = [r for r in state.results if r.agent_name in ("architect", "economist", "systems_architect")]
    failures = [r for r in planning_results if r.status == TaskStatus.FAILED]

    if failures and state.retry_count < state.max_retries:
        return "retry_planning"
    elif failures:
        return "abort"
    return "development"


def route_after_development(state: PipelineState) -> str:
    """Check if code was generated before review."""
    if not state.code_files:
        dev_results = [r for r in state.results if r.agent_name == "coder"]
        if dev_results and dev_results[-1].status == TaskStatus.FAILED:
            if state.retry_count < state.max_retries:
                return "retry_development"
            return "abort"
    return "review"


def route_after_review(state: PipelineState) -> str:
    """Check if reviews passed or need fixes."""
    # If code review has CRITICAL issues, loop back to coder
    if state.code_review and "CRITICAL" in state.code_review:
        if state.retry_count < state.max_retries:
            return "fix_code"
    return "release"


# ── Phase transition nodes ─────────────────────────────────────────

async def enter_development(state: PipelineState) -> dict:
    """Transition marker: planning complete, entering development."""
    return {
        "current_phase": Phase.DEVELOPMENT,
        "completed_phases": state.completed_phases + [Phase.PLANNING],
        "retry_count": 0,
    }


async def enter_review(state: PipelineState) -> dict:
    """Transition marker: development complete, entering review."""
    return {
        "current_phase": Phase.REVIEW,
        "completed_phases": state.completed_phases + [Phase.DEVELOPMENT],
        "retry_count": 0,
    }


async def mark_complete(state: PipelineState) -> dict:
    """Transition marker: pipeline complete."""
    return {
        "current_phase": Phase.COMPLETE,
        "completed_phases": state.completed_phases + [Phase.REVIEW],
    }


async def increment_retry(state: PipelineState) -> dict:
    """Increment the retry counter."""
    return {"retry_count": state.retry_count + 1}


async def abort_pipeline(state: PipelineState) -> dict:
    """Mark pipeline as failed after exhausting retries."""
    return {
        "errors": state.errors + ["Pipeline aborted: max retries exceeded"],
    }


# ── Build the graph ────────────────────────────────────────────────

def build_graph() -> StateGraph:
    """Construct the full orchestration graph."""
    graph = StateGraph(PipelineState)

    # ── Phase 1: Planning ──────────────────────────────────────
    graph.add_node("architect", architect_node)
    graph.add_node("economist", economist_node)
    graph.add_node("systems_architect", systems_node)

    # ── Phase transitions ──────────────────────────────────────
    graph.add_node("enter_development", enter_development)
    graph.add_node("enter_review", enter_review)
    graph.add_node("mark_complete", mark_complete)
    graph.add_node("increment_retry", increment_retry)
    graph.add_node("abort", abort_pipeline)

    # ── Phase 2: Development ───────────────────────────────────
    graph.add_node("coder", coder_node)
    graph.add_node("qa_tester", qa_tester_node)

    # ── Phase 3: Review ────────────────────────────────────────
    graph.add_node("ui_reviewer", ui_reviewer_node)
    graph.add_node("pr_reviewer", pr_reviewer_node)
    graph.add_node("release_manager", release_manager_node)

    # ── Edges: Phase 1 (sequential planning) ───────────────────
    graph.add_edge(START, "architect")
    graph.add_edge("architect", "economist")
    graph.add_edge("economist", "systems_architect")

    # ── Routing: after planning ────────────────────────────────
    graph.add_conditional_edges(
        "systems_architect",
        route_after_planning,
        {
            "development": "enter_development",
            "retry_planning": "increment_retry",
            "abort": "abort",
        },
    )
    # Retry loops back to architect
    graph.add_edge("increment_retry", "architect")

    # ── Edges: Phase 2 (sequential dev) ────────────────────────
    graph.add_edge("enter_development", "coder")
    graph.add_edge("coder", "qa_tester")

    # ── Routing: after development ─────────────────────────────
    graph.add_conditional_edges(
        "qa_tester",
        route_after_development,
        {
            "review": "enter_review",
            "retry_development": "coder",
            "abort": "abort",
        },
    )

    # ── Edges: Phase 3 (parallel review, then release) ─────────
    # UI and PR review run in parallel (both start from enter_review)
    graph.add_edge("enter_review", "ui_reviewer")
    graph.add_edge("enter_review", "pr_reviewer")

    # Both reviews must complete before release manager
    graph.add_edge("ui_reviewer", "release_manager")
    graph.add_edge("pr_reviewer", "release_manager")

    # ── Routing: after review ──────────────────────────────────
    graph.add_conditional_edges(
        "release_manager",
        route_after_review,
        {
            "release": "mark_complete",
            "fix_code": "coder",
        },
    )

    # ── Terminal nodes ─────────────────────────────────────────
    graph.add_edge("mark_complete", END)
    graph.add_edge("abort", END)

    return graph


def compile_graph():
    """Compile the graph into a runnable."""
    graph = build_graph()
    return graph.compile()
