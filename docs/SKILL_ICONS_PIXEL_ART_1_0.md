# Skill Icons Pixel Art 1.0

Pixel-Art-Icons für alle aktiven Skills der drei spielbaren Klassen. Keine neuen Skills, keine Änderung an
Kosten, Cooldowns, Freischaltung oder Kampf.

## Bestand

`data/skills`: 21 aktive Skills, je 7 pro Klasse (Freischaltung über Level oder Talent). Passive Talente
(`data/talents`) und Skill-Modifikationen (`data/skill_mods`) sind keine Skill-Icons; Guardian und Soulbinder
(`playable = false`) haben keine Skills.

| Klasse | Skill-IDs |
|---|---|
| Warrior | furious_strike, battle_cry, blade_rush, warbreaker, whirlwind, blood_frenzy, unbound_fury |
| Arcanist | arcane_bolt, mana_pulse, frostbind, rune_sigil, arcane_rift, astral_lance, astral_ascension |
| Shadowrunner | shadow_strike, expose_weakness, shadowstep, execution, blade_fan, smoke_veil, death_mark |

## Größe und Verwendung

`assets/ui/skills/<skill id>.png`, 40 × 40 RGBA (Katalog). Die Kampfleiste (`HudSlot`, 64 × 64) zeichnete
`skills/<id>` schon 1:1 mit 40 × 40 (Fallback: Kreis + Buchstabe); unbenutzbar = 50 % gedimmt, Cooldown =
dunkler Schleier von oben über dem Icon. Neu: `UiTheme.skill_icon(id, dimmed)` - TextureRect 1:1 (40 × 40,
`STRETCH_KEEP_CENTERED`), in der Klassenstation vor Slot-Karten und Skill-Zeilen (gesperrt = gedimmt); ohne
Datei kein Icon (bisheriges Layout). Das Statuswort im HUD-Slot hat eine dunkle Kontur (das Icon reicht darunter).

## Formensprache

Harte Pixel (aliased), 1 px Ink-Kontur, transparenter Grund; jedes Icon zeigt die Handlung des Skills, eigene
Silhouette (Validator: paarweise Überlappung < 0,7). Akzente = die Skill-Farben (`SkillDefinition.color`):
Warrior Stahl + Rot / Glut (Klinge im Schwungbogen, Kriegshorn mit Schallwellen, Schwert mit Speedlines,
Hammer auf Rissen, Klingenwirbel, Blutstropfen mit Krallen, Flamme mit gesprengter Kette); Arcanist Violett /
Sternengold / Frost (Kugel mit Schweif, Ringe, Eiskristall, Runenraute, Riss, Sternenlanze, Stern über
Sichel); Shadowrunner Schatten-Violett, Stahl, Karmesin (Schattenschnitt, Auge mit Goldiris, drei Chevrons,
Dolch mit Tropfen, Messerfächer, Rauchwolke, gebrandmarkter Schädel).

## Prüfung

`validate_ui_assets.py` (82 PNGs; Icon-Menge = Skills der spielbaren Klassen aus `data/`, Kontur, Palette,
Silhouetten, kompakt), `test_skill_icons` (Datei je Skill, keine Extra-Datei, 1:1, gedimmt, Fallback),
`tests/playtest/ui_art_check.gd` Szene `skill_icons` (Kampfleiste und Skills-Seite aller drei Klassen,
Cooldown, Bereit, Kosten, gesperrt) bei 1080p 75 / 100 / 150 %, 1440p, 4K.
