# PC-04 family documents — independent confirmation review of the version 3 draft set

2026-09-19 · Independent reviewer · **Review only. No code, schema, fixture, catalog, command or
test was written; nothing was run, applied, activated or verified by execution. This document does
not complete PC-04, does not activate any spec, and no task may self-approve from it.**

**Subject.** `docs/planning/family_execution_package.md` (FAMILY-C4-R01 v3 draft),
`docs/planning/family_state_schema.md` (FAMILY-STATE-R01 v2 draft),
`docs/planning/family_lifecycle_contract.md` (FAMILY-LIFE-R01 v2 draft).

**Evidence.** The three drafts, `draft-v2-review.md`, `arithmetic.json` and
`phase-source-excerpts.json` as supplied. No repository file was opened or executed. Findings that
depend on surfaces outside the supplied excerpts are stated as obligations to cite at dispatch,
never as claims of absence. Per the parent's verification, `Injury.last_incident_ordinal_of()`
exists and the ordinal cursor is persisted; I do not treat the excerpt's omission as absence.

**Disposition.** The v2 blocker set B1–B9 is closed, and F10–F17 are addressed. One genuine defect
remains (C-01, CHILL_UNTREATED re-raise), plus two minor within-document items (C-02, C-03). None
requires a new coefficient, scope change, spend or art decision. The numerical and schema contract
is confirmed; the package is **not** runtime-complete and must not be described as implemented.

---

## 1. Disputed arithmetic adjudicated

**1.1 The parent is right to reject `4500 mod 18000 = 0`.** `4500 mod 18000 = 4500`. The v2
review's compressed phrase "4500 ≡ 0 (mod 30), (mod 750) and (mod 18000)" is false in its last
term and is correctly withdrawn.

**1.2 The v2 *conclusion* nevertheless survives, by a different route, and the v3 text states the
correct one.** From ARCH-TICK-002, hour ticks satisfy `(k+4500) mod 750 = 0`; since `4500 mod 750
= 0`, hour ticks are exactly `k mod 750 = 0`, and `750 mod 30 = 0`, so every hour tick is a care
pass tick. Midnight satisfies `(k+4500) mod 18000 = 0`, i.e. `k = 13500 + 18000m`; `13500 mod 30 =
0` and `18000 mod 30 = 0`, so every midnight is likewise a care pass tick. First midnight 13500 and
the 18000-tick period are unchanged; no calendar offset moved. The v3 statement
("4500 mod 30 = 0 and 18000 mod 30 = 0 … first midnight remains 13500") is sufficient and correct.

**1.3 Care equilibrium — confirmed, not reopened.** Decay runs all 24 hours including served hours;
gross 3000/h × 2 h = 6000 balances 250/h × 24 h = 6000, giving the integer 1500 paired ticks/day
baseline. Eligibility is latched (set at `care<=6000`, cleared only at `care>=9000`), so 9000 is
reachable across turns exactly as the worked example states. I do **not** re-propose 3250/h and I
do **not** apply decay a second time inside the served interval.

**1.4 Tables unchanged and still consistent.** Hunger milli-rates, NP/day rows, mood divisors 12/10,
care predivision bound 3499999, whole-step magnitude ≤ 4, remainder magnitude < 750000, and the
480000 adult/elder LARGE/winter hourly maximum all reproduce as in `arithmetic.json`. No
recomputation of those rows is repeated here.

---

## 2. Confirmation of the nine v2 blockers

**B1 CHILL phase placement — CLOSED.** Onset is now submitted at CareHealth after committed
movement incidents, reading the cold value committed by tick k's Needs integration, with the
untreated drain first entering the health sample at k+1. The "before Needs samples" clause is gone.
This is consistent with the excerpted `_tick_resident` sampling order and adds no second health
integration and no retroactive resampling.

**B2 notice registry — CLOSED.** `CARE_NO_WILLING_PROVIDER`, `CARE_DEFERRED_MEDICAL` and
`CARE_DEFERRED_SLEEP` are in the single enumeration with severities (INFO for the two defer codes,
child WARNING/CRITICAL latch for the willing-provider code) and clear conditions. Selection order
and the `(code, resident persistent ID)` dedup key agree across all three files.

