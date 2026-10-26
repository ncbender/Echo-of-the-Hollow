# Architektur – Combat Prototype 0.1

## Leitlinien
- **Komposition statt Monolith:** Der `Player` ist nur Kompositionswurzel. Regeln stecken in kleinen
  Komponenten mit expliziten `step(delta, …)`-Methoden → deterministisch testbar.
- **Bewegung und Aktionen getrennt:** Bewegung (`MovementComponent`), Dash (`DashComponent`) und
  Aktionen (`CombatComponent`) sind unabhängige Zustände. Die Kombination entsteht im `Player` über
  zwei Fragen: *„Darf ein Dash die Aktion abbrechen?“* (`can_dash_cancel`) und *„Welchen
  Bewegungsfaktor erlaubt die Aktion?“* (`get_move_multiplier`). Keine State Machine mit allen
  Kombinationen.
- **Daten statt Sonderfälle:** Angriffe, Combos, Charge-Stufen, Waffen, Gegner-Tuning sind Custom
  Resources (`data/`). Der Code enthält keinen einzigen waffen- oder angriffsspezifischen Zweig.
- **Logik ≠ Darstellung:** `*_view.gd`, `HitReactionFx`, `HitstopController`, `CameraShake`,
  `DebugOverlay` lesen nur Zustand bzw. hören Signale. Spiellogik referenziert sie nie.
- **Genau ein Autoload: `GameSession` (`SessionState`)** – hält den `Character`, damit er Szenenwechsel
  überlebt. Systeme bekommen Abhängigkeiten explizit übergeben (ohne Autoload testbar). Sonst nur
  `DebugView.show_hitboxes` (statische Debug-Variable) und der gecachte `GameDatabase.get_default()`.

## Tick-Ablauf (Player, `_physics_process` → `physics_step(frame, delta)`)
```
PlayerInput.poll()  ──►  InputFrame (move, aim, edge flags, heavy_held)
                              │
Player.physics_step:          ▼
  1. aim übernehmen, ggf. Waffenwechsel (nur idle)
  2. DashComponent.step()        – Dauer, iFrames, sequentielle Regeneration
  3. Dash-Buffer (120 ms) → wenn dash.can_dash() && combat.can_dash_cancel():
        combat.cancel("dash")  → Hitbox aus, Combo-Reset, Buffer leer
        dash.try_start(aim_direction)   – immer Blickrichtung (letzte gültige Maus-Richtung)
  4. CombatComponent.step(delta, frame, aim, blocked = dashing)
        Buffer → Charge/Attack starten, Phasen fortschalten, Treffer scannen
  5. Velocity = Dash ODER (Movement × combat.get_move_multiplier() + combat.take_lunge_velocity())
               + knockback.step()   (KnockbackMotion, Distanz in px)
  6. BodyContact.strip_push → move_and_slide()
```
Tests und skriptierte Playtests liefern `InputFrame`s direkt (`Player.feed_input`, oder
`physics_step` manuell mit festem `delta`).

