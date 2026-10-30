extends TestCase
## Skill Icons Pixel Art 1.0 (docs/SKILL_ICONS_PIXEL_ART_1_0.md): every active skill of a playable class has its
## 40 x 40 icon under skills/<skill id> (and no icon exists for anything else), the class station helper shows it
## 1:1 and dims a locked one, and without art the text-only fallback stays (no icon node).


func test_every_playable_skill_has_its_icon() -> void:
	var db := GameDatabase.get_default()
	var playable := 0
	for skill: SkillDefinition in db.skills.values():
		var class_def := db.get_class_def(skill.class_id)
		if class_def == null or not class_def.playable:
			continue
		playable += 1
		var art := UiSkin.texture(StringName("skills/%s" % skill.id))
		check(art != null and art.get_size() == UiTheme.SKILL_ICON_SIZE, "skills/%s: 40 x 40" % skill.id)
	check_eq(playable, 21, "21 active skills of the three playable classes")
	var files: Array = Array(DirAccess.get_files_at("res://assets/ui/skills")).filter(func(f: String) -> bool: return f.ends_with(".png"))
	for file: String in files:
		check(db.skills.has(StringName(file.get_basename())), "%s belongs to a real skill" % file)
	check_eq(files.size(), playable, "one file per skill, no extra icons")


func test_station_icon_one_to_one_dimmed_and_fallback() -> void:
	var icon := UiTheme.skill_icon(&"furious_strike")
	check(icon != null and icon.texture.get_size() == Vector2(40, 40) and icon.custom_minimum_size == Vector2(40, 40), "1:1 at 40 x 40")
	check(icon.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED, "never stretched")
	check(icon.modulate == Color.WHITE, "an available skill in full colour")
	var locked := UiTheme.skill_icon(&"whirlwind", true)
	check(locked != null and locked.modulate.r < 0.6, "a locked skill dimmed")
	check(UiTheme.skill_icon(&"no_such_skill") == null, "no art: no icon node (the text layout stays)")
	for node: Node in [icon, locked]:
		node.free()
