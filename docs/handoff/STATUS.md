# Status at handoff — 2026-10-02

A snapshot taken on 2026-10-02 at about 18:40 UTC. **The lead planned to merge the in-flight PRs before stopping,
so some of what this file calls "open" may have landed.** Before starting anything, run:

```bash
git fetch origin
gh pr list --state all --limit 20        # what merged, what is still open
git branch -r                            # which branches were pushed
git log --oneline -15 origin/master
```

and compare with the two tables below. Branches that were never pushed exist only in the main checkout's local refs
(`/Users/brendan/Developer/redwall-rts`) and its worktrees under the session scratchpad; if that machine state is gone,
those branches are gone too, and this file says so for each.


> **Update at the end of the lead session (2026-10-02, later the same day).** Sections 1–2 below were
> written before the final merges. Since then these PRs **merged to master**: #221 (Codex review fixes
> R01–R06, decisions 0993–0998), #222 (batch 8: orchards and all three art passes wired, decision 0903),
> #223 (this handoff), #224 (measures phase 1 docs, decision 1011, DEC-049), #225 (settlement hauling
> H0–H2, decisions 1021–1024). Still open at handoff:
> - **#226 `fix/follow-ups`** (decisions 1041–1049): seven fixes plus three write-ups. Merge it when CI is green.
> - **`perf/route-planning`** (decisions 1001–1005): route planning, the meal and bedtime bursts, and the
>   kitchen "cook serves what's in the pot" fix. It had a master merge in progress; if no PR exists, check the
>   branch's working tree is clean against its HEAD, run the CI-style gates, open the PR and merge when green.
>   1005's tests are not yet mutation-tested or independently reviewed: do both before merging if time allows.
> - **The main checkout** `/Users/brendan/Developer/redwall-rts` is now on clean master. Its old working state
>   (about 360 changes from mid-September on `docs/executor-followup-rulings`) is saved on the **local, unpushed**
>   branch `backup/main-checkout-2026-10-02` and `stash@{0}`. `.codex/` and `.agents/` were left in place.
>   Some untracked Astra cycle-2/3 rulings and validators from 2026-09-14 may be worth recovering from it (Q-F1).
> Always confirm with `gh pr list --state all --limit 20` and `git log --oneline origin/master -20`.

## 1. Merged since 2026-09-30

All into `master` at `github.com/gradybre/redwall-rts`. "Decisions" are `docs/decisions/` records unless marked DEC.

