class_name GameHud
extends CanvasLayer
## In-game UI. Pure presentation: reads the Character through the
## PlayerProgressionBridge and calls its public methods.
##
## Layout (design px, anchored, every resolution and UI scale):
##   top centre     enemy / boss frame, tutorial hint below it
##   top right      quest tracker
##   bottom left    player frame (health, resource, dash, defense, buffs)
##   bottom centre  heavy charge, context prompt, skill bar, messages
##   bottom right   loot feed, save indicator
## The middle of the screen stays free for the fight and its telegraphs.

var bridge: PlayerProgressionBridge
var toasts: ToastFeed
var player_frame: PlayerFrame
var target_frame: TargetFrame
var charge_meter: ChargeMeter
var loot_feed: LootFeed
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
var _hint_spacer: Control


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

	# top right: quest tracker
	objectives = ObjectivePanel.new()
	objectives.name = "QuestTracker"
	objectives.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objectives.offset_left = -UiTheme.HUD_COLUMN_WIDTH - margin
	objectives.offset_right = -margin
	objectives.offset_top = margin
	objectives.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(objectives)

	# bottom left: player frame
	player_frame = PlayerFrame.new()
	player_frame.name = "PlayerFrame"
	player_frame.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	player_frame.offset_left = margin
	player_frame.offset_bottom = -margin
	player_frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(player_frame)

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
	skill_bar = SkillBar.new()
	skill_bar.name = "SkillBar"
	skill_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # four slots wide, not the whole column
	bottom.add_child(skill_bar)

	# bottom right: loot feed above the save indicator
	loot_feed = LootFeed.new()
	loot_feed.name = "LootFeed"
	loot_feed.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	loot_feed.offset_left = -380
	loot_feed.offset_right = -margin
	loot_feed.offset_bottom = -margin - 160   # above the skill bar and the save indicator
	loot_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	loot_feed.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(loot_feed)
	save_indicator = SaveIndicator.new()
	save_indicator.name = "SaveIndicator"
	save_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	save_indicator.offset_left = -260
	save_indicator.offset_top = -margin - 150
	save_indicator.offset_right = -margin
	save_indicator.offset_bottom = -margin - 102   # above the skill bar height (the centre column may move right)
	save_indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	save_indicator.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(save_indicator)
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
	skill_bar.bridge = bridge
	objectives.bridge = bridge
	player_frame.bridge = bridge
	target_frame.bridge = bridge
	charge_meter.bridge = bridge
	loot_feed.bridge = bridge
	death_overlay.bridge = bridge
	bridge.message.connect(toasts.push.bind(UiTheme.RESONANCE))
	bridge.item_received.connect(loot_feed.push)
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


## C: class, talents and skills away from a class station (learning talents only).
func toggle_character() -> void:
	if bridge == null:
		return
	if class_panel.visible:
		class_panel.hide()
	else:
		close_windows()
		class_panel.open(bridge.character, null, "Talents")


func toggle_inventory() -> void:
	if bridge == null:
		return
	if inventory_panel.visible:
		inventory_panel.hide()
	else:
		close_windows()
		inventory_panel.open(bridge.character)


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
const EXTRA_ACTIONS := {&"ui_journal": KEY_J, &"ui_map": KEY_M, &"ui_professions": KEY_P}


static func ensure_input_actions() -> void:
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
	return window


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


## On narrow canvases (high UI scale) the centre column moves right just enough
## not to overlap the player frame; if the skill bar does not fit beside it at
## all, the column stays centred above the frame. Never wider than the canvas.
func _layout_bottom() -> void:
	var canvas := _root.size.x
	var margin := float(UiTheme.SCREEN_MARGIN)
	var frame_right := margin + player_frame.size.x + UiTheme.GAP * 2
	var skills_half := skill_bar.get_combined_minimum_size().x * 0.5
	var shift := maxf(0.0, frame_right + skills_half - canvas * 0.5)
	var lift := 0.0
	if canvas * 0.5 + shift + skills_half > canvas - margin:
		shift = 0.0
		lift = player_frame.size.y + UiTheme.GAP
	var half := minf(UiTheme.FEED_WIDTH, canvas - margin * 2.0 - shift * 2.0) * 0.5
	_bottom.offset_left = -half + shift
	_bottom.offset_right = half + shift
	_bottom.offset_bottom = -margin - lift
	# lifted skill bar: the corner right of the player frame is free for the loot feed
	var cramped := lift > 0.0
	loot_feed.max_rows = 2 if cramped else LootFeed.MAX_ROWS
	loot_feed.offset_bottom = -margin if cramped else -margin - 160
	save_indicator.offset_top = -margin - (160 if cramped else 150)
	save_indicator.offset_bottom = -margin - (112 if cramped else 102)
	_layout_hint(canvas, margin)


## The hint sits under the target frame between the side columns; where that
## room is too small (200 %), it moves below the quest tracker instead.
func _layout_hint(canvas: float, margin: float) -> void:
	var padding := 24.0
	var room := canvas - 2.0 * (objectives.size.x + margin + UiTheme.GAP)
	var below := room < 420.0
	var width := minf(640.0, (canvas - margin * 2.0 if below else room) - padding)
	if not is_equal_approx(_hint_label.custom_minimum_size.x, width):
		_hint_label.custom_minimum_size.x = width
	var above := target_frame.size.y if target_frame.visible else 0.0
	var spacer := maxf(0.0, objectives.position.y + objectives.size.y + UiTheme.GAP - margin - above) if below else 0.0
	_hint_spacer.custom_minimum_size.y = spacer
	_hint_spacer.visible = spacer > 0.0
