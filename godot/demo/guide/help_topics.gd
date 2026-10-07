extends RefCounted
## THE DEMO'S HELP, as searchable topics (decision 0481; review P1 "Objectives / Help": "browse indexed help ... no
## mandatory wall of controls"). It replaces the game menu's Controls page, a wall of 21 keys: the same keys are
## here, each a topic of its own, among how-to topics in plain words ("Why is a job waiting?"), and a topic that a
## command answers carries that command as a button (ACTION_*: the host runs it -- open the Pantry, the Work screen,
## Village news ...). Data and search only; help_page.gd draws it.

const SearchScript := preload("res://demo/guide/guide_search.gd")

## The commands a topic may link to (the host maps each to what it does).
const ACTION_NONE: StringName = &""
const ACTION_PANTRY: StringName = &"pantry"
const ACTION_KITCHEN: StringName = &"kitchen"
const ACTION_JOBS: StringName = &"jobs"
const ACTION_NEWS: StringName = &"news"
const ACTION_RESIDENTS: StringName = &"residents"
const ACTION_WATER: StringName = &"water"
const ACTION_DIG: StringName = &"dig"
const ACTION_FIELD_GUIDE: StringName = &"field_guide"
const ACTION_PROJECTS: StringName = &"projects"
const ACTION_PRACTICE: StringName = &"practice"
const ACTION_GUIDE: StringName = &"guide"
## The playtest log's folder (decision 0562).
const ACTION_LOGS: StringName = &"logs"
## The Heating fuel breakdown (decision 0571, demo/winter/fuel_panel.gd).
const ACTION_FUEL: StringName = &"fuel"
const ACTION_LABELS: Dictionary = {
	ACTION_PANTRY: "Open the Pantry (K)", ACTION_KITCHEN: "Open the Kitchen tab", ACTION_JOBS: "Open Work (J)",
	ACTION_NEWS: "Open Village news (N)", ACTION_RESIDENTS: "Open Residents (L)", ACTION_WATER: "Open the Water panel",
	ACTION_DIG: "Open the Dig tool (B)", ACTION_FIELD_GUIDE: "Open the field guide", ACTION_PROJECTS: "Open projects",
	ACTION_PRACTICE: "Open practice stories", ACTION_GUIDE: "Show the guide card", ACTION_FUEL: "Open Heating fuel",
	ACTION_LOGS: "Open the log folder",
}

