@tool
extends EditorPlugin
## Registers the demo pack's export plugin (decision 1841). Editor-only: the preset's exclude_filter keeps addons/ out
## of the pack.

const ExportPlugin := preload("res://addons/demo_pack_files/export_plugin.gd")

var _export: EditorExportPlugin = null


func _enter_tree() -> void:
	"""Register the export plugin for every export this editor runs; it acts only on the demo_build feature."""
	_export = ExportPlugin.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	"""Unregister it and drop the reference."""
	remove_export_plugin(_export)
	_export = null
