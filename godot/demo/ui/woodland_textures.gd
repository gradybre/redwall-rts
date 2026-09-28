extends RefCounted
## Procedural textures for the woodland skin: carved wood, parchment, brass and rivets.
##
## ART-UI-11 and ASSETS.md forbid using the woodland concept as a runtime overlay or cutting it
## into pieces, and paid image generation is not approved. So every texel here is COMPUTED: a
## rounded-rectangle distance field shapes the piece, a seamless FastNoiseLite field mottles
## the parchment and warps the wood grain, and a moulding profile lit from the upper left
## (ART-LOCK-001 §4's 225 degree light) carves the frame. Colours come only from
## `woodland_palette.gd`'s twelve pigments and their blends.
##
## ---------------------------------------------------------------------------------------
## EVERY PIECE IS A NINE-PATCH, AND ITS MIDDLE TILES WITHOUT A SEAM. `StyleBoxTexture` tiles
## the region between the margins, whose period is `size - 2 * margin`. The noise image is
## generated seamless at exactly that period and sampled at `(x - margin) mod period`, so the
## right edge of one tile meets the left edge of the next in the same grain. The wood rings
## follow DEPTH from the outer edge rather than x or y, which is what mitres the corners.
##
## Generation runs once per piece per process, off every frame path: `woodland_styles.gd`
## caches the finished textures, and nothing here is called from `_process`.

const Palette := preload("res://demo/ui/woodland_palette.gd")

## ART-LOCK-001 §4: light from the upper left, 45 degrees up. Screen-space unit vector.
const LIGHT_X: float = -0.70710678
const LIGHT_Y: float = -0.70710678
## Wood grain: rings per pixel of depth, and how hard the noise warps them.
const RING_FREQUENCY: float = 2.1
const RING_WARP: float = 5.5
## The carved groove's position across the band (0 = outer edge, 1 = inner) and its softness.
const GROOVE_AT: float = 0.64
const GROOVE_WIDTH: float = 0.9
const GROOVE_DEPTH: float = 0.28
## Width of the brass inlay line between the carved band and the field.
const INLAY_WIDTH: float = 1.4
## The one-pixel ink contour every piece carries on its outer edge.
const OUTLINE_WIDTH: float = 1.2
## Paper speckle: amplitude of the per-texel fibre noise.
const FIBRE_AMOUNT: float = 0.12
## How much of a face's tone range the mottle spans around its middle: paper is quiet, and
## wood streaks a little more. Both stay inside the range the contrast tests check.
const PAPER_SPREAD: float = 0.55
const GRAIN_SPREAD: float = 0.8
## How far the inset shadow reaches into the field, in pixels.
const INSET_REACH: float = 2.6
## How far a rivet's shadow falls toward the lower right, in pixels.
const RIVET_SHADOW_OFFSET: float = 0.8
## FastNoiseLite settings for the mottle and the grain warp.
const NOISE_FREQUENCY: float = 0.045
const NOISE_OCTAVES: int = 4
const NOISE_SKIRT: float = 0.12


## One textured piece: shape, band, field and finish.
class Spec:
	extends RefCounted
	## Square texture side in pixels.
	var size: int = 48
	## Nine-patch margin in pixels; the tiled middle is `size - 2 * margin` wide.
	var margin: int = 10
	## Width of the carved band from the outer edge, in pixels.
	var band: float = 3.0
	## Outer corner radius in pixels.
	var radius: float = 6.0
	## The band's and the field's tone ranges.
	var band_dark: Color = Palette.DEEP_SHADE
	var band_light: Color = Palette.UMBER
	var face_dark: Color = Palette.OAT
	var face_light: Color = Palette.CREAM
	## 1.0 draws wood grain in the field, 0.0 draws paper mottle; between is brushed metal.
	var grain: float = 0.0
	## Moulding light strength. Positive stands proud; negative is pressed in.
	var relief: float = 0.4
	## How dark the field gets where it meets the band.
	var inset_shadow: float = 0.0
	## The thin line between band and field; alpha 0 draws none.
	var inlay: Color = Color(0.0, 0.0, 0.0, 0.0)
	## Brass rivets at the four corners of the band.
	var rivets: bool = false
	var rivet_radius: float = 2.6
	## The outer contour colour.
	var outline: Color = Palette.DEEP_SHADE
	## Seed for the noise, so every piece is reproducible run to run.
	var noise_seed: int = 7

	func period() -> int:
		"""The width of the tiled middle region, which the noise must repeat on."""
		return maxi(1, size - 2 * margin)