## [title, key(s), what it does, keywords, action]. The how-to topics first, then one per key.
const TOPICS: Array = [
	["Select and inspect a resident", "Left click", "Click a resident to select them: the Demo party panel (left) shows what they are doing, their skills, how well fed they are and what you can order them to do. Shift+click adds or removes one; drag a box to select several.", "select inspect resident villager party panel who", ACTION_RESIDENTS],
	["Bring in a harvest", "Right click a bed", "A ripe bed is harvested by a resident: select one and right-click the bed, or click the bed and press Harvest. Food counts once it is carried and shelved in a store; the Pantry shows what arrived and when it spoils.", "harvest ripe bed crop pantry store food", ACTION_PANTRY],
	["Plant a bed", "Click a bed, Plant…", "Click an empty bed and press Plant…: the crop picker lists every crop, the ones that can be sown now first, with how long each takes and what it yields. Radish ripens soonest.", "plant sow seed bed crop grow", ACTION_NONE],
	["Feed the village: the kitchen", "K, Kitchen tab", "The cook makes porridge for breakfast (07:00) and vegetable soup for supper (17:00) from the pantry's grain and roots -- or, while the stores hold fresh fish and roots, the fish stew in the soup's place -- with water from the butt and a little wood. The Kitchen tab shows the plan, what is short and how to fix it.", "kitchen supper breakfast cook meal eat porridge soup fish stew fed hungry", ACTION_KITCHEN],
	["Go fishing", "Water panel, Fishing", "The Water panel's Fishing section chooses a trip -- its site, method and fish -- and shows the stock, quota, expected catch, gear and risk before Authorise trip sends the fishers out (a boat takes two). The catch goes into the pantry: fresh fish keeps two days, so the kitchen cooks it in the fish stew, or the drying rack keeps it as dried fish.", "fish fishing boat trip catch net trap ice jetty rack dried mill flour gear", ACTION_WATER],
	["Why is a job waiting?", "J", "The Work screen lists every task, blocked first, and says why each waits: no store has room, nobody can reach it, nobody eligible is free. Reassign, prioritise, pause or cancel it there.", "job work task waiting blocked why crew priority", ACTION_JOBS],
	["A button is greyed out", "Hover it", "Every action's button has a card: hover it (or focus it) to read what it will do, who will do it, what it costs -- and, when it can't be done now, why and what to do first (\"To fix:\").", "refused disabled greyed cannot why card fix", ACTION_NONE],
	["Ferry and regatta", "Water panel, Ferry and Regatta; Feast", "The ferry rows the far copse's windfall across the run to the ferry stage on a timetable (Gather the far copse, then haulers stack it); anyone may ride it when it is the quicker way, and storms, floods or ice close it. The regatta is a race and a feast once a season, the first in summer: pick its day and host, check the preview (what the feast needs and leaves), and Hold it -- or skip the season at no cost. The village goals First crossing and Regatta day (O, Goals) mark the first of each.", "ferry boat cross far copse wood windfall timetable passenger regatta race feast host occasion chronicle goal", ACTION_WATER],
	["Build a bridge", "Water panel", "The Water panel's Bridges section steps through the sites (◀ Site ▶, or Span two banks…) with each kind's cost: a plank footbridge (planks, sawn from wood) or a log bridge (one log). A loaded resident never swims, so a bridge is the dry way over for carriers.", "bridge cross stream water planks log ford", ACTION_WATER],
	["Dig a tunnel", "B", "Press B (or the party panel's Dig tunnel) with a mouse, mole or squirrel selected, and drag from where it starts to where it ends (8 m at least). Tunnels are walked in any weather, lead to burrow homes and root cellars, and drain or water a bed above them once you fit it an outlet (the bed's Tunnel outlet).", "dig tunnel mole route dry burrow cellar", ACTION_DIG],
	["Protect beds from frost and wet", "Click a bed", "Frost nights are announced at noon the day before: Cover a bed with a crop (4 °C warmer for the night). A waterlogged bed stops growing: Drain it, raise it with tunnel earth, or run a tunnel under it and fit a drain outlet.", "frost cover drain wet waterlogged raise bank bed weather", ACTION_NONE],
	["Keep the village warm in winter", "Heating fuel, the top bar", "From a cold autumn day through winter every hearth -- each burrow home's and the hall's -- burns wood from the stores: 4 U a day in winter, 2 U on a spring or autumn day under 10 °C. The top bar's Heating fuel says how many days the wood lasts; under 2 it turns clay and the Firewood order in the woods goes urgent. A hearth out of wood lets its room cool toward the frost. Below 0 °C, outdoors or in a cold room, residents build up exposure: after 4 hours they are Chilled -- working at 80% -- and go to warm up by a lit hearth. Gather deadfall or fell in a forestry zone before winter; click Heating fuel for the breakdown, the twelve-day winter target and the emergency choices.", "winter heat heating fuel firewood wood hearth cold chilled warm exposure frost fire", ACTION_FUEL],
	["Pause and speed", "Space, F1 F2 F3, G", "Space pauses; paused, Space (or the pause card's Resume) clears your pause, a planning pause or a critical pause -- never the game menu's. The HUD's 1x, 2x and 4x buttons set the speed, and Run until… (G, the button by 4x) runs the village to dawn, dusk, the next meal, a project, a harvest or a warning, then pauses saying so. F1, F2 and F3 set 1x, 2x and 4x. The same menu's Skip to next season asks first, then runs the crops, stores, weather and hearths to 06:00 on the next season's first day; walking, work, meals and the cold are not lived. Paused, you can still select, inspect and give orders: they are carried out on resume.", "pause speed time fast slow resume run until dawn dusk skip season", ACTION_NONE],
	["Find anything: the object list", "F6", "The object list names every resident, crop bed, tree, bridge, tunnel mouth and room; Enter on a row selects it and centres the view on it.", "object list find select keyboard bed tree bridge mouth room", ACTION_NONE],
	["Easier to read, steer or hear", "Game menu, Settings", "Settings holds four presets -- Large readable, Keyboard planner, Reduced motion and Quiet focus -- each previewed before it applies, and every setting on its own; under Time, Pause while planning and Pause on a critical incident.", "accessibility preset large readable keyboard reduced motion quiet focus contrast tooltip settings planning critical", ACTION_NONE],
	["What happened? Village news", "N", "Village news keeps every warning and report, newest first, with Go to for its place; Needs attention lists what is still open.", "news history warning happened incident notice", ACTION_NEWS],
	["Find a resident", "L", "Residents (L) lists everyone: where they are, what they are doing, what they go back to. Click a row to select them and centre the camera on them.", "residents list find who where roster", ACTION_RESIDENTS],
	["Plan the season", "T, the Farm panel's Planner (T)", "The seasonal planner shows every bed at a glance -- what needs attention, what is ripe soon -- the season's calendar with the frost and meals, soil plans for each bed, and the record of each day's food. Compare… in a bed's panel ranks the beds side by side on the map.", "planner season calendar plan soil compare record forecast beds", ACTION_NONE],
	["Map layers", "V, the Map layer picker", "One map layer shows at a time, each answering one question: soil moisture, ripeness, where they can wade, swim or dive, the woods' zones, the tunnels below. V steps through them.", "map layer overlay moisture ripeness water range woods", ACTION_NONE],
	["Name a project of your own", "Village guide (O), Projects", "Pin up to three projects: a name, the places it is about and a simple measure (ready food, wood, bridges ...). When its measure is reached the village news records it.", "project goal pin measure chronicle", ACTION_PROJECTS],
	["Look something up: the field guide", "Village guide (O), Field guide", "The field guide lists the demo's crops and dishes, materials, buildings and stations, residents' skills and water safety: what each is for, what it needs, alternatives and where it is here.", "field guide almanac crop dish material building skill water safety", ACTION_FIELD_GUIDE],
	["Practise a situation", "Village guide (O), Practice", "Practice stories are short situations kept apart from your village -- a loaded crew at the stream, a delivery with nowhere to go, a winter pantry -- each with a restart and a debrief. Nothing they do touches the village.", "practice story lesson try scenario", ACTION_PRACTICE],
	["The first-village guide", "Game menu, Objectives (O)", "One objective at a time, each done only by what really happens in the village. Hide it, or reopen it, from the game menu or Objectives (O): nothing is granted or lost either way.", "guide objective tutorial skip reopen first", ACTION_GUIDE],
	["Saving", "", "The demo can't save yet: quitting or restarting loses this village.", "save load quit restart", ACTION_NONE],
	["Something went wrong? Report it", "F12, Settings", "Press F12 (Fn+F12 on a Mac) the moment you see a bug, a crash or a freeze: it marks the playtest log with the time and what happened just before. The logs are in %APPDATA%\\Godot\\app_userdata\\Redwall Demo\\logs on Windows and ~/Library/Application Support/Godot/app_userdata/Redwall Demo/logs on a Mac (Redwall RTS in place of Redwall Demo when run from the project); send Brendan the newest playtest file. Settings, Playtest log, opens the folder and copies a report to paste.", "bug crash freeze report log problem error mark send playtest", ACTION_LOGS],
]
## The demo's keys and clicks, one topic each (they were the Controls page).
const KEY_ROWS: Array = [
	["Left click", "Select a resident (Shift: add or take them out); a bed, tunnel, tree or bridge site opens its panel"],
	["Left drag", "Box-select residents (Shift: add to the selection)"],
	["Right click", "Order the selection: move there, or work the spot, bed, tree, heap or water clicked"],
	["Shift + right click", "Queue the order at the end of the selection's order lists"],
	["R", "Release the selection to its own routine"],
	["Esc", "Close the top pop-up; then clear the selection; then open the game menu"],
	["W A S D, arrows", "Pan the camera"],
	["Q / E, middle drag", "Turn the camera (middle drag also tilts it)"],
	["Wheel, Page Up / Down", "Zoom"],
	["Home", "Reset the view"],
	["Space", "Pause; or, paused, Resume (your pause, a planning pause, a critical pause)"],
	["F1 / F2 / F3", "Speed 1x, 2x, 4x (a pause stays a pause)"],
	["G", "Run until dawn, dusk, the next meal, a project, a harvest or a warning (the button by 4x); or skip to the next season"],
	["F6", "The object list: every resident, bed, tree, bridge, mouth and room; Enter selects and centres"],
	["B", "Dig tool: drag a tunnel (Enter digs a piece laid by clicks; Backspace takes a point back)"],
	["H / C in the Dig tool", "Place a burrow home / a root cellar"],
	["U", "Underground view"],
	["V", "Step the map layers"],
	["K", "The Pantry"],
	["T", "The seasonal planner: every bed at a glance, the season's calendar, soil plans and the record"],
	["J", "Work: tasks, crews and projects"],
	["L", "Residents"],
	["N", "Village news"],
	["O", "The village guide: objectives, projects, field guide, help, practice"],
	["F7", "Keyboard focus: world, then the right column, the left column, the map layers, and the guide card or the offer card while shown"],
	["Tab / Shift+Tab", "Next / previous button where the focus is"],
	["Enter / Space", "Press the focused button"],
	["F8", "Demo Lab"],
	["F11", "Full screen"],
	["F12", "Mark a problem in the playtest log (for a bug report)"],
]

