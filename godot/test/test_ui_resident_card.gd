extends "res://test/framework/test_case.gd"
## Coverage for UI-SET-036's composition: UXV-019..022's exact strings.
##
## The card is the last place a store value is transformed before a player reads it, so every
## test here asserts on the FINAL STRING against a figure this file states independently --
## GDD §5.1's 7500 initial needs, §5.2's 250/hour hunger decay and its size multipliers, §5.3's
## 5000*L*L level curve. Asserting that the card "called the store" would pass against a card
## that prints a constant.
##
## Two of these tests exist because the shipped card broke a requirement in terms:
##   * `test_the_percent_is_the_players_value_and_never_the_basis_points` is UXV-020's own
##     sentence -- "never expose 7500 as the player-facing 75% value".
##   * `test_the_visible_label_is_fullness_and_the_number_is_not_inverted` is UXV-021's, both
##     halves: the word changes AND the number does not.

const UiResidentCard := preload("res://scripts/ui/ui_resident_card.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const UiArt := preload("res://ui/ui_art.gd")

## GDD §5.1: "all five needs 7500, health 100" at spawn. Stated here, not imported.
const SPAWN_NEED: int = 7500
const SPAWN_HEALTH: int = 100
## GDD §5.2: hunger 250 need points/hour before multipliers; small multiplier 1000/1000.
## 250 points of 10000 is 2.50 percentage points, and the sign is decay.
const SMALL_HUNGER_RATE: String = "-2.50 pp/h"
## Medium is x1200/1000, so 300 points/hour: 3.00 percentage points.
const MEDIUM_HUNGER_RATE: String = "-3.00 pp/h"
## GDD §5.1 gives every active starter skill 20000 XP; §5.3's curve puts level L at 5000*L*L,
## so 20000 XP is exactly level 2 and the next threshold is 5000*3*3.
const STARTER_SKILL_XP: int = 20000
const STARTER_SKILL_LEVEL: int = 2
const NEXT_LEVEL_THRESHOLD: int = 45000

var _residents: ResidentsScript = null
var _needs: NeedsScript = null
var _card: UiResidentCard = null


func before_each() -> void:
	"""Build a real resident store with the GDD §5.1 cohort, and a card over it."""
	_residents = ResidentsScript.new()
	_needs = _residents.needs()
	_card = UiResidentCard.new()


func after_each() -> void:
	"""Drop the stores; they are plain RefCounted and own no node."""
	_card = null
	_needs = null
	_residents = null


func _named_slot() -> int:
	"""The slot of the one starter the §5.1 cohort names, found rather than assumed."""
	for slot: int in ResidentsScript.RESIDENT_CAPACITY:
		if _residents.is_alive(slot) and _residents.is_named(slot):
			return slot
	fail("the §5.1 cohort names exactly one starter, and none was found")
	return 0


func _spawn(species_key: StringName) -> int:
	"""Spawn one resident of a species and return its slot, asserting the spawn succeeded."""
	var made: ResidentsScript.OpResult = _residents.spawn(species_key)
	assert_true(made.ok, "a %s is spawned (error: %s)" % [species_key, made.error])
	return made.value


# --- UXV-020: the exact percent --------------------------------------------------------------

func test_the_percent_is_the_players_value_and_never_the_basis_points() -> void:
	"""UXV-020: "never expose 7500 as the player-facing 75% value"."""
	assert_equal(UiResidentCard.percent_text(7500), "75%", "7500 basis points is 75 percent")
	assert_equal(UiResidentCard.percent_text(0), "0%", "the floor is 0 percent")
	assert_equal(UiResidentCard.percent_text(10000), "100%", "the ceiling is 100 percent")


func test_the_percent_keeps_up_to_two_decimals_and_trims_trailing_zeroes() -> void:
	"""§5's rule, worked through every shape it names."""
	assert_equal(UiResidentCard.percent_text(7501), "75.01%", "a hundredth survives")
	assert_equal(UiResidentCard.percent_text(7510), "75.1%", "a trailing zero is trimmed")
	assert_equal(UiResidentCard.percent_text(7550), "75.5%", "and so is a half")
	assert_equal(UiResidentCard.percent_text(1), "0.01%", "one basis point is a hundredth")
	assert_equal(UiResidentCard.percent_text(9999), "99.99%", "one short of the ceiling")


func test_the_percent_conversion_is_exact_across_the_whole_scale() -> void:
	"""Every value 0-10000 must convert to a string that reads back as the same basis points.

	This is the property, not a sample: parsing the printed percent back to hundredths of a
	percent must return the original integer for all 10001 values.
	"""
	var wrong: int = 0
	for value: int in range(0, NeedsScript.NEED_MAX + 1):
		var text: String = UiResidentCard.percent_text(value)
		if int(round(text.trim_suffix("%").to_float() * 100.0)) != value:
			wrong += 1
	assert_equal(wrong, 0, "all 10001 values round-trip exactly")


func test_a_percent_string_never_carries_the_basis_point_scale() -> void:
	"""A percent that still says 10000 would be the defect this requirement names."""
	assert_false(UiResidentCard.percent_text(10000).contains("10000"),
		"100% does not print the scale it came from")
	assert_false(UiResidentCard.percent_text(7500).contains("7500"),
		"nor does 75% print its basis points")


# --- UXV-020: the per-simulated-hour rate ----------------------------------------------------

func test_the_rate_is_signed_percentage_points_per_simulated_hour() -> void:
	"""§5's worked example: -250 need points/hour is -2.50 pp/h."""
	assert_equal(UiResidentCard.rate_text(-250 * 1000), SMALL_HUNGER_RATE,
		"the GDD §5.2 baseline hunger decay")
	assert_equal(UiResidentCard.rate_text(1200 * 1000), "+12.00 pp/h", "rest in a bed is signed")
	assert_equal(UiResidentCard.rate_text(0), "0.00 pp/h", "zero carries no sign")


func test_the_rate_rounds_to_nearest_with_ties_away_from_zero() -> void:
	"""§5: "display-only rounding is nearest with ties away from zero"."""
	assert_equal(UiResidentCard.rate_hundredths(1500), 2, "a positive tie rounds up")
	assert_equal(UiResidentCard.rate_hundredths(-1500), -2, "a negative tie rounds down")
	assert_equal(UiResidentCard.rate_hundredths(1499), 1, "just below the tie rounds down")
	assert_equal(UiResidentCard.rate_hundredths(-1499), -1, "and so does its negative")


# --- UXV-021: Fullness, not Hunger, and not inverted -----------------------------------------

func test_the_visible_label_is_fullness_and_the_number_is_not_inverted() -> void:
	"""UXV-021 in both halves: the word changes, and 7500 stays 75% rather than becoming 25%."""
	var slot: int = _spawn(&"mouse")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the five rows fill")
	var row: UiResidentCard.Row = _card.row(NeedsScript.NEED_HUNGER)
	assert_equal(row.label, "Fullness", "the visible label is Fullness")
	assert_equal(row.basis_points, SPAWN_NEED, "over the store's own §5.1 spawn value")
	assert_equal(row.value_text, "75%", "shown as satisfaction, not severity")
	assert_false(row.value_text.contains("25"), "25% would be the inverted reading")


func test_the_underlying_hunger_field_is_named_in_accessible_detail() -> void:
	"""§5: "with Hunger/fullness in accessible detail"."""
	var slot: int = _spawn(&"mouse")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the five rows fill")
	var row: UiResidentCard.Row = _card.row(NeedsScript.NEED_HUNGER)
	assert_true(row.accessible.contains("hunger"), "the store field is disclosed: %s"
		% row.accessible)
	assert_true(row.accessible.contains("Fullness"), "beside the visible label")


# --- UXV-020: five independent rows ----------------------------------------------------------

func test_five_independent_rows_are_composed_with_their_own_labels() -> void:
	"""UXV-020 requires five rows. GDD §4.2 fixes exactly five need columns."""
	var slot: int = _spawn(&"mouse")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the five rows fill")
	assert_equal(_card.row_count(), NeedsScript.NEED_COUNT, "one row per need column")
	var labels: PackedStringArray = PackedStringArray()
	for index: int in _card.row_count():
		labels.append(_card.row(index).label)
	assert_equal(String(", ").join(labels), "Fullness, Rest, Comfort, Social, Purpose",
		"in GDD §4.2's own column order")


func test_each_row_carries_its_own_value_rather_than_one_shared_figure() -> void:
	"""Five rows that all print the same number would not be five independent rows."""
	var slot: int = _spawn(&"mouse")
	assert_true(_needs.apply_need_event(slot, NeedsScript.NEED_REST, -2500).ok,
		"rest is driven down to 5000")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the five rows fill")
	assert_equal(_card.row(NeedsScript.NEED_REST).value_text, "50%", "rest reads 50%")
	assert_equal(_card.row(NeedsScript.NEED_HUNGER).value_text, "75%",
		"and fullness is unchanged at 75%")


# --- §5: an unpublished rate says so ---------------------------------------------------------

func test_the_published_hunger_rate_reaches_the_row_with_its_size_multiplier() -> void:
	"""§5: "Use the actual effective model context". A medium resident decays faster."""
	var small: int = _spawn(&"mouse")
	var medium: int = _spawn(&"otter")
	assert_true(_card.fill_needs(_residents, _needs, small), "the mouse's rows fill")
	assert_equal(_card.row(NeedsScript.NEED_HUNGER).rate_text, SMALL_HUNGER_RATE,
		"the small size multiplier is applied")
	assert_true(_card.fill_needs(_residents, _needs, medium), "the otter's rows fill")
	assert_equal(_card.row(NeedsScript.NEED_HUNGER).rate_text, MEDIUM_HUNGER_RATE,
		"and the medium one is a different, larger figure")


func test_the_winter_multiplier_reaches_the_rate_the_player_reads() -> void:
	"""REQ-SET-143's x1.20 must change the displayed rate, or it is not the effective one."""
	var slot: int = _spawn(&"mouse")
	assert_true(_needs.set_winter(true).ok, "winter is in force")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the five rows fill")
	assert_equal(_card.row(NeedsScript.NEED_HUNGER).rate_text, "-3.00 pp/h",
		"250 x 1.20 is 300 points/hour, which is 3.00 percentage points")


func test_the_four_unpublished_rates_say_so_rather_than_printing_zero() -> void:
	"""§5: "If rate isn't published, say Rate unavailable". A fabricated 0.00 would be worse."""
	var slot: int = _spawn(&"mouse")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the five rows fill")
	for need: int in [NeedsScript.NEED_REST, NeedsScript.NEED_COMFORT,
			NeedsScript.NEED_SOCIAL, NeedsScript.NEED_PURPOSE]:
		var row: UiResidentCard.Row = _card.row(need)
		assert_false(row.has_rate, "%s publishes no effective rate" % row.label)
		assert_equal(row.rate_text, UiResidentCard.RATE_UNAVAILABLE,
			"%s says so in §5's own words" % row.label)
		assert_false(row.rate_text.contains("0.00"), "%s prints no zero" % row.label)


func test_the_fullness_row_does_have_a_published_rate() -> void:
	"""The unavailable state must not be the universal answer either."""
	var slot: int = _spawn(&"mouse")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the five rows fill")
	assert_true(_card.row(NeedsScript.NEED_HUNGER).has_rate,
		"hunger's effective rate IS published by needs.gd")


# --- refusal, never a plausible row ----------------------------------------------------------

func test_a_slot_with_no_resident_refuses_by_name() -> void:
	"""REQ: no sentinel. An empty slot must not compose a card of zeroes."""
	assert_false(_card.fill_needs(_residents, _needs, 0), "an empty slot refuses")
	assert_equal(_card.last_refusal(), UiResidentCard.REFUSE_NOT_A_RESIDENT,
		"with the exact code")


func test_absent_stores_refuse_by_name() -> void:
	"""A null store is a different fault from an empty slot and is named differently."""
	assert_false(_card.fill_needs(null, _needs, 0), "no residents store refuses")
	assert_equal(_card.last_refusal(), UiResidentCard.REFUSE_NO_STORES, "with its own code")


func test_a_successful_fill_clears_the_refusal() -> void:
	"""A stale refusal code after a good call would misreport the next reader."""
	assert_false(_card.fill_needs(_residents, _needs, 0), "the empty slot refuses")
	var slot: int = _spawn(&"mouse")
	assert_true(_card.fill_needs(_residents, _needs, slot), "the real slot fills")
	assert_equal(_card.last_refusal(), UiResidentCard.REFUSE_NONE, "and clears the code")


# --- UXV-019 and UXV-022: identity, health, activity and skills ------------------------------

func test_the_heading_is_the_name_alone_and_the_species_is_its_own_line() -> void:
	"""§4.1: "A name is a heading, not a dense concatenation ... in one line"."""
	assert_equal(_residents.spawn_initial_settlement().value,
		ResidentsScript.INITIAL_POPULATION, "the §5.1 cohort is created")
	var warden: int = _named_slot()
	var heading: String = UiResidentCard.heading_text(_residents, warden)
	assert_true(_residents.is_named(warden), "the warden carries the authored name")
	assert_false(heading.contains("mouse"), "the heading is the name only: '%s'" % heading)
	assert_true(UiResidentCard.identity_text(_residents, _needs, warden).contains("mouse"),
		"and the species is on the identity line")


func test_an_unnamed_resident_is_named_as_unnamed_rather_than_left_blank() -> void:
	"""A blank heading would read as a failed load rather than an unnamed resident."""
	var slot: int = _spawn(&"mole")
	assert_false(_residents.is_named(slot), "this one has no authored name")
	assert_equal(UiResidentCard.heading_text(_residents, slot),
		UiResidentCard.UNNAMED_HEADING, "so the heading says so")


func test_health_stays_on_its_own_0_to_100_scale() -> void:
	"""§5: "Health remains 0-100, e.g. 100 / 100". It is not a percent and not basis points."""
	var slot: int = _spawn(&"mouse")
	assert_equal(UiResidentCard.health_text(_needs, slot), "Health %d / 100" % SPAWN_HEALTH,
		"health is printed on its own scale")
	assert_false(UiResidentCard.health_text(_needs, slot).contains("%"),
		"and never as a percent")


func test_the_activity_line_uses_the_published_status_and_job_state() -> void:
	"""UXV-022: "job/role/mood/health use actual fields"."""
	var slot: int = _spawn(&"mouse")
	var jobs: JobsScript = JobsScript.new(_residents)
	var text: String = UiResidentCard.activity_text(_needs, jobs, slot)
	assert_true(text.contains("Active"), "the published ResidentStatus: '%s'" % text)
	assert_true(text.contains(UiResidentCard.NO_JOB_AGENT),
		"and the job store's own answer, not an invented occupation")


func test_a_spawned_idle_agent_reads_as_idle_rather_than_absent() -> void:
	"""An agent row with no job is a different fact from no agent row at all."""
	var slot: int = _spawn(&"mouse")
	var jobs: JobsScript = JobsScript.new(_residents)
	assert_true(jobs.spawn_agent(slot).ok, "the resident gets a job agent")
	var text: String = UiResidentCard.activity_text(_needs, jobs, slot)
	assert_true(text.contains(UiResidentCard.JOB_IDLE), "it reads as idle: '%s'" % text)


func test_the_skill_row_carries_level_exact_xp_and_the_next_threshold() -> void:
	"""UXV-022: "Skills include level and current/next-threshold XP"."""
	assert_equal(_residents.spawn_initial_settlement().value,
		ResidentsScript.INITIAL_POPULATION, "the §5.1 cohort is created")
	var slot: int = _named_slot()
	assert_equal(_residents.skill_xp_of(slot, 0).value, STARTER_SKILL_XP,
		"the store holds §5.1's starting XP")
	var text: String = UiResidentCard.skill_text(_residents, slot, 0)
	assert_true(text.contains("level %d" % STARTER_SKILL_LEVEL),
		"the level from §5.3's curve: '%s'" % text)
	assert_true(text.contains(str(STARTER_SKILL_XP)), "the exact accumulated XP")
	assert_true(text.contains(str(NEXT_LEVEL_THRESHOLD)),
		"and §5.3's next-level threshold of 5000*3*3")


func test_a_max_level_skill_says_max_level_rather_than_an_invented_threshold() -> void:
	"""§5: "A max-level row says Max level with its actual XP"."""
	var slot: int = _spawn(&"mouse")
	assert_true(_residents.set_skill_xp(slot, 0, 500000).ok, "the skill is driven to level 10")
	assert_equal(_residents.skill_level_of(slot, 0).value, ResidentsScript.SKILL_LEVEL_MAX,
		"the store agrees it is at the cap")
	var text: String = UiResidentCard.skill_text(_residents, slot, 0)
	assert_true(text.contains("max level"), "the row says so: '%s'" % text)
	assert_true(text.contains("500000"), "and still carries the actual XP")


func test_an_unreadable_health_says_unavailable_rather_than_zero_of_one_hundred() -> void:
	"""UXV-022: "Missing values are explicitly unavailable rather than fabricated".

	`Health 0 / 100` is a dying resident. A slot the store refuses is not one, and the two must
	never look the same on the card.
	"""
	var text: String = UiResidentCard.health_text(_needs, 0)
	assert_false(_needs.is_alive(0), "slot 0 holds no resident")
	assert_true(text.contains(UiResidentCard.UNAVAILABLE), "so health says so: '%s'" % text)
	assert_false(text.contains("0 / 100"), "and never prints a fabricated zero")


func test_an_unreadable_skill_says_unavailable_rather_than_level_zero() -> void:
	"""Level 0 is a real level. A refused read is not, and must not borrow its wording."""
	var text: String = UiResidentCard.skill_text(_residents, 0, 0)
	assert_true(text.contains(UiResidentCard.UNAVAILABLE), "the skill row says so: '%s'" % text)
	assert_false(text.contains("level 0"), "and never claims a real level 0")


func test_an_unreadable_species_says_unavailable_rather_than_naming_one() -> void:
	"""Naming a species for a slot the store refused would drive the wrong medallion."""
	var text: String = UiResidentCard.species_text(_residents, 0)
	assert_equal(text, UiResidentCard.UNAVAILABLE, "the species is unavailable")
	assert_false(UiResidentCard.has_emblem(StringName(text)),
		"and it resolves to no medallion")


# --- ART-UI-06: generic species medallions ---------------------------------------------------

func test_the_four_delivered_species_resolve_to_real_medallion_sources() -> void:
	"""ART-LOCK-001 §5 delivers mouse, mole, otter and squirrel at 48 and 64 px."""
	for species: StringName in UiResidentCard.EMBLEM_SPECIES:
		for pixels: int in UiResidentCard.EMBLEM_SIZES:
			var path: String = UiResidentCard.emblem_path(species, pixels)
			assert_true(FileAccess.file_exists(path),
				"%s at %d px exists at %s" % [species, pixels, path])


func test_a_species_with_no_delivered_medallion_gets_none_rather_than_a_mouse() -> void:
	"""The lock: "never reuse a mouse emblem for every resident"."""
	assert_false(UiResidentCard.has_emblem(&"hedgehog"), "no hedgehog medallion is delivered")
	assert_equal(UiResidentCard.emblem_path(&"hedgehog", 48), "",
		"so no source is offered for one")
	assert_equal(UiResidentCard.emblem_path(&"badger", 64), "", "and none for a badger")


func test_the_24_px_diagnostic_size_is_not_offered_as_a_portrait_size() -> void:
	"""The lock: 24 px "is a diagnostic species test, not a newly authorized ... portrait"."""
	assert_equal(UiResidentCard.emblem_path(&"mouse", 24), "",
		"24 px resolves to no production source")
	assert_equal(UiResidentCard.EMBLEM_SIZES, [48, 64], "only the two production sizes exist")


func test_the_production_size_follows_the_detail_column_width() -> void:
	"""§1.2's detail widths are 320/336/384; only the wide column takes the 64 px roundel."""
	assert_equal(UiResidentCard.emblem_pixels_for_width(320.0), 48, "narrow takes 48")
	assert_equal(UiResidentCard.emblem_pixels_for_width(336.0), 48, "standard takes 48")
	assert_equal(UiResidentCard.emblem_pixels_for_width(384.0), 64, "wide takes 64")


func test_the_medallion_is_described_as_generic_and_never_as_a_portrait() -> void:
	"""UXV-019: the emblem "never implies a unique portrait or invented biography"."""
	var description: String = UiResidentCard.emblem_description(&"otter")
	assert_true(description.contains("Generic"), "it is announced as generic: '%s'" % description)
	assert_true(description.contains("not a portrait"), "and explicitly not a portrait")
	assert_true(UiResidentCard.EMBLEM_NOTE.contains("not a portrait"),
		"and the visible note says the same")


func test_every_medallion_path_is_the_art_registrys_own() -> void:
	"""The card must not name a file the registry does not declare."""
	for species: StringName in UiResidentCard.EMBLEM_SPECIES:
		var asset_id: StringName = StringName("ART.EMBLEM.%s_64"
			% String(species).to_upper())
		assert_true(UiArt.has_asset_id(asset_id), "%s is a declared asset" % asset_id)
		assert_equal(UiResidentCard.emblem_path(species, 64),
			UiArt.source_path_of(UiArt.ASSET_ID.find(asset_id)),
			"and the card resolves it through the registry")