## Komponenten
| Datei | Verantwortung |
|---|---|
| `scripts/player/player_input.gd` | Geräte-Input → `InputFrame`. Klicks werden aus Events gezählt (1 Klick = 1 Flanke, kein Auto-Repeat). |
| `scripts/core/input_frame.gd` | Absicht eines Ticks (Bewegung, Ziel, Flanken, gehaltener RMB). |
| `scripts/core/input_buffer.gd` | Einslotiger Eingabepuffer mit Zeitfenster. |
| `scripts/player/movement_component.gd` (+`MovementConfig`) | Lokomotion, Beschleunigung, Diagonal-Clamping. |
| `scripts/player/dash_component.gd` (+`DashConfig`) | Ladungen, Regeneration, Dauer, iFrames. |
| `scripts/combat/combat_component.gd` | Aktionsschicht: IDLE / CHARGING / ATTACKING mit Phasen STARTUP/ACTIVE/RECOVERY, Chain-Cancel, Dash-Cancel-Regeln, Trefferaufbau, Modifier. |
| `scripts/combat/combo_controller.gd` | Reine Logik: welcher Angriff als nächstes (Folgeknoten, Unlocks, Fenster, Pause). |
| `scripts/combat/attack_definition.gd` | Ein Combo-Knoten (alle Werte, Links, Cancel-Flags, Unlock, Tags). |
| `scripts/combat/charge_profile.gd` | Charge-Schwellen und Multiplikatoren je Stufe. |
| `scripts/combat/weapon_family.gd` | Angriffe + Wurzeln einer Waffenfamilie, Validierung des Combo-Baums. |
| `scripts/combat/attack_hitbox.gd` | Kreissektor-Abfrage direkt im Physics-Space, merkt sich Treffer pro Aktivierung. |
| `scripts/combat/hurtbox.gd` | Empfängt Treffer, Team-Filter, optionale Unverwundbarkeit (Callable). |
| `scripts/combat/hit_data.gd` | Ein aufgelöster Treffer (Schaden, Haltung, Knockback, Hitstop, Tags, Tier). |
| `scripts/combat/health_component.gd` | Leben, Haltung (Poise), Stagger, Tod. |
| `scripts/combat/attack_modifier.gd` | Basisklasse für Item-/Talent-/Mastery-Effekte auf Treffer. |
| `scripts/combat/knockback_motion.gd` | **Einziges Knockback-Modell** (Spieler + Gegner): Distanz in px mit konstanter Verzögerung, über `move_and_slide` (Wände/Körper schlucken den Rest), Debug-Messung. Gegner skalieren mit `EnemyConfig.knockback_taken()`, der Spieler mit dem Reaktions-Multiplikator – genau eine Skalierung. |
| `scripts/enemies/enemy.gd` (+`EnemyConfig`) | KI erzeugt `InputFrame`s für eine eigene `CombatComponent`. |
| `scripts/fx/*`, `*_view.gd`, `scripts/ui/debug_overlay.gd` | Darstellung / Game Feel. |

## Wichtige Entscheidungen
1. **Hitbox als direkte Shape-Abfrage** (`intersect_shape`) statt Area2D-Overlap: keine
   Ein-Frame-Latenz beim Aktivieren, Scan beim Eintritt in ACTIVE (auch sehr kurze Fenster treffen),
   ein Cancel deaktiviert synchron → keine Ghost-Hits.
2. **Ein Feld pro Input für Folgeangriffe** (`next_light`, `next_heavy`) erzwingt Combo-Regel 1
   strukturell. Neue Input-Typen = neues Feld + Enum-Eintrag (bewusst explizit).
3. **Heavy wird beim Charge-Start aufgelöst** (nicht beim Release): Overlay zeigt das Ziel, und der
   Combo-Timer kann sauber pausieren.
4. **Gegner nutzen dieselbe CombatComponent.** Telegraph = Startup-Phase der Angriffsdaten.
   Dadurch gelten Cancel-, Hitbox- und Treffer-Regeln automatisch auch für Gegner.
5. **Hitstop global über `Engine.time_scale`** (Feel-Schicht, Obergrenze 0,15 s). Zählt unskalierte
   Frame-Zeit, damit es mit `--fixed-fps` und echter Zeit gleich funktioniert.
6. **Phasenzeiten mit Epsilon** (1e-5) gegen Float-Akkumulation bei 1/60-Schritten.

