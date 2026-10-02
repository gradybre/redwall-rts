# 0993 — The village keeps one cloth, and every claimant reserves it
Date: 2026-10-02 · Status: Accepted

Numbered from the range 0993–0999 assigned to the fixes of the independent review of 2026-10-02
(`docs/reviews/2026-10-02-codex-review.md` on branch `codex/review-2026-10-02`, PR #216). This record answers its **R01**.

## The finding

Batch 7 created the starting cloth twice: the hall's projects kept their own `cloth_milli` of 24 U
(`hall_projects.gd`, decision 0771) and the care state kept another 24 U (`care_state.gd`, decisions 0622/0623). Building
the infirmary (12 U) and upgrading the hall (8 U) left 28 U between the two books instead of 4 U of one opening stock.
Decision 0902 reconciled the care shelf against the infirmary building but missed the hall's copy.

## The ruling

**Brendan, 2026-10-02:** "R01 (high): one shared village cloth store. The hall's tier-2 upgrade, the infirmary building
and treatments all reserve and debit that one store, holding the GDD §5.1 opening 24 U. Add an integration conservation
test covering both buildings, a treatment, cancellation and loads in transit."

## Decision

- **The store** is the village stores (`demo/tunnel/tunnel_stores.gd`, "the demo's one stores"): `cloth_milli_u`, opening
  at `START_CLOTH_MILLI_U` = 24000 (GDD §5.1), and one reservation row per claimant -- `CLOTH_HALL`, `CLOTH_INFIRMARY`,
  `CLOTH_TREATMENT`. `cloth_free()` is the stock less every claim; `reserve_cloth` reserves only free cloth;
  `release_cloth` gives back only what that claimant held; `take_cloth` takes free cloth all or nothing; `add_cloth`
  returns a load or a refund. A lift is a release followed by a take, so the stock falls only when cloth is lifted
  (REQ-SET-124).
- **The hall** (`hall_projects.gd`): a carrier setting off for cloth reserves it under the hall's claim; `unreserve`,
  `cancel` and finishing (`_clear_cells`) give back what the project still holds; `in_stock(cloth)` is the stores' free
  cloth. `cloth_milli` remains as a read/write view of the stores' stock, so the panel and existing tests read the one
  figure.
- **The infirmary building** (`infirmary_project.gd`): the same, under the infirmary's claim. Its constructor no longer
  takes the care state; the `cloth_held` callable and `cloth_committed()` (the old two-ledger reconciliation of 0902's
  M1) are gone -- the claims replace them.
- **Treatments** (`care_state.gd`, `care_desk.gd`): a treatment reserves its 0.5 U (REQ-SET-173) when its healer is sent
  (`claim_cloth`); the reservation is lifted at work start (`pay_treatment`, §5.3: inputs consumed at work start) or
  given back when the healer stops unpaid (`release_cloth`, from `_on_treat_ended` and a refused order). `affords()` now
  counts only herb for the healers already sent: their cloth is already reserved. `treatment_refusal` says NO_CLOTH only
  when the patient holds no claim and the free cloth is short. `use_cloth(stores)` binds the care state to the village
  stores (`infirmary_building.gd configure` binds it); unbound -- a unit test -- it keeps private stores with the same
  opening 24 U. `cloth_milli` is again a view of the bound stores' stock.
- The care section's supplies line now says the cloth is in the village stores.

## Tests

`test_demo_village_cloth.gd` (new): the review's reproduction (24 − 12 − 8 = 4 U, before and after building), a
reservation never free to another claimant (hall, infirmary and a treatment on 9 U), a treatment with both buildings'
cloth in transit, a load carried back and a cancel with a load in arms (conserved at every step: stock + in arms +
delivered + built in + paid treatments = 24 U, and claims never exceed the stock), a cancel after work began (80%,
REQ-SET-126) giving back reservations, an unpaid treatment's reservation given back, and the store API's boundaries.
`test_demo_care_desk.gd`: a healer sent reserves the cloth and a healer stood down gives it back.
`test_demo_infirmary_building.gd`: the old two-ledger test replaced by the shared-claims one.

## Consequences

- Anything new that consumes cloth must reserve it in the village stores under a claimant row (add one) -- never keep
  its own copy.
- The physical pick-up spots are unchanged (the hall's carriers at the stockpile, the infirmary's at the care shelf);
  only the books are one. No PROPOSAL: the ruling settles every choice here.

## Source

Brendan's ruling of 2026-10-02 on R01; GDD §5.1 (initial inventory: cloth 24 U), §5.3 (inputs at work start), §5.9 /
REQ-SET-136 (the hall's tier-2 package, cloth 8), §5.9's Infirmary row (cloth 12), REQ-SET-124/126, REQ-SET-173.
