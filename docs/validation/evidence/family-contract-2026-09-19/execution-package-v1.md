# Fixed life stages, households and care

PC-04 / FAMILY-C4-R01 · version 1 draft · 2026-09-19 · Astra

Status: authoring and independent review. This is a proposed exact engineering
amendment under the delegated settlement scope, not a record of numeric values
supplied by Brendan and not permission to activate incomplete dependent profiles.
The user-confirmed boundary is DEC-032/033. The policies below are [NEW] except
where explicitly inherited. Births, aging, adulthood transitions and death by age
remain outside this release. Stage is fixed for a scenario. All living residents
count toward 256, all resident rows toward 512. No family owns a Node hierarchy.

## Authority and compatibility

Retain Residents ADULT=0, CHILD=1, ELDER=2. Its stage column already exists; do not
allocate another. Species identity stays independent of stage. Explicit stage
rows select coefficients; an absent row refuses before spawn/publication. Matching
an adult coefficient is an authored equality, never an implicit adult fallback.
Physical dimensions, locomotion costs, cargo envelopes and rig/pose measurements
remain owned by the stage-qualified movement profile package. The values here
cannot qualify geometry. MOVE-C3-R01's child water/unprotected-climb restrictions
and retained rescue behavior remain unchanged. Elders receive no age-only work,
movement-mode, danger-threshold or skill penalty.

Household membership and caregiver relationships are distinct from affinity.
They never consume a degree-8 Relationship link or disappear when an affinity
edge is evicted. Shared surnames imply neither kinship nor membership. A household
may include unrelated residents and multiple species. Historical names, affinity
and family history use persistent resident IDs; live service assignments always
validate directory slot and generation. Loss of one caregiver leaves the other
and community fallback available.

The six starter pairs in INIT-B have affinity 20, as the numeric starter contract
states. They are not automatically friends: inherited friendship enters at 40
and clears below 25. The queue's phrase “Friend pairs” must be corrected before
INIT-B dispatch. Family expansion does not change these twelve adult initial
residents, add children to the refuge baseline, or change the lone rat petition.
PC-03 must explicitly author mixed-stage scenario households.

## Explicit need and service coefficients

All rates are need points per game hour, integrated with the existing signed
integer remainder rule. No floating-point rates or second health integrator.

| Quantity | ADULT | CHILD | ELDER |
|---|---:|---:|---:|
| Hunger stage multiplier /1000 | 1000 | 750 | 1000 |
| Awake rest decay | 375 | 375 | 375 |
| Bed / floor rest restoration | 1200 / 750 | 1200 / 750 | 1200 / 750 |
| Comfort decay | 100 | 100 | 100 |
| Social decay | 100 | 100 | 100 |
| Purpose decay | 75 | 75 | 75 |
| Daily-care need decay | not applicable | 250 | not applicable |
| Daily-care restoration while receiving service | 0 | 3000 | 0 |
| Starvation health drain | 4 | 4 | 4 |
| Healthy recovery / infirmary recovery | 2 / 4 | 2 / 4 | 2 / 4 |

Hunger's milli-point hourly rate is floor(250000 × size_multiplier ×
season_multiplier × stage_multiplier / 1000000000), evaluated with checked i64
products before division. Size is explicitly SMALL1000/MEDIUM1200/LARGE1600;
season is WINTER1200/otherwise1000. This produces child SMALL187500/MEDIUM225000/
LARGE300000 outside winter and 225000/270000/360000 in winter. Adult and elder
rows retain existing results. Species-to-size comes from the existing validated
species catalog. This table is a need-consumption table, not body scaling.

Existing hunger 3500/1500/0, rest 2500/500/4000, health 0/1..15/16..99,
comfort/social thresholds, temperature/clothing rules, hazard health rates,
food effects and injury treatment quantities apply explicitly to all stages.
Illness has no separate implemented disease catalog today; PC-04 must not claim
that equal injury coefficients implement illness. The finite illness contract is
an unresolved authoring item listed below, and blocks full PC-04 acceptance.

Care is 0..10000, initially 6500 for a child; other stages and absent rows store
canonical zero with zero remainder. It decays during sleep as well as waking.
Service adds 3000/hour while ordinary decay continues, net +2750/hour. A child
becomes eligible for ordinary care at care<=6000 and remains eligible until
care>=9000. Warning at<=3500, critical at<=1500; clear the corresponding warning
only above4000/2000 respectively. Zero care changes mood and warnings, not health
by an invented direct neglect-death roll. Existing food, exposure, illness/injury
and failed rescue remain the causal survival routes.