## Erweiterungspunkte (vorbereitet, nicht implementiert)
| Zukunft | Ansatzpunkt |
|---|---|
| Weitere Waffenfamilien | Neue `.tres` in `data/weapons/`, in `Player.weapons` eintragen. Kein Code. |
| Freischaltbare Combo-Knoten (Mastery) | `AttackDefinition.unlock_requirement` + `CombatComponent.set_unlocked()`. Demo: `sword_light_4_mastery` (F3). |
| Legendary/Unique-Combo-Modifikatoren | `AttackModifier` (`applies_to`, `modify_hit`) in `CombatComponent.modifiers`. |
| Klassenabhängige Angriffseffekte | `effect_tags` am Angriff + `hit_landed`/`attack_started`-Signale; Klasse hängt Modifier/Listener an. |
| Talent-/Item-Trefferereignisse | Signale `hit_landed(HitData)`, `attack_started`, `attack_finished`, `attack_cancelled`, `charge_tier_changed`. `HitData.attack_instance_id` gruppiert Treffer eines Schwungs. |
| Defensiver Slot / Skills | Input-Actions `defensive`, `ability_1..4` existieren; neue Aktion = eigene Komponente, die sich wie der Dash über `can_dash_cancel`-artige Abfragen einklinkt. |

## RPG-Schicht (Overnight 2)
```
 data/ (Resources)            GameDatabase (Registry, Validierung)
   weapons, mastery, classes,        │
   items, sets, world, base          ▼
                              Character (RefCounted, speicherbar)
                               ├─ CharacterClasses   (Level/XP je Klasse, aktive Klasse)
                               ├─ WeaponMastery      (Level/XP je Waffenfamilie, geteilt)
                               ├─ Inventory          (ItemInstances, einziger Speicherort)
                               ├─ CharacterEquipment (Loadout je Klasse = Instanz-IDs)
                               ├─ WorldState         (Map, Spawn, Flags, Gebäude)
                               └─ get_stats()        (StatResolver, immer neu berechnet)
                                     ▲  to_dict / from_dict  ▼
                              SaveSystem (Umschlag, Prüfsumme, .tmp/.bak, Migrationen)

 Szene: GameMap ── bindet ──► Player ◄── PlayerProgressionBridge ──► Character
                                          ├─ CombatRewardTracker (XP aus hit_landed)
                                          ├─ CharacterStatModifier (Stats → AttackModifier)
                                          ├─ ItemEffectRunner (Legendary/Unique/Set, 1 Verbindung)
                                          ├─ Waffe = Familie der Hauptwaffe
                                          └─ ClassResourcePool (Wut …)
```
- **Einzige Brücke** Combat↔RPG: `PlayerProgressionBridge`. Alle Verbindungen zum langlebigen
  `Character` werden verfolgt und in `unbind()` getrennt (keine Doppelregistrierung beim Neuladen).
- Items wirken über den **bestehenden** `AttackModifier`-Hook (neu: `modify_reach`); keine parallele
  Schadenslogik, Basisdaten (`AttackDefinition`) werden nie verändert.
- `Character`-Teilsysteme verbinden Signale über Methoden-Callables (keine Lambdas mit `self`), damit
  keine RefCounted-Zyklen entstehen (Leck in der Startprüfung gefunden und behoben).
- Neue Combat-Bausteine aus Phase 1: `HitReactionComponent` (+Config), `BodyContact`, lokaler Hitstop
  (`apply_hitstop` an Player/Enemy).
- Details: `PROGRESSION_SYSTEM.md`, `CLASS_DESIGN.md`, `TALENT_SYSTEM.md`, `SKILL_SYSTEM.md`, `CLASS_QUESTS.md`, `ITEM_SYSTEM.md`, `EQUIPMENT_SYSTEM.md`,
  `SAVE_SYSTEM.md`.

## Welt-Schicht (Overnight 3)
- `GameMap` = Basisskript jeder Map; `SessionState.travel()` = einzige Übergangs-API (mit Fade,
  Doppelanfragen-Schutz). Kein zusätzlicher Manager; der Character bleibt ein einziges Objekt im Autoload.
- Weltzustand ausschließlich in `WorldState` (Flags, Mapzustände, Gebäude) → automatisch gespeichert.
- Basisbau-Regeln zustandslos in `BaseBuilder`, Sammelregeln in `ResourceGathering` (Zeit injiziert).
- Interaktion: alles „mit G Benutzbare“ erbt von `Interactable` (Klassenstation, Bauplatz, Ressourcenknoten,
  Schalter).
