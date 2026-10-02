# 1045 — Hurt residents stay out of the water, and a patient is not drafted to a rescue

Date: 2026-10-02 · Status: Accepted (the "every role" reach is a PROPOSAL, below)

## The rule

HAZ-001 (`docs/underground_economy_hazard_amendment.md`):

> New deliberate entry to dangerous travel requires health >=70, hunger >3500,
> rest >=4000, no active untreated injury, known complete movement/profile/cargo
> contract and the resident's consent. Check again at edge entry, not just job
> issue. Retreat and rescue from an already occupied edge are not blocked by the
> failing entry test.

The same section counts SWIM_SURFACE and DIVE as dangerous. GDD §5.3 puts health
and rescue safety first in its eligibility order for any job ("Eligibility
order: health/rescue safety; activity permits work; …"). REQ-SET-172 bars an
untreated injury from hazardous work.

The demo already checked consent and rest (`swim_state.gd swim_refusal`). It did
not check health or injury. That was the infirmary review's M6 (decision 0622,
"Left as follow-ups"): a patient lying at its field-care spot could be drafted as
a rescuer and sent into the pond.

## Decision

- **`swim_rules.gd`**: `ENTRY_HEALTH = 70`, `REFUSE_HURT`, and
  `admits_health(health, untreated_injury)`.
- **`swim_state.gd`**:
  - `fitness`, a `(who) -> bool` hook, and `fit(who)`, which is true while the
    hook is unset, as in the suites that have no infirmary.
  - `swim_refusal` now refuses `REFUSE_HURT` after capability, load and consent,
    and before tiredness.
  - Every entry goes through `swim_refusal`: an ordered swim or dive, a route's
    swim link, and both bank rechecks (the crossings' and the rescuer's
    step-down). So the check happens again at the edge, as HAZ-001 asks.
- **`rescue.gd may_go`**: a resident that is not `fit` is not sent to any
  rescue role. That covers swimmer, diver, a line thrown from the bank, and boat
  crew.
- **`demo_care.gd`**:
  - `fitness_in(state, i)`: health ≥ 70 and no injury. Every injury is
    untreated until its treatment clears it. A resident without a row passes.
  - `configure` sets `swim.fitness = fit_for_water`. This is the only wiring.
    It uses a method Callable, so there is no reference cycle, and
    `demo_village.gd` is untouched.
- **Words** (`waterplay_text.gd`): "X isn't well enough to swim (it needs health
  70 and no untreated injury)", and at the bank, "not well enough (…)".

Someone already in the water is never pulled out. `swim_refusal` is asked only
at entry, so retreat, finishing a crossing, and a rescue already under way in
the water are not blocked, as HAZ-001 says.

## Not done

HAZ-001's **hunger > 3500** is not wired into the water's entry test. Its rest
≥ 4000 already is, as the water's stamina (`admits_swim`). Hunger lives in the
kitchen's nourishment. The brief named health and injury, so hunger is left as a
follow-up. It would be one more term in `fitness_in`.

## PROPOSAL for Brendan

HAZ-001 covers only *dangerous* travel. Throwing a line from the bank and crewing
the rescue boat are not listed as dangerous. This change keeps a patient off
those roles too. The reason is §5.3's eligibility order, health first and
activity permitting work, and the fact that the demo's patients lie in bed or at
a field spot until they are treated and back to 70 (decision 0622 P4).

Options:

1. Every rescue role (recommended; built).
2. Only the roles that enter the water. A patient could then still throw a line.

## Verification

- `test_demo_water_play.gd`:
  - `test_entry_needs_health_seventy_and_no_untreated_injury` (boundaries at
    69, 70 and hurt);
  - `test_a_hurt_or_weak_swimmer_is_refused_the_water` (the order of refusals
    and the unset hook);
  - `test_a_patient_is_not_drafted_as_a_rescuer` (every role, a fit swimmer and
    a fit thrower still go, and the words);
  - `test_the_infirmary_answers_the_water_s_fitness`.
- `demo_care_live.gd` at 1280x720 and 1920x1080 checks the real village's wiring:
  the bitten fisher is not fit, and is fit again once treated. The harness's
  minimum check count is raised from 31 to 33. `LIVE-SUMMARY 37 0` at both sizes.
