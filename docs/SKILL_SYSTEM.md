# Skill-System, Status und Effekt-Integration (Class Foundation 0.2)

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Aktive Skills ✅
| Datei | Rolle |
|---|---|
| `SkillDefinition` (`data/skills/`) | Klasse, Tags, Kosten, Cooldown, Freischalt-Level (0 = Talent/Quest), Cast-Lock, Aktionen |
| `SkillAction` + `AreaStrikeAction`, `ProjectileAction`, `ZoneAction`, `MoveAction`, `BuffAction` | Bausteine (Daten) |
| `SkillHitSpec` / `SkillStatusSpec` | Schaden, Haltung, Knockback-Distanz, Typ, Tags, Status, Status verbrauchen, Bonus gegen Status, Ressource pro Treffer |
| `SkillParams` | pro Cast neu aufgelöst: Skill + Mods + Talent-Transformationen + Kosten-/CD-Stats |
| `SkillCast` | Laufzeit eines Casts; `deliver()` ist die **einzige** Stelle, an der ein Skill-Treffer entsteht |
| `SkillBook` | verfügbare Skills/Mods, Slots, Mods setzen, Bereinigung |
| `ClassRuntime` | Ressource, Cooldowns, Buffs, Verstärkung, Pressure, `try_cast` |
| `SkillProjectile`, `SkillZone` (`scripts/combat/`) | generische Kampfknoten (Welt-Abfragen, Wände) |

### Integration in den Combat ✅
- Q/E/R/F → `InputFrame.ability_slot` → 120-ms-Puffer im `Player` (gleiche Regel wie Angriffe/Dash).
- Ein Skill startet nur, wenn ein Dash-Cancel gerade erlaubt wäre (`combat.can_dash_cancel()`), nicht
  während Dash, Skill-Bewegung, Cast-Lock oder Trefferreaktion; er bricht Light-Angriffe/Aufladung
  ab wie ein Dash.
- Cast-Lock: keine Angriffe/Skills, Bewegung × `cast_move_multiplier`. **Dash beendet den Lock.**
- Skill-Bewegung (`Player.start_skill_motion`, Blade Rush, Shadowstep, Shadow Strike): exakte
  Distanz, Wände/Körper stoppen sie, **keine Dash-Ladung, keine iFrames**. Seit Class Combat Polish 0.3 gibt es
  nur zwei Arten (siehe unten): zielgebundene Gap-Closer und kurze Angriffs-Lunges. Der Dash bleibt
  unverändert (Space, Mausrichtung, 2 Ladungen, 300 ms, 180 ms iFrames) – getestet.
- Skill-Treffer = `HitData` mit `source = SKILL`, über die Hurtbox des Ziels (gleiche HP-, Haltungs-,
  Knockback- und Schadenszahlen-Logik). Stats wirken über `CharacterStatModifier` (Skill Damage %,
  bei physischem Schaden zusätzlich Physical Damage %, Krit, Haltung, Knockback) – genau einmal.
  Item-Modifier (Runen, Uniques) wirken nur auf Waffentreffer (`applies_to_skill_hits = false`).
- Cooldown-Reduktion und Ressourceneffizienz sind auf 50 % gedeckelt.

## Skill-Modifikationen ✅
- Zwei Plätze je Skill: **Form** (Ausführung, Reichweite, Form, Trefferverhalten) und **Resonance**
  (Synergien, Ressource, Status). Pro Platz genau eine Mod.
- Änderungen sind Daten (`SkillModDefinition`):
  - Multiplikatoren für Schaden, Haltung, Radius, Reichweite, Kosten und Cooldown
  - zusätzliche Projektile und Durchschläge
  - Tags, Status, Ressource pro Treffer und Bonus gegen einen Status
  - `extra_actions`
  - `replace_actions` = echte Transformation, z. B. Piercing Lunge
- Kompatibilität: `skill_ids` (passt zum Skill), Slot-Art, Freischaltung, `incompatible_with`
  (z. B. Split Bolt ↔ Double Mark, Piercing Lunge ↔ Rage Refund).
- Freischaltung: Klassenlevel oder `unlock_source` (`talent.*`, `quest.*`, `boss.*`, `explore.*`;
  Talent-Freischaltung über `TalentNodeDefinition.unlocks_mods` ist umgesetzt, Boss-/Erkundungsquellen
  🔧 vorbereitet über `ClassBuild.unlocked_mods`).
- 25 Mods: Warrior 10, Arcanist 9, Shadowrunner 6.
- Slots und Mods ändern sich nur an der Klassenstation (kostenlos). Neue Skills füllen automatisch
  leere Slots.

