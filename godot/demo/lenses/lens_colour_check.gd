extends RefCounted
## The colour-blind check for a map layer's area colours (decision 0581). Pure and static; presentation only (float).
##
## A layer's AREA colours -- the ramp a lens paints the ground with -- must stay apart for everyone: every pair at
## least MIN_DE_DAY apart (CIE76 delta E, CIELAB under D65) for normal vision and for full-severity deuteranopia and
## protanopia, simulated with Machado, Oliveira and Fernandes (2009)'s matrices on linear RGB. Each is checked three
## ways: as the legend draws it (opaque), as the day sees it (composited at its own alpha over the ground it is painted
## on), and as the night sees it (that composite through lens_palette.gd's night grade: the saturation cut and the
## haze), where the floor is MIN_DE_NIGHT. Delta E 76 is the simple Euclidean distance; about 2.3 is "just
## noticeable", and 10 keeps two flat map tints clearly apart at a glance.
##
## `failures` names each failing pair in words for a test or a warning; `closest` returns the worst pair.

const Palette := preload("res://demo/lenses/lens_palette.gd")

const VISION_NORMAL: int = 0
const VISION_DEUTAN: int = 1
const VISION_PROTAN: int = 2
const VISION_COUNT: int = 3
const VISION_NAMES: Array[String] = ["normal vision", "deuteranopia", "protanopia"]

const SEEN_LEGEND: int = 0
const SEEN_DAY: int = 1
const SEEN_NIGHT: int = 2
const SEEN_COUNT: int = 3
const SEEN_NAMES: Array[String] = ["in the legend", "by day", "by night"]

## The floors (CIE76 delta E): legend and day, and the night's dimmer grade.
const MIN_DE_DAY: float = 10.0
const MIN_DE_NIGHT: float = 8.0

## Machado 2009, severity 1.0, rows of a 3x3 matrix on linear RGB.
const DEUTAN: PackedFloat32Array = [0.367322, 0.860646, -0.227968, 0.280085, 0.672501, 0.047413,
	-0.011820, 0.042940, 0.968881]
const PROTAN: PackedFloat32Array = [0.152286, 1.052583, -0.204868, 0.114503, 0.786281, 0.099216,
	-0.003882, -0.048116, 1.051998]
## D65 white, for XYZ -> Lab.
const WHITE_X: float = 0.95047
const WHITE_Z: float = 1.08883


static func simulate(colour: Color, vision: int) -> Color:
	"""How `colour` (sRGB) looks with `vision` (VISION_*), opaque."""
	if vision == VISION_NORMAL:
		return Color(colour, 1.0)
	var m: PackedFloat32Array = DEUTAN if vision == VISION_DEUTAN else PROTAN
	var lin: Color = Color(colour, 1.0).srgb_to_linear()
	var out := Color(m[0] * lin.r + m[1] * lin.g + m[2] * lin.b, m[3] * lin.r + m[4] * lin.g + m[5] * lin.b,
		m[6] * lin.r + m[7] * lin.g + m[8] * lin.b)
	out = Color(clampf(out.r, 0.0, 1.0), clampf(out.g, 0.0, 1.0), clampf(out.b, 0.0, 1.0))
	return out.linear_to_srgb()


static func seen(colour: Color, over: Color, when: int) -> Color:
	"""`colour` as drawn: opaque in the legend; by day at its own alpha over `over`; by night that, graded."""
	if when == SEEN_LEGEND:
		return Color(colour, 1.0)
	var day: Color = Color(over, 1.0).lerp(Color(colour, 1.0), colour.a)
	if when == SEEN_DAY:
		return day
	var grey: float = day.get_luminance()
	var flat := Color(grey, grey, grey)
	return flat.lerp(day, Palette.NIGHT_SATURATION).lerp(Palette.NIGHT_HAZE, Palette.NIGHT_HAZE_SHARE)


static func lab(colour: Color) -> Vector3:
	"""CIELAB (L, a, b) of an sRGB colour, D65."""
	var c: Color = Color(colour, 1.0).srgb_to_linear()
	var x: float = (0.4124 * c.r + 0.3576 * c.g + 0.1805 * c.b) / WHITE_X
	var y: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var z: float = (0.0193 * c.r + 0.1192 * c.g + 0.9505 * c.b) / WHITE_Z
	var fy: float = _f(y)
	return Vector3(116.0 * fy - 16.0, 500.0 * (_f(x) - fy), 200.0 * (fy - _f(z)))


static func _f(t: float) -> float:
	"""CIELAB's cube-root companding, linear near black."""
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


static func delta_e(a: Color, b: Color) -> float:
	"""CIE76 delta E between two sRGB colours."""
	return lab(a).distance_to(lab(b))


static func closest(colours: PackedColorArray, over: Color, when: int, vision: int) -> Vector3:
	"""The closest pair of `colours` as seen `when` with `vision`: (delta E, i, j); (INF, -1, -1) under two."""
	var best := Vector3(INF, -1.0, -1.0)
	for i: int in colours.size():
		var a: Color = simulate(seen(colours[i], over, when), vision)
		for j: int in range(i + 1, colours.size()):
			var d: float = delta_e(a, simulate(seen(colours[j], over, when), vision))
			if d < best.x:
				best = Vector3(d, float(i), float(j))
	return best


static func floor_for(when: int) -> float:
	"""The delta E floor for a viewing (SEEN_*)."""
	return MIN_DE_NIGHT if when == SEEN_NIGHT else MIN_DE_DAY


static func failures(colours: PackedColorArray, over: Color, names: PackedStringArray) -> PackedStringArray:
	"""Every viewing and vision in which some pair of `colours` falls under its floor, in words ('swim and dive by
	night with protanopia: 6.1'); empty when they all pass."""
	var out := PackedStringArray()
	for when: int in SEEN_COUNT:
		for vision: int in VISION_COUNT:
			var worst: Vector3 = closest(colours, over, when, vision)
			if worst.y < 0.0 or worst.x >= floor_for(when):
				continue
			out.append("%s and %s %s with %s: %.1f" % [_name(names, int(worst.y)), _name(names, int(worst.z)),
				SEEN_NAMES[when], VISION_NAMES[vision], worst.x])
	return out


static func _name(names: PackedStringArray, k: int) -> String:
	"""A colour's name for a failure line (its index when unnamed)."""
	return names[k] if k < names.size() else "colour %d" % k
