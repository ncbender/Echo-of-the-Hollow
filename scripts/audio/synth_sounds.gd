class_name SynthSounds
extends RefCounted
## Placeholder combat sounds synthesized at runtime (Combat Defense & Feedback
## 0.4): no audio assets exist yet and none are downloaded. Each cue is a short
## mono PCM AudioStreamWAV built from a small recipe (tones, sweeps, noise,
## envelope), generated once and cached. Replace by real assets later by giving
## CombatAudio a file for the same cue id.

const MIX_RATE := 22050

static var _cache: Dictionary = {}

## cue id -> recipe. Layers: {"wave": sine|square|noise, "from": Hz, "to": Hz,
## "gain": 0..1, "attack": s, "length": s}. Total length = longest layer.
const RECIPES := {
	&"hit_light": [{"wave": "noise", "gain": 0.55, "attack": 0.002, "length": 0.05},
		{"wave": "sine", "from": 320.0, "to": 180.0, "gain": 0.35, "attack": 0.001, "length": 0.06}],
	&"hit_heavy": [{"wave": "noise", "gain": 0.5, "attack": 0.002, "length": 0.09},
		{"wave": "sine", "from": 130.0, "to": 60.0, "gain": 0.7, "attack": 0.002, "length": 0.14}],
	&"poise_break": [{"wave": "square", "from": 420.0, "to": 110.0, "gain": 0.3, "attack": 0.002, "length": 0.17},
		{"wave": "noise", "gain": 0.45, "attack": 0.002, "length": 0.12}],
	&"block": [{"wave": "sine", "from": 900.0, "to": 860.0, "gain": 0.4, "attack": 0.001, "length": 0.12},
		{"wave": "sine", "from": 1350.0, "to": 1300.0, "gain": 0.25, "attack": 0.001, "length": 0.1},
		{"wave": "noise", "gain": 0.3, "attack": 0.001, "length": 0.03}],
	&"parry": [{"wave": "sine", "from": 1400.0, "to": 1420.0, "gain": 0.45, "attack": 0.001, "length": 0.3},
		{"wave": "sine", "from": 2100.0, "to": 2150.0, "gain": 0.3, "attack": 0.001, "length": 0.25},
		{"wave": "noise", "gain": 0.25, "attack": 0.001, "length": 0.04}],
	&"guard_break": [{"wave": "square", "from": 180.0, "to": 85.0, "gain": 0.35, "attack": 0.002, "length": 0.2},
		{"wave": "noise", "gain": 0.4, "attack": 0.002, "length": 0.1}],
	&"warrior_skill": [{"wave": "noise", "gain": 0.35, "attack": 0.12, "length": 0.18},
		{"wave": "sine", "from": 110.0, "to": 70.0, "gain": 0.55, "attack": 0.002, "length": 0.15}],
	&"arcane_cast": [{"wave": "sine", "from": 600.0, "to": 1200.0, "gain": 0.4, "attack": 0.01, "length": 0.16},
		{"wave": "sine", "from": 900.0, "to": 1800.0, "gain": 0.15, "attack": 0.01, "length": 0.14}],
	&"arcane_detonate": [{"wave": "sine", "from": 300.0, "to": 900.0, "gain": 0.45, "attack": 0.002, "length": 0.25},
		{"wave": "noise", "gain": 0.3, "attack": 0.002, "length": 0.12}],
	&"shadow_skill": [{"wave": "noise", "gain": 0.4, "attack": 0.06, "length": 0.13},
		{"wave": "sine", "from": 2400.0, "to": 1800.0, "gain": 0.15, "attack": 0.001, "length": 0.04}],
	&"execution": [{"wave": "sine", "from": 90.0, "to": 55.0, "gain": 0.65, "attack": 0.002, "length": 0.2},
		{"wave": "noise", "gain": 0.45, "attack": 0.001, "length": 0.08},
		{"wave": "sine", "from": 1700.0, "to": 900.0, "gain": 0.2, "attack": 0.001, "length": 0.1}],
	&"unblockable_warn": [{"wave": "square", "from": 520.0, "to": 520.0, "gain": 0.22, "attack": 0.002, "length": 0.08},
		{"wave": "square", "from": 390.0, "to": 390.0, "gain": 0.22, "attack": 0.1, "length": 0.2}],
}


static func has_cue(cue: StringName) -> bool:
	return RECIPES.has(cue)


static func stream(cue: StringName) -> AudioStreamWAV:
	if _cache.has(cue):
		return _cache[cue]
	var recipe: Array = RECIPES.get(cue, [])
	if recipe.is_empty():
		return null
	var length := 0.0
	for layer: Dictionary in recipe:
		length = maxf(length, layer.get("attack", 0.0) + layer.length)
	var count := int(length * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cue)
	for layer: Dictionary in recipe:
		var phase := 0.0
		var attack: float = layer.get("attack", 0.0)
		var total: float = attack + layer.length
		for i in count:
			var time := float(i) / MIX_RATE
			if time > total:
				break
			var envelope := time / attack if time < attack and attack > 0.0 else pow(1.0 - (time - attack) / layer.length, 2.0)
			var value := 0.0
			match layer.wave:
				"noise":
					value = rng.randf_range(-1.0, 1.0)
				"square", "sine":
					var freq := lerpf(layer.get("from", 440.0), layer.get("to", 440.0), time / total)
					phase += TAU * freq / MIX_RATE
					value = sin(phase) if layer.wave == "sine" else signf(sin(phase))
			samples[i] += value * envelope * float(layer.get("gain", 0.5))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] * 0.6, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	_cache[cue] = wav
	return wav
