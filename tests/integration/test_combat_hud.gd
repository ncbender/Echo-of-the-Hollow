extends TestCase
## Combat HUD UX 2.0 (docs/COMBAT_HUD_UX_2_0.md): the combat unit (health vessel | 1 2 + Q E R F | resource
## vessel, level / pressure badges in the EXP row), bottle liquid levels, no permanent slot words, the dash
## meter under the hero, the smaller menu bar and the Journey tracker - real arena, real character.

var session: SessionState
var map: GameMap
var character: Character
var _previous: Character


func before_each() -> void:
	session = SessionState.find(get_tree())
	_previous = session.character
	character = CharacterFactory.create_new(session.database)
	character.classes.unlock(&"warrior")
	character.switch_class(&"warrior", true)
	session.set_character(character)
	get_tree().change_scene_to_file("res://scenes/arena/test_arena.tscn")
	for i in 200:
		await get_tree().process_frame
		map = get_tree().current_scene as GameMap
		if map != null and map.is_node_ready() and not session.is_traveling():
			break
	await _frames(2)


func after_each() -> void:
	ObjectivePanel.collapsed = false
	session.settings.set_ui_scale(1.0)
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	await get_tree().process_frame
	session.set_character(_previous)


func _frames(count: int = 2) -> void:
	for i in count:
		await get_tree().process_frame


func _damage(amount: float) -> HitData:
	var hit := HitData.new()
	hit.damage = amount
	return hit


## Every label text of the HUD outside open windows (what the player reads permanently).
func _hud_texts() -> String:
	var texts: PackedStringArray = []
	for label: Label in map.hud.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and not _in_window(label):
			texts.append(label.text)
	return "\n".join(texts)


func _in_window(node: Node) -> bool:
	for window in map.hud._windows:
		if window.is_ancestor_of(node):
			return true
	return false


func test_vessels_follow_damage_healing_spending_regeneration_and_classes() -> void:
	var hud := map.hud
	var health := map.player.health
	health.apply_hit(_damage(100.0))
	await _frames()
	check_eq(hud.health_vessel.value_text, str(ceili(health.health)), "health number after damage")
	check(is_equal_approx(hud.health_vessel.ratio, health.health / health.max_health), "fill = health share (%.3f)" % hud.health_vessel.ratio)
	check(hud.health_vessel.tooltip_text == "Health  %d / %d" % [ceili(health.health), roundi(health.max_health)], "name and maximum only in the tooltip")
	health.heal(40.0)
	await _frames()
	check_eq(hud.health_vessel.value_text, str(ceili(health.health)), "health number after healing")
	var pool := map.bridge.resource_pool
	pool.gain(60.0)
	await _frames()
	check_eq(hud.resource_vessel.value_text, str(roundi(pool.value)), "rage number")
	check(hud.resource_vessel.color == pool.definition.color and hud.resource_vessel.tooltip_text.begins_with("Rage  %d / %d" % [roundi(pool.value), roundi(pool.max_value())]),
		"rage colour, name and maximum in the tooltip: %s" % hud.resource_vessel.tooltip_text)
	pool.spend(25.0)
	await _frames()
	check_eq(hud.resource_vessel.value_text, str(roundi(pool.value)), "rage after spending")
	check(not _hud_texts().contains("Rage") and not _hud_texts().contains("HP") and not _hud_texts().contains("Mana"), "no permanent resource labels")
	for entry: Array in [[&"arcanist", "Mana"], [&"shadowrunner", "Focus"]]:
		character.classes.unlock(entry[0])
		check_eq(character.switch_class(entry[0], true), "", "switched to %s" % entry[0])
		await _frames(3)
		pool = map.bridge.resource_pool
		check(pool != null and hud.resource_vessel.has_value and hud.resource_vessel.tooltip_text.begins_with(entry[1]), "%s: its real resource (%s)" % [entry[0], hud.resource_vessel.tooltip_text])
		check(hud.resource_vessel.color == pool.definition.color, "%s: the resource's own colour" % entry[0])
	# Focus regenerates: the number follows without any spending
	pool.value = 10.0
	await _frames(1)
	var low := hud.resource_vessel.value_text
	for i in 30:
		await get_tree().physics_frame
	await _frames(1)
	check(int(hud.resource_vessel.value_text) > int(low), "regeneration shows (%s -> %s)" % [low, hud.resource_vessel.value_text])
	check_eq(character.switch_class(&"basic_adventurer", true), "", "back to the Basic Adventurer")
	await _frames(3)
	check(map.bridge.resource_pool == null and not hud.resource_vessel.has_value and hud.resource_vessel.value_text == "",
		"no resource: an empty, dimmed vessel without a number")
	check(hud.resource_vessel.tooltip_text.contains("uses no class resource"), "the tooltip says so: %s" % hud.resource_vessel.tooltip_text)
	check(hud.level_badge.text == "Lv %d" % character.classes.get_level(&"basic_adventurer"), "level badge of the active class")
	health.apply_hit(_damage(health.max_health * 2.0))   # last: a dead player regenerates nothing
	await _frames()
	check(hud.health_vessel.ratio == 0.0 and hud.health_vessel.value_text == "0", "empty vessel at 0 health")


