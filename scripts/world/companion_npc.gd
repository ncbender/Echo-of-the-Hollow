class_name CompanionNpc
extends StoryNpc
## A StoryNpc that can follow the player (escort) and lend a hand in fights.
##
## Follow: Mara walks the player's own trail (breadcrumbs), so she never needs
## pathfinding and can never get stuck on walls. Far behind (a long dash, a
## fast detour) she catches up after RECOVER_DELAY with one quiet fade-in
## behind the player - never repeatedly (RECOVER_COOLDOWN). Nothing ever waits
## for her: transitions and scripts only look at the player, and after loading
## or a map change she simply appears next to the player again.
##
## Support (limited, scripted): while `support_condition` holds she strikes the
## nearest enemy within SUPPORT_RANGE every SUPPORT_INTERVAL seconds through
## the normal hit pipeline (Hurtbox.receive_hit). She takes no damage and gives
## the player no XP.

## Follows the player while met (and the NPC is present).
@export var follow_condition: StoryCondition
## Helps in fights while met.
@export var support_condition: StoryCondition

const FOLLOW_GAP := 30.0
const CRUMB_SPACING := 6.0
const MAX_CRUMBS := 240
const MOVE_SPEED := 175.0
const RECOVER_DISTANCE := 190.0
const RECOVER_DELAY := 1.2
const RECOVER_COOLDOWN := 4.0
const SUPPORT_RANGE := 110.0
const SUPPORT_INTERVAL := 2.4
const SUPPORT_DAMAGE := 6.0
const SUPPORT_POISE := 12.0
const SUPPORT_KNOCKBACK := 10.0

var _crumbs: PackedVector2Array = []
var _far_time: float = 0.0
var _recover_cooldown: float = 0.0
var _support_left: float = 1.0
var _was_following: bool = false
## Recoveries so far (tests check that there is no teleport spam).
var recoveries: int = 0
## Support strikes so far.
var strikes: int = 0


func is_following() -> bool:
	return visible and follow_condition != null and StoryCondition.check(follow_condition, character)


func is_supporting() -> bool:
	return visible and support_condition != null and StoryCondition.check(support_condition, character)


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _physics_process(delta: float) -> void:
	var player := _player()
	if player == null or not visible:
		return
	var following := is_following()
	if following and not _was_following:
		_join(player)
	_was_following = following
	if following:
		_follow(player, delta)
	if is_supporting():
		_support(delta)


## Starts following: stands right behind the player (map start, after loading).
func _join(player: Player) -> void:
	_crumbs.clear()
	if global_position.distance_to(player.global_position) > RECOVER_DISTANCE:
		global_position = player.global_position + Vector2(0, FOLLOW_GAP)
	_far_time = 0.0


func _follow(player: Player, delta: float) -> void:
	var target := player.global_position
	if _crumbs.is_empty() or _crumbs[_crumbs.size() - 1].distance_to(target) >= CRUMB_SPACING:
		_crumbs.append(target)
		if _crumbs.size() > MAX_CRUMBS:
			_crumbs.remove_at(0)
	_recover_cooldown = maxf(0.0, _recover_cooldown - delta)
	var distance := global_position.distance_to(target)
	if distance > RECOVER_DISTANCE:
		_far_time += delta
		if _far_time >= RECOVER_DELAY and _recover_cooldown <= 0.0:
			_recover(player)
			return
	else:
		_far_time = 0.0
	var trail := _trail_length(target)
	if trail <= FOLLOW_GAP:
		return
	var step := MOVE_SPEED * clampf(trail / 70.0, 0.7, 1.5) * delta
	while step > 0.0 and not _crumbs.is_empty() and _trail_length(target) > FOLLOW_GAP:
		var next := _crumbs[0]
		var to_next := next - global_position
		if to_next.length() <= step:
			global_position = next
			step -= to_next.length()
			_crumbs.remove_at(0)
		else:
			global_position += to_next.normalized() * step
			step = 0.0


## Length of the remaining trail from here to the player.
func _trail_length(target: Vector2) -> float:
	if _crumbs.is_empty():
		return global_position.distance_to(target)
	var length := global_position.distance_to(_crumbs[0])
	for index in range(1, _crumbs.size()):
		length += _crumbs[index - 1].distance_to(_crumbs[index])
	return length + _crumbs[_crumbs.size() - 1].distance_to(target)


## One quiet catch-up: appears on the trail just behind the player.
func _recover(player: Player) -> void:
	recoveries += 1
	_recover_cooldown = RECOVER_COOLDOWN
	_far_time = 0.0
	var behind := player.global_position + Vector2(0, FOLLOW_GAP)
	var walked := 0.0
	for index in range(_crumbs.size() - 1, 0, -1):
		walked += _crumbs[index].distance_to(_crumbs[index - 1])
		if walked >= FOLLOW_GAP:
			behind = _crumbs[index - 1]
			_crumbs = _crumbs.slice(index - 1)
			break
	global_position = behind
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


func _support(delta: float) -> void:
	_support_left -= delta
	if _support_left > 0.0:
		return
	var enemy := _nearest_enemy()
	if enemy == null:
		_support_left = 0.3
		return
	_support_left = SUPPORT_INTERVAL
	strike(enemy)


func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_distance := SUPPORT_RANGE
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("*", "Enemy", true, false):
		var enemy := node as Enemy
		if enemy.state == Enemy.State.DEAD:
			continue
		var distance := enemy.global_position.distance_to(global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## One support hit through the normal pipeline (the enemy's hurtbox).
func strike(enemy: Enemy) -> void:
	var direction := (enemy.global_position - global_position).normalized()
	var hit := HitData.new()
	hit.attacker = self
	hit.damage = SUPPORT_DAMAGE
	hit.poise_damage = SUPPORT_POISE
	hit.knockback = direction * SUPPORT_KNOCKBACK
	hit.reaction = HitReaction.Type.FLINCH
	hit.reaction_duration = 0.15
	hit.position = enemy.global_position
	hit.source = HitData.Source.TRIGGERED
	if enemy.hurtbox.receive_hit(hit):
		strikes += 1
		var world := CombatFx.world_of(self)
		CombatFx.spawn(world, enemy.global_position + Vector2(0, -4), CombatFx.Style.SLASH, Color(1.0, 0.75, 0.45), 12.0, 0.2, direction)
		CombatAudio.play(self, &"hit_light", enemy.global_position)
