# Gathering Rework 1.1 – mehrstufiges Sammeln (G halten)

Ergänzt `docs/PROFESSIONS.md`. Status: in Arbeit auf `dev/gathering-rework-11`.

## 1. Audit (Phase 1, Basis `5af5443`)

**Schutz:**
- `project.godot`: fremde, uncommittete Änderung, Hash `68321b98…`.
- Echte Saves und `settings.cfg`: nach jedem Godot-Lauf per Hash geprüft.
- `docs/Design/` und `docs/tasks/` sind untracked und bleiben unberührt.

| Bereich | Bestand |
|---|---|
| Daten | `ResourceNodeDefinition` (`data/world/resource_nodes`, 11 Knoten): `yield_item_id`, `yield_quantity`, `respawn_seconds` (Echtzeit, 0 = einmalig), `look`, `profession_id`, `required_level`, `gather_xp` |
| Regeln | `ResourceGathering.gather`: ein Druck = volle Ausbeute + `ProfessionService.gather_xp` (Level-Band-Anteil), dann Erschöpfung |
| Zustand | `WorldState.map_states[map]["node.<node_id>"]` = Unix-Zeit der Rückkehr oder −1 (dauerhaft); fehlt = verfügbar. Werte nur bool/int/float/String |
| Welt | `ResourceNode` (`Interactable`, Area2D, `player_inside`), Platzhalter-Zeichnung pro `look` in `_draw` |
| Eingabe | G = Aktion `interact` (`project.godot`); `GameMap._unhandled_input` ruft bei der Druck-Flanke `Interactable.find_active(...).interact(hud)` auf, bzw. schließt ein offenes Fenster |
| Spieler | `Player` kennt Aktionen mit Laufzeit (Trinken `begin_use`), Treffer in `_on_hit_received` (nach Block/Parry-Auflösung), Tod, Dash, Skills, Angriffe; UI-Block über `Player.input_blocker` |
| Tests | `test_professions`, `test_hollowwood` nutzen `ResourceGathering.gather`; `test_loop` (breit) nutzt `ResourceNode.gather()` |
| Animationen | keine Sprites oder Werkzeug-Animationen; alles Platzhalter-Zeichnung |

## 2. Integrationsplan

- **Daten:**
  - `ResourceNodeDefinition.steps` (Schrittzahl je Ressourcentyp) und `completion_bonus` (garantierter Abschlussbonus, Teil von `yield_quantity`).
  - `ProfessionDefinition.gather_step_seconds` (Prototyp: Woodcutting 0,75, Mining 0,85, Herbalism 0,65, Skinning 0,90 s).
  - Gesamtbudgets = bestehende `yield_quantity` und `gather_xp`, damit die Erträge erhalten bleiben.
- **Zustand pro Knoteninstanz:**
  - `map_states[map]["gather.<node_id>"]` als JSON-String: Schrittzahl, erledigte Schritte, Material- und XP-Plan je Schritt, vergebene Anteile, Abschlussbonus.
  - Dazu `gather_cycle.<node_id>` (Zähler der Erschöpfungen) als Saat für den einmal festgelegten, deterministischen Plan.
  - Erschöpfung wie bisher über `node.<node_id>`.
  - Kein neues Save-Schema, also keine Versionsänderung. Alte Saves haben keine Teilzustände.
- **Schritt:** `ResourceGathering.complete_step` prüft Level, Verfügbarkeit und Taschenplatz, vergibt die Materialien und XP des Schritts, schreibt den Fortschritt und erschöpft nach dem letzten Schritt – alles in einem Aufruf.
- **Steuerung:**
  - `Player.begin_gather(target)` startet auf der Druck-Flanke (`ResourceNode.interact`).
  - Der Player stept die Aktion mit `InputFrame.interact_held` und bricht bei allen Unterbrechungen ab.
  - Abgeschlossene Schritte bleiben erhalten.
- **Visuell:** Werkzeug-Platzhalter in `PlayerView`, Partikel über `CombatFx`, Beschädigungs-, Fall- und Reststufen in `ResourceNode._draw`.
- **Tests (vorab festgelegt):**
  - neu `test_gathering_steps.gd` (Modell, Budgets, Bonus, atomare Schritte, Save/Load, je ein Knoten der vier Berufe)
  - neu `test_gathering_hold.gd` (G halten, Loslassen, Unterbrechungen, Wiedereinstieg, Reichweite, Block ohne Schaden)
  - angepasst bzw. gezielt ausgeführt: `test_professions`, `test_hollowwood` (nur dort, wo Sammeln betroffen ist), `test_input`
  - `test_loop` und Playtests werden nicht ausgeführt (Teststrategie 1.1).
