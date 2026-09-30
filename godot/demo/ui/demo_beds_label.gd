extends RefCounted
## The HUD's Beds cell says whose beds it counts. Decision 0211 (the underground revamp's P5 carry-over). Presentation
## only.
##
## THE CHOICE: RELABEL, NOT FEED. UI-SET's top-left Beds counter is the SETTLEMENT's (the simulation's housing), which
## the demo does not run, so the shell draws it "Unavailable" behind a lock -- and with the demo's burrow homes full of
## beds, "Beds: Unavailable" read as a bug (the P5 brief). The Food cell next to it is fed the demo pantry's
## total, but through the shell's own entry point for a WIRED counter (farm_hud.gd `set_counter_display`); the shell
## REFUSES a value for an unwired one by contract ("writing a value into it would be exactly the fabricated reading
## this shell exists not to produce", ui_shell.gd), and the design (§4 "the HUD's Beds stays the simulation's") and
## decision 0210 keep this counter the simulation's. So the demo writes NO VALUE: it keeps the shell's honest
## "Unavailable" and relabels the cell's CAPTION to say whose figure it is -- CAPTION, "Sim beds" -- with a TOOLTIP on
## the cell pointing to where the demo's beds are counted (a home's panel, each resident's panel). The demo's own bed
## count lives in the Tunnels panel ("Burrow homes: 1 (3 demo beds)").
##
## UIManager and the shell repaint the cell (a relayout, a profile change) with its own caption; `sync()` notices and
## writes the relabel back. Per frame it compares two strings.

const UiShell := preload("res://scripts/ui/ui_shell.gd")

const CAPTION: String = "Sim beds"
const TOOLTIP: String = "The settlement simulation's bed count -- the simulation is not running in this demo. " \
		+ "The demo's beds are in its burrow homes: select a home (Tunnels panel) to fit and count them; a resident's " \
		+ "panel names its bed."

var _shell: UiShell = null


func bind(shell: UiShell) -> void:
	"""Relabel this HUD shell's Beds cell (null: nothing to do)."""
	_shell = shell


func sync() -> bool:
	"""Keep the Beds cell's caption and tooltip the demo's (see THE CHOICE); true when it wrote them this call. The
	cell's value is never touched."""
	if _shell == null or not is_instance_valid(_shell):
		return false
	var caption: Label = _shell.counter_caption_label(UiShell.ID_BEDS)
	var cell := _shell.control_for(UiShell.ID_BEDS) as Control
	if caption == null or cell == null or (caption.text == CAPTION and cell.tooltip_text == TOOLTIP):
		return false
	caption.text = CAPTION
	cell.tooltip_text = TOOLTIP
	return true