func test_combat_bar_slots_have_no_permanent_words() -> void:
	var hud := map.hud
	await _frames(2)
	var slots := hud._combat_row.find_children("*", "HudSlot", true, false)
	check_eq(slots.size(), 6, "six slots 1 2 | Q E R F")
	for slot: HudSlot in slots:
		check(slot.size == UiTheme.HUD_SLOT_SIZE, "%s: 64 x 64" % slot.name)
		check(slot.key != "", "%s: key stays visible (%s)" % [slot.name, slot.key])
	# a fresh warrior: rage 0 - the slotted skill cannot be paid, other slots are empty
	var texts := hud.skill_bar.status_texts() + hud.quick_use.status_texts()
	check("".join(texts) == "", "no 'Empty' / 'None' / cost words: %s" % [texts])
	var runtime := map.bridge.class_runtime
	var first := hud.skill_bar.get_child(0) as HudSlot
	check(not first.usable and first.cost_ratio >= 0.0 and first.cost_color == runtime.pool.definition.color, "unaffordable: dimmed, a resource bar towards the cost")
	check(first.tooltip_text.contains("Not enough Rage") and first.tooltip_text.contains("Cost:"), "cost and reason in the tooltip")
	var empty: HudSlot = null
	for slot: HudSlot in hud.skill_bar.get_children():
		if slot.glyph == HudSlot.Glyph.EMPTY:
			empty = slot
	if check(empty != null, "an empty skill slot"):
		check(empty.status_text() == "" and empty.tooltip_text.contains("No skill in this slot"), "empty: a quiet frame, the reason in the tooltip")
	# cooldown: seconds while it runs, nothing after
	runtime.pool.gain(100.0)
	var skill := runtime.skill_in_slot(0)
	runtime.cooldowns[skill.id] = runtime.time + 3.0
	await _frames(2)
	check(first.cooldown_ratio > 0.0 and first.status_text().ends_with("s") and not first.usable, "cooldown: darkening and seconds (%s)" % first.status_text())
	runtime.cooldowns.erase(skill.id)
	await _frames(2)
	check(first.usable and first.status_text() == "" and first.cost_ratio < 0.0, "ready: no word at all")
	check_eq(hud.find_children("*", "HudXpBar", true, false).size(), 1, "exactly one EXP bar")
	check(hud.xp_bar.size == UiTheme.XP_BAR_SIZE and (hud.xp_bar.text.ends_with("%") or hud.xp_bar.text == HudXpBar.MAX_TEXT), "EXP bar 426 x 14, percent only")
	check(hud.level_badge.text == "Lv %d" % character.classes.get_level(&"warrior"), "level badge: %s" % hud.level_badge.text)
	var hud_text := _hud_texts()
	check(not hud_text.contains("mastery") and not hud_text.contains("Shift:") and not hud_text.contains("Dash") and not hud_text.contains("Warrior"),
		"no mastery, guard, dash or class labels: %s" % hud_text.replace("\n", " | "))


