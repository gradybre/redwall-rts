# PC-04 family documents — independent review of the version 2 draft set

2026-09-19 · Independent reviewer · **Review only. No code, schema, fixture, catalog or command
was written; nothing was run, applied, activated or verified by execution. This document does not
complete PC-04 and no task may self-approve from it.**

**Subject.** `docs/planning/family_execution_package.md` (sha256 `04b5d867…6b96e5`),
`docs/planning/family_state_schema.md` (sha256 `fabbadf6…a36b78`),
`docs/planning/family_lifecycle_contract.md` (sha256 `eb848338…3cb478`).

**Evidence.** The three drafts plus `phase-source-excerpts.json` (needs.gd, injury.gd, catalog.gd,
schedule.gd, systems_architecture.md excerpts) and the v1 review. No repository file was opened or
executed. Findings that depend on surfaces outside the excerpt set are marked *unverified* and are
phrased as obligations to cite, never as claims of absence. I did **not** treat the v1 review as
authority; every disputed number below was recomputed from first principles.

**Disposition.** The proposed numeric/schema contract is close to execution-ready. It is **not yet
execution-ready**: nine finite blockers (B1–B9) remain, all closable by declarations or one- to
three-sentence amendments. No new coefficient is required to close any of them.

---

## 1. Independent adjudication of the disputed v1 findings

**1.1 v1 F-01 ("completion unreachable") — the parent is correct; the prior finding is withdrawn.**
Eligibility is latched (set at `care<=6000`, cleared only at `care>=9000`, otherwise retained), so a
child at 8750 is still eligible and a second service may start. Recomputing the parent's worked
example against a truncating remainder integrator with denominator 750000:

* service net rate +2750000 milli/h ⇒ per tick whole step 3, remainder +500000; over 750 ticks
  `750 × 2750000 / 750000 = 2750` exactly, remainder returns to 0. 6000 → **8750**.
* 30 idle ticks at −250000 milli/h ⇒ `30 × 250000 / 750000 = 10` exactly, remainder 0. → **8740**.
* resumed service: tick 70 gives `70 × 2750000 / 750000 = 256` (→8996); tick 71 gives `260`
  (→**9000**). Completion is reached on service tick 71 and clears eligibility.

The completion bound is therefore reachable and the v1 "dead branch" claim is wrong. Retain 3000/h
and 750 ticks. Do **not** adopt the v1 3250/h suggestion.

**1.2 v1 F-01 equilibrium arithmetic — the parent is correct.** Decay runs all 24 hours including
served hours; the correct balance is `gross 3000 × 2h = 6000` against `250 × 24 = 6000`, i.e.
**1500 paired ticks/day**, an integer. The v1 figure 6000/2750 = 1636.36 applied a *net* rate to a
*full-day* decay total and double-counted the two served hours. The parent's 1500-tick baseline
demand and `1500 × living_child_count` settlement demand follow correctly.

**1.3 v1 F-14 maximum hunger rate — the parent is correct.** `250000 × 1600 × 1200 × 1000 / 1e9 =
480000` (adult/elder, LARGE, winter). 360000 is only the child maximum. *Unverified:* the
`MAX_RATE_MAGNITUDE = 1 200 000` constant cited by the v1 review is not in this excerpt set; the
implementation packet must cite it rather than inherit the claim.

**1.4 Arithmetic I reproduced and confirm as correct.** Hunger table (child 187500/225000/300000
and 225000/270000/360000); NP/day table (child 4500/5400/7200 and 5400/6480/8640; adult/elder
6000/7200/9600 and 7200/8640/11520); mood divisors 12 (3+2+2+1+2+2) and 10; care predivision bound
3499999 and whole-step magnitude 4 (−999999 on the decay side, so the stated −4..10004 window is a
safe superset); remainder magnitude <750000 under truncation toward zero; child schedule tiles
exactly 24 hours (10+2+2+2+2+2+2+2); child purpose 4×400 + 4×320 = 2880/day against 75×24 = 1800.

