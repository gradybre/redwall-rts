# CODEX TASK — Build the two remaining planning documents

> **Shape note:** this is a *task prompt for Codex*, which reads and writes
> files directly. It is not one of the `READY_*` paste-into-chat prompts.
> Point Codex at the repository below, not at a scratch directory — outputs
> must land in the repo so they stop going missing.
>
> If you are using ChatGPT web instead of Codex, use
> `READY_03_gameplay_balance.md` and `READY_04_systems_architecture.md`
> directly and attach the documents they name.

---

Work in the repository at `/Users/brendan/Developer/redwall-rts`.

## Read these first, in full

| Path | What it is |
|---|---|
| `docs/game_gdd.md` | Settlement Layer GDD — **authoritative**, 892 lines |
| `docs/ui_ux_controls.md` | Settlement UI/UX & controls — authoritative, 508 lines |
| `docs/crowd_rendering_architecture.md` | Battle-layer crowd rendering & performance, 1375 lines |
| `docs/game_concept.md` | Three-layer concept brief |
| `CLAUDE.md` | Project instructions; see its Document Authority section |

## Your two commissions

Full briefs already exist in this repository. **Read them and follow them
exactly** — they are the specification for what you are producing:

- `chatgpt-prompts/READY_03_gameplay_balance.md` → write `docs/gameplay_balance.md`
- `chatgpt-prompts/READY_04_systems_architecture.md` → write `docs/systems_architecture.md`

Those two files were written for a chat interface and open by telling the
reader to attach documents. Ignore that instruction only — you read the files
from disk instead. Every other rule in them applies unchanged.

Write both documents. Do not commit; leave the working tree dirty for review.

## Rules that override your instincts

**1. Every number in `docs/game_gdd.md` is immutable.** You may not adjust,
round, "improve", or re-derive one. If your analysis shows a GDD value produces
an unplayable economy or an unreachable performance budget, record it in that
document's `## Conflicts Found` section with the requirement ID and the
arithmetic, then keep using the GDD value everywhere else. Implementation
follows the GDD; a document that silently substitutes a better number produces
code that diverges from both.

**2. Integer arithmetic only.** Authoritative state is integer; float is
presentation and import only. Do not write a gameplay rule as a floating-point
or logarithmic formula. Express curves as integer tables, or as explicit
numerator/denominator pairs with the rounding rule stated for every division.

**3. Living population caps at 256.** Never tabulate, model, or extrapolate
beyond it. The GDD forbids that population existing.

**4. Cite everything you inherit.** Each constraint taken from an existing
document gets its source and section — `[GDD §5.2]`, `[crowd §4.2]`,
`[UI §1.2]`. Each value you originate is marked `[NEW]`. A reader must be able
to tell at a glance which numbers are load-bearing decisions already made and
which are yours.

**5. The two existing architectures have different scopes.** The crowd document
is battle-layer and allocates 2048 model slots; the settlement GDD caps at 256
living residents in 512 slots. They share conventions — packed integer columns,
`(slot, generation)` handles, 1/1024 m positions, 65536 yaw units — and a
settlement citizen keeps its persistent ID when entering battle. Serve the
settlement layer, stay compatible with the crowd store, and call out any place
the two impose incompatible requirements.

## Verify your own output before finishing

Run these against each file you wrote and fix what they catch:

```bash
# No placeholders survived. (Bare "..." is deliberately not matched: ASCII map
# diagrams use runs of dots legitimately.)
grep -nE "TBD|to be determined|\betc\.|TODO" docs/gameplay_balance.md docs/systems_architecture.md

# No population figure past the 256 cap
grep -nE "\b(300|400|500|1000|2000) residents\b" docs/gameplay_balance.md

# No floating-point or logarithmic gameplay formulas.
# Do NOT match "**" here — that is markdown bold, not exponentiation, and it
# fires on every bolded word.
grep -nE "\bln\(|\blog\(|\bexp\(|\bfloat\b" docs/gameplay_balance.md

# Required sections present
grep -c "## Conflicts Found" docs/gameplay_balance.md docs/systems_architecture.md
```

Every hit is either a defect to fix or a deliberate exception you explain in the
document. Report what each check returned when you finish.

No grep can reliably distinguish a decimal in a formula from one in a
performance budget such as `16.67 ms`, so **also spot-check by hand** that every
decimal you wrote is either a quoted GDD value, a time budget, or a ratio
expressed alongside its integer numerator/denominator form.

Then state plainly, in your final message: which requirements you could not
satisfy, which numbers you originated versus inherited, and anything in the
existing documents you believe is wrong. Do not smooth over a conflict to
produce a tidy document — a flagged contradiction is far more useful than a
clean file that quietly disagrees with the spec it was built from.
