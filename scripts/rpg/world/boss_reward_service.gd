class_name BossRewardService
extends RefCounted
## Grove Warden Rare R2 (docs/GROVE_WARDEN_RARE_R2.md): the one guaranteed equipment
## reward of a persistent boss. Two world facts, one derived claim:
##  * defeated.<boss_id>      - set only by GameMap on the real kill (unchanged)
##  * boss_reward.<boss_id>   - set only by claim(), right after the item entered the bag
##  * claim open              = defeated AND not boss_reward (never stored separately)
## The item is rolled at claim time (EquipmentLoot.roll with the boss's table), never at
## the kill. Bag and claim flag change in the same synchronous call, so every save
## snapshot sees both or neither. Class, prologue choice and trials grant nothing here.
## Chapter 1 Rare Reward 1.0 (docs/CHAPTER_1_RARE_REWARD_1_0.md): `taken_flags` are further
## world flags that also count as this reward taken (the frozen claim of an earlier
## placement), so a relocated guarantee is never granted twice.


static func defeat_flag(boss_id: StringName) -> StringName:
	return StringName("defeated.%s" % boss_id)


static func claimed_flag(boss_id: StringName) -> StringName:
	return StringName("boss_reward.%s" % boss_id)


static func is_defeated(character: Character, boss_id: StringName) -> bool:
	return boss_id != &"" and character.world.has_flag(defeat_flag(boss_id))


static func is_claimed(character: Character, boss_id: StringName,
		taken_flags: Array[StringName] = []) -> bool:
	if boss_id == &"":
		return false
	if character.world.has_flag(claimed_flag(boss_id)):
		return true
	for flag in taken_flags:
		if character.world.has_flag(flag):
			return true
	return false


## The derived claim: the boss is proven defeated and its reward was not taken yet.
static func has_claim(character: Character, boss_id: StringName,
		taken_flags: Array[StringName] = []) -> bool:
	return is_defeated(character, boss_id) and not is_claimed(character, boss_id, taken_flags)


## "" if the reward can be taken now, else the reason (also shown to the player).
static func can_claim(character: Character, boss_id: StringName, table: EquipmentLootTable,
		taken_flags: Array[StringName] = []) -> String:
	if not is_defeated(character, boss_id):
		return "The cache is sealed."
	if is_claimed(character, boss_id, taken_flags):
		return "The cache is empty."
	if character.classes.in_trial():
		return "Finish or leave the current trial first."
	if table == null or table.item_ids.is_empty():
		return "The cache holds nothing."
	for item_id in table.item_ids:   # every model must fit: the roll happens only afterwards
		if character.inventory.room_for(item_id) < 1:
			return "Your bag is full. Make room to open the cache."
	return ""


## Takes the open reward: all checks first, then ONE roll of `table` (origin found), the
## instance into the bag, then the claim flag. A refusal rolls nothing and changes nothing.
## Returns "" or the reason; `claimed` receives the new item on success.
static func claim(character: Character, boss_id: StringName, table: EquipmentLootTable,
		rng: RandomNumberGenerator, claimed: Array[ItemInstance] = [],
		taken_flags: Array[StringName] = []) -> String:
	var error := can_claim(character, boss_id, table, taken_flags)
	if error != "":
		return error
	var item := EquipmentLoot.roll(table, character.database, rng)
	if item == null:
		return "The cache holds nothing."
	error = hand_over(character, boss_id, item)
	if error == "":
		claimed.append(item)
	return error


## The hand-over step of claim(): the instance into the bag, and only then the claim flag
## (bool true: WorldState.has_flag cannot compare String values). A failed insert sets no
## flag and keeps no instance - the generated item existed only in memory and the claim
## stays open.
static func hand_over(character: Character, boss_id: StringName, item: ItemInstance) -> String:
	if character.inventory.add_instance(item) != "":
		return "Your bag is full. Make room to open the cache."
	character.world.set_flag(claimed_flag(boss_id))
	return ""
