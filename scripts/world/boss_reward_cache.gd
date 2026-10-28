class_name BossRewardCache
extends Interactable
## Grove Warden Rare R2: the cache at a boss's place (StoryPickup pattern). Present only
## while the derived claim is open (BossRewardService.has_claim: boss defeated, reward
## not taken) - also before the class choice, after map changes, save/load and in old
## saves with a real defeat flag. G takes the reward through BossRewardService.claim;
## a full bag or a running trial keeps the cache (nothing rolled, nothing dropped).
## The first defeat of its boss asks for one milestone save (after the flag is set).

@export var boss_id: StringName
@export var loot_table: EquipmentLootTable
@export var label: String = "Warden's Cache"

var character: Character
var session: SessionState
## Rolls of this cache (one per successful claim); tests may seed it.
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	rng.randomize()
	prompt = "Open %s" % label
	session = SessionState.find(get_tree())
	if session != null:
		character = session.get_character()
		character.world.flag_changed.connect(_on_flag_changed)
	refresh()


func _exit_tree() -> void:
	if character != null and character.world.flag_changed.is_connected(_on_flag_changed):
		character.world.flag_changed.disconnect(_on_flag_changed)


func refresh() -> void:
	visible = character != null and BossRewardService.has_claim(character, boss_id)


## WorldState emits flag_changed only on a real change, so the defeat of the boss
## reaches here once per save state: exactly one milestone save, after the flag is set.
func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == BossRewardService.defeat_flag(boss_id) and session != null:
		session.request_critical_save("boss defeated %s" % boss_id)
	refresh()


## Returns "" on success or the reason; `claimed` receives the new item.
func open(claimed: Array[ItemInstance] = []) -> String:
	if character == null:
		return "The cache is sealed."
	var error := BossRewardService.claim(character, boss_id, loot_table, rng, claimed)
	refresh()
	if error == "" and session != null:
		session.request_critical_save("boss reward %s" % boss_id)
	return error


func interact(hud: GameHud) -> void:
	var claimed: Array[ItemInstance] = []
	var error := open(claimed)
	if error != "":
		hud.notify(error)
		return
	var item := claimed[0]
	var definition := character.database.get_item(item.definition_id)
	if hud.bridge != null:
		hud.bridge.item_received.emit(item.definition_id, item.quantity, item)   # loot feed with the instance rarity
	hud.notify("%s: %s (%s)" % [label, definition.display_name, UiTheme.rarity_name(item.effective_rarity(definition))])


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var wood := Color(0.42, 0.3, 0.18)
	var gold: Color = ItemDefinition.RARITY_COLORS.get(ItemDefinition.Rarity.RARE, Color(1, 0.85, 0.3))
	draw_rect(Rect2(-11, -12, 22, 15), wood)
	draw_rect(Rect2(-11, -16, 22, 5), wood.lightened(0.15))
	draw_rect(Rect2(-11, -16, 22, 19), wood.darkened(0.5), false, 1.0)
	draw_line(Vector2(-11, -11), Vector2(11, -11), gold, 1.0)
	draw_rect(Rect2(-2, -12, 4, 4), gold)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	draw_circle(Vector2(0, -6), 15.0 + 2.0 * pulse, Color(gold, 0.10 + 0.08 * pulse))
	if player_inside:
		draw_rect(Rect2(-13, -18, 26, 23), Color(1, 0.9, 0.5, 0.4 + 0.4 * pulse), false, 1.0)
	WorldText.draw(self, Vector2(-WorldText.width(label, 6) * 0.5, -21), label, 6, gold.lightened(0.3), 2, Color.BLACK)
