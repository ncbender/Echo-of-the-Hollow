class_name GameHud
extends CanvasLayer
## In-game UI. Pure presentation: reads the Character through the
## PlayerProgressionBridge and calls its public methods.
##
## Layout - UI Layout Lock 1.0 (docs/UI_LAYOUT_LOCK_1_0.md; design px, anchored, every
## resolution and UI scale):
##   top left       active effects (potion buff, class buffs) - Combat HUD UX 2.0: health / resource moved down
##   top centre     enemy / boss frame, tutorial hint below it
##   top right      minimap area (placeholder until UI package 2), quest tracker below it
##   bottom left    the one icon menu bar (seven windows)
##   bottom centre  messages, heavy charge, context prompt, the combat unit (Combat HUD UX 2.0,
##                  docs/COMBAT_HUD_UX_2_0.md): health vessel | 1 2 + Q E R F | resource vessel, under it
##                  level badge | EXP bar | pressure badge
##   under the hero dash charges while one recharges (HudDashMeter)
##   bottom right   loot feed, save indicator below it
## The middle of the screen stays free for the fight and its telegraphs.

var bridge: PlayerProgressionBridge
var toasts: ToastFeed
## Combat HUD UX 2.0: health and class resource beside the combat bar (replace the top-left PlayerFrame), the
## class level and pressure badges in the EXP row, the dash charges under the hero.
var health_vessel: HudVessel
var resource_vessel: HudVessel
var level_badge: HudBadge
var pressure_badge: HudBadge
var dash_meter: HudDashMeter
var _combat_unit: HBoxContainer
var target_frame: TargetFrame
var charge_meter: ChargeMeter
var loot_feed: LootFeed
## Loot & Progress Feedback 1.0: the compact hero / mastery level-up message above the toasts.
var progress_notice: ProgressNotice
var death_overlay: DeathOverlay
var class_panel: ClassStationPanel
var inventory_panel: InventoryPanel
var build_panel: BuildPanel
var options_panel: OptionsPanel
var crafting_panel: CraftingPanel
var skill_bar: SkillBar
var objectives: ObjectivePanel
var class_choice_panel: ClassChoicePanel
var pause_menu: PauseMenu
var save_indicator: SaveIndicator
var dialogue_panel: DialoguePanel
var restoration_panel: RestorationPanel
var stash_panel: StashPanel
var waystone_panel: WaystonePanel
var journal_panel: JournalPanel
var world_map_panel: WorldMapPanel
var professions_panel: ProfessionsPanel
## Mara's Hearth Flask upgrades (NPC service "hearth_flask").
var flask_panel: FlaskPanel
var quest_reward_panel: QuestRewardPanel
## Shared confirmation dialog (overwrite, discard, delete ...).
var confirm_dialog: UiConfirmDialog
## Contextual tutorial hint (top centre).
var hint_panel: PanelContainer
var _hint_label: Label
var _hint_left: float = 0.0
var _hint_queue: PackedStringArray = []
## Arrival time (ms) per queued hint: hints older than HINT_STALE_MS are dropped.
var _hint_queued_at: PackedInt64Array = []
const HINT_STALE_MS := 6000
## Player display preferences (from GameSession); null when running without one.
var settings: UserSettings

var _root: Control
var _prompt_box: HBoxContainer
var _prompt_key: Label
var _prompt: Label
var _windows: Array[UiWindow] = []
var _bottom: VBoxContainer
var _left_column: VBoxContainer
## Active timed effects (potion buff) and the quick use slots above the player frame.
var effect_bar: EffectBar
var quick_use: QuickUseBar
var _hint_spacer: Control
## UI Layout Lock 1.0: the one icon menu bar (bottom left), the combat bar row (quick use +
## skills), the right column (minimap area + quest tracker) and the minimap placeholder.
var menu_bar: HudMenuBar
var minimap_frame: PanelContainer
var minimap: AreaMinimap
var _combat_row: HBoxContainer
var _right_column: VBoxContainer
## HUD EXP Bar 1.0: the one EXP bar under the combat bar; both share `_combat_column`
## (XP_BAR_GAP apart) so toasts and the prompt keep their spacing above.
var xp_bar: HudXpBar
var _combat_column: VBoxContainer

