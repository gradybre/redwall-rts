# 1713 — Each water keeps a seasonal record, and intensive harvest shows its recovery first
Date: 2026-10-07 · Status: Accepted (proposals P4, P8 and P9 approved as built, 2026-10-07)

Part of the fishing revamp (#49); the lane's record, gates and review are [1711](1711-the-fishing-rolls-hazards-and-rare-catches-on-the-fishing-stream.md).

## Decision

1. **A record per water** (review ECO-025: "recent landed catch, recovery trend, current commitment and expected
   return to the chosen safe band"). It is kept in `fishery_stewardship.gd` and shown under the gear in the Water
   panel's Fishing section. There are two waters: the stream (the river habitat; its run and ford are one stock, §5.1)
   and the pond (the lake). Each record has:
   - **Landed:** the catch completed cycles took over the last 12 days, as a ring of day totals.
   - **Stock and today's change:** every species summed, against the stock at the day's start.
   - **Places in use:** the effort slots taken, of §5.4's river 4 and lake 6.
   - **The intensive policy's state.**
   - **Restocking:** for each species in REQ-SET-048's latch, the days until midnight recovery alone lifts it
     **strictly above 40%**, the latch's own exit.
2. **The prediction** replays §5.4's midnight day by day on the real calendar, with no fishing:
   `P' = min(K, P + floor(r·P·(K−P)/(1000·K)) + floor(K/200))`, plus salmon's 300 U on autumn day 1. It uses
   fishing.gd's constants and does not copy its arithmetic loosely: the tests check it against the store's
   `daily_recovery_milli` for all six inland stocks and against five real midnights.
3. **Intensive harvest** (REQ-SET-049) uses fishing.gd's one flag per habitat, set through `fishing_driver.gd
   set_intensive`.
   - The panel's **Intensive: off / on** acts on the chosen water.
   - Its action card is shown before it is pressed. It names the 10% hard floor and, for each species, the days from
     that floor back above 40%.
   - REQ-SET-047's closure rule is the store's own: the floor stays 30% during a closure window.
   - The policy is never reset automatically (READY_06 §5).

## PROPOSALS (Brendan's ruling needed)

- **P4. "Predicted recovery time" means the days from the 10% floor back strictly above 40%, with no fishing.** The
  core computes none ("§5.4 states no horizon for one"). 40% is REQ-SET-048's own exit, so this is the only GDD-anchored
  band. Options: (a) as built; (b) back to the 80% starting stock; (c) back to the 30% default floor. **Recommendation:
  (a).**
- **P8. The record keeps 12 days** (one §4.3 season). PROVISIONAL; source: this record.
- **P9. No automatic end for an intensive order.** The review asks for "an explicit end condition", but READY_06 §5
  rules that the player's intensive choice "is never reset automatically". Options: (a) no end condition, as built;
  (b) a player-set end, such as "until the season ends", recorded as the player's own choice and still never a
  fallback. **Recommendation: (a)**; (b) needs a ruling that it does not breach READY_06 §5.

## Why

- No new stock simulation: the record reads the store. The prediction is the store's formula, and a test pins it to
  the store.
- The 40% horizon answers ECO-025's "expected return to the chosen safe band" and REQ-SET-049's "predicted recovery
  time" with one number the GDD already defines.

## Consequences

- `fishery.gd update` calls `steward.follow(driver)`, and each completed cycle calls `steward.record`.
- Changing §5.4's recovery or recruitment changes the prediction automatically. The tests fail if the two ever diverge.

## Source

GDD §5.4 (the recovery formula, quotas, floors, REQ-SET-047–049), READY_06 §5 (decisions 0027/0036); review ECO-025
(decision 0493 row W).

## Brendan's rulings (2026-10-07)

Relayed by the coordinator on PR #236 (no verbatim wording was passed on): P4, P8 and P9 **approved as built, the
values provisional** -- recovery is shown back strictly above 40% (option (a)); the record keeps 12 days
(PROVISIONAL); intensive harvest has no automatic end (option (a)).
