# PC-04 lifecycle, illness and command closure draft

FAMILY-LIFE-R01 · version2 draft · 2026-09-19 · Astra. Not active rules.
This companion supplies proposed resolutions for the remaining gameplay choices;
independent review and owning-spec amendments are required before activation.

## Finite illness model

First-release illness is a noncontagious exposure illness, `CHILL`. This is a
fictional survival mechanic, not a medical model. No epidemic graph, random
mortality, aging, arbitrary disease quota or hidden resistance statistic is added.
The existing aggregate Injury store owns it; health remains solely in Needs.
Append protected InjuryKind CHILL=6, retain NONE..EXHAUSTION0..5 and COUNT=7.
Explicit ADULT/CHILD/ELDER thresholds and effects are identical here, selected
through validated stage records. No unqualified stage inherits a default row.

In ARCH-SYS-017 CareHealth of tick k, after movement incidents, a living
resident whose cold_milli_hours committed by tick k's Needs integration is>=4000
and chill_episode=0 receives one CHILL severity1 incident,
immediatehealthloss0. Set chill_episode=1 only after successful incident commit.
Its untreated drain first enters the existing health sample in tick k+1;
there is no retroactive health resampling or second health integration. Existing severity merge rules remain exact: worse severity replaces; equal
severity retains the lower kindID; untreated time and paid care remain; aggregate
untreated drain is1/hour or4/hour once, never one drain per condition. Thus another
injury can be the displayed primary kind while chill onset is retained in history.
Cold's existing3/hour health drain is a separate causal exposure term and remains.
There is no additional independent illness health clock or per-illness rate.

A successfully treated aggregate clears CHILL under the ordinary herb1000+
cloth500milliU /60000mWU /+10health contract. Conscious-last-resident self-treatment
remains120000mWU. Nonproductive personal self-care remains available to a last
conscious child with reachable supplies and qualified safe contact; this is not
an ordinary productive job and never awards XP. Children never rescue another
resident or become productive HEAL workers. Incapacity cannot self-rescue.

The episode latch rearms only when cold_milli_hours<=1000 and no active CHILL
aggregate remains. Sheltering stops cold damage immediately by existing rules,
but does not magically complete treatment. Treatment while still deeply exposed
cannot create repeated same-tick CHILL incidents. Existing higher-severity injury
may suppress the primary CHILL label; incident history records the actual onset.
The latch is B8[512], initial/absent0, valid0/1, owned by Injury; +512livebytes,
+512snapshotbytes, and must be in its owner schema and canonical image.

All hazard incident producers use the same existing per-resident monotonic ordinal
contract. The CareHealth coordinator reads the last accepted ordinal, checked-adds1
and submits in fixed order: committed movement incidents first in their established
order, then CHILL onset, then treatment. I64_MAX exhaustion refuses the next event
and holds publication with an explicit invariant error; it never resets the cursor
or drops an injury. This ordering and publication response require joint hazard/
CareHealth review before implementation. Treatment does not reset last ordinal.

Warnings: exposure WARNING atcold>=3000, clearbelow2000; CHILL_UNTREATED is active exactly when chill_episode=1 and an active aggregate
injury remains: WARNING, or CRITICAL at health<=15. This intentionally describes
aggregate medical need after chill onset even when FALL/CUT wins the primary kind.
Successful aggregate treatment clears that notice immediately; the retained onset
latch alone cannot keep the notice active. Existing hunger<=1500/0, health<=15/0, airless and
fall-recovery alerts remain. Dedup key=(code,residentpersistentID), not a household
surrogate. Code names are `COLD_ILLNESS_RISK`, `CHILL_UNTREATED`, `CARE_LOW`,
`CARE_CRITICAL`, `CARE_PROVIDER_UNAVAILABLE`, `CARE_ROUTE_UNAVAILABLE` and
`LAST_CAREGIVER_LEAVING`, `CARE_NO_WILLING_PROVIDER`, `CARE_DEFERRED_MEDICAL`
and `CARE_DEFERRED_SLEEP`; severities use existing INFO0/ADVISORY1/WARNING2/CRITICAL3.
The two CARE_DEFERRED codes are INFO and clear when their sleep/medical
exclusion clears. CARE_NO_WILLING_PROVIDER uses the child's WARNING/CRITICAL
latch and clears when service starts, eligibility clears or that cause changes.
Care low/critical thresholds and hysteresis remain in the main draft. Notice data
is derived from authoritative conditions; dismissing a notice never changes care,
health, latches or eligibility. Non-graphic words/icons show causes and rescue/
shelter/treatment actions with actual prerequisites. No fallback teleport.

## Separation, death and departure

Household membership is a declared living arrangement, not a custody or marriage
simulation. Ordinary mood departure applies only to ADULT and ELDER: warning after
two low-mood midnights, intent afterthird, clearing at mood>=3500, and incapacity
blocks exit exactly as the GDD states. A child never receives independent mood
exit intent. No resident's departure automatically moves any other resident.

At departure warning, show affected children and remaining preferred, household
and community providers. For this warning only, a possible provider is a living stage-qualified
ADULT/ELDER with willingness on and no departure intent; instantaneous hunger,
rest, route and current-job gates are excluded. If removing the warned resident
leaves zero such providers, show LAST_CAREGIVER_LEAVING as CRITICAL with the existing two-
midnight warning horizon; this warning does not secretly cancel the adult's intent.
At final lawful map-exit commit, remove only the departing adult/elder, retire that
member's household ref, preserve the household for all survivors, clear active
service involving that resident, remove its live preferred-caregiver references,
and run the ordinary deterministic fallback on the next selection pass. Persist
chronicle departure/separation history before releasing the ID/reference. An
already carried patient must be safely handed off/setdown by the existing rescue
rules before a rescuer can complete departure. No patient vanishes at map exit.