**B3 CHILL_UNTREATED predicate — CLOSED as drafted, with residual C-01 below.** The predicate
`chill_episode = 1 AND an active aggregate injury remains` is explicit, derives nothing from an
absent incident-history store, and correctly survives FALL/CUT winning the primary kind.

**B4 paired social day accumulator — CLOSED.** It lives on the bounded Relationship row, sharing one
pair-day accumulator with social contact, capped at 750 ticks which is also the once-per-day award
latch. `paired_social_ticks_today: I32[2048]` = 8192 B and `paired_social_day: I64[2048]` = 16384 B
sum to the stated **24576** mutable bytes plus an equal snapshot payload, and the draft correctly
refuses to fold that into the family owner's 46352 B. When no edge is available, need/care benefits
still apply and no affinity is generated or banked — the required bounded answer. The F-19
reconciliation is also handled: a pair without an edge cannot satisfy affinity < 0 and cannot enter
the conflict roll.

**B5 fingerprint/version declarations — CLOSED.** CHILL=6/COUNT=7, PLAY=4/LEARNING=5, `young_day`,
the SET_POLICY selector extension and `Injury.chill_episode` enter one versioned rules/catalog
fingerprint; Injury owner schema 1→2, new family owner at 1, other owners listed against their base
in the implementation packet; pre-family files and queued commands refuse rather than migrate. The
requirement to check Injury's actual baseline schema at dispatch is correctly stated as an
obligation, not an assumption.

**B6 turn-limit re-selection — CLOSED.** A service retired by the 750-tick limit records its
provider typed row at the child typed row in a 512×I32 per-tick scratch filled with −1 at tick
begin; if a pass runs that tick, that exact pair is excluded, another eligible provider may serve,
and the sole-provider case explicitly waits for the next 30-tick pass. Completion and safety
interruptions deliberately do not create the exclusion. The scratch has no effect after the current
tick's pass and, because saves occur only at completed boundaries, is correctly neither persisted
nor hashed — it therefore cannot alter a save hash or replay. Note `750 = 25 × 30`, so a service
begun on the interval staged by a pass retires on a pass tick; the exclusion is the operative rule
and the no-op case the v2 review identified is removed.

**B7 validator holes — CLOSED, all four.** (a) `service_paired_ticks` domain is 0..750 with the
explicit refusal of 750 while `provider_slot != -1`, stable saved active range 0..749. (b) The
ADULT/ELDER canonical-zero list now includes `service_paired_ticks`, and the child row alone owns
the session counter; a child must hold `willing = 0` and `provider_served_ticks_today = 0`. (c) The
load invariant is reduced to present/living/stage-legal/generation-matching, with instantaneous
hunger/rest/route eligibility rechecked on resume — correct, since no save can guarantee an
instantaneous predicate. (d) Only living children enter the 256-key sort, and more than 256 living
residents refuses the world invariant before any scratch write rather than truncating.

**B8 rules table representation — CLOSED.** Two flat `PackedInt64Array` tables of 18 values,
index `stage*6 + size*2 + season_index`, allocated once at rule publication, private, exposed only
through checked scalar readers, all 18 cells validated against the formula before publication.
2 × 18 × 8 = **288** immutable catalog bytes, correctly excluded from the 46352 B mutable payload.
Stage count 3 is declared a bound only and is never persisted.

**B9 registered phases and pass predicate — ADDRESSED AS A PROPOSAL; spec amendment still open.**
ARCH-SYS-017a (care integration, using only service participation from the preceding committed
interval and granting nothing for a new assignment), 017b (CHILL and medical completions, then
final mood), 019 (lifecycle commit) and 019a (midnight daily-fairness reset, then selection on
`k mod 30 = 0`) are named and ordered coherently, and the predicate is now unambiguously on the
in-flight tick k before `completed_tick` is published. Ordinary job selection consuming the prior
pass's staged reservations is stated. These ordinals are *proposed*; `systems_architecture.md` is
not amended by this draft set and the reconciliation with ARCH-TICK-003 remains an obligation.

---

## 3. F10–F17 confirmation

