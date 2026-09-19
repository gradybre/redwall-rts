# PC-04 / FAMILY-C4-R01 version 1 draft — independent review

2026-09-19 · Independent reviewer · **Review only. No code, schema, fixture or command was
written, and nothing was run, applied or verified by execution.**

**Subject.** `docs/planning/family_execution_package.md`, version 1 draft, sha256
`3a9819fb…5d15c`.

**Disposition.** **NOT ACCEPTED as PC-04.** The draft correctly states that it closes
proposed coefficient and routine choices only, and that illness, departure/separation, the
packed schema and allocator bounds, command/wire formats, family admission templates and
stage-qualified geometry remain unauthored. This review treats every one of those as **open**
and does not read the draft's own closure list as a completion claim. Within the material the
draft *does* select, the findings below are the gaps that must close before the coefficient
and routine layer can be called reviewed.

**Provenance.** Every number discussed here is an **Astra proposal made under delegated
engineering authority**. Nothing in this review treats any coefficient, threshold, capacity or
schedule slot as user-supplied or inherited. DEC-032/033 supply scope and policy, not values;
the draft says so and this review holds it to that.

---

## 0. Source knowledge limitations (read before relying on any finding)

1. The only evidence available to this review is the supplied excerpt set
   (`source-excerpts.json`, sha256 `76f1097a…827432`) plus the draft itself. No repository
   file was opened, listed or executed.
2. **The prior audit's method of quoting stale in-module GAPS comments as proof of current
   absence is explicitly not repeated here.** Those comment blocks describe the state of a
   module at the time the comment was written, not the state of the repository today. In
   particular, this review makes **no claim** that building, furniture, room, priority or
   schedule stores are absent, and **no claim** that `residents.gd` lacks `set_home`/`set_bed`.
   It is reported that such surfaces exist; they are simply outside the excerpt set, so this
   review cannot describe their APIs, capacities or refusal codes.
3. Consequently every finding below that touches beds, rooms, schedules or priorities is
   phrased as *"the draft does not state X"*, never as *"the engine cannot do X"*. Where a
   repair requires an existing owner's API shape, the repair names the obligation to cite that
   owner rather than guessing it.
4. Arithmetic findings are self-contained and do not depend on (2) or (3).

---

## 1. What checks out

These are verified by reproduction from the draft's own stated formulas and the excerpted GDD
§5.2 baselines. They are recorded so later revisions do not re-litigate them.

| Check | Result |
|---|---|
| Hunger stage formula shape `floor(250000 × size × season × stage / 1e9)` | Dimensionally consistent: 250000 is already milli-need-points/hour, the three multipliers each carry a 1000 denominator, so `1000^3 = 1e9` is the correct single divisor. Matches GDD §5.2's "compound multipliers applied in int64 before division". |
| Child SMALL, non-winter | 250000×1000×1000×750 = 1.875e14 / 1e9 = **187500** ✓ as drafted |
| Child MEDIUM / LARGE, non-winter | 225000 / 300000 ✓ |
| Child SMALL / MEDIUM / LARGE, winter | 225000 / 270000 / 360000 ✓ |
| Overflow headroom | Largest product 250000×1600×1200×1000 = 4.8e14, inside i64 by a wide margin ✓ |
| Largest resulting hunger rate | 360000 milli/hour, inside the excerpted `MAX_RATE_MAGNITUDE` of 1 200 000 ✓ |
| Child mood divisor | Weights 3+2+2+1+2+2 = **12** ✓ matches the stated divisor; adult 3+2+2+1+2 = 10 ✓ unchanged |
| Remainder cleanliness | 187500 per hour against denominator 750000 releases exactly one point every 4 ticks; no drift ✓ |
| Elder row equality | Every elder cell equals the adult cell **as an authored equality**, with an explicit statement that this is not an adult fallback ✓ consistent with MOVE-C3-R01 §3 and DEC-032's no-universal-penalty rule |
| Child caregiver exclusion | Willingness defaults `false` for CHILD and providers must be ADULT/ELDER ✓ no path makes a child a care worker |
| No invented neglect death | Explicitly refused; existing food/exposure/illness/injury/failed-rescue routes retained ✓ DEC-033 compliant |
| No gender field | Explicitly stated ✓ |
| Surname/kinship separation | Explicitly stated ✓ |

---

## 2. Findings and bounded repairs

Severity: **BLOCKER** = the selected rule is arithmetically or deterministically unusable as
written; **MAJOR** = a real behavioural gap that will produce divergent implementations;
**MINOR** = under-specification that a one-sentence amendment closes.

---

### F-01 — BLOCKER. The care completion bound is unreachable inside one bounded session

**Draft text.** Eligibility begins at `care<=6000`; a service "runs until the first of
care>=9000, … or 750 ticks of actual paired service"; service adds 3000/hour "while ordinary
decay continues, net +2750/hour".

**Arithmetic.** 750 ticks is exactly one game hour. Net gain over a full session is therefore
**+2750**. From the *highest possible* eligible starting value, 6000, one session terminates at
**8750**, which is below 9000. The `care>=9000` stop condition is therefore **unreachable from
any eligible start**, and every child remains eligibility-latched after every maximal session.

**Consequences.** (a) The stated stop condition is dead code in every ordinary case, which is
exactly the class of unreachable branch a fixture set will not exercise. (b) The turn-taking
bound and the completion bound can never tie, so the draft never has to say which stop reason
wins — but only by accident. (c) Daily equilibrium: decay is 250/hour × 24 = **6000/day**; net
service gain is 2750/hour, so a child needs 6000/2750 = **2.1818 hours = 1636.36 ticks** of
service per day. That is not an integer and not a whole number of sessions, so the fair-share
and forecast layers inherit a fractional target.

