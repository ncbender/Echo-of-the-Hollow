# UI Layout Lock 1.0 – UI-Paket 1: HUD Layout

Auf dem uncommitteten Stand (A/B/C, Talent-Fix, Gameplay Polish). Keine Save-, Zoom-, `project.godot`- oder Gameplay-Änderung.
Grundlage: UI-Audit „UI Layout Lock 1.0“.

> **Ersetzt durch Combat HUD UX 2.0 (`COMBAT_HUD_UX_2_0.md`):** Oben links steht nur noch die `EffectBar` (Trank- und
> Klassen-Buffs). HP und Klassenressource sind Gefäße links und rechts der Kampfleiste, Level und Pressure stehen als
> Abzeichen in der EXP-Zeile, Dash unter der Spielfigur. Die Menüleiste ist 7 × 34 px mit Abstand 2 und Rand 4
> (≈ 256 × 42). Der Tracker heißt „Journey“: Kopfzeile, eingeklappt nur diese; ohne Kurzfassung der Hauptquest
> und ohne Tastenhinweise. Die Tabelle unten ist der Stand von 1.0.

## HUD-Zonen (`GameHud`, Design-px, Anker)
| Zone | Inhalt | Anker / Maß |
|---|---|---|
| oben links | `PlayerFrame` (Breite 360), darunter `EffectBar` | `LeftColumn`, TOP_LEFT (16, 16) |
| oben Mitte | `TargetFrame` (420, Boss 640), darunter Tutorial-Hinweis | CENTER_TOP; Breite ≤ Canvas − 2 × Seitenreserve (`TargetFrame.side_reserve`) |
| oben rechts | `MinimapFrame` (Platzhalter „Map unavailable“), darunter `QuestTracker` (340) | `RightColumn`, TOP_RIGHT (−356, 16) |
| unten links | `MenuBar` – genau eine Icon-Leiste, 7 × 40 px, Abstand 4 (≈ 324 × 60) | BOTTOM_LEFT (16, −16) |
| unten Mitte | Toasts, Aufladung, Interaktionshinweis, `CombatBar` = `QuickUse` (1 2) + 18 px + `SkillBar` (Q E R F), Slots 64 × 64 (≈ 426 × 64), darunter (6 px) der EXP-Balken 426 × 14 (`docs/HUD_EXP_BAR_1_0.md`) | CENTER_BOTTOM, unten −16 |
| unten rechts | eine Spalte: `SaveIndicator` unten, darüber (Abstand GAP 6) `LootFeed` (340) | BOTTOM_RIGHT; Speicherstatus-Platz = gemessene Höhe (`SaveIndicator.slot_height`, 46 px), immer reserviert; Feed-Unterkante = `GameHud.feed_bottom` (16 + 46 + 6 = 68) |

Responsiv (`GameHud._layout_bottom`): kurzer Canvas (< 800 px hoch, d. h. 150 %) → Minimap-Fläche 168 statt 200, Loot-Feed
3 statt 5 Zeilen (Zeile = 54 px), Hauptquest im Tracker auf 3 Zeilen gekürzt (Volltext im Tooltip). Trackerhöhe ≤ Oberkante
des Feed-Bereichs; darüber scrollt der Tracker. Während eines Dialogs treten Kampfleiste, Toasts/Hinweis und Menüleiste zurück.

Gemessene Canvasgrößen (identisch bei 1080p, 1440p, 4K): 100 % 1920 × 1080 · 125 % 1536 × 864 · 150 % 1280 × 720.

| UI | Boss | Minimap | Tracker | Feed | Kampfleiste | Menü |
|---|---|---|---|---|---|---|
| 100 % | 640 @ x 640 | 200 @ (1704, 16) | y 224, h 329 | y 874 | x 747–1173 | x 16–340 |
| 125 % | 640 @ x 448 | 200 @ (1320, 16) | y 224, h ≤ 316 | y 658 | x 555–981 | x 16–340 |
| 150 % | 512 @ x 384 | 168 @ (1096, 16) | y 192, h ≤ 312 | y 514 | x 427–853 | x 16–340 |

