class_name TrialGrounds
extends Node
## Class Trials 2.0 M3 (docs/CLASS_TRIALS_2_0_M3.md): runs the class trial
## `trial_id` on its own grounds. Rules stay in PrologueService; this node only
## drives the two areas of the map:
##  * training: the `training` encounter starts when the map is entered with
##    this trial running and sends a new wave while training goals are open
##  * trial area: the `finale` encounter (mini-boss) starts once the gate is
##    open (training done) and the player comes within its trigger radius; it
##    comes back if it falls before the finale goals are met (never a dead end)
##  * the end: success (all goals, PrologueService.record), death (the bridge)
##    or leaving (the exit; the altar map ends the trial) - after success or
##    death the player is carried back to the Heart of the Stone, once.
## A preview visit (no running trial) starts nothing. Nothing here is saved.

@export var trial_id: StringName
@export var training: Encounter
@export var finale: Encounter
@export var gate: TrialGate

var character: Character
var session: SessionState
var returning: bool = false


func _ready() -> void:
	for encounter: Encounter in [training, finale]:
		if encounter != null:
			encounter.set_physics_process(false)   # never by proximity alone: this node decides
	_setup.call_deferred()   # after GameMap._ready bound the character


func _setup() -> void:
	session = SessionState.find(get_tree())
	character = session.get_character() if session != null else null
	if character == null:
		return
	character.prologue.trial_finished.connect(_on_trial_finished)
	if character.classes.in_trial() and character.prologue.active_trial != trial_id:
		PrologueService.end_trial(character, false)   # another trial never runs on these grounds
		return
	if is_active():
		var trial: TrialDefinition = character.database.trials[trial_id]
		var map := get_parent() as GameMap
		if map != null:
			map.hud.notify("%s: %s" % [trial.display_name, trial.description])
		if training != null:
			training.start()


## True while this ground's trial runs (a preview visit is not active).
func is_active() -> bool:
	return character != null and character.prologue.active_trial == trial_id and trial_id != &""


func _physics_process(_delta: float) -> void:
	if not is_active() or returning:
		return
	var trained := PrologueService.training_done(character, trial_id)
	if training != null and not trained and not training.running:
		training.start()   # goals not met yet: the next wave
	if finale == null or not trained or finale.running:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null and player.global_position.distance_to(finale.global_position) <= finale.trigger_radius:
		finale.start()   # first time, or again after it fell before the finale goals were met


func _on_trial_finished(_finished_id: StringName, _completed: bool) -> void:
	return_to_altar()   # any trial that ends here (own success or death, a foreign one) goes home


## Back to the Heart of the Stone (success, death). One transition only.
func return_to_altar() -> void:
	if returning or session == null:
		return
	returning = true
	var map_def: MapDefinition = character.database.maps.get(character.world.current_map_id)
	if map_def != null and map_def.resume_map_id != &"":
		session.travel(map_def.resume_map_id, map_def.resume_spawn_id)
