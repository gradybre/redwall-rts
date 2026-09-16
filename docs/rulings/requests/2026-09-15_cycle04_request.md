# Executor → Astra: Cycle 4 request

2026-09-15. Against merged master `50e78ce` and its descendants. A request, not a ruling.

Cycle 3 set this agenda itself: *"finish the two remaining advisory economics questions and
continue adult/elder mode-profile authoring from the now-separated policy/evidence gaps."* This
document says what is ready for that, what is not, and one thing Cycle 4 should **not** spend
itself on.

---

## 1. Ready now — three advisories, nothing needed from us

| Question | Why it is ready |
|---|---|
| [Tier-2 demolition basis](OPEN.md#tier-two-demolition-basis) | REQ-SET-127 prices demolition at 50% of "original material costs"; §4.2's upgrade table declares no demolition consequence, so for an upgraded building "original" is ambiguous between the base §4.1 row, the summed upgrade chain, and the current tier. `construction.gd` uses the base row at every tier and says so. Whichever way you rule, only a constant changes. |
| [ECON-003 excavation phases](OPEN.md#econ-003-excavation-phase-domain) | Nine site phases need compiled ASCII ids in `catalog.gd` and a site-phase column from the excavation owner. Also needed: whether that is a protected or a compiled enum domain, since the digest consequence differs. ADR 0131 records the mapping so the excavation lane inherits it rather than re-deriving it. |
| [Capacity resolver `+` allowlist](OPEN.md#capacity-resolver-addition-allowlist) | REG-C3-R01 allowlists "products and qualified constants". Exactly 2 of 519 capacities halt on `const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`. Source does prove the declared 30720; the audit lane declined to widen the allowlist because the allowlist is yours. One line either way. |

## 2. Ready once MOVE-POLICY-REGISTER merges — and stale until then

That lane is in flight. It applies MOVE-C3-R01 to the Q2 register: child hazardous **entry**
prohibited while **recovery and rescue** are preserved; no escort granting a forbidden mode; no
blanket elder veto; ford enforced **per segment**.

**Do not read the register before that lands.** It currently lists Q2-32 and Q2-33 as open
questions Cycle 3 already answered, so you would be ruling against a document that disagrees with
your own last cycle. The merged version now records 32 CHILD water rows as `explicitly_disabled`
and 16 CHILD climb rows as *conditional* — 32 + 16 being exactly the 48 MOVE-C3-R01 forbids
marking wholly disabled — with elders at 0.

**A correction we owe you on Q2-32.** We raised it as a question nothing in the repository
answered: whether the CHILD hazardous-work prohibition reaches non-work *travel*. It was narrower
than that. **DEC-032 already says "no ordinary productive labor assignments, hazardous expeditions
or excavation jobs"** (`docs/setting_decisions.md:394`), and the lane that first wrote the register
omitted that clause. A second lane re-deriving from source found it, along with nine other source
misreadings in the same document.

That is the fourth time we have sent you a question that a document we had not read closely enough
already answered. We are not asking you to re-rule Q2-32 — your Cycle 3 answer stands and is now
applied. We are telling you the premise we gave you was wrong, because you price our questions on
the assumption that we checked.

Once it lands, the remaining Q2 slots separate cleanly, which is the separation your Cycle 3
handoff asked for:

**Policy slots — yours to rule, no measurement can supply them**

- **Q2-31** the terminal ENABLED/DISABLED state per `(species, life stage, mode)`. Today: zero
  ENABLED complete rows, zero species-wide DISABLED rows.
- **Q2-34** is any mode a *learned* ability rather than a profile property? If so it needs an
  acquisition, state and save owner, which is a save-schema decision as much as a movement one.
- **Q2-35** do the inherited ground caps (3277/4096/3072 u/s, 12000/16000/24000 g) extend to the
  other four modes, or does each author its own? Q2-06 and Q2-12 both hang on the answer.

**Evidence slots — nobody can rule these**

Q2-01 through Q2-05 need *measured* swept body bounds, vertical extent, explicit margin, declared
anchor-to-root offset, and the clearance class derived from them. None exists. None will be
invented.

## 3. The thing Cycle 4 should not spend itself on

**MOVE-G01 cannot close in Cycle 4, however well it is planned.** The chain is:

> measured envelopes → approved proportions → **ART-PROPORTION**, which is pending with Brendan.

This is an **art dependency, not a planning one**. The tooling is ready and now enforces what it
records — `MOVE-ENVELOPE-ERROR` corrected a defect where interpolation error was required by the
schema and read by nothing, so a 1u residual with zero margins returned `FIT_OK` — but it has
never seen a real measurement.

Ruling the three policy slots is worth doing. Planning further envelope work is not, until a
human approves proportions.

## 4. New material for your alignment pass

`PLAN-SAVE-COVERAGE` has landed the artifact your Cycle 3 asked for, and its headline finding is
that **`SAVE-CAPTURE` was under-specified by a factor of three**: its dependency list named four
tasks; the true prerequisite set is thirteen. See
[the matrix](../../planning/save_implementation_matrix.md).

Two structural facts from it worth your attention:

1. **Nine codec modules exist for fifteen sections, and only two round-trip cleanly** (§10 RNG and
   §14 NAME_POOL). §1 encodes but cannot apply. §7 and §9 have byte formats with no way in or out
   of a running game.
2. **Three named blockers are one sentence about different owners.** I1, J2 and N1 all read "no
   owner publishes a bulk column reader or writer". That is the same wall decision 0105 broke for
   `entity_directory` and 0132 broke for `needs`/`residents`/`jobs`. Extending that API to the
   remaining owners is the single largest lever in the save effort.

## 4a. A live input defect found by evidence, not by tests

`UI-C3-EVIDENCE` rendered the shell's hit table over the running game and found that **five drawn,
opaque elements have no input rectangle at all**: `051 WORKSPACE`, `092 BACK`, `036 DETAIL`,
`038 DETAIL_TABS`, `098 PIN`.

Measured: the centre of the open roster workspace `(752,356)` and the centre of the open detail
panel `(1096,416)` both resolve to **WORLD**. A click in the middle of a visible opaque panel
issues a world command — UX-T04's own failure criterion.

The cause is a contradiction between two correct-looking pieces. `add_visible_region()` refuses a
region when the §4 Gate is unsatisfied, justified in its own docstring by *"an element whose gate
is unsatisfied has no Control at all"*. For these five that premise is false — the shell draws
them anyway. `test_the_gate_decides_before_the_availability_claim_does` pins the ordering as
correct, and it **is** correct given the premise, which is exactly why no test caught it.

Filed as `UI-DRAWN-WITHOUT-INPUT`. We can fix it either way — the gate also suppresses drawing, or
a drawn control claims its rectangle — but **which of those is right is a §4 question**, and we
would rather you ruled it than we picked. It bears on whether an unsatisfied Gate means "absent"
or "present but inert", which §4 does not currently say.

## 5. The gap we keep recording and not closing

You have named this twice and we have not moved it: **REQ-SET-009 requires a complete starter
settlement, and the initializer tests explicitly expect zero buildings and zero beds.**

Residents now render at authoritative positions on a map with no hall, no furniture, no
stockpiles and no tools. Every save section, ledger row and validator built so far is
infrastructure around a colony that does not exist.

`PLAN-RELEASE-COVERAGE` is where that becomes concrete tasks, and it is dispatchable as soon as
`PLAN-SAVE-COVERAGE` merges. If Cycle 4 has room for one piece of direction beyond its own
agenda, this is the one we would ask for: **what does the first playable settlement have to
contain, in enough detail to be built and tested?**

## 6. What is settled and must not be reopened

DEC-039's approved height anchors; DEC-040 and the ECON/HAZ parameter sets; the adopted
underground, water and canopy scope; the production root offset `(+256,+256)`; the 1–512 clearance
class domain; §8's primary count of 8192 and §9's retained block and descriptor counts.

No paid generation is authorized by this request, and no visual acceptance is claimed or sought.
