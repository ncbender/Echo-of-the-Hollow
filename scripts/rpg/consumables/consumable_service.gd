class_name ConsumableService
extends RefCounted
## Hearth Flask & special potions (Consumables 1.0). Stateless rules over
## Character.consumables; values from ProgressionRules ("Hearth Flask & Potions").
##
## Flask: charges = base + capacity level; heal share by potency level; the
## heal lands when the drink completes (the player's use action), so an
## interrupted drink costs nothing. No cooldown. Rest points refill it.
## Upgrades at Mara cost gold only and are bought atomically (gold checked
## first, one level per purchase).
## Potions: real stackable items with a PotionEffectDefinition. One potion buff
## at a time - a new one replaces the old. The bag stack is consumed only when
## the drink completes; then the shared cooldown starts. Death ends the buff.
## The buff's stat modifiers go through Character runtime modifiers
## (StatResolver), source key BUFF_KEY - never added twice.

const BUFF_KEY := &"potion_buff"
const CAPACITY := &"capacity"
const POTENCY := &"potency"
const GOLD := &"gold_coin"


# --- flask -------------------------------------------------------------------------

static func max_charges(character: Character) -> int:
	return character.database.rules.flask_base_charges + character.consumables.capacity_level


static func heal_share(character: Character) -> float:
	var steps := character.database.rules.flask_potency_heal
	return steps[clampi(character.consumables.potency_level, 0, steps.size() - 1)]


## "" if a flask drink may start (charges left, alive), otherwise why not.
static func flask_error(character: Character) -> String:
	if character.consumables.charges <= 0:
		return "The Hearth Flask is empty. Rest by a fire to refill it."
	return ""


## The drink completed: one charge is used. Returns the heal share of max
## health (0 when no charge was left - nothing happens then).
static func complete_flask(character: Character) -> float:
	if flask_error(character) != "":
		return 0.0
	character.consumables.charges -= 1
	character.consumables.changed.emit()
	return heal_share(character)


## Rest point: the flask is refilled (health is restored by the rest point itself).
static func rest(character: Character) -> void:
	var full := max_charges(character)
	if character.consumables.charges != full:
		character.consumables.charges = full
		character.consumables.changed.emit()


## Upgrade path data: current level, maximum level, next cost (-1 at the end).
static func upgrade_info(character: Character, path: StringName) -> Dictionary:
	var rules := character.database.rules
	var costs := rules.flask_capacity_costs if path == CAPACITY else rules.flask_potency_costs
	var level := character.consumables.capacity_level if path == CAPACITY else character.consumables.potency_level
	return {"level": level, "max": costs.size(), "cost": costs[level] if level < costs.size() else -1}


## "" if the next upgrade of `path` can be bought now, otherwise why not.
static func upgrade_error(character: Character, path: StringName) -> String:
	if path != CAPACITY and path != POTENCY:
		return "Unknown upgrade."
	var info := upgrade_info(character, path)
	if int(info.cost) < 0:
		return "Fully upgraded."
	var gold := character.inventory.count(GOLD)
	if gold < int(info.cost):
		return "Not enough gold (%d / %d)." % [gold, int(info.cost)]
	return ""


## Buys the next level of `path` (gold only). "" on success, else nothing changed.
## A capacity upgrade also adds the new charge right away.
static func upgrade(character: Character, path: StringName) -> String:
	var error := upgrade_error(character, path)
	if error != "":
		return error
	var info := upgrade_info(character, path)
	if not character.inventory.remove_quantity(GOLD, int(info.cost)):
		return "Not enough gold."
	if path == CAPACITY:
		character.consumables.capacity_level += 1
		character.consumables.charges += 1
	else:
		character.consumables.potency_level += 1
	character.consumables.changed.emit()
	return ""




# --- potions -----------------------------------------------------------------------

static func potion_effect(character: Character, item_id: StringName) -> PotionEffectDefinition:
	var definition := character.database.get_item(item_id)
	return definition.potion_effect if definition != null else null


