class_name TargetFrame
extends PanelContainer
## Top-centre enemy frame: the enemy you fought last (name, rank word, health,
## poise, statuses) - or, while a boss is engaged, a wider boss bar. Small and
## at the top edge, so telegraphs in the playfield are never covered.
## Read-only: Enemy health/poise/status components; rank is presentation data.

const LINGER := 5.0
const BOSS_RANGE := 340.0
const WIDTH := 420.0
const BOSS_WIDTH := 640.0

var bridge: PlayerProgressionBridge
var target: Enemy

var _name: Label
var _rank: Label
var _health: ProgressBar
var _poise: ProgressBar
var _status: Label
var _since_hit: float = 99.0


func _ready() -> void:
	theme_type_variation = &"HudPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 3)
	add_child(box)
	var head := HBoxContainer.new()
	_name = UiTheme.styled("", &"SubheadingLabel")
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	_rank = UiTheme.styled("", &"CaptionLabel")
	head.add_child(_rank)
	box.add_child(head)
	_health = UiTheme.bar(10, UiTheme.HEALTH)
	box.add_child(_health)
	_poise = UiTheme.bar(5, UiTheme.POISE)
	box.add_child(_poise)
	_status = UiTheme.styled("", &"CaptionLabel")
	box.add_child(_status)
	visible = false


## Remembers the enemy the player just hit (connected by GameHud).
func on_player_hit(hit: HitData) -> void:
	var enemy := hit.target as Enemy
	if enemy != null and is_instance_valid(enemy):
		target = enemy
		_since_hit = 0.0


func _process(delta: float) -> void:
	_since_hit += delta
	var player := bridge.player if bridge != null and bridge.is_bound() else null
	if player == null or not is_instance_valid(player):
		visible = false
		return
	var boss := _engaged_boss(player)
	var shown := boss if boss != null else target
	if shown == null or not is_instance_valid(shown) or shown.state == Enemy.State.DEAD \
			or (boss == null and _since_hit > LINGER):
		visible = false
		return
	visible = true
	var config := shown.config
	var is_boss := config.rank == 2
	custom_minimum_size.x = BOSS_WIDTH if is_boss else WIDTH
	_name.text = config.display_name
	if is_boss:
		_name.add_theme_font_override(&"font", UiTheme.display_font())
	else:
		_name.remove_theme_font_override(&"font")
	_name.add_theme_color_override(&"font_color", UiTheme.BRONZE if is_boss else UiTheme.TEXT_PRIMARY)
	_rank.text = ["", "ELITE", "BOSS"][clampi(config.rank, 0, 2)]
	_rank.add_theme_color_override(&"font_color", UiTheme.WARNING if config.rank > 0 else UiTheme.TEXT_MUTED)
	_health.custom_minimum_size.y = 14 if is_boss else 10
	_health.max_value = maxf(1.0, shown.health.max_health)
	_health.value = shown.health.health
	_poise.max_value = maxf(1.0, shown.health.max_poise)
	_poise.value = shown.health.poise
	var parts: PackedStringArray = []
	if shown.health.is_staggered():
		parts.append("STAGGERED")
	var statuses := StatusComponent.of(shown)
	if statuses != null:
		for status_id in statuses.active_ids():
			var definition: StatusEffectDefinition = bridge.character.database.statuses.get(status_id)
			var stacks := statuses.stacks(status_id)
			parts.append("%s%s" % [definition.display_name if definition != null else String(status_id).capitalize(), " x%d" % stacks if stacks > 1 else ""])
	_status.text = "  ·  ".join(parts)
	_status.visible = not parts.is_empty()


func _engaged_boss(player: Node2D) -> Enemy:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("*", "Enemy", true, false):
		var enemy := node as Enemy
		if enemy.config.rank == 2 and enemy.state != Enemy.State.DEAD \
				and enemy.global_position.distance_to(player.global_position) < BOSS_RANGE:
			return enemy
	return null
