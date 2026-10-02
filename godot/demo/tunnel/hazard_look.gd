extends RefCounted
## THE HAZARDS' VISUAL LANGUAGE: which look a tunnel's hazard state shows. Decision 0211 (the underground revamp's P5;
## DEC-040: hazards are "warned" and show in the geometry before they strike; design §6 "Hazards made visible").
## Presentation only, pure and static, integer in and out.
##
## tunnel_hazards.gd builds two pressures per segment, per mille of the way to striking. The LOOK follows them:
##
##   state (tunnel_hazards.gd)            look                                         level
##   under SIGN_PERMILLE, or braced       NONE: plain earth                             0
##   seep from SIGN_PERMILLE              SEEP_SIGNS: the wet stretch darkens, glossy,   rises SIGN -> 1000
##                                        streaked, a puddle, drips from the crown
##   seep past WARN_PERMILLE (warned)     SEEP_WARNED: the same, spreading along the     (the warning names it)
##                                        bore, the drips heavier
##   strain from SIGN_PERMILLE            STRAIN_SIGNS: cracks over the weak section,    rises SIGN -> 1000
##                                        sand stains, sand trickling from the crown
##   strain past WARN_PERMILLE (warned)   STRAIN_WARNED: wider cracks, the crown sagging
##   FLOODED (struck)                     FLOODED: water in the bore (bore_mesh FLOODED) 0 (the flood's own look)
##   COLLAPSED (struck)                   COLLAPSED: the fall's rubble (RUBBLE)          0 (the fall's own look)
## So every warning is seen before the notice feed says it (SIGN_PERMILLE < WARN_PERMILLE), and grows to the strike.
## A segment with both pressures shows both (a look each; `seep_look` and `strain_look`).

const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

## The first signs show at this share of the way to striking: half the warning's.
@warning_ignore("integer_division") const SIGN_PERMILLE: int = HazardsScript.WARN_PERMILLE / 2

const LOOK_NONE: int = 0
const LOOK_SEEP_SIGNS: int = 1
const LOOK_SEEP_WARNED: int = 2
const LOOK_FLOODED: int = 3
const LOOK_STRAIN_SIGNS: int = 4
const LOOK_STRAIN_WARNED: int = 5
const LOOK_COLLAPSED: int = 6
const LOOK_NAMES: Array[String] = ["plain", "seep: first signs", "seep: warned", "flooded", "strain: first signs",
	"strain: warned", "fallen in"]


static func level_permille(pressure_permille: int) -> int:
	"""How far a hazard's look has come (per mille): 0 below SIGN_PERMILLE, rising to 1000 as the pressure reaches
	1000."""
	if pressure_permille < SIGN_PERMILLE:
		return 0
	@warning_ignore("integer_division") return mini((pressure_permille - SIGN_PERMILLE) * Rules.PERMILLE / (Rules.PERMILLE - SIGN_PERMILLE), Rules.PERMILLE)


static func seep_look(seep_permille: int, closed: int, braced: bool) -> int:
	"""The look a seep of `seep_permille` shows on a segment `closed` (underground_graph.gd CLOSED_*), braced or not."""
	if closed == GraphScript.CLOSED_FLOODED:
		return LOOK_FLOODED
	if braced or closed != GraphScript.CLOSED_NONE or seep_permille < SIGN_PERMILLE:
		return LOOK_NONE
	return LOOK_SEEP_WARNED if seep_permille >= HazardsScript.WARN_PERMILLE else LOOK_SEEP_SIGNS


static func strain_look(strain_permille: int, closed: int, braced: bool) -> int:
	"""The look a strain of `strain_permille` shows on a segment `closed`, braced or not."""
	if closed == GraphScript.CLOSED_COLLAPSED:
		return LOOK_COLLAPSED
	if braced or closed != GraphScript.CLOSED_NONE or strain_permille < SIGN_PERMILLE:
		return LOOK_NONE
	return LOOK_STRAIN_WARNED if strain_permille >= HazardsScript.WARN_PERMILLE else LOOK_STRAIN_SIGNS


static func shown_level(look: int, pressure_permille: int) -> int:
	"""The level (per mille) the bore's shader draws for `look` at `pressure_permille`: the pressure's while it is a
	sign or a warning, else 0 (struck, a look of its own; or nothing)."""
	var warning := look == LOOK_SEEP_SIGNS or look == LOOK_SEEP_WARNED or look == LOOK_STRAIN_SIGNS \
			or look == LOOK_STRAIN_WARNED
	return level_permille(pressure_permille) if warning else 0
