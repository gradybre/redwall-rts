# Brendan's rulings since 2026-09-30 — an index

One line per ruling, oldest first. "Recorded in" is where the ruling's text lives: a `docs/decisions/` record
(`NNNN`), a `docs/setting_decisions.md` entry (`DEC-nnn`), or a ruling file. Read the record for the exact wording;
this index only points.

**Branch marks.** No mark: on `origin/master` as of the snapshot (`7dadb0f0`). Otherwise the branch it is on:
**B8** `integrate/review-batch-8` (PR #222), **RF** `fix/codex-review` (PR #221), **PF** `perf/route-planning`,
**HL** `feat/hauling-h0-h2`, **MS** `feat/demo-measures`. **Tracker only** means the ruling was recorded only in the
coordinator's tracker, which this handoff replaces: **this file is its first repository record.** When you build
against a tracker-only ruling, quote it from here in your decision record.

Every row was checked against the record named.

## 2026-09-30

| Topic | Ruling | Recorded in |
|---|---|---|
| The external review, every item | Decided and split into lettered groups A–AJ; all approved except: **V** (combat, army, campaign) deferred to a separate prototype; **AF** deferred, "come back to later"; **AI** split, UX-021 and UX-024 deferred; **AJ** split, UX-030 and UX-032 to the backlog. Conditions: S's save half deferred; R asks before each download; N shows the staple first; T proposes names first; AH's kit art asked separately; AC's mentoring rule change to be recorded; AD's child items wait on PC-04; W's content calls inside the content library and its pantry rules (eel a hazard, no shrimp, mussel coast-only, saltpan from coastal brine); AE lore original only; AJ no paid spend without asking | 0493 |
| Water part B (group K) | Approved whole, "everything": trips into the pantry, gear, the rack, the mill, boats, weir irrigation (wet/normal/dry, no hydrology), ice fishing, ferries, the regatta feast, otter songs (original text only) | 0493 row K; 0431 (dates it 2026-10-01), 0439, 0441 |
| Spoil (group L) | Dug earth is never fertiliser; spoil is earth for raising beds, banking paths and backfill; compost only from plant waste | 0401, 0493 |
| Sound packs (group R) | All nine CC0 packs (P1–P8 and the shovel) approved for download; nothing else | 0351, 0493 |
| The first meal loop (group N) | Two dishes alternating: wild oat porridge (the GDD's `porridge`) and Togget's vegetable soup (`root_stew`); water a stocked item drawn at the well, 1 WU a unit; fuel 0.1 U of wood a batch; breakfast and supper | 0381, 0493 |

## 2026-10-01

| Topic | Ruling | Recorded in |
|---|---|---|
| Fishing boats | Fixed routes only, no free sailing | 0432 (undated there) |
| Day length | A game day is 10 real minutes at 1x, as the GDD says | 0421, 0493 |
| Resident names (T) | All option A (Wenna Tallowby, Jory Whitethorn, Linnet Whinberry, Tobit Highbough, Tegwin Slipstone, Corra Netley, Tuppen Clayholm, Hulda Slatebrook, Elstan Weirholt); an ORIGINAL community, not Rowan's | 0491, 0493 |
| Otter song texts | All four approved as written | 0442, 0493 |
| Guide objective texts (U) | Approved, with "they" (not "it") for residents | 0481, 0493 |
| Coverage gaps | Group AK (F48, UX-005, UX-006, bridge removal with a cap) approved; test hygiene to run; four settlement loose ends "fix all"; the release gates (asset contact metadata, the silent-video work chain, graphics tiers with the GTX 1660 floor, fresh-player sessions by Brendan) folded into the performance and playtest step | 0493, 0501, 0511 |
| The Warden | Adults and elders may be Warden, never children; a living Warden may be replaced with confirmation (the old one steps down); naming waits on READY_07 I2 | 0511, DEC-042 |
| PC-04, the family package | Adopted with children inactive; the drafted values confirmed (child hunger 750/1000; care decay 250/h, gain 3000/h, start ≤ 6000, stop ≥ 9000; household ≤ 8; ≤ 2 named caregivers; …); children may have non-violent arguments; engineering gates 1–6 stay open | 0521, DEC-044, 0493 |
| Demolition | Answers 1–9 approved; furniture removal returns 50% of materials; the full path D1–D9 | 0531, DEC-043, `docs/rulings/2026-10-01_demolition_containment.md` |
| Demolition refunds | Doorless refunds start from the ring of tiles touching the footprint, nearest the front first; piles never on any standing footprint | 0532, DEC-043 |
| Demolition D4 | P1–P5 approved as built (now R1–R5) | 0534 |
| New features, first list | Day/night lighting, seasonal trees, winter fuel and warmth, the balance sim, the scale test approved. Not chosen: save reconsider, session recording, newcomers, seasonal foliage ("re-offer later") | Approvals stated in 0541, 0551, 0571, 0911, 0561. Not-chosen list: tracker only |
| Process | "Start as many concurrently as you can without conflicts and auto start as conflicts are resolved"; keep all agents on Opus | Tracker only |
| The feature list ("FEATURE SCHEDULER") | Approved for building as their triggers clear: #10 chronicle, #18 preserving, #19 brewing, #20 orchards, #22 foraging, #23 skills, #24 day planner, #31 paths and roads, #33 hauling and zones, #34 livelier weather, #37 river trade, #38 standing orders, and the already-running #16 dishes, #26 infirmary, #30 cellar, #39 notices, #40 map layers | Built ones in their records (0631, 0671, 0681, 0711, 0601, 0621, 0611, 0591, 0581). The rest: tracker only |
| New features, "NEW 2" | #9 feasts, #10 chronicle, #11 wildlife, #14 soak test, #15 crash and playtest log approved. Not chosen: #5 saving, #6 session recording, #7 newcomers, #12 trader, #13 mood bubbles | 0631, 0921, 0562 for the built ones. #9, #11 and the not-chosen list: tracker only |
| New features, "NEW 3" | #48, #49, #51, #53, #54, #55, #56, #57, #58, #59, #60 approved | Built: #53 0771, #57 0781, #58 0791, #60 0801, #48 within the crops lane (0883). #49, #51, #54, #55, #56, #59: tracker only |
| Winter | Chilled is 80% work plus warm-up breaks, no health loss; the GDD's continuous hearth burn; clothing tier 1; a Skip-to-next-season control. Stated as defaults and not objected to: the HUD's "Heating fuel: N days" and a 12-day pre-winter target | 0571 (it records all six as rulings) |
| The cool cellar (#30) | P1–P6 approved as built; P7: "Build both cellars" | 0611, 0612 |
| The Cellar building | P1–P4 approved: available from the start, 500 g a unit (2,000 U), no staffing, the library model | 0612 |
| The Great Hall (#53) | Option A, the adopted version; P1–P5 approved as built; P6 keeps decision 0210's value | 0771 |
| Notices (#39) | P1–P10 approved as built | 0591 |
| Run until next warning | Skips snoozed kinds; warnings the toast budget held back still stop the run | 0591 |
| Goals (#57) | P1–P7 approved as built | 0781 |
| Dishes (#16) | P1–P4 approved as built; P5 "add in everything for 5 now" (phase 2) | 0601, 0603, DEC-045 |
| Dishes phase 2 | Recipe numbers approved; moles favour the root pie; oatcake and farl left to #17; potato raw-edible | 0603, DEC-045 |
| Hives | Start soon (group Y's hives, honey and wax), after batch 7 | Tracker only |
| The playtest log | Playtest builds export debug; the release flag kept for finals; no `always_track_call_stacks` | 0562 |
| Balance tuning E1–E7 | E1 a stocked opening pantry (40 wheat, 50 carrot); E7 threats on the calendar, about one in nine days; E2 a rootless fish dish and E3 dried fish and flour as inputs (dishes phase 2); E4 covered by the bean hotpot; E5 12–18 beds with a default sowing policy; rerun the year matrix after these and the winter merge | E1/E7 0912; E2–E4 0603; E5 0886, DEC-046. The rerun: tracker only (MEASURE-BAL) |
| Map layers (#40) | P1–P8 approved as built | 0581 |
| Performance after the scale test | Route planning and the bursts approved, and the smaller fixes (spatial hash, affinity buckets, board index); the crowd path and capacity limits **not now** | 1001–1004 (PF; dated 2026-10-02 there). "Not now": tracker only; the perf doc says "deferred by Brendan" |
| The regatta feast | "Add nuts & herbs now"; the feast stays at the 17:00 supper | Nuts and herbs: 0682, 0438. The 17:00 time: written into `demo/regatta/regatta_rules.gd`; the ruling itself: tracker only |
| The regatta feast's readings | Hold the feast with a missing course (no buff); Shared Warmth is a readout | 0682 |
| The camera (#60) | All 8 approved; 5 (strip clear of the news), 6 (edge-pan toggle) and 8 (Follow button) then built | 0801 |
| Art pass 1 | The full pass, about 480 credits (11 models and about 25 icons) | 0941 (B8) |
| The art lock | "Make sure to change the art lock rules to request for paid generation, not block it altogether"; "Subagents may, within approved cap" | 0961 |
| Multiselect (#58) | P1–P10 approved as built | 0791 |
| The infirmary (#26) | "The infirmary should be its own place and that's where residents go to rest and heal" | 0622, 0623 |
| The infirmary building | P1–P3 approved; P4 "Build the buildings panel" (pending: BLD-PANEL) | 0623 |
| Foraging (#22) | P1–P9 approved as built | 0681 |
| Standing orders (#38) | All proposals approved as built | 0711 |
| The chronicle (#10) | P1–P5 approved as built | 0631 |
| Crops (group X) | Approved as built; "note identical crops"; "add flax now" (pending: FLAX) | 0881–0886 |
| The soak test | Keep the pantry top-up and the daily work party | 0921 |
| The pause card | Move it beside the guide when it would cover the Map picker: yes. Superseded on 2026-10-02 by batch 7's ruling 4 (fall back to the top of the alert column) | 0931 leaves it open; 0902 ruling 4 replaces it |
| Ferry and regatta goals, every-dish text | Yes, option (b): "First crossing" and "Regatta day" (pending: GOALS-2); every dish counts everyday dishes (done in 0902) | Goals: tracker only. Every dish: 0902 reconciliation 5 |
| Orchards (#20) | P1–P9 approved as built; the hedge yields the generic `berries` item; raw fruit rows | 0671–0677 (B8) |
| The M3 orchard timing change (group Y) | The direction approved 2026-09-30; the numbers approved 2026-10-01 | 0672 (B8) |

## 2026-10-02

| Topic | Ruling | Recorded in |
|---|---|---|
| Batch 7's eight questions | The recommended option on all eight: the hotpot stays everyday and the feast's main; "a full larder" counts only food the village cooked or brought in; the hall's lamp is dark only while its hearth is out; the pause card falls back to the top of the alert column; the hall's tier-2 fuel factor goes to a follow-up (pending: HALL-FUEL); the two herb patches merge during the Buildings-panel work (pending: BLD-PANEL); the herb moves from pantry to shelf at once, for now; the soak report's self-test runs in CI | 0902 |
| Demolition D5 | P1 (a): furniture's package derived from its type, plus a quarter of the WU; P2: a single-piece removal door; P3 (a): commit and close refuse demolition | 0535, 0536 |
| Demolition D5 readings | R1–R8 confirmed | 0536 |
| Art pass 2 | "Build all": evergreens, nine portraits, the stone Great Hall, flax stages, tapestry, chronicle page, hall banner, wildlife (about 430 credits, cap 450), plus free fixes. The building kit (UX-014) not included | 0951 (B8; it lists the window glow masks and the winter-oak cleanup as the free fixes) |
| Art pass 2 sizes | Approved | 0951, DEC-047 (B8) |
| Art pass 3 | Preserving and brewing props, digging props, free effects (bees, fire, lightning, ice); cap 270; icons held until the style question was ruled | 0971 (B8) |
| The style probe | Approved, cap 95 | 0981 (B8) |
| Art direction | Keep the current world look (DEC-038); item and dish icons keep the 3D-render style; watercolour for portraits, emblems and medallions | 0971 and the art lock's "Style scope" section (B8) |
| Art pass 3 sizes; top bar | Sizes approved; the top-bar icons stay watercolour | 0971, DEC-048 (B8) |
| The Codex review (R01–R07) | Fix R01, R02, R04, R05, R06 now; R03: the infirmary gets its own hearth and fuel; R07: route work now, crowd later | 0993–0998 (RF); 1001 (PF). "Crowd later": tracker only |
| 0995's proposals | P1: no warm-up breaks at the infirmary for non-patients; P2: consolidation leaves the infirmary lit | 0995 (RF) |
| 0997's proposal | Option A as built: a season skip lapses the feast's meal | 0997 (RF) |
| 0998's proposals | P1: the singular leak line counted in every gate (built); P2: a follow-up; P3: when the soak harness is next touched | 0998 (RF) |
| Batch 8 art | The flax, linen and wax icon sheet (cap 12); building thumbnails rendered free during the Buildings-panel work | Icons: 0972 (B8). Thumbnails: tracker only |
| Measures | Replace "U" with per-good measures (weight in the tooltip; plain words on the HUD's quick readouts); "U view" becomes "Underground", keeping the U key | 1011, DEC-049 (MS) |
| Measures proposals | The table and P1–P6, P8 approved; P7 changed to "Apply to demo and game spec"; P9 (b) and P10 (b) | 1011, DEC-049, `ui_ux_controls.md` amended (MS) |
| Demolition D6 | P1, P2, P4–P6 approved; no tool wear for now; P3: "Build hauling (06.4) next" | 0537 |
| Hauling 06.4 | R-H1–R-H7: a provisional clearance class (not closing MOVE-G01); satchels created per haul (dropped to a pile on death, kept in the satchel on cancel); the lowest-slot eligible store, else piles, with the edge-cell approach; the unload in HAUL_OUTPUT; loads sized at assignment; HAUL_SOURCE and HAUL_DESTINATION purposes | 1021, `construction_execution_package.md` §2 (HL) |
| Hauling H0–H2 | Clearance class 1 for mouse, mole, otter and squirrel, PROVISIONAL, closing no MOVE gate; the other proposals as recommended (R-H8–R-H14) | 1022–1024, packet §2 (HL) |
| Batch 8's nine questions | All approved: the stone hall keeps its roundels (only the composed chimney dropped); the cream window glow stays; fifteen evergreens, pine trunk 0.45 m, yew 0.9 m, sink 0.6 m; the bramble edge stays at (-25, 27); group tiles two across with portraits; portraits in the demo inspector's header; the tapestry restaged with margins 120/240; the hazel's nuts show all year for now; future lanes use the waiting icon keys | 0903, DEC-047 (B8) |
| H6 store filters | P1–P8 approved as recommended | 1031 |
| Perf proposals | Approved (the records' recommended options) | Tracker only; 1001–1004 (PF) still read "PROPOSAL" |
| The kitchen | "Fix kitchen now": the cook serves on call | Tracker only; 1005 not yet written (PF, uncommitted) |
| Wrap-up | Near the weekly limit: start the follow-up fixes and these handoff documents; merge everything in flight through CI; then stop | Tracker only |

## 2026-10-07

| Topic | Ruling | Recorded in |
|---|---|---|
| The season skip in the time controls (1653 P1–P3) | Approved as built: it sits in the Run until… menu (no new button or key); the Demo Lab keeps its trigger; it is disabled during a run | 1653 (relayed by the coordinator) |
| "Regatta day" (1651 P1) | (b): "Regatta day counts only a regatta whose feast was served"; a regatta skipped past does not count | 1651 (relayed by the coordinator) |
| "Regatta day", what "served" means (1651) | The stricter reading: it counts only when at least one resident ate the feast's main course | 1651 (relayed by the coordinator) |
| Wildlife (#11) and livelier weather (#34) proposals | All approved as built: W1–W3 (the animals' year and counts; robins flush from residents; reduced motion stills the wildlife) and P1–P4 (P1 settles **Q-D15 as (a)**: lightning strikes trees or open ground only, never a building, no fire spreads; a struck tree's brief smoulder; the events' looks; lightning frequency). Relayed by the coordinator | 1631, 1632 (`feat/demo-wildlife-weather`) |
| HIVES | Proposals P1–P8 approved as built (the inherited apiary, its place, the winter feed first, honey to the old orchard's baskets, winter feeding, the wax shelf, recolonising in spring, the seeded wildlife roll) | 1601 (`feat/demo-hives-preserving`) |
| PRESERVE | Proposals P1–P7 approved as built (dried fruit on the rack, the preserving table, player-ordered batches, rations as a reserve, units not mass, the first-input fetch, salt fish and jam/pickles/cheese not built) | 1611 |
| BREW | Proposals P1–P7 approved as built; the Hearth regatta feast pours mead and the cordial | 1621 |
| Q-D5 and DEC-007 | "Approve and build Q-d5 and dec-007": build the new recipes for the waiting icons (jam, pickles, a plant-milk cheese, ale, cider) and rule DEC-007's drink depiction -- ale and cider follow the mead rule (a feast or table drink only, no intoxication, no effect on Shared Warmth) | 1621; 1625 (`feat/demo-new-recipes`) |
| 1625's proposals | Q1 (the four rows' numbers and the feast pour) **approved as provisional**, to be tuned after a balance run; Q2 (nut cheese) and Q3 (ale from barley, cider from apples) **confirmed as built**; pickles **"both vinegar and salt"**: (b) build the salt-free vinegar pickle now -- apple vinegar from the orchard's apples, then roots in that vinegar, every number PROVISIONAL and beyond the library's formulas by his approval; (a) a salted pickle gated on salt **if the demo has a salt path** -- it has none, so the salted pickle is approved and waits on salt (no salt source invented) | 1625 (`feat/demo-new-recipes`, #234) |
| Crop and ingredient "Uses" | Fix the crop card Uses gaps (roots → pickles, barley → ale, apples → cider and vinegar) and every other ingredient feeding a new or earlier row (honey → jam, nuts → cheese, ...), derived from the recipe rows so it cannot drift | 1625 (follow-up section) |
| Pickles and the follow-up's points | **Exclude potatoes from pickles**: the pickles row takes onions and the other roots, never potato (a recipe change in the row; the derived Uses follow). Kept as built: the apple's uses live in the field guide (no crop card), and the cordial is listed twice for honey and berries (dish and brewery row) | 1625 ("Brendan's ruling on the follow-up") |
| Q-D7, orchard remainders (RG-Y) | (a), "Both, agent proposes numbers": a sapling can be moved once, with a delay of some days; carts are a haul tool for harvest groups. The numbers (the delay, the cart's load and costs) are the lane's PROVISIONAL proposals, put to him | 1721 (`feat/demo-orchard-outings`; relayed by the coordinator) |
| RG-Y's proposals (1721 P1–P12) | All twelve approved, each as option (a), provisional, as built: the 12-day settling, a sapling's first 24 days, the move's 20 + 40 WU and compost 4 U, a 40 U cart at walking pace for wood 4 U and 60 WU, the fresh-table share, the beech hollow protected, the 10% grove reserve, home before dark, one 8 U carry kit, the lead in the news and note only, the latest place note | 1721 (relayed by the coordinator) |

## Standing rules (not dated rulings)

- **Windows builds only when Brendan asks** (his standing instruction; README §3.10).
- **Paid generation by request** (0961; README §3.8).
- **Every approval and ruling goes into the repository**, not only a chat or a tracker (AGENTS.md "Everything lives in
  the repository").

Not Brendan's: decision 0492 (the planner on T, Run-until on G, T no longer the Dig alias) was the coordinator's
resolution of a key clash at batch 5, not a ruling.
