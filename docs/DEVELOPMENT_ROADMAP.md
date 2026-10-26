# Development Roadmap

## Meilenstein 0.1 – Combat Prototype (aktuell)
| Phase | Inhalt | Status → siehe `OVERNIGHT_REPORT.md` |
|---|---|---|
| A | Projekt, Testarena, Doku, Git, Testrunner | ✅ abgeschlossen |
| B | Player, WASD, Mausziel, Kamera, Kollision, Dash (2 Ladungen) | ✅ abgeschlossen |
| C | AttackDefinition, Light/Heavy, Charge, Phasen, Combo-Baum, Buffer, Cancels | ✅ abgeschlossen |
| D | Einhandschwert, Trainingspuppe, Schaden/HP, Feedback, Debug-Overlay | ✅ abgeschlossen |
| E (optional) | Zweihandschwert, Waffenwechsel | ✅ abgeschlossen |
| F (optional) | Einfacher Nahkampfgegner, Telegraph, Tod, Debug-Spawn | ✅ abgeschlossen |

## Overnight 2 – Stabilisierung & RPG-Fundament
| Phase | Inhalt | Status (Details: `OVERNIGHT_REPORT_02.md`) |
|---|---|---|
| 1 | Kollision, lokaler Hitstop, Trefferreaktionen | ✅ |
| 2 | Waffenbeherrschung | ✅ |
| 3 | Klassen (Basic Adventurer, Warrior) | ✅ |
| 4 | Items & Inventar | ✅ |
| 5 | Equipment & Klassen-Loadouts | ✅ |
| 6 | Legendary/Unique/Set | ✅ |
| 7 | Save/Load | ✅ |
| 8 (optional) | Maps & Regionen | siehe Report |
| 9 (optional) | Basisbau | siehe Report |

## Danach (Vorschlag, nicht begonnen)
- **0.2 Combat Feel:** echte Sprite-Animationen statt Platzhalter, Animationsdaten an Attack-Phasen
  koppeln, Sound-Hooks, Feintuning mit menschlichem Playtest.
- **0.3 Defensive & Fähigkeiten:** Shift-Slot (Parry/Block pro Klasse), Q/E/R/F-Skill-Slots mit
  Cooldowns, erste Klasse.
- **0.4 Gegner-Grundlagen:** mehrere Gegnertypen, Gruppen-KI, Elite-Modifikatoren.
- **0.5 Progression-Hooks:** Waffenbeherrschung (schaltet Combo-Knoten frei), erste Unique-Modifier
  über `AttackModifier`.
- Später: Map-Übergänge, Heimatbasis, Crafting, NPCs, Dungeons, Bosse.
