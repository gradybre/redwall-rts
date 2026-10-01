# 0562 — The demo keeps a playtest log of its own
Date: 2026-10-01 · Status: Accepted

The brief asked for a number from 0561 to 0569. 0561 was already taken: `wt-scale` holds the uncommitted
`0561-the-demo-scale-test-and-its-stress-cast.md`. No branch and no other worktree uses 0562.

## Decision

Brendan approved a crash and error log for playtesters on 2026-10-01. The live demo now writes one **playtest
log** per session (`godot/demo/playtest/`). It sits in `user://logs` beside Godot's own `godot.log`, and the folder
keeps the last ten sessions, each capped at 2 MiB. A file holds:

- a header describing the machine, the build and the settings, which also says whether the previous session ended
  cleanly;
- a 64-entry breadcrumb ring of notable events;
- every engine and script error and warning, caught through `OS.add_logger`;
- a heartbeat every 30 s;
- freezes, written on recovery and also by a watch thread while they last;
- the tester's F12 marks;
- an end marker.

Settings has **Open log folder**, **Copy report** and **Mark a problem here**, and Help says where the files are. The
Windows build packs `demo/build_info.json`, so the header names the commit it was built from.

## What Godot gives, and what it does not (measured on 4.7.2)

- **File logging is on for desktop exports by default.** `debug/file_logging/enable_file_logging.pc=true` covers
  release exports too. A release export wrote `user://logs/godot.log`, even though plain `get_setting` reports
  `false`, because it ignores the `.pc` override.
- **Godot's own log loses lines in a crash.** In a release export `application/run/flush_stdout_on_print` is off, so
  `godot.log` is flushed only on error lines. In the crash probe below, a `print` made before the crash appeared
  neither on stdout nor in the file. This is why the session has its own file, and it flushes every write.
- **`Logger` / `OS.add_logger` work from GDScript.** One `_log_error` arrives for each `push_error`, `push_warning`,
  GDScript runtime error and engine `ERR_*`, from any thread, with `ScriptBacktrace` frames. `printerr` arrives as
  `_log_message(..., true)` and `print` as `_log_message(..., false)`.
  - The logger keeps only stderr lines. `print` stays in `godot.log`.
  - For an engine check, `rationale` holds the message and `code` the condition. For `push_error`, `code` holds the
    message.
  - (`test/run_tests.gd`'s header still says an error handler is "a C++/GDExtension-only API". That was true before
    4.5; the runner was not changed here.)
- **A release export hides script errors, and a null call kills it.** This was measured with a tiny probe pack run
  on the macOS **release** template, which runs the same GDScript VM code as the Windows one:
  - an out-of-range array index raised nothing at all;
  - a method called on null **ended the process with signal 11**. No message reached stdout or `godot.log`, and
    `NOTIFICATION_CRASH` did not arrive.

  The macOS **debug** template reported both as `SCRIPT ERROR` with frames, and carried on.
- **A script Logger must be released before GDScript shuts down.** The first version kept the session in a `static
  var`. After the session ended cleanly, the process aborted at exit with `libc++abi: ... recursive_mutex lock
  failed` (status 134). The session's own `Logger` object was being freed after the scripting language had gone.
  `stop_session` now drops the static reference as it removes the logger.
  `test_ending_the_session_lets_go_of_it` asserts, through WeakRefs, that the session and its logger are freed at the
  stop; the mutation that restores the old behaviour fails it. `test_demo_playtest_live.gd` asserts its harness exits 0.

## The choices

- **Its own file, not only Godot's.** `godot.log` stays, and the tester sends both. Ours flushes every write. It is
  structured: header, breadcrumbs, errors with their frames, heartbeats, freezes, marks and an end marker. Its rotation
  (`playtest-*`) never touches Godot's (`godot*.log`). The names sort by local start time and carry the process id,
  because live harnesses start in the same second.
- **The ring keeps no memory per event.** It is six packed columns, sized once:
  - real time, game tick, kind, and two ints;
  - a `StringName` tag, which is always an existing name, so storing it only takes a reference.

  `test_recording_retains_nothing` records 10,000 events after a warm-up and asserts zero change in static memory
  and object count. That catches growth, not a temporary freed inside `record`: Godot has no allocation counter, so
  "no allocation per event" rests on review of `record` (index writes into packed columns, no text). Text is made
  only when lines are written: in a batch at most once a second, or in the dump after a mark or a freeze.
- **Breadcrumbs come from public state, read each frame.** These are the input gate's `top_layer()`, the right
  column's `shown`, the underground view, the map layer, the notice feed's `revision`, and two new order counters on
  `demo_command.gd`. A change of value is one event. The alternative was to add a signal or hook to each owner.
  That would have meant edits in six shared files that other agents are changing, for the same information. The
  probes cost a few Callable calls a frame, and they allocate nothing unless something changed.