- Details: `WORLD_SYSTEM.md`.

## Display- & UI-Schicht (UI Foundation 0.1, Details `DISPLAY_AND_UI_STANDARD.md`)
- Designfläche 1920×1080, `canvas_items`/`keep`; UI-Skalierung = `Window.content_scale_factor`
  aus `UserSettings` (gehalten von `GameSession.settings`, Datei `user://settings.cfg`, nie im Save).
- `CameraShake` teilt `base_zoom` (3,75) durch den UI-Faktor → Weltausschnitt konstant 512×288.
- `UiTheme`: einzige Quelle für Schriftgrößen, Farben, Styles, Layout-Konstanten (Design-Px).
- `UiWindow`: Basis aller RPG-Fenster (Einpassen in die sichtbare Fläche, Scrollen, Zentrieren);
  `GameHud` registriert Fenster, `OptionsPanel` (O) editiert `UserSettings`.
- `WorldText`: scharfe Texte in der gezoomten Welt. Keine `Control.scale`-Skalierung für UI.

## Crafting-Schicht (Crafting Foundation 0.1, Details `CRAFTING_DESIGN.md`)
- **Definitionen** (`scripts/rpg/crafting/`, Daten `data/crafting/`): Material, Affix/Tier, Essenz,
  Resonanz, Einlage, Währung, Operation, Evolution (Stufe/Mutation). `ItemDefinition.crafting`
  (`CraftingProfile`) legt fest, welche Operationen ein Item erlaubt. Alles ist in `GameDatabase`
  registriert und gegenseitig validiert.
- **Instanzdaten** auf `ItemInstance`: Level, Qualität, Material, Affixe, Essenzen, Sockel,
  Evolution, Revision.
- **`ItemStats`**: einzige Umrechnung von Crafting-Zustand in StatModifier (→ `StatResolver` über
  `Character._stat_sources`) und ItemEffects (→ `ItemEffectRunner.rebuild`). Keine zweite
  Stat- oder Effektlogik.
- **`AffixPool`**: gewichteter Pool, den Vorschau und Würfeln gemeinsam nutzen.
  **`CraftingService`**: zustandslose Transaktionen über `CraftingRequest` → `CraftingPreview`
  → `Result`, Tabellen je Operation.
  **`ItemEvolution`**: Item-EP, von der Bridge bei akzeptierten Treffern vergeben.
- **Combat-Anbindung** nur über vorhandene Wege:
  - Neue Stats laufen über `CharacterStatModifier`, also den AttackModifier-Hook.
  - Essenzen, Runen und Mutationen sind `ItemEffect`s; ihre Modifier laufen über
    `get_attack_modifiers_for(runner, key)` (mit Weak-Ref auf den Runner, ohne Zyklus).
  - Der Runner verwaltet Markierungen, geteilten Effektzustand und Stats.
  - Knockback läuft über `KnockbackMotion` und wird genau einmal skaliert.
- **UI**: `CraftingPanel` (`UiWindow`) an der Schmiede (`BuildingDefinition.crafting_station`).

## Kollisionslayer
1 `world` (Wände, Dummies) · 2 `player` · 3 `enemy` · 4 `hurtbox` (nur Abfragen, kein Monitoring).
Player-Körper kollidiert mit `world` + `enemy`; Gegner mit `world`, `player`, `enemy`. Interactables
und Pickups überwachen nur `player`.