**1.5 Byte arithmetic — all totals reproduce exactly.** Household 256+1024+1024+1024+8192+8192+8 =
**19720**; dependent 2048+2048+4096+4096+2048+4096+4096+2048+2048+8 = **26632**; combined **46352**;
scratch 2048+1024+512 = **3584**; permanent **49936**; live+scratch+one snapshot **96288**. Member
arena 256×8 = 2048 matches `member_slot` capacity. `provider_served_ticks_today` 0..18000 matches
the 18000-tick day of ARCH-TICK-002 at one child per provider per tick.

**1.6 Phase congruences — confirmed favourable.** ARCH-TICK-002 gives hour boundaries at
`(k+4500) mod 750 = 0` and midnight at `(k+4500) mod 18000 = 0`. Since 4500 ≡ 0 (mod 30), (mod 750)
and (mod 18000) ⇒ hour and midnight ticks are always `k ≡ 0 (mod 30)`, i.e. always care-pass ticks.
The drafted midnight sequence (attribute elapsed interval to the old day → lifecycle commit → reset
daily provider totals and `served_day` → selection) is therefore realisable without a special case.
State this congruence in the draft as a proof, not a coincidence.

**1.7 ScheduleTemplate ID — confirmed.** `schedule.gd` states template IDs are compiled from
ascending ASCII key order. `{default, flexible, night_shift, young_day}` sorts `default(0),
flexible(1), night_shift(2), young_day(3)`; `y` > `n`, so existing persisted IDs are preserved and
the new ID is 3, exactly as the lifecycle contract claims. `TEMPLATE_KEYS`/`TEMPLATE_COUNT` must
change with it.

**1.8 CommandKind — confirmed.** `catalog.gd` lists exactly 24 kinds 0..23; the drafts add none.

---

## 2. Findings

Severity: **BLOCKER** = blocks an execution-ready numerical/schema contract; **MAJOR** = will
produce divergent implementations; **MINOR** = one-sentence closure.

**F-01 — BLOCKER (B1). CHILL phase placement is self-contradictory.** The lifecycle contract says
onset happens "At the start of the elapsed interval, before Needs samples its health-rate inputs",
but also that the **CareHealth** coordinator submits it *after* committed movement incidents. Per
the excerpt, `needs.gd::_tick_resident` samples `starving`/`cold_gain`/`health_rate` first and then
integrates, inside the needs-integration phase (ARCH-SYS-003); movement incidents are produced at
ARCH-SYS-012 and CareHealth is ARCH-SYS-017 — all strictly *after* that sample. The two sentences
cannot both hold in one tick. *Repair (no new value):* delete the "before Needs samples" clause and
state: "CHILL onset is submitted in the CareHealth phase of tick k, from the cold value committed
by tick k's needs integration; any untreated drain it causes first enters the health sample of tick
k+1." This preserves the deliberate pre-interval sampling order the excerpt documents.

**F-02 — BLOCKER (B2). The notice-code registry is incomplete across documents.** The lifecycle
contract enumerates seven codes; the parent uses `CARE_NO_WILLING_PROVIDER`, `CARE_DEFERRED_MEDICAL`
and `CARE_DEFERRED_SLEEP`, none of which appear in that enumeration. This is an obsolete-list
contradiction, not an appendix refinement, and I decline to resolve it silently. *Repair:* add the
three codes to the single registry with severity (the two defer codes INFO per the parent, the
willing-provider code WARNING/CRITICAL from the critical latch) and their clear conditions.

**F-03 — BLOCKER (B3). `CHILL_UNTREATED` has no authoritative predicate.** Under the excerpted
merge rule, equal severity retains the lower kind ID, so CHILL=6 is discarded as the aggregate
whenever any severity-1 kind 1..5 is already present. The only new persisted bit is
`chill_episode`, which is an onset latch that also stays 1 after treatment until `cold<=1000`.
There is therefore no state from which "chilled and untreated" can be derived, and the contract
itself disclaims that an incident-history store exists. *Repair:* either define the notice
predicate explicitly over `(chill_episode == 1) AND (an active aggregate injury exists)`, or add a
second B8[512] `chill_active` bit (+512 live, +512 snapshot) and state its set/clear points.