## Combat HUD UX 2.0: gap between the vessels and the combat bar.
const COMBAT_UNIT_GAP := 6
const MINIMAP_SIZE := 200.0
## Minimap side on short canvases (150 % UI scale: 720 design px high).
const MINIMAP_SIZE_SMALL := 168.0
const SHORT_CANVAS := 800.0
## Loot feed: one row is a HUD panel (30 px icon plus padding, 50 px) and a 4 px gap. Its bottom
## edge (`feed_bottom`, distance to the canvas bottom) sits one GAP above the save indicator's slot.
const FEED_ROW := 54.0

## HUD Notification Collision Fix 1.0: bottom right is one column - the save indicator's slot at the
## bottom (its measured height, reserved whether it shows or not), the loot feed above it. Set by
## _layout_bottom; nothing moves when an entry or the save hint appears or fades.
var feed_bottom: float = 0.0


func _ready() -> void:
	layer = 20
	ensure_input_actions()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var margin := UiTheme.SCREEN_MARGIN

	# top centre: enemy / boss frame, hint below
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = margin
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	target_frame = TargetFrame.new()
	target_frame.name = "TargetFrame"
	target_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(target_frame)
	_hint_spacer = Control.new()
	_hint_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hint_spacer)
	hint_panel = PanelContainer.new()
	hint_panel.name = "Hint"
	hint_panel.theme_type_variation = &"HudPanel"
	hint_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.visible = false
	_hint_label = UiTheme.wrapped("", UiTheme.PARCHMENT, 640)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_panel.add_child(_hint_label)
	top.add_child(hint_panel)

	# top right: minimap area (placeholder), quest tracker below it
	_right_column = VBoxContainer.new()
	_right_column.name = "RightColumn"
	_right_column.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_right_column.offset_left = -UiTheme.HUD_COLUMN_WIDTH - margin
	_right_column.offset_right = -margin
	_right_column.offset_top = margin
	_right_column.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_right_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_column.add_theme_constant_override(&"separation", UiTheme.GAP)
	_root.add_child(_right_column)
	minimap_frame = _minimap_placeholder()
	_right_column.add_child(minimap_frame)
	objectives = ObjectivePanel.new()
	objectives.name = "QuestTracker"
	_right_column.add_child(objectives)

	# top left: active effects (potion buff, class buffs)
	_left_column = VBoxContainer.new()
	_left_column.name = "LeftColumn"
	_left_column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_left_column.offset_left = margin
	_left_column.offset_top = margin
	_left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_column.add_theme_constant_override(&"separation", UiTheme.GAP)
	_root.add_child(_left_column)
	effect_bar = EffectBar.new()
	effect_bar.name = "EffectBar"
	_left_column.add_child(effect_bar)

	# bottom left: the one icon menu bar
	menu_bar = HudMenuBar.new()
	menu_bar.name = "MenuBar"
	menu_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu_bar.offset_left = margin
	menu_bar.offset_bottom = -margin
	menu_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	menu_bar.menu_pressed.connect(open_menu)
	_root.add_child(menu_bar)

	# bottom centre: charge, prompt, skills, messages
	var bottom := VBoxContainer.new()
	_bottom = bottom
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_left = -UiTheme.FEED_WIDTH * 0.5
	bottom.offset_right = UiTheme.FEED_WIDTH * 0.5
	bottom.offset_bottom = -margin
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	progress_notice = ProgressNotice.new()   # Loot & Progress Feedback 1.0: hero / mastery level-ups, one at a time
	progress_notice.name = "ProgressNotice"
	bottom.add_child(progress_notice)
	toasts = ToastFeed.new()
	bottom.add_child(toasts)
	charge_meter = ChargeMeter.new()
	charge_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(charge_meter)
	_prompt_box = HBoxContainer.new()
	_prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := UiTheme.key_chip("G")
	_prompt_key = chip.get_child(0) as Label
	_prompt_box.add_child(chip)
	_prompt = UiTheme.label("", UiTheme.PARCHMENT)
	_prompt.add_theme_font_size_override(&"font_size", UiTheme.FONT_SUBHEADING)
	_prompt.add_theme_constant_override(&"outline_size", 6)
	_prompt_box.add_child(_prompt)
	bottom.add_child(_prompt_box)
	# the combat unit (Combat HUD UX 2.0): health vessel | combat bar (quick use 1 / 2, a wider gap, skills
	# Q E R F; the EXP bar right under it) | resource vessel; the level and pressure badges in the EXP row
	_combat_unit = HBoxContainer.new()
	_combat_unit.name = "CombatUnit"
	_combat_unit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_combat_unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_unit.add_theme_constant_override(&"separation", COMBAT_UNIT_GAP)
	bottom.add_child(_combat_unit)
	health_vessel = HudVessel.new()
	health_vessel.name = "HealthVessel"
	level_badge = HudBadge.new()
	level_badge.name = "LevelBadge"
	_combat_unit.add_child(_vessel_column(health_vessel, level_badge))
	_combat_column = VBoxContainer.new()
	_combat_column.name = "CombatColumn"
	_combat_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_combat_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_column.add_theme_constant_override(&"separation", UiTheme.XP_BAR_GAP)
	_combat_unit.add_child(_combat_column)
	_combat_row = HBoxContainer.new()
	_combat_row.name = "CombatBar"
	_combat_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_combat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_row.add_theme_constant_override(&"separation", 18)
	_combat_column.add_child(_combat_row)
	quick_use = QuickUseBar.new()
	quick_use.name = "QuickUse"
	_combat_row.add_child(quick_use)
	skill_bar = SkillBar.new()
	skill_bar.name = "SkillBar"
	_combat_row.add_child(skill_bar)
	xp_bar = HudXpBar.new()
	xp_bar.name = "XpBar"
	_combat_column.add_child(xp_bar)
	resource_vessel = HudVessel.new()
	resource_vessel.name = "ResourceVessel"
	resource_vessel.kind = HudVessel.Kind.RESOURCE
	pressure_badge = HudBadge.new()
	pressure_badge.name = "PressureBadge"
	pressure_badge.kind = HudBadge.Kind.PRESSURE
	_combat_unit.add_child(_vessel_column(resource_vessel, pressure_badge))

	# bottom right: loot feed above the save indicator
	loot_feed = LootFeed.new()
	loot_feed.name = "LootFeed"
	loot_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	loot_feed.offset_left = -UiTheme.HUD_COLUMN_WIDTH - margin
	loot_feed.offset_right = -margin
	loot_feed.offset_bottom = -float(margin) - SaveIndicator.FALLBACK_HEIGHT - UiTheme.GAP   # exact in _layout_bottom
	loot_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	loot_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(loot_feed)
	save_indicator = SaveIndicator.new()
	save_indicator.name = "SaveIndicator"
	save_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	save_indicator.offset_left = -260
	save_indicator.offset_top = -margin - SaveIndicator.FALLBACK_HEIGHT   # measured slot in _layout_bottom
	save_indicator.offset_right = -margin
	save_indicator.offset_bottom = -margin
	save_indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	save_indicator.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(save_indicator)
	# under the hero: dash charges (placed every frame from the player's canvas position)
	dash_meter = HudDashMeter.new()
	dash_meter.name = "DashMeter"
	_root.add_child(dash_meter)
	death_overlay = DeathOverlay.new()
	_root.add_child(death_overlay)

	# windows (on top of the HUD)
	class_panel = _add_window(ClassStationPanel.new()) as ClassStationPanel
	inventory_panel = _add_window(InventoryPanel.new()) as InventoryPanel
	build_panel = _add_window(BuildPanel.new()) as BuildPanel
	options_panel = _add_window(OptionsPanel.new()) as OptionsPanel
	crafting_panel = _add_window(CraftingPanel.new()) as CraftingPanel
	class_choice_panel = _add_window(ClassChoicePanel.new()) as ClassChoicePanel
	dialogue_panel = _add_window(DialoguePanel.new()) as DialoguePanel
	restoration_panel = _add_window(RestorationPanel.new()) as RestorationPanel
	restoration_panel.hud = self
	stash_panel = _add_window(StashPanel.new()) as StashPanel
	stash_panel.hud = self
	waystone_panel = _add_window(WaystonePanel.new()) as WaystonePanel
	journal_panel = _add_window(JournalPanel.new()) as JournalPanel
	world_map_panel = _add_window(WorldMapPanel.new()) as WorldMapPanel
	professions_panel = _add_window(ProfessionsPanel.new()) as ProfessionsPanel
	flask_panel = _add_window(FlaskPanel.new()) as FlaskPanel
	flask_panel.hud = self
	quest_reward_panel = _add_window(QuestRewardPanel.new()) as QuestRewardPanel
	quest_reward_panel.hud = self
	pause_menu = _add_window(PauseMenu.new()) as PauseMenu
	pause_menu.options_requested.connect(_open_options_from_pause)
	options_panel.process_mode = Node.PROCESS_MODE_ALWAYS   # reachable from the pause menu
	confirm_dialog = _add_window(UiConfirmDialog.new()) as UiConfirmDialog
	crafting_panel.recipes_requested.connect(open_build_panel)
	crafting_panel.workbench_requested.connect(_open_smithy_workbench)
	professions_panel.restoration_requested.connect(open_restoration)
	professions_panel.hud = self
	var session := SessionState.find(get_tree())
	if session != null:
		settings = session.settings
	if settings != null:
		settings.changed.connect(_refit_windows)


