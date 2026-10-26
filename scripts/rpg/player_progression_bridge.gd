class_name PlayerProgressionBridge
extends Node
## The single connection point between the combat layer (Player scene) and the
## RPG layer (Character). Added as child of the Player by SessionState.bind_player().
## Responsibilities: XP from combat events, mastery unlocks -> combo tree.
## All signal connections to the long-lived Character are tracked and removed in
## unbind(), so reloading a scene never leaves duplicate registrations behind.

signal message(text: String)

var player: Player
var character: Character
var rewards: CombatRewardTracker

var _connections: Array[Array] = []   # [Signal, Callable]


func bind(target_player: Player, target_character: Character) -> void:
	unbind()
	player = target_player
	character = target_character
	rewards = CombatRewardTracker.new(character, character.database.rules)
	rewards.attach(player.combat)
	_track(character.mastery.leveled_up, _on_mastery_leveled_up)
	_track(character.mastery.unlocked, _on_mastery_unlocked)
	refresh_unlocks()


func unbind() -> void:
	for pair in _connections:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_connections.clear()
	if rewards != null:
		rewards.detach()
		rewards = null


func is_bound() -> bool:
	return character != null and player != null


## Re-applies all mastery techniques to the combo tree (after load, level-up ...).
func refresh_unlocks() -> void:
	player.combat.combo.unlocks.clear()
	for requirement in character.mastery.unlocked_requirements():
		player.combat.set_unlocked(requirement, true)


func current_family_id() -> StringName:
	return player.combat.weapon.id if player.combat.weapon != null else &""


func debug_add_mastery_xp(amount: int) -> void:
	character.mastery.add_xp(current_family_id(), amount)


func _track(sig: Signal, callable: Callable) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable)
		_connections.append([sig, callable])


func _on_mastery_leveled_up(family_id: StringName, level: int) -> void:
	message.emit("%s mastery reached level %d" % [_family_name(family_id), level])


func _on_mastery_unlocked(family_id: StringName, unlock: MasteryUnlock) -> void:
	refresh_unlocks()
	var kind := "Technique" if unlock.is_technique() else "Milestone"
	message.emit("%s unlocked: %s (%s)" % [kind, unlock.display_name, _family_name(family_id)])


func _family_name(family_id: StringName) -> String:
	var family: WeaponFamily = character.database.weapons.get(family_id)
	return family.display_name if family != null else String(family_id)


func _exit_tree() -> void:
	unbind()