var _entries: Array[SearchScript.Entry] = []


func _init() -> void:
	"""Index every topic and key once."""
	for topic: Array in TOPICS:
		_entries.append(SearchScript.Entry.new(String(topic[0]), "%s %s" % [topic[1], topic[3]], String(topic[2])))
	for row: Array in KEY_ROWS:
		_entries.append(SearchScript.Entry.new(String(row[1]), "key %s" % row[0], String(row[1])))


func count() -> int:
	"""How many topics, the keys included."""
	return TOPICS.size() + KEY_ROWS.size()


func search(query: String) -> PackedInt32Array:
	"""The topics matching `query`, best first (guide_search.gd); all, in order, for an empty one."""
	return SearchScript.search(_entries, query)


func title_of(k: int) -> String:
	"""Topic `k`'s heading (a key's: what it does)."""
	return String(TOPICS[k][0]) if k < TOPICS.size() else String(KEY_ROWS[k - TOPICS.size()][1])


func keys_of(k: int) -> String:
	"""Topic `k`'s key or where it is ('' for none)."""
	return String(TOPICS[k][1]) if k < TOPICS.size() else String(KEY_ROWS[k - TOPICS.size()][0])


func body_of(k: int) -> String:
	"""Topic `k`'s text ('' for a key: its heading says it)."""
	return String(TOPICS[k][2]) if k < TOPICS.size() else ""


func action_of(k: int) -> StringName:
	"""The command topic `k` links to (ACTION_NONE for none)."""
	return StringName(TOPICS[k][4]) if k < TOPICS.size() else ACTION_NONE


static func action_label(action: StringName) -> String:
	"""A linked command's button words."""
	return String(ACTION_LABELS.get(action, ""))
