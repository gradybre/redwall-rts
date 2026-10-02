# 0631 — The village chronicle writes a season's page from what was recorded
Date: 2026-10-01 · Status: Accepted (feature approved by Brendan 2026-10-01; his rulings on the five PROPOSALS, 2026-10-01, below)

The number 0631 comes from the brief's range, 0631–0639. No record numbered 0630–0639 exists on any branch
(`git log --all`) or in any sibling worktree.

Feature #10, "the village chronicle". At each season's end the village writes a page in a record-keeper's voice, and a
book view shows the pages. The work is presentation only (decision 0196): nothing is written into the simulation. It is
built on `feat/demo-notices` (decision 0591), whose notice history it reads by entry id.

## What the documents already rule

- **GDD §4.2 `ChronicleRecord`** covers death, departure, notability, assistance and Charter events, each per resident,
  append-only, with 64-row presentation pages. Those are the settlement's rows. The demo does not write them (decision
  0491 already says so for the people's ledger). The season page is a presentation over the demo's own records.
- **Setting bible, LORE-T07**: "Memory accumulates honestly." Recorded simulation history must not present invented
  accomplishments or friendships.
- **Setting bible, CULT-002**: "A keeper records the season's most consequential events", with "add no record of an
  event that did not occur".
- **Setting bible, §13.3**: the chronicle's voice must "record the real event before interpretation", bound to the
  actual participants.
- **Setting bible, §16**: "Read committed events once; repeated presentation does not execute the event or grant a
  second reward", and "Reopening a codex/chronicle entry must not mutate simulation."
- **Setting bible, §9.3**: copy may describe a real conflict event but "may not fabricate motives".
- **DEC-022**: mixed story surfaces, with "Current chronicle/notices stay bound to committed events".
- **DEC-017**: light dialect only in a resident's own words. Record and system text stay plain.
- **Review UX-021 (return journal)** is DEFERRED with saving. Its guidance still applies to any recap: "store real facts
  and player notes; avoid auto-generated narrative that invents events or long recaps." So no save browsing is built,
  and pages are session-only.
- **Review UX-020 (named projects)**: a done project "records a small Chronicle entry". The guide already posts that
  line, and the page counts it.
- **Lore**: the demo's people are an original community (decision 0491). The songs are original (0442). The page's
  wording is original, with no book's name, place or phrase (`test_the_words_carry_no_canon_name`).
- **UI §2.1 and decision 0391**: 14 px minimum type, and buttons at least 32 px tall.
- **UI §1**: a modal sits centred in the HUD's modal rectangle.

## Decision

1. **What a page tells.** Every line is bound to a recorded fact, and a section with nothing recorded is left out.
   - **The harvest and the table** come from the farm's after-action record (0451):
     - food stored this season and its three largest items;
     - portions eaten;
     - meals missed, counted per resident;
     - crops withered.
     The village's first food in store and its first cooked meals are told once in its life.
   - **Weather and trouble** come from two sources, capped at four lines:
     - the season's §5.10 event and the days the record saw it;
     - incident lines in the news, counted once per subject or once per day. These are trees blown down, the garden
       flooded, tunnels flooded or fallen in, a threat sheltered from, residents in difficulty in the water, frost
       nights, blighted beds, days without a meal and nights without a bed.
   - **Deeds** are the season's committed deeds from the people's ledger (0491), in the reflection's order, three shown.
     A first rescue, bridge, tunnel or room in the village's life says so.
   - **Friends and neighbours** compare the ledger's friend flags at the season's start and end (REQ-SET-037). They tell
     friendships made and lapsed, and the pair who worked side by side most (at least 3 hours).
   - **Songs and gatherings** cover:
     - the season's occasions;
     - songs learned, comparing what each resident knew at the season's start and end;
     - the evenings the supper table sang.
   - An opening line is chosen by the first mood that holds, and a closing line ends the page. Each mood's wordings
     claim no more than its own condition:
     - an occasion;
     - hunger: somebody went without, or a day had no meal;
     - crops lost;
     - hard weather: an adverse §5.10 event (blight, drought, early frost, hard freeze or heavy rain) or a weather
       trouble (wind, garden flood, tunnel flood or frost). Calm days and an ideal spell are not hard weather;
     - other trouble;
     - steady;
     - bare.
   - Supper songs are told as "singing at supper", never as the table singing together, because a song sung alone
     counts too.
2. **Reading the news by entry id.** New rows are read with `is_new_since`, never as the newest N, because a grouped
   repeat keeps its id and moves to the top. Each row counts in the season of its `first_tick`, so a line said on a
   season's last evening and read a frame later is still that season's.
3. **When a page is written.** The season changes at midnight. The page waits until the farm's record has closed the
   season's last day (the farm hour after midnight, once the kitchen has tallied supper), so its totals are whole. If
   another season ends first (a calendar jump), or a whole day passes, the page is written with what is kept. A page is
   written once. It posts one Village info line (kind `chronicle_page`) and calls the tapestry hook.
4. **Curation is read when shown.** A page keeps up to eight deed lines, each with its deed serial. When the page is
   shown it applies the player's curation from the reflection (0491, SOC-028):
   - a pinned deed is shown first;
   - a deed kept private or dismissed is never shown;
   - with no deed left, the Deeds heading is dropped.
   So answering the reflection after the page was written still decides what the page tells. Reading changes nothing.
