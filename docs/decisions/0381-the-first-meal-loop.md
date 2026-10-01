# 0381 — The first meal loop: a cook, two dishes, breakfast and supper
Date: 2026-10-01 · Status: Accepted

> **Superseded in part by [0421](0421-a-game-day-lasts-ten-minutes.md) (2026-10-01):** with a game day of ten minutes
> walking fits the day, so breakfast is 07:00-08:59 and supper 17:00-18:59 (were 06:00-12:59 and 13:00-16:59), the
> cook rises at 05:00 (was 01:00) and supper is cooked from 15:00 (was 09:00); the hand-out interval is 15 ticks and
> the re-call 38 (the real seconds they were). The "Open" notes on slow walking, late suppers and slow harvests are
> answered there.

> **Extended by [0436](0436-the-kitchens-third-dish-is-the-fish-stew.md) (2026-10-01):** a third dish, §5.7's fish
> stew, is cooked at supper in place of the soup whenever a batch's fresh fish and roots are free; ruling 1's
> alternation stands otherwise. Dried fish is eaten raw as the reserve (0434).

Review group N (findings F21 and UX-027, with the minimal versions of ECO-029 and SOC-007): in the live demo a harvest
could not end in anyone being fed. Now the village keeps a kitchen. A cook fetches the food, cooks it and puts the
portions out on the hall's table. The residents eat breakfast and supper there, and each carries an integer
nourishment state. The code is `godot/demo/kitchen/`, and every number in it is cited in `meal_rules.gd`.

Numbered 0381: the highest record on any branch or worktree was 0371, and the brief asked for the next free number above
0380.

## Brendan's rulings (2026-09-30), as built

1. **There are two dishes, and they alternate.** Wild oat porridge
   (`salamandastron::SAL_recipe_wild_oat_porridge`) is cooked as the GDD's `porridge` row: grain 2 + water 2 → 2
   portions × 1800 NP, 12 WU, Kitchen/COOK, shelf 24 h. Togget's vegetable soup
   (`outcast::OUT_recipe_togget_s_vegetable_soup`) is cooked as `root_stew`: roots 3 + water 1 → 2 × 1800 NP, 16 WU,
   shelf 24 h. The source rows are `docs/game_gdd.md` §5.7 and `docs/gameplay_balance.md` §3.1–3.2.
   - Breakfast is porridge and supper is soup. The meals alternate, so the dishes do.
   - When one dish's food is wanting and the other's is not, that meal is cooked as the other dish.
