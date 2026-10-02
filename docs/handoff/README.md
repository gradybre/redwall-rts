# Handoff — start here

Written 2026-10-02, when the lead session reached its usage limit. This folder lets a fresh agent, Claude or
Codex, with no memory of earlier sessions, continue every remaining item at the same quality.

Read in this order:

1. **This file**: what the project is, the rules every lane follows, and how work moves from a branch to master.
2. [`STATUS.md`](STATUS.md): what is merged, what is in flight, and what each open branch still needs.
3. [`SEQUENCE.md`](SEQUENCE.md): the recommended order, what can run in parallel, and the file-conflict map.
4. [`BACKLOG.md`](BACKLOG.md): every remaining item as a self-contained work packet.
5. [`RULINGS.md`](RULINGS.md): Brendan's rulings since 2026-09-30, each traced to its record.
6. [`OPEN_QUESTIONS.md`](OPEN_QUESTIONS.md): what still waits on Brendan, with options and a recommendation.

Nothing in this folder is a ruling. Where it says "approved", it cites the decision record (`NNNN`) or Brendan's
decision (`DEC-nnn`) that holds the approval. If a citation and this folder disagree, the cited record wins and this
folder gets fixed.

---

## 1. What the project is

A Redwall-inspired colony builder in Godot 4.7.2 and GDScript. Only the **settlement layer** is being built; the
battle and campaign layers are deferred (review group V, decision 0493).

The repository holds two things that are built side by side:

- **The settlement game** (`godot/scripts/`, `scenes/main.tscn`). It follows the GDD strictly: integer state,
  packed columns, the save format, the registry and the memory ledger. Demolition (D1–D6) and hauling (H0–H2, H6)
  are settlement work.
