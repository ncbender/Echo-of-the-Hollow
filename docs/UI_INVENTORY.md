# UI-Inventur (Stand vor UI/UX Redesign 1.0, Branch-Basis `94a4c41`)

Legende: ✅ vorhanden · 🟡 rudimentär · ⬜ existiert nicht (Gameplay fehlt) · 🛠 nur Debug

| Bereich | Stand | Umsetzung (Datei) | Bemerkung |
|---|---|---|---|
| Title / New Game | ✅ | `ui/title_screen.gd` | Continue, New Game (2 Klicks), Load, Options, Quit. Kein Charakter-Select: ein Charakter pro neuer Reise, kein Gameplay dafür |
| Continue / Save / Load | ✅ | `title_screen.gd`, `pause_menu.gd` | 5 manuelle Slots, 3 Autosaves, Slotinfo |
| Pause | ✅ | `pause_menu.gd` | Resume, Save, Load, Options, Quit to Title |
| Settings | ✅ | `options_panel.gd` | UI-Skalierung, Fenster, Effektlautstärke, Autosave, Speicheranzeige |
| Controls / Keybindings | 🟡 | Debug-Overlay-Hilfetext | keine Steuerungsübersicht im Menü, kein Umbelegen |
| HUD Health | 🛠 | nur `debug_overlay` (Text) und Spielfigur | keine reguläre Lebensleiste |
| Class Resource / XP | ✅ | `class_info_panel.gd` | Text + dünne Balken |
| Dash Charges | 🛠 | Debug-Overlay | – |
| Skills Q/E/R/F + Cooldowns | ✅ | `skill_bar.gd` | Textkacheln |
| Heavy Charge | ✅ (Welt) | `player_view.gd` | Ladering an der Figur |
| Defense / Parry / Counter | 🟡 | `class_info_panel.gd` (Text „COUNTER!“), Welt-FX | – |
| Enemy-Leisten | 🟡 | `enemy_view.gd` (HP-Balken über Gegner) | kein Name, keine Poise, keine Elite-/Bossleiste |
| Statuseffekte | 🟡 | Welt-Marker (`status_component`/FX) | keine HUD-Anzeige für den Spieler |
| Quest Tracker | ✅ | `objective_panel.gd` („Journey“) | Trial-Ziele, Story, Klassenquests |
| Tutorials / Prompts | ✅ | `game_hud.gd` (Hint-Panel, „[G] …“) | – |
| Inventory | ✅ | `inventory_panel.gd` | Textraster, keine Kategorien, keine Sortierung, kein Vergleich |
| Character / Equipment | 🟡 | `inventory_panel.gd` | 15 Slots als Liste, Stats-Text |
| Item Details / Tooltip | 🟡 | `inventory_panel._item_lines` | ohne Crafting-Zustand (Material, Essenzen, Sockel, Qualität, Evolution) |
| Classes / Talents / Skills / Presets / Class Quests | ✅ | `class_station_panel.gd`, `talent_tree_view.gd` | funktional, dicht |
| Resonance Forge | ✅ | `crafting_panel.gd` | 3 Spalten, alle Operationen in einer Leiste |
| Smithy-Rezepte / Gebäude | ✅ | `build_panel.gd` | „Smithy recipes“, Lagerinfo |
| Storage (Lager-UI) | ⬜ | – | Old Storehouse gibt nur +10 Plätze; kein Lagergameplay |
| Merchant / Trading | ⬜ | – | kein Händlergameplay |
| Haven Restoration | ✅ | `restoration_panel.gd` | Kosten, Restore, „unavailable“ |
| Dialogue / Choice | ✅ | `dialogue_panel.gd`, `class_choice_panel.gd` | keine Antwortauswahl (Dialoge sind linear) |
| Quest Journal | ⬜ | – | nur Tracker im HUD |
| World Map | ⬜ | – | Navigation nur über Ausgänge und Wegsteine |
| Waystone Travel | ✅ | `waystone_panel.gd` | – |
| Loot Notifications | 🟡 | `toast_feed.gd` („Picked up …“) | reine Textzeilen |
| Memory Fragments | ✅ | `readable.gd` → Dialogfenster | – |
| Death / Respawn | ⬜ | – | Spieler respawnt nach 1,5 s ohne Anzeige |
| Save Indicator | ✅ | `save_indicator.gd` | – |
| Debug UI | 🛠 | `debug_overlay` (Status + Tastenhilfe) | immer sichtbar, nicht vom Spiel getrennt |
| Welttexte | ✅ | `WorldText` | Namen an NPCs/Ruinen/Stationen, Schadenszahlen |

**Gameplay, das fehlt und vom Redesign nicht erfunden wird:**
- Charakterauswahl
- Händler
- Lager-Inventar
- Antwortauswahl in Dialogen
- Umbelegen von Tasten
- Verkaufen von Items
- Tränke benutzen
- echte Weltkarte mit Gelände
- Revitalisierung der Ruinen
