# Open questions for Brendan

Everything here waits on Brendan unless marked **CLOSED** (with where its ruling is recorded). Each recommendation is the
handoff's, not his. Ask them in
groups (README §4): the settlement group before HAUL-H3 or DEMO-D7 starts, and each demo group before its packet
starts. When he answers, record the ruling verbatim in the lane's decision record (and a `DEC-nnn` for a creative or
policy ruling), then delete the question from this file.

IDs: **Q-F** foundations and housekeeping, **Q-S** settlement, **Q-D** demo. The packet that needs each answer is in
brackets.

## Foundations and housekeeping

**Q-F1. The main checkout's uncommitted changes.** `/Users/brendan/Developer/redwall-rts` is on an old branch
(`docs/executor-followup-rulings`, merged 2026-09-12) with 361 changed paths, mostly staged additions, far from
master. This session did not establish where they came from. [STATUS §3; WIN-PERF]
- (a) Leave them untouched; all work and builds use fresh worktrees of `origin/master`.
- (b) Look through them together, then commit what is wanted onto a branch.
- (c) Discard them and put the checkout on master.

Recommendation: (a) now, then (b) when you have time. Never (c) without looking.

**Q-F2. Hardware for the Windows qualification.** REQ-SET-163's floor is a Ryzen 5 3600 / GTX 1660 Super 6 GB /
16 GB. Your known Windows PC has a 5090 (`docs/validation/WINDOWS_START.md`), which cannot certify the floor. [WIN-PERF]
- (a) Find a floor-class machine before claiming support at 256 residents.
- (b) Measure on your PC now as USER-PC evidence only, and certify the floor later.
- (c) Cap the claim below 256 residents until a floor machine is available.

Recommendation: (b) now, (a) before any release claim.

**Q-F3. Recording the feature lists.** Your 2026-10-01 feature approvals (#9, #11, #18, #19, #23, #24, #31, #33, #34,
#37, #49, #51, #54, #55, #56, #59), the not-chosen lists and "crowd later" were recorded only in the coordinator's
tracker; RULINGS.md is now their first repository record. [all of BACKLOG Part 4]
- (a) Add one `DEC-nnn` to `docs/setting_decisions.md` listing them, quoting RULINGS.md.
- (b) Leave RULINGS.md as the record; each lane quotes it.

Recommendation: (a), so the approvals sit in the authority document.

## Settlement

**Q-S1. Command kinds for demolition's player paths.** ARCH-CMD-003 fixes 24 command kinds (asserted in
`command_dispatch.gd`). DEMOLISH exists (catalog id 6); REMOVE_FURNITURE, "evacuate, then demolish" and "cancel the
evacuation" do not. [DEMO-D7]
- (a) Carry them as payload flags on DEMOLISH; the frozen set and the save format stay as they are.
- (b) Amend ARCH-CMD-003 to add kinds.

Recommendation: (a).

**Q-S2. The boat installation contract.** Task 06.4 asks H7 for "a declared boat installation/owner contract" with no
`boat` item; no such contract was found (unverified). [HAUL-H7]
- (a) H7 drafts it (a boat is an installation owned by its building, with its gear lots) for your approval.
- (b) Leave boats out of 06.4 and give them to a later task.

Recommendation: (a).

**Q-S3. Who evacuates residents before a demolition.** REQ-SET-127 needs residents out first; no slice owns it. [HAUL-H5,
DEMO-D7, DEMO-D9]
- (a) A small slice, "D7b", after HAUL-H5: occupants are moved out by the job system before the admit.
- (b) Inside HAUL-H5, with the goods evacuation.
- (c) Inside DEMO-D7, with the player's command.

Recommendation: (a), so each file keeps one writer.

**Q-S4. Saving the new state.** The haul admission record, the demolition admission record, the paid ledger, the
evacuation intent and store policy are all unsaved (classified UNRESOLVED); `CONSTRUCTION-SAVED-BINDINGS` has no
queue entry. [HAUL-H8, DEMO-D9]
- (a) Add a queue task now, scheduled after HAUL-H8.
- (b) Fold it into HAUL-H8.

Recommendation: (a): H8 is already large.

**Q-S5. When the pre-demolition quicksave is taken** for an "evacuate, then demolish" order (REQ-SET-158; 0537 left
it to D7). [DEMO-D7]
- (a) When the player places the order.
- (b) When the deferred admit fires, possibly hours later and at speed.

Recommendation: (a): the player is present and the save holds the state they decided from.

**Q-S6. The quicksave with no save system.** Production saving (the save orchestrator) is not finished, and the demo's
saving is deferred. [DEMO-D7]
- (a) D7 ships the dispatch, UI and notice; the quicksave is recorded as blocked on the save orchestrator
  (`SAVE-ORCHESTRATOR` in `work_queue.json`).
- (b) Hold all of D7 until saving exists.

Recommendation: (a).

## Demo