**Bounded repairs — pick exactly one.**

- **Repair A (change the bound).** Raise the session limit to **900 ticks**. A session from
  6000 then reaches 9000 after 818.18 ticks (first tick at which care>=9000 is tick 819 given
  the retained-remainder integrator), inside the bound, so completion is reachable and
  turn-taking still caps a session at 1.2 hours. Requires stating the tie rule for the case
  where completion and the tick bound coincide.
- **Repair B (change the rate) — recommended.** Set service restoration to **3250/hour**, so
  net gain is exactly **+3000/hour**. Then:
  - one 750-tick session from the eligibility threshold 6000 lands on exactly 9000, so the
    completion stop and the turn-taking stop coincide by construction — the draft must then
    state that the recorded stop reason is **completion**, not exhaustion;
  - daily equilibrium becomes 6000/3000 = **exactly 2 hours = 1500 ticks = 2 full sessions per
    child per day**, which makes the fairness counters, the forecast in F-14 and the fixture
    set integer-exact.

Either repair must be restated in the coefficient table, not only in prose.

---

### F-02 — BLOCKER. The care accumulator's unit, denominator and overflow bound are unstated, and the drafted rate exceeds the existing proved bound

**Draft text.** "There is one accumulator for care, owned by the dependent store. Reaching
either bound discards outward overflow and remainder exactly as Needs does."

**Gap.** "Exactly as Needs does" imports the denominator `750 ticks × 1000 milli = 750000` and
the signed truncated-remainder rule, but the draft never states that care values are carried in
milli-care-points. If they are, the service rate is **3 000 000 milli/hour** (or 3 250 000 under
repair B), which is **outside the excerpted `MAX_RATE_MAGNITUDE = 1 200 000`** that `needs.gd`
proves at construction and enforces by refusal. Care therefore cannot be integrated by the
existing integrator without invalidating that proof, and the draft does not say it has its own.

**Bounded repair.** The dependent store must state, as table rows, all five of:
1. care is stored 0..10000 in whole points with a signed int64 milli-point remainder;
2. denominator = 750000, identical to Needs;
3. the rate set actually reachable: `-250000` (decay), `+2750000` or `+3000000` (net service),
   and nothing else;
4. its **own** maximum-rate-magnitude constant and the one-line overflow proof for it, stated
   independently of `needs.gd`'s constant, exactly as the draft already requires a single health
   integrator — one care integrator, its own proved bound, no reuse of a bound proved for a
   different rate set;
5. an explicit statement that care is **never** routed through the Needs integrator, so
   `NEED_COUNT` stays 5 and the five fixed `NeedRemainders` accumulators are untouched.

---

### F-03 — MAJOR. Ordinary-care urgency is stated against only one of the four competing buckets

**Draft text.** "Critical care uses urgency1; ordinary care uses urgency3, behind any ready
priority0 rescue."

**Gap.** Saying urgency 3 is behind urgency 0 is tautological. The clause omits the two buckets
that actually matter: **urgency 1 personal critical needs** and **urgency 2 food/fuel while
projected reserve < 2 days**. It also leaves REQ-SET-014's "available food shall remain the
highest nonrescue job priority" unreconciled, which is the precise conflict the previous audit
flagged and this draft does not resolve in words.

**Bounded repair.** Replace with an explicit four-line ordering statement:

> Ordinary daily care is urgency 3. It is behind urgency 0 rescue and feeding an incapacitated
> resident, behind urgency 1 personal critical needs, and behind urgency 2 food/fuel jobs while
> the projected reserve is under two days. REQ-SET-014's "highest nonrescue" clause is
> unchanged: an available-food job outranks ordinary care in every case.

And state the **within-bucket** position: urgency 3 is shared with ordinary production and
construction, and the existing intra-bucket sort key
`(player_priority, job_priority, −skill_level, estimated_path_cells, created_tick, job_id)` has
no term that expresses "care before construction". The draft's own sentence "Safe productive
work may finish its existing at-most 30 WU segment before ordinary care begins" implies care
*displaces* queued ordinary work, which equal-bucket membership does not deliver. Choose one:
(i) give ordinary care a fixed `job_priority` value that sorts ahead of production inside bucket
3, stating the exact value; or (ii) state that care does **not** displace queued ordinary work
and is selected only when a provider is otherwise idle at a selection boundary. Option (ii) is
cheaper but must then be reconciled with the eligibility/critical thresholds, because it makes
care coverage dependent on settlement workload.

---

### F-04 — MAJOR (with a clean available resolution). Critical care at urgency 1 has no tiebreak against the provider's own critical needs — but the provider gate almost closes it

**Observation.** Urgency 1 is "personal critical needs". Placing critical care in the same
bucket creates a contention the intra-bucket sort key cannot express: a provider's own critical
need versus another resident's critical child.

**However**, the draft's own provider gate is `hunger>1500`, `rest>500`, plus living, conscious
and not in danger. Those thresholds are **exactly** the GDD's urgent-hunger and
collapse-rest thresholds. A provider in urgency-1 hunger or rest crisis is therefore already
**ineligible** to provide care, so the contention is vacuous for the two numeric criticals.

**Residual gap.** It is *not* vacuous for (a) provider health, which the draft gates only
indirectly via "living conscious", and (b) any other urgency-1 personal critical condition the
job owner recognises (e.g. cold/exposure response).

**Bounded repair.** State the coincidence explicitly so it is a designed invariant rather than
an accident, and close the residue:

> The provider gate thresholds are deliberately identical to the urgency-1 personal-critical
> thresholds, so no provider can simultaneously owe an urgency-1 personal job and be eligible to
> provide care. Provider health must additionally be `>=16` (conscious per the existing
> health/status precedence), stated as a numeric gate rather than inferred from "conscious". Any
> other urgency-1 condition recognised by the job owner also disqualifies a provider for the
> duration of that condition.

