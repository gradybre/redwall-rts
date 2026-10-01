# 0501 — A clean test log is asserted, not hoped for
Date: 2026-10-01 · Status: Accepted

Numbered 0501: the test-and-diagnostics hygiene brief assigned the 0501–0509 block, and no branch or worktree used
any number in it.

## Decision

The full suite passed, but its log was not clean, and nothing checked that. Each `ERROR:` and `WARNING:` line the
worker prints is now one of three things:

- **Declared by its test.** A negative test calls `expect_diagnostic("fragment")` before it provokes the line. The
  runner reprints the line as `EXPECTED ...` and fails the test if the line never appears.
- **Tolerated.** One of the engine's two outside-the-tree notices, in a suite that overrides
  `tolerates_outside_tree()`, or a line its test declared with `tolerate_diagnostic()` because it depends on the
  machine. The runner reprints it as `TOLERATED ...`.
- **A finding.** It is printed unchanged.

`tools/run_tests.sh` counts findings and the worker's leaks at exit from the raw log, and fails the run when any is
above zero. All four allowances are zero. CI also fails on any GDScript analyzer warning (`tools/gdscript_warnings.py
--max 0`). Two reference cycles in production code are fixed, each with a test.

## What the log held (master df9aec3, 7,082 tests)

| | Lines | Expected negative fixture | Outside the tree | Exit leak report | Real bug |
|---|---|---|---|---|---|
| `ERROR:` | 316 | 15 | 290 | 11 | 0 |
| `WARNING:` | 405 | 35 | 367 | 3 | 0 |

- **Exit leak report.** The worker leaked 13,034 ObjectDB instances and 87 resources, plus the RID and
  PagedAllocator lines that follow from them.