- **The live demo** (`godot/demo/`, scene `demo/demo_village.tscn`, decision 0196). A presentation-led village of
  nine named residents that boots the real game and draws on top of it. Most of the review groups and numbered
  features (#9, #18, #33 and so on) are demo work. `godot/demo/README.md` (about 2,500 lines on batch 8) is its
  feature index: every lane adds a section there.

The feature numbers (#9 feasts, #18 preserving, and so on) come from Brendan's feature lists of 2026-10-01 ("NEW 2"
and "NEW 3"). They are recorded only in the coordinator's tracker, which this folder replaces; `BACKLOG.md` keeps
each number beside its packet.

## 2. Authority order

`AGENTS.md` sets it, and it settles any conflict between documents:

1. `docs/setting_decisions.md`: Brendan's decisions, `DEC-nnn`.
2. `docs/game_gdd.md` (rev 1.1), as amended by `docs/setting_rules_amendment.md` (SET-AMEND-001) and
   `docs/movement_direction_amendment.md` (SET-MOVE-001). **The GDD is authoritative.**
3. `docs/ui_ux_controls.md` (rev 1.1).
4. `docs/gameplay_balance.md`, `docs/systems_architecture.md`.
5. `docs/crowd_rendering_architecture.md`.
6. `docs/setting_bible.md`.
7. `docs/validation_resolution.md` and `docs/validation/`.
8. `docs/decisions/`: engineering decisions, `NNNN`.
9. `AGENTS.md` and `CLAUDE.md`: working rules.

So **the GDD outranks `CLAUDE.md`**, and where `CLAUDE.md` and `AGENTS.md` disagree, `AGENTS.md` wins and `CLAUDE.md`
gets fixed. A lower document that contradicts a higher one is fixed, not worked around. Two separate logs: `NNNN` in
`docs/decisions/` and `DEC-nnn` in `docs/setting_decisions.md` are unrelated numbering schemes (see
`docs/decisions/README.md`); always say which one you cite.

Also read before writing code, as `CLAUDE.md` lists: `docs/movement_direction_amendment.md`,
`docs/redwall-content-library/README.md` with its `authoring_handoff.md`, `docs/ENVIRONMENT.md`, and
`docs/decisions/0006-prototype-diverges-from-gdd.md`.

## 3. How to work

These are the rules every lane followed in this session (the coordinator's lane rules, given here in full), plus the
gates and the records around them.

### 3.1 Setup

- Work only in your own git worktree, on your own branch, based on `origin/master` (or on the integration branch you
  are told to base on).
- Run `godot --headless --path godot --editor --quit` from the worktree first, to import the project.
  **`--path godot` is mandatory**: from the repository root without it, Godot opens the project manager, does nothing
  and exits 0 (`docs/ENVIRONMENT.md`).
- Read `CLAUDE.md`, `AGENTS.md`, `docs/ENVIRONMENT.md` and `godot/demo/README.md`.
- For demo work, stage the gitignored art first if you want to see it (§3.9). Code must also run without it.

### 3.2 Rules come from the documents, never from invention

- **Check the design first.** Before building, read what the feature's rules already are in `docs/game_gdd.md`,
  `docs/gameplay_balance.md`, `docs/ui_ux_controls.md`, the content library (`docs/redwall-content-library/README.md`
  and `authoring_handoff.md`) and `docs/setting_rules_amendment.md`, and implement the adopted rules.
- **Where the documents are silent,** choose the smallest sensible behaviour and mark it as a **PROPOSAL** in your
  decision record. List it in your report as a question for Brendan, with options and a recommendation (format in
  §4). Build it so that a different ruling is a small change.
- **Never contradict an adopted rule.** If a feature as asked would contradict one, stop and report the conflict
  instead of building it.
- **Never invent a ruling.** "Approved" in a record means Brendan said so, and the record quotes or cites where. A
  proposal stays a proposal until he rules; the ruling is then written into the same decision record under
  "Brendan's rulings (date)" (see 0902, 0903, 0537 for the pattern).

### 3.3 Code

- The GDScript standards in `CLAUDE.md`: full static typing; functions of 30 lines or fewer; a docstring on every
  function; integer authoritative state, with float only for presentation; packed columns rather than one Resource
  per entity; no allocation in hot or per-frame paths; no stubs or TODOs.
- **Zero warnings.** CI runs `python3 tools/gdscript_warnings.py --max 0` (about 2.5 minutes, through the editor's
  language server). Annotate a meant integer division on the statement itself:
  `@warning_ignore("integer_division") var half: int = n / 2`. Do not shadow names. Details in `docs/ENVIRONMENT.md`.
- **Keep the shared surface small.** Many lanes run at once. Prefer new files and narrow, additive hooks in shared
  files. List every shared file you touch in your report, with the hook added. Do not refactor code you do not own.
- **Keys.** Check the existing bindings (`godot/demo/demo_window_keys.gd` and the input harness
  `godot/test/live/demo_input_live.gd`) before assigning one, and report every key you add. Prefer putting a new
  panel behind an existing menu or workspace over a new key.
- **Paid services.** Spend no paid generation credits and download nothing unless Brendan has approved an itemised
  list (§3.8). Use existing assets, tints, shaders and procedural work. If a feature truly needs new art, say so in
  the report.

### 3.4 Tests and gates

Every one of these must hold before a branch is handed back. Exit status 0 is never evidence; quote the summary
lines.

- **Test every public function**, add boundary tests, and add allocation checks for per-tick code. Tests live in
  `godot/test/test_<module>.gd` in the in-repo framework (decision 0004). A test that provokes `push_error` or
  `push_warning` on purpose declares it first with `expect_diagnostic("fragment")`.
- **Iterate with focused tests** (single test files, or a focus runner; `docs/ENVIRONMENT.md` "Reading the test log").
- **Run the full suite once at the end, the way CI does**:
  1. move `godot/demo/assets` aside (CI has no staged assets);
  2. delete `godot/.godot` and re-import: `godot --headless --path godot --editor --quit`;
  3. run `./tools/run_tests.sh`, or the shards as CI does (decision 0991):
     `./tools/run_tests.sh --shard N/8 --output-dir <dir>` for N = 0..7, then
     `python3 tools/ci_test_shards.py verify --reports <dir> --count 8`;
  4. restore the assets.

  It must end with **0 failures, 0 unexpected errors, 0 unexpected warnings and 0 leaked objects or resources** on
  both the `diagnostics:` and `log:` lines (decision 0501). Integration batches run it both staged and CI-style
  (see 0903 "Gates").
- **The analyzer:** `python3 tools/gdscript_warnings.py --max 0` must print `0 GDScript warning(s)`. A run started
  the moment the import cache is put back can report spurious warnings; rerun it (0903 "Gates").
- **The contracts.** CI's "contracts" group runs every specification check: `docs/validation/decision_numbers.py`,
  `docs/validation/ready07_arithmetic.py`, `docs/validation/merge_gate.py` (the memory ledger chain and row
  arithmetic), `tools/dispatch_plan.py --validate`, `tools/astra_inbox.py --check`,
  `tools/generate_canonical_state_table.py --check`, `tools/lane_notes.py --check`, the movement checks,
  `docs/validation/state_registry_coverage.py` and the rest listed in `.github/workflows/tests.yml`. Settlement work
  that adds bytes must update the memory ledger and the registry capacity audit so these pass.
- **Live harnesses.** Run the ones your change can affect (`godot/test/live/*.gd`) at **1280x720 and 1920x1080**:
  `godot --headless --path godot --script res://test/live/<name>.gd -- --size 1920x1080`.
- **Frames.** For anything visible, capture frames at 1080p (and 720p for UI) into
  `scratchpad/<feature>_check/` and **look at every one** before claiming it works.
- **Flakes.** If a wall-clock test flakes under load, rerun it once. Never change a budget. The routes harness's
  "dig: confirm refused" at 1280x720 was a known transient (0903 "What the gates found"); its root-cause fix is
  decision 1041 on `fix/follow-ups`.
- **The machine may be loaded.** In this session up to about 15 lanes ran at once. Keep below that, and expect
  timing tests to flake above a load of about 35.

### 3.5 Mutation testing and independent review

- **Mutation-test the new logic** and report the kill count. Lanes wrote their own small mutation scripts (one
  mutant per run: change an operator, a constant or a branch, run the focused suite, restore). Every survivor needs a
  reason, and any survivor left is declared in the PR as `SURVIVED_MUTANTS`.
- **Independent review.** Run an independent reviewer on the diff (Claude Code: the `code-reviewer` agent; Codex: a
  separate reviewing session that did not write the code) and **wait for it** before handing back. Fix every
  CRITICAL and HIGH; fix or answer each MEDIUM in the decision record.

### 3.6 Records

- **A decision record** for the lane in `docs/decisions/`, within the number range the packet assigns (BACKLOG.md
  assigns ranges of ten from **1101**). Check the number is free on your branch and on every other branch:
  `git for-each-ref` over `refs/heads` and `refs/remotes`, then `git ls-tree` each ref's `docs/decisions/`. Then run
  `python3 docs/validation/decision_numbers.py` (it refuses duplicates and heading mismatches). The record states the
  rules used (with their REQ, section or decision), every PROPOSAL, the gates' summary lines, the review outcome and
  the mutation counts. Format: `docs/decisions/README.md`.
- **Brendan's own decisions** go in `docs/setting_decisions.md` as the next `DEC-nnn` (the latest is DEC-048 on batch
  8 and DEC-049 on `feat/demo-measures`; see STATUS.md). A DEC records a creative or policy ruling; an engineering
  record cites it.
- **The demo README.** A demo lane adds or updates its section in `godot/demo/README.md`.
- **Lane notes** (settlement tasks). One new file per lane, `docs/tasks/lanes/<task>/<YYYY-MM-DD>-<slug>.md`, never an
  append to a shared file; `python3 tools/lane_notes.py --check` enforces it. Tick the task checklist's `[ ]` boxes
  in `docs/tasks/`.
- **The work queue.** `docs/planning/work_queue.json` is the settlement task graph (for example `DEMOLITION-D7`,
  `HAUL-H3`). Update a task's `status` (blocked, ready, in_flight, review, done) when it changes;
  `python3 tools/dispatch_plan.py --validate` checks it in CI.

### 3.7 The pull request

The template `.github/pull_request_template.md` has three sections, "What changed", "Evidence" (the actual commands
and what they printed; a screenshot for anything visual) and "Declarations". The declarations are read by
`tools/auto_merge.py`:

```text
DEVIATIONS: none
SURVIVED_MUTANTS: none
BLOCKED: none
```

`none` is the normal answer. Anything else holds the PR for a human to read. `DEVIATIONS` is where a lane says it
did not do part of its brief, or overruled it, and why (D6 declared one: hauling waited on 06.4, decision 0537).
`BLOCKED` means *this change is not safe to merge*, not that later work is blocked. A missing block holds the PR too.

### 3.8 Paid generation (decision 0961)

Paid generation (Meshy) is **by request**: present Brendan an itemised, costed list and proceed only once he
approves it. Once he has approved a list and a credit cap, the lead may hand those exact calls to a subagent, whose
brief names the items and the hard cap; it checks the balance before and after each group, stops at the cap and
reports, and never widens the list or asks Brendan itself. `meshy_check_balance` is free. The last recorded balance
is about 98 credits (after the flax icons, 0972; unverified since). UI art follows
`docs/design/ui_refinement/asset_generation_lock.md`, as amended for render-style item icons (0971).

### 3.9 Staged art is gitignored: how to restage it (decision 0903)

`godot/demo/assets/` and `assets/library/` are gitignored (decisions 0188, 0196). Merging an art branch brings only
its tools and ledgers. To stage everything in a checkout:

```bash
python3 tools/stage_demo_assets.py                    # all demo assets (needs the local library; ~2.8 GB)
python3 tools/stage_demo_assets.py --only art         # just the art passes: make_demo_food_art.py + tools/stage_art_passes.py
python3 tools/demo_texture_imports.py --godot godot   # VRAM compression; build_demo_windows.py runs it itself
```

`tools/stage_art_passes.py` runs `make_art_pass2.py all` and `make_art_pass3.py` (and `--icons`) only when a pass's
record is missing (each needs Blender), then writes the manifest rows. The shared library is
`/Users/brendan/Developer/redwall-rts/assets/library/` (pass `--library <path>` from another worktree). Every piece
of art degrades to the stand-in it replaced when not staged, and the suites must pass both ways.

### 3.10 Windows builds

Build the Windows demo **only when Brendan asks**. The command is in `docs/ENVIRONMENT.md`
(`python3 tools/build_demo_windows.py --out <folder>`; `--release` for a final build, decision 0562). Restage the art
in the checkout you build from first (§3.9).

### 3.11 Standing safety rules

- **Never kill by pattern** (`pkill -f`, `killall`). Other agents run the same commands on this machine. Kill only
  PIDs you started, checking each one's working directory first. (One lane's `pkill -f tools/run_tests.sh` killed
  other lanes' suites on 2026-10-01.)
- **Never wait on `pgrep -f <name>`**: it matches its own shell, so the wait never ends. Wait on a PID or a file.
- **Stage named paths only.** Never `git add .` or `git add -A`.
- **Do not push, merge, rebase, reset, stash or check out other branches** unless the lead (or Brendan) told you to.
  Pushing needs an instruction.
- **Never print, log or commit an API key.** `MESHY_API_KEY`'s locations are in `docs/ENVIRONMENT.md`; its value is
  never in the repository.
- **Scan your diff for credential-shaped strings** before committing (for example
  `git diff --cached | grep -nEi 'api[_-]?key|secret|token|msy_|sk-[a-z0-9]'`).
- Commits use Conventional Commits and end with the co-author line your tool's instructions give (this session used
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`).

### 3.12 What a lane reports back

The commits; the suite's summary lines and the harness lines; the frame paths; the mutation counts; the review
outcome; every shared file and key touched; and the PROPOSALS needing Brendan's ruling.

## 4. How Brendan likes to work

- **Concise approval questions, each with a recommendation.** Number them. For each: what was built or is proposed,
  two or three lettered options, and "Recommendation: (x)". See the "For Brendan" sections of 0902 and 0903.
- **Group related items.** He rules on a batch at a time ("P1–P10 approved as built"). Collect a lane's proposals into
  one message rather than asking one by one.
- **Record his rulings verbatim.** Quote his words where he gave words ("Build both cellars", "The infirmary should be
  its own place and that's where residents go to rest and heal"). Put them in the lane's decision record under
  "Brendan's rulings (date)", and add a `DEC-nnn` to `docs/setting_decisions.md` when the ruling is a creative or
  policy one.
- **Plain language.** Short sentences, no jargon he has to decode, numbers where they matter.
- **He approves scope, then expects the lead to run it.** "Start as many concurrently as you can without conflicts,
  and auto start as conflicts are resolved" (2026-10-01). Keep him informed of results and questions, not of
  mechanics.
- **Art spend** is always asked first, itemised with credit costs (§3.8).
- **Windows builds** only on request.

## 5. Picking the next item, and the branch, PR and merge flow

1. **Check what actually landed.** The lead planned to merge the in-flight PRs before stopping. Run
   `git fetch origin`, `gh pr list --state all --limit 20` and `git branch -r`, and compare with STATUS.md.
2. **Pick from SEQUENCE.md**: the first packet whose dependencies have merged and whose files do not collide with a
   running lane. Open questions that block a packet are listed in it; ask Brendan before building those parts.
3. **Branch** from `origin/master`: `feat/<short-name>`, `fix/<short-name>` or `perf/<short-name>`, in its own
   worktree. Use the packet's decision range.
4. **Build, test, review, record** as in §3.
5. **Demo lanes go into an integration batch.** When several demo lanes are done, an integrator creates
   `integrate/review-batch-N` from `origin/master`, merges each branch `--no-ff`, reconciles the collisions (work-board
   source numbers, pantry item numbers, `setting_decisions.md` DEC order, ledgers), runs every gate staged and
   CI-style, and writes one record, `09xx`, with the table of branches, the reconciliations, what the gates found,
   "For Brendan" questions and, after he answers, "Brendan's rulings". Batches 6, 7 and 8 are decisions 0901, 0902 and
   0903; batch 9 would take **0904**. Settlement lanes (demolition, hauling, review fixes) open their own PRs.
6. **PR** with the template's three sections. Merge `origin/master` into the branch first if master moved, and rerun
   the gates.
7. **Merge when CI is green.** The required check is the aggregate "Godot headless suite" (decision 0991); every shard,
   gate group and contract job must pass. A PR with a non-`none` declaration waits for a human read.
   `tools/auto_merge.py` (dry run by default) checks the four conditions. Merge only when told to merge; the lead
   merged PRs in an agreed order (STATUS.md).
8. **After merging,** mark the task done in `work_queue.json` (settlement) and move to the next packet.
