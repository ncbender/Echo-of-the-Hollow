class_name FlaskPanel
extends UiWindow
## Mara's Hearth Flask upgrades (Consumables 1.0): two separate paths paid in
## gold only - Capacity (more charges) and Potency (more healing per charge).
## Each row shows now -> next, the cost against the gold carried and an
## Upgrade button (disabled with the reason). All rules in ConsumableService.

const WIDTH := 560

var character: Character
## The NPC that opened the window (closes when the player walks away).
var site: Node2D
## Set by GameHud (the NPC's dialogue from the Talk button).
var hud: GameHud
var last_message: String = ""
var last_ok: bool = true

var _list: VBoxContainer


func _ready() -> void:
	set_title("Hearth Flask")
	set_close_text("Close [G / Esc]")
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", UiTheme.GAP)
	body.add_child(_list)


func open(target_character: Character, target_site: Node2D = null) -> void:
	character = target_character
	site = target_site
	last_message = ""
	show()
	rebuild()


func _process(_delta: float) -> void:
	if visible and site != null and (not is_instance_valid(site) or not site.get(&"player_inside")):
		hide()


func rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_list.add_child(UiTheme.wrapped("Mara can strengthen your Hearth Flask. Upgrades are paid in gold and last for good. Rest by a fire to refill the flask.",
		UiTheme.TEXT_SECONDARY, WIDTH))
	var gold := character.inventory.count(ConsumableService.GOLD)
	var gold_row := UiTheme.stat_row("Gold", InventoryPanel.gold_text(gold), UiTheme.PARCHMENT)
	gold_row.name = "Gold"
	_list.add_child(gold_row)
	var rules := character.database.rules
	var capacity := ConsumableService.upgrade_info(character, ConsumableService.CAPACITY)
	var charges := ConsumableService.max_charges(character)
	_list.add_child(_path_card(ConsumableService.CAPACITY, "Capacity", "%d charges" % charges,
		"%d charges" % (charges + 1), capacity))
	var potency := ConsumableService.upgrade_info(character, ConsumableService.POTENCY)
	var heal := roundi(ConsumableService.heal_share(character) * 100.0)
	var next_heal := roundi(rules.flask_potency_heal[mini(int(potency.level) + 1, rules.flask_potency_heal.size() - 1)] * 100.0)
	_list.add_child(_path_card(ConsumableService.POTENCY, "Potency", "heals %d%% of max health" % heal,
		"heals %d%% of max health" % next_heal, potency))
	var npc := site as StoryNpc
	var talk := DialogueService.pick(character, npc.definition()) if npc != null else null
	if talk != null and hud != null:   # the NPC's (already heard) talk stays reachable
		var button := UiTheme.button("Talk to %s" % npc.definition().display_name, &"", hud.open_dialogue.bind(talk))
		button.name = "Talk"
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_list.add_child(button)
	var result := UiTheme.wrapped(last_message, UiTheme.SUCCESS if last_ok else UiTheme.DANGER, WIDTH)
	result.name = "Result"
	result.visible = last_message != ""
	_list.add_child(result)


func _path_card(path: StringName, title: String, now: String, next: String, info: Dictionary) -> Control:
	var card := UiTheme.card(&"CardPanel")
	card.name = "Path_%s" % path
	var box := card.get_node("Box") as VBoxContainer
	var head := HBoxContainer.new()
	var heading := UiTheme.styled(title, &"SubheadingLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	head.add_child(UiTheme.styled("Level %d / %d" % [int(info.level), int(info.max)], &"SmallLabel"))
	box.add_child(head)
	var done := int(info.cost) < 0
	box.add_child(UiTheme.stat_row("Now", now, UiTheme.TEXT_PRIMARY))
	if done:
		box.add_child(UiTheme.label("Fully upgraded.", UiTheme.SUCCESS))
		return card
	box.add_child(UiTheme.stat_row("Next", next, UiTheme.SUCCESS))
	var gold := character.inventory.count(ConsumableService.GOLD)
	var cost := UiTheme.stat_row("Cost", "%s gold" % InventoryPanel.gold_text(int(info.cost)), UiTheme.SUCCESS if gold >= int(info.cost) else UiTheme.DANGER)
	cost.name = "Cost"
	box.add_child(cost)
	var error := ConsumableService.upgrade_error(character, path)
	var button := UiTheme.button("Upgrade %s" % title, &"PrimaryButton", upgrade.bind(path))
	button.name = "Upgrade_%s" % path
	button.disabled = error != ""
	button.tooltip_text = error
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(button)
	return card


## Upgrade button (UI and tests): one level of `path`, paid in gold.
func upgrade(path: StringName) -> String:
	var error := ConsumableService.upgrade(character, path)
	last_ok = error == ""
	last_message = error if error != "" else "Mara works the flask: %s upgraded." % ("Capacity" if path == ConsumableService.CAPACITY else "Potency")
	rebuild()
	return error
