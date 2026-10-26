class_name SaveCoordinator
extends Node
## Every save goes through here (Save Foundation 1.1, docs/SAVE_SYSTEM.md):
##  * one write at a time: requests are queued and written one per frame, never
##    in parallel; the snapshot (Character.to_dict) is taken at write time, in a
##    single frame, so it is always consistent
##  * periodic autosave every AUTOSAVE_INTERVAL seconds of ACTIVE play (not
##    while paused, loading/travelling or without a running map), if enabled
##  * critical saves (milestones: arriving in Haven, quest completion, class
##    choice, waystone, restoration ...) ALWAYS happen - the periodic switch and
##    any cooldown never drop them; several pending critical/auto requests are
##    merged into ONE autosave write that contains all changes
##  * autosaves rotate over three slots (oldest first) and never touch the five
##    manual slots
## Child of SessionState (the only autoload); processes while the tree is paused
## so a manual save from the pause menu works, but only counts unpaused time.

signal save_started(kind: Kind)
## `id` = request id from request_*; ok + a short message for the HUD.
signal save_finished(id: int, ok: bool, kind: Kind, message: String)

enum Kind { AUTO, CRITICAL, MANUAL }

const AUTOSAVE_INTERVAL := 300.0

var session: SessionState
var periodic_enabled: bool = true
## Active play seconds since the last autosave (periodic or critical).
var active_time: float = 0.0
## Last finished write, for tests and the save menu.
var last_result: Dictionary = {}

var _auto_pending: Array[int] = []      # request ids merged into the next autosave
var _critical_pending: bool = false
var _manual_pending: Array[Dictionary] = []   # {"id", "slot"}
var _next_id: int = 1
var _reasons: PackedStringArray = []
## A failed critical save is retried after this many seconds (never dropped).
const RETRY_DELAY := 5.0
var _retry_left: float = -1.0


func _init(owner_session: SessionState = null) -> void:
	session = owner_session
	process_mode = Node.PROCESS_MODE_ALWAYS


## Periodic (low priority) autosave request. Merged with other pending ones.
func request_autosave(reason: String = "periodic") -> int:
	var id := _next_id
	_next_id += 1
	_auto_pending.append(id)
	_reasons.append(reason)
	return id


## Milestone save: always written (even with periodic autosave off).
func request_critical(reason: String) -> int:
	var id := request_autosave(reason)
	_critical_pending = true
	return id


func request_manual(slot: int) -> int:
	var id := _next_id
	_next_id += 1
	_manual_pending.append({"id": id, "slot": clampi(slot, 1, SaveSlots.MANUAL_SLOTS)})
	return id


func has_pending() -> bool:
	return not _auto_pending.is_empty() or not _manual_pending.is_empty()


## A consistent, safe moment: a ready map, no map transition, a character.
func can_write() -> bool:
	if session == null or session.character == null or session.is_traveling():
		return false
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene is GameMap and scene.is_node_ready()


func _process(delta: float) -> void:
	if session != null and not get_tree().paused and can_write():
		active_time += delta
		session.character.play_time += delta
		if periodic_enabled and active_time >= AUTOSAVE_INTERVAL and _auto_pending.is_empty():
			request_autosave("periodic")
	if _retry_left > 0.0:
		_retry_left -= delta
		if _retry_left <= 0.0:
			request_critical("retry after a failed save")
	flush()


## Writes at most one pending save now (manual first). Returns true if it wrote.
func flush() -> bool:
	if not has_pending() or not can_write():
		return false
	if not _manual_pending.is_empty():
		var request: Dictionary = _manual_pending.pop_front()
		_write(request.id, Kind.MANUAL, SaveSlots.manual_path(session.save_path, request.slot), [request.id])
		return true
	var ids := _auto_pending.duplicate()
	var kind := Kind.CRITICAL if _critical_pending else Kind.AUTO
	_auto_pending.clear()
	_critical_pending = false
	_write(ids[ids.size() - 1], kind, SaveSlots.auto_path(session.save_path, SaveSlots.next_auto_slot(session.save_path)), ids)
	_reasons.clear()
	return true


func _write(id: int, kind: Kind, path: String, ids: Array) -> void:
	save_started.emit(kind)
	var character := session.character
	var meta := SaveSystem.describe(character)
	meta["kind"] = ["autosave", "milestone", "manual"][kind]
	meta["reason"] = ", ".join(_reasons) if kind != Kind.MANUAL else "manual"
	var error := SaveSystem.write_payload(character.to_dict(), path, meta)
	var ok := error == OK
	if ok and kind != Kind.MANUAL:
		active_time = 0.0
	if not ok and kind == Kind.CRITICAL:
		_retry_left = RETRY_DELAY   # milestones are written again until they succeed
	last_result = {"ok": ok, "kind": kind, "path": path, "error": error}
	var message := "Progress saved" if ok else "Save failed (%s)" % error_string(error)
	for request_id: int in ids:
		save_finished.emit(request_id, ok, kind, message)


## A different character was loaded: pending writes of the old one are dropped
## and the periodic timer starts over.
func reset() -> void:
	_auto_pending.clear()
	_manual_pending.clear()
	_critical_pending = false
	_reasons.clear()
	_retry_left = -1.0
	active_time = 0.0