## Klassen-Schicht (Class Foundation 0.2, Details `CLASS_DESIGN.md`, `TALENT_SYSTEM.md`, `SKILL_SYSTEM.md`, `CLASS_QUESTS.md`)
```
 data/classes, talents, skills, skill_mods, status, trials, quests  ──►  GameDatabase (+ TalentService.validate_data)
 Character
  ├─ CharacterClasses   aktive Klasse, Level/XP; trial_class_id (temporär, nie gespeichert)
  ├─ ClassBuilds        ClassBuild je Klasse: Talente, Slots, Mods, Freischaltungen, Presets (+ Trial-Build)
  ├─ PrologueState      Trials, Wahl     ├─ QuestLog   Klassenquests
  └─ _runtime_modifiers Buff-Statquellen (nicht gespeichert)
 PlayerProgressionBridge
  ├─ ClassRuntime       Ressource, Cooldowns, Buffs, Pressure; Player.ability_handler = try_cast
  ├─ ItemEffectRunner   Item- + Talent- + Klassen-Effekte; dispatch_hit = einziger Trefferstrom
  └─ apply_status       Status auf Gegnern, dem Spieler gutgeschrieben
```
- Regeln stehen zentral und zustandslos in `TalentService`, `SkillBook`, `PresetService`,
  `PrologueService` und `QuestService`. Die UI ruft nur diese Dienste auf.
- Der Player kennt keine Klassen. Er bietet generische Hooks:
  - `ability_handler` (Q/E/R/F mit Puffer)
  - `can_start_skill`, also dieselbe Cancel-Regel wie der Dash
  - `begin_skill` für den Cast-Lock
  - `start_skill_motion`, eine exakte Distanz, kein Dash
- Generische Combat-Bausteine: `StatusComponent`, `StatusEffectDefinition`, `SkillProjectile` und
  `SkillZone`. `CombatComponent.attack_speed` beschleunigt die Phasen.
- `HitData` trägt jetzt:
  - `source` und `depth` (Kettenschutz)
  - `broke_poise` und `killed`
  - einen Status-Snapshot des Ziels
- `ItemEffect.hit_sources` filtert pro Effekt, welche Treffer ihn erreichen.
- Eine Trial schaltet die Klasse über die Getter-Eigenschaft `active_class_id` um. Alle Systeme
  sehen dadurch automatisch die Trial-Klasse, `to_dict` schreibt aber immer die echte Klasse.

## Verteidigung, Feedback, Audio (Combat Defense & Feedback 0.4)
- **`DefenseComponent`** (Combat-Schicht, vom Player in `_ready` erzeugt) plus **`DefenseProfile`** (Daten):
  - Das Profil kommt von `WeaponFamily.defense_profile`; ein Schild überschreibt es
    (`ItemDefinition.defense_profile`, von der Bridge gesetzt).
  - `Hurtbox.hit_filter` löst Block/Parry auf, **bevor** Schaden, Zahlen, Reaktion oder Ressourcen
    den Treffer sehen.
  - `AttackDefinition.defense_flags` legt Blockable, Parryable und Guard Breaking fest.
  - Gegner reagieren über `Enemy.on_parried` und `EnemyConfig.parry_*`.
  - Der Counter ist ein `AttackModifier` (`DefenseComponent.CounterModifier`), nur für direkte
    Waffentreffer.
- **`CombatFx`** (`scripts/fx/`): prozedurale Einmal-Effekte.
  - Die Spiellogik ruft nur `CombatFx.spawn(...)`.
  - Daten: `SkillFxSpec` und `StatusEffectDefinition.marker`.
  - Feedback des Combat-Layers (Player, EnemyView) hängt an vorhandenen Signalen: `parried`,
    `blocked`, `guard_broken`, `poise_broken`.
- **`CombatAudio`** (`scripts/audio/`):
  - ein Node pro Map, erzeugt von `GameMap`, freigegeben mit der Map
  - aufgerufen über `CombatAudio.play(near, cue)`
  - Stimmen-Pool, Drossel, Bus „SFX“
  - Lautstärke aus `UserSettings.sfx_volume`
- **`SynthSounds`:** Platzhalter-Klänge zur Laufzeit; echte Dateien über `CombatAudio.files`.
- **Kein zweites Autoload:** Audio ist an die Map gebunden, Effekte an den Szenenbaum.