## Menüleiste und Tasten
| Icon | Ansicht | Taste |
|---|---|---|
| Inventory | `InventoryPanel`, Seite Equipment | I |
| Character | `InventoryPanel`, Seite Overview (Details zählt mit) | C |
| Skills & Talents | `ClassStationPanel`, Seite Talents | T (neu, Laufzeit-Action `ui_talents`) |
| Professions | `ProfessionsPanel` | P |
| Journal | `JournalPanel` | J |
| Map | `WorldMapPanel` | M |
| Settings | `OptionsPanel` | O |

Klick = Taste (`GameHud.open_menu`), erneut = schließen, Inventory ↔ Character wechselt die Seite. Ein Fenster zur Zeit,
Esc wie bisher. Tooltip „Name [Taste]“ aus der InputMap (`OptionsPanel.binding_text`). Icons ohne Tastaturfokus, aktives
Icon hervorgehoben. `toggle_character()` öffnet jetzt die Charakterübersicht; die Talente öffnet `toggle_talents()`.

## Maus und Kampf
`PlayerInput`: gehaltene LMB/RMB zählen nur, wenn der Druck auf dem Spielfeld begann (`_unhandled_input`); HUD-Buttons und
Slots (`MOUSE_FILTER_STOP`) nehmen Klicks ab. Beim Beginn einer Fenstersperre setzt `Player.apply_input_block` die
gehaltenen Tasten zurück (`PlayerInput.release_holds`).

## Kampfleiste
`HudSlot`: prozedurale Übergangsglyphe (Skill: Buchstabe in Skillfarbe; Flasche; Trank), Taste, Cooldown-Abdunkelung, kurzes
Statuswort („No Rage“, „2.1s“, „Empty“, „2/2“, „None“). Name, Beschreibung, Kosten, Cooldown im Tooltip.

## Questtracker
Hauptquest (Name, Ziel, Zähler), max. 3 einzeilige Nebenquests (Tooltip = voller Schritttext), „+N more (J)“, offene Rewards
in festem Bereich unter dem Scrollteil (nie weggescrollt), Klassenquests. „-“/„+“ minimiert (nur Titel + offene Rewards;
reiner Anzeigezustand dieser Sitzung, `ObjectivePanel.collapsed`, nicht gespeichert).

## Offen
- UI-Paket 2: Minimap-Rendering, Fog of War, Gebietskarte, Marker (Platzhalter `MinimapFrame` reserviert).
- UI-Paket 3: echte Icons/Rahmen (Glyphen sind Platzhalter), Journal-Kategorien, Abgleich `DISPLAY_AND_UI_STANDARD.md`.
- Minimiert-Zustand wird nicht über Neustarts gespeichert (wäre eine `UserSettings`-Erweiterung).

## Tests
`test_ui_layout_lock` (6). Angepasst: `test_hud` (Statuswort statt Text), `test_class_ui`/`test_armor_mastery` und Playtest
`gallery_screens` (`toggle_talents`), `test_class_trials_m3`/`test_quest_turnin_mara_ui` (`ObjectivePanel.full_text()`),
`test_gameplay_polish` (Tracker endet über dem Feed-Bereich).

## HUD Notification Collision Fix 1.0

Ursache der Überlappung (14 px): Der Speicherstatus war mit fest 26 px Höhe eingeplant (`offset_top = −16 − 26`),
die Feed-Unterkante fest bei −48. Das HudPanel um eine Textzeile ist aber 46 px hoch (2 × 10 px Innenabstand + Zeile);
der PanelContainer wuchs nach oben (GROW_BEGIN) bis −62 in die unterste Feed-Zeile - bei jeder Auflösung und Skalierung
(Design-px). Korrektur: Die rechte untere Ecke ist eine Spalte. `GameHud._layout_bottom` misst den Platz des
Speicherstatus (`SaveIndicator.slot_height`, eine Zeile, unabhängig vom Text und davon, ob er gezeigt wird) und setzt
Speicherstatus-Oberkante und `feed_bottom` daraus; der Platz bleibt immer reserviert, also springt nichts, wenn Loot
kommt, verblasst oder der Hinweis erscheint/verschwindet. Test: `test_hud_notifications` (sichtbare Rechtecke disjunkt,
≥ GAP Abstand, keine Bewegung; 75–150 %, geöffnetes Fenster); Galerie-Ansicht `hud_notifications`.
