extends RefCounted
## What each season does to the woods and the ground: pure sampling. Decision 0551 (review UX-028's seasonal art).
## Presentation only -- nothing here reads or writes a row, a rate or a tick the village runs on.
##
## A TREE'S LOOK is three numbers the tree shader reads per tree (season_leaves.gdshaderinc):
##   * `tint`    -- the leaves' colour: rgb is a LINEAR hue scaled by the season's value lift (the shader multiplies
##                  it by each leaf texel's own luminance, so the texture's light and shade are kept), `a` how far
##                  the leaves take it (0: the summer texture as authored);
##   * `bare`    -- the share of leaf texels dropped (an opaque-pass discard by UV cell, so clumps go, not a fade);
##   * `blossom` -- the share of the spring flowering speckle shown (the oaks' catkins).
## Each KIND keeps its own habit: the oak and the beech (and the young oak) are deciduous; an EVERGREEN kind keeps
## the summer look the whole year (the demo stages no conifer yet: the kind is here so one drops in unchanged).
##
## THE YEAR. Twelve days a season (sim_clock.gd DAYS_PER_SEASON). Each season's own look runs on its local day; for
## its first BLEND_DAYS a tree eases from the previous season's END look into it, and every tree starts that
## blend up to STAGGER_DAYS late, by its stable hash -- so no season arrives as a swap and no two neighbours turn
## together:
##   spring  -- leaf-out from bare (the blend), fresh light green, the oaks' catkins over the first days;
##   summer  -- the texture as authored;
##   autumn  -- a gradual turn to gold, ochre, russet or (rarely) red, each tree its own colour and its own pace;
##              the crowns stay full (the falling leaves and the leaves lying on the ground say they are coming down);
##   winter  -- they fall (the blend): bare, but for the trees that keep their dry leaves (marcescence: most
##              young oaks, some beeches, a few old oaks hold brown leaves to spring) -- until THE THAW.
## THE THAW. The leaf-out is the one change that is NOT at its season's start: it runs over winter's last days
## (from THAW_FROM_DAY, THAW_DAYS long, staggered like the rest) and ends in spring's first look, so spring opens in
## fresh leaf. The demo opens on Spring 1: a blend at spring's start would greet every new village with bare woods
## for its first forty minutes. Spring's own blend is then from that thawed look into itself, a no-op.
## THE GROUND follows the same calendar without the stagger (`ground_into`): fresher grass in spring, drier in
## autumn and winter, and fallen leaves lying through autumn into winter. Every colour the ground is given stays in
## its DEC-038 value group (decision 0301; the checks hold it).
##
## A TREE'S HASH is a pure function of where it stands (`tree_hash`), so a tree keeps its colour and its pace
## across a restart, a reload of its model, a fall and a regrowth. Nothing here allocates: samples are written
## into reused objects.

const SimClock := preload("res://scripts/core/sim_clock.gd")

const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3

const KIND_OAK: int = 0
const KIND_BEECH: int = 1
const KIND_YOUNG_OAK: int = 2
const KIND_EVERGREEN: int = 3
## Whether each kind drops its leaves.
const DECIDUOUS: Array[bool] = [true, true, true, false]
## The share of each kind's trees that keep dry leaves through winter, and how much of them they keep.
const MARCESCENT_SHARE: PackedFloat32Array = [0.12, 0.35, 0.8, 0.0]
const MARCESCENT_KEEP: float = 0.3
## How much catkin or blossom speckle each kind shows at its spring peak.
const BLOSSOM_PEAK: PackedFloat32Array = [1.0, 0.0, 0.6, 0.0]

const DAYS_PER_SEASON: float = float(SimClock.DAYS_PER_SEASON)
## A season's look eases in over this many days after its (staggered) start ...
const BLEND_DAYS: float = 2.5
## ... which each tree reaches up to this many days late, by its hash.
const STAGGER_DAYS: float = 1.5
## Spring: how far the leaves take the fresh green; the catkins show from day 0.5 to day 9 of the season.
const SPRING_MIX: float = 0.4
const BLOSSOM_FROM_DAY: float = 0.5
const BLOSSOM_TO_DAY: float = 9.0
const BLOSSOM_EASE_DAYS: float = 2.0
## Autumn: a tree turns over TURN_DAYS (0.55-1.1 of it by its hash, eased in; the slowest is through by day 11.4), to AUTUMN_MIX of its colour. Its crown
## stays whole: a crown with leaves down is drawn through a discard in every shadow cascade (decision 0551's
## measurement), so the woods thin only in winter's first days, then stand as bare boughs (bare_boughs.gd).
const TURN_DAYS: float = 9.0
const TURN_PACE_MIN: float = 0.55
const TURN_PACE_MAX: float = 1.1
const AUTUMN_MIX: float = 0.7