func setup(progression_bridge: PlayerProgressionBridge) -> void:
	bridge = progression_bridge
	var map := get_parent() as GameMap
	if map != null and map.area_map != null:
		minimap.bind(map)
		minimap_frame.get_node("Unavailable").visible = false
	skill_bar.bridge = bridge
	objectives.bridge = bridge
	health_vessel.bridge = bridge
	resource_vessel.bridge = bridge
	level_badge.bridge = bridge
	pressure_badge.bridge = bridge
	dash_meter.bridge = bridge
	quick_use.bridge = bridge
	xp_bar.bridge = bridge
	effect_bar.bridge = bridge
	target_frame.bridge = bridge
	charge_meter.bridge = bridge
	loot_feed.bridge = bridge
	progress_notice.bridge = bridge
	death_overlay.bridge = bridge
	bridge.message.connect(toasts.push.bind(UiTheme.RESONANCE))
	bridge.item_received.connect(loot_feed.push)
	bridge.profession_xp.connect(loot_feed.push_xp)
	if bridge.player != null and not bridge.player.combat.hit_landed.is_connected(target_frame.on_player_hit):
		bridge.player.combat.hit_landed.connect(target_frame.on_player_hit)


## Contextual tutorial hint, top centre, fades after `seconds`. A hint arriving
## while another is shown waits its turn (the current one is shortened).
func show_hint(text: String, seconds: float = 8.0) -> void:
	if hint_panel.visible and _hint_left > 0.6:
		if text != _hint_label.text and not _hint_queue.has(text):
			_hint_queue.append(text)
			_hint_queued_at.append(Time.get_ticks_msec())
			_hint_left = minf(_hint_left, 2.5)
		return
	_hint_label.text = text
	_hint_left = seconds
	hint_panel.modulate.a = 1.0
	hint_panel.visible = true