Death uses the same surviving-network cleanup after needs declareshealth0 and
before progression observes the population. Death/inventory/bed/job releases and
burial retain their existing rules. If all named caregivers die, community fallback
remains. If no capable provider remains, the children stay simulated with visible
critical unmet-care/health warnings; existing food and survival consequences
continue. Do not create a phantom adult, despawn an orphan, freeze its needs or
trigger immediate defeat while living residents remain. Relief and admitting new
residents are separate owned systems, not free caregiver generation.

For grief, reuse existing values rather than invent a family buff: loss of a named
caregiver or household member uses friend_died(-1800,72hours); other deaths use
actual friendship to choose friend_died versus stranger_died(-300,24hours). One
loss produces at most one grief memory per living observer/sourceID, selected by
strongest applicable category, not stacked kinship+friendship. Same-kind/source
refresh and8-entry eviction remain inherited. Household departure adds a chronicle
separation record and changes care availability, but no invented death memory or
numeric departure-grief effect. Ordinary care adds paired contact under existing
social rules; REQ-SET-036's +8care event is reserved for completed medical treatment/
rescue, not each turn of daily companionship. No repeated1hour affinity payout.

## Versioned player commands and schedule identities

Keep all24economic CommandKind numbers unchanged. Extend SET_POLICY's explicit
selector domain:0foragequota/1forageenabled unchanged;2CARE_WILLING;3CARE_PREFERRED.
This versioned extension changes the rules/catalog fingerprint on activation;
files and queued commands with incompatible fingerprints refuse, never migrate
by interpreting previously invalid values.

- CARE_WILLING: targetvalidlivingADULT/ELDER, arg0=2, arg1=0or1, flags/payloadempty
  as ordinary scalar policy. Child targets refuse. Save willingness, terminate
  ordinary care at the safe boundary if disabled; never disable medical rescue.
- CARE_PREFERRED: targetvalidlivingCHILD, arg0=3, arg1=0, exactly16payloadbytes:
  two(slot:i32,generation:u32)refsLE. Null(-1,0) means unused tail. Nonnullrefs must
  be distinct livingADULT/ELDER, resolve to increasing persistentIDs, and cannot
  refer to a differentworld or invalidgeneration. Store resolved persistentIDs.
  Empty preferences are legal and preserve household/community fallback.

Both validate target, mode, payloadlength/domain, complete references and all
store capacity before any mutation; duplicate/noop follows existing command result
semantics. Malformed commands leave family state and counters unchanged except
existing diagnostic rejection accounting. Queue/dispatch admission sequence and
load-barrier handling remain the ordinary economic path. No direct UI storewrite.

Append protected Activity PLAY=4, LEARNING=5; preserveSLEEP0/ANYTHING1/WORK2/SOCIAL3.
Add ScheduleTemplate key `young_day` to the ASCII-compiled domain, after existing
`default`, `flexible`, `night_shift`, so currenttemplateIDs0/1/2stay andnewID3.
Its24hours are exactly the main draft's child template. CHILD schedule edits permit
SLEEP/ANYTHING/SOCIAL/PLAY/LEARNING and refuse WORK beforeanyrowchange; adult/elder
may choose teaching/playing/social time through their ordinary personal service
choices, with no production XP. A stage-qualified display tells the player these
stages stay fixed. No schedule command changes life stage.

## Family profile grammar

Family-enabled admission profiles must declare the finite1..8member units they
use, with every member's species/stage/initialstate and preferred-caregiver member
indices. Each event contributes at most8people in total. The whole admission unit
is accepted/refused/expired, never truncated. A family profile identity includes
all these fields, the selection algorithm and this ruleversion. Invalid member
index, duplicate slot, unsupportedstage/profile, missinggeometry or overfullunit
refuses before materializing a candidate.

The original Refuge normal adult-singleton rotation and one rat petition remain
unchanged under their current profile. PC-03 owns a named family-enabled scenario
and its complete finite unit sequence; no anonymous generic household is inserted
into the old fixture. Family capability cannot be declared release-complete until
such a profile is authored, initialized, saved and played through admission.

## Scope and required review

These are proposed exact choices. Confirm arithmetic, safe ordering, memory/
serialization, warning timing, adult behavior preservation where not explicitly
amended, commandcounter semantics and independent player-flow evidence. In
particular, compare CHILL sequencing with the actual Needs health tick API before
writing code; no doubleintegration or hidden same-tick death reversal is allowed.
This file does not claim that the multi-owner lifecycle transaction, incident
producer, notice owner, memory store or chronicle exists.

## Version2 owner and phase clarifications

All of CHILL=6, PLAY=4/LEARNING=5, young_day, the SET_POLICY selectors and
Injury.chill_episode enter one versioned family rules/catalog fingerprint. They
require explicit GDD protected-enum and schedule-template amendments. Existing
ordinal values stay fixed. Injury owner schema1 advances to2 when the bit is
implemented; its actual baseline schema must be checked at dispatch, never
overwrite an intervening revision. New family owner starts at1. Needs, Residents
and Schedule owner version changes follow their exact changed canonical columns
or domains together with the rules fingerprint; list actual versions in the
implementation packet against its base. Pre-family files/queuedcommands refuse
incompatible rules/owner schemas; no default-child migration is allowed.

CHILL onset consumes a strictly greater per-resident incident ordinal even though
its immediate loss is0. The existing Injury.last_incident_ordinal_of() accessor
and persisted _last_incident_ordinal column are the source; verify their current
signature at dispatch. Treating any aggregate after an onset clears that medical
need as one aggregate treatment, not a per-kind cure list. The coordinator's
I64_MAX handling and publish-hold response require fault-test evidence before
activation; no claim is made that the current coordinator already supplies it.
