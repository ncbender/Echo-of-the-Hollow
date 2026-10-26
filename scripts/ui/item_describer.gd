class_name ItemDescriber
extends RefCounted
## One description of an item instance for every UI (tooltip, inventory details,
## forge): always the same section order -
##   1 name  2 rarity / type / item level  3 base stats  4 affixes
##   5 monster essences  6 sockets  7 quality  8 unique / set / evolution
##   9 comparison with the equipped item (actions are added by the window).
## Values come from the item data and ItemStats (the same numbers the game
## applies); nothing is recomputed or invented here.

## Lines: {"text", "color", "style"} with style "title" / "meta" / "section" /
## "line" / "dim" / "good" / "bad".


static func lines(character: Character, item: ItemInstance, compare: bool = true) -> Array[Dictionary]:
	var db := character.database
	var definition := db.get_item(item.definition_id)
	var result: Array[Dictionary] = []
	if definition == null:
		result.append(_l("Unknown item", "title"))
		return result
	result.append(_l(definition.display_name, "title", UiTheme.rarity_color(definition.rarity)))
	var meta: PackedStringArray = [UiTheme.rarity_name(definition.rarity), type_name(definition)]
	if definition.is_equippable() or definition.crafting != null:
		meta.append("Item Level %d" % item.item_level)
	if definition.is_stackable() and item.quantity > 1:
		meta.append("x%d" % item.quantity)
	result.append(_l("  ·  ".join(meta), "meta"))
	var profile := definition.crafting
	# 3 base stats (quality applies to them)
	var factor := 1.0 + item.quality * ItemStats.QUALITY_PERCENT_PER_POINT / 100.0
	var base: Array[Dictionary] = []
	for modifier in definition.base_stats:
		if modifier == null:
			continue
		var scaled := item.quality > 0 and profile != null and (profile.quality_stats.is_empty() or modifier.stat in profile.quality_stats)
		var shown := StatModifier.make(modifier.stat, modifier.flat * factor, modifier.percent * factor) if scaled else modifier
		base.append(_l(shown.describe() + ("  (quality)" if scaled else ""), "line"))
	if item.is_imprinted():
		var material: MaterialDefinition = db.materials.get(item.material_id)
		if material != null:
			base.append(_l("%s imprint: %s" % [material.display_name, _modifiers(material.imprint_modifiers)], "line", material.color.lightened(0.2)))
	_section(result, "Base", base)
	# 4 affixes
	var affixes: Array[Dictionary] = []
	for entry in item.affixes:
		affixes.append(_l(affix_text(db, entry), "line"))
	if profile != null and profile.affix_slots > 0:
		for index in range(item.affixes.size(), profile.affix_slots):
			affixes.append(_l("Open affix slot", "dim"))
	_section(result, "Affixes", affixes)
	# 5 monster essences (+ resonance)
	var essence_lines: Array[Dictionary] = []
	if profile != null and profile.essence_slots > 0:
		var active := ItemStats.active_essences(item, definition)
		for index in mini(2, profile.essence_slots):
			if index < active.size():
				var essence: EssenceDefinition = db.essences.get(active[index])
				essence_lines.append(_l("%s - %s" % [essence.display_name, essence.description] if essence != null else String(active[index]), "line", UiTheme.RESONANCE))
			else:
				essence_lines.append(_l("Empty essence slot", "dim"))
		for resonance: EssenceResonanceDefinition in db.resonances.values():
			if resonance.matches(active):
				essence_lines.append(_l("Resonance: %s - %s" % [resonance.display_name, resonance.description], "line", UiTheme.RESONANCE))
	_section(result, "Monster Essences", essence_lines)
	# 6 sockets
	var socket_lines: Array[Dictionary] = []
	if profile != null and profile.socket_slots > 0:
		for index in profile.socket_slots:
			if index < item.sockets.size():
				var socketable: SocketableDefinition = db.socketables.get(item.sockets[index])
				socket_lines.append(_l("%s - %s" % [socketable.display_name, socketable.description] if socketable != null else "Empty socket", "line"))
			else:
				socket_lines.append(_l("Closed socket (open it at the forge)", "dim"))
	_section(result, "Sockets", socket_lines)
	# 7 quality
	if profile != null and profile.max_quality > 0:
		_section(result, "Quality", [_l("%d / %d  (+%d%% base stats)" % [item.quality, profile.max_quality, roundi(item.quality * ItemStats.QUALITY_PERCENT_PER_POINT)], "line")])
	# 8 unique core / set / evolution
	var special: Array[Dictionary] = []
	for effect in definition.effects:
		special.append(_l(effect.description, "line", UiTheme.PARCHMENT))
	if definition.set_id != &"":
		var set_def: SetDefinition = db.sets.get(definition.set_id)
		special.append(_l("Set: %s (%d equipped)" % [set_def.display_name if set_def else String(definition.set_id),
			character.equipped_set_counts().get(definition.set_id, 0)], "line", UiTheme.rarity_color(ItemDefinition.Rarity.SET)))
	var evolution := ItemStats.evolution_of(definition, db)
	if evolution != null:
		var stage := evolution.get_stage(item.evolution_stage())
		special.append(_l("Evolution: %s, stage %d / %d%s" % [evolution.display_name, item.evolution_stage(), evolution.max_stage(),
			" (%s)" % stage.display_name if stage != null else ""], "line"))
		var next := ItemEvolution.next_stage(item, definition, db)
		if next != null:
			special.append(_l("Item XP %d / %d for the next stage" % [item.evolution_xp(), next.xp_required], "dim"))
	_section(result, "Unique, Set & Evolution", special)
	# requirements and flavour
	if not definition.required_class_ids.is_empty():
		var names: PackedStringArray = []
		for class_id in definition.required_class_ids:
			var class_def := db.get_class_def(class_id)
			names.append(class_def.display_name if class_def != null else String(class_id))
		var allowed := character.classes.active_class_id in definition.required_class_ids
		result.append(_l("Requires: %s" % ", ".join(names), "line" if allowed else "bad"))
	if definition.description != "":
		result.append(_l(definition.description, "dim"))
	# 9 comparison
	if compare and definition.is_equippable() and not character.equipment.is_equipped(item.instance_id):
		result.append_array(comparison(character, item, definition))
	return result