## Puts a potion type on quick slot 2. "" on success.
static func assign_potion(character: Character, item_id: StringName) -> String:
	if potion_effect(character, item_id) == null:
		return "Only special potions go on the potion slot."
	character.consumables.potion_slot = item_id
	character.consumables.changed.emit()
	return ""


## "" if the slotted potion may be drunk now, otherwise why not.
static func potion_error(character: Character) -> String:
	var state := character.consumables
	if character.classes.in_trial():
		return "Potions stay sealed during a class trial; the Hearth Flask still answers."   # no item use (M3)
	if state.potion_slot == &"" or potion_effect(character, state.potion_slot) == null:
		return "No potion on the potion slot. Right-click a potion in your bag."
	if character.inventory.count(state.potion_slot) <= 0:
		var definition := character.database.get_item(state.potion_slot)
		return "No %s left." % (definition.display_name if definition else "potion")
	if state.cooldown_left > 0.0:
		return "Potions are on cooldown (%d s)." % ceili(state.cooldown_left)
	return ""


## The drink completed: one potion leaves the bag, its buff replaces any
## active one, the shared cooldown starts. "" on success, else nothing changed.
static func complete_potion(character: Character) -> String:
	var error := potion_error(character)
	if error != "":
		return error
	var state := character.consumables
	if not character.inventory.remove_quantity(state.potion_slot, 1):
		return "The potion is gone."
	var effect := potion_effect(character, state.potion_slot)
	state.buff_item = state.potion_slot
	state.buff_left = effect.duration
	state.cooldown_left = character.database.rules.potion_cooldown
	refresh_buff(character)
	state.changed.emit()
	return ""


## Applies the active buff's modifiers (or removes them) - called after loading too.
static func refresh_buff(character: Character) -> void:
	var state := character.consumables
	var effect := potion_effect(character, state.buff_item) if state.buff_item != &"" else null
	if effect == null or state.buff_left <= 0.0:
		state.buff_item = &""
		state.buff_left = 0.0
		character.clear_runtime_modifiers(BUFF_KEY)
	else:
		character.set_runtime_modifiers(BUFF_KEY, effect.modifiers)


## Ends the active potion buff (death).
static func end_buff(character: Character) -> void:
	var state := character.consumables
	if state.buff_item == &"":
		return
	state.buff_item = &""
	state.buff_left = 0.0
	refresh_buff(character)
	state.changed.emit()


## Game time passes (the bound player's physics tick): buff and cooldown run down.
static func step(character: Character, delta: float) -> void:
	var state := character.consumables
	if state.cooldown_left > 0.0:
		state.cooldown_left = maxf(0.0, state.cooldown_left - delta)
	if state.buff_item != &"":
		state.buff_left -= delta
		if state.buff_left <= 0.0:
			end_buff(character)


## Clamps loaded values to the current data (charges, levels, unknown items).
static func sanitize(character: Character) -> void:
	var rules := character.database.rules
	var state := character.consumables
	state.capacity_level = clampi(state.capacity_level, 0, rules.flask_capacity_costs.size())
	state.potency_level = clampi(state.potency_level, 0, rules.flask_potency_costs.size())
	state.charges = clampi(state.charges, 0, max_charges(character)) if state.charges >= 0 else max_charges(character)
	if state.potion_slot != &"" and potion_effect(character, state.potion_slot) == null:
		state.potion_slot = &""
	state.cooldown_left = clampf(state.cooldown_left, 0.0, rules.potion_cooldown)
	refresh_buff(character)


## Active timed effects for the HUD effect bar ([{"id", "name", "summary",
## "color", "left", "total"}]); today only the potion buff.
static func active_effects(character: Character) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var state := character.consumables
	var effect := potion_effect(character, state.buff_item) if state.buff_item != &"" else null
	if effect != null and state.buff_left > 0.0:
		var definition := character.database.get_item(state.buff_item)
		result.append({"id": effect.id, "name": definition.display_name, "summary": effect.summary,
			"color": effect.color, "left": state.buff_left, "total": effect.duration})
	return result