func current_hint() -> String:
	return _hint_label.text if hint_panel.visible else ""


## True if a hint containing `text` is shown or waiting to be shown.
func has_hint(text: String) -> bool:
	if current_hint().contains(text):
		return true
	for queued in _hint_queue:
		if queued.contains(text):
			return true
	return false


## Current interaction prompt ("" when nothing is in reach).
func prompt_text() -> String:
	return _prompt.text if _prompt_box.visible else ""


func open_dialogue(dialogue: DialogueDefinition, on_done: Callable = Callable()) -> void:
	if bridge == null:
		return
	close_windows()
	dialogue_panel.open_dialogue(bridge.character, dialogue, on_done)


## Plain lines (signs, notes, scenes): [{"name", "text", "color"}].
func open_lines(lines: Array[Dictionary], on_done: Callable = Callable()) -> void:
	close_windows()
	dialogue_panel.open_lines(lines, on_done)


func notify(text: String) -> void:
	toasts.push(text)


func is_window_open() -> bool:
	for window in _windows:
		if window.visible:
			return true
	return false


func close_windows() -> void:
	for window in _windows:
		window.hide()


func open_class_panel(station: ClassStation) -> void:
	if bridge == null:
		return
	close_windows()
	class_panel.open(bridge.character, station, "Classes")


## The one-time choice of the first class (the Whispering Stone).
func open_class_choice(station: ClassChoiceStation) -> void:
	if bridge == null:
		return
	close_windows()
	class_choice_panel.open(bridge.character, station)


## Fast travel at an awake waystone.
func open_waystones(waystone: Waystone) -> void:
	if bridge == null:
		return
	close_windows()
	waystone_panel.open(bridge.character, waystone)


## A ruin of Haven: costs and the Restore button (or "unavailable for now").
## The Haven stash at a ruin with stash access (also while it is ruined).
func open_stash(site: RuinSite) -> void:
	if bridge == null:
		return
	close_windows()
	stash_panel.open(bridge.character, site)


