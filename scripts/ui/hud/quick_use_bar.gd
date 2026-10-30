class_name QuickUseBar
extends HBoxContainer
## HUD quick use, the left pair of the combat bar (UI Layout Lock 1.0): key 1 Hearth Flask and key 2 the
## slotted special potion as compact HudSlots. Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): no permanent
## count - the bottle's liquid shows what is left (flask_fill / potion_fill), the exact number, the name and
## why it cannot be used are in the hover tooltip; the potion cooldown darkens the slot behind the bottle
## with its seconds in the corner. Pure presentation over Character.consumables (ConsumableService) - never
## drives a timer, never changes a rule.

## Potion liquid in whole quarters of one bag stack (ItemDefinition.max_stack): the stack is the only limit the
## data knows - no "largest stack ever", no new capacity. 1 potion is the lowest visible step, a full stack (or
## more in several stacks) the full bottle; quarters never pretend an exact percentage.
const POTION_STEPS := 4

var bridge: PlayerProgressionBridge

var _flask: HudSlot
var _potion: HudSlot


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 6)
	_flask = _slot("1", "FlaskSlot", HudSlot.Glyph.FLASK)
	_potion = _slot("2", "PotionSlot", HudSlot.Glyph.POTION)


func _slot(key: String, slot_name: String, glyph: HudSlot.Glyph) -> HudSlot:
	var slot := HudSlot.new()
	slot.name = slot_name
	slot.key = key
	slot.glyph = glyph
	add_child(slot)
	return slot


func _process(_delta: float) -> void:
	visible = bridge != null and bridge.is_bound()
	if visible:
		refresh()


## Transient words of the flask and potion slot (tests, gallery): "" or the potion cooldown.
func status_texts() -> PackedStringArray:
	return PackedStringArray([_flask.status_text(), _potion.status_text()])


## Liquid of the Hearth Flask: charges of the real maximum (ConsumableService.max_charges).
static func flask_fill(charges: int, maximum: int) -> float:
	return clampf(float(charges) / float(maxi(1, maximum)), 0.0, 1.0)


## Liquid of a potion stack: quarters of one bag stack, at least one quarter while one potion is left.
static func potion_fill(count: int, stack: int) -> float:
	if count <= 0:
		return 0.0
	var share := float(mini(count, maxi(1, stack))) / float(maxi(1, stack))
	return clampf(ceilf(share * POTION_STEPS) / POTION_STEPS, 1.0 / POTION_STEPS, 1.0)


func refresh() -> void:
	var character := bridge.character
	var state := character.consumables
	var full := ConsumableService.max_charges(character)
	var heal := roundi(ConsumableService.heal_share(character) * 100.0)
	_flask.glyph = HudSlot.Glyph.FLASK
	_flask.glyph_color = UiTheme.HEALTH.lightened(0.1)
	_flask.fill = flask_fill(state.charges, full)
	_flask.usable = state.charges > 0
	_flask.set_status("")
	_flask.tooltip_text = "Hearth Flask  [1]\nCharges: %d / %d\nHeals %d%% of your health per charge.%s" % [state.charges, full, heal,
		"\nEmpty - rest by a fire to refill it." if state.charges <= 0 else "\nRest by a fire to refill it."]
	var definition := character.database.get_item(state.potion_slot) if state.potion_slot != &"" else null
	if definition == null:
		_potion.glyph = HudSlot.Glyph.EMPTY
		_potion.usable = false
		_potion.cooldown_ratio = 0.0
		_potion.fill = 0.0
		_potion.set_status("")
		_potion.tooltip_text = "Potion slot  [2]\nNo potion slotted. Right-click a potion in your bag."
		return
	var count := character.inventory.count(state.potion_slot)
	var cooldown := character.database.rules.potion_cooldown
	var error := ConsumableService.potion_error(character)
	_potion.glyph = HudSlot.Glyph.POTION
	_potion.glyph_color = definition.potion_effect.color.lightened(0.1) if definition.potion_effect != null else UiTheme.RESONANCE
	_potion.fill = potion_fill(count, definition.max_stack)
	_potion.cooldown_ratio = state.cooldown_left / cooldown if cooldown > 0.0 and state.cooldown_left > 0.0 else 0.0
	_potion.usable = error == ""
	_potion.set_status("%ds" % ceili(state.cooldown_left) if state.cooldown_left > 0.0 else "")
	var lines: PackedStringArray = ["%s  [2]" % definition.display_name, "In your bag: %d" % count]
	if definition.potion_effect != null and definition.potion_effect.summary != "":
		lines.append(definition.potion_effect.summary)
	if error != "":
		lines.append(error)
	_potion.tooltip_text = "\n".join(lines)