**F-04 — BLOCKER (B4). The paired social day accumulator has no bounded owner.** The parent makes
ordinary care inherit the +2-per-pair-per-day social award after 750 accumulated paired ticks
(correctly equal to 60 WU at 60 WU/game hour), and requires care and social time to share one
pair-day accumulator. But care pairs are explicitly *not* degree-8 affinity edges, so a pair with no
Relationship row has nowhere bounded to accumulate; the naive space is 256×256. The family schema
allocates nothing for it. *Repair, bounded and deterministic:* state that the accumulator lives on
the existing Relationship row only; ordinary care locates or creates that row under the unchanged
degree-8 rules, and when no row can exist the care service awards no affinity and consumes no
budget. Alternatively award only on a completed full-length 750-tick service instance (exactly one
award maximum per instance) and say so — but note this changes the semantics from "accumulated that
day" and drops partial-service accumulation.

**F-05 — BLOCKER (B5). Catalog fingerprint and Injury payload versions are declared only for
SET_POLICY.** Three further appends are proposed: `INJURY_KIND` CHILL=6 / COUNT=7, `ACTIVITY`
PLAY=4 / LEARNING=5, and the ScheduleTemplate key. Per `catalog.gd`, INJURY_KIND values are
protected by decision 0018 and ACTIVITY is an explicit fixed §4.3 enum described as "Four values, no
reserved gap" — appending is ID-preserving but is a GDD §4.3 amendment plus a rules/catalog
fingerprint change, and persisted schedule hours carry Activity values whose domain validator
currently bounds at 3. Separately, `chill_episode` is a new Injury column requiring an Injury owner
schema version bump and a canonical-image entry. *Repair:* one paragraph stating that all four
changes (three appends + Injury schema) bump their declared fingerprints/versions together with
SET_POLICY, and that pre-family files and queued commands refuse rather than migrate.

**F-06 — MAJOR (B6). The 750-tick turn limit can be a no-op.** 750 = 25×30, so a service started at
a pass tick retires at another pass tick. The schema retires the assignment "in the same committed
tick", and the pass runs after that commit, so the same provider is free and the same child still
eligible in that very pass. With a single available provider the pair is immediately re-selected
and the only cost is one restoration-free selection tick, which defeats the stated turn-taking
purpose. *Repair:* state one rule — e.g. "a provider that retired a service on the turn limit is
not a candidate for the same child in the pass that retires it" — and state the intended behaviour
when it is the only qualified provider (immediate re-selection on the next pass is acceptable if
declared).

**F-07 — MAJOR (B7). Four validator holes in the dependent table.**
(a) `service_paired_ticks` is given range 0..750 while the invariant text says a saved active
assignment holds 0..749; the load validator's accepted domain must be stated as: 750 is refused
whenever `provider_slot != -1`.
(b) ADULT/ELDER canonical-zero list omits `service_paired_ticks` (it lists care, remainder,
eligible, warning bits, preferred IDs, provider ref); add it, and state which row owns the session
counter (child row) so it is not duplicated on the provider.
(c) Load validation requires every provider ref to identify a "living **eligible** ADULT/ELDER",
but eligibility is an instantaneous hunger/rest/health/danger predicate that no save can guarantee
and that the same section says is rechecked on resume. Reduce the load invariant to living, present,
stage-legal and generation-matching.
(d) Scratch is sized 256 child keys while the store has 512 present-capable rows; state that the
sort set is *living* children (bounded by the 256 living cap) and that exceeding 256 refuses rather
than truncating.

**F-08 — MAJOR (B8). `core/family_rules.gd` table representation is unstated.** Prioritised in the
brief: the 3×3×2 table must be declared as a flat packed array with an explicit index formula
(`stage*6 + size*2 + season`), built once at catalog publication and made read-only, **not** a
nested Dictionary and not rebuilt per tick. The draft's "immutable table" wording does not exclude a
Dictionary, and a GDScript `const Dictionary` is not deeply immutable by itself. Also state that
the stage count is a bound only and is never persisted.

