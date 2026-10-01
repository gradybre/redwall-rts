extends RefCounted
## The woodland skin's StyleBoxes and heading font, built from `woodland_textures.gd` pieces.
##
## Each PIECE is one procedural texture, rendered once per process and cached; each STYLEBOX is
## a thin `StyleBoxTexture` over a piece, made per theme slot so that it can carry that slot's
## ORIGINAL content margins. That is the rule that keeps this a skin and not a relayout: a
## Button's minimum size is its stylebox's content margins plus its text, so a stylebox that
## brought its own margins could grow a control the shell had sized exactly. `box()` therefore
## takes the margins from the caller, which reads them off the stylebox being replaced.
##
## Frames draw OUTSIDE their panel through expand margins. The carved band is 14 px wide, and
## the shell places a panel's first control 8 px inside its edge; drawing the band inward would
## put wood under the resource captions. Expand margins move the drawing without moving the
## rectangle, so every hit area, focus rectangle and child position is exactly what it was.

const Palette := preload("res://demo/ui/woodland_palette.gd")
const Textures := preload("res://demo/ui/woodland_textures.gd")

## Noto Serif SemiBold, copied unaltered with its OFL licence from the design reference fonts.
const HEADING_FONT_PATH: String = "res://demo/ui/fonts/NotoSerif-SemiBold.ttf"

## A panel: carved wood outside, a brass inlay, parchment within.
const PIECE_PANEL: StringName = &"panel"
## A panel that clips its own contents cannot draw outside itself, so it wears a thinner carving
## held wholly inside its rectangle.
const PIECE_PANEL_TIGHT: StringName = &"panel_tight"
## The command dock: carved wood outside and a darker planked wood within.
const PIECE_DOCK: StringName = &"dock"
## A notice or the pause banner: a thin brass-lit rim around deep green lacquer.
const PIECE_NOTICE: StringName = &"notice"
## The minimap and tooltip inset: sage-washed map paper, pressed into the panel.
const PIECE_MAP: StringName = &"map"
const PIECE_WOOD: StringName = &"wood"
const PIECE_WOOD_HOVER: StringName = &"wood_hover"
const PIECE_WOOD_DISABLED: StringName = &"wood_disabled"
const PIECE_BRASS: StringName = &"brass"
const PIECE_TILE: StringName = &"tile"
const PIECE_TILE_HOVER: StringName = &"tile_hover"
const PIECE_TILE_DISABLED: StringName = &"tile_disabled"
const PIECE_ROW: StringName = &"row"
const PIECE_FIELD: StringName = &"field"

