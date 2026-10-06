# 1205 — Superseded content-3 publications pin owner bytes from git

Date: 2026-10-06 · Status: Accepted

## What happened

Four Python suites failed with pinned-digest drift that predates ADR 1200:

| Suite | Refusal | Cause |
|---|---|---|
| `first-entry-prefix-v1/test_compile_entry_frontier.py` | `ENTRY_FRONTIER_STRUCTURE_DRIFT:manifest.json` | the structural-v1 manifest records `underground_connector_{catalog,assemblies,recipes}.gd` as they were at `c975e1bd` |
| `test_entry_work_area.py`, `test_rebind_handling_diagnostic.py` | same | both build on the frontier rebuild |
| `mole-worker/test_publish_short_step_profiles.py` | `STEP_PUBLICATION_HASH:…underground_profiles.gd` | qualified-step-v4 pins seven scripts as they were at `CONSUMER_COMMIT` `912de685` |

## Classification

All three publications are **historical**. `structural-v1`, `frontier-v2` and
`qualified-step-v4` bind profile content 3. ADR 1200 moved the runtime to content 5
(`qualified-haul-v6`, bundle `qualified-haul-v2`/`qualified-install-v3`).
No runtime script loads them, and `tools/renew_source_pins.py` renews only v6.
Every drifted digest equals the file at the commit the publication names. That
was checked one file at a time with `git show`.

The live owners are runtime code, and the active publication already pins them
(ADR 1192 §7). Renewing these historical manifests would rewrite published
artifacts to describe code they were never built against, so they are not renewed.

## Decision

- `compile_entry_prefix.py` and `compile_entry_frontier.py` read producer and
  owner script digests from git at `PUBLISHED_AT` (`c975e1bd`, `b315b7c7`) via
  `published()`, never from the live tree. Data inputs are still read live and
  checked against their SHA pins. Every output byte is still rebuilt and compared
  with the committed packet. The tests now also assert that comparison directly.
- `publish_short_step_profiles.py` resolves each pinned file that git tracks at
  `CONSUMER_COMMIT` from that commit through one `git cat-file --batch` process.
  For a Git LFS pointer, the live file must hash to the oid the commit recorded.
  An untracked input, or a run outside a checkout, still requires live bytes to
  match exactly. A module that the replay **executes** must also match live
  (`MODULE_DRIFT`). The producer's own digest comes from its publishing commit,
  `84739fcc`.
- The publication was renewed in place while it was active (its `renewals`
  record), so the replay is not compared byte-for-byte with the committed files.

## Not covered

The short-step reconstruction also reads 153 gitignored `godot/demo/assets/`
files, including the `underground-matrices` world basis and grip palette and the
cast/props meshes. No commit has ever held them. ADR 1192 §2 does not admit them
as evidence, so the seven reconstruction tests skip with that reason when the
files are absent. The eight admission/refusal tests always run. With the pins
fixed, the reconstruction was **not** re-run end to end in this checkout. Doing so
would mean copying files from a sibling worktree, which is the overlay pattern
ADR 1192 forbids. Committing those assets, or retiring the replay, is a separate
decision.

Dated evidence replays under `docs/validation/evidence/` that pin the old bytes of
`compile_entry_prefix.py` or `compile_entry_frontier.py` now record history only,
as ADR 1192 §Consequences already states.