**F-09 — MAJOR (B9). The care pass and care integration are not registered phases.** The parent
places the pass "after that tick's care/health/lifecycle commit", i.e. after ARCH-SYS-019, in the
progression/notices band, while job selection (ARCH-SYS-009/010) runs earlier in the same tick and
must consume assignments staged by the *previous* pass. Nothing in the excerpted ARCH-SYS table
carries these. *Repair:* amend `systems_architecture.md` with named ordinals for (i) care
integration inside ARCH-SYS-017 and (ii) the care selection pass after ARCH-SYS-019, and define
"completed tick modulo 30" unambiguously (state whether the predicate is on k or k−1, since
`completed_tick=k` is set at the end of the tick). The parent's own statement that this ordering
must be reconciled with ARCH-TICK-003 is correct but is an obligation, not a closure.

**F-10 — MAJOR. Provider commitment is derived but the derivation's cost is unstated.** "No inverse
provider→child array is authoritative … derived by bounded scan of the 512 dependent rows" is
sound, but the "not committed to another service" gate and the duplicate-provider refusal both need
that scan. State that the pass builds the 512-byte occupancy scratch once per pass (already
budgeted) and that no other caller performs an unbounded scan.

**F-11 — MAJOR. Injury ordinal API and exhaustion behaviour are prerequisites, not rules.** The
excerpt shows `_last_incident_ordinal` is private and `apply_incident` refuses `ordinal <= last`.
The contract's "read the last accepted ordinal, checked-add 1" requires a typed accessor that is not
shown, and "I64_MAX exhaustion refuses the next event and holds publication with an explicit
invariant error" is a behaviour the excerpted store does not have. Also state whether the ordinal
cursor is persisted. Name these as owner-API obligations on the Injury/CareHealth joint review.

**F-12 — MINOR. CHILL incident arguments are legal against the excerpted checks.** kind 6 < COUNT 7,
severity 1 ∈ {1,2}, loss 0 passes `loss < 0` and `loss > HEALTH_MAX`, ordinal > 0 and strictly
increasing. `needs.apply_health_event(slot, 0)` is a no-op write path; state that a zero-loss
incident is expected to return 0 and is still ordinal-consuming.

**F-13 — MINOR. CHILL clear-by-treatment is coarser than it reads.** There is one aggregate, so
treating a resident whose aggregate is FALL also clears the pending CHILL state. Combined with the
latch rearm condition (`cold<=1000` and no active CHILL aggregate), this is conservative but should
be stated explicitly so an implementer does not add a per-kind clear.

**F-14 — MINOR. Cold units.** `cold_milli_hours >= 4000` (onset), `>=3000` / `<2000` (warning) and
`<=1000` (rearm) are consistent milli-hour thresholds against the excerpted `_integrate_cold`, which
floors at 0 and has no upper bound. State that onset reads the committed value, never the rate.

**F-15 — MINOR. Household allocator is internally consistent.** Null `(-1,0)`, first allocation at
generation 1, "lowest free row whose retained generation < I32_MAX allocates with generation+1", and
the single terminal use of generation MAX all compose without collision; `next_household_id` 1 →
terminal 2147483648 yields exactly the stated 1..2147483647 domain. No change required; add it to
the fixture list as an asserted invariant rather than prose.

**F-16 — MINOR. "Last currently qualified willing provider" is undefined.** Give the exact predicate
evaluated at the departure-warning midnight (living, ADULT/ELDER, willing, not itself departing,
stage-legal) and state that instantaneous route/need gates are deliberately excluded so the warning
is stable across a day.

**F-17 — MINOR. Child key packing is unstated.** 256 I64 sort keys are correctly sized, but the
packing of `(critical latch, care ascending, persistent_id ascending)` into one i64 should be
stated (1 + 14 + 31 bits fits) so the sort is reproducible byte-for-byte across implementations.