With that sentence, critical care may remain in urgency 1 with no new bucket.

---

### F-05 — MAJOR. Willingness filters the critical path too, and the draft does not say so

**Draft text.** Selection draws "from declared willing caregivers, then willing adult/elder
members of the household, then willing community providers"; and "Turning it off ends ordinary
service at the next safe boundary".

**Gap.** Every tier is willingness-filtered, with no exception stated for **critical** care. As
written, a settlement in which every provider has toggled willingness off leaves a critical
child with a warning and no service, indefinitely. The draft also says turning willingness off
ends *ordinary* service, which hints that critical service is different, but never states it.

**Bounded repair.** Choose and state one, explicitly, in one sentence:

- **(i) No override (recommended, consistent with the draft's refusal to compel).** Willingness
  filters all tiers including critical. Then the draft must additionally require a **distinct,
  higher-severity notice** for "critical care unmet: no willing provider", separate from the
  "no qualified provider or route" notice, so the player sees that the cause is a player toggle
  and not a routing failure; and the UI must surface the toggle from that notice.
- **(ii) Critical override.** Willingness is ignored for critical care only. Then the draft must
  state that this is a compelled assignment, that it ends the moment the critical latch clears,
  and that it never extends to medical HEAL or rescue policy.

Silence is not acceptable here because the two options produce opposite survival outcomes under
the same player input.

---

### F-06 — MAJOR. The selection pass and the 30-tick staggered reselection are two different determinism models

**Draft text.** "Reselect on the next normal 30-tick staggered selection boundary." and
"Selection first orders children by (critical before ordinary, care ascending, persistent_id
ascending). A provider is chosen from … tiers …"

**Gap.** The existing staggered model reevaluates idle residents "every 30 ticks, staggered by
resident ID mod 30", i.e. **per-resident, spread across 30 ticks**. The care rule describes a
**global pass** that sorts all eligible children and then walks provider tiers with a
"no provider selected twice in the same pass" rule. A global pass and a per-resident stagger
cannot both be the selection model: under the stagger there is no single pass in which
"selected twice" is even well defined.

**Bounded repair — pick one and state it as a phase ordinal.**

- **(A) Global care pass (recommended, matches the drafted fairness rule).** Care selection runs
  once per 30 ticks at ticks where `tick mod 30 == 0`, as a named simulation phase that executes
  **before** individual job selection in the same tick. Within the pass, the drafted child sort
  and provider tiers apply, and "same pass" is exactly that one execution. Providers already
  engaged in an active service are **not candidates** in the pass (state this; it is currently
  only implied by "not committed to another service").
- **(B) Per-provider stagger.** Each provider, at its own `id mod 30` boundary, claims the
  highest-ranked unserved eligible child. Then the "no provider twice in a pass" rule is deleted
  and replaced by an atomic claim on the child, and fairness ordering degrades to arrival order
  within the 30-tick window — which weakens the fair-share intent and should be rejected unless
  the job owner requires it.

Whichever is chosen, the draft must name the phase's position relative to need integration, the
midnight reset (F-07) and job selection, because all three mutate the inputs the others read.

---

### F-07 — MAJOR. Midnight fairness reset: attribution, in-flight services and phase order are unstated

**Draft text.** "Daily totals reset at midnight before new service selection; days and partial
service survive save/load."

**Gaps.**
1. **Attribution.** A service spanning midnight has ticks on both sides. The draft does not say
   whether those ticks are credited to the day in which each tick occurred or to the day the
   service started. Only the former is reconstructible after a reload.
2. **In-flight cancellation.** The draft does not say whether the reset cancels or preserves an
   active service. "Partial service survives save/load" is about persistence, not about the day
   boundary.
3. **Session counter vs daily counter.** There are two counters — the 750-tick session bound and
   the per-day fair-share total — and the draft never says the reset touches only the second.
4. **Phase order.** Midnight already carries affinity decay toward zero for pairs without
   contact for 3 days, departure-counter evaluation, reputation recomputation and the lifecycle
   commit. The care reset's ordinal among these is unstated, and the draft's own M4/mean-mood
   interaction (F-18) makes the ordering observable.

**Bounded repair.** State four sentences:

> Each tick of actual paired service is credited to the day in which that tick occurs. The
> midnight reset zeroes only the per-provider daily paired-care tick totals; it never cancels an
> active service and never resets the 750-tick session counter, which belongs to the service
> instance. The reset executes at a named ordinal within the midnight phase, after the lifecycle
> commit and before the day's first care-selection pass. Both counters, the day index, the
> active provider/patient generation refs, the eligibility latch and both warning latches are
> captured and restored.

---

### F-08 — MAJOR. "No eligible provider or route" has no notice identity, dedup key or clearing rule

**Draft text.** "If there is no qualified provider or route, retain the child's need and a
specific warning".