**Q-D1. The B key.** UI §5 binds B to the Build command (`open_build`); the demo's Dig tool also uses B. The new
Buildings panel needs a key. [BLD-PANEL]
- (a) B opens the Buildings panel; Dig moves to the panel or another key.
- (b) B stays Dig; the panel opens from the HUD's Build button only.

Recommendation: (a), which follows the UI spec.

**Q-D2. Cloth with no Workshop.** The GDD makes cloth at a Workshop (flax 4 → cloth 2), which needs iron 4; the demo has
no Workshop and no iron in its stores. [FLAX]
- (a) Build the Workshop in the demo (with Q-D3's answer for iron).
- (b) Make cloth at the workbench in the demo, as a recorded demo deviation.
- (c) Grow flax and make rope now; cloth waits.

Recommendation: (a) if Q-D3 is (a); otherwise (c).

**Q-D3. Iron and rope for the GDD's buildings.** The Apiary (rope 2), Dryer (rope 4), Preserver (iron 2), Brewery
(iron 2) and Workshop (iron 4) cannot be paid for: the demo's stores hold no iron or rope (only the gear locker's 4 U
rope and 2 U iron). The GDD's starting inventory includes iron 20 and rope 20. [HIVES, PRESERVE, BREW, FLAX]
- (a) Add the GDD's starting iron 20 and rope 20 to the demo's stores.
- (b) Make rope from flax first (FLAX) and use only the gear locker's iron.
- (c) Waive those costs in the demo.

Recommendation: (a): it follows the GDD's own opening.

**Q-D4. Unlocks with no milestones.** The demo evaluates no M1–M4 milestones, so "unlocks at M2" has no trigger.
[HIVES, PRESERVE, BREW and others]
- (a) Available from the start, as the Cellar building was (0612 P1).
- (b) Unlock on a demo goal.
- (c) Build milestone evaluation into the demo.

Recommendation: (a).

**Q-D5. Recipes the GDD does not have.** Jam, pickles, a plant-milk cheese, ale and cider have icons (0971) but no GDD
rows; DEC-007 leaves how drink and alcohol are depicted open; salt (for salt fish and pickles) needs a coast the demo
does not have. [PRESERVE, BREW]
- (a) Build only the GDD's rows now (dried fruit, rations, mead, the infusion); the icons wait.
- (b) Also draft the new recipes from the content library for your approval in one batch, as DEC-045 was.
- (c) Rule how drink is depicted (mead is "a feast ingredient only; no intoxication") before any ale or cider.

Recommendation: (a) now, with (b) and (c) asked together.

**Q-D6. The Cellar building's units.** It counts capacity at 500 g a unit (0612) while food is 250 g a unit; measures
P5 left this alone. [MEAS-2]
- (a) Leave it.
- (b) Count its capacity in food units (doubling what it holds).
- (c) Keep the mass and show capacity in baskets computed from it.

Recommendation: (c).

**Q-D7. Orchard remainders.** **CLOSED: ruled (a) by Brendan on 2026-10-07**, "Both, agent proposes numbers": a
sapling can be moved once, with a delay of some days; carts are a haul tool for harvest groups (decision 1721, which
built both and puts its numbers to him as proposals). Moving a sapling needs its own ruling (0673); harvest groups
have baskets but no carts (0674). [RG-Y]
- (a) Saplings can be moved once, with a delay of days; carts as a haul tool.
- (b) Neither.

Recommendation: ask for the delay and the cart's capacity if (a).

**Q-D8. The first year's calm (ECO-036)** leans on difficulty knobs from deferred group AF. [RG-AB]
- (a) Build seasonal suggestions and bounded risk (ECO-037, ECO-038) now; ECO-036 waits for AF.
- (b) Raise AF now.

Recommendation: (a).