func open_restoration(site: RuinSite) -> void:
	if bridge == null:
		return
	close_windows()
	restoration_panel.open(bridge.character, site)


func open_build_panel(plot: BuildPlot) -> void:
	if bridge == null:
		return
	close_windows()
	build_panel.open(bridge.character, plot)


## T: class, talents and skills away from a class station (learning talents only).
func toggle_talents() -> void:
	if bridge == null:
		return
	if class_panel.visible:
		class_panel.hide()
	else:
		close_windows()
		class_panel.open(bridge.character, null, "Talents")


## I: the inventory window on its equipment page (paper doll and bag).
func toggle_inventory() -> void:
	_toggle_inventory_view("Equipment")


## C: the character overview - the inventory window's Overview page (stats, paper doll).
func toggle_character() -> void:
	_toggle_inventory_view("Overview")


## The inventory window holds two menu views: Equipment (I) and the character pages
## Overview / Details (C). The same view again closes it; the other one switches the page.
func _toggle_inventory_view(page: String) -> void:
	if bridge == null:
		return
	if inventory_panel.visible and _inventory_view() == _view_of(page):
		inventory_panel.hide()
		return
	if not inventory_panel.visible:
		close_windows()
	inventory_panel.left_page = page
	inventory_panel.open(bridge.character)


static func _view_of(page: String) -> StringName:
	return &"inventory" if page == "Equipment" else &"character"


func _inventory_view() -> StringName:
	return _view_of(inventory_panel.left_page)


## The menu bar's click: exactly the toggle of its key (I C T P J M O).
func open_menu(id: StringName) -> void:
	match id:
		&"inventory": toggle_inventory()
		&"character": toggle_character()
		&"talents": toggle_talents()
		&"professions": toggle_professions()
		&"journal": toggle_journal()
		&"map": toggle_map()
		&"settings": toggle_options()


## The menu view open now (&"" = none of the seven).
func open_menu_view() -> StringName:
	if inventory_panel.visible:
		return _inventory_view()
	for entry: Array in [[class_panel, &"talents"], [professions_panel, &"professions"], [journal_panel, &"journal"],
			[world_map_panel, &"map"], [options_panel, &"settings"]]:
		if (entry[0] as UiWindow).visible:
			return entry[1]
	return &""


## Top-right minimap frame (Map & Fog of War 1.0): the AreaMinimap of the current map; the
## "Map unavailable" line only stays where a map has no picture (no session).
func _minimap_placeholder() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.name = "MinimapFrame"
	frame.theme_type_variation = &"HudPanel"
	frame.size_flags_horizontal = Control.SIZE_SHRINK_END
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	var label := UiTheme.styled("Map unavailable", &"CaptionLabel")
	label.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.name = "Unavailable"
	frame.add_child(label)
	minimap = AreaMinimap.new()
	minimap.name = "Minimap"
	frame.add_child(minimap)
	return frame


## Resonance Forge at a crafting station (smithy).
func open_crafting_panel(plot: BuildPlot) -> void:
	if bridge == null:
		return
	close_windows()
	crafting_panel.open(bridge.character, plot)


## The forge's Blacksmithing workbench (the Old Smithy is that workstation).
func _open_smithy_workbench(plot: BuildPlot) -> void:
	var site := plot as RuinSite
	if site != null:
		open_professions(site.ruin_id, site)


## Keys of the windows added after the first input map (journal, map, professions). Registered at
## runtime so the project's input map file stays untouched; shown in Controls.
## Keys 1 / 2 are the Hearth Flask and the potion slot (Consumables 1.0); the
## weapon slot actions lose those keys at runtime (they stay as actions).
const EXTRA_ACTIONS := {&"ui_journal": KEY_J, &"ui_map": KEY_M, &"ui_professions": KEY_P, &"ui_talents": KEY_T,
	&"use_flask": KEY_1, &"use_potion": KEY_2}
const RELEASED_KEYS := {&"weapon_slot_1": KEY_1, &"weapon_slot_2": KEY_2}


static func ensure_input_actions() -> void:
	for action: StringName in RELEASED_KEYS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == RELEASED_KEYS[action]:
				InputMap.action_erase_event(action, event)
	for action: StringName in EXTRA_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = EXTRA_ACTIONS[action]
		InputMap.action_add_event(action, key)


