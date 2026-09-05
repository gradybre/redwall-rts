"""CLI entry point for the Redwall RTS Orchestrator."""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

import click
from dotenv import load_dotenv
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.live import Live
from rich.text import Text

from orchestrator.graph import compile_graph
from orchestrator.state import PipelineState, Phase, TaskStatus

console = Console()


def _phase_color(phase: Phase) -> str:
    return {
        Phase.PLANNING: "cyan",
        Phase.DEVELOPMENT: "yellow",
        Phase.REVIEW: "magenta",
        Phase.COMPLETE: "green",
    }.get(phase, "white")


def _status_icon(status: TaskStatus) -> str:
    return {
        TaskStatus.PENDING: "[dim][ ][/dim]",
        TaskStatus.IN_PROGRESS: "[yellow][~][/yellow]",
        TaskStatus.COMPLETE: "[green][x][/green]",
        TaskStatus.FAILED: "[red][!][/red]",
        TaskStatus.BLOCKED: "[dim][-][/dim]",
    }.get(status, "[ ]")


def _render_state(state: PipelineState) -> Table:
    """Render pipeline state as a Rich table."""
    table = Table(title="Redwall RTS Pipeline", show_header=True, border_style="dim")
    table.add_column("Agent", style="bold")
    table.add_column("Status")
    table.add_column("Files")
    table.add_column("Errors")

    for r in state.results:
        status_style = "green" if r.status == TaskStatus.COMPLETE else "red"
        table.add_row(
            r.agent_name,
            f"[{status_style}]{r.status.value}[/{status_style}]",
            str(len(r.files_created)),
            str(len(r.errors)) if r.errors else "-",
        )

    return table


@click.group()
def cli():
    """Redwall RTS Multi-Agent Orchestrator."""
    load_dotenv()


@cli.command()
@click.argument("task_description")
@click.option("--feature", "-f", required=True, help="Feature name (e.g., 'resource-gathering')")
@click.option("--phase", "-p", type=click.Choice(["all", "planning", "development", "review"]), default="all")
@click.option("--dry-run", is_flag=True, help="Show what would run without executing")
def run(task_description: str, feature: str, phase: str, dry_run: bool):
    """Run the orchestrator pipeline for a feature."""
    console.print(Panel(
        f"[bold]Feature:[/bold] {feature}\n"
        f"[bold]Task:[/bold] {task_description}\n"
        f"[bold]Phase:[/bold] {phase}",
        title="[bold cyan]Redwall RTS Orchestrator[/bold cyan]",
        border_style="cyan",
    ))

    if dry_run:
        console.print("\n[dim]Dry run — showing pipeline structure:[/dim]")
        _show_pipeline_structure()
        return

    asyncio.run(_run_pipeline(task_description, feature, phase))


async def _run_pipeline(task_description: str, feature: str, phase: str):
    """Execute the pipeline asynchronously."""
    graph = compile_graph()

    initial_state = PipelineState(
        task_description=task_description,
        feature_name=feature,
    )

    console.print("\n[bold cyan]Starting pipeline...[/bold cyan]\n")

    # Stream through the graph, printing updates
    final_state = None
    async for event in graph.astream(initial_state.model_dump(), stream_mode="updates"):
        for node_name, node_output in event.items():
            if node_name.startswith("__"):
                continue
            console.print(f"  [dim]>[/dim] [bold]{node_name}[/bold] completed")

            # Show any new results
            if "results" in node_output:
                for r in node_output["results"]:
                    if isinstance(r, dict):
                        status = r.get("status", "complete")
                        files = r.get("files_created", [])
                    else:
                        status = r.status.value
                        files = r.files_created

                    if files:
                        for f in files:
                            console.print(f"    [green]+[/green] {f}")

            # Track phase transitions
            if "current_phase" in node_output:
                phase_val = node_output["current_phase"]
                if isinstance(phase_val, str):
                    phase_val = Phase(phase_val)
                color = _phase_color(phase_val)
                console.print(f"\n  [bold {color}]>>> Entering {phase_val.value.upper()} phase <<<[/bold {color}]\n")

        final_state = node_output

    # Print summary
    console.print("\n")
    console.print(Panel(
        "[bold green]Pipeline complete[/bold green]" if not (final_state or {}).get("errors")
        else f"[bold red]Pipeline failed[/bold red]\n{chr(10).join((final_state or {}).get('errors', []))}",
        title="Result",
        border_style="green" if not (final_state or {}).get("errors") else "red",
    ))


def _show_pipeline_structure():
    """Print the pipeline structure without running it."""
    phases = {
        "Phase 1: Planning": [
            ("Architect", "GPT-6 Astra", "Game design docs, UI/UX specs"),
            ("Economist", "GPT-6 Astra", "Balance tables, production chains"),
            ("Systems Architect", "Claude Opus", "ECS design, performance budgets"),
        ],
        "Phase 2: Development": [
            ("Coder", "Claude Opus", "GDScript implementation"),
            ("QA Tester", "Claude Sonnet", "GUT test generation"),
        ],
        "Phase 3: Review & Commit": [
            ("UI Reviewer", "Gemini Pro", "HUD/layout validation"),
            ("PR Reviewer", "Claude Opus", "Security & anti-pattern audit"),
            ("Release Manager", "Gemini Flash", "Semantic commits, task sync"),
        ],
    }

    for phase_name, agents in phases.items():
        table = Table(title=phase_name, show_header=True, border_style="dim")
        table.add_column("Agent", style="bold")
        table.add_column("Model", style="cyan")
        table.add_column("Output")

        for name, model, output in agents:
            table.add_row(name, model, output)

        console.print(table)
        console.print()


@cli.command()
def status():
    """Show the current pipeline configuration and API key status."""
    import os
    load_dotenv()

    table = Table(title="API Key Status", show_header=True)
    table.add_column("Provider")
    table.add_column("Status")

    for name, env_var in [
        ("Anthropic (Claude)", "ANTHROPIC_API_KEY"),
        ("OpenAI (Astra)", "OPENAI_API_KEY"),
        ("Google (Gemini)", "GOOGLE_API_KEY"),
    ]:
        key = os.environ.get(env_var, "")
        if key and len(key) > 10:
            table.add_row(name, f"[green]Configured[/green] ({key[:8]}...)")
        else:
            table.add_row(name, "[red]Missing[/red]")

    console.print(table)


@cli.command()
def agents():
    """List all agents and their model assignments."""
    _show_pipeline_structure()


if __name__ == "__main__":
    cli()
