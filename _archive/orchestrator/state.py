"""LangGraph state schema for the orchestrator pipeline."""

from __future__ import annotations

from enum import Enum
from typing import Annotated, Any

from pydantic import BaseModel, Field
from langgraph.graph.message import add_messages


class Phase(str, Enum):
    PLANNING = "planning"
    DEVELOPMENT = "development"
    REVIEW = "review"
    COMPLETE = "complete"


class TaskStatus(str, Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETE = "complete"
    FAILED = "failed"
    BLOCKED = "blocked"


class AgentResult(BaseModel):
    """Result from a single agent execution."""
    agent_name: str
    status: TaskStatus = TaskStatus.COMPLETE
    output: str = ""
    files_created: list[str] = Field(default_factory=list)
    files_modified: list[str] = Field(default_factory=list)
    errors: list[str] = Field(default_factory=list)


class PipelineState(BaseModel):
    """
    Central state object passed through the LangGraph pipeline.
    Every node reads from and writes to this shared state.
    """
    # ── Human input ──────────────────────────────────────────────
    task_description: str = ""
    feature_name: str = ""

    # ── Phase tracking ───────────────────────────────────────────
    current_phase: Phase = Phase.PLANNING
    completed_phases: list[Phase] = Field(default_factory=list)

    # ── Agent results (append-only log) ──────────────────────────
    results: list[AgentResult] = Field(default_factory=list)

    # ── Planning outputs ─────────────────────────────────────────
    gdd_content: str = ""
    ui_ux_spec: str = ""
    balance_tables: str = ""
    systems_spec: str = ""

    # ── Development outputs ──────────────────────────────────────
    code_files: dict[str, str] = Field(default_factory=dict)  # path -> content
    test_files: dict[str, str] = Field(default_factory=dict)
    asset_files: list[str] = Field(default_factory=list)  # paths to .glb etc.

    # ── Review outputs ───────────────────────────────────────────
    ui_review: str = ""
    code_review: str = ""
    commit_message: str = ""
    commit_sha: str = ""

    # ── Messages (for LangGraph message passing) ─────────────────
    messages: Annotated[list, add_messages] = Field(default_factory=list)

    # ── Error tracking ───────────────────────────────────────────
    errors: list[str] = Field(default_factory=list)
    retry_count: int = 0
    max_retries: int = 2
