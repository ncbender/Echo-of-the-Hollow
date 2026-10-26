class_name CombatRewardTracker
extends RefCounted
## Turns the player's accepted hits into progression XP (weapon mastery of the
## attack's family, class XP for the active class).
## Exploit guards:
##  * only accepted hits count (CombatComponent.hit_landed) - clicks never give XP
##  * one reward per (swing, target): duplicate events are ignored
##  * training targets give reduced XP with a per-target cap and no kill reward
##  * a kill is rewarded once per target instance
##  * Armor Mastery: a kill gives its mastery XP to the worn armour too (never hits taken)

signal rewarded(kind: StringName, amount: int)

const DEDUPE_MEMORY := 512

var character: Character
var rules: ProgressionRules
var _combat: CombatComponent
var _seen_hits: Dictionary = {}
var _seen_order: Array[String] = []
var _killed: Dictionary = {}
var _training_xp: Dictionary = {}   # target instance id -> mastery XP granted


func _init(owner_character: Character, progression_rules: ProgressionRules) -> void:
	character = owner_character
	rules = progression_rules if progression_rules != null else ProgressionRules.new()


func attach(combat: CombatComponent) -> void:
	detach()
	_combat = combat
	combat.hit_landed.connect(_on_hit_landed)


func detach() -> void:
	if _combat != null and is_instance_valid(_combat) and _combat.hit_landed.is_connected(_on_hit_landed):
		_combat.hit_landed.disconnect(_on_hit_landed)
	_combat = null


func _on_hit_landed(hit: HitData) -> void:
	if hit.attack == null or hit.target == null or not is_instance_valid(hit.target):
		return
	var target_id := hit.target.get_instance_id()
	var key := "%d:%d" % [hit.attack_instance_id, target_id]
	if _seen_hits.has(key):
		return
	_remember(key)

	var training := hit.target.is_in_group(&"training_target")
	var xp := rules.mastery_xp_per_hit
	if &"finisher" in hit.tags:
		xp += rules.finisher_bonus_xp
	var profile := hit.attack.charge_profile
	if profile != null and profile.max_tier() > 0 and hit.charge_tier >= profile.max_tier():
		xp += rules.full_charge_bonus_xp
	if training:
		var granted: int = _training_xp.get(target_id, 0)
		xp = mini(floori(xp * rules.training_xp_multiplier), rules.training_xp_cap_per_target - granted)
		_training_xp[target_id] = granted + maxi(xp, 0)
	if xp > 0:
		character.mastery.add_xp(hit.attack.weapon_family_id, xp)
		rewarded.emit(&"mastery", xp)
	if not training and rules.class_xp_per_hit > 0:
		character.add_class_xp(rules.class_xp_per_hit)

	if not training and not _killed.has(target_id) and _is_dead(hit.target) \
			and hit.target.has_method(&"get_kill_reward"):
		_killed[target_id] = true
		var reward: Dictionary = hit.target.call(&"get_kill_reward")
		var mastery_xp: int = reward.get("mastery_xp", 0)
		var class_xp: int = reward.get("class_xp", 0)
		if mastery_xp > 0:
			character.mastery.add_xp(hit.attack.weapon_family_id, mastery_xp)
			rewarded.emit(&"kill_mastery", mastery_xp)
			ArmorMasteryService.add_xp(character, mastery_xp)   # the worn armour learns from the kill too
		if class_xp > 0:
			character.add_class_xp(class_xp)
			rewarded.emit(&"kill_class", class_xp)


## Kill by a skill or a status tick (no weapon swing): class XP of the kill
## reward, once per target; no weapon mastery (no weapon was used).
func reward_kill(hit: HitData) -> void:
	var target := hit.target
	if target == null or not is_instance_valid(target) or target.is_in_group(&"training_target"):
		return
	var target_id := target.get_instance_id()
	if _killed.has(target_id) or not _is_dead(target) or not target.has_method(&"get_kill_reward"):
		return
	_killed[target_id] = true
	var reward: Dictionary = target.call(&"get_kill_reward")
	var class_xp: int = reward.get("class_xp", 0)
	ArmorMasteryService.add_xp(character, float(reward.get("mastery_xp", 0)))   # armour learns from every kill
	if class_xp > 0:
		character.add_class_xp(class_xp)
		rewarded.emit(&"kill_class", class_xp)


func _is_dead(target: Node) -> bool:
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	return health != null and health.is_dead()


func _remember(key: String) -> void:
	_seen_hits[key] = true
	_seen_order.append(key)
	if _seen_order.size() > DEDUPE_MEMORY:
		_seen_hits.erase(_seen_order.pop_front())