| PR | Branch | What | Decisions |
|---|---|---|---|
| #199 | `integrate/review-batch-1` | Live demo plus review fixes B, C, D, E, G | 0222, 0231, 0241, 0251, 0261 |
| #200 | `feat/live-demo` | Tunnel revamp phase 6, the second level | 0212 |
| #201 | `integrate/review-batch-2` | Review fixes H, I, J, Q, R, tunnel P6 | 0292, 0301, 0331, 0332, 0351 |
| #202 | `integrate/review-batch-3` | Group A hand-offs and routing desk (A + D2), the CC0 sound files | 0361, 0351 |
| #203 | `integrate/review-batch-4` | Tunnel P7 assets, meals (N), panels at 720p (F), Work screen (M), spoil as earth (L) | 0371, 0381, 0391, 0401, 0411 |
| #204 | `feat/demo-day-length` | A game day lasts ten real minutes | 0421 |
| #205 | `fix/settlement-loose-ends` | APPOINT_WARDEN, truthful availability reasons | 0511, DEC-042 |
| #206 | `feat/demolition-d1` | Demolition D1: containment ruling, container anchor tiles | 0531, DEC-043 |
| #207 | `integrate/review-batch-5` | Water part B (B1, B2), planner (O), routes (P), session (S), guided village (U), named residents (T), review log | 0431–0436, 0441, 0442, 0451, 0461, 0471, 0481, 0491, 0492, 0493 |
| #208 | `feat/demolition-d2` | Demolition D2: ground piles and the refund ring | 0532 |
| #209 | `feat/family-pc04` | PC-04 adopted with children inactive | 0521, DEC-044 |
| #210 | `chore/test-hygiene` | Zero-warning, zero-leak, zero-unexpected-log gates | 0501 |
| #211 | `feat/demolition-d3` | Demolition D3: the starter colony stands and owns the stores | 0533 |
| #212 | `integrate/review-batch-6` | Notices, goals, playtest log, map layers, scale test, ferry and regatta | 0901 (+ lanes 0437–0439, 0561, 0562, 0581, 0591, 0781) |
| #213 | `docs/art-lock-request` | Paid generation by request, delegable within a cap | 0961 |
| #214 | `feat/demolition-d4` | Demolition D4: gate pass, preview/admit, the paid ledger | 0534 |
| #215 | `integrate/review-batch-7` | Winter, light, seasons, orders, camera, selection, cellar, hall, dishes, crops, infirmary, forage, chronicle, soak, balance, pause card | 0902 (+ lanes; see 0902's table) |
| #216 | `codex/review-2026-10-02` | The independent review of batches 5–7 and D1–D4 (doc only) | `docs/reviews/2026-10-02-codex-review.md` |
| #217 | `feat/demolition-d5` | Demolition D5: one-commit completion, furniture by type | 0535, 0536 |
| #218 | `codex/ci-shard` | Sharded CI (longest job about 9 min, from about 55) | 0991 |
| #219 | `feat/demolition-d6` | Demolition D6: removal work under BUILD, evacuate-then-demolish intent | 0537 |
| #220 | `feat/store-filters-h6` | Hauling H6: store filters, store minimums, SET_STORE_* commands (merged 18:32 UTC) | 1031 |

