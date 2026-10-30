class_name Enemy
extends CharacterBody2D
## Simple melee enemy: chase, telegraphed attack, hit reaction, stagger, death.
## The AI only produces InputFrames for its own CombatComponent, so enemy attacks
## use exactly the same data, phases, hitboxes and hit pipeline as the player.
## The telegraph is the (long) startup phase of the enemy's attack definition.

signal defeated(enemy: Enemy)
## A player parried one of this enemy's attacks (feedback).
signal parried

enum State { CHASE, TELEGRAPH, ATTACKING, STAGGERED, DEAD }

@export var config: EnemyConfig
@export var attacks: WeaponFamily
## Non-empty for boss/quest enemies: once defeated, a world flag keeps them
## defeated across map changes and saves. Normal enemies leave it empty and
## respawn whenever the map is loaded again.
@export var persistent_id: StringName
## Persistent enemies without a reward cache (whose BossRewardCache would ask for it) request
## the milestone save of their first defeat themselves (GameMap). Off for every other enemy.
@export var defeat_milestone: bool = false
## Hollowwood Loot Integration 1.0: equipment roll of THIS placed enemy per real death
## (EquipmentLoot, once; GameMap._spawn_drops). Null = fixed drops only.
@export var equipment_loot: EquipmentLootTable

var target: Node2D
var state: State = State.CHASE
var _cooldown: float = 0.0
var knockback := KnockbackMotion.new()
var dead_time: float = 0.0
## Remaining local hitstop; while > 0 the enemy (AI, combat, movement) is frozen.
var hitstop_left: float = 0.0
var _attacks_started: int = 0

@onready var combat: CombatComponent = $CombatComponent
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
var status: StatusComponent


func _ready() -> void:
	if config == null:
		config = EnemyConfig.new()
	if config.max_health > 0.0 or config.max_poise > 0.0:
		health.max_health = config.max_health if config.max_health > 0.0 else health.max_health
		health.max_poise = config.max_poise if config.max_poise > 0.0 else health.max_poise
		health.reset()
	status = StatusComponent.of(self, true)
	status.resistances = config.status_resistances
	status.max_slow_cap = config.max_slow
	knockback.deceleration = config.knockback_decay
	if config.attacks != null:
		attacks = config.attacks   # the variant's own attacks (EnemyConfig.attacks); without one nothing changes
	combat.set_weapon(attacks)
	combat.attack_finished.connect(func(_attack: AttackDefinition) -> void: _cooldown = config.attack_cooldown)
	hurtbox.invulnerability_check = health.is_dead
	hurtbox.hit_received.connect(_on_hit_received)
	health.poise_broken.connect(_on_poise_broken)
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player") as Node2D


func _physics_process(delta: float) -> void:
	physics_step(delta)


func physics_step(delta: float) -> void:
	if state == State.DEAD:
		dead_time += delta
		if dead_time >= config.despawn_delay:
			queue_free()
		return
	if hitstop_left > 0.0:
		hitstop_left = maxf(0.0, hitstop_left - delta)
		velocity = Vector2.ZERO
		return

	_cooldown = maxf(0.0, _cooldown - delta)
	var to_target := _to_target()
	var frame := InputFrame.new()
	frame.aim_direction = to_target.normalized()

	if state == State.STAGGERED:
		if not health.is_staggered():
			state = State.CHASE
	elif combat.state == CombatComponent.State.IDLE and _cooldown <= 0.0 \
			and to_target != Vector2.ZERO and to_target.length() <= config.attack_range:
		_attacks_started += 1
		var interval := config.heavy_attack_interval
		if interval > 0 and _attacks_started % interval == 0 and attacks.root_heavy != &"":
			frame.heavy_pressed = true   # tap: AI heavies are never charged
		else:
			frame.light_pressed = true

	combat.step(delta, frame, frame.aim_direction, state == State.STAGGERED)
	_sync_state()
	_move(to_target, delta)


## Local hitstop (see HitstopController). Overlapping requests never add up.
## Rewards for the progression system (CombatRewardTracker), granted once per enemy.
func get_kill_reward() -> Dictionary:
	return {"mastery_xp": config.mastery_xp_reward, "class_xp": config.class_xp_reward}


func apply_hitstop(duration: float) -> void:
	hitstop_left = maxf(hitstop_left, duration)


func _to_target() -> Vector2:
	if target == null or not is_instance_valid(target) or not _target_alive():
		return Vector2.ZERO
	return target.global_position - global_position


func _target_alive() -> bool:
	var target_health := target.get_node_or_null("HealthComponent") as HealthComponent
	return target_health == null or not target_health.is_dead()


func _sync_state() -> void:
	if state == State.STAGGERED:
		return
	if combat.state != CombatComponent.State.ATTACKING:
		state = State.CHASE
	elif combat.phase == CombatComponent.Phase.STARTUP:
		state = State.TELEGRAPH
	else:
		state = State.ATTACKING


func _move(to_target: Vector2, delta: float) -> void:
	var desired := Vector2.ZERO
	var distance := to_target.length()
	var knocked := knockback.is_active()
	if knocked:
		desired = knockback.step(delta)   # own steps/lunge pause, so the push distance is exact
	elif state == State.CHASE and distance > config.stop_distance and distance < config.aggro_range:
		desired = to_target.normalized() * config.move_speed * status.move_multiplier()   # chill: own locomotion only
	elif combat.state == CombatComponent.State.ATTACKING:
		desired = combat.take_lunge_velocity(delta)
	velocity = BodyContact.strip_push(self, desired, delta)
	move_and_slide()
	if knocked:
		knockback.record(get_position_delta())


func _on_hit_received(hit: HitData) -> void:
	knockback.start(hit.knockback * config.knockback_taken())
	if is_braced():
		hit.poise_damage *= config.braced_poise_taken   # one scaling at the receiver, like parry poise
	health.apply_hit(hit)


## True while the running attack is in an uninterruptible phase and this enemy braces in it.
func is_braced() -> bool:
	return config.braced_poise_taken < 1.0 and not combat.is_interruptible()


## Called by the defender (DefenseComponent) after a successful parry.
func on_parried() -> void:
	if state == State.DEAD:
		return
	parried.emit()
	if config.parry_interrupts:
		combat.cancel(&"parried")   # the swing is over; pending hits are discarded
		_cooldown = maxf(_cooldown, config.parry_daze)


func _on_poise_broken() -> void:
	if state == State.DEAD:
		return
	combat.cancel(&"stagger")   # interrupts telegraph/attack, pending hit is discarded
	state = State.STAGGERED


func _on_died() -> void:
	combat.cancel(&"death")
	state = State.DEAD
	$CollisionShape2D.set_deferred(&"disabled", true)
	defeated.emit(self)