static func build(spec: Spec) -> ImageTexture:
	"""Render one piece into a texture. Returns null for a spec too small to have a middle."""
	if spec == null or spec.size <= 2 * spec.margin:
		return null
	var image: Image = Image.create_empty(spec.size, spec.size, false, Image.FORMAT_RGBA8)
	var noise: Image = noise_image(spec.period(), spec.noise_seed)
	for y: int in spec.size:
		for x: int in spec.size:
			image.set_pixel(x, y, texel(spec, noise, x, y))
	if spec.rivets:
		_stamp_rivets(image, spec)
	return ImageTexture.create_from_image(image)


static func noise_image(period: int, noise_seed: int) -> Image:
	"""A seamless, normalised 0..1 greyscale noise field that tiles on `period`."""
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = NOISE_FREQUENCY
	noise.fractal_octaves = NOISE_OCTAVES
	return noise.get_seamless_image(period, period, false, false, NOISE_SKIRT, true)


static func texel(spec: Spec, noise: Image, x: int, y: int) -> Color:
	"""The colour of one texel: transparent outside, carved band, inlay, then field."""
	var depth: float = -_rounded_sdf(spec, float(x) + 0.5, float(y) + 0.5)
	if depth <= -0.5:
		return Color(0.0, 0.0, 0.0, 0.0)
	var period: int = spec.period()
	var n: float = noise.get_pixel(posmod(x - spec.margin, period),
		posmod(y - spec.margin, period)).r
	var color: Color
	if depth < spec.band:
		color = _band_color(spec, depth, n, _facing(spec, float(x) + 0.5, float(y) + 0.5))
	elif spec.inlay.a > 0.0 and depth < spec.band + INLAY_WIDTH:
		color = spec.inlay
	else:
		color = _field_color(spec, depth, n, x, y)
	if depth < OUTLINE_WIDTH:
		color = color.lerp(spec.outline, clampf(OUTLINE_WIDTH - depth, 0.0, 1.0))
	color.a = clampf(depth + 0.5, 0.0, 1.0)
	return color


static func _rounded_sdf(spec: Spec, px: float, py: float) -> float:
	"""Signed distance to the piece's rounded rectangle: negative inside, positive outside."""
	var half: float = float(spec.size) * 0.5
	var qx: float = absf(px - half) - (half - spec.radius)
	var qy: float = absf(py - half) - (half - spec.radius)
	var ox: float = maxf(qx, 0.0)
	var oy: float = maxf(qy, 0.0)
	return sqrt(ox * ox + oy * oy) + minf(maxf(qx, qy), 0.0) - spec.radius


static func _facing(spec: Spec, px: float, py: float) -> float:
	"""How squarely the outward face at this texel looks toward the light, -1..1."""
	var half: float = float(spec.size) * 0.5
	var dx: float = px - half
	var dy: float = py - half
	var qx: float = absf(dx) - (half - spec.radius)
	var qy: float = absf(dy) - (half - spec.radius)
	var nx: float = signf(dx) if qx >= qy else 0.0
	var ny: float = signf(dy) if qy >= qx else 0.0
	if qx > 0.0 and qy > 0.0:
		var length: float = sqrt(qx * qx + qy * qy)
		nx = signf(dx) * qx / length
		ny = signf(dy) * qy / length
	return nx * LIGHT_X + ny * LIGHT_Y


static func _band_color(spec: Spec, depth: float, n: float, facing: float) -> Color:
	"""The carved band: warped grain rings, a moulding lit from the upper left, one groove."""
	var rings: float = 0.5 + 0.5 * sin(depth * RING_FREQUENCY + n * RING_WARP)
	var mix: float = clampf(0.2 + 0.45 * rings + 0.5 * (n - 0.5), 0.0, 1.0)
	var tone: Color = spec.band_dark.lerp(spec.band_light, mix)
	var t: float = depth / spec.band
	var lit: float = spec.relief * cos(PI * t) * facing
	var groove: float = (t - GROOVE_AT) * spec.band / GROOVE_WIDTH
	tone = tone.lerp(Palette.DEEP_SHADE, GROOVE_DEPTH * exp(-groove * groove))
	if lit > 0.0:
		return tone.lerp(spec.band_light.lerp(Palette.OAT, 0.45), lit)
	return tone.lerp(Palette.DEEP_SHADE, -lit)