## J: story, side quests and Haven.
func toggle_journal() -> void:
	if bridge == null:
		return
	if journal_panel.visible:
		journal_panel.hide()
	else:
		close_windows()
		journal_panel.open(bridge.character)


## P: professions (looking only; crafting needs a workstation in Haven).
func toggle_professions() -> void:
	if bridge == null:
		return
	if professions_panel.visible:
		professions_panel.hide()
	else:
		close_windows()
		professions_panel.open(bridge.character)


## A workstation (Haven workshop, Old Smithy): professions at that station.
func open_professions(station_id: StringName, site: Node2D = null) -> void:
	if bridge == null:
		return
	close_windows()
	professions_panel.open(bridge.character, station_id, site)


## M: the region map.
func toggle_map() -> void:
	if bridge == null:
		return
	if world_map_panel.visible:
		world_map_panel.hide()
	else:
		close_windows()
		world_map_panel.open(bridge.character)


func toggle_options() -> void:
	if settings == null:
		return
	if options_panel.visible:
		options_panel.hide()
	else:
		close_windows()
		options_panel.open(settings)


## UiWindows size and center themselves (see UiWindow).
func _add_window(window: UiWindow) -> UiWindow:
	window.hide()
	_root.add_child(window)
	_windows.append(window)
	window.visibility_changed.connect(_update_window_focus)
	return window


