class_name ItemInstance
extends RefCounted
## One physical item (or stack) owned by a character. Identity is the
## instance_id: it never changes and is never shared by two instances.
## Static data comes from the ItemDefinition referenced by definition_id.

var instance_id: String
var definition_id: StringName
var quantity: int = 1
## Individual rolled modifiers: [{"stat": String, "flat": float, "percent": float}].
var affixes: Array[Dictionary] = []
## Prepared: individual item progression (e.g. kills, upgrade level).
var progress: Dictionary = {}
## Prepared: socketed essence data.
var essence: Dictionary = {}
## Prepared: evolution state of evolving items.
var evolution: Dictionary = {}


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


func to_dict() -> Dictionary:
	var data := {"id": instance_id, "def": String(definition_id), "qty": quantity}
	if not affixes.is_empty():
		data["affixes"] = affixes.duplicate(true)
	if not progress.is_empty():
		data["progress"] = progress.duplicate(true)
	if not essence.is_empty():
		data["essence"] = essence.duplicate(true)
	if not evolution.is_empty():
		data["evolution"] = evolution.duplicate(true)
	return data


## Parses saved data; returns null when mandatory fields are missing/invalid.
static func from_dict(data: Variant) -> ItemInstance:
	if not data is Dictionary:
		return null
	var id := str(data.get("id", ""))
	var def_id := str(data.get("def", ""))
	var qty := int(data.get("qty", 0))
	if id == "" or def_id == "" or qty <= 0:
		return null
	var item := ItemInstance.create(StringName(def_id), qty, id)
	for affix: Variant in data.get("affixes", []):
		if affix is Dictionary:
			item.affixes.append(affix)
	for key: String in ["progress", "essence", "evolution"]:
		if data.get(key) is Dictionary:
			item.set(key, data[key])
	return item
