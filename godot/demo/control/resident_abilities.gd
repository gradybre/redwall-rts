extends RefCounted
## What one resident can be ordered to do, in words, for the demo party panel. Decision 0205 (the
## playtest of 2026-09-29: "Selecting a resident gives a clear list of actions they can take").
##
## One short line per kind of work (one line each in the panel's column), each saying what to
## right-click; the skill-gated work says why this body cannot ("× ..."), with the rule that gates it. The answers are read from the rules that decide them,
## never restated: digging (tunnel_rules.gd `is_digger`), fitting a standard bore (`fits_bore`),
## swimming and diving (waterplay/swim_rules.gd), gnawing (forestry/forest_skills.gd), breaking rock
## (tunnel/tunnel_crew.gd) and carrying (a carry clip with recorded root motion). Everything else --
## moving, the farm's verbs, the woods' felling and sawing, clearing spoil -- anybeast does (LORE-P12).

const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const ForestSkills := preload("res://demo/forestry/forest_skills.gd")
const TunnelCrew := preload("res://demo/tunnel/tunnel_crew.gd")

const HEADING: String = "Orders (right-click):"
const CAN: String = "• "
const CANNOT: String = "× "
const MOVE_LINE: String = "Move or work — the ground, a work spot"
const FARM_LINE: String = "Farm: sow, tend, harvest, drain — a bed"
const SPOIL_LINE: String = "Spoil: dig out, haul away — a heap"
const NO_SPOIL_LINE: String = "Spoil: cannot carry it away"
const FELL_LINE: String = "Woods: fell, gather, saw — a tree"
const GNAW_LINE: String = "Woods: gnaw, gather, saw — a tree"
const CARRY_LINE: String = "Carry: logs, harvests, spoil, planks"
const NO_CARRY_LINE: String = "Carry: has no carrying walk"
const DIG_LINE: String = "Dig tunnels (T), widen, dig rooms"
const NO_DIG_LINE: String = "Digging: only moles dig"
const BORE_LINE: String = "Tunnels: brace, lanterns — a tunnel"
const NO_BORE_LINE: String = "Tunnels: too big until widened"
const ROCK_LINE: String = "Rock: breaks it for a dig crew"
const DIVE_LINE: String = "Water: swim, dive — deep water"
const SWIM_LINE: String = "Water: swim, unladen — deep water"
const NO_SWIM_LINE: String = "Swimming: wades the ford only"


static func lines_for(species: String, height_m: float, radius_m: float, can_carry: bool) -> PackedStringArray:
	"""The panel's lines for one resident: the heading, then one line a kind of work, `CAN` or
	`CANNOT` first."""
	var lines := PackedStringArray([HEADING, CAN + MOVE_LINE, CAN + FARM_LINE])
	lines.append(CAN + SPOIL_LINE if can_carry else CANNOT + NO_SPOIL_LINE)
	lines.append(CAN + (GNAW_LINE if ForestSkills.GNAWING_SPECIES.has(species.to_lower()) else FELL_LINE))
	lines.append(CAN + CARRY_LINE if can_carry else CANNOT + NO_CARRY_LINE)
	lines.append_array(tunnel_lines(species, height_m, radius_m))
	lines.append(water_line(species))
	return lines


static func tunnel_lines(species: String, height_m: float, radius_m: float) -> PackedStringArray:
	"""Digging (moles only), fitting a standard bore, and breaking rock (the badger)."""
	var lines := PackedStringArray()
	if TunnelRules.is_digger(species):
		lines.append(CAN + DIG_LINE)
	if TunnelRules.fits_bore(TunnelRules.to_u(height_m), TunnelRules.to_u(radius_m)):
		lines.append(CAN + BORE_LINE)
	else:
		lines.append(CANNOT + NO_BORE_LINE)
	if species.to_lower() == TunnelCrew.BREAKER_SPECIES:
		lines.append(CAN + ROCK_LINE)
	if not TunnelRules.is_digger(species):
		lines.append(CANNOT + NO_DIG_LINE)
	return lines


static func water_line(species: String) -> String:
	"""Diving (otters), swimming (every listed swimmer) or wading only (the badger, anything unlisted)."""
	if SwimRules.dives_of(species):
		return CAN + DIVE_LINE
	if SwimRules.swim_mm_s_of(species) > 0:
		return CAN + SWIM_LINE
	return CANNOT + NO_SWIM_LINE
