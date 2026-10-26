class_name Interactable
extends Area2D
## Something the player can use with the interact key (G) while standing in it.
## Subclasses override interact(); the HUD shows `prompt` while in range.

@export var prompt: String = "Interact"

var player_inside: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # player body
	monitoring = true
	monitorable = false
	add_to_group(&"interactable")
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			player_inside = true)
	body_exited.connect(func(body: Node2D) -> void:
		if body is Player:
			player_inside = false)


func interact(_hud: GameHud) -> void:
	pass


## The interactable the player currently stands in (first found), or null.
static func find_active(tree: SceneTree) -> Interactable:
	for node in tree.get_nodes_in_group(&"interactable"):
		var interactable := node as Interactable
		if interactable != null and interactable.player_inside and interactable.is_visible_in_tree():
			return interactable
	return null