Adult/elder mood keeps the inherited divisor10 formula. Child mood is
clamp(floor((3*hunger+2*rest+2*comfort+social+2*purpose+2*care)/12)+memories,
0,10000). Care is integrated before mood at CareHealth; lifecycle follows.
There is one accumulator for care, owned by the dependent store. Reaching either
bound discards outward overflow and remainder exactly as Needs does.

An ordinary bed is valid for a child only if its actual furniture use/contact
and the child's qualified profile admit it. No doubled occupancy, free cot,
sharing workaround or generic adult fit. One assigned valid reachable bed per
resident, including all admitted children/elders. Clothing tier1 remains a spawn
equipment grant. Children receive no productive tool or seeded productive skill
XP. Adults and elders retain immigrant basic tool and two seeded active skills
at5000XP each. Reserved skill3 remains0 for every stage. Prepared portions and
raw-food rules are unchanged; lower demand cannot manufacture partial prepared
servings or refund clamped nutrition.

## Daily routines and shared care

Child template:20:00–06:00 SLEEP,06:00–08:00 ANYTHING,08:00–10:00 LEARNING,
10:00–12:00 PLAY,12:00–14:00 ANYTHING,14:00–16:00 PLAY,16:00–18:00 LEARNING,
18:00–20:00 SOCIAL. Sleep exits at rest>=9000 into ANYTHING; emergencies interrupt
using existing priority order. Adult and elder default, night and flexible
schedules are unchanged. No age forces an elder into a teacher/caregiver role.
Learning and play are nonproductive personal activities. They consume no recipe
inputs, create no output/inventory, award no production XP and never satisfy a
productive-work counter. Fixed stages mean learning never promises an adulthood
transition. While safely active, play restores purpose320/hour; learning restores
purpose400/hour. These replace useful-labor purpose restoration, not stack with it.
Paired social restoration follows the existing1200/hour and one shared-meal200.

Daily care is a nonproductive paired personal service, separate from medical
HEAL and rescue HAUL jobs. Care grants the receiver's care restoration and paired
social restoration to both; caregiver purpose restoration is320/hour. It awards
no productive XP, uses no tools/materials, and creates no ordinary goods. A
caregiver can serve one child and a child can receive one caregiver at a time.
Travel earns neither care nor social/purpose restoration. A provider must be a
living conscious ADULT or ELDER, not in danger, not carrying a rescue patient,
not committed to another service, and must have reachable legal contact. Provider
hunger>1500, rest>500 and child health>15 are required; incapacity uses medical
care. Personal emergencies and rescue interrupt immediately. Safe productive
work may finish its existing at-most30WU segment before ordinary care begins.

A service runs until the first of care>=9000, child/provider interruption,
contact invalidation or 750 ticks of actual paired service. The 750-tick limit
is a turn-taking bound, not a completion bonus. Partial restoration persists;
no all-or-nothing payout can be duplicated by cancellation/reload. Reselect on
the next normal30tick staggered selection boundary. Critical care uses urgency1;
ordinary care uses urgency3, behind any ready priority0 rescue. Provider willingness
is a saved boolean defaulttrue for ADULT/ELDER, falseforCHILD. Turning it off ends
ordinary service at the next safe boundary and never disables existing medical
rescue policy. No gender field is consulted.

Selection first orders children by (critical before ordinary, care ascending,
persistent_id ascending). A provider is chosen from declared willing caregivers,
then willing adult/elder members of the household, then willing community
providers. Within each tier sort (paired-care ticks served today ascending,
provider persistent_id ascending). Availability and a valid reachable contact are
preconditions; a blocked named caregiver does not prevent fallback. No provider
may be selected twice in the same pass. Daily totals reset at midnight before
new service selection; days and partial service survive save/load. If there is
no qualified provider or route, retain the child's need and a specific warning;
never teleport, ignore a prohibition, grant remote care or remove the child.

## Household lifecycle and admission boundary

A resident belongs to zero or one live household. Maximum256 live household rows;
maximum8 living members per household, including children. These are game grouping
bounds, not biological claims. Up to two named preferred caregivers per child,
ordered by persistent ID for canonical storage. Named preferences are not exclusive
custody: community fallback still operates. A preference may name a living adult
or elder outside the household. Death/departure clears only invalid live service
links; historical family/identity records remain in the chronicle. Removing one
member never deletes surviving members or a child's other support links. Reclaim
an empty household row only after the lifecycle commit has recorded history.

