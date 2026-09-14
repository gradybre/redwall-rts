# The development loop

The whole of development after this point runs as one cycle that repeats without
being asked. It has exactly one stop: **art**. Everything else — dispatch,
implementation, testing, pull requests, CI, merging, unblocking the next wave —
runs to completion without a human in the path.

This document is the contract. The tools implement it; if they disagree with
this file, the tools are wrong and get fixed.

## The cycle

```
                    docs/planning/work_queue.json
                                │
                                ▼
                    tools/dispatch_plan.py
        ┌───────────────────────┴───────────────────────┐
        │  largest set of ready tasks whose owned       │
        │  files do not intersect each other or         │
        │  anything already in flight or in review      │
        └───────────────────────┬───────────────────────┘
                                ▼
                    subagents, one per task
                    each with an explicit file allowlist
                                │
                                ▼
                    PR, using .github/pull_request_template.md
                    with DEVIATIONS / SURVIVED_MUTANTS / BLOCKED
                                │
                                ▼
                    CI: contracts job, then godot job
                                │
                                ▼
                    tools/auto_merge.py
        ┌───────────────────────┴───────────────────────┐
        │  four refusals: CI all green, mergeable,      │
        │  merge_gate.py against the BRANCH's ledger,   │
        │  and all three declarations empty             │
        └───────────────────────┬───────────────────────┘
                                ▼
                    merged → status done → dependants unblock
                                │
                                └──────────► back to dispatch_plan
```

Two side channels feed the same queue:

```
  questions the executor may not answer      art that needs a human eye
              │                                        │
              ▼                                        ▼
  docs/rulings/requests/OPEN.md          docs/planning/art_approvals.json
  (generated, tools/astra_inbox.py)      (ONLY Brendan writes this)
              │                                        │
              ▼                                        ▼
  Astra rules → docs/rulings/*.md         Brendan writes `approved`
              │                                        │
              └────────────► work_queue.json ◄─────────┘
                             gate cleared, task dispatchable
```

## Why it stops for art and nothing else

Two things here cannot be undone by reverting a commit, and neither can be
judged by a machine:

**Paid generation spends real money.** Meshy credits come out of Brendan's
account. `tools/art_gate.py` refuses any generation whose id is not `approved`
in `docs/planning/art_approvals.json`, and it prints the credit cost when it
refuses so the ask always arrives with the number attached. There is no
`--force`, no environment variable and no agent-writable path to an approval.
If there were, the gate would be decoration.

**Visual acceptance is taste.** Whether the badger reads as a badger, whether
the HUD looks right at NARROW. No test asserts that, and an agent that accepts
its own art is grading its own work. Decision 0002 additionally forbids bulk
creature generation before proportion approval — a sequencing rule that green CI
does not satisfy.

Everything else is arithmetic, behaviour or process, and all three are checkable.

## Ownership is the concurrency primitive

Two agents editing one file is the failure this system exists to prevent. It has
happened here, and the recovery cost real work: `git apply --3way` rolls back
atomically, so one conflicted file abandons all six and the repair is
file-by-file with `git merge-file` against a stale base.

So every task in `work_queue.json` declares `owns`, and the dispatcher will not
emit two tasks whose `owns` intersect. A trailing `/` is a directory prefix. A
task in `review` still owns its files — its PR is open, and a second lane
editing them produces exactly the conflict being avoided.

A task that owns no files is a validation error, because nothing serialises it.

## The four refusals before a merge

`tools/auto_merge.py` merges only what survives all four, and prints the named
reason for every hold.

1. **Every required check is SUCCESS.** Not pending, not "no checks configured".
   I merged on pending CI twice against an explicit instruction not to, and got
   away with it both times. That is the argument for a script doing this.
2. **Mergeable, not draft, no conflicts.**
3. **`merge_gate.py` passes against the branch's own ledger** — fetched at the
   PR's head ref, not master's. The ledger chain, the cross-form double budget
   and the row arithmetic. See [ADR 0128](../decisions/0128-the-merge-gate-and-the-injury-double-budget-it-found.md).
4. **`DEVIATIONS` / `SURVIVED_MUTANTS` / `BLOCKED` are all empty, and all
   present.** A missing block holds the PR exactly as a non-empty one does.

   `BLOCKED:` means **this change is not safe to merge**. It does NOT mean
   "downstream work remains blocked": a lane that honestly scopes what it did
   not claim is doing the right thing, and holding its PR for that would teach
   every future lane to under-report scope to get through the gate. A gate that
   punishes honesty gets lied to. Scope a lane deliberately left open belongs in
   the PR body as prose, not in this field. §11's codec not existing is not a
   reason to refuse §11's store.

Check 4 is what keeps a human in the loop without keeping them in the way. Most
changes declare nothing and merge untouched. A lane that overrules its brief may
be right — one was, citing SAVE-LAYOUT-R01 over the instruction I had given it —
and a script that ranked that would be wrong whichever way it ruled. So it does
not rank it. It stops and surfaces it.

## Running one turn of the loop

```bash
python3 tools/dispatch_plan.py            # what can start right now, and why the rest cannot
python3 tools/auto_merge.py               # dry run: what would merge, and what holds each PR
python3 tools/auto_merge.py --merge       # act
python3 tools/astra_inbox.py              # regenerate OPEN.md from open_items.json
python3 tools/review_packet.py            # build the packet Astra reviews
python3 tools/art_gate.py --list          # what is waiting on Brendan
```

CI runs `dispatch_plan.py --validate` and `astra_inbox.py --check` in the
contracts job, so a malformed graph or a stale inbox fails in under a minute
rather than silently dispatching nothing.

## What this cannot do

Worth writing down, because a pipeline this automatic invites more trust than it
has earned:

- **It cannot tell a branch-deletion hazard from a tidy-up.** It learned one:
  merging a PR that other PRs are based on must NOT delete its branch, because
  GitHub closes those PRs rather than retargeting them, and a closed PR whose
  base branch is gone cannot be reopened. That specific case is now handled;
  the general class is not.
- **It cannot see absent work.** Nothing in this repository detects a task that
  was never added to the queue. That is what Astra's periodic review is for, and
  it is the last item in every review packet for that reason.
- **It cannot judge whether a narrower implementation satisfies a broader
  requirement.** A lane that implements half of what was specified, correctly,
  passes every check here.
- **It cannot catch a delta that is wrong but self-consistent.** L1 verifies the
  chain, not whether a decision's byte count was computed correctly in the first
  place.
- **It does not measure performance.** The 100 MB ledger cap is a budget to
  measure against, not a claim. A measured overrun still fails qualification.
