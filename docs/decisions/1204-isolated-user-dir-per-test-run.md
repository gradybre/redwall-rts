# 1204 — Each test run gets its own empty `user://`

Date: 2026-10-06 · Status: Accepted

## What happened

`test_underground_connector_workpieces.gd` failed in a full run. Its two
profile-reload tests took turns failing, and the result changed between
otherwise identical commits. A `git bisect` blamed a docs-only commit,
`3d251548`. Run alone in a quiet checkout, the suite passed.

## Cause

Fixtures write fixed `user://` paths, for example
`user://test-underground-connector-profiles.bin`. Godot derives `user://` from
the project name, so every checkout of this repository uses the same directory:
the main worktree, agent worktrees and the full-run worktree. Concurrent runs
overwrote each other's fixture files mid-test. The `Condition "len == 0"`
engine errors in the log were reads of files that another process had just
truncated.

## Decision

`tools/run_tests.sh` creates a fresh temporary directory for each run and
removes it on exit. It points Godot's `user://` there by setting `HOME` (macOS)
and `XDG_DATA_HOME` (Linux) for the Godot process only. Every run starts from an
empty `user://`, so:

- parallel runs, worktrees and CI shards cannot interfere;
- a test that depended on files left behind by an earlier run now fails visibly.

The editor import step (`godot --headless --path godot --editor --quit`) and the
playable demo keep the real user directory.

## Rejected

| Option | Why not |
|---|---|
| Unique file names per test | Has to be kept up across 67 distinct paths and every future fixture. |
| An untracked `override.cfg` with `custom_user_dir_name` | Would also redirect the demo's logs and saves for that checkout. |
