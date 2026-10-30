class_name ProgressNotice
extends PanelContainer
## Loot & Progress Feedback 1.0 (docs/LOOT_PROGRESS_FEEDBACK_1_0.md): one compact message above the toasts for a
## real level-up - the hero (the active class's level: emblem, gold accent, "Warrior · Level 7", "+1 talent point"
## only when the rules really gave one) or a weapon mastery (combo icon, steel-cyan accent, "One-Handed Sword
## mastery 9", "New combo: ..." only when one was unlocked). Fed by PlayerProgressionBridge.progress, which only
## fires inside the real XP grants (never on load, class switch or sync).
## Several levels of one grant come in one frame: they are coalesced (one message "Level 5 → 7", one effect).
## Hero and mastery never overlap: they are shown one after the other, the hero first. Each message starts the
## matching world pulse on the hero (LevelUpFx). While the bottom centre is hidden (dialogue) the message waits;
## messages still waiting when the map changes are shown on the next map (session memory only, never saved).

const SHOW := 2.6
const FADE := 0.4
const ICON := Vector2(40, 40)

var bridge: PlayerProgressionBridge:
	set(value):
		if bridge != null and bridge.progress.is_connected(_on_progress):
			bridge.progress.disconnect(_on_progress)
		bridge = value
		if bridge != null:
			bridge.progress.connect(_on_progress)
			_restore_carry.call_deferred()

## Collected in this frame (kind + id -> notice), then queued: [{kind, id, first, level, details}].
var _pending: Dictionary = {}
var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _age: float = 0.0
var _flush_queued: bool = false
static var _carry: Array[Dictionary] = []
static var _carry_owner: Character


func _init() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visible = false


## The message shown now ({} = none) and the ones waiting (tests).
func current() -> Dictionary:
	return _current


func waiting() -> int:
	return _queue.size() + _pending.size()


## Text of the shown message (tests, debugging).
func text() -> String:
	var lines: PackedStringArray = []
	for label: Label in find_children("*", "Label", true, false):
		lines.append(label.text)
	return "\n".join(lines)


func _on_progress(kind: StringName, id: StringName, level: int, detail: String) -> void:
	var key := "%s:%s" % [kind, id]
	var notice: Dictionary = _pending.get(key, {})
	if notice.is_empty():
		notice = {"kind": kind, "id": id, "first": level, "level": level, "details": []}
		_pending[key] = notice
	notice.first = mini(int(notice.first), level)
	notice.level = maxi(int(notice.level), level)
	if detail != "" and not (notice.details as Array).has(detail):
		(notice.details as Array).append(detail)
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


## One grant is over: its coalesced notices join the queue, the hero's first.
func _flush() -> void:
	_flush_queued = false
	var notices: Array = _pending.values()
	_pending.clear()
	notices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.kind == &"hero" and b.kind != &"hero")
	for notice: Dictionary in notices:
		_queue.append(notice)


func _process(delta: float) -> void:
	if _current.is_empty():
		if _queue.is_empty() or not _shown_area_visible():
			return
		_start(_queue.pop_front())
		return
	if not _shown_area_visible():
		return   # dialogue: the message waits
	_age += delta
	modulate.a = clampf((SHOW + FADE - _age) / FADE, 0.0, 1.0)
	if _age >= SHOW + FADE:
		_current = {}
		visible = false


## The bottom centre itself (dialogues hide it); this notice is hidden between messages.
func _shown_area_visible() -> bool:
	var parent := get_parent() as CanvasItem
	return parent != null and parent.is_visible_in_tree()


func _start(notice: Dictionary) -> void:
	_current = notice
	_age = 0.0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", UiTheme.GAP + 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var hero: bool = notice.kind == &"hero"
	var accent := ColorRect.new()
	accent.color = UiTheme.BRONZE if hero else UiTheme.RESONANCE
	accent.custom_minimum_size = Vector2(4, 0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(accent)
	var icon := _icon(notice)
	if icon != null:
		row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override(&"separation", 0)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	for line: Array in lines(notice):
		var label := UiTheme.styled(line[0], line[1])
		label.add_theme_color_override(&"font_color", line[2])
		texts.add_child(label)
	modulate.a = 1.0
	visible = true
	_pulse(hero)


## The message lines [text, variation, colour]: head (name · level, "5 → 7" for several levels at once) and,
## only when real, the extra line (talent points from the rules; the new combo / technique from the data).
func lines(notice: Dictionary) -> Array:
	var db := bridge.character.database if bridge != null and bridge.character != null else null
	if db == null:
		return []
	var level := int(notice.level)
	var first := int(notice.first)
	var span := "Level %d" % level if first >= level else "Level %d → %d" % [first - 1, level]
	var result: Array = []
	if notice.kind == &"hero":
		var definition := db.get_class_def(notice.id)
		result.append(["%s  ·  %s" % [definition.display_name if definition != null else String(notice.id), span], &"SubheadingLabel", UiTheme.PARCHMENT])
		var rules := db.rules.talent_rules()
		var points := rules.points_at_level(level) - rules.points_at_level(first - 1)
		if points > 0 and definition != null and not definition.talent_tree_ids.is_empty():
			result.append(["+%d talent point%s" % [points, "" if points == 1 else "s"], &"SmallLabel", UiTheme.RESONANCE])
		return result
	var family: WeaponFamily = db.weapons.get(notice.id)
	result.append(["%s mastery  ·  %s" % [family.display_name if family != null else String(notice.id), span], &"SmallLabel", UiTheme.TEXT_PRIMARY])
	for detail: String in notice.details:
		result.append(["New: %s" % detail, &"CaptionLabel", UiTheme.RESONANCE])
	return result


## Hero: the class emblem. Mastery: the art of the newest combo the family has at this level (ComboIcons).
func _icon(notice: Dictionary) -> Control:
	var db := bridge.character.database
	if notice.kind == &"hero":
		var definition := db.get_class_def(notice.id)
		return ClassEmblem.new().setup(definition, false, ICON.x) if definition != null else null
	var family: WeaponFamily = db.weapons.get(notice.id)
	if family == null:
		return null
	var best: Dictionary = {}
	for entry: Dictionary in ComboIcons.entries(family):
		if int(entry.level) <= int(notice.level) and (best.is_empty() or int(entry.level) >= int(best.level)):
			best = entry
	var texture := UiSkin.texture(ComboIcons.icon_id(family, best.sequence)) if not best.is_empty() else null
	if texture == null:
		return null
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = ICON
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## The world pulse on the hero (a child of the player: it moves with the hero and leaves with the map).
func _pulse(hero: bool) -> void:
	var player := bridge.player if bridge != null and bridge.is_bound() else null
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	var fx := LevelUpFx.new()
	fx.kind = LevelUpFx.HERO if hero else LevelUpFx.MASTERY
	player.add_child(fx)


## Map change: the message on screen (unless nearly done) and every waiting one come back on the next map.
func _exit_tree() -> void:
	if bridge == null or bridge.character == null:
		return
	_carry.clear()
	_carry_owner = bridge.character
	if not _current.is_empty() and _age < SHOW * 0.5:
		_carry.append(_current)
	_carry.append_array(_queue)
	_carry.append_array(_pending.values())


func _restore_carry() -> void:
	if _carry.is_empty() or bridge == null or bridge.character == null:
		return
	if bridge.character == _carry_owner:
		_queue.append_array(_carry)
	_carry.clear()
	_carry_owner = null
