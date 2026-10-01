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
const ACTION_LABELS: Dictionary = {
	ACTION_PANTRY: "Open the Pantry (K)", ACTION_KITCHEN: "Open the Kitchen tab", ACTION_JOBS: "Open Work (J)",
	ACTION_NEWS: "Open Village news (N)", ACTION_RESIDENTS: "Open Residents (L)", ACTION_WATER: "Open the Water panel",
	ACTION_DIG: "Open the Dig tool (B)", ACTION_FIELD_GUIDE: "Open the field guide", ACTION_PROJECTS: "Open projects",
	ACTION_PRACTICE: "Open practice stories", ACTION_GUIDE: "Show the guide card",
}

## [title, key(s), what it does, keywords, action]. The how-to topics first, then one per key.
const TOPICS: Array = [
	["Select and inspect a resident", "Left click", "Click a resident to select it: the Demo party panel (left) shows what it is doing, its skills, how well fed it is and what you can order it to do. Shift+click adds or removes one; drag a box to select several.", "select inspect resident villager party panel who", ACTION_RESIDENTS],
	["Bring in a harvest", "Right click a bed", "A ripe bed is harvested by a resident: select one and right-click the bed, or click the bed and press Harvest. Food counts once it is carried and shelved in a store; the Pantry shows what arrived and when it spoils.", "harvest ripe bed crop pantry store food", ACTION_PANTRY],
	["Plant a bed", "Click a bed, Plant…", "Click an empty bed and press Plant…: the crop picker lists every crop, the ones that can be sown now first, with how long each takes and what it yields. Radish ripens soonest.", "plant sow seed bed crop grow", ACTION_NONE],
	["Feed the village: the kitchen", "K, Kitchen tab", "The cook makes porridge for breakfast (07:00) and vegetable soup for supper (17:00) from the pantry's grain and roots, with water from the butt and a little wood. The Kitchen tab shows the plan, what is short and how to fix it.", "kitchen supper breakfast cook meal eat porridge soup fed hungry", ACTION_KITCHEN],
	["Why is a job waiting?", "J", "The Work screen lists every task, blocked first, and says why each waits: no store has room, nobody can reach it, nobody eligible is free. Reassign, prioritise, pause or cancel it there.", "job work task waiting blocked why crew priority", ACTION_JOBS],
	["A button is greyed out", "Hover it", "Every action's button has a card: hover it (or focus it) to read what it will do, who will do it, what it costs -- and, when it can't be done now, why and what to do first (\"To fix:\").", "refused disabled greyed cannot why card fix", ACTION_NONE],
	["Build a bridge", "Water panel", "The Water panel's Bridges section steps through the sites (◀ Site ▶, or Span two banks…) with each kind's cost: a plank footbridge (planks, sawn from wood) or a log bridge (one log). A loaded resident never swims, so a bridge is the dry way over for carriers.", "bridge cross stream water planks log ford", ACTION_WATER],
	["Dig a tunnel", "B", "Press B (or the party panel's Dig tunnel) with a mouse, mole or squirrel selected, and drag from where it starts to where it ends (8 m at least). Tunnels are walked in any weather, drain the beds above them and lead to burrow homes and root cellars.", "dig tunnel mole route dry burrow cellar", ACTION_DIG],
	["Protect beds from frost and wet", "Click a bed", "Frost nights are announced at noon the day before: Cover a bed with a crop (4 °C warmer for the night). A waterlogged bed stops growing: Drain it, raise it with tunnel earth, or run a tunnel under it.", "frost cover drain wet waterlogged raise bank bed weather", ACTION_NONE],
	["Pause and speed", "Space, 1x 2x 4x", "Space pauses and resumes; the HUD's 1x, 2x and 4x buttons set the speed. Paused, you can still select, inspect and give orders: they are carried out on resume.", "pause speed time fast slow", ACTION_NONE],
	["What happened? Village news", "N", "Village news keeps every warning and report, newest first, with Go to for its place; Needs attention lists what is still open.", "news history warning happened incident notice", ACTION_NEWS],
	["Find a resident", "L", "Residents (L) lists everyone: where it is, what it is doing, what it goes back to. Click a row to select it and centre the camera on it.", "residents list find who where roster", ACTION_RESIDENTS],
	["Map layers", "V, the Map layer picker", "One map layer shows at a time, each answering one question: soil moisture, ripeness, where they can wade, swim or dive, the woods' zones, the tunnels below. V steps through them.", "map layer overlay moisture ripeness water range woods", ACTION_NONE],
	["Name a project of your own", "Village guide (O), Projects", "Pin up to three projects: a name, the places it is about and a simple measure (ready food, wood, bridges ...). When its measure is reached the village news records it.", "project goal pin measure chronicle", ACTION_PROJECTS],
	["Look something up: the field guide", "Village guide (O), Field guide", "The field guide lists the demo's crops and dishes, materials, buildings and stations, residents' skills and water safety: what each is for, what it needs, alternatives and where it is here.", "field guide almanac crop dish material building skill water safety", ACTION_FIELD_GUIDE],
	["Practise a situation", "Village guide (O), Practice", "Practice stories are short situations kept apart from your village -- a loaded crew at the stream, a delivery with nowhere to go, a winter pantry -- each with a restart and a debrief. Nothing they do touches the village.", "practice story lesson try scenario", ACTION_PRACTICE],
	["The first-village guide", "Game menu, Objectives (O)", "One objective at a time, each done only by what really happens in the village. Hide it, or reopen it, from the game menu or Objectives (O): nothing is granted or lost either way.", "guide objective tutorial skip reopen first", ACTION_GUIDE],
	["Saving", "", "The demo can't save yet: quitting or restarting loses this village.", "save load quit restart", ACTION_NONE],
]
## The demo's keys and clicks, one topic each (they were the Controls page).
const KEY_ROWS: Array = [
	["Left click", "Select a resident (Shift: add or take it out); a bed, tunnel, tree or bridge site opens its panel"],
	["Left drag", "Box-select residents (Shift: add to the selection)"],
	["Right click", "Order the selection: move there, or work the spot, bed, tree, heap or water clicked"],
	["Shift + right click", "Queue the order at the end of the selection's order lists"],
	["R", "Release the selection to its own routine"],
	["Esc", "Close the top pop-up; then clear the selection; then open the game menu"],
	["W A S D, arrows", "Pan the camera"],
	["Q / E, middle drag", "Turn the camera (middle drag also tilts it)"],
	["Wheel, Page Up / Down", "Zoom"],
	["Home", "Reset the view"],
	["Space", "Pause or resume"],
	["B or T", "Dig tool: drag a tunnel (Enter digs a piece laid by clicks; Backspace takes a point back)"],
	["H / C in the Dig tool", "Place a burrow home / a root cellar"],
	["U", "Underground view"],
	["V", "Step the map layers"],
	["K", "The Pantry"],
	["J", "Work: tasks, crews and projects"],
	["L", "Residents"],
	["N", "Village news"],
	["O", "The village guide: objectives, projects, field guide, help, practice"],
	["F7", "Keyboard focus: world, then the right column, then the left column, then the map layers"],
	["Tab / Shift+Tab", "Next / previous button where the focus is"],
	["Enter / Space", "Press the focused button"],
	["F8", "Demo Lab"],
	["F11", "Full screen"],
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
