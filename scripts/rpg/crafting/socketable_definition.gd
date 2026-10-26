class_name SocketableDefinition
extends Resource
## Gem or rune that fits into a socket (independent of essence slots).
## Removing it returns the item: socket contents are freely exchangeable.

enum Kind { GEM, RUNE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var item_id: StringName
@export var kind: Kind = Kind.GEM
@export var modifiers: Array[StatModifier] = []
@export var effect: ItemEffect
@export var allowed_slot_kinds: Array[ItemDefinition.SlotKind] = []
