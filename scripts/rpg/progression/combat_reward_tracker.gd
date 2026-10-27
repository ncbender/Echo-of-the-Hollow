class_name CombatRewardTracker
extends RefCounted
## Turns the player's fights into progression XP.
##  * Weapon mastery (Weapon Mastery 1.4): only from valid fights - when an enemy
##    dies, its mastery XP is split among the weapon families that dealt damage
##    to it, by their share of that weapon damage (participation, not per hit and
##    not only the last hit). A kill by a skill or a status still pays the
##    families that took part. Training targets give no mastery XP.
##  * Class XP: per accepted hit on a non-training target (unchanged).
##  * Armor Mastery: a kill gives its mastery XP to the worn armour too.
## Exploit guards: only accepted hits count (clicks never give XP); one class
## reward per (swing, target); a kill is rewarded once per target instance.

signal rewarded(kind: StringName, amount: int)

const DEDUPE_MEMORY := 512

var character: Character
var rules: ProgressionRules
var _combat: CombatComponent
var _seen_hits: Dictionary = {}
var _seen_order: Array[String] = []
var _killed: Dictionary = {}
## Weapon damage per living target: target instance id -> {family id: damage}.
var _contributions: Dictionary = {}
var _contribution_order: Array[int] = []


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


## Weapon damage `family_id` dealt to `target` so far (tests, debug).
func contribution(target: Node, family_id: StringName) -> float:
	var entry: Dictionary = _contributions.get(target.get_instance_id(), {})
	return entry.get(family_id, 0.0)


func _on_hit_landed(hit: HitData) -> void:
	if hit.attack == null or hit.target == null or not is_instance_valid(hit.target):
		return
	var target_id := hit.target.get_instance_id()
	var training := hit.target.is_in_group(&"training_target")
	if not training:
		_contribute(target_id, hit.attack.weapon_family_id, hit.damage)
	var key := "%d:%d" % [hit.attack_instance_id, target_id]
	if _seen_hits.has(key):
		return
	_remember(key)
	if not training and rules.class_xp_per_hit > 0:
		character.add_class_xp(rules.class_xp_per_hit)

	if not training and not _killed.has(target_id) and _is_dead(hit.target) \
			and hit.target.has_method(&"get_kill_reward"):
		_killed[target_id] = true
		var reward: Dictionary = hit.target.call(&"get_kill_reward")
		var mastery_xp: int = reward.get("mastery_xp", 0)
		var class_xp: int = reward.get("class_xp", 0)
		_pay_mastery(target_id, mastery_xp)
		ArmorMasteryService.add_xp(character, mastery_xp)   # the worn armour learns from the kill too
		if class_xp > 0:
			character.add_class_xp(class_xp)
			rewarded.emit(&"kill_class", class_xp)


## Kill by a skill or a status tick (no weapon swing): class XP of the kill
## reward once per target, and the weapon families that took part in the fight
## share its mastery XP.
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
	_pay_mastery(target_id, int(reward.get("mastery_xp", 0)))
	ArmorMasteryService.add_xp(character, float(reward.get("mastery_xp", 0)))   # armour learns from every kill
	if class_xp > 0:
		character.add_class_xp(class_xp)
		rewarded.emit(&"kill_class", class_xp)


func _contribute(target_id: int, family_id: StringName, damage: float) -> void:
	if family_id == &"":
		return
	if not _contributions.has(target_id):
		_contributions[target_id] = {}
		_contribution_order.append(target_id)
		if _contribution_order.size() > DEDUPE_MEMORY:
			_contributions.erase(_contribution_order.pop_front())
	var entry: Dictionary = _contributions[target_id]
	entry[family_id] = float(entry.get(family_id, 0.0)) + maxf(damage, 0.001)


## Splits `xp` among the families that damaged the target (largest share gets
## the rounding rest); nothing when no weapon took part.
func _pay_mastery(target_id: int, xp: int) -> void:
	var entry: Dictionary = _contributions.get(target_id, {})
	_contributions.erase(target_id)
	_contribution_order.erase(target_id)
	if xp <= 0 or entry.is_empty():
		return
	var total := 0.0
	var best: StringName = &""
	for family_id: StringName in entry:
		total += entry[family_id]
		if best == &"" or entry[family_id] > entry[best]:
			best = family_id
	var shares := {}
	var paid := 0
	for family_id: StringName in entry:
		shares[family_id] = floori(xp * entry[family_id] / total)
		paid += shares[family_id]
	shares[best] += xp - paid
	for family_id: StringName in shares:
		if shares[family_id] > 0:
			character.mastery.add_xp(family_id, shares[family_id])
			rewarded.emit(&"kill_mastery", shares[family_id])


func _is_dead(target: Node) -> bool:
	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	return health != null and health.is_dead()


func _remember(key: String) -> void:
	_seen_hits[key] = true
	_seen_order.append(key)
	if _seen_order.size() > DEDUPE_MEMORY:
		_seen_hits.erase(_seen_order.pop_front())
