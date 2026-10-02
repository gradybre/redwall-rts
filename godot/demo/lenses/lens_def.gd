extends RefCounted
## One map layer as DATA (decision 0581): everything the layers, the picker, the legend, the hover readout and the
## compare outlines need, in one record handed to `map_lenses.gd add_def`. Presentation only.
##
## ADDING A LAYER (a seasonal one, the winter's fuel): fill one of these and add it --
##
##     var def := LensDefScript.new()
##     def.group = "Woods"; def.label = "Leaf fall"; def.question = "Which trees are bare?"
##     def.show = my_overlay.set_shown                     # show(on: bool) switches the layer's own marks
##     def.swatches = PackedColorArray([...]); def.words = PackedStringArray([...])
##     def.ramp_from = 0; def.ramp_count = 3               # the swatches that form an ordered ramp (0: keys only)
##     def.ticks = PackedStringArray([...])                # one threshold line per ramp entry, with its units
##     def.caption = "Leaf cover, % of a full crown"       # what the ramp measures, with its units
##     def.areas = PackedInt32Array([0, 1, 2])             # which swatches the probe reads as areas (default: the ramp)
##     def.over = LensPalette.OVER_GRASS                    # what the areas are painted over (the colour check)
##     def.probe = MyProbe.new(...)                        # lens_probe.gd: the readout and the outlines (optional)
##     var row: int = demo_farm.lenses.add_def(def)
##
## V reaches it (after the layers already added), the picker lists it, the legend draws its ramp and keys, the
## readout and the compare list follow its probe, and the colour check (test_demo_lens_kit.gd and the live harness)
## covers its ramp -- with no change to the picker, V or the readout. Put its area colours in lens_palette.gd.

const ProbeScript := preload("res://demo/lenses/lens_probe.gd")
const SubjectScript := preload("res://demo/lens_subject.gd")
const Palette := preload("res://demo/lenses/lens_palette.gd")

## The planning question's group ("Growing", "Getting there", "Woods", "Underground"), the layer's own label, and
## its ONE question.
var group: String = ""
var label: String = ""
var question: String = ""
## `show(on: bool)`: switches the layer's own marks.
var show: Callable = Callable()
## The legend: a swatch and its word each (a swatch with alpha 0 is words only).
var swatches: PackedColorArray = PackedColorArray()
var words: PackedStringArray = PackedStringArray()
## Which swatches form the ordered RAMP (drawn as one continuous bar with its thresholds); the rest are keys.
var ramp_from: int = 0
var ramp_count: int = 0
## One short threshold per ramp entry, with units ("≤0.25 m"), and what the ramp measures.
var ticks: PackedStringArray = PackedStringArray()
var caption: String = ""
## Which swatches are AREAS -- the classes the probe's readings name and the outlines trace (empty: the ramp's).
var areas: PackedInt32Array = PackedInt32Array()
## The ground the areas are painted over (lens_palette.gd OVER_*), for the colour check.
var over: Color = Palette.OVER_GRASS
## What the layer says about a point (null: no readout, not comparable).
var probe: ProbeScript = null
## Whom the layer is drawn for (null: nobody in particular).
var subject: SubjectScript = null
## `state() -> bool` for a layer with an outside switch of its own (map_lenses.gd `follow_state`); invalid: on V's
## cycle.
var follow: Callable = Callable()