- **Errors keep time order with the breadcrumbs.** Before an error line is written, any breadcrumbs not yet written
  go first; this is `drain_into`, which is safe from any thread. An error's own breadcrumb is not written twice, but a
  dump still lists it. A line repeated more than five times is counted, not written, so an error raised every frame
  cannot fill the file.
- **Freezes are seen twice.** On the main thread, a frame longer than 3 s while running (20 s while loading, which
  covers the boot and a restart) is written when it ends. A low-priority thread polls every 200 ms. It writes the same
  freeze, once per stall, while the stall is still going, so a hang that the tester kills is in the file. Both
  thresholds sit far above the clock's own quarter-second stall pause (decision 0205), which keeps its banner.
- **The node lives under the root.** It survives Restart demo, which reloads the scene, so one process means one
  file. Every bind moves it to the root's last child, so its `_input` reads F12 before the demo's input gate, which
  swallows keys under a modal. The gate is unchanged.
- **F12, plus a button.** F1–F9 and F11 are bound. F10 activates the window menu on Windows. Mac keyboards need Fn
  for F12, so Settings carries the same Mark.
- **Privacy.** The log holds no account name, machine name, path or typed text. The writer replaces the home and
  user-data folders, longest first and with either slash, with `~` and `<user data>`. The header reads only the
  hardware, the OS, the renderer and the demo's settings. Breadcrumbs hold codes and the game's own node names. A
  notice's breadcrumb is its source and level, never its text.
- **The version.** `build_demo_windows.py` writes `godot/demo/build_info.json` before the export. It is gitignored,
  packed by `*.json`, and removed in a `finally`, so a project run never reads a stale copy. The pack's verification
  now fails without it, or when the log did not start. A project run asks git once; an export without the file says
  "unknown (no build info packed)".

## Brendan's ruling: playtest builds are debug exports (2026-10-01)

Brendan ruled that **playtest builds use the debug export**, while release stays available for final builds.

- `tools/build_demo_windows.py` now exports with `--export-debug` on `windows_debug_x86_64.exe` by default. `--release`
  exports on the release template. `build.json` records the mode (`export.mode`).
- On the debug template a GDScript error is reported with its script frames and the game carries on, where release
  ends the process at a null call with no word. `godot.log` is flushed on every line (`flush_stdout_on_print.debug`),
  and the heartbeat's engine memory (`Performance.MEMORY_STATIC`, 0 in release) is real. The cost is GDScript speed:
  a playtest build's frame times are not the release budget's.
- The packed `demo/build_info.json` carries the mode (`"export": "debug"`), and the header quotes it ("abc1234 (built
  ..., debug export)"). The pack's verification compares the packed commit and mode with the build's own and fails on
  a mismatch: the verify step boots the pack with the editor binary, which is always a debug build, so the file is
  the only witness of the template used.
- **`always_track_call_stacks` stays off.** The debug template already gives every error its script frames; a release
  build, which would need it, is a final build.
- No Windows build or export was run for this; Brendan builds on request.

## Not done, and why

- **No upload or crash reporter.** The tester sends the file.

## After the independent review (8538e084)

- **The freeze watch is tested as the process wires it.** Deleting `start_watch`'s `on_freeze`, `frame`'s beat or
  `set_phase`'s threshold had left every test green. The thread test now goes through `start_watch` and `set_phase`
  (with `running_freeze_usec` shortened), and a test checks that each frame beats the watch at the phase's threshold.
- **The end marker is never dropped at the cap** (`write_final`), so a full file does not read as a crash.
- **Headless runs log under `user://logs/headless`** (`PlaytestLog.default_dir`), so the live harnesses -- several
  run at once on this machine -- never rotate a developer's own sessions away, nor each other's out from under a
  check.
- **A second `start_session` ends the first**, so its logger and thread never outlive it.
- The live harness now writes the user-data and home folders into an error and checks both come out scrubbed.
- The heartbeat says "n/a (release build)" for engine memory where Performance cannot count it, and reads the error
  counts under their lock; rotation clamps `keep` to at least 1.

## Shared files touched

- `demo/demo_village.gd`: `PlaytestLog.ensure` first in `_ready`, `PlaytestTaps.wire` after `_build_input`,
  `opened` in `_open_running`, `restarting` in `restart`, and the Help topic's command.
- `demo/ui/demo_menu.gd`: the Settings section.
- `demo/guide/help_topics.gd`: the topic, its command and F12.
- `demo/control/demo_command.gd`: two order counters.
- `tools/build_demo_windows.py` (build info; the debug default and `--release`), `tools/godot/verify_demo_pack.gd`,
  `tools/test_build_demo_windows.py`, `tools/demo_build/README.txt` and `.gitignore`.
- `test/live/demo_input_live.gd`: five playtest-log steps (the mark over the menu, and the log surviving Restart).
- `godot/demo/README.md` (For playtesters) and `docs/ENVIRONMENT.md` (the release-template findings).
- `project.godot` is not touched.