## Value lifts: a turned or fresh leaf reads a little lighter than the summer texel, a dry one a little darker.
const FRESH_LIFT: float = 1.15
const AUTUMN_LIFT: float = 1.05
const DRY_LIFT: float = 0.85
## Leaf hues, sRGB (DEC-038's restrained ochre and earth: no saturated orange).
const FRESH: Color = Color(0.6, 0.72, 0.3)
const GOLD: Color = Color(0.66, 0.58, 0.32)
const OCHRE: Color = Color(0.6, 0.48, 0.28)
const RUSSET: Color = Color(0.5, 0.37, 0.24)
const RED: Color = Color(0.47, 0.29, 0.21)
const DRY: Color = Color(0.38, 0.32, 0.26)
## Each kind's autumn colours, chosen per tree by its hash; the last is RED, taken by RED_SHARE of the trees.
const AUTUMN_OAK: Array[Color] = [OCHRE, RUSSET, GOLD]
const AUTUMN_BEECH: Array[Color] = [GOLD, OCHRE, RUSSET]
const RED_SHARE: float = 0.1

## Ground (see THE GROUND): spring's fresh grass, the dry grass of autumn and winter, and the fallen leaves.
const FRESH_GRASS: Color = Color(0.42, 0.56, 0.24)
const DRY_GRASS: Color = Color(0.56, 0.49, 0.3)
const FRESH_GRASS_MIX: float = 0.3
const DRY_GRASS_MIX: float = 0.4
const LITTER_RUSSET: Color = Color(0.42, 0.28, 0.16)
const FALLEN_LEAVES: Color = Color(0.5, 0.33, 0.17)
## The ground cover's albedo multiply, fresh and dry.
const TUFT_FRESH: Color = Color(0.95, 1.08, 0.88)
const TUFT_DRY: Color = Color(1.12, 0.98, 0.72)
## Fallen leaves lie from AUTUMN_LEAVES_FROM_DAY, reach AUTUMN_LEAVES_MAX by the end of autumn, and WINTER_LEAVES
## of them stay, browned, under the snow.
const AUTUMN_LEAVES_FROM_DAY: float = 2.0
const AUTUMN_LEAVES_MAX: float = 0.55
const WINTER_LEAVES: float = 0.35
## The thaw (see THE THAW): winter's leaf-out, trees and ground.
const THAW_FROM_DAY: float = 8.5
const THAW_DAYS: float = 2.0
## Falling leaves (falling_leaves.gd) blow from LEAF_DROP_FROM_DAY of autumn, and on into winter's first days.
const LEAF_DROP_FROM_DAY: float = 3.0
const LEAF_DROP_EASE_DAYS: float = 3.0
const WINTER_DROP_DAYS: float = 2.5

const MASK32: int = 0xFFFFFFFF
## Positions are hashed on a 1/64 m grid.
const HASH_GRID: float = 64.0


class Sample:
	"""One tree's look (see the header): written by `sample_into`, read by the tree shader per instance."""
	var tint: Color = Color(1.0, 1.0, 1.0, 0.0)
	var bare: float = 0.0
	var blossom: float = 0.0

	func set_summer() -> void:
		"""The texture as authored."""
		tint = Color(1.0, 1.0, 1.0, 0.0)
		bare = 0.0
		blossom = 0.0


class Ground:
	"""The ground's season: how fresh, how dry, and how many fallen leaves lie (each 0..1)."""
	var fresh: float = 0.0
	var dry: float = 0.0
	var leaves: float = 0.0

	func set_to(p_fresh: float, p_dry: float, p_leaves: float) -> void:
		"""All three at once."""
		fresh = p_fresh
		dry = p_dry
		leaves = p_leaves


var _prev: Sample = Sample.new()
var _cur: Sample = Sample.new()
var _prev_ground: Ground = Ground.new()
var _cur_ground: Ground = Ground.new()


# --- the hash ------------------------------------------------------------------------------------------

static func tree_hash(at: Vector2) -> int:
	"""A stable 32-bit hash of where a tree stands (on a 1/64 m grid): the same spot, the same hash, every run."""
	var x: int = roundi(at.x * HASH_GRID) & MASK32
	var z: int = roundi(at.y * HASH_GRID) & MASK32
	return _mix32(x ^ _mix32(z + 0x9E3779B9))


static func _mix32(value: int) -> int:
	"""MurmurHash3's 32-bit finaliser: every input bit moves every output bit."""
	var h: int = value & MASK32
	h ^= h >> 16
	h = (h * 0x85EBCA6B) & MASK32
	h ^= h >> 13
	h = (h * 0xC2B2AE35) & MASK32
	h ^= h >> 16
	return h


