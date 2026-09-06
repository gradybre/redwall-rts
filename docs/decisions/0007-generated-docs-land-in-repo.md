# 0007 — Externally generated documents are written into the repository
Date: 2026-09-06 · Status: Accepted

## Decision
Any document produced by an external model is saved into `docs/` in this
repository, not into a scratch or dated working directory.

## Why
`docs/crowd_rendering_architecture.md` was generated, then left in a dated Codex
directory. `docs/game_gdd.md` cited it in **six places** as an existing
authority while it was absent from the repository for a day. Work proceeded on a
dangling reference, and an architecture prompt was written telling the reader to
generate a document that already existed.

## Consequences
- `chatgpt-prompts/CODEX_01_build_remaining_docs.md` pins the working directory
  to the repository for exactly this reason.
- After any external generation run, confirm the output is in `docs/` **and
  committed** before building on it.
- If a document references another, check the referenced file exists.

## Source
Discovered 2026-09-05 when the crowd document was found at
`~/Documents/Codex/2026-09-05/i-am-building-a-woodland-rts/docs/`.
