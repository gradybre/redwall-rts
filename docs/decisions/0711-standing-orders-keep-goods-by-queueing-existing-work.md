# 0711 — Standing orders keep goods by queueing the work the demo already has
Date: 2026-10-01 · Status: Accepted (feature #38, approved by Brendan 2026-10-01); its five proposals ruled by Brendan 2026-10-01: all approved as built

Numbered 0711 from the brief's range 0711–0719. No record numbered 071x exists on this branch, on any branch
(`git log --all -- 'docs/decisions/071*'`) or in any sibling worktree.

## Decision

The live demo gets **standing orders** (`godot/demo/orders/`; presentation only, nothing in the settlement simulation is
written): goals such as "keep 20 U of planks" or "always keep 3 days of meals", for which the village queues the work
itself. `godot/demo/README.md` ("Standing orders") says what the player sees.

- **The model** (`standing_orders.gd`): packed columns, twelve rows sized once -- the good (kind, item), the amount
  (milli-U, or milli-days for meals), the priority (REQ-SET-026's 1..4), on/off, the hysteresis latch, the state, the
  good measured, the committed output, and up to three held jobs a row (board source, the owner's row, the job's serial).
- **One goal per kind** (`order_goal.gd` and `goal_*.gd`) measures the good from its owner's own figure and opens work
  through its owner's own board -- the same calls an order with nobody selected makes -- so the work board (decision
  0411) lists and claims it like any other task. **No work-board source is added**; no source number is taken.
- **Evaluation on the game hour** (`demo_standing.gd`): when the calendar's hour index moves (one hour, or a skip's many)
  every player order is kept once. A per-frame cost of one integer comparison; a thousand keeps allocate no object
  (tested).
- **The UI** is a fourth tab, **Standing orders**, on the Work screen (the HUD's Jobs command, J): no new key.
- **The winter's Firewood** (decision 0571) is the book's **built-in** order, its behaviour unchanged (below).

## Rules used (from the documents)

- **GDD §4 `ProductionOrder` / `OrderMode` MAINTAIN_STOCK, REQ-SET-097**: "ONCE, REPEAT, and MAINTAIN_STOCK production
  orders with an explicit target". A standing order is the demo's MAINTAIN_STOCK for goods the demo makes; the GDD's
  is per building and per recipe, the demo has no recipe stations but the kitchen, so it is per good.
- **REQ-SET-098**: "count unreserved inventory plus committed in-progress outputs against the target before issuing
  another batch". The order counts what its live jobs will still bring (a load in hand, a saw batch, a deadfall pile, a
  tree's 12 U, a ripe bed's expected yield) before opening another.
- **REQ-SET-099**: a blocking reason is shown specifically ("not enough wood to saw: a batch takes 2.0 U and the stores
  hold 0.5 U — keep wood stocked").
- **GDD §5.3 urgency bucket 2** ("food/fuel jobs while projected reserve<2 days") and **systems_architecture.md**'s
  declared-versus-effective bucket: a job's urgency is derived from the reserve each hour, never stored as its bucket.
  Wood orders read the winter's fuel-days test (`demo_winter.gd firewood_urgent`); meal orders and orders for a crop a
  dish takes read the kitchen's Ready food under two days (**REQ-SET-113**). Written to the board's existing Urgent mark
  only when it changes, so a player's own mark on a task holds in between (decision 0571's rule, generalised).
- **REQ-SET-117**'s "minimum reserves per item" and **ui_ux_controls.md UI-SET-044** (order row: "Recipe+mode+target+in
  progress+blocking reason") shape the row: target, state, what is coming, why blocked, the work queued.
- **UI §7**: only conditions that need the player are incidents; the review's ECO-033/034 (approved group W: purpose
  reserves, shared storage policies) are **not built** -- an order keeps a total, not a purpose or a store, so W can
  later add "which store" and "which promise" without undoing this.

## How the Firewood was generalised, not duplicated

`forest_crew.gd raise_firewood` became `raise_wood(origin)` (deadfall nearest the log stack, else the nearest fellable
mature tree in a forestry zone); `raise_firewood` calls it with ORIGIN_FIREWOOD, and the "keep wood" goal with
ORIGIN_PLAYER. The winter's `_keep_firewood` now asks the book to keep its built-in order (`goal_firewood.gd` reads the
winter's own `firewood_wanted`, `firewood_urgent` and twelve-day projection), still on the winter's hour. Its one job at
a time, its origin, its Woods activity, its Urgent writes (a new job is written once, then only on a change) and its
re-raise after a cancel are the same: `test_demo_winter.gd` passes unchanged. (One wording change: a full woods board
is now said as such instead of "no deadfall".) The player may now **switch it off** -- switched on again it is kept at
once rather than at the next hour; nothing else: its amount, priority and presence are the winter's. Without a book handed to it (a suite's village) the winter makes its own.