## UI Window Foundation 1.0: a window has the focus - the minimap / tracker column and the
## combat bar step back (their content lives in the Map and Journal; nothing can be cast while
## a window blocks input). Player frame, target frame, menu bar, toasts, loot feed and save
## indicator stay: health and feedback must never vanish while the world keeps running.
## Applied at once when a window opens or closes (a click in the next frame meets the real HUD).
func _update_window_focus() -> void:
	var focused := is_window_open() and not (dialogue_panel != null and dialogue_panel.visible)
	_right_column.visible = not focused
	# the combat bar fades instead of hiding: the bottom column keeps its layout, so the slots
	# are back in place the moment a window closes (a click there never reaches the playfield)
	_combat_row.modulate.a = 0.0 if focused else 1.0
	xp_bar.modulate.a = _combat_row.modulate.a   # steps back together with the combat bar
	level_badge.modulate.a = _combat_row.modulate.a   # the EXP row steps back as one; the vessels stay (health never hides)
	pressure_badge.modulate.a = _combat_row.modulate.a
	for slot in _combat_row.find_children("*", "HudSlot", true, false):
		(slot as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE if focused else Control.MOUSE_FILTER_STOP


## True while the combat bar is shown (not stepped back behind a window).
func combat_bar_shown() -> bool:
	return _combat_row.is_visible_in_tree() and _combat_row.modulate.a > 0.0


## The visible canvas changes with the UI scale / window mode: re-fit open windows.
func _refit_windows() -> void:
	for window: UiWindow in _windows:
		window.queue_fit()


func _exit_tree() -> void:
	if settings != null and settings.changed.is_connected(_refit_windows):
		settings.changed.disconnect(_refit_windows)
	if bridge != null and is_instance_valid(bridge.player) and bridge.player.combat.hit_landed.is_connected(target_frame.on_player_hit):
		bridge.player.combat.hit_landed.disconnect(target_frame.on_player_hit)


func _process(delta: float) -> void:
	_layout_bottom()
	var target := Interactable.find_active(get_tree())
	var prompt := target.prompt if target != null and not is_window_open() else ""
	_prompt.text = prompt
	_prompt_box.visible = prompt != ""
	if hint_panel.visible:
		_hint_left -= delta
		hint_panel.modulate.a = clampf(_hint_left / 0.6, 0.0, 1.0)
		hint_panel.visible = _hint_left > 0.0
		while not hint_panel.visible and not _hint_queue.is_empty():
			var next := _hint_queue[0]
			var stale := Time.get_ticks_msec() - _hint_queued_at[0] > HINT_STALE_MS
			_hint_queue.remove_at(0)
			_hint_queued_at.remove_at(0)
			if stale:
				continue   # the moment has passed
			show_hint(next)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_character"):
		toggle_character()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_talents"):
		toggle_talents()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_options"):
		toggle_options()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_journal"):
		toggle_journal()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_map"):
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_professions"):
		toggle_professions()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		if is_window_open():
			close_windows()
		else:
			open_pause_menu()
		get_viewport().set_input_as_handled()


## Esc with no other window: pause menu (save, load, options, title).
func open_pause_menu() -> void:
	var session := SessionState.find(get_tree())
	if session == null:
		return
	close_windows()
	hint_panel.visible = false
	pause_menu.open(session)


func _open_options_from_pause() -> void:
	pause_menu.hide()
	if settings != null:
		options_panel.open(settings)


## UI Layout Lock 1.0 zones for the current canvas (design px; 1920x1080 at 100 %, 1536x864
## at 125 %, 1280x720 at 150 % UI scale - the same at every resolution):
##  * short canvas: smaller minimap area and three loot rows
##  * the quest tracker ends above the loot feed (it scrolls, it never covers the feed)
##  * the boss bar stays between the side columns, the centre column between menu bar and feed
##  * a dialogue in the lower screen part hides the bottom-centre column and the menu bar
##  * any other window hides the right column (minimap, tracker) and the combat bar
func _layout_bottom() -> void:
	var canvas := _root.size
	var margin := float(UiTheme.SCREEN_MARGIN)
	var short := canvas.y < SHORT_CANVAS
	var side := MINIMAP_SIZE_SMALL if short else MINIMAP_SIZE
	if not is_equal_approx(minimap_frame.custom_minimum_size.x, side):
		minimap_frame.custom_minimum_size = Vector2(side, side)
	loot_feed.max_rows = 3 if short else LootFeed.MAX_ROWS
	# bottom-right column: save slot (measured, never smaller than the panel really is), gap, feed
	var save_slot := save_indicator.slot_height()
	save_indicator.offset_top = -margin - save_slot
	feed_bottom = margin + save_slot + UiTheme.GAP
	loot_feed.offset_bottom = -feed_bottom
	var feed_top := canvas.y - feed_bottom - loot_feed.max_rows * FEED_ROW
	var tracker_top := margin + minimap_frame.get_combined_minimum_size().y + UiTheme.GAP
	objectives.max_height = maxf(0.0, feed_top - UiTheme.GAP - tracker_top)
	var left := margin + _left_column.size.x + UiTheme.GAP
	var right := margin + _right_column.size.x + UiTheme.GAP
	target_frame.side_reserve = maxf(left, right)
	var half := minf(UiTheme.FEED_WIDTH, canvas.x - 2.0 * (margin + menu_bar.size.x + UiTheme.GAP)) * 0.5
	_bottom.offset_left = -half
	_bottom.offset_right = half
	_bottom.offset_bottom = -margin
	var talking := dialogue_panel.visible
	_bottom.visible = not talking
	menu_bar.visible = not talking
	menu_bar.set_active(open_menu_view())
	_update_window_focus()
	_layout_hint(canvas.x, margin)


## The hint sits under the target frame between the side columns; where that
## room is too small, it moves below the right column instead.
func _layout_hint(canvas: float, margin: float) -> void:
	var padding := 24.0
	var room := canvas - 2.0 * target_frame.side_reserve
	var below := room < 420.0
	var width := minf(640.0, (canvas - margin * 2.0 if below else room) - padding)
	if not is_equal_approx(_hint_label.custom_minimum_size.x, width):
		_hint_label.custom_minimum_size.x = width
	var above := target_frame.size.y if target_frame.visible else 0.0
	var spacer := maxf(0.0, _right_column.position.y + _right_column.size.y + UiTheme.GAP - margin - above) if below else 0.0
	_hint_spacer.custom_minimum_size.y = spacer
	_hint_spacer.visible = spacer > 0.0


## An NPC's service window (data: NpcDefinition.service). False if the service
## is unknown - the NPC then says an idle line instead.
func open_npc_service(service: StringName, site: Node2D) -> bool:
	if bridge == null:
		return false
	var windows := {&"hearth_flask": flask_panel, &"quest_rewards": quest_reward_panel}
	var window: Variant = windows.get(service)
	if window == null:
		return false
	close_windows()
	window.open(bridge.character, site)   # every service window: open(character, site)
	return true


## A vessel over its badge (Combat HUD UX 2.0): the badge sits in the EXP row, the vessel spans the combat bar
## and the gap above it - the column is exactly as high as the combat bar and the EXP bar together.
func _vessel_column(vessel: HudVessel, badge: HudBadge) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "%sColumn" % vessel.name
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", UiTheme.HUD_SLOT_SIZE.y + UiTheme.XP_BAR_GAP - HudVessel.SIZE.y)
	column.add_child(vessel)
	column.add_child(badge)
	return column