static func unit(bits: int, part: int) -> float:
	"""One of three independent 0..1 draws from a tree's hash (`part` 0, 1 or 2: ten bits each)."""
	return float((bits >> (part * 10)) & 0x3FF) / 1024.0


# --- the trees -----------------------------------------------------------------------------------------

static func day_in_season(season_day: int, tick_of_day: int) -> float:
	"""Days into the season (0 at its first midnight) from the calendar's 1-based day and its tick of day."""
	return float(season_day - 1) + float(tick_of_day) / float(SimClock.TICKS_PER_DAY)


func sample_into(kind: int, bits: int, season: int, day: float, out: Sample) -> void:
	"""Tree `kind` with hash `bits`, `day` days into `season` (0 spring .. 3 winter): its look into `out`. For its first
	BLEND_DAYS after its staggered start the look eases from the previous season's end."""
	var start: float = unit(bits, 0) * STAGGER_DAYS
	state_into(kind, bits, season, day - start, _cur)
	var w: float = blend_weight(day - start)
	if w >= 1.0:
		_copy(_cur, out)
		return
	state_into(kind, bits, (season + 3) % 4, DAYS_PER_SEASON, _prev)
	blend_into(_prev, _cur, w, out)


static func blend_weight(local_day: float) -> float:
	"""How far into a season's blend a tree is, `local_day` days after its own start: an eased 0..1."""
	return smoothstep(0.0, 1.0, clampf(local_day / BLEND_DAYS, 0.0, 1.0))


static func state_into(kind: int, bits: int, season: int, local_day: float, out: Sample) -> void:
	"""Season `season`'s own look for a tree, `local_day` days after its start (no blend)."""
	out.set_summer()
	if not DECIDUOUS[kind]:
		return
	match season:
		SPRING:
			out.tint = hue(FRESH, FRESH_LIFT, SPRING_MIX)
			out.blossom = BLOSSOM_PEAK[kind] * _bump(local_day, BLOSSOM_FROM_DAY, BLOSSOM_TO_DAY, BLOSSOM_EASE_DAYS)
		AUTUMN:
			_autumn_into(kind, bits, local_day, out)
		WINTER:
			_winter_into(kind, bits, local_day, out)


static func _winter_into(kind: int, bits: int, local_day: float, out: Sample) -> void:
	"""Winter: bare (or holding dry leaves), until the thaw leafs it out into spring's first look over winter's last
	days (see THE THAW)."""
	var keeps: bool = unit(bits, 1) < MARCESCENT_SHARE[kind]
	var thaw: float = smoothstep(0.0, 1.0, clampf((local_day - THAW_FROM_DAY) / THAW_DAYS, 0.0, 1.0))
	var bare: float = 1.0 - MARCESCENT_KEEP if keeps else 1.0
	out.tint = mix_tints(hue(DRY, DRY_LIFT, 1.0), hue(FRESH, FRESH_LIFT, SPRING_MIX), thaw)
	out.bare = bare * (1.0 - thaw)


static func _autumn_into(kind: int, bits: int, local_day: float, out: Sample) -> void:
	"""Autumn: the tree turns to its own colour at its own pace, its crown whole."""
	var pace: float = TURN_DAYS * lerpf(TURN_PACE_MIN, TURN_PACE_MAX, unit(bits, 2))
	var turn: float = smoothstep(0.0, 1.0, clampf(local_day / pace, 0.0, 1.0))
	out.tint = hue(autumn_colour(kind, bits), AUTUMN_LIFT, turn * AUTUMN_MIX)


static func autumn_colour(kind: int, bits: int) -> Color:
	"""A tree's own autumn colour (sRGB): RED for RED_SHARE of trees, else one of its kind's by its hash."""
	var draw: float = unit(bits, 1)
	if draw >= 1.0 - RED_SHARE:
		return RED
	var colours: Array[Color] = AUTUMN_BEECH if kind == KIND_BEECH else AUTUMN_OAK
	var k: int = mini(int(draw / (1.0 - RED_SHARE) * float(colours.size())), colours.size() - 1)
	return colours[k]


static func hue(srgb: Color, lift: float, amount: float) -> Color:
	"""A leaf tint as the shader takes it: the colour in linear light divided by its own luminance (a hue the
	shader scales by each texel's luminance) times `lift`, and `amount` in alpha."""
	var linear: Color = srgb.srgb_to_linear()
	var luma: float = maxf(0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b, 0.0001)
	return Color(linear.r / luma * lift, linear.g / luma * lift, linear.b / luma * lift, amount)


