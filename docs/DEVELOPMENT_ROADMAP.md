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
| 8 | Regionen & Maps (Overnight 3) | ✅ |
| 9 | Basisbau mit festen Bauplätzen (Overnight 3) | ✅ |
| 10 | Erster integrierter Gameplay-Loop (Overnight 3) | ✅ |

## Seitdem umgesetzt
| Meilenstein | Inhalt | Bericht |
|---|---|---|
| Combat Polish 0.2 | Dash zur Maus, distanzbasierter Knockback, Gegnerresistenz, exakter Lunge | `COMBAT_POLISH_02_REPORT.md` |
| UI Foundation 0.1 | 1920×1080-Design, 4K, UI-Skalierung, Theme, responsive Fenster | `UI_FOUNDATION_01_REPORT.md` |
| Crafting Foundation 0.1 | Resonanzschmieden A–G: Material, Affixe, Operationen, Essenzen, Sockel, Qualität, Evolution, Forge-UI | `CRAFTING_FOUNDATION_01_REPORT.md` |
| Class Foundation 0.2 | Attack Speed, Bleeding/Chill, gemeinsamer Trefferstrom; Talent-Engine (7 Tiers), Skills Q/E/R/F mit Form-/Resonance-Mods; Warrior, Arcanist, Shadowrunner; Prolog mit Trials und Klassenwahl; Klassenquests; Presets; Klassenstation-UI; Save v4 | `CLASS_FOUNDATION_02_REPORT.md` |
| Class Combat Polish 0.3 | Focus passiv, zielgebundene Gap-Closer, Skill-Lunges gedeckelt | `CLASS_COMBAT_POLISH_03_REPORT.md` |
| Combat Defense & Feedback 0.4 | Focus 6/s, Block & Parry (Shift, Profile, Unblockable/Guard Break), Skill-VFX, Synth-Combat-Audio, Status-/Poise-Lesbarkeit | `COMBAT_DEFENSE_FEEDBACK_04_REPORT.md` |

## Danach (Vorschlag, nicht begonnen)
- **Crafting 0.2:** Loot-Generator mit Affixen (Gleichwertigkeit Loot ↔ Crafting), Essenz-Drops von
  Monstern, Balance nach menschlichem Playtest, VFX/SFX für Entladung und Resonanz, Respec-Regeln.
- **0.2 Combat Feel:** echte Sprite-Animationen statt Platzhalter, Animationsdaten an Attack-Phasen
  koppeln, Sound-Hooks, Feintuning mit menschlichem Playtest.
- **Klassen/Combat danach:**
  - menschlicher Playtest von Block/Parry und des Skill-Feedbacks
  - echte Audio- und VFX-Assets statt der Synth- und Prozedural-Platzhalter
  - Parry-Talente, restliche Skills (8 pro Klasse)
  - Guardian (Eide) und Soulbinder (Echos)
  - Questgebiete/NPCs, Mod-Quellen aus Bossen und Erkundung, Forge-UI-Überarbeitung
- **Gegner-Grundlagen:** mehrere Gegnertypen, Gruppen-KI, Elite-Modifikatoren, mehr
  parier-/blockbare Angriffsmuster.
- **0.5 Progression-Hooks:** Waffenbeherrschung (schaltet Combo-Knoten frei), erste Unique-Modifier
  über `AttackModifier`.
- Später: NPCs, Dungeons, Bosse (Map-Übergänge, Heimatbasis und Crafting-Grundlage existieren).
