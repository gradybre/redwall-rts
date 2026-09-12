# 0059 — Allocate before consume is a repository-wide rule

Date: 2026-09-11 · Status: **Accepted** (executor; records existing practice)

## The rule

**A refusal leaves every collaborating store byte-identical.** Every capacity
check, domain check, ownership check and resource check a call needs must run
and pass *before* that call writes, clears, decrements or reserves anything. A
call that discovers a problem halfway through has already violated this rule,
however carefully it unwinds.

The consequences that follow from it, all already relied on in the code:

- A refused command costs nothing. There is no partial application, so no caller
  has to compensate for one and no test has to assert what a half-applied
  operation leaves behind.
- Refusals are therefore testable by inspection of the state that was supposed
  to change. `test_command_dispatch.gd`'s refusal tests assert the refusal code
  *and* that the named row is untouched — for example a `CANCEL_JOB` pointed at
  a resident refuses by kind "and the resident it pointed at is untouched". A
  rule stated only as "costs nothing" would not be checkable; one stated as
  "leaves the store as it was" is. The stronger whole-store byte comparison is
  available where a test wants it, but is not how the current suite is written.
- Multi-store operations are atomic without a transaction mechanism. Because
  every store validates before any store writes, the group either applies
  everywhere or nowhere, and the repository needs no rollback log.
- Failure ordering is a design constraint, not an implementation detail. When a
  check can only be performed after a write, that is a signal to restructure the
  call, not to add an unwind path.

## Why this record exists

Forty-three comments across seventeen files cite *"decision 0024"* for this
rule. The lineage is real but the citation does not carry the rule.

[Decision 0024](0024-work-tick-optimization-order.md) is *"Work-tick optimisation
order and workload references"*. Its §1 does state the hazard, at lines 36–39,
in terms:

> `_commit()` currently consumes remaining work *before* `_allocate_shares()`.
> Moving a potentially failing read into `_distribute_leftover()` would introduce
> a failure **after progress was already consumed**.

That is the rule's origin, and it is why the citations are not baseless. But it
names the hazard **at one call site, about one refactor**, and it never promotes
it to anything binding on `gear.gd`, `fishing.gd`, `command_dispatch.gd`,
`world_init.gd` or any other store. A reader following the citation from
`gear.gd`'s pool allocator arrives at a document about tick optimisation order
and finds no rule there.

**This corrects [decision 0052](0052-resource-ids-are-compiled-item-definition-keys.md).**
That record says 0024 *"contains no such rule"* and calls the citation *"wrong"*
and the record *"unrelated"*. That is too strong: 0024 names the hazard, it just
never generalises it. 0052's instruction — *"write the missing record under a new
number or repoint the citations — not invent a third number"* — is what this
record carries out.

## Which citations change and which do not

Not every reference to 0024 is a mis-citation. Three of its sections have real,
specific subjects that modules correctly point at:

| Citation | Stays at 0024 | Why |
|---|---|---|
| `work.gd` lazy identity reads | yes | 0024 §1 is exactly this |
| `work.gd` `tick_*_into` entry points | yes | 0024 §2 is exactly this |
| `needs.gd` / `work.gd` one fused reader call | yes | 0024 §4 is exactly this |
| `work.gd:776` "decision 0024's named hazard" | yes | it *is* the named site |
| everything citing it for the general rule | **repoints to 0059** | 0024 does not state a general rule |

## Scope of this change

**This record only.** The comment sweep was deliberately a separate change:
`gear.gd`, `fishing.gd`, `world_init.gd` and `job_planner.gd` were owned by
in-flight branches when this record was written, and rewriting comments
underneath a running agent is how merge conflicts and lost work happen. The
sweep was to land when the tree was quiet, reclassifying each citation against
the table above rather than replacing the number everywhere.

**The sweep has since landed** (branch `docs/allocate-before-consume-sweep`).
Twenty-three citations across ten files were repointed to this record;
twenty-six were left at 0024 because §1, §2, §4 or the named hazard is genuinely
their subject. One remains outstanding: `world_init.gd:13`
(*"ALLOCATE BEFORE CONSUME, AT WORLD SCALE (decision 0024)"*) is a general-rule
citation that belongs here, but that file was under concurrent ownership during
the sweep and was left byte-untouched. It is the only known unrepointed
general-rule citation.

## What this does not do

It does not change any code, any behaviour, any gameplay constant or the memory
ledger. It does not create a new rule: every module already implements this, and
several say so in their own headers. It records one that was being obeyed and
cited without ever having been written down.