- **Outside the tree.** 280 `!is_inside_tree()` reads and 10 `Camera is not inside scene.`, all from suites that build
  node fixtures. The 367 warnings were one Control notice ("non-equal opposite anchors ... overridden after
  _ready()"), all printed from `ui_shell.gd _set_rect`.
- **Expected negative fixtures.** 18 tests across 12 suites, for example UI_FRAME_* refusals, the stock-integrity
  halt, the missing-sound-file warnings, and an unknown water landing.
- **GDScript analyzer warnings.** No `--script` run ever prints these. Through the language server there were 1,370
  in 283 of 628 files:

  | Warning | Count |
  |---|---|
  | INTEGER_DIVISION | 796 |
  | SHADOWED_VARIABLE | 217 |
  | ASSERT_ALWAYS_TRUE | 130 |
  | SHADOWED_GLOBAL_IDENTIFIER | 72 |
  | SHADOWED_VARIABLE_BASE_CLASS | 54 |
  | INCOMPATIBLE_TERNARY | 42 |
  | CONFUSABLE_LOCAL_DECLARATION | 19 |
  | UNUSED_PARAMETER | 12 |
  | UNUSED_PRIVATE_CLASS_VARIABLE | 9 |
  | UNUSED_VARIABLE | 9 |
  | NARROWING_CONVERSION | 8 |
  | STATIC_CALLED_ON_INSTANCE | 2 |

  The review's "about 404 diagnostics" in the debugger was the subset loaded by one demo run.

## The real bugs: two reference cycles that outlived a Restart

GDScript has no cycle collector, so two RefCounted objects that hold each other are never freed. A Restart
(`demo_village.gd restart`) reloads the scene and frees its nodes, but cycles among the RefCounted objects survive.

1. **The tunnel router held the network that owns it.** `underground_graph.gd plan()` hands the router itself through
   `use_paths`. The router kept `_graph`, and the surface planner `_nav`, until the next plan cleared them, so every
   network that had ever planned outlived its village, along with the router's `MAX_NODES * MAX_NODES` columns. The
   router now lets go of both when `plan` returns (`tunnel_router.gd _release`). This one fix removed the leak from 11
   of the 20 leaking suites, including `test_demo_tunnel_ext_world.gd`, which Group N had seen leak 555 instances
   when run alone.
2. **A resident's unfinished job held its owner, and the owner held the residents.** `unfinished_job.gd` keeps a
   reference-counted owner alive on purpose, because a tunnel job's task is dropped the moment its worker is called
   away. For a long-lived owner that also holds the brains, though, that reference closes a cycle. The kitchen
   (`_brains`) is the one the suite caught; the tunnel works, the work board and the night routine hold brains too. The actor that owns a brain now has it
   drop its task and unfinished jobs on `NOTIFICATION_PREDELETE` (`demo_actor.gd`, `resident_brain.gd drop_jobs`).

`test/test_demo_lifetimes.gd` covers both through WeakRefs, including a plan that ends in the router's fallback and a
brain whose task (not only an unfinished job) holds the owner. The code review showed that dropping either of those
two releases still passed the first version of these tests, so each now has a test of its own.

None of the ERROR or WARNING lines was a real bug. The two cycles were found from the leak count, not from a printed
error.

A third bug turned up while reading divisions for intent: `farm_text.gd _tenths` printed -0.5 °C as "0.5", because
the whole part of -5 tenths is 0 and the fraction went through `absi`. A frost between 0 and -1 °C lost its minus
sign on the clock line. The sign is now written separately, and `test_demo_farm_ui.gd` pins -0.5, -1.5, -3, 12.5
and 0.

## Test-teardown leaks, fixed in the tests

- **A lambda capturing a fixture that stores the lambda.** Fixed in three suites:
  - `test_demo_work.gd`: the farm crew's notice lambda held the rig, and the rig held the crew. `after_each` drops the
    rig's farm and board. Its users `_edges` and `_screen` are fixed with it.
  - `test_demo_route_desk.gd`: a desk's turn lambda held the desk.
  - `test_demo_earth.gd`: the crew's notice lambda held the suite.
- **`demo_village.gd` makes its child nodes in member initialisers and parents them in `_ready()`.** A village that
  never enters the tree leaves them parentless when freed. `test_demo_integration.gd` now frees those members, and
  `test_demo_prewarm.gd` warms the committed mouse GLB instead of instancing the whole village as a "model".
- **Two smaller leaks.**
  - `test_demo_kitchen.gd`: the brains' kitchen jobs (cycle 2 above) are cleared in `after_each`, because these
    brains have no actor.
  - `test_demo_theatre.gd`: a smoke emitter made only to read its `amount` is now freed.

Every suite run alone, and the full run, now leaks 0 objects and 0 resources.

## Outside the tree is tolerated, not fixed

The worker runs every suite in `_initialize`, before the root Window is in the tree (docs/ENVIRONMENT.md, "Real
input in a headless run"). So a node fixture can never be inside it, and a global-transform read or a camera ray on
one prints the engine's notice. Particle emitters restarting do this too. The fix in each case would be to run the
worker inside the tree and parent every fixture there. That would fire `_ready()` across a dozen demo suites and
change what they test, which is a larger change than this hygiene pass. So the notice is tolerated, but narrowly:

- Only the two exact engine notices are tolerated, and only from the functions the harness trips. The line after
  each must be its `at:` line naming `get_global_transform (scene/3d/node_3d.cpp` or `scene/3d/camera_3d.cpp`.
  `!is_inside_tree()` is the message of every unguarded tree check in the engine, so a `grab_focus` or a 2D rect
  read before the tree would otherwise slip through as tolerated (the code review's M2).
- Only in suites that declare `tolerates_outside_tree()` (eight).
- They are counted on the runner's diagnostics line, so a jump is visible.
- A real game run has every node in the tree, and the 600-frame boot and both live harnesses print neither notice.

**Unstaged assets are tolerated per test.** CI has no staged demo assets (`godot/demo/assets/` is gitignored). There,
the three tests that build the real sound table (two in `test_demo_sound.gd`, one in `test_demo_sound_cost.gd`) each
print 21 "plays silent until they are staged" warnings. Where the assets are staged, they print none. Expecting the
line would fail locally, and leaving it would fail CI, so those three tests call `tolerate_diagnostic()` for that one
fragment. This was found by running the suite on a copy of the project without `demo/assets/`.

**The anchors warning was fixed instead.** `ui_shell.gd _set_rect` sets a zone's size with `set_size()` rather than
the `size` property. The two do the same thing, but only the property setter warns. The shell lays its geometry out
again on every resize, so nothing overrides it, and the live layout harness checks the result at 1280x720 and
1920x1080. That warning was also the only one printed by the live harnesses running the real scene (four times per
run), so the fix cleans them too.

## Analyzer warnings: each one fixed by its intent, none switched off

- **Nothing is disabled in `project.godot`.**
- **An intended integer division is annotated on its own statement:** `@warning_ignore("integer_division")` on the same
  line. Authoritative state is integer by design.
  - Verified on 4.7.2: `int(a / b)` does NOT silence the warning, and an annotation on the `func` line does NOT cover
    its body. An `elif` condition needs `@warning_ignore_start`/`_restore`.
  - Each division was read for intent. Where an integer quotient feeds float maths it was a bug candidate. Only one
    came up (`swim_motion.gd flow_m_s`). It mirrors the integer flood scale of `water_crossings.gd` and
    `swim_rules.gd`, so it was kept integer and annotated.
- **Constant pins.** `assert(CONST == value)` lines are deliberate pins, annotated `assert_always_true`.
- **Shadowing.** Shadowing locals and parameters are renamed, with the docstrings that named them. Class members,
  which are API, are annotated instead.
- **Unused parameters** take a `_` prefix.
- **Unused private members** are deleted. `residents.gd _math` was also struck from
  `docs/persistence_state_registry.md`.
- **The rest.** Narrowing reads of `Performance.get_monitor` are wrapped in `int()`. Ternaries are given one type.
  A static call made through an instance now goes through its script constant.

## The guard

- **`tools/run_tests.sh`** prints a `log:` line and fails if any count is above its allowance (all zero):
  - `^ERROR:`/`^USER ERROR:` lines;
  - `^WARNING:`/`^USER WARNING:` lines;
  - leaked ObjectDB instances;
  - resources still in use.

  It counts from the raw log, not from the runner's own `diagnostics:` line, so a supervisor that stops classifying
  is still caught. Raising an allowance needs a decision record that names what it allows and why.
- **`tools/gdscript_warnings.py`** starts a headless editor with `--lsp-port` and opens every `.gd` file through LSP.
  It waits for the editor's `loading_editor_layout` step first: twice, connecting earlier crashed 4.7.2 with signal
  11. The language server also crashes now and then partway through a long run, and passes the same files on the
  next start, so a crash restarts the editor and resumes at the file it died on. Three crashes in a row with no
  progress fail the run. It fails above `--max`, and CI runs it with `--max 0`.
- **`tools/test_run_tests_diagnostics.py`** runs the real runner on six fixture suites in a scratch project. It checks
  that each case is classified. CI runs it after the suite. The cases are:
  - a declared line;
  - a declaration nothing printed;
  - an undeclared warning;
  - a tolerated outside-the-tree read;
  - the same message from `grab_focus`, and in a suite that declares no tolerance, both of which must stay findings;
  - a RefCounted cycle.

## Rejected

- **A runner-wide allowlist of message texts.** It would have hidden a new refusal that happened to match an old
  one. A declaration in the test that provokes it can't.
- **Swallowing expected lines.** They are reprinted with a prefix instead, so the log still shows what each negative
  test proved.
- **Converting integer divisions with `floori(float(a) / b)`.** It rounds negatives differently, and above 2^53 it
  loses int64 precision.
