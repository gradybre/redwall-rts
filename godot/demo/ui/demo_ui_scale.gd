extends RefCounted
## The demo's interface scale: UI §8.1's `ui_scale` (100, 125 or 150 %), chosen in the game menu's
## Settings (demo_menu.gd). Decision 0261; every demo panel, the level indicator and the action cards' tooltips
## follow it since decision 0391. DEMO UI.
##
## The HUD shell takes it through its own `apply_user_scale`; every demo panel lays itself out on the
## HUD's layout (`UiLayout.compute_into`) and reads the percent from here, so the demo's panels grow with
## the HUD instead of staying at 100 % beside it. `apply` sets it and has every panel place itself again
## (they re-place on the viewport's `size_changed`, which it raises).

const UiLayout := preload("res://scripts/ui/ui_layout.gd")

## The percent every demo panel lays out at.
static var percent: int = UiLayout.USER_SCALE_100


static func fits(width: int, height: int, user_percent: int, minimum_logical_height: float) -> bool:
	"""Whether `user_percent` leaves the HUD's layout at least `minimum_logical_height` logical pixels tall
	in a `width` x `height` window (the demo's panels need that much to be read)."""
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	if not layout.compute_into(maxi(width, UiLayout.SUPPORTED_MIN_WIDTH), maxi(height, UiLayout.SUPPORTED_MIN_HEIGHT),
			user_percent, false, geometry):
		return false
	return geometry.logical_height >= minimum_logical_height


static func effective_scale(size_px: Vector2) -> float:
	"""The HUD's effective scale S for a window of `size_px` at `percent` (UI §1.2: base scale x user scale; a
	window below the supported floor is laid out as the floor, as every demo panel does)."""
	return UiLayout.effective_scale(maxi(int(size_px.x), UiLayout.SUPPORTED_MIN_WIDTH),
		maxi(int(size_px.y), UiLayout.SUPPORTED_MIN_HEIGHT), percent)


static func apply(user_percent: int, viewport: Viewport) -> bool:
	"""Lay the demo's panels out at `user_percent` from now on, and have them place themselves again.
	Refuses a percent UI §1.2 does not define."""
	if not UiLayout.is_user_scale(user_percent):
		return false
	percent = user_percent
	if viewport != null:
		viewport.size_changed.emit()
	return true