## Stat difference against the item in the slot this item would take.
static func comparison(character: Character, item: ItemInstance, definition: ItemDefinition) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var slot := character.equipment.auto_slot(item)
	if slot < 0:
		var allowed := EquipSlot.allowed_slots(definition)
		slot = allowed[0] if not allowed.is_empty() else -1
	if slot < 0:
		return result
	var current := character.equipment.get_item(slot)
	var db := character.database
	var title := "Compared with %s" % ("empty %s" % EquipSlot.display_name(slot) if current == null else db.get_item(current.definition_id).display_name)
	var mine := totals(ItemStats.modifiers(item, definition, db))
	var theirs := totals(ItemStats.modifiers(current, db.get_item(current.definition_id), db)) if current != null else {}
	var keys: Array = mine.keys()
	for key: String in theirs:
		if not key in keys:
			keys.append(key)
	keys.sort()
	var rows: Array[Dictionary] = []
	for key: String in keys:
		var delta: float = float(mine.get(key, 0.0)) - float(theirs.get(key, 0.0))
		if is_zero_approx(delta):
			continue
		var stat := StringName(key.get_slice("|", 0))
		var percent := key.ends_with("|%")
		var number := StatModifier._number(absf(delta))
		var text := "%s%s%s %s" % ["+" if delta > 0.0 else "-", number, "%" if percent else "", Stats.display_name(stat)]
		rows.append(_l(text + ("  (better)" if delta > 0.0 else "  (worse)"), "good" if delta > 0.0 else "bad"))
	if rows.is_empty():
		rows.append(_l("No stat difference", "dim"))
	result.append(_l(title, "section"))
	result.append_array(rows)
	return result


## Summed flat and percent values per stat ("stat|flat" / "stat|%").
static func totals(modifiers: Array[StatModifier]) -> Dictionary:
	var sums := {}
	for modifier in modifiers:
		if modifier.flat != 0.0:
			var key := "%s|flat" % modifier.stat
			sums[key] = float(sums.get(key, 0.0)) + modifier.flat
		if modifier.percent != 0.0:
			var key := "%s|%%" % modifier.stat
			sums[key] = float(sums.get(key, 0.0)) + modifier.percent
	return sums