## Brendan's rulings (2026-10-01) and derived choices

**Brendan approved all five proposals as built on 2026-10-01** (items 1, 2, 3, 4 and 10 below, each marked RULED); each took
option (a), the recommendation. The other items are this record's derived choices.

Each was the smallest sensible demo behaviour where the documents are silent; the options are kept as the record of what was weighed.

1. **RULED (Brendan, 2026-10-01: approved as built) — the band (hysteresis).** On below the amount; off once the good reaches amount + band; between, it keeps
   what it was. Bands: planks 2 U (one saw batch), wood 2 U (the largest deadfall pile), meals 0.5 day (one meal for
   the village), a crop 1 U. *Options*: (a) these fixed bands (recommended: simple, one batch's worth); (b) a percentage
   of the amount; (c) a player-set band.
2. **RULED (Brendan, 2026-10-01: approved as built) — jobs held at once.** Woods orders 2, farm orders 3, the Firewood 1 (decision 0571). *Options*: (a) these
   (recommended: two sawyers share one sawhorse; three is one harvest per ripe bed in practice); (b) one each, as the
   Firewood; (c) unlimited within the committed-output test.
3. **RULED (Brendan, 2026-10-01: approved as built) — "days of meals" is fulfilled by harvesting, not by cooking.** The kitchen cooks every meal itself from
   the stores (decision 0381), and its Ready food already counts what the stores would cook, so a cooking batch does not
   raise the figure (and portions keep only 24 h). What raises it is food into store: the order harvests ripe beds of
   any crop a dish takes. With no wood for the fire it is blocked. *Options*: (a) this (recommended); (b) also order
   extra cooking batches ahead (needs the kitchen to cook beyond its two planned days -- a kitchen change and spoilage);
   (c) count raw harvests only, not Ready food.
4. **RULED (Brendan, 2026-10-01: approved as built) — a crop not yet ripe is "Blocked", with one notice.** "No carrot bed is ripe yet (2 growing) — the order
   harvests it when it ripens" is shown as Blocked and raises one Village warning, resolved when a harvest is queued.
   *Options*: (a) this (recommended: it is true that nothing can be queued, and the brief says notices only when blocked);
   (b) a fourth state "Waiting for the crop" with no notice.
5. **Defaults** (demo values): first amounts planks 20 U, wood 40 U, meals 3 days, a crop 10 U (the brief's examples);
   steps 5 U / 10 U / 0.5 day / 5 U; most 200 U / 400 U / 10 days / 100 U; twelve orders; one order per good.
6. **Priority and Urgent on a task the player has touched.** A new order is Normal. The order writes its priority on a
   job only while the task is still at the priority the order last left it at (Normal for a job it has just taken),
   so a priority the player gave the task holds -- including on a farm harvest the order ADOPTS. Urgency is written
   only when the reserve's state changes, and a job taken while the reserve is not short is not written at all, so a
   player's Urgent mark on an adopted harvest holds (found by the review, H1).
7. **Removing or switching off** leaves the jobs it queued on the board: work in hand is never thrown away by a change
   of goal (the Work screen can cancel them).
8. **Adopting** a farm harvest the farm's routine already queued (REQ-SET-073) rather than opening a second; a job is
   held by one order only (`tracked`).
9. **Session only**: the demo cannot save, so orders are not saved.
10. **RULED (Brendan, 2026-10-01: approved as built) — committed output is the order's own jobs.** REQ-SET-098's count includes only what the order's own
    jobs will bring, not other work bringing the same good (the Firewood's job, a routine haul of a felled trunk, a
    harvest the player ordered by hand). A "keep wood" order beside the Firewood can therefore queue a little more than
    needed, never less. *Options*: (a) this (recommended for the demo: simple, and over-queueing is bounded by the
    kind's job limit and stops at the band); (b) count every job on the owners' boards bringing that good into store.
11. While an order is **off**, its jobs' Urgent marks are left as they were until it is switched on again.

## Shared surface

`forestry/forest_crew.gd` (`raise_wood`), `winter/demo_winter.gd` (`bind_work` takes the book; `_keep_firewood` keeps the
built-in order), `work/work_screen.gd` (VIEW_ORDERS, `set_standing`, `standing_view`), `demo_village.gd`
(`_build_standing`, `standing()`), `godot/demo/README.md`. No key, no work-board source, no notice source.

## Source

Feature #38 (Brendan, 2026-10-01); GDD §4 ProductionOrder/OrderMode, §5.3, REQ-SET-026/073/097/098/099/113/117;
`ui_ux_controls.md` UI-SET-044, §7; `systems_architecture.md` ARCH-STATE-005's declared urgency; the review's
ECO-032/033/034 (group W, approved, not built); decisions 0381, 0411, 0571.
