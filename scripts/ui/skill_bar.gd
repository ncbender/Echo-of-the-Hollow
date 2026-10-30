class_name SkillBar
extends HBoxContainer
## HUD row of the four skill slots (Q/E/R/F) in the combat bar (UI Layout Lock 1.0): a compact HudSlot each.
## Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): no permanent words ("Empty", "8 Mana", "Ready") - an empty
## slot is a quiet frame with its key; a cooldown darkens the slot with its seconds; a skill the resource cannot
## pay is dimmed with a thin bar of the resource towards its cost. Name, description, cost, cooldown and the
## reason are in the hover tooltip.
## Pure presentation; reads the bridge's ClassRuntime.

const KEYS := ["Q", "E", "R", "F"]

var bridge: PlayerProgressionBridge

var _slots: Array[HudSlot] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 6)
	for index in KEYS.size():
		var slot := HudSlot.new()
		slot.name = "Skill%s" % KEYS[index]
		slot.key = KEYS[index]
		add_child(slot)
		_slots.append(slot)


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound()   # Combat HUD UX 2.0: four quiet frames even without a skill (one unit)
	if visible:
		refresh()


## The short status words of the four slots (tests, gallery).
func status_texts() -> PackedStringArray:
	var texts: PackedStringArray = []
	for slot in _slots:
		texts.append(slot.status_text())
	return texts


func refresh() -> void:
	var runtime := bridge.class_runtime
	for index in KEYS.size():
		var slot := _slots[index]
		var skill := runtime.skill_in_slot(index)
		if skill == null:
			slot.glyph = HudSlot.Glyph.EMPTY
			slot.letter = ""
			slot.cooldown_ratio = 0.0
			slot.usable = false
			slot.cost_ratio = -1.0
			slot.set_status("")
			slot.tooltip_text = "%s  [%s]\nNo skill in this slot. Slot skills at a class station." % ["Empty slot", KEYS[index]]
			continue
		var params := runtime.params_for(skill)
		var left := runtime.cooldown_left(skill.id)
		var pool := runtime.pool
		var affordable := params.cost <= 0.0 or (pool != null and pool.value + 0.0001 >= params.cost)
		var resource := pool.definition.display_name if pool != null else ""
		var cost := "%d %s" % [roundi(params.cost), resource] if params.cost > 0.0 else "No cost"
		slot.glyph = HudSlot.Glyph.SKILL
		slot.glyph_color = skill.color.lightened(0.2)
		slot.letter = skill.display_name.left(1).to_upper()
		slot.icon = UiSkin.texture(StringName("skills/%s" % skill.id))   # optional art, else the letter glyph
		slot.cooldown_ratio = left / maxf(params.cooldown, 0.01) if left > 0.0 else 0.0
		slot.usable = affordable and left <= 0.0
		slot.set_status("%.1fs" % left if left > 0.0 else "")
		slot.cost_ratio = (pool.value / params.cost if pool != null else 0.0) if not affordable else -1.0
		slot.cost_color = pool.definition.color if pool != null else UiTheme.TEXT_MUTED
		var lines: PackedStringArray = ["%s  [%s]" % [skill.display_name, KEYS[index]]]
		if skill.description != "":
			lines.append(skill.description)
		lines.append("Cost: %s  ·  Cooldown: %.1fs" % [cost, params.cooldown])
		if left > 0.0:
			lines.append("On cooldown: %.1fs." % left)
		if not affordable:
			lines.append("Not enough %s: needs %s." % [resource if resource != "" else "resource", cost])
		slot.tooltip_text = "\n".join(lines)