func test_flask_and_potion_liquid_levels() -> void:
	var hud := map.hud
	var state := character.consumables
	var full := ConsumableService.max_charges(character)
	var flask := hud.quick_use.get_child(0) as HudSlot
	var potion := hud.quick_use.get_child(1) as HudSlot
	state.charges = full
	await _frames()
	check(is_equal_approx(flask.fill, 1.0) and flask.usable, "full flask")
	check(flask.tooltip_text.contains("Charges: %d / %d" % [full, full]), "exact charges in the tooltip")
	state.charges = 1
	await _frames()
	check(is_equal_approx(flask.fill, 1.0 / full) and flask.usable, "one charge: a low level (%.2f)" % flask.fill)
	var mask := UiSkin.texture(&"hud/flask_fill")
	if mask != null:
		check(HudFillArt.fill_rows(mask, flask.fill, 3) >= 3, "one charge stays visible (>= 3 rows)")
	state.charges = 0
	await _frames()
	check(flask.fill == 0.0 and not flask.usable and flask.tooltip_text.contains("Empty"), "empty flask: dark, the reason in the tooltip")
	check(potion.glyph == HudSlot.Glyph.EMPTY and potion.tooltip_text.contains("No potion slotted"), "no potion: an empty slot")
	check_eq(ConsumableService.assign_potion(character, &"ember_draught"), "", "potion slotted")
	var stack := character.database.get_item(&"ember_draught").max_stack
	for entry: Array in [[0, 0.0], [1, 0.25], [2, 0.25], [3, 0.5], [5, 0.5], [6, 0.75], [8, 1.0], [stack, 1.0], [stack + 7, 1.0]]:
		check(is_equal_approx(QuickUseBar.potion_fill(entry[0], stack), entry[1]), "%d potions -> %.2f" % [entry[0], entry[1]])
	character.inventory.add_item(&"ember_draught", 3)
	await _frames()
	check(potion.glyph == HudSlot.Glyph.POTION and is_equal_approx(potion.fill, 0.5), "three potions: half a bottle")
	check(potion.tooltip_text.contains("In your bag: 3") and potion.tooltip_text.contains(character.database.get_item(&"ember_draught").display_name), "name and count in the tooltip")
	state.cooldown_left = 12.0
	await _frames()
	check(potion.cooldown_ratio > 0.0 and potion.status_text() == "12s" and not potion.usable and is_equal_approx(potion.fill, 0.5),
		"cooldown: veil and seconds in the corner, the liquid stays")
	state.cooldown_left = 0.0
	character.inventory.remove_quantity(&"ember_draught", 3)
	await _frames()
	check(potion.fill == 0.0 and not potion.usable and potion.tooltip_text.contains("No "), "none left: a dark, empty bottle")
	check("".join(hud.quick_use.status_texts()) == "", "no permanent counts")


func test_dash_meter_under_the_hero() -> void:
	var meter := map.hud.dash_meter
	await _frames(2)
	check(not meter.visible, "all charges ready: hidden")
	check(map.player.dash.try_start(Vector2.RIGHT), "a dash")
	await _frames(2)
	check(meter.visible and meter.max_charges == map.player.dash.config.max_charges and meter.charges < meter.max_charges, "after a dash: shown at once with the real charges")
	check(is_equal_approx(meter.segments_width(), meter.max_charges * HudDashMeter.SEGMENT.x + (meter.max_charges - 1) * HudDashMeter.SEGMENT_GAP), "one segment per charge")
	for i in 30:   # the dash itself is over; the charge still recharges, the hero stands still
		await get_tree().physics_frame
	await _frames(1)
	var foot := map.player.get_global_transform_with_canvas().origin
	var rect := meter.get_global_rect()
	check(rect.position.y > foot.y + 40.0 and absf(rect.get_center().x - foot.x) < 2.0, "under the hero, centred (%s / %s)" % [rect, foot])
	check(Rect2(Vector2.ZERO, map.hud._root.size).encloses(rect), "inside the canvas")
	for i in 600:
		await get_tree().physics_frame
		if map.player.dash.charges >= map.player.dash.config.max_charges:
			break
	await _frames(2)
	check(map.player.dash.charges == map.player.dash.config.max_charges and not meter.visible, "recharged: hidden again")
	map.player.defense.counter_left = 0.4
	await _frames(1)
	check(meter.visible and meter.defense_word == "Counter!", "the counter window shows under the hero")
	map.player.defense.counter_left = 0.0


func test_menu_bar_is_smaller_and_keeps_seven_click_targets() -> void:
	var bar := map.hud.menu_bar
	session.settings.set_ui_scale(0.75)
	await _frames(4)
	check_eq(bar.buttons.size(), 7, "seven functions")
	var rects: Array[Rect2] = []
	for id: StringName in bar.buttons:
		var button := bar.buttons[id] as Control
		check(button.size == UiTheme.MENU_ICON_SIZE, "%s: %s button" % [id, UiTheme.MENU_ICON_SIZE])
		check(button.tooltip_text.contains("[") and button.mouse_filter == Control.MOUSE_FILTER_STOP, "%s: tooltip with the key, stops the click" % id)
		for other in rects:
			check(not other.intersects(button.get_global_rect()), "%s: its own click area" % id)
		rects.append(button.get_global_rect())
	check(bar.size.y <= UiTheme.MENU_ICON_SIZE.y + 2 * HudMenuBar.PADDING + 0.5 and bar.size.x < 270.0, "compact bar (%s)" % bar.size)


