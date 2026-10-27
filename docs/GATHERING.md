# Gathering Rework 1.1 – mehrstufiges Sammeln (G halten)

Ergänzt `docs/PROFESSIONS.md`. Status: umgesetzt auf `dev/gathering-rework-11` (Bericht `GATHERING_REWORK_11_REPORT.md`).

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

## 3. Umsetzung

### Daten (Prototypwerte)
| Beruf | Sekunden pro Schritt (`ProfessionDefinition.gather_step_seconds`) | Knoten: Schritte (`steps`) |
|---|---:|---|
| Woodcutting | 0,75 | Oak Tree 3, Old Oak 4 |
| Mining | 0,85 | Forest Rock 3, Iron Vein 4, Rich Iron Vein 5, Ancient Deposit 5 |
| Herbalism | 0,65 | Duskleaf Patch 1, Wild Flax 2, Duskleaf Cluster 3 |
| Skinning | 0,90 | Stag Remains 2, Elk Remains 3 |

- **Gesamtbudgets:** unverändert die bisherigen `yield_quantity` und `gather_xp`. Ein Knoten liefert also über alle Schritte genau den alten Gesamtertrag.
- **XP:** XP-Budget = `gather_xp` × Level-Band-Anteil (wie bisher), festgelegt beim Planen des Zyklus.
- **Abschlussbonus:** `completion_bonus` = 1 Einheit des Hauptmaterials auf dem letzten Schritt, Teil des Budgets.
- **Schrittzahl:** Einfache bzw. Level-1-Vorkommen liegen am unteren Rand der Spanne, reiche bzw. Level-3-Vorkommen am oberen.

### Plan und Zustand (`ResourceGathering`)
**Plan** (`make_plan`), einmal pro Zyklus festgelegt:
- Der Bonus geht auf den letzten Schritt, das übrige Material wird zufällig auf die Schritte verteilt; ein Schritt darf 0 ergeben.
- XP werden gleichmäßig verteilt, der Rest geht auf die letzten Schritte.
- Saat = Map, Knoten und `gather_cycle.<node_id>`. Unterbrechen, Laden oder erneutes Interagieren würfelt deshalb nie neu; erst der nächste Zyklus nach dem Respawn bekommt einen neuen Plan.

**Zustand pro Instanz:** `map_states[map]["gather.<node_id>"]` als JSON-String mit `steps`, `done`, `item`, `items[]`, `xp[]`, `bonus`, `given_items`, `given_xp`. Daraus ergibt sich das Restbudget (`remaining_items`).
- Beim Lesen wird geprüft: Länge, Wertebereich und Summen (`given_*` = Summe der erledigten Schritte).
- Unlesbare oder widersprüchliche Zustände geben nie eine Belohnung; der Knoten gilt dann als erschöpft und respawnt normal.

**`complete_step` als eine Transaktion:**
1. Prüfung: Level, Verfügbarkeit, Platz in der Tasche für das Material dieses Schritts.
2. Danach geschieht alles ohne Abbruchmöglichkeit: Material in die Tasche, Fortschritt schreiben, XP vergeben.
3. Nach dem letzten Schritt: Erschöpfung (`node.<node_id>` wie bisher, Echtzeit-Respawn bzw. dauerhaft), Teilzustand löschen, Zyklus +1.

Eine Ablehnung ändert nichts. `gather()` erntet alle restlichen Schritte am Stück und ist nur für Tests und Simulationen gedacht (gleiche Summen).

### Steuerung (`Player`)
- `ResourceNode.interact` startet bei der G-**Druck**-Flanke (`GameMap`) `Player.begin_gather(node)`, aber nur aus dem neutralen Zustand (wie Skills) und wenn der Knoten bearbeitbar ist.
- `_step_gather` zählt die Schrittzeit, solange `InputFrame.interact_held` gilt. Nach jedem vollen Schritt ruft es `complete_step` auf; bei Erschöpfung oder Ablehnung endet die Aktion.
- Gehaltenes G startet nie einen neuen Knoten; nach jeder Unterbrechung braucht es einen neuen Druck.