**F-18 — Obsolete-prose check (reported, not silently resolved).** I compared the parent's body
against its own §"Version 2 review resolutions" appendix and the two companions. The v1 review's
urgency-1 text no longer appears — the body now states urgency 3 with ranks 0/1/2 throughout, so
there is no stale urgency contradiction. Care initial 6500, thresholds 6000/9000/3500/1500 and
clears 4000/2000, provider gates (hunger>1500, rest>500, health>=16, child health>15), the
finish-reason precedence and the dedup key all agree across the three files. The only live
cross-document contradictions I found are F-01, F-02, F-03 and the F-07(a)(c) domain mismatches.

**F-19 — Reversal recorded, not a defect.** The parent deliberately reverses the v1 recommendation
to exclude CHILD from the 18:00 pair-conflict roll, and instead states the roll applies to all
stages with conflict memory but no injury or combat. That is an authored choice within delegated
scope and I do not object; it should be listed as a deliberate reversal in the change log so it is
not re-litigated, and the conflict path's affinity loss must be reconciled with F-04's Relationship
row question (a child with no edge cannot lose affinity).

**F-20 — Scope hygiene, confirmed good.** All three files state they are proposals under delegated
engineering authority, not user-supplied values; the Refuge rotation and lone rat petition are
preserved; no birth/aging/adulthood/age-death is introduced; no elder penalty, no gender field, no
neglect-death roll, no child productive XP or tool, no graphic presentation, no teleport fallback.
The INIT-B "Friend pairs" correction (affinity 20 against thresholds 40/25) remains a genuine
defect caught upstream. I found no policy violation.

---

## 3. Smallest finite blocker set for an execution-ready contract

Closing exactly these nine, each a declaration or a one- to three-sentence amendment, makes the
numerical and schema contract executable as written:

**B1** CHILL phase placement (F-01). **B2** notice-code registry completion (F-02). **B3**
`CHILL_UNTREATED` predicate or `chill_active` bit (F-03). **B4** bounded owner for the paired
social day accumulator (F-04). **B5** catalog fingerprint + Injury schema version declarations for
the three appends and the new bit (F-05). **B6** turn-limit re-selection rule (F-06). **B7** the
four validator-domain corrections (F-07). **B8** `family_rules.gd` flat-array representation and
index formula (F-08). **B9** registered ARCH-SYS ordinals for care integration and the care pass,
plus an unambiguous pass predicate (F-09).

None of these requires a new coefficient, a scope change, spend or an art decision, so all nine are
bounded repairs Astra may make directly.

---

## 4. Prerequisites that are *not* missing rules

These remain open but are implementation or external-profile dependencies; they must not be counted
as defects of this draft set and must not be closed by it:

1. Injury owner: typed last-ordinal accessor, exhaustion refusal path, ordinal persistence (F-11).
2. Needs owner: citation of the actual health-rate composition and the maximum-rate constant.
3. Relationship owner: the pair-day accumulator contract that B4 binds to.
4. Command owner: the SET_POLICY record shape (arg0/arg1/payload) that CARE_WILLING/CARE_PREFERRED
   assume, and the atomic-unit ACCEPT_CANDIDATES variant and its replay identity.
5. Multi-owner admission/lifecycle transaction (the drafts correctly refuse to fake it with a
   sequence of individually atomic calls).
6. Notice owner, chronicle and memory store — explicitly disclaimed by the lifecycle contract.
7. Movement profile producer: stage-qualified child geometry/rig/bed/contact. Until published, no
   child holds a valid bed and every child-containing admission unit refuses; this is a declared
   external prerequisite, and the parent already states the refusal correctly.
8. PC-03: the named family-enabled scenario and its finite unit sequence.
9. World-level snapshot/memory accounting: the 96288 B figure is owner-local and the schema is right
   to make no ARCH-MEM-006 claim from it.

---

## 5. Scope statement

This document is a review. It produced no code, schema, fixture, catalog entry, command or test, and
changed no file other than itself. It activated nothing and completed no PC-04 claim. Every repair
above is a bounded proposal for Astra to accept, alter or reject; each is derived arithmetically or
structurally from the drafts' own proposals and the supplied excerpts, and none carries user
authority. Where the excerpt set was insufficient, the finding names the owner to cite rather than
asserting absence.
