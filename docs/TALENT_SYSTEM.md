# Talent-System (Class Foundation 0.2)

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Modell ✅
| Datei | Rolle |
|---|---|
| `TalentTreeDefinition` (`data/talents/*.tres`) | ein Baum: ID, Klasse, Name, Farbe, Knoten |
| `TalentNodeDefinition` (Sub-Resource) | ID, Klassen-ID, Baum-ID, Tier 1–4, Max-Rang, Spalte 0–3, Voraussetzungen, Klassenlevel, Effekte |
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

## Punkteschwellen ✅ (verbindlich, Talent Structure Rework 1.0 - `TALENT_STRUCTURE_REWORK_1_0.md`)
| Tier | 1 | 2 | 3 | 4 (Endtalent) |
|---|---|---|---|---|
| Punkte in **niedrigeren** Tiers desselben Baums | 0 | 5 | 18 | 30 |

- Ein Tier öffnet nur über Punkte im eigenen Baum; innerhalb eines offenen Tiers ist **jedes** Talent frei wählbar.
  Bäume sind frei mischbar; Punkte anderer Bäume zählen nie.
- Voraussetzungen (`prerequisites`) nur für direkte Upgrades des Skills eines Aktiv-Talents (6 Stück), nie für
  Endtalente oder Passives.
- Endtalent (Tier 4) kostet selbst einen Punkt → 31 Punkte; mit 56 Punkten (ab Level 5, Level 60) ist höchstens ein
  Endtalent möglich (2 × 31 > 56), Tier 3 in höchstens zwei Bäumen (3 × 19 > 56), Tier 2 in allen dreien (getestet).
- Geprüft werden außerdem Max-Rang, verfügbare Punkte, Klassenlevel, Voraussetzungen.
- Datenprüfung beim Laden: keine Zyklen, Voraussetzungen gleiche Klasse und gleicher oder
  niedrigerer Tier, jeder Tier erreichbar (Rangkapazität darunter ≥ Schwelle), genau ein Endtalent
  pro Baum, Spalte 0–3, `tier_points` hat `TalentRules.TIERS` (4) Einträge, Skills/Mods existieren.
- Jeder Baum: 13 Knoten (Tier 1–3 je vier, Tier 4 ein Endtalent), Kapazität unterhalb des Endtalents 36–38 ≥ 30.
- Talentseite (Skills & Talents UX 2.0 Phase 2): ein Baum zur Zeit, vier Plätze je Tier-Zeile, Linien nur für echte
  Voraussetzungen; Klick wählt aus, gelernt wird nur über den Learn-Button im Detailbereich.

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
- den ganzen Ausrüstungswechsel (`CharacterEquipment.loadout_error`, siehe unten)
- das Gold

Fehlende Items werden gemeldet, nie neu erzeugt.

### Aktivierung: alles oder nichts ✅ (Preset Activation Atomicity Fix 1.0)

**Bisheriger Fehler.** `activate` lief so ab: Prüfung → Gold zahlen und Respec zählen → Talente, Slots und Mods
übernehmen → erst zuletzt `apply_loadout`. `apply_loadout` prüft mehr als `validate`:
- die Tasche im Zielzustand,
- eine Zweihandwaffe mit Nebenhand-Item,
- dasselbe Item doppelt.

Scheiterte es (z. B. volle Tasche), waren Talente, Skills, Mods und Gold schon gewechselt. Zusätzlich setzte
`build.from_dict(preset)` alles zurück, was ein Preset nicht enthält: den Respec-Zähler (der nächste Reset war
wieder kostenlos), Freischaltungen aus anderen Quellen (`unlocked_skills` / `unlocked_mods`). Die Preset-Felder
(`name`, `equipment`, …) landeten in `build.extra`.

**Jetzt.**
- **Vollständige Vorprüfung:** `validate` ruft nach den Einzelprüfungen der Item-Referenzen
  `CharacterEquipment.loadout_error(class, equipment)` auf. Das ist das Urteil von `apply_loadout` ohne Änderung:
  - dieselben Prüfungen über das gemeinsame `_plan_loadout`;
  - die Tasche wird im **echten Zielzustand** gemessen (Loadout kurz gesetzt, `used_slots` gezählt, sofort
    zurückgesetzt);
  - frei werdende Plätze zählen, Tausch bei voller Tasche ist erlaubt;
  - abgelehnt nur, wenn die Tasche über der Kapazität **und** voller als vorher wäre (`_overfills`, dieselbe
    Regel wie bei jedem Loadout-Wechsel).
- **Durchführung in umkehrbarer Reihenfolge**, erst nach bestandener Prüfung:
  1. `apply_loadout` (selbst atomar);
  2. die Reset-Kosten, nur bei anderen Talenten (scheitert die Zahlung, stellt `restore_loadout` das Loadout
     exakt wieder her);
  3. zuletzt der Build im Speicher - **nur** Talente, Q/E/R/F und Mods aus dem Preset (kann nicht scheitern).
     Respec-Zähler +1 nur bei Talentwechsel; Freischaltungen, andere Presets und `extra` bleiben.
- Eine abgelehnte Aktivierung lässt Talente, Skills, Mods, Respec-Zähler, alle Loadouts, Tasche, Lager und Gold
  unverändert. Die Presets-Seite zeigt den Grund (z. B. „Your bag is full - make room first.“) vorher und sperrt
  Activate.
- Keine Änderung an Preset-Format, Slotregeln, Kapazität (40), Reset-Preisen; Save v15.
- Tests: `test_preset_atomicity` (Fälle A-O, voller Zustandsvergleich vor / nach einer abgelehnten Aktivierung),
  `test_preset_ui` (Grund sichtbar, Activate gesperrt, nichts geändert).

## Laden
`TalentService.sanitize_build` repariert geladene Builds:
- Unbekannte Knoten werden entfernt.
- Ränge werden geklemmt.
- Eine ungültige Verteilung wird als Ganzes zurückgesetzt.
- Skills und Mods werden bereinigt.

Alle Korrekturen landen als Warnungen. Builds gesperrter Klassen werden nicht gespeichert.
