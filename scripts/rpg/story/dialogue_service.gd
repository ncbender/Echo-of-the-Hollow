class_name DialogueService
extends RefCounted
## Dialogue rules. Stateless: progress is "dialogue.<id>" flags plus the story
## events reported on completion.

const PLAYER := &"player"


## The dialogue `npc` offers right now (null: only idle lines).
static func pick(character: Character, npc: NpcDefinition) -> DialogueDefinition:
	if npc == null:
		return null
	for dialogue in npc.dialogues:
		if dialogue == null or not StoryCondition.check(dialogue.condition, character):
			continue
		if not dialogue.repeatable and character.world.has_flag(dialogue.done_flag()):
			continue
		return dialogue
	return null


## True if the offered dialogue moves the story on (HUD marker "!").
static func has_story_dialogue(character: Character, npc: NpcDefinition) -> bool:
	var dialogue := pick(character, npc)
	return dialogue != null and dialogue.event_id != &"" and not character.world.has_flag(dialogue.done_flag())


## Called once the last line was read.
static func finish(character: Character, dialogue: DialogueDefinition) -> void:
	character.world.set_flag(dialogue.done_flag())
	if dialogue.event_id != &"":
		StoryService.notify(character, dialogue.event_id)


static func speaker_name(db: GameDatabase, speaker: StringName) -> String:
	if speaker == PLAYER:
		return "You"
	var npc: NpcDefinition = db.npcs.get(speaker)
	return npc.display_name if npc != null else ""


static func speaker_color(db: GameDatabase, speaker: StringName) -> Color:
	if speaker == PLAYER:
		return Color(0.75, 0.85, 1.0)
	var npc: NpcDefinition = db.npcs.get(speaker)
	return npc.color.lightened(0.25) if npc != null else Color(0.8, 0.8, 0.8)


static func validate_data(db: GameDatabase) -> PackedStringArray:
	var errors: PackedStringArray = []
	var ids := {}
	for npc: NpcDefinition in db.npcs.values():
		for dialogue in npc.dialogues:
			if dialogue == null or dialogue.id == &"" or dialogue.lines.is_empty():
				errors.append("npc %s has an empty or unnamed dialogue" % npc.id)
				continue
			if ids.has(dialogue.id):
				errors.append("dialogue id %s used twice" % dialogue.id)
			ids[dialogue.id] = true
			for line in dialogue.lines:
				if line.speaker != &"" and line.speaker != PLAYER and not db.npcs.has(line.speaker):
					errors.append("dialogue %s: unknown speaker %s" % [dialogue.id, line.speaker])
	return errors