## Every piece's recipe. Surfaces index `woodland_palette.gd`; `outline` indexes its PIGMENTS.
## size/margin/expand/band/radius are pixels; `tile` tiles the middle instead of stretching it.
const RECIPES: Dictionary = {
	&"panel": {"size": 128, "margin": 26, "expand": 10, "band": 14.0, "radius": 8.0,
		"band_surface": Palette.SURFACE_WOOD, "face": Palette.SURFACE_PARCHMENT, "grain": 0.0,
		"relief": 0.5, "inset": 0.32, "inlay": true, "rivets": true, "outline": 1, "tile": true},
	&"panel_tight": {"size": 64, "margin": 12, "expand": 0, "band": 6.0, "radius": 5.0,
		"band_surface": Palette.SURFACE_WOOD, "face": Palette.SURFACE_PARCHMENT, "grain": 0.0,
		"relief": 0.5, "inset": 0.3, "inlay": true, "rivets": false, "outline": 1, "tile": true},
	&"dock": {"size": 128, "margin": 26, "expand": 10, "band": 14.0, "radius": 8.0,
		"band_surface": Palette.SURFACE_WOOD, "face": Palette.SURFACE_WOOD, "grain": 1.0,
		"relief": 0.5, "inset": 0.35, "inlay": true, "rivets": true, "outline": 1, "tile": true},
	&"notice": {"size": 64, "margin": 12, "expand": 2, "band": 3.0, "radius": 7.0,
		"band_surface": Palette.SURFACE_BRASS, "face": Palette.SURFACE_LACQUER, "grain": 0.25,
		"relief": 0.6, "inset": 0.3, "inlay": false, "rivets": false, "outline": 1, "tile": false},
	&"map": {"size": 64, "margin": 10, "expand": 0, "band": 2.0, "radius": 3.0,
		"band_surface": Palette.SURFACE_WOOD, "face": Palette.SURFACE_MAP, "grain": 0.0,
		"relief": -0.4, "inset": 0.35, "inlay": false, "rivets": false, "outline": 8, "tile": true},
	&"wood": {"size": 48, "margin": 10, "expand": 0, "band": 3.0, "radius": 6.0,
		"band_surface": Palette.SURFACE_WOOD, "face": Palette.SURFACE_WOOD, "grain": 1.0,
		"relief": 0.6, "inset": 0.0, "inlay": false, "rivets": false, "outline": 1, "tile": false},
	&"wood_hover": {"size": 48, "margin": 10, "expand": 0, "band": 3.0, "radius": 6.0,
		"band_surface": Palette.SURFACE_WOOD, "face": Palette.SURFACE_WOOD, "grain": 1.0,
		"relief": 0.7, "inset": 0.0, "inlay": true, "rivets": false, "outline": 1, "tile": false},
	&"wood_disabled": {"size": 48, "margin": 10, "expand": 0, "band": 3.0, "radius": 6.0,
		"band_surface": Palette.SURFACE_WOOD_DISABLED, "face": Palette.SURFACE_WOOD_DISABLED,
		"grain": 1.0, "relief": 0.25, "inset": 0.0, "inlay": false, "rivets": false, "outline": 1,
		"tile": false},
	&"brass": {"size": 48, "margin": 10, "expand": 0, "band": 3.0, "radius": 6.0,
		"band_surface": Palette.SURFACE_BRASS, "face": Palette.SURFACE_BRASS, "grain": 0.3,
		"relief": 0.7, "inset": 0.0, "inlay": false, "rivets": false, "outline": 1, "tile": false},
	&"tile": {"size": 48, "margin": 10, "expand": 0, "band": 3.0, "radius": 5.0,
		"band_surface": Palette.SURFACE_PARCHMENT, "face": Palette.SURFACE_PARCHMENT,
		"grain": 0.0, "relief": 0.7, "inset": 0.0, "inlay": false, "rivets": false, "outline": 8,
		"tile": false},
	&"tile_hover": {"size": 48, "margin": 10, "expand": 0, "band": 3.0, "radius": 5.0,
		"band_surface": Palette.SURFACE_PARCHMENT, "face": Palette.SURFACE_PARCHMENT,
		"grain": 0.0, "relief": 0.8, "inset": 0.0, "inlay": true, "rivets": false, "outline": 8,
		"tile": false},
	&"tile_disabled": {"size": 48, "margin": 10, "expand": 0, "band": 3.0, "radius": 5.0,
		"band_surface": Palette.SURFACE_PARCHMENT_DISABLED,
		"face": Palette.SURFACE_PARCHMENT_DISABLED, "grain": 0.0, "relief": 0.3, "inset": 0.0,
		"inlay": false, "rivets": false, "outline": 8, "tile": false},
	&"row": {"size": 48, "margin": 10, "expand": 0, "band": 2.0, "radius": 3.0,
		"band_surface": Palette.SURFACE_PARCHMENT, "face": Palette.SURFACE_PARCHMENT,
		"grain": 0.0, "relief": 0.4, "inset": 0.0, "inlay": false, "rivets": false, "outline": 8,
		"tile": false},
	&"field": {"size": 48, "margin": 10, "expand": 0, "band": 2.0, "radius": 4.0,
		"band_surface": Palette.SURFACE_PARCHMENT, "face": Palette.SURFACE_PARCHMENT,
		"grain": 0.0, "relief": -0.6, "inset": 0.3, "inlay": false, "rivets": false, "outline": 8,
		"tile": false},
}

