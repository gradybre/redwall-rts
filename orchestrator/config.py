"""Model configuration and provider setup for the multi-agent orchestrator."""

from __future__ import annotations

import os
from dataclasses import dataclass
from enum import Enum

from dotenv import load_dotenv
from langchain_anthropic import ChatAnthropic
from langchain_openai import ChatOpenAI
from langchain_google_genai import ChatGoogleGenerativeAI

load_dotenv()


class ModelRole(str, Enum):
    """Which model to use for each agent role."""
    ORCHESTRATOR = "orchestrator"
    ARCHITECT = "architect"
    ECONOMIST = "economist"
    SYSTEMS = "systems"
    CODER = "coder"
    QA_TESTER = "qa_tester"
    BLENDER = "blender"
    UI_REVIEWER = "ui_reviewer"
    PR_REVIEWER = "pr_reviewer"
    RELEASE_MANAGER = "release_manager"


@dataclass
class ModelSpec:
    """Specification for a model assignment."""
    provider: str  # "anthropic", "openai", "google"
    model_id: str
    temperature: float = 0.2
    max_tokens: int = 8192


# ── Model assignments ──────────────────────────────────────────────
# GPT-6 Astra: frontier reasoning — architect & economy design
# Claude Opus: code generation, review, systems architecture
# Claude Sonnet: fast routing, QA
# Gemini Flash/Pro: lightweight tasks, UI checks, git ops

MODEL_MAP: dict[ModelRole, ModelSpec] = {
    ModelRole.ORCHESTRATOR: ModelSpec("anthropic", "claude-sonnet-4-20250514", temperature=0.0, max_tokens=4096),
    ModelRole.ARCHITECT: ModelSpec("openai", "gpt-6-astra", temperature=0.3, max_tokens=16384),
    ModelRole.ECONOMIST: ModelSpec("openai", "gpt-6-astra", temperature=0.1, max_tokens=16384),
    ModelRole.SYSTEMS: ModelSpec("anthropic", "claude-opus-4-20250514", temperature=0.2, max_tokens=12288),
    ModelRole.CODER: ModelSpec("anthropic", "claude-opus-4-20250514", temperature=0.1, max_tokens=16384),
    ModelRole.QA_TESTER: ModelSpec("anthropic", "claude-sonnet-4-20250514", temperature=0.1, max_tokens=8192),
    ModelRole.BLENDER: ModelSpec("google", "gemini-2.0-flash", temperature=0.2, max_tokens=8192),
    ModelRole.UI_REVIEWER: ModelSpec("google", "gemini-2.0-pro", temperature=0.2, max_tokens=8192),
    ModelRole.PR_REVIEWER: ModelSpec("anthropic", "claude-opus-4-20250514", temperature=0.0, max_tokens=12288),
    ModelRole.RELEASE_MANAGER: ModelSpec("google", "gemini-2.0-flash", temperature=0.0, max_tokens=4096),
}


def get_llm(role: ModelRole):
    """Instantiate the correct LLM for a given agent role."""
    spec = MODEL_MAP[role]

    if spec.provider == "anthropic":
        return ChatAnthropic(
            model=spec.model_id,
            temperature=spec.temperature,
            max_tokens=spec.max_tokens,
            api_key=os.environ["ANTHROPIC_API_KEY"],
        )
    elif spec.provider == "openai":
        return ChatOpenAI(
            model=spec.model_id,
            temperature=spec.temperature,
            max_tokens=spec.max_tokens,
            api_key=os.environ["OPENAI_API_KEY"],
        )
    elif spec.provider == "google":
        return ChatGoogleGenerativeAI(
            model=spec.model_id,
            temperature=spec.temperature,
            max_output_tokens=spec.max_tokens,
            google_api_key=os.environ["GOOGLE_API_KEY"],
        )
    else:
        raise ValueError(f"Unknown provider: {spec.provider}")
