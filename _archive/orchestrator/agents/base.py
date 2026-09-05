"""Base utilities shared by all agents."""

from __future__ import annotations

import os
from pathlib import Path

from langchain_core.messages import SystemMessage, HumanMessage

from orchestrator.config import ModelRole, get_llm
from orchestrator.state import AgentResult, TaskStatus


def load_prompt(prompt_name: str) -> str:
    """Load a prompt template from the prompts/ directory."""
    prompt_path = Path(__file__).parent.parent / "prompts" / f"{prompt_name}.md"
    if prompt_path.exists():
        return prompt_path.read_text()
    return ""


def read_doc(doc_name: str, docs_path: str = "./docs") -> str:
    """Read a document from the project docs/ directory."""
    doc_path = Path(docs_path) / doc_name
    if doc_path.exists():
        return doc_path.read_text()
    return ""


def write_doc(doc_name: str, content: str, docs_path: str = "./docs") -> str:
    """Write a document to the project docs/ directory."""
    doc_path = Path(docs_path) / doc_name
    doc_path.parent.mkdir(parents=True, exist_ok=True)
    doc_path.write_text(content)
    return str(doc_path)


def write_code(file_path: str, content: str, project_root: str = ".") -> str:
    """Write a code file to the project."""
    full_path = Path(project_root) / file_path
    full_path.parent.mkdir(parents=True, exist_ok=True)
    full_path.write_text(content)
    return str(full_path)


async def invoke_agent(
    role: ModelRole,
    system_prompt: str,
    user_prompt: str,
    agent_name: str,
) -> AgentResult:
    """
    Invoke an LLM with the given role and prompts.
    Returns a structured AgentResult.
    """
    llm = get_llm(role)
    try:
        response = await llm.ainvoke([
            SystemMessage(content=system_prompt),
            HumanMessage(content=user_prompt),
        ])
        return AgentResult(
            agent_name=agent_name,
            status=TaskStatus.COMPLETE,
            output=response.content,
        )
    except Exception as e:
        return AgentResult(
            agent_name=agent_name,
            status=TaskStatus.FAILED,
            errors=[str(e)],
        )