## Status (Phase A) ✅
`StatusEffectDefinition` (`data/status/`) + `StatusComponent` auf Gegnern und Dummies.
| Status | Wirkung | Regeln |
|---|---|---|
| Bleeding | 3 Schaden/s je Stack, Tick 0,5 s, 4 s | bis 5 Stacks, jede Anwendung erneuert die Dauer; Schaden als `HitData` (Quelle STATUS) über die Hurtbox, dem Spieler zugeordnet |
| Chill | −15 % Bewegung je Stack, 2,5 s | bis 3 Stacks (max. 45 %); nur die eigene Fortbewegung des Gegners, nie `Engine.time_scale`, nie Dash/Spieler |
| Arcane Mark | Markierung | bis 3 Stacks, 6 s |
| Weak Point | Markierung | 1 Stack, 5 s |
| Smoked | −30 % Bewegung | 1 s, von Smoke Veil erneuert |
| Death Mark | Markierung | 8 s |

- Resistenz je Gegner (`EnemyConfig.status_resistances`, 0–1, 1 = immun): verkürzt Dauer und
  schwächt die Stärke. Boss-Grenze `EnemyConfig.max_slow`: Grove Warden 25 % Slow, 50 % Blutungsresistenz.
- Stats: Bleed Chance / Bleed Damage / Chill Chance (Waffentreffer würfeln, Bloodsteel-Prägung
  +15 % Blutung, Frostglas +20 % Chill). Blutung und Kälte werden nicht mehr über Life on Hit bzw.
  Haltung simuliert.
- Visuelles Feedback: Status-Punkte über dem Gegner (Stack-Striche), Kältering, farbige
  Schadenszahlen je Typ (bleed, frost, arcane, shock).

## Angriffsgeschwindigkeit (Phase A) ✅
- `Stats.ATTACK_SPEED` wird zu `CombatComponent.attack_speed = clamp(1 + %/100, 0,75, 1,4)`. Die
  Grenzen stehen in `ProgressionRules`.
- Item-, Talent- und Buff-Beiträge summieren sich im `StatResolver`.
- Der Wert wird beim Angriffsstart übernommen und pro Angriff mit `attack_speed_scaling`
  (Standard 1) skaliert.
- Beschleunigt werden Startup, Active, Recovery und `chain_delay`. Die Lunge wird über die kürzere
  Zeit verteilt (gleiche Distanz). Ansichten nutzen `phase_progress()`, damit Animation, Hitbox und
  Phase synchron bleiben.
- Nicht beschleunigt werden die Heavy-Charge-Stufen, Combo-Fenster, Input-Buffer und Dash.

## Gemeinsame Effekt-Integration (Phase A4) ✅
- `ItemEffectRunner.dispatch_hit` ist der **eine** Ereignisstrom für:
  - Waffentreffer (`hit_landed`)
  - Skill-Treffer
  - Status-Ticks
  - ausgelöste Treffer (Opt-in)
- Effekte wählen ihre Quellen über `ItemEffect.hit_sources` (Standard: nur direkte Waffentreffer;
  alte Item-Effekte verhalten sich unverändert).
- `HitData` kennt:
  - `source`: DIRECT, SKILL, TRIGGERED oder STATUS
  - `depth`: Auslösetiefe
  - `broke_poise` und `killed`: von `HealthComponent` gesetzt
  - einen Status-Snapshot des Ziels vor dem Treffer
- Damit sind Finisher, aufgeladene Heavies, Haltungsbruch, Skill-Treffer, Essenzen, Statusschaden
  und Kills dieselben Ereignisse für Klassen, Talente, Crafting, Trials und Quests.
- Kettenschutz:
  - Treffer werden in eine Warteschlange gestellt; kein Effekt läuft in einem anderen.
  - Ein Treffer wird nie zweimal verteilt.
  - Treffer mit `depth > MAX_TRIGGER_DEPTH (1)` werden verworfen.
- Kills durch Skills oder Status geben Klassen-XP (einmal pro Ziel, keine Waffenbeherrschung).
- Block und Parry existieren noch nicht. Shift (`defensive`) bleibt ohne Funktion (⬜).

