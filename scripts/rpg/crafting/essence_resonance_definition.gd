class_name EssenceResonanceDefinition
extends Resource
## Extra effect while BOTH essences are bound in the same item.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var essence_a: StringName
@export var essence_b: StringName
@export var effect: ItemEffect


func matches(essences: Array[StringName]) -> bool:
	return essence_a in essences and essence_b in essences
