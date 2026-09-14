# 0139 — A declared grammar for the declaration blocks, and a packet that labels its own evidence

Date: 2026-09-14
Status: Accepted
Owner: packet-evidence lane (task 09)

## Context

`tools/review_packet.py` printed **"None in this window"** under the heading
"Declared exceptions". That sentence was read as a finding. It was not. It was
an artefact of where the generator looked:

- it read **local HEAD commit bodies**, not the final pull request bodies where
  the declaration blocks are actually written and edited;
- it listed merges with `git log --merges`, which **omits every squash-merged
  PR**, because a squash result has one parent;
- it could not see anything merged after the local ref was last fetched.

A read-only GitHub query over `merged:2026-09-10..2026-09-14` returned **103
merged PR records** (limit 200, so not truncated). The old generator listed 50
PRs drawn from local commits. **49 further in-window PRs reachable from cached
master were absent** — 40 one-parent results plus nine later two-parent merges —
and three more were not reachable from that ref at all. The evidence is
preserved at `docs/planning/astra_cycles/cycle_01_merged_prs.json`.

Astra's verdict on what that means, which this decision adopts verbatim:

> Missing declarations are **missing evidence**, not approved exceptions or a
> retroactive finding that older work violated a then-nonexistent gate.

Of the 103 records, **nine** carry all three declaration blocks and **94** carry
none of them.

Separately, the parser itself was a heuristic. PRs #103 and #104 both wrote:

```
SURVIVED_MUTANTS: none — two survived initially, both were REAL DEFECTS and
both were fixed (...). All seven required mutants were re-run against the final
source and all died.
```

The old rule was `value.lower() not in ("none", "none.")` → non-empty → reported
as a declared exception. Astra:

> Those explanations are not final survivors. The existing parser ... needs a
> declared grammar and tests, not a heuristic that silently discards arbitrary
> text after "none".

## Decision

### 1. The packet reads merged pull request bodies, and paginates

`gh pr list --search 'merged:<from>..<to>' --state merged --limit <n> --json
number,title,body,mergedAt,mergeCommit`. Commit messages are used for nothing
except one labelled reachability cross-check.

`gh pr list --search` exposes no cursor, so **pagination is by time**. A
sub-window that returns exactly `--limit` rows may have been cut short, so it is
split into two overlapping halves and re-queried; results are de-duplicated by
PR number. A one-second window that still saturates cannot be subdivided, so the
tool **raises** — it does not return a short list. Verified: the same window
returns the same 105 records at `--limit 100` (3 sub-queries) and at
`--limit 10` (37 sub-queries).

### 2. The declaration grammar, v1

Printed into the tool's docstring, into `GRAMMAR`, and into the packet itself so
a reader can check a verdict without reading the source.

```
declaration ::= line_start , margin , emphasis , NAME , emphasis , ":" , value , EOL
margin      ::= { " " | "\t" | ">" | "-" | "+" | "*" }
emphasis    ::= { "*" | "_" | "`" }
NAME        ::= "DEVIATIONS" | "SURVIVED_MUTANTS" | "BLOCKED"   (uppercase, exact)
value       ::= { character - EOL }

normalise(value) = strip whitespace and * _ ` from both ends, then strip one
                   trailing "."

CLEAR      <- normalise(value) case-folds to exactly "none"
MALFORMED  <- normalise(value) is empty
QUALIFIED  <- case-folded value begins "none" followed by a non-word character,
              and anything else remains
DECLARED   <- anything else
MISSING    <- no declaration line for that NAME anywhere in the body
```

Two or more lines for one NAME: **every** occurrence is printed and the block
takes the **most severe** outcome, `DECLARED > MALFORMED > QUALIFIED > CLEAR`.

### 3. `none — <explanation>` is QUALIFIED: neither cleared nor counted

This is the load-bearing choice, and it is deliberately **not** binary.

The brief set two constraints that no two-valued answer satisfies:

1. a lane must not be able to hide a real survivor behind the word "none";
2. a lane that honestly explains a *killed* mutant must not be reported as
   carrying one.

Calling `none — ...` **empty** breaks (1): `SURVIVED_MUTANTS: none — M7 is still
alive, we shipped anyway` would clear. Calling it **non-empty** breaks (2), and
is what misreported #103 and #104, both of which describe mutants that died.