F10 provider occupancy is built once per pass from the 512 bindings into the budgeted 512 B scratch,
with duplicate detection; no other unbounded scan is introduced. F11 is correctly carried as an
Injury/CareHealth joint obligation — the accessor and persisted cursor exist per parent
verification, and the I64_MAX refusal/publish-hold response is explicitly *not* claimed to exist
today and is bound to fault-test evidence. F12 zero-loss ordinal-consuming incident is stated. F13
coarse aggregate clear is stated, with no per-kind cure list. F14 cold milli-hour thresholds
(4000 onset / 3000 warn / 2000 clear / 1000 rearm) are consistent and read the committed value.
F15 allocator invariants are unchanged and internally consistent. F16 gives the exact stable
departure-warning predicate (living, stage-qualified, willing, no departure intent; instantaneous
need/route/job gates deliberately excluded). F17 key packing is now explicit:
`(ordinary_bit<<45) | (care<<31) | persistent_id` with `care` 0..10000 occupying bits 31..44,
`persistent_id` 1..I32_MAX fitting bits 0..30 and `ordinary_bit` at bit 45 — no overlap, ascending
sort yields critical-first then care ascending then ID ascending, and the stated bound `< 2^46`
holds.

---

## 4. Byte arithmetic of the new scratch and extensions

Scratch: 256 × I64 child keys 2048 + 256 × I32 provider rows 1024 + 512 B occupancy 512 +
512 × I32 turn-retired provider rows 2048 = **5632 B** as stated. Combined permanent payload
46352 + 5632 = **51984 B**. Owner-local live + scratch + one full snapshot
46352 + 5632 + 46352 = **98336 B**, matching both the schema and `arithmetic.json`, and correctly
carrying no ARCH-MEM-006 world claim. `chill_episode` B8[512] adds 512 live + 512 snapshot bytes to
the Injury owner. Relationship adds 24576 mutable bytes plus an equal snapshot payload, budgeted to
the implementation packet rather than to the family owner. `provider_served_ticks_today` 0..18000
remains exactly the 18000-tick day at one child per provider per tick.

---

## 5. Remaining findings

**C-01 — MAJOR (the one genuine defect). `CHILL_UNTREATED` can re-raise without a new chill onset.**
*Exact contradiction.* The predicate is `chill_episode = 1 AND an active aggregate injury remains`,
while `chill_episode` rearms only when `cold_milli_hours <= 1000` **and** no active CHILL aggregate
remains. Successful treatment clears the aggregate but not the episode latch if the resident is
still cold.
*Reproducer.* (1) Resident reaches `cold_milli_hours = 4000`; CHILL onset commits, `chill_episode
= 1`, notice active. (2) Treatment completes; the aggregate clears; the draft states the notice
clears immediately. (3) The resident stays exposed with `cold_milli_hours` between 1001 and 3999,
so the latch does not rearm and `chill_episode` stays 1, yet no new CHILL incident is admitted.
(4) An unrelated CUT incident creates a new active aggregate. The predicate is now true again and
`CHILL_UNTREATED` re-raises, asserting a chill-derived medical need that no onset created.
*Smallest ordinary engineering resolution.* Take the v2 B3 option B that was scoped but not
adopted: add a second `chill_active` B8[512] bit in the Injury owner (+512 live, +512 snapshot,
inside the same schema 2 bump), set it on successful CHILL onset commit and clear it on successful
aggregate treatment; make the notice predicate `chill_active = 1` and leave `chill_episode` purely
as the onset/rearm latch with its existing `cold <= 1000` rearm. Clearing `chill_episode` at
treatment instead is **not** acceptable, because it would permit immediate re-onset while still
deeply exposed, which the lifecycle contract explicitly forbids. This is one column plus two
sentences; it is not a coefficient, scope or spend decision.

**C-02 — MINOR. Stale pass-predicate prose in the parent body.** "Reselect in a global care pass
every 30 ticks (completed tick modulo 30 = 0)" in *Daily routines and shared care* now contradicts
the v3 disposition's "the predicate uses the in-flight tick k, before completed_tick is finally
published". One of the two must go; edit the body sentence to the in-flight-k wording so no
implementer reads the older phrasing as authoritative.