static func _field_color(spec: Spec, depth: float, n: float, x: int, y: int) -> Color:
	"""The field: paper mottle or wood grain within its tone range, shaded at the band."""
	var period: float = float(spec.period())
	var along: float = float(posmod(y - spec.margin, spec.period()))
	var cycles: float = maxf(1.0, roundf(period / 5.0))
	var streak: float = 0.5 + 0.5 * sin(along * TAU * cycles / period + n * RING_WARP)
	var fibre: float = _hash01(x, y) - 0.5
	var pattern: float = lerpf(n, 0.3 * streak + 0.7 * n, spec.grain)
	var spread: float = lerpf(PAPER_SPREAD, GRAIN_SPREAD, spec.grain)
	var mix: float = 0.55 + (pattern - 0.5) * spread + fibre * FIBRE_AMOUNT
	var tone: Color = spec.face_dark.lerp(spec.face_light, clampf(mix, 0.0, 1.0))
	var reach: float = depth - spec.band - (INLAY_WIDTH if spec.inlay.a > 0.0 else 0.0)
	var shade: float = spec.inset_shadow * exp(-maxf(reach, 0.0) / INSET_REACH)
	return tone.lerp(Palette.DEEP_SHADE, shade)


static func _hash01(x: int, y: int) -> float:
	"""A deterministic per-texel value in 0..1: the fine fibre speckle of paper and grain."""
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)


static func _stamp_rivets(image: Image, spec: Spec) -> void:
	"""Press a brass rivet into the band at each of the four corners."""
	var inset: float = spec.band * 0.5 + spec.radius * 0.3
	var far: float = float(spec.size) - inset
	for corner: int in 4:
		var cx: float = inset if corner % 2 == 0 else far
		var cy: float = inset if corner < 2 else far
		_stamp_rivet(image, cx, cy, spec.rivet_radius)


static func _stamp_rivet(image: Image, cx: float, cy: float, radius: float) -> void:
	"""One domed brass rivet: umber rim, brass body, a cream glint toward the light."""
	var reach: int = ceili(radius + 1.5)
	for y: int in range(floori(cy) - reach, floori(cy) + reach + 1):
		for x: int in range(floori(cx) - reach, floori(cx) + reach + 1):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var under: Color = image.get_pixel(x, y)
			image.set_pixel(x, y, _rivet_texel(under, float(x) + 0.5 - cx, float(y) + 0.5 - cy, radius))


static func _rivet_texel(under: Color, dx: float, dy: float, radius: float) -> Color:
	"""A rivet texel laid over the band: a soft shadow, then the shaded dome."""
	var sx: float = dx - RIVET_SHADOW_OFFSET
	var sy: float = dy - RIVET_SHADOW_OFFSET
	var shadow: float = clampf(radius + RIVET_SHADOW_OFFSET - sqrt(sx * sx + sy * sy), 0.0, 1.0)
	var base: Color = under.lerp(Palette.DEEP_SHADE, 0.45 * shadow)
	base.a = under.a
	var distance: float = sqrt(dx * dx + dy * dy)
	var cover: float = clampf(radius - distance + 0.5, 0.0, 1.0)
	if cover <= 0.0:
		return base
	var glint_x: float = dx + radius * 0.38
	var glint_y: float = dy + radius * 0.38
	var glint_reach: float = sqrt(glint_x * glint_x + glint_y * glint_y) / (radius * 0.75)
	var glint: float = clampf(1.0 - glint_reach, 0.0, 1.0)
	var dome: Color = Palette.BRASS.lerp(Palette.CREAM, 0.7 * glint)
	dome = dome.lerp(Palette.UMBER, clampf((distance / radius - 0.7) * 2.2, 0.0, 0.85))
	return base.lerp(Color(dome, base.a), cover)


static func ring(size: int, radius: float) -> ImageTexture:
	"""The keyboard focus ring: dark, bright brass, dark -- readable on light and dark alike."""
	var image: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var spec: Spec = Spec.new()
	spec.size = size
	spec.radius = radius
	for y: int in size:
		for x: int in size:
			var depth: float = -_rounded_sdf(spec, float(x) + 0.5, float(y) + 0.5)
			image.set_pixel(x, y, _ring_texel(depth))
	return ImageTexture.create_from_image(image)


static func _ring_texel(depth: float) -> Color:
	"""One texel of the three-line focus ring, by depth from its outer edge."""
	if depth <= -0.5 or depth >= 3.5:
		return Color(0.0, 0.0, 0.0, 0.0)
	var color: Color = Palette.focus_bright() if depth >= 1.0 and depth < 2.5 \
		else Palette.FOCUS_DARK
	color.a = clampf(depth + 0.5, 0.0, 1.0) * clampf(3.5 - depth, 0.0, 1.0)
	return color