**Q-D9. The mentoring rule change** (group AC's condition; SOC-005). The GDD's mentoring gives 100 XP an hour under its
friendship rules; the review proposes one lead and up to two apprentices, lessons costing 10–20% of crew time, and
experience only from supervised work. [RG-AC, SKILLS]
- (a) Adopt the review's model, with numbers to confirm (lesson cost, apprentices per lead).
- (b) Keep the GDD's model and show it visibly.

Recommendation: (a), as approved, with the lesson cost set at 15% unless you prefer otherwise.

**Q-D10. Children.** PC-04 keeps children inactive; group AD's child items wait on it. [RG-AD]
- (a) Keep them inactive; build the adult and elder parts.
- (b) Activate children, which needs PC-04's engineering gates 1–6.

Recommendation: (a).

**Q-D11. The hour of a called feast.** The GDD starts feasts at 18:00 (REQ-SET-103); the regatta feast is served at the
17:00 supper (kept, 2026-10-01). [FEAST]
- (a) Called feasts at 18:00, the regatta unchanged.
- (b) Every feast at the 17:00 supper.

Recommendation: (a), unless DAYPLAN moves supper.

**Q-D12. Arrivals.** Review items SOC-020 (admission), SOC-021 (visitors) and SOC-022 (a welcome period) were approved in
group AE, but "newcomers" was not chosen on 2026-10-01. [RG-AE, NEIGHBOURS]
- (a) Build none of them for now.
- (b) Build visitors only (they leave; nobody joins).

Recommendation: (a) until you say otherwise.

**Q-D13. Bridges: removal and the cap** (group AK; the one-line approval is the only specification). The demo has a
fixed pool of six bridges and no removal. [RG-AK]
- (a) Keep six; add removal that returns half the materials (as furniture does, DEC-043).
- (b) A different cap, or a limit by cost.

Recommendation: (a), confirming the return.

**Q-D14. Darkness and meal hours.** The demo applies no darkness penalty, so residents work outdoors in the dark in
winter; supper is at 17:00 against the GDD's SOCIAL 18–20. [DAYPLAN]
- (a) Apply the GDD's unlit outdoor work ×0.75 and its schedule hours.
- (b) Keep the demo's hours and no penalty.

Recommendation: (a), with candles from HIVES as the remedy.

**Q-D15. Lightning and fire.** **CLOSED: ruled (a) by Brendan on 2026-10-07** (decision 1632, P1, approved as built;
`RULINGS.md`). The GDD says release 1 has no structure fire or random disaster; the fire effect exists.
[WEATHER]
- (a) Lightning strikes trees or open ground only, never a building; no fire spreads.
- (b) Lightning may start a fire.

Recommendation: (a).

**Q-D16. What the water revamp (#54) covers.** Only its title survives. [WATER]
- (a) Seasonal water: river and pond ice with the shader, spring flow; plus ECO-040 diving surveys.
- (b) Something else you had in mind.

Recommendation: confirm (a) or describe (b).

**Q-D17. What river trade (#37) covers.** The GDD has no trade; LORE-T05 forbids claiming a trade route that does not
exist; DEC-004 is open; barter (SOC-042) is in deferred group V; "the trader" (#12) was not chosen. [TRADE]
- (a) Hold it until DEC-004 and group V are taken up.
- (b) A bounded form: river boats carry goods between the village's own landings only.

Recommendation: (a).

**Q-D18. Store-policy UI in the demo.** 1031 P7 forbids a store-policy UI until `ui_ux_controls.md` has UI-SET rows;
demo lanes have built demo UI without spec rows before. [ZONES]
- (a) The demo may build its own, recorded as a demo deviation.
- (b) Add the UI-SET rows first, then build.

Recommendation: (b) if the settlement UI will follow soon; otherwise (a).

**Q-D19. What exploration (#55) and neighbours (#56) cover.** The GDD is silent on both; neighbours as partners collide
with deferred group V and DEC-004. [EXPLORE, NEIGHBOURS]
- (a) Exploration: discoveries inside the map (dive surveys, warren finds, remembered places); neighbours wait.
- (b) Something else you had in mind.

Recommendation: confirm (a).

**Q-D20. Several feast forms (SOC-024).** 0438 recorded it as not adopted: the GDD's feast rules (including its 80%
rule) are used as written. [RG-AE]
- (a) Keep the GDD's rules.
- (b) Amend the GDD for feast forms with separate verdicts.

Recommendation: (a).

**Q-D21. A "coins" find.** Art pass 3 made a coins icon, but the village's economy has no currency. [DIG]
- (a) Coins are an old keepsake, a find for the chronicle, with no value.
- (b) No coins find.

Recommendation: (a).


## Added at the end of the lead session (2026-10-02)

**Q-P1. Kitchen serving rule (decision 1005).** "The cook serves what is in the pot when the meal is called"
was built literally. It feeds villages of 50–256, but supper at 9 residents went 8 → 7 and at 25 about 22 → 17
(breakfast is now fed instead). [PERF]
- (a) Keep the literal rule. Recommended.
- (b) Find a trigger that keeps 9 and 25 identical; two variants were tried and failed (see 1005).

**Q-F4. Woods mark colours (decision 1044).** The stump and young-tree colours were changed to pass the colour-blind
floors. [FOLLOW-UPS]
- (a) Keep the two new colours. Recommended.
- (b) Add a SPRING pigment to the woodland palette instead. Also: should the zone washes pass on their own?

**Q-F5. Water fitness (decision 1045).** A resident below health 70 or with an untreated injury never takes a rescue role. [FOLLOW-UPS]
- (a) Keep them off every rescue role (built). Recommended.
- (b) Only off roles that enter the water. Note HAZ-001's hunger > 3500 condition is not wired yet.

**Q-F6. Fishing hazard roll (decision 1046, not built).** [FOLLOW-UPS]
- Which crew member is hurt: (a) the helm, recommended; (b) a random crew member.
- Injury kind for net, trap and weir: (a) BITE, recommended; (b) CUT.
- Should the preview use the crew's group level?

**Q-F7. Grass speckle and gait scrape (decision 1049, not built).** The speckle needs a screenshot or camera
position from Brendan; the swing-foot scrape needs paid gait re-authoring (a credit request under decision 0961).