## Bewegung: Dash, Gap-Closer, Lunge (Class Combat Polish 0.3) ✅
| Art | Wer | Regeln |
|---|---|---|
| **Universal Dash** | Space, alle Klassen | unverändert: 2 Ladungen, 300 ms, 180 ms iFrames, Richtung = Maus |
| **Attack Lunge** (Waffe) | Light-/Heavy-Combos (`AttackDefinition.lunge_distance`) | unverändert |
| **Attack Lunge** (Skill, `MoveAction`) | Shadow Strike (24 px), Piercing Lunge (36 px) | Teil des Angriffs, Obergrenze `MoveAction.MAX_LUNGE` = 40 px auch mit Mods; der Schlag folgt bei Ankunft |
| **Offensiver Gap-Closer** (`GapCloserAction`) | Shadowstep (130 px, 70°-Kegel), Blade Rush (110 px, 50°) | braucht ein lebendes Ziel im Mauskegel und in Reichweite; Zielpunkt frei vor dem Gegner; freier Weg (Wände **und** Körper, Ziel ausgenommen); sonst Abbruch **vor** Kosten/Cooldown mit Meldung |

- Gap-Closer und Lunges laufen über `Player.start_skill_motion`: exakte Distanz, Kollision über
  `move_and_slide`, keine Dash-Ladung, keine iFrames, kein Teleport.
- `Player.skill_motion_finished(completed)` meldet die Ankunft. Ankunftstreffer und alle folgenden
  Aktionen des Skills (Buff, Phantom-Step-Schlag …) laufen erst dann (`SkillAction.defers_following`).
- Wird die Bewegung unterbrochen (Trefferreaktion, Tod), entfallen sie. Der Ankunftstreffer landet
  nur, wenn man wirklich beim Ziel angekommen ist.
- `SkillAction.cast_error` prüft Bedingungen vor jedem Verbrauch. Erste Nutzerin ist die Zielsuche
  der Gap-Closer.
- Mods: Long Charge und Far Step vergrößern die Zielreichweite. Long Strike verlängert die Lunge
  (gedeckelt).

Geprüft und **unverändert**:
- Arcanist: keine Bewegungsskills.
- Warrior: Furious Strike, Warbreaker, Whirlwind (rotiert am Ort), Battle Cry, Blood Frenzy, Unbound Fury.
- Shadowrunner: Expose Weakness, Execution, Blade Fan, Smoke Veil, Death Mark.

## Feedback: VFX, Audio, Lesbarkeit (Combat Defense & Feedback 0.4) ✅
- `SkillDefinition.fx` (`SkillFxSpec`) beschreibt pro Skill:
  - einen Cast-Effekt am Spieler und einen Treffer-Effekt am Ziel (nur bei akzeptierten Treffern)
  - eine Aura, solange der Buff läuft
  - Cast- und Treffer-Sound
- Effekte sind `CombatFx`-Knoten: prozedural, mit fester Lebensdauer, räumen sich selbst ab. Eine
  Aura endet mit dem Buff, dem Klassenwechsel oder dem Tod.
- Sie verändern nie Hitboxen oder Schaden.

| Klasse | Stil | Beispiele |
|---|---|---|
| Warrior | warm (rot/orange/gold), Wucht | Battle-Cry-, Blood-Frenzy- und Unbound-Fury-Aura, Blade-Rush-Kreuzschlag, Warbreaker-Funken, Sichelhiebe |
| Arcanist | blau/violett, sauber | Glyphen beim Wirken, Stern-Treffer, Splitter-Projektile (Frostbind, Astral Lance), Detonations-Stern + Ring |
| Shadowrunner | dunkel-violett, präzise | Nachbilder entlang Shadowstep/Blade Rush, violette Hiebe, karmesinroter Execution-Kreuzschlag, Messer-Projektile (Blade Fan) |

- **Talent-Effekte:** Worldbreaker, Aftershock und Thousand Cuts mit Ring + Funken. Ruptures
  (Blood Oath) mit Stern.
- **Projektile:** Formen Orb, Splitter, Messer (`ProjectileAction.shape`).
- **Status-Marker nach Form** (`StatusEffectDefinition.marker`):
  - Arcane Mark: eine kreisende Rune pro Stack
  - Weak Point / Death Mark: Fadenkreuz-Klammern
  - Bleeding: Tropfen
  - Chill: kühle Tönung + Kristalle + Ring
  - Smoked: Rauch

  Dazu die Punkt-Zeile über dem Lebensbalken. Marker verschwinden bei Verbrauch, Ablauf (Blinken in
  den letzten 0,4 s) und Tod.
- **Verbrauch einer Markierung:** Stern + Ring in der Status-Farbe und `consume_sound`
  (`arcane_detonate`, `execution`).
- **Poise Break:** Stern, Ring, „BREAK“ und Sound. Normale Treffer zeigen nur Aufblitzen und Zahl.
- **Audio:** `CombatAudio` mit Synth-Platzhaltern, siehe `COMBAT_DEFENSE_FEEDBACK_04_REPORT.md`.