**C-03 — MINOR. Day authority for eviction protection is unnamed.** The parent protects a
same-day-contact edge by selecting only non-friend edges with `last_contact_day` strictly before
today, while the new column it budgets is `paired_social_day`. If these are two independently
written day fields they can diverge (contact recorded on one path only), and the once-per-day award
latch and the eviction guard would then disagree. Resolution: state in one sentence either that
`paired_social_day` *is* the authority the eviction guard reads, or that it is written in lockstep
with the existing `last_contact_day` in the same Relationship commit. The Relationship owner must
confirm the actual column name at dispatch; I do not assert either column absent.

**C-04 — MINOR, obligation only. Mood ownership across 017b and ARCH-SYS-018.** The draft computes
final mood at ARCH-SYS-017b, while ARCH-SYS-018 SocialMood is the registered needs-derived mood /
affinity / memories phase and also owns the 18:00 conflict result and the paired contact that the
+2 pair-day award rides on. The integration owner must state, in the systems_architecture
amendment, which phase writes the mood value and where the paired-social accumulator increment and
its once-per-day award land relative to 017a/017b/018. This is an ordering declaration, not a
missing rule, and the parent already carries the ARCH-TICK-003 reconciliation obligation.

**C-05 — Recorded, not a defect.** The child pair-conflict decision (non-graphic arguments with
inherited affinity/memory consequences at all stages, no combat or injury) is a deliberate reversal
of the first review's optional age-exclusion suggestion, correctly marked as an authored engineering
choice and not a user policy decision. It should stay in the change log so it is not re-litigated.

**C-06 — Scope hygiene, confirmed good.** All three files remain proposals under delegated
engineering authority. No births, aging, adulthood transition or death by age; fixed stage; no elder
penalty; no gender field; no neglect-death roll; no child productive XP, tool or output; no graphic
presentation; no teleport fallback; Refuge adult-singleton rotation and the lone rat petition
preserved; the INIT-B "Friend pairs" correction (affinity 20 against 40/25) still stands. No policy
violation found.

---

## 6. Classification: closed versus still needed

**Closed at the numerical/schema level (no further decision required to write the implementation
packet against them):** all stage/size/season need and service coefficients and the hunger and
NP/day tables; the care integrator's rate set, denominator, truncation, bounds and remainder
discipline; care thresholds, hysteresis and the eligibility latch; finish-reason precedence and
session-tick accounting; the 1500 paired-tick daily baseline; selection ordering, fairness totals
and the midnight attribution/reset sequence; the turn-limit exclusion scratch and its
non-persistence; child sort-key packing; all validator domains and canonical-zero/unused values;
household allocator, ID and generation terminal behaviour; every byte figure (19720 / 26632 /
46352 / 5632 / 51984 / 98336, Relationship +24576, chill latch 512, rules 288); schedule template
ID 3 and the SET_POLICY selector domain 0..3; the tick-phase congruences and first midnight 13500.

**Still needed before any activation claim:** (i) exact public API parameter records and wire
signatures for the family owner, including the `select_care_into` / `advance_care_tick` fact
records; (ii) the atomic multi-owner admission and lifecycle transaction — its participants,
ordering and fault boundary — which must not be faked as a series of individually atomic calls, and
the atomic-unit `ACCEPT_CANDIDATES` variant with its replay identity; (iii) owning-spec activation:
`systems_architecture.md` ordinals 017a/017b/019a and the ARCH-TICK-003 reconciliation, GDD §4.3
protected-enum and schedule-template amendments, Injury schema 2 against its verified baseline, and
the rules/catalog fingerprint change; (iv) the Relationship owner's pair-day accumulator contract,
column naming (C-03) and budget; (v) the Injury/CareHealth joint review of ordinal submission order,
I64_MAX refusal and publish-hold, with fault-test evidence; (vi) PC-03's named family-enabled
profile and finite unit sequence; (vii) the stage-qualified movement/geometry/bed/contact producer,
until which every child-containing admission unit correctly refuses; (viii) complete codecs,
world-level snapshot accounting, and native Mac player-flow captures.

---

## 7. Scope statement

This document is a review. It produced no code, schema, fixture, catalog entry, command or test and
changed no file other than itself. It activated nothing, ran nothing and completes no PC-04 claim;
the package remains in-flight planning, not runtime. C-01 through C-04 are bounded proposals for
Astra to accept, alter or reject; each is derived from the drafts' own statements and the supplied
excerpts, none carries user authority, and none is a scope, spend or art decision.