`master` at the snapshot: `7dadb0f0` (the #220 merge).

## 2. In flight

The agreed merge order (coordinator, 2026-10-02): **batch 8 → review fixes → perf → H6 (done) → H0–H2.** Each later
branch merges `origin/master` again before its PR and reruns the gates.

| Branch | PR / pushed | Head at snapshot | Behind master | Decisions | State |
|---|---|---|---|---|---|
| `integrate/review-batch-8` | **#222 open**, CI running | `9e31d2e5` | 4 commits (#220 and its merge) | 0903; lanes 0671–0677, 0941, 0951, 0971, 0972, 0981; DEC-047, DEC-048 | Built, gated, Brendan's nine rulings applied |
| `fix/codex-review` | **#221 open**, CI partly run (shards 0–6, contracts, metadata-a/c passed; shard 7, analyzer, metadata-b pending) | `e25499d7` | 4 | 0993–0998; 0561 amended | Built, rulings recorded |
| `perf/route-planning` | **not pushed**, no PR | `a7ba04c2` + uncommitted work | 20 (based on batch 7's merge `d75d9d89`) | 1001–1004; 1005 reserved, not yet written | Built; the kitchen fix (1005) in progress |
| `feat/hauling-h0-h2` | **not pushed**, no PR | `cc17d569` | 4 (has #219, not #220) | 1021–1024 | Built, rulings recorded |
| `feat/demo-measures` | **not pushed**, no PR | `1f0266e2` | 15 | 1011, DEC-049 | Phase 1 (documents) done; phase 2 not started |
| `fix/follow-ups` | **not pushed**, no PR | `f31ddbe6` | 4 | 1041–1043 written; 1044–1049 reserved | In progress: three fixes committed, a fourth under way |

Branches that are not pushed live only in the local refs of `/Users/brendan/Developer/redwall-rts` and in their
worktrees under the session scratchpad (`.../scratchpad/wt-perf`, `wt-haul`, `wt-measures`, `wt-followups`). If they
are not on `origin` when you start, look there first (`git -C /Users/brendan/Developer/redwall-rts branch --list`).

### 2.1 `integrate/review-batch-8` (PR #222)

- **Contains** `origin/master` (to #219) plus six branches merged `--no-ff`: `feat/demo-orchards` (0671–0677),
  `art/new-foods` (0941), `art/second-pass` (0951, DEC-047), `art/third-pass` (0971, DEC-048; the UI art lock amended
  for render-style item icons), `art/style-probe` (0981, ledger only) and `art/flax-icons` (0972). Then the art wired
  into the demo, with every piece falling back to its stand-in when unstaged. New tool `tools/stage_art_passes.py` and
  `stage_demo_assets.py --only art`.
- **Reconciliations** (0903): one `berries` item (29, `CAT_BERRIES` 12), apple 30 and pear 31 (`CAT_FRUIT` 13),
  `PANTRY_ITEM_COUNT` 32; `SOURCE_ORCHARD` 13, `SOURCE_COUNT` and `SOURCE_WALK` 14; `RAW_NP_PER_U` the union; a
  silently duplicated `farm_pantry.gd reserve_at_into` unified; `setting_decisions.md` ordered DEC-044 to DEC-048.
- **Gates** (0903): 8768 tests staged and CI-style, 0 failures, 0 unexpected, 0 leaks; after merging master, 8 shards
  8925 tests, 0 failures; analyzer 0 warnings in 1008 files.
- **Brendan's rulings** (2026-10-02): all nine 0903 recommendations approved (RULINGS.md).
- **Left before merge:** CI green on #222. It is 4 commits behind master (#220 touched only settlement files and
  docs, so a clean merge is expected; unverified).
- **After merge:** restage the art in any checkout you run or build from (README §3.9).

### 2.2 `fix/codex-review` (PR #221)

- **Contains** fixes for the 2026-10-02 Codex review (`docs/reviews/2026-10-02-codex-review.md`) findings R01–R06,
  as Brendan ruled them on 2026-10-02:
  - R01, one village cloth that the hall, the infirmary and treatments reserve (0993);
  - R02, opening-stock provenance kept on the pantry's lots (0994);
  - R03, the infirmary heats itself with its own hearth and fuel (0995; Brendan's P1 and P2 rulings recorded there);
  - R04, household bindings keep the whole directory EntityRef (0996; family owner now 48,400 bytes);
  - R05, a meal is finalized once its last bowl is eaten or given back (0997);
  - R06, the scale test's exit report must be empty (0998), and every leak gate counts the engine's singular
    "leaked object" line.
- R07 (route budget) is `perf/route-planning`, below.
- **Left before merge:** CI green; then, after batch 8 merges, merge `origin/master` and rerun the gates.
  **Expect a conflict in `godot/demo/kitchen/kitchen.gd`** (this branch adds about 160 lines of meal-finalizing
  code; batch 8 adds about 22) and possibly `demo_village.gd` (one line here).

### 2.3 `perf/route-planning` (not pushed)

- **Contains** Codex review R07 and the scale test's recommendations, approved by Brendan on 2026-10-01 ("route
  planning and bursts, and the smaller fixes"; crowd path and capacity limits **not now**):
  - 1001, one route plan is local and divisible, and the routing desk carries it across frames;
  - 1002, one field per shared goal guides a crowd's plans, away from the goal;
  - 1003, the meal call and dusk send at most eight residents a frame;
  - 1004, residents by cell for the walking step, people's pairs by bucket, a claim index that does not grow.
  - Measured in `docs/performance/2026-10-02-route-planning.md`: the bursts are gone at 50 (frame p95 under 10 ms);
    100 residents at 17–21 ms p95; 256 runs at 40–49 ms p95 (from 207–302 ms).
- **In progress at the snapshot (uncommitted):** decision **1005**, Brendan's "fix kitchen now" ruling: the cook
  serves what is in the pot as it is cooked ("SERVED AS IT IS COOKED"; without it, supper fed no one at 50 residents
  and above), diners without a seat wait at wait spots, and a trip whose plan found no route waits 2 s before
  replanning ("NO WAY YET"). Changed: `kitchen.gd`, `kitchen_places.gd`, `resident_brain.gd`; a scratch file
  `godot/test/zz_focus_tmp.gd` must not be committed.
- **Rulings not yet written in:** the four proposals in 1001–1004 (wanderers show "finding a route"; a guided route
  may be up to 15% longer; eight a frame; owners publish a waiting revision) were approved by Brendan on 2026-10-02
  (coordinator's tracker: "RULINGS approved", which in this session meant each record's recommended option) but still
  read "PROPOSAL (Brendan)". Record them before the PR, naming the option each record recommends.
- **Left before merge:** finish and record 1005 (tests, mutation, review); merge `origin/master` (20 commits behind:
  batch 8, the review fixes and #220 will all be on master by then); **expect conflicts in `kitchen.gd`** with both
  batch 8 and #221; rerun every gate CI-style; push; PR.

### 2.4 `feat/hauling-h0-h2` (not pushed)

- **Contains** task 06.4's first three hauling slices: the hauling packet
  (`docs/planning/construction_execution_package.md`), queue entries `HAUL-H0`…`HAUL-H8`, the per-haul satchel
  (`haul_carry.gd`), claim-carrying load and unload, the ground-pile mover, the payload sizer, destination selection
  (`haul_planner.gd`), numbered reservation purposes; decisions 1021–1024 and Brendan's rulings R-H1–R-H14
  (BACKLOG.md hauling packets). Suite 8878 tests, 0 failures; mutation 81 mutants, 75 killed (the record gives the
  survivors' reasons; check the PR declares any left).
- **Memory:** +196,608 B for the haul record and +34,956 B scratch (1023).
- **Left before merge:** merge `origin/master` (now including #220 H6). **Expect conflicts in the memory ledger
  files** that both touch: `docs/validation/ready07_arithmetic.py`, `docs/systems_architecture.md` §2–§3,
  `docs/persistence_state_registry.md` and `docs/planning/registry_capacity_audit.json`. Recompute the totals, do not
  hand-merge them (a research pass estimated payload 70,959,904 B and live 79,348,512 B combined; unverified), and
  regenerate the capacity audit (`tools/audit_registry_capacities.py`). Rerun gates; push; PR.
- Also fixes stale queue rows on master: `DEMOLITION-D6` and `GROUND-CLEARANCE-ADMISSION`. `DEMOLITION-D1` still
  reads `review` on both master and this branch although it merged as #206; fix it in the next queue edit.

### 2.5 `feat/demo-measures` (not pushed)

- **Contains** phase 1 of the measures work, documents only: decision 1011 (goods counted in natural measures; the
  "U view" becomes "Underground", keeping the U key), DEC-049 in `setting_decisions.md`, and amendments to
  `docs/ui_ux_controls.md` (UI-SET-004, -005, -050, -099). Brendan's rulings on the table and P1–P10 are recorded.
- **Left:** phase 2, the implementation (BACKLOG packet MEAS-2). Merge or rebase onto master first: **DEC-049 must sit
  after DEC-048** in `setting_decisions.md` (batch 8 adds DEC-047 and DEC-048 above where this branch put DEC-049).
  Either PR phase 1 on its own after batch 8, or carry these three commits into the phase 2 branch.

### 2.6 `fix/follow-ups` (started 2026-10-02)

- A lane started near the end of the session for the small follow-up fixes, decision range 1041–1049. Its brief is
  not in the repository. **Not pushed** at the snapshot. Done so far (local commits):
  - 1041, `3e4cae13`: the routes harness lays its dig where nobody stands (the "dig: confirm refused" flake, Codex R08);
  - 1042, `878bc89c`: the setting contract counts `excavated_earth`, and CI now runs it;
  - 1043, `f31ddbe6`: the leat head's obstacle is (x, radius, z), so Tegwin is no longer stuck in the cabbage bed.
- In progress (uncommitted): `forestry/forest_marks.gd`, `demo_village.gd` and `test_demo_lens_probes.gd`, most likely
  the Woods marks' colour-blind fix.
- **Left:** finish, gates CI-style, review, push, PR. BACKLOG.md packet FOLLOW-UPS lists every candidate item; strike
  what this branch's decisions 1041–1049 finished.

## 3. Shared state worth knowing

- **The main checkout is stale; do not build from it.** `/Users/brendan/Developer/redwall-rts` sits on
  `docs/executor-followup-rulings` (merged as #61 on 2026-09-12) with 361 changed paths in its index and working tree
  (mostly staged additions), far from `origin/master`. Their origin was not established in this session. **Do not
  commit, stash, reset or discard them** without asking Brendan (OPEN_QUESTIONS Q-F1). For runs and the Windows build,
  use a fresh worktree of `origin/master` and stage art with `--library /Users/brendan/Developer/redwall-rts/assets/library`.
- **The local `master` ref is stale** (`52255a49`). Always branch from `origin/master` after `git fetch`.
- **About 100 worktrees** are registered (`git worktree list`), most under the session scratchpad, 15 marked
  prunable. Worktrees of merged branches can be removed (`git worktree remove <path>`); never remove one with
  uncommitted work without reading it first (`wt-perf` and `wt-followups` had some at the snapshot).
- **CI** is sharded (decision 0991): eight suite shards, four gate groups and the specification contracts, about
  9 minutes; the required aggregate check is "Godot headless suite". Batch 8's last full count: 8,925 tests, 0
  failures, 272 expected and 353 tolerated diagnostics, 0 unexpected, 0 leaks (0903, CI-style shards).
- **Known flakes:** the routes live harness's dig confirm at 1280x720 (Codex R08; fixed by 1041 on `fix/follow-ups`, not yet merged); the layout
  harness's "party 9" check under heavy load (0902); the analyzer right after the import cache is restored (0903).
  Rerun once; never change a budget.
- **Numbering at batch 8:** work-board sources `SOURCE_FARM` 0 … `SOURCE_ORCHARD` 13, `SOURCE_COUNT` = `SOURCE_WALK` =
  14; pantry items up to `ITEM_PEAR` 31, `PANTRY_ITEM_COUNT` 32, categories up to `CAT_FRUIT` 13; decisions up to 0991
  on master and 0903 in batch 8, 0998 (#221), 1004 (perf), 1011 (measures), 1024 (hauling), 1031 (#220); DEC-046 on
  master, DEC-048 in batch 8, DEC-049 on the measures branch. Free decision gaps: 0992, 0999, 1006–1010, 1012–1020,
  1025–1030, 1032–1040; 1005 is perf's; 1041–1049 are `fix/follow-ups`'; 1101–1560 are BACKLOG.md's.
- **Rulings given but not yet written into the repository** (record them in the named place when you touch it):
  - perf 1001–1004's four proposals, "rulings approved" (Brendan, 2026-10-02): the records still read
    "PROPOSAL (Brendan)" on `perf/route-planning`;
  - "fix kitchen now" (Brendan, 2026-10-02): decision 1005 is not written yet;
  - the ferry and regatta goals, "YES" (2026-10-01): GOALS-2 records it;
  - the approved feature list (#9, #11, #18, #19, #23, #24, #31, #33, #34, #37, #49, #51, #54, #55, #56, #59), hives
    "start soon", the not-chosen list, "crowd later", the feast kept at 17:00: RULINGS.md is their first repository
    record.
- **Meshy balance** was about 98 credits after the flax icons (0972); not rechecked (`meshy_check_balance` is free).
- **Machine load.** This session ran up to about 20 agents at once and hit a concurrent-subagent limit of 20
  (reviewers included); timing tests flaked above a load of about 35. Keep to about 15 feature lanes so each can run
  its reviewer.
