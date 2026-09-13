# 0129 — The development loop stops only for art

**Status:** accepted. **Date:** 2026-09-12. **Supersedes nothing; extends [0128](0128-the-merge-gate-and-the-injury-double-budget-it-found.md).**

## Context

Development to this point has run as rounds: dispatch a wave of subagents, wait,
reconcile, merge, repeat, with a human deciding each time what could safely run
in parallel. That decision was made from memory, and memory failed. Two lanes
were dispatched against branches that did not contain the files they were told
to edit. Three were briefed against an artifact that was untracked in the
working tree. Recovering from one of those cost a file-by-file `git merge-file`
repair against a stale base, because `git apply --3way` rolls back atomically and
one conflicted file abandons all six.

Brendan asked for the rounds to stop being rounds: continuous dispatch, automatic
merging, and a standing review loop with Astra, for the rest of development —
with art, and only art, asking permission.

## Decision

The loop is specified in [`docs/automation/README.md`](../automation/README.md)
and implemented by five tools. The contract is that file; the tools follow it.

**`docs/planning/work_queue.json`** is the graph. Each task declares `status`,
`depends_on`, `owns` and `gate`. A task owning no files is a validation error,
because `owns` is the concurrency primitive and nothing else serialises it.

**`tools/dispatch_plan.py`** emits the largest set of tasks that can start now:
dependencies done, gate clear, and no owned path intersecting any other selected
task or anything `in_flight` **or `review`**. Including `review` is deliberate —
a task whose PR is open still owns its files, and a second lane editing them
produces exactly the conflict this exists to prevent. Selection order is by id
so a plan does not reshuffle between runs. `--validate` refuses duplicate ids,
unknown dependencies, cycles and art gates with no approval id, and runs in CI.

**`tools/auto_merge.py`** merges what survives four refusals: every required
check SUCCESS (not pending — I merged on pending CI twice here against an
explicit instruction, and got away with it both times, which is the argument for
a script); mergeable and not draft; `merge_gate.py` against the branch's own
ledger fetched at its head ref; and all three declaration blocks present and
empty. It never force-merges and never enables auto-merge.

**`tools/art_gate.py`** is the only gate that does not clear itself, and the
only one with no override. Paid generation spends Brendan's money and cannot be
undone by reverting a commit; visual acceptance is taste, and an agent accepting
its own art grades its own work. Approval is a human writing `approved` and a
name into `docs/planning/art_approvals.json`. There is no `--force` and no
agent-writable path, because a gate with one is decoration.

**`tools/astra_inbox.py`** and **`tools/review_packet.py`** are the planner's two
stable paths. `OPEN.md` is generated from `open_items.json` and CI refuses a
stale rendering — a hand-maintained index goes stale in about a week and then
quietly stops being read, which is how four lanes reported four blockers that
were one missing artifact. The review packet leads with declared deviations and
surviving mutants, before merged work, because those are the only entries where
the executor and the plan disagreed and they are what a good-faith summary
buries.

`.github/pull_request_template.md` carries the three declaration blocks, so the
report the merge gate reads is produced by default rather than remembered.

## Why the human stays in exactly two places

`DEVIATIONS` / `SURVIVED_MUTANTS` / `BLOCKED` keep a human in the loop without
keeping them in the way: most changes declare nothing and merge untouched, and a
change that overrules its brief stops and waits to be read. A lane once
overruled my brief correctly, citing SAVE-LAYOUT-R01's record-major exception
over the column-major instruction I had given it. A script that ranked that
would have been wrong whichever way it ruled, so it does not rank it.

Art is the other. Everything else in the pipeline is arithmetic, behaviour or
process, and all three are checkable.

## Consequences

Honest first output: the dispatcher reports **zero** tasks dispatchable. Five
lanes are in flight, three PRs are in review, and every remaining task is held
behind an Astra ruling or an art approval. That is a true statement about the
project, and a queue that invented work to look busy would be worse than one
that says so.

What the loop cannot do is listed in the contract and repeated in every review
packet: it cannot see work that was never added to the queue, cannot judge
whether a narrower implementation satisfies a broader requirement, cannot catch
a byte delta that is wrong but self-consistent, and measures no performance. The
first of those is the reason Astra's alignment pass exists and why absence is
the last item in every packet.
