extends RefCounted
## The infirmary's words: the resident card's lines, the news and incident lines, the infirmary section's lines.
## Decision 0622. Pure: everything is read from the arguments. Plain words (UI §7: the severity is said, never only
## coloured), and the GDD's numbers as the player meets them -- health out of 100, herbs and cloth in U, care in WU.

const Rules := preload("res://demo/infirmary/care_rules.gd")
const Injury := preload("res://scripts/core/injury.gd")

@warning_ignore_start("integer_division")

## InjuryKind's words (GDD §4.3), with their article.
const KIND_WORDS: Array[String] = ["no injury", "a cut", "a bite", "a fall", "exposure", "exhaustion"]
## The same, bare ("Corra Netley's bite").
const KIND_NOUNS: Array[String] = ["", "cut", "bite", "fall", "exposure", "exhaustion"]
const SEVERITY_WORDS: Array[String] = ["", "minor", "serious"]
## Why a patient waits (care_state.gd REFUSE_*, and nobody free).
const WAIT_NO_HERB: String = "no herbs on the shelf — the herbalist gathers more by day"
const WAIT_NO_CLOTH: String = "no cloth left for dressings"
const WAIT_NO_HEALER: String = "nobody free to treat them"
const WAIT_GOING: String = "on the way to rest"
const WAIT_HEALER: String = "a healer is coming"


static func kind_words(kind: int) -> String:
	"""An InjuryKind with its article ("a bite")."""
	return KIND_WORDS[clampi(kind, 0, KIND_WORDS.size() - 1)]


static func injury_words(kind: int, severity: int) -> String:
	"""An injury in words: "a bite (minor)"."""
	return "%s (%s)" % [kind_words(kind), SEVERITY_WORDS[clampi(severity, 0, 2)]]


static func rate_words(rate: int) -> String:
	"""A health rate an hour: "+4 an hour", "−1 an hour", "steady"."""
	if rate == 0:
		return "steady"
	return "%s%d an hour" % ["+" if rate > 0 else "−", absi(rate)]


static func hurt_lines(health: int, kind: int, severity: int, untreated_h: int, rate: int, care: String) -> PackedStringArray:
	"""A hurt resident's card lines: the injury and health, the untreated hours and the rate, and its care."""
	var lines := PackedStringArray()
	lines.append("Hurt: %s · health %d" % [injury_words(kind, severity), health])
	lines.append("Untreated %d h · health %s%s" % [untreated_h, rate_words(rate), " until treated" if rate < 0 else ""])
	if not care.is_empty():
		lines.append(care)
	return lines


static func care_words(healer_name: String, percent: int, waiting: String) -> String:
	"""The treatment's state: "Being treated by Linnet Whinberry — 40%" or "Waiting: <why>"."""
	if not healer_name.is_empty():
		return "Being treated by %s — %d%%" % [healer_name, percent]
	return "" if waiting.is_empty() else "Waiting: " + waiting


static func recovering_line(health: int, rate: int, infirmary: bool, resting: bool) -> String:
	"""A treated resident below full health: "Recovering · health 67 · +4 an hour in the infirmary · up at 70 in about
	1 h"."""
	var where := " in the infirmary" if infirmary else ""
	var line := "Recovering · health %d · %s%s" % [health, rate_words(rate), where]
	if resting and health < Rules.UP_HEALTH and rate > 0:
		line += " · up at %d in about %d h" % [Rules.UP_HEALTH, ceili(float(Rules.UP_HEALTH - health) / float(rate))]
	return line


static func health_line(health: int, rate: int, starving: bool) -> String:
	"""Health below 100 for another cause: "Health 82 · −4 an hour (starving)"."""
	return "Health %d · %s%s" % [health, rate_words(rate), " (starving)" if starving else ""]


static func skill_line(level: int) -> String:
	"""The HEAL skill: "Healing · Level 2"."""
	return "Healing · Level %d" % level


static func short_word(hurt: bool, kind: int, health: int) -> String:
	"""A group row's word: "hurt (bite)", "recovering (67)", or ""."""
	if hurt:
		return "hurt (%s)" % KIND_NOUNS[clampi(kind, 0, KIND_NOUNS.size() - 1)]
	return "recovering (%d)" % health if health < Rules.HEALTH_MAX else ""


static func hurt_notice(who: String, kind: int, severity: int, loss: int, cause: String) -> String:
	"""The news line when someone is hurt."""
	var lost := " and lost %d health" % loss if loss > 0 else ""
	return "%s is hurt%s: %s%s. Needs treatment — herb 1 U and cloth 0.5 U, an hour's care at a bed" % [who,
		"" if cause.is_empty() else " " + cause, injury_words(kind, severity), lost]


static func hurt_summary(who: String, kind: int) -> String:
	"""The one-line form: "Corra Netley hurt (bite) — needs treatment"."""
	return "%s hurt (%s) — needs treatment" % [who, KIND_NOUNS[clampi(kind, 0, KIND_NOUNS.size() - 1)]]


static func treated_notice(healer: String, patient: String, kind: int, health: int) -> String:
	"""The news line when a treatment is done."""
	var rest := "" if health >= Rules.UP_HEALTH else "; resting until health %d" % Rules.UP_HEALTH
	return "%s treated %s's %s (herb 1 U, cloth 0.5 U): health %d%s" % [healer, patient,
		KIND_NOUNS[clampi(kind, 0, KIND_NOUNS.size() - 1)], health, rest]


static func supplies_line(herb_milli: int, cloth_milli: int) -> String:
	"""The care supplies: "Herbs 11.0 U · cloth 23.5 U on the hall's shelf"."""
	return "Herbs %s U · cloth %s U on the hall's shelf" % [units(herb_milli), units(cloth_milli)]


static func patch_line(patch_milli: int, floor_milli: int) -> String:
	"""The herb patch: "Herb patch 128.0 U (gathered down to 32.0 U)"."""
	return "Herb patch by the south road: %s U (gathered down to %s U)" % [units(patch_milli), units(floor_milli)]


static func units(milli: int) -> String:
	"""Milli-U as U with one decimal, floored: "11.5"."""
	return "%d.%d" % [milli / 1000, (milli % 1000) / 100]
