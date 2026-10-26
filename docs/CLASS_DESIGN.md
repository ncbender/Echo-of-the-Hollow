# Klassen-Design (Class Foundation 0.2)

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen
Details: `TALENT_SYSTEM.md` (Talente, Respec, Presets), `SKILL_SYSTEM.md` (Skills, Mods, Status),
`CLASS_QUESTS.md` (Prolog, Klassenquests). Früherer Name dieses Dokuments: `CLASS_SYSTEM.md`.

## Grundregeln ✅
- Ein Charakter kann alle Klassen freischalten, spielt aber immer genau **eine** (aktive Klasse).
- **Geteilt:** Weltfortschritt, Quests, Inventar und Iteminstanzen, Materialien/Währungen,
  Waffenbeherrschung, Heimatbasis.
- **Pro Klasse:** freigeschaltet, Level (1–60), XP, Ressource (Laufzeit), Talentverteilung,
  Skill-Freischaltungen, 4 Skill-Slots, Mods, Loadout (Instanz-Referenzen), 5 Build-Presets.
- Klassenwechsel nur an einer **Klassenstation** (`Character.switch_class`), nie während einer Trial.
- Nur die aktive Klasse bekommt Klassen-XP (Treffer, Kills; Skill-/Statuskills ebenfalls).
- Talentpunkte: ab Level 10 einer pro Level → **51 auf Level 60** (`TalentRules`).
- XP-Kurve der 60er-Klassen: `100 × 1,07^(Level−1)` (vorläufig, nicht balanciert).

## Klassen
| Klasse | Status | Ressource | Mechanik | Bäume (Endtalent) |
|---|---|---|---|---|
| Basic Adventurer | ✅ Start, max. Lv 10 | – | neutral, keine Schilde, keine Skills | – |
| Warrior | ✅ spielbar | **Rage** (zerfällt nach 3 s) | Combat Pressure: aufeinanderfolgende Treffer (≤ 2 s) beschleunigen den Rage-Aufbau (+10 %/Stack, max. 5) | Berserker (Unbound Fury, aktiv) · Warbreaker (Worldbreaker, transformativ) · Bloodblade (Blood Oath) |
| Arcanist | ✅ spielbar | **Mana** (regeneriert 8/s) | Arcane Marks (bis 3 Stacks), von Mana Pulse / Rune Sigil / Astral Lance detoniert | Elemental Weaver (Winter's Grasp) · Runemaster (Glyph Cascade) · Astral Scholar (Astral Ascension, aktiv) |
| Shadowrunner | ✅ spielbar | **Focus** (zerfällt nach 4 s) | Weak Points: Light-Finisher legen sie frei, Treffer darauf +10 % und Fokus-Bonus, Execution verbraucht sie | Assassin (Death Mark, aktiv) · Bladestorm (Thousand Cuts) · Night Hunter (Nightfall) |
| Guardian | 🔧 vorbereitet (`playable = false`) | Resolve | später: talentabhängige heilige Eide | – |
| Soulbinder | 🔧 vorbereitet (`playable = false`) | Soul Energy | später: Seelenenergie, Echos | – |

Ausrüstungsregeln: Warrior alle Waffen + Schilde · Arcanist Einhandschwert, keine Schilde/Dual Wield ·
Shadowrunner Einhandschwert, Dual Wield, keine Schilde.

## Ressourcen (`ClassResourceDefinition`, datengetrieben) ✅
| | Rage | Mana | Focus |
|---|---|---|---|
| Start / Max | 0 / 100 | 100 / 100 | 0 / 100 |
| Regeneration | −10/s nach 3 s | +8/s | −8/s nach 4 s |
| Treffer | +8 (+6 Finisher, +4 Heavy) | +3 | +5 (+8 Finisher, +10 Weak Point, +5 Krit) |
| Getroffen | +5 | – | – |
| Haltungsbruch / Kill | +10 / +8 | – / +10 | +8 / +12 |
| Combat Pressure | 5 Stacks, 2 s, +10 % | – | 5 Stacks, 1,5 s, +5 % |

Max. Ressource durch Stat `max_resource` (Talente), Gewinn durch `resource_gain`, Kosten durch
`resource_efficiency`. Ressourcen werden nicht gespeichert.

## Skills je Klasse (Details `SKILL_SYSTEM.md`)
| Warrior | Arcanist | Shadowrunner |
|---|---|---|
| Furious Strike (Lv 1) | Arcane Bolt (Lv 1) | Shadow Strike (Lv 1) |
| Battle Cry (Lv 3) | Mana Pulse (Lv 3) | Expose Weakness (Lv 3) |
| Blade Rush (Lv 5) | Frostbind (Lv 5) | Shadowstep (Lv 5) |
| Warbreaker (Lv 8) | Rune Sigil (Lv 8) | Execution (Lv 8) |
| Whirlwind (Talent) | Arcane Rift (Talent) | Blade Fan (Talent) |
| Blood Frenzy (Talent) | Astral Lance (Talent) | Smoke Veil (Talent) |
| Unbound Fury (Endtalent) | Astral Ascension (Endtalent) | Death Mark (Endtalent) |

Grundangriffe (Light/Heavy) bleiben kostenlos und unverändert.

## Klassenstation & Fenster ✅
`ClassStationPanel` – mit **G** an einer Klassenstation (alles erlaubt) oder **C** überall (nur
ansehen + Talente lernen). Seiten: Klassen, Talente (drei Bäume, Linien, Tooltips), Skills
(Slots + Form/Resonance), Presets, Quests. HUD: Klasseninfo (Ressource, Pressure), Skill-Leiste
Q/E/R/F (Kosten, Cooldown), Ziele-Panel (Trial/Quests).

## Erweiterbarkeit
Neue Klasse = `ClassDefinition` + Ressource + 3 `TalentTreeDefinition` + Skills/Mods als Daten.
Klassenmechaniken als `innate_effects` (Effekte wie Talente). Kein Klassencode in Systemen.
