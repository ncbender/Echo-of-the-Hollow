class_name CombatAudio
extends Node
## Combat audio layer of a map (Combat Defense & Feedback 0.4). One instance per
## GameMap (created in code, freed with the map - scene changes end all sounds;
## a paused tree pauses them). Gameplay code only calls the static play().
##  * a small pool of positional AudioStreamPlayer2D voices on the "SFX" bus
##  * the same cue at most once per THROTTLE seconds (a sweep hitting five
##    enemies plays one hit sound) and at most MAX_PER_CUE voices at once
##  * busy moments get quieter: every voice already playing lowers new ones
##  * effects volume from UserSettings (user://settings.cfg), applied to the bus
## Sounds come from SynthSounds (placeholders) unless a file is registered.

const GROUP := &"combat_audio"
const BUS := &"SFX"
const VOICES := 12
const THROTTLE := 0.05
const MAX_PER_CUE := 3
## Most recent cues (tests, debugging).
const LOG_SIZE := 64

## Optional real assets: cue id -> AudioStream (overrides the synth placeholder).
static var files: Dictionary = {}

var played: Array[StringName] = []
var _voices: Array[AudioStreamPlayer2D] = []
var _last_played: Dictionary = {}   # cue -> time (s)
var _time: float = 0.0


static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, &"Master")


## Volume 0..1 of all combat sounds (UserSettings.sfx_volume).
static func set_volume(linear: float) -> void:
	ensure_bus()
	var index := AudioServer.get_bus_index(BUS)
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


## Plays `cue` at `at` through the combat audio of `near`'s scene tree.
static func play(near: Node, cue: StringName, at: Vector2 = Vector2.INF) -> bool:
	if cue == &"" or near == null or not near.is_inside_tree():
		return false
	var audio := near.get_tree().get_first_node_in_group(GROUP) as CombatAudio
	if audio == null:
		return false
	var position := at
	if position == Vector2.INF and near is Node2D:
		position = (near as Node2D).global_position
	return audio.play_cue(cue, position)


func _ready() -> void:
	add_to_group(GROUP)
	ensure_bus()
	for i in VOICES:
		var voice := AudioStreamPlayer2D.new()
		voice.bus = BUS
		voice.max_distance = 700.0
		add_child(voice)
		_voices.append(voice)


func _process(delta: float) -> void:
	_time += delta


func play_cue(cue: StringName, at: Vector2) -> bool:
	var stream: AudioStream = files.get(cue, SynthSounds.stream(cue))
	if stream == null:
		return false
	if _time - float(_last_played.get(cue, -1.0)) < THROTTLE:
		return false   # same event already sounding (multi-target hits, double triggers)
	var same := 0
	var busy := 0
	var free_voice: AudioStreamPlayer2D = null
	for voice in _voices:
		if voice.playing:
			busy += 1
			if voice.stream == stream:
				same += 1
		elif free_voice == null:
			free_voice = voice
	if same >= MAX_PER_CUE or free_voice == null:
		return false
	_last_played[cue] = _time
	free_voice.stream = stream
	free_voice.global_position = at
	free_voice.volume_db = -1.5 * busy   # many sounds at once: each new one quieter
	free_voice.play()
	played.append(cue)
	if played.size() > LOG_SIZE:
		played.pop_front()
	return true