2. **Water is a real stock.** A resident draws it at the well at a WU a unit (BAL-SUPPLY-004: "10000 milli-U per 10000
   milli-WU") and pours it into the village's water butt beside the well. That butt is the stores'
   `water_milli_u` (`tunnel_stores.gd` WATER).
   - Water is credited only when it is poured. A batch takes its water from that stock, as it takes its wood.
3. **Fuel:** each batch takes 100 milli-U of wood from the village stores (BAL-SUPPLY-004).
4. **Breakfast and supper, two served meals a day.** Portions keep 24 h, so a day's meals are cooked on that day.

## What the crops are

The GDD has one `grain` item and one `roots` item. The demo grows sixteen fine-grained crops, each by one §5.6 row
(`farm_catalog.gd` ITEM_CROP), and that row also sets the crop's shelf life. A recipe's category is therefore that row:

| Category | Crops | Note |
|---|---|---|
| **grain** | wheat, barley, oats | the §5.6 grain row; §5.7's "Grain/flour" |
| **roots** | radish, turnip, carrot, beetroot, parsnip, onion | the §5.6 roots row; onion is a bulb, which decision 0196 put with the roots |

The porridge's book ingredient is "wild oats". The soup's book ingredient is only "vegetables", and carrot and turnip
are the library's AI-authored selection. So every crop of the category is accepted, as the GDD's own category is
(`meal_rules.gd` THE CROPS IN EACH CATEGORY). Cabbage-row and bean-row crops feed neither dish.

## The need, in NP

- **Hunger** is §5.2's need, 0–10000. Each game hour it falls by `scripts/core/family_rules.gd`'s adult rate for the
  resident's size and the season, with §5.2's remainder rule. That table is called, never retyped.
  - The rate is 250 an hour for a small resident: 6000 NP a day. The GDD states the same figure twice: §2's glossary
    says a "small resident requires 6000/day", and §7.1 gives `(small + 1.2 medium + 1.6 large) x 6000`.
  - A medium resident needs 7200 a day and a large one 9600. In winter each is 1.2 times that.
- **Size class** comes from `residents.gd` SPECIES_*_KEYS:
  - mouse, mole and squirrel are small;
  - the otter is medium;
  - the badger is large;
  - the beaver is not among the GDD's sixteen species. DEC-041 puts it between the squirrel and the otter "but
    stockier", so it is **medium**: a demo value.
  - The cast names its species capitalised ("Badger"), so the match ignores case. (The first capture showed the badger
    reading "of 6000 NP" until it did.)
- **A portion** adds its 1800 NP at PLAIN quality. Fullness is clamped at 10000 "without refunding excess NP" (§5.2).
  - Two meals are 3600 NP, 60% of a small resident's 6000. The rest is left to later food work.
  - So a village fed only by the kitchen drifts down to **hungry** within a few days and stays there. That is the
    rulings' arithmetic, shown honestly; no penalty follows from it.
- **Fed, peckish and hungry** are §5.2's thresholds ("Eat ≤3500; urgent ≤1500"):
  - **fed** is above 3500;
  - **peckish** is 1501 to 3500;
  - **hungry** is 1500 and below.
- **No penalties are invented.** REQ-SET-014's health loss and the meal-quality memories are not modelled. Everyone
  opens at 10000 (a demo value).
- **Monotony is shown, not applied** (§5.7: of the last 6 recipe ids, 2–3 repeats give −200 and 4–6 give −400, for 6 h).
  - Even strict alternation reaches 2 repeats on the fifth meal, so the readout appears from day 3. The demo has no mood
    model.
- **Raw emergency food** follows REQ-SET-013 under WorldPolicy `raw_emergency_food` (default true). At a meal's end, a
  resident without a portion at hunger 1500 or below eats raw-edible food that nobody has reserved, where it is stored.
  - It eats enough to add at most 3000 NP: 3.75 U of roots at 800 NP a unit, or cabbage at 600.
  - Grain and beans are never eaten raw (§5.7 marks them "No").

## Who cooks

- **The village cook is the keeper** (`kitchen.gd` COOK_KEYS; the first resident in a world without one). This is the
  existing specialist convention, as the bridgewright is the village's bridge specialist.
- **A stand-in** cooks when the cook is not free and a meal is due: the nearest free resident.
- **The player's Cook order** makes the nearest selected resident the cook now.
- **The HUD says who:** the Kitchen tab's first line and the ledger name the cook. Its party-panel and roster words
  are the task's own: "Fetching food for the kitchen from the kitchen pantry", "Cooking wild oat porridge for
  breakfast (4 portions in the pot)", "Carrying the pot to the table".

## The round, the windows and the night

- **The cook's round**, every step physical:
  1. **Fetch.** The cook goes to a store holding the planned meals' reserved food, picks it up (1 WU), carries it to
     the cauldron and puts it down (1 WU). A second store is a trip of its own.
  2. **Cook.** A batch at a time, at §5.2's step rate: 80 milli-WU each calendar tick, 60 WU a game hour, skill 0,
     PLAIN.
  3. **Serve.** Each meal's pot is carried to the hall's east table as soon as it is cooked, and the portions are put
     out (1 WU).
  4. **Eat.** The cook eats there, then fetches the next food. Leaving while breakfast is served, it eats its supper
     early: supper's own portion, never breakfast's.
- **The meals are planned four ahead** (two days), so one fetch brings a day's food ahead of time.
- **The windows** (demo values; the night is decision 0210's, 18:00–05:59):
  - breakfast is called at 06:00, on waking, and served until 12:59;
  - supper is called at 13:00 and served until 16:59. Its end comes an hour before bedtime because a meal's end is
    when the hungry set off to eat raw food: ended at dusk, they were sent to bed on the way and the tally already
    posted was wrong (the review's H1). A diner or raw eater already on its meal finishes it before bed.
- **The cook rises at 01:00** to have breakfast on the table by morning: the night routine's EARLY RISER
  (`night_routine.gd` `set_early_riser`).
  - It rises only while it has today's meals to get cooked. One still on its way to bed turns back.
- **Supper is cooked from 09:00** (`meal_rules.gd` COOK_FROM_HOUR). On the open table a portion ages at §5.8's
  open-pile factor, 1500, and summer multiplies it by 1.5 again: 10.7 game hours of its 24. A supper put out at dawn
  would spoil before 17:00 (the review's H3); cooked from 09:00 and put out as it is cooked, it lasts in any season.
- **Diners are called once their meal is on its way:** its portions out, in the pot, or a batch of it (or an earlier
  meal) cooking. Nobody waits at a table for a meal that is not coming; a diner already waiting whose meal stops
  coming gets up and goes.
- **A meal waiting in the pot goes out before a later meal is cooked** (`_pot_due`). Measured: a breakfast cooked
  late at 10:00 was kept in the pot while supper's batches cooked, and 0 of 9 ate it.
- **The cook takes its portion when it decides to eat,** so the diners waiting cannot take it on its way; with none
  left it goes on with its round. Before, it could sit waiting at a table until dusk, and nothing else was cooked
  (the review's H2).
  - A call parks the work in hand on the resume queue (decision 0205), as the night does. A drawer is called too.
  - **Nobody carrying a load is called**, to a portion or to raw food: a harvest or logs in hand are delivered first
    (decision 0222). Measured: calling the harvest's carrier to supper parked its delivery, and the harvest reached
    the kitchen pantry four game days after it was cut.
  - **A diner already eating finishes its bowl** (12 WU, a fifth of an hour) before the night takes it to bed.
  - Seats are five round each of the hall's two tables.

## Why there is a kitchen pantry, and other choices made against the clock

- **The calendar makes walking expensive.** On the demo calendar a metre of walking costs about 0.4 game hours (2.5 s
  a game hour; a mouse walks about a metre a second).
- **The village is spread out:**
  - the covered store is 9 m from the cauldron;
  - the hall, where the bedless sleep, is 12 m from it;
  - the well is 9 m from it.
- **A cook fetching each meal from the covered store cannot serve two meals a day.** Measured in a headless run of the
  real village, the round to the store and back is most of a day.
- **So the kitchen has a store of its own:** the **kitchen pantry**, at the end of the path to the kitchen (10.5, −2.6).
  - It is a storage-provider location at GDD §5.8's PANTRY factor, 750 per mille, holding 120 U (a demo value).
  - Harvests already go to the slowest-spoiling store with room, so the order is: a cool root cellar (350), then this
    pantry, then the covered store (1000).
  - The cook takes from it, in a couple of game hours.
- **The water butt stands beside the well**, so a drawer's trip is a walk to the well and back. Ruling 2 says the water
  goes "into the stores"; the stores are stock with no place, and wood is used the same way.
- **The butt holds 40 U** (a demo value): more than two days of both meals for nine.
- **Keep water drawn**, on by default, keeps the butt full: a maintained stock, after REQ-SET-097's MAINTAIN_STOCK.
  Whoever is free and not due at a table draws it, at most two at once.
- **A load in hand is delivered before bed.** Under decision 0222's rule that a job never closes holding a load, the
  cook carrying food or the pot, and a drawer carrying water, finish that delivery after dusk. The kitchen task reports
  it to the night routine as `urgent`. Empty-handed, they go to bed.

## Holding and taking the food

`ingredient_takes.gd` follows decision 0222's pattern of holds: **reserve, consume, return**.

- **Reserve.** A planned meal reserves its food from real lots, the lot that spoils first first. The reservation is
  made against (row, **serial**): `farm_pantry.gd` WITHDRAWALS gives a reused row a new serial, so a lot that spoiled is
  never cooked.
- **The books do not move.** The food stays in its lot, ageing at its store's rate, until a batch starts. The Pantry
  shows it as "N U for the kitchen".
- **Consume.** A batch withdraws exactly its food once (`withdraw_into`), together with its water and wood, all or
  nothing.
- **Return.** A release gives the reservation back. Nothing moved, so nothing is credited and nothing is made fresher.
- **The batch in progress belongs to the kitchen** (REQ-SET-091). A cook called away, or sent to bed, leaves it at the
  cauldron, and whoever cooks next finishes it.
- **A cancel follows REQ-SET-094.** The meal's reservation is given back. A batch already cooking yields half its food's
  mass as spoiled food and no portions. Food the cook has already fetched stays at the kitchen, in the **larder**, for
  the next meal of its category.
- **Portions are lots** (`meal_store.gd`):
  - in the pot they age at the covered-store factor;
  - on the table they age at the open-pile factor (§5.8: "Prepared food left on tables uses open-pile factor");
  - they are eaten by §5.7's order;
  - a reserved portion is consumed once, when the eating ends (REQ-SET-095), and given back if the diner is called
    away;
  - a spoiled portion is 2 U of spoiled food (500 g against 250 g).
- **Leftovers** are portions from meals whose serving is over that will still be good at a meal's call. They reduce
  the next meal's batches.
- **The larder counts as the dish's food.** A meal turns to the other dish only when neither the stores nor the larder
  hold a batch of its own. (Measured: with supper's roots waiting in the larder, the next supper was porridge.)
- **The tally at a meal's end** counts a diner still holding its portion, or its raw food, as served. If it is then
  called away before eating, the portion goes back and the tally moves it to "went without" (`_served_but_missed`).
  It is never counted twice and never left out.

## What the player sees

- **Ready food is days of meals.** The top bar's cell is the portions held, plus the portions the stores' grain and
  roots would cook (at most the wood allows), divided by the portions the village eats a day (one a meal, two meals,
  every resident). It is shown in tenths, floored: "2.5 days".
  - Water is not counted, because it is drawn at the well as needed.
  - The ledger adds one line of the stock behind it: "5 portions · grain 18.0 · roots 12.0 U". The shell's ledger is
    a fixed size, so water, wood and the cook are left to the Kitchen tab; the cell's tooltip says how the days are
    counted.
- **The Pantry** has a third tab, **Kitchen**, holding:
  - the cook and what it is doing;
  - any refusal and its fix;
  - the next meals;
  - the pot and the table;
  - the butt and the fuel;
  - how the village is fed;
  - the last meals' tallies;
  - the buttons Cook now, Draw water, Keep water drawn and Cancel the next meal.
- **The Stocks tab** ends with each dish's portions, as ready food, and the water.
- **The Recipes tab** (it was "Recipe ideas (not cookable yet)") marks the two dishes "Cookable (active)" on their
  crops.
- **The Cook and Draw water buttons carry action cards** (decision 0332), built from `decide_meal` and `decide_draw`,
  the very functions the orders run. A refusal reads, for example: "Can't now: the water butt holds 0.0 U; togget's
  vegetable soup needs 1.0 U a batch (2.0 U for the meal) / To fix: Pantry (K) ▸ Kitchen ▸ Draw water".
- **A meal called with nothing coming** raises the incident `kitchen:no_meal` ("No supper tonight: <reason>. To fix:
  <fix>"). It is resolved when the village next eats.
- **Each meal's end** posts its tally to the news: "Supper, day 2: 8 ate, 1 went without".
- **The resident panel** shows the fed line: "Fed · 72% full · 1800/6000 NP today", then "Last meal: breakfast,
  porridge", with the monotony line when it applies. The roster shows the word.
- **Presentation:**
  - the cook carries the fetched item's own model, the pot as a basket, and a drawer its water in a jar;
  - steam rises over the cauldron while a batch cooks. It is six pooled quads on the demo clock, not particles, so the
    warren's 200-particle budget (decision 0211) is untouched;
  - bowls on the table show the portions put out;
  - diners sit on `chair_sit_idle` when it is staged, and otherwise wait idle and eat on `stand_and_drink`.

## The review (code-reviewer, 2026-10-01), fixed

- **No per-frame allocation** in what is polled every frame: the slots' order is kept sorted when a slot changes
  (`_slot_order`), and the cook's duty (the night polls `up_early`) and the item it is drawn carrying are kept for a
  calendar tick.
- **No reference cycle outlives a Restart.** A kitchen task holds the kitchen weakly (the kitchen keeps its tasks and
  the brains keep them too). The night routine's early-riser morning is a bound method, not a lambda holding the
  routine. The Kitchen tab and the view are freed if nothing took them.
- **A cook goes to bed only empty-handed**: any food in hand or the pot is delivered first.
- **An unreachable store** lets go only the food still waiting there; fetched food stays the meal's.
- **A withdrawal is whole**: a reservation is cut to what its lot still holds before a batch withdraws.
- **Free food** is counted in one pass over the reservations, not one per lot.
- **The logs are bounded**: the last 64 meals and 256 batches.
- **Cook now with nothing left to cook** is refused: "breakfast, day 3 has all it needs".
- **Left as they are:** a raw meal's news line is posted at the meal's end, so if the player then orders that
  resident away, the line already said "ate raw" (the tally itself is corrected); an unreachable store may be
  reserved again an hour later; a reserved portion eaten past its shelf life gives its full NP; a Draw water order for
  a busy selected resident queues instead.

## Rejected

- **Fetching each meal's food just before cooking:** it cannot fit the day.
- **Strict village-wide soonest-to-spoil without the kitchen pantry:** the cook would walk to the covered store every
  day.
- **The cook sleeping in the kitchen:** it is against ruling 3 of decision 0210, that residents sleep at home.
- **Steam as particles:** the budget is spent.
- **Calling diners at the window's opening whatever is coming:** whole mornings were spent waiting at tables, and the
  water was never drawn.

## Measured

Acceptance runs of the real nine-resident village with the staged assets, 1920x1080 at 4x (the frames and logs are
in the group's report). The harness tops the kitchen pantry up with 40 U of wheat and 50 U of carrots, logged, and
places the fieldworker by a reachable roots bed, because the walk from the hall to the beds is most of a day.

- **The stock falls by exactly the recipe.** Every batch the harness saw took grain −2000 (porridge) or roots −3000
  (soup), water −2000 or −1000 and wood −100 milli-U, and nothing else.
- **The books balance.** Before 90000 + harvest 5100 − cooked 88000 − raw 7100 = 0 milli-U, and the pantry held 0.
- **Breakfast and supper alternate.** On days 3–4: breakfast porridge 8 of 9, supper soup 8 of 9, breakfast
  porridge 9 of 9 (in a later run: 9, 7 and 1 raw, 8).
- **The opening days are thin.** Day 0's breakfast cannot be fetched in time, and some suppers are put out late.
- **Food is wasted.** About 20 portions over four days spoiled on the table; see Open.
- **The shortage is reported exactly.** With the butt emptied and food stocked, breakfast's refusal reads "the water
  butt holds 0.0 U; wild oat porridge needs 2.0 U a batch (10.0 U for the meal)", with its fix. The incident "No
  breakfast this morning" is raised, and the meal is tallied "0 ate, 9 went without".
- **Interruptions conserve the stock.** The suite drives the whole loop on real brains (`test_demo_kitchen.gd`):
  - the cook called away mid-batch, a diner called away, a cancel, and night falling mid-batch;
  - a diner still eating at the end, a diner called away after it, and a raw meal at supper's end with the night
    running.

  Each checks the pantry's books, each batch taken once, each portion once, and no lot made fresher.
- **The suite and harness:**
  - `./tools/run_tests.sh`: 6851 test(s), 558671 assertion(s), 0 failure(s);
  - the live input harness: LIVE-SUMMARY 128 0 (1280x720) and 133 0 (1920x1080);
  - 72 mutants of the new logic were each killed by the suite, 16 of them after tests were added for them.

## Open

- **Walking is slow on this calendar, and it sets the pace.** A resident covers about 1–3 m a game hour, and
  carrying slows it further: the pot's trip of about 3 m from the cauldron to the table took the cook 2–3 game hours.
  - Some suppers reach the table after 17:00 and are eaten by nobody.
  - Diners working far off cannot reach the table within a meal's window.
  - The cure is in the walking pace or the village layout, not the kitchen.
- **Portions spoil.** Each meal is cooked for every resident, but some cannot come. Leftovers are counted only for the
  next meal, and only if they will still be good then; the rest spoil on the table at the open-pile factor.
- **The farm's harvest takes days to arrive.** In the runs the carrier took 1.5–5 game days to shelve 5.1 U in the
  kitchen pantry: it is parked each night and walks from the hall each morning. This is farm behaviour that predates
  this group, measured here.
- **The party panel's fit can fold the fed line away** when a resident's orders list is long (the mice). The
  Residents roster always shows the word; the badger's panel shows the line.
- **A summer breakfast cooked at 01:00 and put out at once spoils at about 12:10**, so the last of breakfast's window is
  lost then (the review's LOW).
- **Carry mass is not enforced on fetched food.** A cook picks up all of the planned meals' food at a store; §5.2's
  12 kg for a small resident would cap a day's food for nine at about two trips.
- **Cooking skill, quality, XP and mastery are not modelled** (REQ-SET-091 and 096 beyond the batch snapshot). Every
  portion is PLAIN.
- **Health, mood and departure are not affected** by hunger or monotony. Those are readouts.
- **With food only in far stores, the meals run late.** Soonest-to-spoil sends the cook there first. This is honest,
  and the cure is a root cellar near the kitchen or room in the kitchen pantry.
- **The sound cues come later** (the brief).

## Integration with review batch 4

- **The fed line always shows.** The note above ("the party panel's fit can fold the fed line away") is resolved:
  F's panel (0391) never folds, and the fed rows are no longer one of the skills providers that came last. The
  command layer carries them as their own entry (`demo_command.gd set_fed_text` / `fed_text`): for one resident
  they are the rows right after what it is doing (before the order list and the skills), and in a group row the
  word follows the state. They are part of the panel's refresh signature.
- **Meals and the work board** (0411): the board claims no work for a resident `kitchen.gd kept_for_meals` keeps,
  and the cook's round and the water draws are rows on the Work screen (`work/kitchen_work.gd`).
