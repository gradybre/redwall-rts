# 0961 — Paid generation is by request, and may be delegated within an approved cap

Date: 2026-10-01 · Status: Accepted (Brendan's rulings, 2026-10-01)

## Context

The UI art lock (ART-LOCK-001, `docs/design/ui_refinement/asset_generation_lock.md`) said
"Paid generation NOT APPROVED", which read as a standing block. The paid-asset process
(`docs/design/paid_asset_process.md`) also said a subagent can never call a paid tool,
because a subagent cannot obtain consent.

On 2026-10-01 Brendan approved an itemised art pass for the new foods, plants and props
(about 480 Meshy credits, from a balance of 1,213) and the coordinator delegated it to a
subagent with a hard cap of 520 credits, which the process did not allow. The subagent's
paid calls were paused while Brendan was asked.

## Decision

1. **Brendan:** "Make sure to change the art lock rules to request for paid generation, not
   block it altogether." Paid generation is now **by request**: present an itemised,
   costed list; proceed once he approves it. The lock's `paid_generation_authorized: false`
   now means "no standing approval", and a `paid_generation_policy` field says so.
2. **Brendan chose "Subagents may, within approved cap":** once he has approved an itemised
   list and a credit cap, the lead may hand those exact calls to a subagent. The subagent's
   brief names the approved items and the hard cap, checks the balance before and after each
   group, stops at the cap and reports. It never asks Brendan itself or widens the list.

## Changed

- `docs/design/ui_refinement/asset_generation_lock.md`: the header and the handoff paragraph.
- `docs/design/ui_refinement/README.md`: the lock summary.
- `docs/design/ui_refinement/asset_generation_lock.json`: new `paid_generation_policy`.
- `docs/design/paid_asset_process.md`: "The rule".
- `godot/demo/ui/woodland_ornament.gd`: a comment that cited the old block.

`asset_generation_lock_validation.json` and the 2026-09-20 evidence manifest are historical
records of their own runs and are left as they were.
