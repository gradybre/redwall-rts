# 0884 — A tunnel is transport only until an outlet is fitted and set: Shut, Drain or Feed
Date: 2026-10-01 · Status: Accepted

Brendan approved the review's **ECO-006** ("Explicit irrigation and drainage", REVIEW.md 2315): "Separate deliberate
water-service fittings from the existence of a travel tunnel: a drain outlet, a shallow feeder channel and a closable
garden inlet. Use a small discrete wet/normal/dry model first. Show affected beds and preserve a transport-only
choice. Give storage/route projects no automatic irrigation promise merely because they share a graph." Decision 0441
(water part B2) already built the **closable inlet and feeder channel** -- the weir's sluice and the garden leat, three
discrete services over three beds with an affected-bed preview -- and the review's tension note (bounded, discrete
service zones; no hydrology) holds. What remained was the tunnels: since decision 0196 a finished tunnel under a bed
drained it, and one carrying the stream's water irrigated it, merely by being there. Numbering: see 0881.

## Decision

- **A tunnel is transport only.** `farm_tunnels.gd` still records the facts -- a dry tunnel under a bed, one carrying
  water under it -- but they do nothing to the bed by themselves (`farm_sim.gd` TUNNEL OUTLETS).
- **Fit outlet** is a job (`farm_jobs.gd` KIND_FIT_OUTLET: walk to the bed, 6 WU of spade-work, a demo value equal to
  a ditch's), offered only for a laid bed with a finished tunnel under it and no outlet yet; its action card is the
  crew's own `decide`, as every verb's. It is fitted **Shut**.
- A fitted outlet has three discrete settings, changed at once from the bed panel (a board moved in its mouth, no
  job): **Shut** (transport only), **Drain** (the bed sheds into a *dry* tunnel under it: decision 0196's drainage,
  up to 1500 a day toward its band's low side), **Feed** (a tunnel carrying the stream's water pulls the bed toward
  its band's middle, up to 1500 a day). Drain over a wet tunnel drains nothing and Feed over a dry one feeds nothing;
  the panel says which. The leat still comes first (0441): a bed the leat waters is not drained that day.
- **The bed panel's Tunnel outlet box** (`farm_outlet_box.gd`) shows what runs under the bed, Fit outlet, and the
  three settings, each tooltip its effect on this bed -- the affected-bed preview for a one-bed fitting -- the
  setting now pressed.
- Job kinds after Drain shift by one: KIND_FIT_OUTLET is 9, KIND_COUNT 10, KIND_DELIVER 10, KIND_RETURN_EARTH 11
  (every reader uses the names).

## Why

The review's player problem is "a transport project can change a garden's water condition without the player feeling
they designed or controlled the service." A per-bed outlet makes the service a choice, keeps a transport-only tunnel
the default, and needs no hydrology: the effects are the existing moisture rules.

## Brendan's ruling (2026-10-01)

The tunnel-outlet defaults are **approved as built** (proposals 1–2 below). Recorded at the batch 7 integration (decision 0902); nothing changed in behaviour.

## Proposals for Brendan

1. **Fitting is 6 WU and setting is instant**, as the sluice's order is (0441). **Recommendation:** keep.
2. **Existing play changes**: a tunnel dug under a wet bed no longer drains it until an outlet is fitted and set to
   Drain (the first spring's threats text says "Drain them, run a tunnel under them and fit a drain outlet, or raise
   them"). **Recommendation:** keep -- it is what the review asked.
