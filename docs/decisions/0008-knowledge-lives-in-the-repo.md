# 0008 — Project knowledge lives in the repository, not in one assistant
Date: 2026-09-06 · Status: Accepted

## Decision
Anything a future contributor — human or model — would need must exist in this
repository. Assistant-private memory may hold a **pointer** to it, never the
only copy.

## Why
A full day of work produced decisions that existed only in a chat transcript.
The Claude memory directory for this project was **empty**. Codex, and any other
model, could see none of it. Meanwhile `AGENTS.md` and `CLAUDE.md` in a sibling
project had already drifted apart, showing that duplicating the same content
into two files does not survive contact with real editing.

## Consequences
- `AGENTS.md` is the model-agnostic entry point and names the canonical sources.
  It carries the non-negotiables inline and **points** to detail rather than
  duplicating it.
- `docs/decisions/` records decisions. `docs/ENVIRONMENT.md` records toolchain
  facts and working commands.
- **A decision is not made until it is written here.** Recording it is part of
  the work, not follow-up.
- Assistant memory files should contain pointers to these paths, so a fresh
  session is told where to look rather than carrying a stale second copy.

## Source
User instruction, 2026-09-06.
