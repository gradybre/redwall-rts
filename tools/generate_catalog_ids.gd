extends SceneTree
## Authoring/build-time generator for `godot/data/catalog_ids.json` (ruling §10B, GDD §4.2).
##
## Usage, from the repository root:
##     godot --headless --path godot --script "$PWD/tools/generate_catalog_ids.gd"
##     godot --headless --path godot --script "$PWD/tools/generate_catalog_ids.gd" -- --check
##
## Prefer `tools/generate_catalog_ids.sh`, which asserts that this actually ran: `godot` invoked
## without a correct `--path` silently opens the project manager and exits 0, so an exit status
## of 0 is not on its own evidence that anything happened (docs/ENVIRONMENT.md).
##
## `--check` verifies the committed artifact and writes nothing, for CI. The default mode writes,
## and is reproducible: catalog_ids.gd's single canonical encoder is a pure function of the
## registries, so running this twice produces byte-identical output and the second run reports
## `action=unchanged`.
##
## This is the ONLY writer of the artifact. Runtime compares and refuses; it never rewrites.

const CatalogIds := preload("res://scripts/core/catalog_ids.gd")

const MARKER: String = "##CATALOG_IDS## "
const CHECK_FLAG: String = "--check"
const EXIT_OK: int = 0
const EXIT_REFUSED: int = 1


func _initialize() -> void:
	"""Build the artifact from the registries, then either check it or write it."""
	var built: CatalogIds.BuildResult = CatalogIds.build()
	if not built.ok:
		printerr("catalog_ids: refused to build: %s (%s)" % [built.error, built.detail])
		quit(EXIT_REFUSED)
		return
	if OS.get_cmdline_user_args().has(CHECK_FLAG):
		quit(_check(built.artifact))
		return
	quit(_write(built.artifact))


func _check(artifact: CatalogIds.Artifact) -> int:
	"""Verify the committed artifact against the freshly built one without writing anything."""
	var result: CatalogIds.VerifyResult = CatalogIds.verify_file()
	if not result.ok:
		printerr("catalog_ids: %s does not match the installed catalog: %s (%s)"
			% [CatalogIds.ARTIFACT_PATH, result.error, result.detail])
		return EXIT_REFUSED
	_report(artifact, "checked")
	return EXIT_OK


func _write(artifact: CatalogIds.Artifact) -> int:
	"""Write the canonical bytes, unless the committed file already holds exactly them."""
	if _existing_bytes() == artifact.bytes:
		_report(artifact, "unchanged")
		return EXIT_OK
	var file: FileAccess = FileAccess.open(CatalogIds.ARTIFACT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("catalog_ids: could not open %s for writing (error %d)"
			% [CatalogIds.ARTIFACT_PATH, FileAccess.get_open_error()])
		return EXIT_REFUSED
	file.store_buffer(artifact.bytes)
	file.close()
	if _existing_bytes() != artifact.bytes:
		printerr("catalog_ids: the file on disk does not match what was written")
		return EXIT_REFUSED
	_report(artifact, "wrote")
	return EXIT_OK


func _existing_bytes() -> PackedByteArray:
	"""The committed artifact's exact bytes, or an empty array when there is no file yet."""
	if not FileAccess.file_exists(CatalogIds.ARTIFACT_PATH):
		return PackedByteArray()
	var file: FileAccess = FileAccess.open(CatalogIds.ARTIFACT_PATH, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


func _report(artifact: CatalogIds.Artifact, action: String) -> void:
	"""Print the one machine-readable line the shell wrapper asserts on."""
	print(MARKER + "action=%s bytes=%d sha256=%s domains=%d rows=%d path=%s"
		% [action, artifact.bytes.size(), artifact.digest_hex(), artifact.domains.size(),
			artifact.row_count, CatalogIds.ARTIFACT_PATH])