static func _bump(day: float, from_day: float, to_day: float, ease_days: float) -> float:
	"""0 before `from_day`, easing up to 1 over `ease_days`, and back down to 0 by `to_day`."""
	var up: float = clampf((day - from_day) / ease_days, 0.0, 1.0)
	var down: float = clampf((to_day - day) / ease_days, 0.0, 1.0)
	return smoothstep(0.0, 1.0, minf(up, down))


static func blend_into(a: Sample, b: Sample, w: float, out: Sample) -> void:
	"""`w` of the way from look `a` to look `b` (the tints by `mix_tints`)."""
	out.tint = mix_tints(a.tint, b.tint, w)
	out.bare = lerpf(a.bare, b.bare, w)
	out.blossom = lerpf(a.blossom, b.blossom, w)


static func mix_tints(a: Color, b: Color, w: float) -> Color:
	"""`w` of the way from tint `a` to tint `b`: the hues mix by how much each is taken (premultiplied), so a summer
	tint (amount 0) brings no colour of its own."""
	var amount: float = lerpf(a.a, b.a, w)
	var wa: float = a.a * (1.0 - w)
	var wb: float = b.a * w
	if wa + wb <= 0.0:
		return Color(1.0, 1.0, 1.0, amount)
	var total: float = wa + wb
	return Color((a.r * wa + b.r * wb) / total, (a.g * wa + b.g * wb) / total, (a.b * wa + b.b * wb) / total, amount)


static func _copy(from: Sample, out: Sample) -> void:
	"""`out` made equal to `from`."""
	out.tint = from.tint
	out.bare = from.bare
	out.blossom = from.blossom


# --- the ground ----------------------------------------------------------------------------------------

func ground_into(season: int, day: float, out: Ground) -> void:
	"""The ground's season `day` days into `season`, easing from the previous season's end over BLEND_DAYS."""
	ground_state_into(season, day, _cur_ground)
	var w: float = blend_weight(day)
	if w >= 1.0:
		out.set_to(_cur_ground.fresh, _cur_ground.dry, _cur_ground.leaves)
		return
	ground_state_into((season + 3) % 4, DAYS_PER_SEASON, _prev_ground)
	out.set_to(lerpf(_prev_ground.fresh, _cur_ground.fresh, w), lerpf(_prev_ground.dry, _cur_ground.dry, w),
		lerpf(_prev_ground.leaves, _cur_ground.leaves, w))


static func ground_state_into(season: int, day: float, out: Ground) -> void:
	"""Season `season`'s own ground `day` days in (no blend)."""
	match season:
		SPRING:
			out.set_to(1.0, 0.0, 0.0)
		SUMMER:
			out.set_to(0.0, 0.0, 0.0)
		AUTUMN:
			var leaves: float = clampf((day - AUTUMN_LEAVES_FROM_DAY) / (DAYS_PER_SEASON - AUTUMN_LEAVES_FROM_DAY), 0.0, 1.0)
			out.set_to(0.0, 0.5 * clampf(day / TURN_DAYS, 0.0, 1.0), leaves * AUTUMN_LEAVES_MAX)
		_:
			var thaw: float = smoothstep(0.0, 1.0, clampf((day - THAW_FROM_DAY) / THAW_DAYS, 0.0, 1.0))
			out.set_to(thaw, 1.0 - thaw, WINTER_LEAVES * (1.0 - thaw))


static func grass_target(base: Color, ground: Ground) -> Color:
	"""A grass colour (the ground's own `base`) in this season: toward FRESH_GRASS in spring, DRY_GRASS when dry."""
	return base.lerp(FRESH_GRASS, ground.fresh * FRESH_GRASS_MIX).lerp(DRY_GRASS, ground.dry * DRY_GRASS_MIX)


static func litter_target(base: Color, ground: Ground) -> Color:
	"""The woods' leaf litter in this season: redder as the fallen leaves lie."""
	return base.lerp(LITTER_RUSSET, ground.leaves * 0.5)


static func tuft_multiply(ground: Ground) -> Color:
	"""The ground cover's albedo multiply in this season (white: as authored)."""
	return Color.WHITE.lerp(TUFT_FRESH, ground.fresh).lerp(TUFT_DRY, ground.dry)


static func leaf_drop(season: int, day: float) -> float:
	"""How hard leaves are falling, 0..1 (falling_leaves.gd): rising through autumn, dying away early in winter."""
	if season == AUTUMN:
		return smoothstep(0.0, 1.0, clampf((day - LEAF_DROP_FROM_DAY) / LEAF_DROP_EASE_DAYS, 0.0, 1.0))
	if season == WINTER:
		return 1.0 - smoothstep(0.0, 1.0, clampf(day / WINTER_DROP_DAYS, 0.0, 1.0))
	return 0.0