**Unterbrechungen** (`gather_stopped(reason)`), jeweils sofort; der angefangene Schritt gibt nichts, erledigte Schritte bleiben:
- G losgelassen, WASD, Dash, Angriff (L/H), Skill-Taste, Tasten 1/2 (Trinken), Shift (Block/Parry)
- echter HP-Verlust, Reaktion ab INTERRUPT (Stun), Knockback, Tod
- offenes Fenster oder Pausemenü (`apply_input_block`)
- Verlassen der Knoten-Area

Ein Treffer ohne HP-Verlust (z. B. pariert) unterbricht nicht.

Final Integration: Tasten 1/2 und Shift unterbrechen das Sammeln ebenfalls (`GATHER_DRINK`, `GATHER_DEFEND`).
Danach starten Trank bzw. Block/Parry im selben Tick unter ihren unveränderten Regeln. Sammeln läuft nie
gleichzeitig mit Trinken, Block oder Parry (Start nur aus dem neutralen Zustand). Ein angearbeiteter Knoten
bleibt dauerhaft angearbeitet; die bestehende Nachwachszeit beginnt erst bei der Erschöpfung. Die
Datenbank-Validierung prüft `steps >= 1` und `0 <= completion_bonus <= yield_quantity`. Gehaltenes G löst keine
weiteren Interaktionen aus, weil die Map nur Druck-Ereignisse ohne Echo auswertet.

### Visuell – nur Platzhalter (keine Sprites oder Animationen vorhanden)
- `PlayerView._draw_gather_tool`: rein visuelles Werkzeug je Beruf – Axt, Spitzhacke, Sichel, Häutemesser. Es wird über 70 % des Schritts ausgeholt und in den letzten 30 % zugeschlagen. Kein Item, kein Slot, keine Haltbarkeit; der Waffen-Slot bleibt unberührt.
- `ResourceNode._draw`: Abnutzung wächst mit den Schritten.

| Knoten | Abnutzung | Erschöpft |
|---|---|---|
| Baum | Kerbe im Stamm | Fallanimation 0,6 s, danach Stumpf mit Schnittfläche |
| Fels/Ader | Risse; Erzflecken verschwinden | Geröll |
| Pflanze | Halme werden einzeln entfernt | Stoppeln |
| Kadaver | Hautstreifen werden abgezogen | Knochen |

- Partikel pro Schritt über `CombatFx` (SPARKS in Holz-, Stein-, Erz-, Blatt- bzw. Hautfarbe); HUD-Meldung pro Schritt („Oak Tree 2/3 · +1 Timber · Woodcutting 2“).
- Isolierte Sichtprüfung: `tests/playtest/gathering_visual_check.gd` (Screenshots in `tests/output/gathering/`).

### Save
- Kein Schemawechsel, die Version bleibt 10: `map_states` war schon frei belegbar (skalare Werte). Neu sind nur die Schlüssel `gather.*` und `gather_cycle.*`.
- Alte Stände: Erschöpfte Knoten bleiben erschöpft. Teilzustände gab es vorher nicht; unberührte Knoten starten einen frischen Zyklus.

### Final Guarantee (garantierte Ausbeute)
- **Garantien**, alle innerhalb des einmal festgelegten Gesamtbudgets:
  - Bei zwei oder mehr Schritten gibt der **erste** abgeschlossene Schritt ≥ 1 Hauptmaterial.
  - Der **letzte** Schritt gibt ≥ 1 als Abschlussbonus.
  - Ein Ein-Schritt-Vorkommen gibt seine garantierte Einheit in diesem einen Schritt.
  - Die übrigen Einheiten werden zufällig verteilt; Zwischenschritte dürfen 0 geben.
- **Prüfung:** `ResourceNodeDefinition.budget_errors()` (in der Datenbank-Validierung) verlangt Ertrag ≥ 1, Schritte ≥ 1 und `1 ≤ completion_bonus ≤ yield − (1 bei ≥ 2 Schritten)`.
  - Alle 11 vorhandenen Vorkommen erfüllen das; keine Budget- oder Balanceänderung nötig.
  - Ungültige Budgets werden gemeldet. Selbst dann erzeugt der Plan nie mehr als das Budget: Bei Budget 1 auf 3 Schritten bleibt die eine Einheit der Abschlussbonus.
- **Bestehende Pläne:** Gespeicherte Teilzustände (aus 1.1) werden unverändert weitergeführt, nie neu gewürfelt. Ihr erster Schritt ist ohnehin schon abgeschlossen. Defekte Zustände geben weiter nie etwas.
