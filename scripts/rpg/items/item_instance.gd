class_name ItemInstance
extends RefCounted
## One physical item (or stack) owned by a character. Identity is the
## instance_id: it never changes and is never shared by two instances.
## Static data comes from the ItemDefinition referenced by definition_id.
## Crafting state (docs/CRAFTING_DESIGN.md) is individual data of the instance:
## it is saved exactly as rolled and never re-rolled or derived on load.

var instance_id: String
var definition_id: StringName
var quantity: int = 1
## Affix tiers depend on it; independent of quality.
var item_level: int = 1
## 0..CraftingProfile.max_quality; improves defined base stats (+1 % per point).
var quality: int = 0
## Main material chosen at imprint ("" = not imprinted yet).
var material_id: StringName = &""
## Rolled affixes: {"affix": id, "tier": n, "tier_model": 3/5, "stat": id, "flat": v, "percent": v}
## ("tier_model" = AffixTiers model the tier number belongs to).
## Entries without "affix" are legacy stat rolls (still applied, not reforgeable).
var affixes: Array[Dictionary] = []
## Bound essences (max CraftingProfile.essence_slots, never more than 2).
var essences: Array[StringName] = []
## Opened sockets; "" = empty socket, otherwise a SocketableDefinition id.
var sockets: Array[StringName] = []
## Evolution state of evolving items: {"stage": int, "xp": int, "path": String}.
var evolution: Dictionary = {}
## Free-form individual progress; also keeps data that could not be applied
## (e.g. essences beyond the slot limit) so no player property is ever lost.
var progress: Dictionary = {}
## Increments with every crafting change. Crafting requests carry the revision
## they were previewed for, so a repeated click on a stale preview never applies twice.
var revision: int = 0
## Player protection (docs/ITEM_SYSTEM.md, Item Integrity): a favourite or a
## locked item is never salvaged. Only single items (not stacks) carry them.
var favorite: bool = false
var locked: bool = false
## Where the item came from (ORIGINS); &"" = not tracked (stacks, debug and
## test items). Old saves get ORIGIN_LEGACY - never guessed.
var origin: StringName = &""

const ORIGIN_FOUND := &"found"
const ORIGIN_CRAFTED := &"crafted"
const ORIGIN_QUEST := &"quest_reward"
const ORIGIN_STARTING := &"starting"
const ORIGIN_LEGACY := &"unknown_legacy"
const ORIGINS: Array[StringName] = [ORIGIN_FOUND, ORIGIN_CRAFTED, ORIGIN_QUEST, ORIGIN_STARTING, ORIGIN_LEGACY]


static func create(item_id: StringName, amount: int = 1, id: String = "") -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = id if id != "" else IdGenerator.new_id("itm")
	item.definition_id = item_id
	item.quantity = amount
	return item


func affix_modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for affix in affixes:
		result.append(StatModifier.make(StringName(str(affix.get("stat", ""))), float(affix.get("flat", 0.0)), float(affix.get("percent", 0.0))))
	return result


func is_imprinted() -> bool:
	return material_id != &""


func evolution_stage() -> int:
	return int(evolution.get("stage", 1))


func evolution_xp() -> int:
	return int(evolution.get("xp", 0))


func evolution_path() -> StringName:
	return StringName(str(evolution.get("path", "")))


func touch() -> void:
	revision += 1


func to_dict() -> Dictionary:
	var data := {"id": instance_id, "def": String(definition_id), "qty": quantity}
	if item_level != 1:
		data["ilvl"] = item_level
	if quality != 0:
		data["quality"] = quality
	if material_id != &"":
		data["material"] = String(material_id)
	if not affixes.is_empty():
		data["affixes"] = affixes.duplicate(true)
	if not essences.is_empty():
		data["essences"] = _strings(essences)
	if not sockets.is_empty():
		data["sockets"] = _strings(sockets)
	if not evolution.is_empty():
		data["evolution"] = evolution.duplicate(true)
	if not progress.is_empty():
		data["progress"] = progress.duplicate(true)
	if revision != 0:
		data["rev"] = revision
	if favorite:
		data["fav"] = true
	if locked:
		data["lock"] = true
	if origin != &"":
		data["origin"] = String(origin)
	return data


## Parses saved data; returns null when mandatory fields are missing/invalid.
## Optional crafting fields fall back to defaults when missing or malformed.
static func from_dict(data: Variant) -> ItemInstance:
	if not data is Dictionary:
		return null
	var id := str(data.get("id", ""))
	var def_id := str(data.get("def", ""))
	var qty := int(data.get("qty", 0))
	if id == "" or def_id == "" or qty <= 0:
		return null
	var item := ItemInstance.create(StringName(def_id), qty, id)
	item.item_level = maxi(1, _int(data.get("ilvl", 1), 1))
	item.quality = maxi(0, _int(data.get("quality", 0), 0))
	item.material_id = StringName(str(data.get("material", ""))) if data.get("material") is String else &""
	var saved_affixes: Array = data["affixes"] if data.get("affixes") is Array else []
	for affix: Variant in saved_affixes:
		if affix is Dictionary:
			item.affixes.append(_normalized_affix(affix))
	item.essences = _names(data.get("essences", []))
	item.sockets = _names(data.get("sockets", []))
	if data.get("evolution") is Dictionary and not data["evolution"].is_empty():
		var saved: Dictionary = data["evolution"]
		item.evolution = {"stage": _int(saved.get("stage", 1), 1), "xp": _int(saved.get("xp", 0), 0), "path": str(saved.get("path", ""))}
	if data.get("progress") is Dictionary:
		item.progress = data["progress"]
	item.revision = maxi(0, _int(data.get("rev", 0), 0))
	item.favorite = data.get("fav") == true
	item.locked = data.get("lock") == true
	var saved_origin := StringName(str(data.get("origin", ""))) if data.get("origin") is String else &""
	item.origin = saved_origin if saved_origin in ORIGINS else (ORIGIN_LEGACY if saved_origin != &"" else &"")
	return item


## JSON turns integers into floats: restore the canonical types of a rolled affix.
static func _normalized_affix(affix: Dictionary) -> Dictionary:
	var result := affix.duplicate(true)
	for key: String in ["tier", "tier_model"]:
		if result.has(key):
			result[key] = _int(result[key], 0)
	for key: String in ["flat", "percent"]:
		result[key] = float(result[key]) if result.get(key) is float or result.get(key) is int else 0.0
	return result


static func _int(value: Variant, fallback: int) -> int:
	return int(value) if value is int or value is float else fallback


static func _names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for entry: Variant in value:
			if entry is String or entry is StringName:
				result.append(StringName(str(entry)))
	return result


static func _strings(names: Array[StringName]) -> Array:
	var result := []
	for name in names:
		result.append(String(name))
	return result