## The focus ring's texture side, its nine-patch margin and how far it sits outside the control.
## ui_theme.gd's focus outline is 2 px offset 2 px; the ring's three lines sit in that offset.
const RING_SIZE: int = 16
const RING_MARGIN: int = 5
const RING_RADIUS: float = 6.0
const RING_EXPAND: float = 3.0
## Readout hover and pressed washes: umber over parchment, faint enough to keep ink at 4.5:1.
const READOUT_HOVER_ALPHA: float = 0.10
const READOUT_PRESSED_ALPHA: float = 0.18
const READOUT_RADIUS: int = 4

## HIGH CONTRAST (decision 0471, UI §8.1 `high_contrast`): the pieces text is read on are re-rendered with a flat,
## opaque, untextured face -- no grain, no relief, no inset shading, the parchment's lightest tone -- under the same
## carved band, IN PLACE: each cached texture is updated, so every panel and the HUD already wearing it changes at once
## (a live preview), and a piece first drawn later is drawn the same way.
const CONTRAST_PIECES: Array[StringName] = [PIECE_PANEL, PIECE_PANEL_TIGHT, PIECE_MAP, PIECE_ROW, PIECE_FIELD,
	PIECE_TILE, PIECE_TILE_HOVER]

## Whether the text pieces wear the high-contrast face now.
static var high_contrast: bool = false

## Rendered pieces by name, shared across every apply in the process. A texture changes only through
## `set_high_contrast`, which updates it in place for every user at once; StyleBoxes are NOT shared, because each
## carries margins.
static var _pieces: Dictionary = {}
static var _ring: ImageTexture = null
static var _heading_font: Font = null


static func has_recipe(piece: StringName) -> bool:
	"""True when a piece name has a recipe here."""
	return RECIPES.has(piece)


static func piece(name: StringName) -> Texture2D:
	"""The texture for one named piece, rendered on first use. Null for an unknown name."""
	if not RECIPES.has(name):
		return null
	if not _pieces.has(name):
		_pieces[name] = Textures.build(spec_for(name))
	return _pieces[name] as Texture2D


static func spec_for(name: StringName) -> Textures.Spec:
	"""Turn one recipe row into a texture spec, resolving its surfaces to pigment tones."""
	var row: Dictionary = RECIPES[name]
	var spec: Textures.Spec = Textures.Spec.new()
	spec.size = int(row["size"])
	spec.margin = int(row["margin"])
	spec.band = float(row["band"])
	spec.radius = float(row["radius"])
	spec.band_dark = Palette.face_dark(int(row["band_surface"]))
	spec.band_light = Palette.face_light(int(row["band_surface"]))
	spec.face_dark = Palette.face_dark(int(row["face"]))
	spec.face_light = Palette.face_light(int(row["face"]))
	spec.grain = float(row["grain"])
	spec.relief = float(row["relief"])
	spec.inset_shadow = float(row["inset"])
	spec.inlay = Palette.BRASS if bool(row["inlay"]) else Color(0.0, 0.0, 0.0, 0.0)
	spec.rivets = bool(row["rivets"])
	spec.outline = Palette.PIGMENTS[int(row["outline"])]
	spec.noise_seed = hash(name) & 0xFFFF
	if high_contrast and CONTRAST_PIECES.has(name):
		_flatten(spec, int(row["face"]))
	return spec


static func _flatten(spec: Textures.Spec, face: int) -> void:
	"""The high-contrast face: one opaque tone, no grain, relief or inset shading, a dark outline."""
	spec.face_dark = Palette.face_light(face)
	spec.face_light = Palette.face_light(face)
	spec.grain = 0.0
	spec.relief = 0.0
	spec.inset_shadow = 0.0
	spec.outline = Palette.DEEP_SHADE


static func set_high_contrast(on: bool) -> int:
	"""Turn the high-contrast face on or off, re-rendering the text pieces already drawn in place (see HIGH
	CONTRAST); returns how many were redrawn."""
	if on == high_contrast:
		return 0
	high_contrast = on
	var redrawn: int = 0
	for name: StringName in CONTRAST_PIECES:
		if _pieces.has(name):
			(_pieces[name] as ImageTexture).update(Textures.build_image(spec_for(name)))
			redrawn += 1
	return redrawn