5. **Occasions come from "Chronicle:" Village lines.** These are lines the regatta's feast already writes (0438, on
   its own branch), the first village standing (0481) and a project done (0481).
   - A later feature's gathering, arrival or departure joins the page by posting a Village line beginning
     "Chronicle: ".
   - The people's pinned deeds also post "Chronicle:", under the crew's source. Those are read from the ledger instead,
     where curation lives, so they are not told twice.
   - A deed kind outside the seven told here (the regatta's own `KIND_REGATTA`) is its feature's to tell through its
     "Chronicle:" line.
6. **Variety without randomness.** Most lines have two or three wordings. `pick(seed, season, slot)` is an integer
   hash of the farm's weather seed (`FarmSim.WEATHER_SEED`), so the same village writes the same page every time.
7. **The book.** `chronicle/chronicle_window.gd` is a modal of the input gate (Esc and × close it) and a planning
   surface ("the chronicle").
   - It sits in the HUD's modal rectangle at the HUD's scale, at most 720 wide, at full height, and the page scrolls.
   - Tabs list the pages by season, plus **This season**: the season under way, written so far and marked as being
     written. A session that ends before its first season does still has a page.
   - Earlier page and Later page step through the book.
   - It opens from a **Chronicle** button in Village news (N) and one in the village guide (O). Each closes its own
     window first. **No key was added.**
8. **The tapestry hook.** The great hall's tapestry is on unmerged `feat/demo-great-hall`. The chronicle has one
   documented hook point, `chronicle().page_written: (absolute_season, title, summary) -> void`, called once per page
   written. Nothing in the demo depends on that branch.

## PROPOSALS (the documents are silent; the smallest demo behaviour was chosen)

- **P1 — "Who fell out with whom" is told only as a friendship lapsed.** The demo records no quarrel: affinity only
  grows, and fades after three days without contact (§5.3, 0491). Inventing quarrels would break LORE-T07 and §9.3.
  - Options:
    - (a) tell only lapsed friendships, as "drifted apart" (built);
    - (b) add a recorded disagreement event (a new system, for a later feature);
    - (c) leave the line out.
  - Recommendation: (a) now, and (b) only when a conflict event exists.
- **P2 — Arrivals and departures.** The demo has none (a fixed cast of nine). The page has no section for them, and any
  future one joins through a "Chronicle:" Village line.
  - Recommendation: keep it that way until arrivals exist.
- **P3 — The keeper's voice is the village's, not a named resident's.** CULT-002 names "a keeper", and CULT-002 is
  PROPOSED under DEC-014, which is OPEN. Attributing the page to Wenna Tallowby (the mouse keeper) would put words in a
  person's mouth.
  - Options:
    - (a) unattributed (built);
    - (b) "Set down by Wenna Tallowby, keeper".
  - Recommendation: (a) until DEC-014 settles.
- **P4 — Pages last the session.** Saving is deferred (UX-021). The book keeps 48 pages, twelve years, and drops the
  oldest first.
  - Recommendation: persist the pages with the save work.
- **P5 — The season-so-far page.** It was added so that a playtest shorter than a season (two hours at 1x) still ends
  on a page.
  - Options:
    - (a) keep it as a tab (built);
    - (b) also post it to the news when the session is quit;
    - (c) drop it.
  - Recommendation: (a).

### Brendan's rulings (2026-10-01)

**P1–P5 are approved as built:** lapsed friendships told as "drifted apart" (P1 a); no arrivals-and-departures section
until arrivals exist (P2); the keeper's voice unattributed (P3 a); pages last the session until the save work (P4);
the season-so-far page kept as a tab (P5 a). Nothing changed in behaviour. Recorded at the batch 7 integration
(decision 0902).

## Review

The independent review (code-reviewer) found no CRITICAL problems. It found two HIGH lore problems, both fixed with
tests:

- **Openings claimed what was not recorded.** A lost crop opened "Not every bowl was filled". Calm days opened "The
  weather tried the village". The moods were split as in decision 1, so each wording claims only its own condition.
- **A solo supper song was told as the table singing together.** It is now told as singing at supper.

Its MEDIUM findings were also fixed:

- The occasion wording now assumes no gathering.
- A draft test could not fail; it now has a first it could wrongly use up.
- Three paths had no test: the end-of-season snapshots against a page written later, songs learned in the draft, and
  a day whose weather was not seen. Each now has one.

Its LOW findings were fixed too:

- "one portion" is now singular.
- A project name that contains a quote mark is kept whole.
- The owners' prefixes are made once.

Two LOW notes are left as they are:

- A first-night frost warning, posted the evening before, counts in the earlier season.
- The Lab's "Next weather" skip can take the season-end snapshots up to two days late.

Mutation testing: 43 mutants of the new logic and hooks, all 43 killed. Two earlier equivalents were removed: a
redundant sort was deleted as dead code, and a project-name case was given its own test.

## Consequences

- A feature that wants a line on the season's page posts a Village notice beginning "Chronicle: ". It does not call
  the chronicle.
- The chronicle reads the incident kinds in `chronicle_tally.gd` `TROUBLE_KINDS`. A renamed incident key drops out of
  the page silently, so rename the two together.
- Nothing here writes the GDD's `ChronicleRecord`. When the settlement's chronicle is built, this page should be
  rebuilt over those rows.

## Source

- The feature brief, approved by Brendan 2026-10-01.
- `docs/setting_bible.md`: LORE-T07, CULT-002, §9.3, §13.3 and §16.
- `docs/setting_decisions.md`: DEC-017, DEC-022 and DEC-014.
- `docs/game_gdd.md` §4.2.
- `docs/reviews/2026-09-30-external-review.md`: UX-020 and UX-021, with decision 0493's approval log.
- Decisions 0331, 0438, 0442, 0451, 0481, 0491 and 0591.
