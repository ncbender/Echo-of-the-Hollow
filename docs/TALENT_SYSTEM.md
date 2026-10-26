# Talent-System (Class Foundation 0.2)

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Modell ✅
| Datei | Rolle |
|---|---|
| `TalentTreeDefinition` (`data/talents/*.tres`) | ein Baum: ID, Klasse, Name, Farbe, Knoten |
| `TalentNodeDefinition` (Sub-Resource) | ID, Klassen-ID, Baum-ID, Tier 1–7, Max-Rang, Spalte, Voraussetzungen, Klassenlevel, Effekte |
| `TalentRules` (`data/progression/talent_rules.tres`) | Tier-Schwellen, erster Punkt, Slots, Presets, Respec-Kosten |
| `ClassBuild` (Laufzeit, gespeichert) | Ränge, Skill-Slots, Mods, Sonder-Freischaltungen, Respecs, Presets |
| `ClassBuilds` | alle Builds eines Charakters + temporärer Trial-Build |
| `TalentService` | **einzige** Regelstelle: Validierung, Lernen, Respec, Reparatur, Datencheck |
| `PresetService` | Build-Presets |

## Knotentypen ✅
- **Passive:** `stat_modifiers` pro Rang (über `StatResolver`, immer neu berechnet) und/oder
  `effects` (Kampfeffekte, Stärke = Rang).
- **Active:** `unlocks_skill` – der Skill wird verfügbar und, falls ein Slot frei ist, belegt.
- **Transformative:** `skill_mods` (immer aktive Skill-Änderung, z. B. Furious Cleave ersetzt die
  Aktion) und/oder `effects` (Klassenmechanik, z. B. Worldbreaker).

Generische Talent-Effekte (keine Sonderfälle):
- `ConditionalHitBonusEffect` (+% Schaden/Haltung/Knockback unter `HitCondition`)
- `HitTriggerEffect` (Ressource, Heilung, Status, Cooldown, Status verbrauchen, Burst)

`HitCondition` prüft Quelle (direkt/Skill/ausgelöst/Status), Tags, volle Aufladung, Status des Ziels
(Snapshot vor dem Treffer), Ressourcenquote, Pressure, kürzlich gewirkten Skill, Kill, Haltungsbruch
und Krit.

## Punkteschwellen ✅ (verbindlich)
| Tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Punkte in **niedrigeren** Tiers desselben Baums | 0 | 5 | 10 | 15 | 20 | 25 | 30 |

- Bäume sind frei mischbar; nur Punkte im eigenen Baum zählen.
- Endtalent (Tier 7) kostet selbst einen Punkt → 31 Punkte; mit 51 Punkten ist höchstens ein
  Endtalent möglich (getestet).
- Geprüft werden außerdem Max-Rang, verfügbare Punkte, Klassenlevel, Voraussetzungen.
- Datenprüfung beim Laden: keine Zyklen, Voraussetzungen gleiche Klasse und gleicher oder
  niedrigerer Tier, jeder Tier erreichbar (Rangkapazität darunter ≥ Schwelle), genau ein Endtalent
  pro Baum, Skills/Mods existieren.
- Jeder Baum: 13 Knoten (je Tier 1–6 zwei Knoten, Tier 7 ein Endtalent), Kapazität unterhalb von
  Tier 7 ≥ 30.

## Talentbäume (39 Knoten je Klasse, alle mit echtem Effekt)
Vollständige Werte stehen in den `.tres` und in den Tooltips. Beispiele:
- **Berserker:** Seething Blood (+2 % Angriffstempo/Rang), Relentless (+4 %/Rang bei ≥ 50 % Rage),
  Whirlwind [A], Cyclone [T], Furious Cleave [T, 360°], **Unbound Fury** [A].
- **Warbreaker:** Heavy Hands, Crushing Finish, Breaker (Rage bei Haltungsbruch), Aftershock (Burst bei
  Heavy-Finishern), Titan's Grip [T], **Worldbreaker** (+30 % Haltung, Beben 56 px / 60 %).
