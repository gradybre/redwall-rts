extends RefCounted
## EACH SPECIES' FAVOURITES: the dishes of the recipe book (dish_book.gd) a species likes or dislikes. Decision 0601
## (feature 16). DATA AND DISPLAY ONLY: a resident eating a favourite is noted on its card, and the cook weighs the
## village's tastes when it picks a dish (kitchen.gd THE CHOICE) -- there is NO mood, need or memory effect. The GDD
## defines no favourite-food effect, and the variety-and-favourites mood (feature 17) is not approved.
##
## WHERE EACH ENTRY COMES FROM (`basis`): LIBRARY when the content library ties the species to that very dish; PROPOSAL
## when the library only points that way, or not at all -- each says what it rests on, and each is a question for
## Brendan (decision 0601). A taste is a species' default, never a job lock or a work multiplier (LORE-P12); it says
## nothing about any one resident's own interests (demo_people.json).
##   mole      likes Togget's vegetable soup -- LIBRARY: Togget is a mole (outcast::OUT_character_togget), and the soup
##                   is his
##             likes Wild-beetroot soup -- PROPOSAL: moles' own dish in the books is the deeper'n'ever turnip, tater and
##                   beetroot pie (long_patrol::LP-FOOD-deeper-n-ever-turnip-tater-and-beetroot-pie, "Named
##                   mole-associated pie"); this is its beetroot, as soup
##             likes the Turnip, potato and beetroot pie -- LIBRARY: that very pie, the moles' deeper'n'ever turnip,
##                   tater and beetroot pie (long_patrol::LP-FOOD-deeper-n-ever-turnip-tater-and-beetroot-pie;
##                   martin_warrior::MW_RECIPE_turnip_potato_and_beetroot_pie). Brendan's ruling on decision 0603,
##                   2026-10-01
##   badger    likes Wild-beetroot soup -- PROPOSAL: a badger enjoys the pungent hotroot soup of "pounded thick red
##                   roots" (outcast::OUT_note_05_food_ingredients_prep); the demo's red-root soup
##   squirrel  likes Barleymeal porridge and Vole vegetable stew -- PROPOSAL: Drufo, an elder squirrel, makes a hot
##                   grain and root soup of grain, turnip, carrot and wild onion
##                   (triss::TRI_recipe_drufo_s_hot_grain_and_root_soup); its grain is the porridge's, its roots the
##                   stew's
##   otter     likes Poached dace -- PROPOSAL: the otters are the books' fishers (redwall::RW-CHARACTER-winifred,
##                   "Otter fishing champion"); the river fish the village catches, poached plain
##   mouse     likes Bean hotpot -- PROPOSAL, no library basis: the GDD's Hearth feast serves it first (§5.7)
##   beaver    likes Bean hotpot; dislikes Poached perch or trout and Poached dace -- PROPOSAL: the beaver is not in
##                   the books' food (DEC-041 adds it); a plant-eater, as the animal is
## No species dislikes a dish in the library; the beaver's are the only dislikes, and a proposal.

const LIKE: int = 1
const DISLIKE: int = -1
const LIBRARY: String = "LIBRARY"
const PROPOSAL: String = "PROPOSAL"

## The species with tastes (the demo's cast: demo/assets/manifest.json), lower case as residents.gd keys them.
const SPECIES: Array[StringName] = [&"mouse", &"mole", &"squirrel", &"otter", &"badger", &"beaver"]

## [species, dish key, LIKE or DISLIKE, basis]; the reasons are above.
const ENTRIES: Array = [
	[&"mole", &"soup", LIKE, LIBRARY],
	[&"mole", &"beetroot_soup", LIKE, PROPOSAL],
	[&"mole", &"root_pie", LIKE, LIBRARY],
	[&"badger", &"beetroot_soup", LIKE, PROPOSAL],
	[&"squirrel", &"barleymeal", LIKE, PROPOSAL],
	[&"squirrel", &"vole_stew", LIKE, PROPOSAL],
	[&"otter", &"poached_dace", LIKE, PROPOSAL],
	[&"mouse", &"bean_hotpot", LIKE, PROPOSAL],
	[&"beaver", &"bean_hotpot", LIKE, PROPOSAL],
	[&"beaver", &"fish_stew", DISLIKE, PROPOSAL],
	[&"beaver", &"poached_dace", DISLIKE, PROPOSAL],
]

const NONE: int = -1


static func species_row(species: String) -> int:
	"""A species' row in SPECIES, by its name in any case (the cast says "Badger"); NONE for one with no tastes."""
	return SPECIES.find(StringName(species.to_lower()))


static func taste(row: int, dish_key: StringName) -> int:
	"""How species row `row` takes the dish keyed `dish_key`: LIKE, DISLIKE or 0."""
	if row < 0 or row >= SPECIES.size():
		return 0
	for entry: Array in ENTRIES:
		if entry[0] == SPECIES[row] and entry[1] == dish_key:
			return int(entry[2])
	return 0


static func basis_of(row: int, dish_key: StringName) -> String:
	"""Where species row `row`'s taste for `dish_key` comes from (LIBRARY or PROPOSAL; "" for none)."""
	for entry: Array in ENTRIES:
		if row >= 0 and row < SPECIES.size() and entry[0] == SPECIES[row] and entry[1] == dish_key:
			return String(entry[3])
	return ""


static func species_with(dish_key: StringName, how: int) -> PackedStringArray:
	"""The species that take the dish keyed `dish_key` `how` (LIKE or DISLIKE), in SPECIES order."""
	var out := PackedStringArray()
	for row: int in SPECIES.size():
		if taste(row, dish_key) == how:
			out.append(String(SPECIES[row]))
	return out