func test_journey_tracker_collapsed_expanded_and_goals() -> void:
	var tracker := map.hud.objectives
	for quest_id: StringName in [&"the_first_signs", &"the_lost_hunter", &"what_the_roots_keep", &"embers_of_shelter"]:
		character.quests.entries[quest_id] = {"state": "active", "step": 0, "progress": {}}
	await _frames(3)
	var text := tracker.full_text()
	check(text.contains("The First Signs") and text.contains("Find the way east of the Whisper Forest"), "main: title and concrete goal")
	check(not text.contains("Edrin warned") and not text.contains("[J]") and not text.contains("Main Quest"), "no narrative, no key hints, no campaign label")
	for quest_id: StringName in [&"the_lost_hunter", &"what_the_roots_keep", &"embers_of_shelter"]:
		var quest := session.database.story_quests[quest_id] as StoryQuestDefinition
		check(text.contains(quest.display_name) and text.contains(StoryService.short_goal(character, quest_id)), "side: %s with its goal" % quest.display_name)
	for goal: Label in tracker.find_children("Goal", "Label", true, false):
		check(not goal.clip_text and goal.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and goal.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"goal '%s' wraps, never cut" % goal.text)
	var expanded := tracker.size.y
	tracker.toggle_collapsed()
	await _frames(3)
	check(tracker.full_text() == "" and tracker.size.y < 40.0 and tracker.size.y < expanded, "collapsed: one slim header row (%.0f)" % tracker.size.y)
	tracker.toggle_collapsed()
	await _frames(2)
	# the open-ended main quest without objectives: its optional short HUD goal, not the long step text
	character.quests.entries.erase(&"the_first_signs")
	character.quests.entries[&"beyond_the_roots"] = {"state": "active", "step": 0, "progress": {}}
	await _frames(3)
	check(tracker.full_text().contains("Beyond the Roots\nFurther story is not yet available.") and not tracker.full_text().contains("Warden's Rest"),
		"hud_goal for a step without objectives: %s" % tracker.full_text())


func test_layout_of_the_combat_unit_at_three_scales() -> void:
	var hud := map.hud
	hud.loot_feed.push(&"iron_ore", 2)
	hud.loot_feed.push(&"timber", 3)
	hud.loot_feed.push(&"stone", 1)
	map.bridge.class_runtime.pressure = 2
	map.bridge.class_runtime._pressure_left = 9999.0   # held for the whole check
	for scale: float in [0.75, 1.0, 1.25, 1.5]:
		var tag := "%d %%" % roundi(scale * 100.0)
		session.settings.set_ui_scale(scale)
		await _frames(5)
		var canvas := Rect2(Vector2.ZERO, hud._root.size)
		var row := hud._combat_row.get_global_rect()
		var xp := hud.xp_bar.get_global_rect()
		var left := hud.health_vessel.get_global_rect()
		var right := hud.resource_vessel.get_global_rect()
		check(left.end.x <= row.position.x and right.position.x >= row.end.x, "%s: health | combat bar | resource" % tag)
		check(is_equal_approx(left.position.y, row.position.y) and is_equal_approx(right.position.y, row.position.y), "%s: vessels start with the combat bar" % tag)
		var badge := hud.level_badge.get_global_rect()
		check(is_equal_approx(badge.position.y, xp.position.y) and is_equal_approx(badge.size.y, xp.size.y) and badge.end.x <= xp.position.x, "%s: level badge in the EXP row, left of the bar" % tag)
		check(hud.pressure_badge.visible and is_equal_approx(hud.pressure_badge.get_global_rect().position.y, xp.position.y), "%s: pressure badge in the EXP row" % tag)
		check(left.end.y <= badge.position.y, "%s: vessel above the badge" % tag)
		var unit := hud._combat_unit.get_global_rect()
		check(canvas.encloses(unit), "%s: combat unit on screen" % tag)
		check(not unit.intersects(hud.menu_bar.get_global_rect()), "%s: apart from the menu bar" % tag)
		check(not unit.intersects(hud.loot_feed.get_global_rect()), "%s: apart from the loot feed %s / %s" % [tag, unit, hud.loot_feed.get_global_rect()])
		check(not unit.intersects(hud.save_indicator.get_global_rect()), "%s: apart from the save status" % tag)
	map.bridge.class_runtime.pressure = 0
	hud.toggle_inventory()
	await _frames(3)
	check(hud.health_vessel.is_visible_in_tree() and hud.resource_vessel.is_visible_in_tree() and not hud.combat_bar_shown(),
		"a window: health and resource stay, the combat bar steps back")
	hud.close_windows()