- **Bloodblade:** Serrated Edge (Blutungschance), Hemorrhage (Finisher → Blutung je Rang),
  Sanguine (Heilung je Blutungstick), Blood Frenzy [A], **Blood Oath** (30 % Blutungsschaden als
  Heilung, Finisher zerreißen ≥ 3 Stacks für 8 je Stack).
- **Elemental Weaver:** Chill-Chance, Frostbite, Shatterbolt [T], Ice Lance [T], **Winter's Grasp**
  (+40 % gegen 3 Chill-Stacks, Skills zerschmettern den Chill).
- **Runemaster:** Resonant Marks, Glyph Lore (schaltet Mod „Double Mark“ frei), Arcane Rift [A],
  Detonation, Echoing Marks, **Glyph Cascade** (zweites Siegel).
- **Astral Scholar:** Studious, Clarity, Focused Mind, Astral Lance [A], Lance of Stars [T],
  **Astral Ascension** [A].
- **Assassin:** Precision, Keen Eye, Opportunist, Guillotine [T], Swift Kill, **Death Mark** [A]
  (+60 % gegen markierte Ziele, Kill → Cooldowns −4 s, +30 Fokus).
- **Bladestorm (0.3):** Dancing Blades (+% Focus-Gewinn) wurde zu **Focused Strikes** (gleiche ID
  `sr_bs_dance`): direkte Waffentreffer haben 25 % Chance auf 3 Bonus-Focus pro Rang, max. einmal pro Schwung.
- **Bladestorm:** Quick Hands, Flurry, Blade Fan [A], Fan of Knives [T], Piercing Blades [T],
  **Thousand Cuts** (Light-Finisher → Klingenring 50 %, Blutung).
- **Night Hunter:** Ambush, Smoke Veil [A], Choking Smoke [T], Phantom Step [T], **Nightfall**.

Balance: **konservative Startwerte, nicht gespielt.**

## Respec ✅
- Nur an einer Klassenstation, nicht während einer Trial; setzt alle Talente einer Klasse zurück.
- Erster Respec jeder Klasse kostenlos, danach `10 + 2 × (Level − 1)` **Gold Coins** (normale
  Währung; Gegner droppen Gold, Grunt 3, Grove Warden 25).
- Bleiben erhalten: Klassen-XP/-Level, Skill-/Mod-Freischaltungen aus anderen Quellen,
  Waffenbeherrschung, Quests.
- Skills/Mods, die nur ein Talent freigeschaltet hat, verlassen ihre Slots (`SkillBook.sanitize`).

## Build-Presets ✅
Fünf Plätze pro Klasse (`ClassBuild.presets`). Ein Preset speichert Name, Talentverteilung, vier
Skills, Mods, Equipment-Referenzen der Klasse (Instanz-IDs) und `extra` (klassenspezifisch, frei).

| Aktion | Kosten |
|---|---|
| Speichern, Umbenennen, Löschen | kostenlos, überall |
| Aktivieren mit identischer Talentverteilung | kostenlos (Klassenstation) |
| Aktivieren mit anderer Verteilung | normale Respec-Kosten (zählt als Respec) |

Vor dem Aktivieren prüft `PresetService.validate`:
- die Klassenfreischaltung
- Talente (gleiche Regeln wie beim Lernen)
- Skills und Mods gegen einen Probe-Build mit den Preset-Talenten
- vorhandene Iteminstanzen und Ausrüstungsregeln
- das Gold

Fehlende Items werden gemeldet, nie neu erzeugt. Eine ungültige Aktivierung ändert nichts.

## Laden
`TalentService.sanitize_build` repariert geladene Builds:
- Unbekannte Knoten werden entfernt.
- Ränge werden geklemmt.
- Eine ungültige Verteilung wird als Ganzes zurückgesetzt.
- Skills und Mods werden bereinigt.

Alle Korrekturen landen als Warnungen. Builds gesperrter Klassen werden nicht gespeichert.