A candidate household is one acceptance unit of1..8 members. Selection, refusal,
expiry, bed/capacity/food checks and admission apply to the whole unit; UI cannot
silently truncate it to fit. Candidate count remains a maximum of8 people/event,
not8households. Each scenario AdmissionProfile must explicitly author a finite
household template sequence and species/stage/member/caregiver rows; absent data
refuses family-enabled admission instead of inventing a family from surnames.
Existing adult-singleton rotation and the lone rat exception remain unchanged
for the current Refuge profile. A future family-enabled profile needs a versioned
scenario/admission amendment, exact template expansion algorithm and identity.

Preflight the complete unit's resident/directory/household/gear/container/bed
capacity, stage catalogs, qualified arrival contacts, legal routes and resulting
four-day ready-food reserve before any allocator or bed mutation. The exception
food override does not bypass capacity, beds or arrival safety. Commit all identities,
beds, needs, household/preference records, child warning state and candidate
retirement together. No partial household, duplicate tool, default child adult-XP
or half-cleared petition survives refusal or fault recovery.

Children do not independently execute the adult mood-departure rule. Their low
mood is still visible. Adult/elder departures keep their own warnings and require
an explicit family-separation transaction before final map exit; they cannot
silently transport another member or strand an already carried child. The exact
family departure/consent rule remains an unresolved authoring item below. This
blocks lifecycle integration, not the coefficient and store contracts' review.

## Storage and serialization design obligations

One new bounded household/dependent owner composes with Residents and Needs;
no duplicate health, life-stage, global identity allocator or inventory store.
Households need a reusable row generation, monotonic household ID, live member
count and explicit membership refs. Dependents need care/remainder, preferred
caregiver IDs, active provider/patient generation refs, eligibility/warning latches,
service progress and daily provider fair-share totals. Purely derived roster
labels, forecast text and sorted scratch are not additional authoritative copies.

Exact per-column types, canonical unused values, maximums, schema/section ownership,
allocator terminal behavior, cross-reference validation, capture/restore atomicity,
command wire formats and runtime/snapshot peak bytes are still to be authored.
Do not add arrays to the memory ledger or registry until that complete table is
independently reviewed. The existing affinity store can be designed independently
once household/affinity separation above is accepted; no degree cap expansion is
required to preserve a child's care network.

## Interface and player evidence

Roster and immigration review show life stage, household members, preferred and
current caregiver, care value/trend, unavailable-provider/route cause, valid bed,
food demand and whether a whole household fits. Use text/icon severity as well as
color. Forecast child intake with the exact above coefficient; count every person
for beds, population and total mood. A visible helping animation must be labelled
nonproductive and cannot call work or inventory commits.

Child survival warnings reuse actual health/starvation/cold/air/recovery thresholds
and give a reachable rescue action when one exists. The UI must also warn that a
profile/contact is unqualified. No graphic injury/death presentation, surprise
mortality quota or fictitious invulnerability. A blocked rescue remains a shown
cause. Native Mac review must demonstrate the care selection/interruption,
blocked-route warning, family admission refusal and caregiver-loss recovery flows.
Headless counters cannot substitute for those captures.

## Review and remaining closure

This draft closes proposed coefficient and routine choices, not all PC-04 gates.
Required next revisions before full execution approval:

1. A finite illness model with causal exposures, exact thresholds/rates, recovery,
   warnings and no overlapping health integration; reconcile the existing GDD's
   illness promise without adding an unbounded disease simulation.
2. Exact departure/separation behavior and grief/history ownership, including
   last caregiver loss and no capable adult remaining.
3. Complete packed schema, allocator bounds, wire/command versions, memory peak,
   load-barrier behavior and bounded owner API contracts.
4. Concrete finite family candidate templates and admission expansion in PC-03;
   preserve original Refuge and rat petition until a specifically authored revision.
5. Stage-qualified geometry/rig/bed/contact evidence and movement profile producer.
6. Independent review, exact arithmetic fixtures, negative/fault tests, task graph
   and owning-spec amendments. No task may self-approve from this draft alone.

Required tests include all3stages×3sizes×2seasons, integer daily consumption and
remainder continuation, care thresholds and service interruption without duplicate
benefits, fairness ties/midnight reset, named-provider loss and community fallback,
child no-output/no-production-XP, elder equality without fallback, stale refs,
whole-household cap/bed/food refusal without mutations, last provider absence,
hostile save cross-links and actual mixed-stage world continuation. Fixed-stage
and no-aging invariants must hold across an arbitrary number of scenario years.
