# 1841 — The demo pack carries every underground binary by an export plugin
Date: 2026-10-09 · Status: Accepted (supersedes in part [1127](1127-source-preserving-profile-export.md))

## Decision

The Windows demo pack gets the underground binaries the running game opens with FileAccess from an editor export
plugin, not from the preset's `include_filter`. The plugin is `godot/addons/demo_pack_files`, enabled in
`project.godot`, and it acts only on exports with the `demo_build` feature. It packs exactly the files in
`godot/data/underground/runtime_files.gd`, at their own `res://` paths, and only at the SHA-256 their reader pins. That
list is made of the readers' own constants, with no copied path. The preset's `include_filter` goes back to
`*.json, demo/assets/*`, and `addons/*` is excluded from the pack.

## Why

After the digging revamp, `python3 tools/build_demo_windows.py` failed its pack check. The demo now loads the content-10
profile `qualified-claw-stairs-v11/mole-worker.ugprof`, but the preset still named the old
`profile-publication-v3-frontier` one. `verify_demo_pack.gd` stops before it boots the demo when the profile check
fails. The later failures in that report (main scene `None`, no `demo_build` feature, no staged assets, no stall
banner, no build info, no playtest log) were only fields it never filled. Its code returns before `_boot_demo`. None
of them was a separate fault.

Renaming the one path would not have been enough. The runtime opens 14 binaries:

| Reader | Files |
|---|---|
| `UndergroundSession` (level catalog) | `initial_level_pack.uglvl` |
| `MolePresentation.load_sources` | six `.ugactor` images: actor, handling, wood haul, stone haul, claw, paw |
| `mole_profile_catalog` | the content-10 `.ugprof` wire |
| `UndergroundRouteComposition` | the `qualified-stairs-v9` `structure.ugconn` and the `stair-motion.ugstair` wire |
| `UndergroundEntryComposition` | the `qualified-stairs-v9` recipes, assemblies, frontier and workpieces |

The old filter named two of them. **Four of the actor images sit under `.gdignore` folders** (`stand-walk-v2/` and
`claw-work-v1/`). A probe project on Godot 4.7.2 showed that the exporter never enters such a folder, even for a path
named exactly in `include_filter`, and it says nothing. The same probe showed that `EditorExportPlugin.add_file` packs
a file under `.gdignore` at its own path. These are the alternatives considered:

- **Name all 14 in `include_filter`.** It cannot reach the four. A hand-kept list also went stale once already.
- **Remove the two `.gdignore` files.** The editor would then import thousands of evidence PNGs and scripts, and
  `all_resources` would pack them.
- **Move or copy the images.** That breaks the immutable published paths the readers pin (ADR 1217: nothing published
  is edited).
- **Rewrite the `.pck` after export.** That means a hand-written writer for an engine-internal format.

So an export plugin is Godot's own mechanism for a file the filters cannot reach. Its list comes from the readers'
constants, so a renewed pin moves the list with it. `test_underground_runtime_files.gd` checks for staleness. It walks
the demo scene and the autoloads through every resource their source names. Every existing non-resource file that
this code names must be in the list or in the declared `NAMED_UNREAD` list. `NAMED_UNREAD` holds the bundle's copies
of the ground-pace connector and the profile, which no reader opens. Every listed file must also be named by that code.
The test fails when one entry is removed.

A pack that was missing these files would still have booted. `demo_village.gd` refuses an unloaded underground with
only a warning, so the old check would have passed a demo with no underground at all. The pack check therefore adds
two things:

- **Before the boot:** `runtime_files()` streams each listed file from the pack and checks it against its pin. The
  size bound is 4 MiB, against a largest image of 1,058,772 bytes.
- **After the boot:** the check confirms that the underground foundation mounted, with its actor image, and that
  its route graph was composed. It reads the Session's public `world_route_provider()`, which is non-null only past
  route composition with nothing refused. Session state 2 is not enough: a route composition refused before its
  catalog loads also returns the Session to state 2.
- **Where it runs:** the check runs in the logs folder, so a `res://` path missing from the pack cannot fall through
  to a project file beside the working directory.

`build_demo_windows.py` fails the build if the check read no list, if any file is refused, if the foundation is not
mounted, or if the log holds the "Underground foundation unavailable" warning.

The plugin's choice of files is a static function, `files_to_pack(features)`, which the headless suite tests directly.
An `EditorExportPlugin` cannot be instantiated outside the editor. Given no `demo_build` feature, it returns nothing;
given the feature, it returns every listed file at its pin; a changed or missing file is refused. Godot gives
`_export_begin` no way to abort an export, so a refused file is an `ERROR` line, which fails the export step. It must
stay an error.

## Consequences

- When a new runtime reader opens a binary, its constants go into `runtime_files.gd`. The test enforces this.
- The staleness walk sees a path only as a double-quoted `res://` literal naming a file on disk. A reader that builds
  a path with `path_join` or `%` must add its constants to the list by hand. A second test refuses any reachable use of
  a `NAMED_UNREAD` constant outside its own catalog.
- Do not put underground paths back in `include_filter`. A path under `.gdignore` silently does nothing there.
- The plugin loads in every editor session but registers only the export hook. It loads the list lazily, only when a
  `demo_build` export runs.
- Script export mode 0 and 1127's cached-source and profile checks are unchanged.
- `res://data/rules_identity.bin` and `lookup_identity.bin` (`save_identity_hashes.gd`) are named by the demo's code
  but are not in the repository. They are out of this decision's scope, and the staleness test counts only files that
  exist.

## Evidence

The full build was `python3 tools/build_demo_windows.py --out <scratch>/winbuild-test`, a debug export of the staged
worktree at `b9dcb501` plus this change. It exited 0 and produced a 688.0 MiB zip.

- **Export log:** it stored exactly the 14 binaries (6 `.ugactor`, 1 each of `.uglvl`, `.ugprof`, `.ugconn`,
  `.ugstair`, `.ugrecp`, `.ugasmb`, `.ugfront`, `.ugwipc`) and nothing from `addons/`.
- **Verification:** `runtime_files` reported 14 files, 3,824,790 bytes, none refused. The main scene was
  `res://demo/demo_village.tscn`, with `demo_build` on, `underground_mounted` true, the stall banner shown and
  resumed, 45 ticks after resume, the playtest log started and the beaver's flat roll bound.
- **Diagnostics:** both logs held zero error lines and zero warning lines.

## Source

The failed build of 2026-10-09 (`redwall-rts-build-2026-10-09/logs/verify.log`), the 4.7.2 probe described above,
ADR 1217's immutability rule, and decision 0196's build contract.