static func box(name: StringName, margins: PackedFloat32Array) -> StyleBoxTexture:
	"""A StyleBoxTexture over one piece, carrying the caller's content margins (l, t, r, b)."""
	var row: Dictionary = RECIPES.get(name, RECIPES[PIECE_WOOD])
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = piece(name if RECIPES.has(name) else PIECE_WOOD)
	style.set_texture_margin_all(float(row["margin"]))
	style.set_expand_margin_all(float(row["expand"]))
	var mode: StyleBoxTexture.AxisStretchMode = StyleBoxTexture.AXIS_STRETCH_MODE_TILE \
		if bool(row["tile"]) else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_horizontal = mode
	style.axis_stretch_vertical = mode
	_set_content_margins(style, margins)
	return style


static func focusable(control: Control, margins: PackedFloat32Array) -> void:
	"""Let a demo action control take keyboard focus (Tab, Shift+Tab, F7) and wear the HUD's focus ring
	while it has it (decision 0261). The ring is the control's own `focus` StyleBox, so it goes when the
	control does (decision 0198); a click's focus is hidden in Godot 4.7, so the ring shows for the
	keyboard only."""
	control.focus_mode = Control.FOCUS_ALL
	control.add_theme_stylebox_override(&"focus", ring_box(margins))


static func ring_box(margins: PackedFloat32Array) -> StyleBoxTexture:
	"""The focus ring as a StyleBox: drawn just outside the control, never over its content."""
	if _ring == null:
		_ring = Textures.ring(RING_SIZE, RING_RADIUS)
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _ring
	style.draw_center = false
	style.set_texture_margin_all(float(RING_MARGIN))
	style.set_expand_margin_all(RING_EXPAND)
	_set_content_margins(style, margins)
	return style


static func wash(alpha: float, margins: PackedFloat32Array) -> StyleBoxFlat:
	"""A faint umber wash for a readout's hover and pressed states; no border, no texture."""
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(Palette.UMBER, alpha)
	style.set_corner_radius_all(READOUT_RADIUS)
	_set_content_margins(style, margins)
	return style


static func clear(margins: PackedFloat32Array) -> StyleBoxEmpty:
	"""An invisible StyleBox that still carries the original content margins."""
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	_set_content_margins(style, margins)
	return style


static func margins_of(style: StyleBox) -> PackedFloat32Array:
	"""A StyleBox's four content margins (l, t, r, b); zeros for a missing one."""
	var out: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	if style == null:
		return out
	out[0] = style.get_margin(SIDE_LEFT)
	out[1] = style.get_margin(SIDE_TOP)
	out[2] = style.get_margin(SIDE_RIGHT)
	out[3] = style.get_margin(SIDE_BOTTOM)
	return out


static func _set_content_margins(style: StyleBox, margins: PackedFloat32Array) -> void:
	"""Copy four content margins onto a StyleBox. A short array leaves the rest at zero."""
	style.content_margin_left = margins[0] if margins.size() > 0 else 0.0
	style.content_margin_top = margins[1] if margins.size() > 1 else 0.0
	style.content_margin_right = margins[2] if margins.size() > 2 else 0.0
	style.content_margin_bottom = margins[3] if margins.size() > 3 else 0.0


static func heading_variant(original: Font) -> Font:
	"""The serif in place of `original`, keeping its OpenType features (the counters' `tnum`).

	The shell's counter face is a FontVariation carrying `"tnum": 1`, so digits share one
	advance and a changing value does not jitter. Swapping in the bare serif would drop that;
	this wraps the serif in a FontVariation with the same features. Null when the serif has not
	been imported, so the caller keeps the original."""
	var serif: Font = heading_font()
	if serif == null:
		return null
	var variant: FontVariation = FontVariation.new()
	variant.base_font = serif
	if original is FontVariation:
		variant.opentype_features = (original as FontVariation).opentype_features.duplicate()
	return variant


static func heading_font() -> Font:
	"""Noto Serif SemiBold, or null when the font has not been imported (degrade, never fail)."""
	if _heading_font == null and ResourceLoader.exists(HEADING_FONT_PATH):
		_heading_font = load(HEADING_FONT_PATH) as Font
	return _heading_font