static func type_name(definition: ItemDefinition) -> String:
	if definition.slot_kind != ItemDefinition.SlotKind.NONE:
		var kind: String = ItemDefinition.SlotKind.keys()[definition.slot_kind]
		return {"ONE_HAND_WEAPON": "One-Handed Weapon", "TWO_HAND_WEAPON": "Two-Handed Weapon", "OFF_HAND": "Off-Hand",
			"NECK": "Necklace"}.get(kind, kind.capitalize())
	return ItemDefinition.Category.keys()[definition.category].capitalize()


## Inventory tab of an item: Equipment / Materials / Consumables / Quest.
static func category_tab(definition: ItemDefinition) -> String:
	if definition.is_equippable() or definition.category in [ItemDefinition.Category.WEAPON, ItemDefinition.Category.ARMOR,
			ItemDefinition.Category.JEWELRY, ItemDefinition.Category.TRINKET]:
		return "Equipment"
	match definition.category:
		ItemDefinition.Category.CONSUMABLE:
			return "Consumables"
		ItemDefinition.Category.QUEST:
			return "Quest"
	return "Materials"


static func affix_text(db: GameDatabase, entry: Dictionary) -> String:
	var affix: AffixDefinition = db.affixes.get(StringName(str(entry.get("affix", ""))))
	var value := float(entry.get("flat", 0.0)) + float(entry.get("percent", 0.0))
	var stat := Stats.display_name(StringName(str(entry.get("stat", ""))))
	var number := StatModifier._number(value)
	if affix == null:
		return "+%s %s (fixed)" % [number, stat]
	return "+%s %s  ·  %s, tier %d" % [number, stat, affix.display_name, int(entry.get("tier", 0))]


## Plain text (simple tooltips, logs).
static func text(character: Character, item: ItemInstance) -> String:
	var parts: PackedStringArray = []
	for line in lines(character, item):
		parts.append(line.text if line.style != "section" else "- %s -" % line.text)
	return "\n".join(parts)


## Builds the description as controls into `box` (details column, tooltips).
## `compact` leaves out the dimmed lines (empty slots, flavour text) - used by
## tooltips that would not fit on a small canvas.
static func build(box: Container, character: Character, item: ItemInstance, width: float, compare: bool = true, compact: bool = false) -> void:
	for line in lines(character, item, compare):
		if compact and line.style == "dim":
			continue
		match line.style:
			"title":
				var title := UiTheme.styled(line.text, &"HeaderLabel")
				title.add_theme_color_override(&"font_color", line.color)
				title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				title.custom_minimum_size = Vector2(width, 0)
				box.add_child(title)
			"meta":
				var meta := UiTheme.styled(line.text, &"SmallLabel")
				meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				meta.custom_minimum_size = Vector2(width, 0)
				box.add_child(meta)
			"section":
				box.add_child(UiTheme.section(line.text))
			_:
				var color: Color = line.color
				var label := UiTheme.wrapped(line.text, color, width)
				if line.style == "dim":
					label.theme_type_variation = &"SmallLabel"
					label.add_theme_color_override(&"font_color", UiTheme.TEXT_MUTED)
				box.add_child(label)


static func _section(result: Array[Dictionary], title: String, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	result.append(_l(title, "section"))
	result.append_array(entries)


static func _l(text: String, style: String, color: Color = UiTheme.TEXT_PRIMARY) -> Dictionary:
	var shown := color
	match style:
		"meta":
			shown = UiTheme.TEXT_SECONDARY
		"dim":
			shown = UiTheme.TEXT_MUTED
		"good":
			shown = UiTheme.SUCCESS
		"bad":
			shown = UiTheme.DANGER
	return {"text": text, "color": shown, "style": style}


static func _modifiers(modifiers: Array[StatModifier]) -> String:
	var parts: PackedStringArray = []
	for modifier in modifiers:
		parts.append(modifier.describe())
	return ", ".join(parts)
