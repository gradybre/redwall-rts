# 1241 — Merging master renumbers the branch's DEC-058 (tread fitting) to DEC-060
Date: 2026-10-09 · Status: Accepted

## Decision
When `origin/master` (merge-base `82d60ba8`, 137 commits) was merged into `claude/ug-paid-start` so draft PR #241
could merge, one user-decision number collided: both sides had written a `DEC-058` into `docs/setting_decisions.md`.
Master's stands; the branch's moved to the next free number.

| Old (branch, before the merge) | New | Entry |
|---|---|---|
| DEC-058 | **DEC-060** | Treads are fitted with a general paw working motion; exact contact not required (ADR 1217 step 2d, ADR 1209, ADR 1229) |
| — | DEC-058 (unchanged, master) | Every feast is served at the 17:00 supper (ADR 1701) |

No other number collided: the branch's DEC-050…DEC-057 and DEC-059 are not used on master, and its ADRs
(up to 1240) do not overlap master's (1601…1742). `docs/validation/decision_numbers.py` passes on the merge.

## Why
Master's DEC-058 was already published on the default branch and cited from the GDD (REQ-SET-103's amendment
anchor), the balance and UI docs, the handoff rulings and the demo's feast code; renumbering it would break
published links. The branch's entry was unpublished (draft PR). Renumbering only the colliding entry, not the
branch's whole run, keeps every other citation valid.

## Consequences
- Branch references to the tread-fitting decision now read DEC-060: ADRs 1209, 1217 and 1229, the stairs
  publication's generator and manifests (`publish_qualified_stairs.py`, `qualified-stairs-v7/v8/v9/manifest.json`),
  and code comments in `underground_profiles.gd`, `underground_entry_frontier.gd`,
  `underground_connector_contacts.gd` and the qualified-claw runtime scripts. The edited comments changed pinned
  consumer scripts, so their source pins, the memory census and the checkpoints were regenerated in the merge.
- **Deliberately left reading DEC-058:** the committed review evidence under
  `mole-worker/claw-work-v1/evidence/` (`claw-turn-review-v1`, `tread-fit-review-v1`) and the four generator and
  prover scripts whose SHA-256 that evidence records (`derive_stair_rows.py`, `native_claw_stairs.py`,
  `prove_tread_step_back.py`, `publish_claw_stairs_runtime.py`). Editing them would break the recorded provenance of
  evidence produced before the merge; there, DEC-058 means DEC-060 by this record.
- A "DEC-058" in a transcript, commit message or review packet written before 2026-10-09 on this branch means
  **DEC-060**. A "DEC-058" anywhere on master, or after the merge, means the feast supper.
- `docs/setting_decisions.md` now orders DEC-057, DEC-058 (feast), DEC-059, DEC-060 (treads); DEC-060 carries a
  renumbering note.

## Source
Brendan, 2026-10-09 (in chat): merge master into the branch so PR #241 becomes mergeable, master's numbers standing
where already published.
