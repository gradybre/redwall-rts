# Redwall RTS — Project Instructions

## Overview
A Redwall-inspired RTS colony-builder built in Godot 4.x with GDScript.
Development is driven by a multi-agent LangGraph orchestrator that routes
tasks through Planning → Development → Review phases.

## Architecture
- **Orchestrator**: LangGraph pipeline (`orchestrator/graph.py`)
- **Agents**: Specialized LLM agents in `orchestrator/agents/`
- **Specs**: All design documents live in `docs/`
- **Game code**: Godot project in `godot/`
- **Tasks**: Sequential checklists in `docs/tasks/`

## Model Assignments
| Agent | Model | Provider |
|---|---|---|
| Orchestrator (Router) | Claude Sonnet | Anthropic |
| Architect | GPT-6 Astra | OpenAI |
| Economist | GPT-6 Astra | OpenAI |
| Systems Architect | Claude Opus | Anthropic |
| Coder | Claude Opus | Anthropic |
| QA Tester | Claude Sonnet | Anthropic |
| Blender MCP | Gemini Flash | Google |
| UI Reviewer | Gemini Pro | Google |
| PR Reviewer | Claude Opus | Anthropic |
| Release Manager | Gemini Flash | Google |

## Code Standards (GDScript)
- Full static typing on every variable and function
- Max function length: 30 lines
- ECS/Data-Oriented patterns — entities are IDs, components are data arrays
- Object pooling for transient entities
- No `await` in physics processing
- `@onready` for node refs, `@export` for inspector values

## Running the Pipeline
```bash
# Full pipeline
python -m orchestrator.main run "description" -f feature-name

# Planning only
python -m orchestrator.main run "description" -f feature-name -p planning

# Dry run (show structure)
python -m orchestrator.main run "description" -f feature-name --dry-run

# Check API key status
python -m orchestrator.main status
```

## VSCode Tasks
- `Cmd+Shift+B` → Run full pipeline
- Command Palette → "Tasks: Run Task" → select specific phase
