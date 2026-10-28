class_name SaveSystem
extends RefCounted
## Versioned, checksummed save files for one Character (docs/SAVE_SYSTEM.md).
##
## File = JSON envelope:
##   {"format": FORMAT, "version": VERSION, "saved_at": unix,
##    "checksum": sha256(payload_text), "payload": payload_text}
## The payload is stored as exact JSON text so the checksum covers precisely the
## bytes that will be parsed (re-serialising parsed JSON is not stable: 1 -> 1.0).
##
## Write procedure (never damages the last valid save):
##   1. write "<path>.tmp" and close it
##   2. read it back and verify format + checksum
##   3. copy the current "<path>" (if any) to "<path>.bak"
##   4. replace "<path>" with the verified temp file
## If the process dies at any point, either the old save or its .bak copy is
## intact; load() falls back to the .bak automatically. Nothing else is deleted.

const FORMAT := "echoes_of_the_hollow_save"
const VERSION := 15
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"


class LoadResult:
	extends RefCounted
	var character: Character
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	## "main", "backup" or "" when nothing could be loaded.
	var source: String = ""

	func ok() -> bool:
		return character != null


## Saves `character` to `path`. Returns OK or the failing Error code.
## `meta`: display information (location, play time, class, kind) stored next to
## the payload; never used to restore game state.
static func save_to(character: Character, path: String, meta: Dictionary = {}) -> Error:
	return write_payload(character.to_dict(), path, meta if not meta.is_empty() else describe(character))


## Strictly increasing write order (ms clock, never repeating within a run).
static var _last_order: int = 0


static func _next_order() -> int:
	_last_order = maxi(_last_order + 1, int(Time.get_unix_time_from_system() * 1000.0))
	return _last_order


## Test hook: the next write fails after the temp file (simulated crash/full disk).
static var fail_next_write: bool = false


## Writes an already captured snapshot (SaveCoordinator takes it in one frame).
static func write_payload(payload: Dictionary, path: String, meta: Dictionary = {}) -> Error:
	# full precision: stored decimals (weapon base damage, Striking) load back bit-identical
	var payload_json := JSON.stringify(payload, "", true, true)
	var envelope := {
		"format": FORMAT,
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"order": _next_order(),
		"checksum": payload_json.sha256_text(),
		"payload": payload_json,
		"meta": meta,
	}
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var temp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope, "\t", true))
	file.close()
	if fail_next_write:
		fail_next_write = false
		DirAccess.remove_absolute(temp_path)
		return ERR_FILE_CANT_WRITE
	var check: Variant = _read_payload(temp_path, PackedStringArray())
	if check == null:
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(path):
		var copied := DirAccess.copy_absolute(path, path + BACKUP_SUFFIX)
		if copied != OK:
			return copied
	return DirAccess.rename_absolute(temp_path, path)


## Loads a character from `path` (falls back to "<path>.bak" if the main file
## is missing or damaged). Never raises: problems are reported in the result.
static func load_from(path: String, database: GameDatabase) -> LoadResult:
	var result := LoadResult.new()
	var payload: Variant = _read_payload(path, result.errors) if FileAccess.file_exists(path) else null
	result.source = "main"
	if payload == null:
		if not FileAccess.file_exists(path):
			result.errors.append("save file not found: %s" % path)
		var backup := path + BACKUP_SUFFIX
		if FileAccess.file_exists(backup):
			payload = _read_payload(backup, result.errors)
			result.source = "backup"
			if payload != null:
				result.warnings.append("main save unusable - loaded the backup copy")
	if payload == null:
		result.source = ""
		return result
	result.character = Character.from_dict(payload, database, result.warnings)
	return result


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BACKUP_SUFFIX)


## Parses and validates one file; returns the migrated payload or null.
static func _read_payload(path: String, errors: PackedStringArray) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("%s: empty or unreadable" % path.get_file())
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: invalid JSON (line %d: %s)" % [path.get_file(), json.get_error_line(), json.get_error_message()])
		return null
	var envelope: Variant = json.data
	if not envelope is Dictionary or envelope.get("format") != FORMAT:
		errors.append("%s: not an Echoes of the Hollow save" % path.get_file())
		return null
	var version := int(envelope.get("version", -1))
	if version < 1:
		errors.append("%s: missing save version" % path.get_file())
		return null
	if version > VERSION:
		errors.append("%s: saved by a newer game version (%d > %d)" % [path.get_file(), version, VERSION])
		return null
	var payload_text: Variant = envelope.get("payload")
	if not payload_text is String:
		errors.append("%s: payload missing" % path.get_file())
		return null
	if (payload_text as String).sha256_text() != str(envelope.get("checksum", "")):
		errors.append("%s: checksum mismatch (file damaged or edited)" % path.get_file())
		return null
	var payload: Variant = JSON.parse_string(payload_text)
	if not payload is Dictionary:
		errors.append("%s: payload is not valid JSON" % path.get_file())
		return null
	return SaveMigrations.migrate(payload, version, errors)


## Display information of a character for save slots.
static func describe(character: Character) -> Dictionary:
	var map_def: MapDefinition = character.database.maps.get(character.world.map_id)
	var class_def := character.database.get_class_def(character.classes.active_class_id)
	return {
		"location": map_def.display_name if map_def != null else String(character.world.map_id),
		"play_time": int(character.play_time),
		"class": class_def.display_name if class_def != null else "",
		"level": character.classes.get_level(character.classes.active_class_id),
	}


## Header of a save file without loading it: {"valid", "path", "saved_at",
## "version", "meta", "error"}. "valid" requires format, version and checksum;
## a damaged main file with a usable backup reports the backup.
static func read_info(path: String) -> Dictionary:
	var info := {"valid": false, "path": path, "saved_at": 0, "order": 0, "version": 0, "meta": {}, "error": "", "exists": false}
	for candidate: String in [path, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		info.exists = true
		var json := JSON.new()   # instance parse: no engine error for damaged files
		var envelope: Variant = json.data if json.parse(FileAccess.get_file_as_string(candidate)) == OK else null
		if not envelope is Dictionary or envelope.get("format") != FORMAT:
			info.error = "damaged"
			continue
		var payload_text: Variant = envelope.get("payload")
		if not payload_text is String or (payload_text as String).sha256_text() != str(envelope.get("checksum", "")):
			info.error = "damaged"
			continue
		if int(envelope.get("version", 0)) > VERSION:
			info.error = "newer game version"
			continue
		info.valid = true
		info.error = "" if candidate == path else "restored from backup"
		info.saved_at = int(envelope.get("saved_at", 0))
		info.order = int(envelope.get("order", info.saved_at * 1000))
		info.version = int(envelope.get("version", 0))
		info.meta = envelope.get("meta", {}) if envelope.get("meta") is Dictionary else {}
		return info
	return info
