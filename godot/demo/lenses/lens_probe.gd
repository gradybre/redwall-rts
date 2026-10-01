extends RefCounted
## What a map layer says about one point of the ground: the base of every layer's PROBE (decision 0581). The hover
## readout (demo/ui/demo_lens_readout.gd) asks the shown layer's probe what lies under the pointer, and the compare
## outlines (lens_contours.gd) ask the compared layer's probe over a grid. Presentation only: a probe reads the
## simulation's integer state and writes nothing.
##
## TWO HALVES, so that the pointer costs nothing. `read_into` is called up to ten times a second and must not
## allocate: it fills a caller-owned Reading with integers -- which legend entry is under the point, which AREA class
## the outlines trace, the exact value, and whose it is (a bed, a tree, a zone, a body height). `describe` turns a
## Reading into words and is called only when the Reading (or the probe's `field_revision`) changes, so its string
## formatting happens on a change, never per frame.
##
## THE FIELD. A probe that can be outlined (`can_outline`) names the ground its areas lie in (`field_bounds_m`), the
## grid step to sample it at (`field_cell_m`), how high its marks are drawn (`draw_y_m`), and a number that moves
## whenever its areas may have changed (`field_revision`) -- the outlines are redrawn only then.
##
## The base probe has nothing to say: a layer without a probe (Routes, Underground) shows no readout and is not
## offered for comparison.


class Reading:
	"""A caller-owned answer to `read_into`: integers only, compared to decide whether to re-describe."""
	## The legend entry under the point (its swatch's index), -1 for none.
	var entry: int = -1
	## The area class the outlines trace (an index into the legend's swatches), -1 outside every area.
	var area: int = -1
	## The exact value read (a moisture, a depth in u, hours), in the probe's own integer units.
	var value: int = 0
	## Whose value it is: a bed, a tree, a zone, a body height (the probe's own numbering), -1 for nobody.
	var who: int = -1

	func clear() -> void:
		"""Nothing under the point."""
		entry = -1
		area = -1
		value = 0
		who = -1

	func same_as(other: Reading) -> bool:
		"""Whether `other` reads exactly the same."""
		return entry == other.entry and area == other.area and value == other.value and who == other.who

	func copy_from(other: Reading) -> void:
		"""Take `other`'s fields."""
		entry = other.entry
		area = other.area
		value = other.value
		who = other.who


## The default grid step for outlines (m) and how high outlines are drawn (m).
const CELL_M: float = 0.5
const DRAW_Y_M: float = 0.05


func read_into(_point_m: Vector2, out: Reading) -> bool:
	"""What lies at the ground point (x, z metres), into `out`; false (and `out` cleared) where there is nothing to
	say. Must not allocate."""
	out.clear()
	return false


func describe(_reading: Reading) -> String:
	"""The Reading in words, for the readout (called on a change only)."""
	return ""


func can_outline() -> bool:
	"""Whether this layer's areas can be outlined over another layer."""
	return false


func field_bounds_m() -> Rect2:
	"""The ground (x, z metres) the areas lie in; empty when there are none."""
	return Rect2()


func field_cell_m() -> float:
	"""The grid step the outlines sample at (m)."""
	return CELL_M


func draw_y_m() -> float:
	"""How high above the ground the outlines are drawn (m): at the layer's own marks."""
	return DRAW_Y_M


func field_revision() -> int:
	"""Moves whenever the areas -- or what `describe` would say -- may have changed."""
	return 0


func legend_ticks() -> PackedStringArray:
	"""The legend's threshold words when they follow a subject (the Water range's depths for whoever is painted);
	empty when the layer's own fixed ones stand. Called only when `field_revision` moves."""
	return PackedStringArray()


func legend_caption() -> String:
	"""The legend's caption when it follows a subject; empty when the layer's own fixed one stands."""
	return ""