No regular expression can tell those two strings apart, because the difference
is in the meaning of the prose. So the parser **refuses to decide**. QUALIFIED
is its own outcome: it is not counted as a survivor, it is not counted as clean,
it is printed **in full** in its own packet section, and the section says in
plain words that only a human can grade it. This is the same posture as
AGENTS.md's rule against sentinel returns — a value that cannot be determined is
declared undetermined rather than folded into a neighbouring one.

Two consequences follow and are accepted:

- **`n/a`, `N/A`, `nil`, `—` are DECLARED, not CLEAR.** Only the literal word
  `none` clears a block. Widening the vocabulary widens the hiding place.
- **Case matters: a lowercase `deviations:` is MISSING, not a declaration.** A
  lane that evades the gate by casing therefore lands in the *louder* bucket,
  not the quieter one, so the incentive points the right way.

### 4. A table cell is not a declaration

`|` is excluded from `margin`. `.github/pull_request_template.md`, PR #106 and
`tools/auto_merge.py`'s own documentation all contain markdown tables whose
cells name the blocks; a row such as ``| `DEVIATIONS:` | must be `none` |`` is a
specification of the mechanism, not a lane declaring anything about its own
change. Mid-line mentions are likewise not declarations. Both are pinned by
negative tests, because a parser that counts prose is precisely how "None in
this window" got printed over 94 PRs that declared nothing.

### 5. The packet labels its own evidence, in the artifact

Not in a log. `docs/planning/review_packet.md` now opens with an **Evidence
basis** block naming the source (live query, or a preserved snapshot with its
sha256), the requested window, the observed `mergedAt` range, the record count,
the local ref used only for cross-checks, and an explicit truncation statement.
`§9 What this packet could not see` enumerates the blind spots by name.

When zero records are audited the packet prints, in the file:

> **THIS PACKET CANNOT DISTINGUISH "no exceptions" FROM "no evidence".**

A snapshot source always reports truncation as **unknown**: a preserved snapshot
is evidence of what was seen, not proof of what existed.

Declared and qualified text is **never** shortened. Only incidental fields take
a bound, and those show an ellipsis when they hit it.

## Consequences

Regenerated over the preserved 103-record corpus, the packet reports
**2 DECLARED** (#112 `SURVIVED_MUTANTS`, #104 `DEVIATIONS`), **2 QUALIFIED**
(#103 and #104 `SURVIVED_MUTANTS`), **0 MALFORMED**, and **282 MISSING**
block-instances across 94 PRs, with 6 PRs declaring all three blocks as an
unqualified `none`. The old generator reported none of this.

## Alternatives rejected

- **Keep reading commits, and just widen the regex.** The 49 absent PRs are not
  a regex problem. No parser improvement reaches a PR body that the source never
  loaded.
- **Treat `none — <prose>` as CLEAR and rely on the human reading the PR.** The
  packet exists because that human read is what gets skipped.
- **Fail the packet on a QUALIFIED block.** The packet is a review artifact, not
  a gate; `tools/auto_merge.py` is the gate, and it already holds these PRs.
- **A fixed `--limit 200` with a truncation warning.** A warning that nobody
  reads is how this defect happened. Bisect-or-raise cannot be ignored.

## Reported, not fixed here (outside this lane's allowlist)

- `tools/auto_merge.py::check_report` accepts an **empty** block as passing:
  `match.group(1).strip().strip("*").lower() not in ("none", "none.", "")`. A PR
  body containing a bare `DEVIATIONS:` with nothing after it therefore
  auto-merges. Under this grammar that is MALFORMED and must hold the PR. It
  also uses `re.search`, so it reads only the **first** occurrence of a block
  and a later `DEVIATIONS: none` line is invisible to it — the opposite of the
  most-severe-wins rule adopted here. Owner of `tools/auto_merge.py` should
  adopt `review_packet.classify_value()` rather than keep a second parser.
- `docs/planning/astra_cycles/cycle_01_merged_prs.json` is a bare JSON list with
  no query metadata, so the tool cannot read back the window, limit or ref that
  produced it and must infer the window from the `mergedAt` range. The loader
  already accepts a `{"query": {...}, "records": [...]}` form; populating it is
  the snapshot owner's call, not this lane's.
