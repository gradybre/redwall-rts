# 0126 — The tool gate gets an `_into` form, and the alias rules stop being copied
Date: 2026-09-12 · Status: Accepted

## Decision

Two cross-lane blockers, closed in the two files that own them.

1. **`jobs.tool_gate_into(job_slot, out) -> bool`** is published, and
   `tool_gate_of()` is rewritten as a delegation to it. Decision 0110 named the
   allocating reader as the reason `work.gd` cannot consult §5.3's tool gate on
   the productive tick.
2. **`command_dispatch._alias_refusal()` no longer holds the name rules.** It
   asks `Residents.name_refusal()` — the one resident-owned validator from
   decision 0112 — and maps the answer onto this layer's `RESULT_ALIAS_*`
   vocabulary in `_alias_result_for()`.

## Why

**The gate.** `work.gd` reads the gate once per contributor per productive tick.
An `IntResult` per call on that path is exactly what AGENTS.md's
no-allocation-on-hot-paths rule forbids, so the gate was simply not read and a
tool-required job whose worker held no binding produced work and wore nothing.
The `_into` form is the established shape here: caller-owned result, explicit
refusal on an invalid slot or an absent row, and a `false` return the caller must
not read as a valid zero. That last point carries weight for this column in
particular: `GATE_NOT_REQUIRED` **is** 0, so "this job needs no tool" and "there
is no job in that row" would be the same answer under a sentinel, and they are
opposite instructions to the settlement code.

`tool_gate_of()` delegates rather than repeating the column read, so the two
forms cannot drift into different validation orders or different refusal codes.
The older `*_of()`/`*_into()` pairs in `jobs.gd` still read their column twice
through the shared `_read()` helper; converting them is a separate change and is
deliberately not made here.

**The alias.** `_alias_refusal()` was a second copy of ARCH-SAVE-005's rules and
the copy had drifted: its control test was `code_point < 32 or code_point == 127`
and it missed the C1 block U+0080..009F entirely. The severity is precise, and it
decides how this is tested. **No invalid name reached a column** — since decision
0112 `set_name()` validates through `name_refusal()`, so a C1 alias was refused
either way. What the player got was `COMMAND_STORE_REFUSED` (result id 13)
instead of `COMMAND_ALIAS_CONTROL_CHARACTER` (result id 0): the right outcome
with the wrong reason. The tests therefore assert the **code**, not that a
refusal happened, because both spellings refuse.

Three traps are inherited by delegating rather than reimplementing, and each is
pinned by a test at this layer:

* **Scalar length is not byte length and not grapheme-cluster count.** 32 astral
  scalars are 128 bytes and are admitted; 17 `e`+U+0301 pairs are 17 clusters, 34
  scalars, and are refused.
* **Nothing is normalized, truncated or replaced.** An over-long alias is a
  refusal, and an accepted decomposed alias is stored scalar-for-scalar.
* **The control test is an explicit integer predicate**, not an engine Unicode
  category lookup — that predicate lives in `residents.gd` and this layer no
  longer has one at all.

What stays in `command_dispatch.gd` is the one rule that is about the **wire**
rather than the name: the decoded alias must re-encode to the byte count the
command declared. Godot's decoder substitutes U+FFFD rather than failing, and
U+FFFD is a legal name scalar, so no name validator can see that the payload was
malformed — only the round trip can. `ALIAS_MAX_BYTES` is now taken from
`ResidentsScript.NAME_MAX_UTF8_BYTES` so the pre-decode ceiling cannot disagree
with the store's.

An **unrecognised** resident refusal code is not guessed at. It is returned as
`RESULT_STORE_REFUSED` with the store's own code preserved in
`_result_store_code`, so a sixth name rule added later reports honestly instead
of being mapped onto a plausible-looking neighbour.

## Consequences

* `work.gd` can now read the gate per tick. **It does not yet.** That file is not
  this change's to edit; its header and one test still record the unenforced
  gate, and updating both is the EH-03 owner's change.
* A third copy of the length rule survives in `godot/scripts/ui/ui_command_bridge.gd`
  (`ALIAS_MIN_CHARACTERS`/`ALIAS_MAX_CHARACTERS`, a pre-submit length check with
  no control-character rule at all). It is not on this change's allowlist. It is
  a UI pre-filter rather than an admission gate, so nothing invalid passes
  because of it, but it should be folded into `name_refusal()` by that file's
  owner.
* `command_dispatch.gd` no longer defines `ALIAS_MIN_CHARACTERS`,
  `ALIAS_MAX_CHARACTERS`, `ASCII_SPACE` or `ASCII_DELETE`. Nothing outside that
  file referenced them; `test_command_dispatch.gd` transcribes the bounds itself
  from ARCH-SAVE-005, which is the point.
* **No new packed column, so no ledger or registry row is owed by this change.**
  `tool_gate_into()` reads the existing `_tool_gate` byte column and the alias
  fold-in deletes code. `state_registry_coverage.py` is unchanged at 47 modules,
  326 rows, 648 packed columns.
* The alias half **depends on decision 0112's `name_refusal()`**, which landed on
  master as 98074fd while this change was in flight. This branch is rebased onto
  it; the alias half does not compile on anything earlier.

## Source

* Decision 0110, "What this does not establish" — the gate reader's allocation,
  named as the blocker.
* Decision 0112 / NAME-R02 — `name_refusal()` as the single validator, and the
  three traps it names.
* ARCH-SAVE-005 — "Player aliases are 2-32 Unicode characters with control
  characters rejected".
* AGENTS.md — no allocation on hot paths; never return a sentinel to signal
  failure.