**Gap.** The existing notice model deduplicates on an active key of `(code, source)` and bounds
active condition keys and affected IDs. The draft names neither the code nor the source, so two
implementations will legitimately choose `source = child` (one notice per child, correct for
rescue actions, noisy at scale) versus `source = household` (aggregated, but wrong when a
child's provider set is community-wide and not household-bounded).

**Bounded repair.** State, as a small table: distinct codes for (a) no willing provider, (b) no
**qualified** provider (willing but gated out by hunger/rest/health/danger/commitment), (c) no
legal reachable contact/route, (d) critical unmet — with `source = the child's persistent
resident row` in every case, the exact clearing condition for each (service started, or the
blocking cause resolved), and the severity mapping. Distinguishing (a), (b) and (c) is required
by the draft's own UI clause "unavailable-provider/route cause".

---

### F-09 — MAJOR. Sleep override: neither direction of the sleep/care interaction is stated

**Draft text.** Care "decays during sleep as well as waking"; the child template is 20:00–06:00
SLEEP; "Sleep exits at rest>=9000 into ANYTHING; emergencies interrupt using existing priority
order."

**Gaps.**
1. **May ordinary care interrupt scheduled sleep?** Unstated. Care decays for ten unserved hours
   overnight (2500 points under the drafted decay), so the question is load-bearing, not
   cosmetic.
2. **May critical care interrupt sleep?** Unstated. "Emergencies interrupt using existing
   priority order" is about the child's own emergencies, not about a third party initiating a
   service on a sleeping child.
3. **May a service continue into a sleep window?** Unstated.
4. **Post-wake ANYTHING inside the sleep window.** A child that reaches rest 9000 exits to
   ANYTHING at, say, 23:20 and then has hours of unscheduled night activity. The draft says
   nothing about what a child may do there. Because MOVE-C3-R01's child prohibitions are
   entry-based and not time-based, nothing in the drafted text prevents a child's night ANYTHING
   from routing anywhere ordinarily permitted.

**Bounded repair.** Four sentences, all inside the routine section:

> Ordinary care never initiates during a child's scheduled SLEEP window and never wakes a child;
> an ordinary service already in progress ends at the safe boundary when the window begins.
> Critical care may initiate during the sleep window and the child is woken; that interruption is
> recorded as a sleep interruption and no rest is refunded. A child that exits sleep on rest>=9000
> inside its scheduled SLEEP window remains in a quiet ANYTHING confined to its assigned bed's
> room or the household's interior, initiates no travel outside it, and initiates no hazardous
> entry; it re-enters sleep normally when rest falls to the seek-sleep threshold. Elder and adult
> sleep behaviour is unchanged.

The confinement clause is the one that keeps the night ANYTHING from silently becoming an
unsupervised-child routing problem that the movement package would then inherit.

---

### F-10 — BLOCKER. Learning does not close the inherited mentoring path, which awards skill XP

**Draft text.** "Learning and play are nonproductive personal activities. They consume no recipe
inputs, create no output/inventory, award no production XP and never satisfy a productive-work
counter." and "learning restores purpose 400/hour".

**Gap.** The inherited rule set already contains a **mentoring** path: a SOCIAL alternative
selected when an available friend has a skill at least three levels higher, granting the learner
**100 XP in that skill**, once per pair per day, with purpose restoration of **400/hour** — the
exact number the draft assigns to child learning. Two problems follow:

1. A child has all skills at level 0 and seeds none, so **every** adult with any skill at level 3
   or above trivially satisfies the mentoring predicate. Nothing in the draft prevents a child
   from being selected as the mentoring **learner** during its SOCIAL block, which would award a
   child 100 XP in a production skill — directly contrary to "Children receive no productive tool
   or seeded productive skill XP" and to the standing policy that a helping activity must not
   secretly create production XP.
2. Reusing 400/hour for learning invites an implementer to conclude learning **is** mentoring,
   which would make the XP award part of learning by construction.

**Bounded repair.** Two explicit sentences:

> LEARNING is a distinct activity and is not the inherited mentoring alternative; its 400/hour
> purpose restoration is an authored equality with the mentoring rate, not a binding to it, and
> LEARNING awards no XP in any skill column. A CHILD is ineligible as either the mentor or the
> learner in the inherited mentoring rule; the mentoring predicate excludes CHILD on both sides.

If Astra intends children to gain *some* XP, that is a separate authored decision with its own
skill column, value and justification — it cannot arrive through an unclosed inherited path.

---

### F-11 — MAJOR. Ordinary daily care versus the inherited +8 medical/rescue affinity award

**Draft text.** "Daily care is a nonproductive paired personal service, separate from medical
HEAL and rescue HAUL jobs." Nothing is said about affinity.

**Gap.** The inherited relationship rules award **+8 affinity** when "one completes rescue/care
for the other", at most once per event, and **+2** for 60 WU of completed social activity,
capped once per pair per day. Daily care is paired and is literally called *care*. As written,
an implementer may reasonably apply either award, both, or neither. The difference is material:
at two sessions per child per day, a +8-per-service reading reaches the friendship threshold of
40 within days and then saturates the child's degree-8 relationship budget with caregiver edges
— which the draft elsewhere is at pains to prevent ("Household membership and caregiver
relationships … never consume a degree-8 Relationship link").

**Bounded repair.** State all three cases explicitly:

> The inherited +8 rescue/care affinity award applies to **medical HEAL treatment completion and
> completed rescue only**. Ordinary daily care is not that event and does not award +8. A
> completed ordinary care service of at least 60 WU-equivalent of paired time awards the ordinary
> paired-social +2, capped at one such gain per pair per day, identical to any other paired social
> activity, and creates a Relationship edge only under the existing degree-8 rules — the care
> assignment itself remains outside that budget and is never evicted with it.

Also state the **conflict-roll** interaction, which is currently silent: the inherited 18:00
daily pair conflict roll fires for two residents sharing a social room with mood<2500 and
affinity<0. The child SOCIAL block is 18:00–20:00, so children are in scope by default. Add:

> CHILD residents are excluded from the daily pair conflict roll on both sides; the roll
> considers ADULT and ELDER pairs only.

This is a policy-compliance point as much as a mechanics one: a child-involving conflict event
with affinity loss and a conflict memory is not something the draft should acquire by silence.

---

### F-12 — MAJOR. Warning, critical and eligibility latches: precedence, implication and read-source are unstated

**Draft text.** "A child becomes eligible for ordinary care at care<=6000 and remains eligible
until care>=9000. Warning at<=3500, critical at<=1500; clear the corresponding warning only
above 4000/2000 respectively."

**What is correct.** Three independent hysteresis bands, each with a set threshold and a strictly
higher clear threshold. At care 3800 neither the warning set nor the warning clear condition
holds, so the latch retains — that is the intended and correct behaviour of a latch, and the
draft's wording supports it.

**Gaps.**
1. **Implication.** Is a critical child also a warned child? The bands overlap (critical set 1500
   is inside the warning band), but the latches are described as independent, so a child that
   falls below 1500 without passing through a tick in the 1501–3500 range would, on a literal
   reading, carry critical without warning. State: **critical implies warning**; setting critical
   sets the warning latch, and the warning latch cannot clear while critical is set.
2. **Read source for selection.** The selection ordering says "critical before ordinary". It does
   not say whether that reads the **latch** or the **raw value**. These differ in the hysteresis
   band: a child at care 1800 has the critical latch set (not yet cleared, needs >2000) but a raw
   value above the critical threshold. Reading raw values makes ordering flap across a single
   tick mid-service. **State that selection, ordering and urgency assignment read the latches.**
3. **Evaluation point.** State that all three latches are evaluated once per tick on the
   post-integration care value, in the CareHealth step the draft already names, and never
   mid-service on a partially applied value.
4. **Multi-band crossing.** A single service step can cross from 1400 to 5000. State the
   evaluation order (critical clear, then warning clear, then eligibility) and confirm both
   clears occur in that one step.
5. **Eligibility latch and the unreachable ceiling.** Under F-01 as drafted, the eligibility latch
   effectively never clears. Repair B closes this; if Repair A is chosen instead, state what the
   eligibility latch means for a child parked between 8750 and 9000.
6. **Notice severity mapping.** The draft requires text/icon severity as well as colour but never
   maps warning/critical onto the existing severity domain. State the mapping.

---

### F-13 — MAJOR. Medical care and ordinary care do not compose: the child's care need keeps decaying with no serviceable path

**Draft text.** "Provider hunger>1500, rest>500 and **child health>15** are required; incapacity
uses medical care."

**Gap.** An incapacitated child (health 1..15) is excluded from ordinary care by its own health
gate. Its care value continues to decay at 250/hour regardless, reaching critical inside roughly
a day, and the "no qualified provider" warning fires with a cause that is misleading: the cause
is not an absent provider, it is that the child is in medical care. The draft does not say
whether medical HEAL grants any care restoration, nor whether the care clock is suppressed.

**Bounded repair — pick one and state it.**

- **(i) Suppress the warning, keep the decay (recommended).** While a child is INCAPACITATED or
  is an active rescue patient, ordinary care is not selectable, care continues to decay, the
  no-provider notices are suppressed and replaced by a distinct "care deferred: under medical
  care" cause shown in the UI, and ordinary eligibility resumes at the tick the child's health
  reaches 16.
- **(ii) Grant care during treatment.** Completion of a medical HEAL on a child additionally adds
  an explicitly authored one-shot care amount. This requires a number and must state that it is
  not the +3000/hour service rate and does not stack with a concurrent ordinary service.

Option (i) requires no new coefficient and is the smaller change. Either way the draft must also
state that **ordinary care and medical HEAL are mutually exclusive on the same child at the same
time**, which the one-provider/one-child rule implies but never says.

---

### F-14 — BLOCKER. Forecast daily demand conflates need-point decay with nutrition points

**Draft text.** "Forecast child intake with the exact above coefficient" and the preflight
requirement for a "resulting four-day ready-food reserve".

**Gap.** The "above coefficient" is the **hunger need** decay in milli-need-points per hour. The
ready-food reserve, the food-days figure and the admission rejection at fewer than four food-days
are computed in **nutrition points (NP)** from a separate baseline — the excerpted GDD states a
small resident requires 6000 NP/day at baseline, and the daily-demand denominator scales that
baseline by size and season. Need-point decay and NP demand are two different quantities on two
different scales. Instructing the UI to forecast intake "with the exact above coefficient"
produces a number in the wrong unit, and the draft supplies **no** child NP rule at all.

This is the single largest omission in the selected material: every mixed-stage household
admission decision, the four-day reserve preflight, the food-days display and the M4 food-days
condition all run through the NP denominator, and none of them has a child value.

**Bounded repair.** Author the NP rule explicitly and symmetrically with the hunger rule:

> Daily nutrition demand is `floor(6000 × size_multiplier × season_multiplier × stage_multiplier
> / 1e9)` NP, with the same size (1000/1200/1600), season (winter 1200, otherwise 1000) and stage
> (ADULT 1000 / CHILD 750 / ELDER 1000) multipliers, evaluated as checked i64 products before a
> single division.

Worked values, which must appear as a table so fixtures can assert them:

| | SMALL | MEDIUM | LARGE |
|---|---:|---:|---:|
| Child, non-winter | 4500 | 5400 | 7200 |
| Child, winter | 5400 | 6480 | 8640 |
| Adult/Elder, non-winter | 6000 | 7200 | 9600 |
| Adult/Elder, winter | 7200 | 8640 | 11520 |

The draft must additionally state **two** aggregation rules that are currently silent and that
change the result:

1. Whether the per-resident value is floored **per resident and then summed** (the natural reading
   of a per-resident demand column) or summed in milli-units and floored once. These differ.
   Specify per-resident floor, then sum, and say so.
2. That the forecast is a **rate**, whereas actual consumption is in whole prepared portions with
   clamped, non-refunded nutrition. The four-day preflight must therefore state whether it uses
   the rate (simpler, slightly optimistic for children because clamped excess is discarded) or
   whole-portion granularity. The draft already forbids manufacturing partial servings or
   refunding clamped nutrition; it must now say that the reserve check knowingly uses the rate and
   that the discarded excess is not credited.

---

### F-15 — MAJOR. Forecast of care demand and coverage is required by the UI section but never defined

**Draft text.** The interface section requires "care value/trend" and "unavailable-provider/route
cause", and the routine section defines fair-share totals, but no demand or coverage figure is
specified.

**Bounded repair.** Under Repair B of F-01 the arithmetic is exact and should be stated:

> Required daily service is 1500 ticks per eligible child (6000 points of daily decay at a net
> +3000/hour). Settlement daily care demand is `1500 × living_child_count` ticks. Coverage is the
> ratio of that demand to the sum, over willing and qualified providers, of ticks available inside
> their schedules after the urgency 0–2 obligations named in F-03 — displayed as an explicit
> shortfall in ticks, not a colour.

Under Repair A the same figure is 1636.36 ticks/child/day, which is the reason Repair B is
recommended: the forecast becomes integer-exact.

---

### F-16 — MAJOR. Stage-row selection: the refusal is stated as policy but has no named owner, code or evaluation point

**Draft text.** "Explicit stage rows select coefficients; an absent row refuses before
spawn/publication."

**Gap.** Stage-domain validation (a stage outside 0..2 refused, never clamped to adult) is an
existing, verifiable behaviour. **Coefficient-row presence** is a different check and the draft
names neither its owner nor its refusal code nor the exact moment it runs. "Before
spawn/publication" is two different moments.

**Bounded repair.** State: which owner holds the `[stage]`-indexed coefficient table; that the
table is indexed 0..2 with the stage count used only as a bound and never stored; a named refusal
code for an absent or incomplete stage row; and the two evaluation points — (a) at store
construction, refusing to publish an incomplete table at all, and (b) at spawn, refusing a stage
whose row is absent. Constructing with an incomplete table and only catching it at spawn leaves a
world that can be loaded and then cannot spawn, which is the worse failure mode.

---

### F-17 — MINOR. Adult and elder care rows: "not applicable" versus canonical zero

**Draft text.** The table gives ADULT and ELDER "not applicable" for daily-care decay, while the
prose says other stages "store canonical zero with zero remainder".

**Gap.** Two different statements for the same cells. The distinction matters because a zero-rate
integer column is integrated (and provably contributes nothing) whereas "not applicable" suggests
the column is not read at all.

**Bounded repair.** One sentence: "ADULT and ELDER care values and remainders are canonically zero
and are never integrated; the care eligibility predicate requires `stage == CHILD`, so no elder or
adult can acquire a care dependency, a care warning or a care-derived mood term." This also
forecloses the reading in which elders drift into a dependency model — which would be a de facto
age penalty and is exactly what MOVE-C3-R01 §3 and DEC-032 forbid.

---

### F-18 — MAJOR. Children in mean mood change reputation and the M4 gate; the consequence is implied but not stated

**Draft text.** "count every person for beds, population and total mood." Child mood uses the
divisor-12 formula including care at weight 2.

**Consequence the draft does not name.** Mean mood feeds daily reputation (`floor(mean_mood/2)`
plus other terms), and reputation feeds the immigration candidate count. Mean mood is also an M4
Hearth Charter condition at `>=6500` maintained across the defined interval. Because a child's
mood carries a care term that can reach zero, an under-served child depresses mean mood, which
depresses reputation, which reduces future candidate counts — a coupling that is defensible but
must be deliberate.

**Bounded repair.** State it as an accepted consequence in one sentence, and state the ordering
dependency: the midnight reputation recomputation reads mood **after** the day's final care
integration and latch evaluation. Also state whether child mood participates in the M4 mean-mood
condition (it must, under "count every person"), because the Charter condition is checked at a
specific tick and a silent inclusion or exclusion changes when the game can be won.

---

### F-19 — MINOR. "While safely active" is undefined for play and learning

**Draft text.** "While safely active, play restores purpose 320/hour; learning restores purpose
400/hour."

**Gap.** "Safely active" is not defined. The draft elsewhere is precise that travel earns neither
care nor social/purpose restoration; the same clarity is owed here.

**Bounded repair.** "Safely active means the child is at a legal location for the activity, not
travelling, not in danger, not incapacitated and not interrupted; travel ticks and interrupted
ticks restore nothing. Neither play nor learning requires a building, furniture, station, tool or
unlock, so both are available from the starting settlement; no later building grants either a
bonus rate unless a future amendment authors one." The last clause matters because an unlockable
nursery-type building exists in the progression tables and an implementer may assume a binding.

**Purpose budget check (favourable).** Child purpose decay is 75/hour = 1800/day. The template
provides 4 hours of learning (1600) and 4 hours of play (1280) = **2880/day**, comfortably above
decay, so the previously flagged "child purpose starves because purpose only comes from labour"
conflict **is** resolved by this draft. That resolution should be stated as such so it is not
reopened.

---

### F-20 — MINOR. The 750-tick session counter needs explicit inclusion and exclusion rules

**Bounded repair.** State: the counter advances only on ticks of actual paired service, not on
travel, setup, waiting or interruption; it is per service instance and resets when a new service
instance begins; an interruption ends the instance rather than pausing it, so a resumed service is
a new instance with a fresh 750 (or 900) bound; and the daily fair-share total accumulates across
instances. Without the last two sentences, "turn-taking bound, not a completion bonus" can be
defeated by deliberate interrupt/resume cycling.

---

### F-21 — MINOR. Fairness tiering can starve the fair-share intent, and that trade-off should be stated

**Observation.** Tiers are strict: named caregivers, then household adults/elders, then community.
Fair-share ordering applies only **within** a tier. A named caregiver who has already served 1400
ticks today is therefore still selected ahead of a household adult with zero ticks. That is a
defensible authored choice — named preference should mean something — but it partially negates the
"care shared among available adults" intent at the settlement level.

**Bounded repair.** No mechanical change required; state the trade-off explicitly so it is a
decision rather than an artefact, and confirm the "blocked named caregiver does not prevent
fallback" rule covers the case where the named caregiver is merely *busy* (not blocked), since
that is the common case. If Astra wants true shared load, the minimal change is to make the daily
tick total the **first** sort key across all tiers with the tier as the tiebreak — one sentence,
still fully deterministic.

---

### F-22 — MINOR. Child bed validity depends on unpublished stage geometry, so family-enabled admission is externally blocked

**Draft text.** "An ordinary bed is valid for a child only if its actual furniture use/contact and
the child's qualified profile admit it."

**Observation.** This is the correct rule and correctly refuses a generic adult fit, doubled
occupancy or a free cot. But the qualified child profile it depends on is, by the draft's own
authority section, owned by the stage-qualified movement profile package and not yet authored.

**Bounded repair.** State the consequence plainly rather than leaving it to inference: "Until
stage-qualified child bed contact and geometry are published by the movement profile producer, no
child can hold a valid bed, and therefore family-enabled admission and child-bearing scenario
households refuse. This is a declared external prerequisite, not a defect of this amendment." The
draft lists the producer as remaining work item 5; the blocking relationship should be explicit in
the admission section where an implementer will look.

*(Per §0, this review makes no claim about whether bed, furniture or room stores currently exist —
only that the **stage-qualified child contact rule** the draft depends on is, by the draft's own
text, unauthored.)*

---

### F-23 — MINOR. Household row capacity and the caps are consistent, but reuse safety needs one more sentence

**Observation.** 256 household rows with up to 8 living members each, against a 256 living cap and
512 resident rows, is internally consistent — the living cap binds first, and the degenerate case
of 256 one-member households is representable. Good.

**Bounded repair.** The storage section names "a reusable row generation" and "monotonic household
ID". State the invariant they exist to enforce: a reclaimed household row must bump its generation
so that any retained `(slot, generation)` household reference from before reclamation refuses
rather than resolving to the new tenant — the same discipline the resident directory already
applies. Add that a child's preferred-caregiver entries and any active provider/patient refs are
validated by generation on every read, and that a stale ref is a refusal, never a silent fallback
to "no preference" (which would silently widen a child's caregiver set).

---

## 3. Deterministic corner cases the amendment must answer explicitly

Each row is a concrete scenario whose outcome is currently ambiguous. The fixture list should name
one case per row.

| # | Corner case | Currently ambiguous because |
|---|---|---|
| C-01 | Two children tie on care value | Resolved: persistent_id ascending. ✓ Keep as a fixture. |
| C-02 | Two providers tie on daily ticks within a tier | Resolved: provider persistent_id ascending. ✓ Keep. |
| C-03 | A provider is the named caregiver of two children who are both critical | No rule for which child wins beyond the global child sort; confirm the child sort is authoritative and the provider serves the first, leaving the second to the next tier. |
| C-04 | Service in progress when midnight falls | F-07 |
| C-05 | Service in progress when a save is taken and reloaded mid-session | Persistence list must include the session tick counter, both latches, the eligibility latch and both generation refs (F-07) |
| C-06 | Care reaches exactly 9000 on the exact tick the session bound expires | Stop-reason tie (F-01 Repair B makes this the *normal* case) |
| C-07 | Care crosses 1400 → 5000 in one integration step | Multi-band latch clear order (F-12.4) |
| C-08 | Care sits at 3800 | Latch retained by hysteresis ✓ — assert it, since a naive implementation clears here |
| C-09 | Provider's hunger crosses 1500 downward mid-service | Interruption is implied by the gate but the boundary (immediate vs next safe boundary) is unstated |
| C-10 | Child health falls to 15 mid-service | F-13; service must end and the cause must change, not simply drop |
| C-11 | Every willing provider toggles willingness off while a child is critical | F-05 |
| C-12 | A child is critical and the only qualified provider is carrying a rescue patient | Draft gates this out correctly; assert the resulting notice code is the "qualified but unavailable" variant, not "no provider" (F-08) |
| C-13 | Named caregiver dies mid-service | Contact invalidation ends the service; assert partial restoration persists and the next pass falls through to the household tier |
| C-14 | A child's only two named caregivers are both outside the household and both depart | Preferences must clear to empty and community fallback must engage without a gap; also F-23 stale-ref handling |
| C-15 | Household of 8 admitted when exactly 8 beds and exactly 4.0 food-days remain | Whole-unit atomicity plus the F-14 rounding rule determine accept/refuse; the boundary must be asserted, and the draft's "four-day reserve" must say whether exactly 4 passes |
| C-16 | Admission unit contains a child with no valid stage-qualified bed contact | F-22; must refuse the whole unit with no partial mutation |
| C-17 | Child exits sleep at 23:20 on rest 9000 | F-09.4 |
| C-18 | Critical care initiates at 02:00 | F-09.2 |
| C-19 | Child and adult both enter a SOCIAL room at 18:00 with mood<2500 and affinity<0 | F-11 conflict-roll exclusion |
| C-20 | Child completes a 60-WU-equivalent care service with an adult for the second time in one day | F-11 affinity cap |
| C-21 | Provider is willing, qualified and reachable but the child is asleep and only ordinary-eligible | F-09.1 — must produce *no* notice, not a false "unavailable provider" |
| C-22 | Stage row for CHILD is absent from the coefficient table at load | F-16 — refuse at construction, not at spawn |
| C-23 | Mixed-stage world runs an arbitrary number of years | Fixed-stage / no-aging invariant: no stage byte ever changes, no birth, no adulthood transition. ✓ Already required by the draft; keep. |

---

## 4. Policy compliance

| Policy | Assessment |
|---|---|
| No fabricated user-inherited values | **Compliant.** The draft's opening paragraph is explicit that these are proposed engineering values under delegated scope and not numbers supplied by the user. Retain that paragraph verbatim through revisions. |
| No child hazardous work, expeditions or excavation | **Compliant.** Children receive no productive tool, no seeded production XP, no work schedule block and no productive-work counter satisfaction. |
| Helping animation must not secretly produce inventory or XP | **Compliant in the UI section** ("labelled nonproductive and cannot call work or inventory commits"), but see **F-10**: the *mentoring* path is an unclosed route to production XP that the animation clause does not cover. |
| No universal elder penalty | **Compliant.** Every elder coefficient equals adult **as an authored equality**, no age-only work, movement, danger or skill penalty, and no forced teacher/caregiver role. F-17 closes the one residual reading. |
| No birth, aging, adulthood transition, age death | **Compliant.** Fixed stage per scenario, explicitly stated, and learning is explicitly said not to promise an adulthood transition. |
| DEC-033 consequences without invented mortality | **Compliant.** Zero care changes mood and warnings, not health; no neglect-death roll; existing causal survival routes retained; no graphic presentation; blocked rescue remains a shown cause. |
| Population accounting, all stages | **Compliant.** All living residents count to 256, all rows to 512, whole-unit admission preflight. |
| No Node hierarchy / unbounded graph per family | **Compliant as stated**, though the byte budget itself is deferred to the unauthored schema table — which the draft correctly refuses to pre-commit. |
| Q2-32 child hazardous entry / recovery-is-not-entry | **Compliant by reference** — the draft retains MOVE-C3-R01's child water and unprotected-climb restrictions and retained rescue behaviour unchanged. F-09's night-ANYTHING confinement is recommended so the routine layer does not create a new entry surface by omission. |
| Q2-33 no elder veto | **Compliant.** |
| Affinity/friendship correction | **Compliant and valuable**: the draft correctly identifies that starter pairs at affinity 20 are *not* friends under the inherited 40/25 thresholds and requires the queue wording to be corrected before dispatch. This is a genuine defect caught. |
| Refuge and rat petition preserved | **Compliant.** Existing adult-singleton rotation and the lone rat exception are explicitly unchanged, and a family-enabled profile is explicitly deferred. |

**No policy violations found.** The one policy-adjacent risk is F-10, where an inherited mechanism
rather than a drafted rule would award a child production XP.

---

## 5. Acceptance conditions for a version 2 of this draft

Version 2 of the **coefficient and routine layer** (not PC-04 as a whole) may be recommended for
acceptance when all of the following are true:

1. F-01 resolved by an explicitly chosen repair, with the completion bound demonstrably reachable
   and the daily service requirement stated as an integer.
2. F-02 resolved: care accumulator unit, denominator, reachable rate set, its own maximum-rate
   bound with a one-line proof, and an explicit statement that `NEED_COUNT` remains 5.
3. F-14 resolved: an authored nutrition-point stage rule with the worked table, the per-resident
   floor-then-sum aggregation rule, and the rate-versus-whole-portion statement for the four-day
   reserve check.
4. F-03, F-04, F-05 resolved: a complete urgency statement naming buckets 0–3, the REQ-SET-014
   reconciliation, the deliberate provider-gate/urgency-1 threshold coincidence, the numeric
   provider health gate, and an explicit willingness rule for the critical path.
5. F-06, F-07 resolved: one selection model, named as a phase ordinal, with midnight attribution,
   in-flight behaviour and the two-counter distinction stated.
6. F-09 resolved: both directions of the sleep/care interaction plus post-wake confinement.
7. F-10 resolved: LEARNING severed from the mentoring path and CHILD excluded from mentoring on
   both sides.
8. F-11, F-12, F-13 resolved: affinity classification for ordinary care, conflict-roll exclusion,
   the three latch rules (implication, latch-read selection, evaluation point and order), and the
   medical/ordinary care composition rule.
9. F-08, F-15, F-16 resolved: notice codes and sources, the care coverage forecast formula, and the
   stage-row refusal owner, code and evaluation points.
10. F-17, F-19, F-20, F-21, F-22, F-23 addressed, each with the one-sentence amendment named above.
11. A fixture table exists mapping each of C-01 … C-23 to a named test, with expected integer
    values, before any dependent profile is enabled.

**These conditions do not accept PC-04.** The draft's own remaining closure items — a finite
illness model, exact departure/separation and grief/history ownership, the complete packed
schema with allocator bounds, wire/command versions, memory peak and load-barrier behaviour,
concrete family candidate templates and admission expansion in the scenario package, stage-qualified
geometry/rig/bed/contact evidence and the movement profile producer, and the independent fixtures,
negative/fault tests and owning-spec amendments — all remain open and are **not** treated by this
review as satisfied, implied or partially delivered. No task may self-approve from this draft or
from this review.

---

## 6. Scope statement

This document is a review. It produced no code, no schema, no fixture, no command and no test, and
it changed no file other than itself. It ran nothing and applied nothing. Every repair above is a
**bounded proposal for Astra to accept, alter or reject**; none is an adoption, and none carries
user authority. Where a repair names a number, that number is derived arithmetically from values
the draft itself proposes, and it is offered as an option, not as a settled coefficient.
