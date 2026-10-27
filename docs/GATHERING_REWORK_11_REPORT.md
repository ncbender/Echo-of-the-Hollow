# Gathering Rework 1.1 – Abschlussbericht

**Branch:** `dev/gathering-rework-11` (lokal, nicht gepusht), Basis `5af5443` (Combat Rework / Weapon Mastery 1.4–1.5).
Systemdoku: `docs/GATHERING.md`.

**Schutz:**
- `project.godot`: fremd und uncommittet, Hash `68321b98…` unverändert, nie gestaged.
- Echte Saves und `settings.cfg`: nach jedem Godot-Lauf per SHA-256 geprüft, unverändert.
- Tests nutzen eigene Testcharaktere und nur `user://test_saves/`.
- Kein Push, keine Force-Operation.

## Commits und Phasen

| Phase | Commit | Inhalt |
|---|---|---|
| 1 Audit | `a517e6c` | Gathering-Code, G = `interact`, Save-Modell (`map_states`), Integrationsplan, Testdateien vorab festgelegt |
| 2 Datenmodell | `2f3a03f` | `steps`, `completion_bonus`, `gather_step_seconds`; fester Plan pro Zyklus; persistenter Teilzustand |
| 3 G-Halten | `9d0c72d` | `Player.begin_gather`/`_step_gather`, `InputFrame.interact_held`, alle Unterbrechungen |
| 4 Loot/XP | `b53a22d` | `complete_step` als Transaktion, Abschlussbonus, Restbudget, Anti-Dupe, manipulierte Zustände, `ResourceNode`-Anbindung |
| 5 Visuell | `6957e6b` | Werkzeug-Platzhalter, Beschädigungsstufen, fallender Baum/Stumpf, Geröll, Stoppeln, Knochen, Partikel |
| 6 Tests/Doku | dieser Commit | Dokumentation, Bericht |

Alle sechs Phasen sind fertig.

## Ausgeführte Tests (nur die vorab festgelegten Dateien)

| Datei | Ergebnis | Inhalt |
|---|---|---|
| `test_gathering_steps.gd` (neu) | 6 / 6 | Daten je Beruf; Budgets = alte Gesamterträge und XP; Bonus; kein Neuwürfeln; je ein Knoten aller vier Berufe Schritt für Schritt; Ablehnungen (Level, volle Tasche) ändern nichts; Teilfortschritt über Save/Load ohne Reroll und Dupe; erschöpft bleibt erschöpft; manipulierter, unlesbarer und alter Zustand ohne Belohnung |
| `test_gathering_hold.gd` (neu) | 6 / 6 | Schritt-Timing (0,75 s), Halten bis zur Erschöpfung, gehaltenes G startet nichts Neues; Loslassen und neuer Druck; alle Unterbrechungen; geblockter Treffer ohne Schaden; nur aus neutralem Zustand, kein Trinken; echter `ResourceNode` mit Spieler |
| `test_professions.gd` | 10 / 10 | Berufsregeln, Sammel-XP und Erschöpfung über Save/Load |
| `test_hollowwood.gd` | 6 / 6 | Knotenplatzierung, Level-3-Knoten, Erreichbarkeit, Rezepte |
| `test_input.gd` | 4 / 4 | Eingabekanten, Tasten 1/2 |

**Summe: 32 / 32 grün.** `--import` lief ohne Fehler und Warnungen.

Die alte Prüfung „unterbricht alle Unterbrechungsarten“ deckt alle zehn Gründe ab: Loslassen, WASD, Dash, Angriff, Skill, HP-Schaden, Stun, Knockback, Tod, Menü – plus Reichweite.

**Sichtprüfung:** isoliert mit `tests/playtest/gathering_visual_check.gd` (eigene Mini-Szene, kein Map- oder Story-Durchlauf). Vier Screenshots in `tests/output/gathering/`:
- alle vier Berufe unberührt, angearbeitet und erschöpft
- Axt ausgeholt und Schlag
- Baum im Fallen mit Holzsplittern
- Stumpf

**Nicht ausgeführt** (Teststrategie 1.1): volle Suite, Galerie, Prolog-, Loop-, Crafting- und Klassen-Playtests, `test_loop`.

**Empfehlung, nicht ausgeführt:**
- `test_loop`: nutzt `ResourceNode.gather()`, das jetzt alle Schritte am Stück erntet und dieselbe Gesamtausbeute liefert.
- Ein `loop_playtest`-Durchlauf als breiter Regressionstest.
- Ein manueller Feel-Test mit echter Tastatur (G halten).

## Save und Schutzmaßnahmen

- **Kein Schemawechsel, die Version bleibt 10.** Neue Schlüssel in `WorldState.map_states`:
  - `gather.<node_id>`: JSON mit `steps`, `done`, `item`, `items[]`, `xp[]`, `bonus`, `given_items`, `given_xp`
  - `gather_cycle.<node_id>`: Zähler der Erschöpfungen
  - `node.<node_id>`: Erschöpfung wie bisher
- **Alte Saves:** Erschöpfte Knoten bleiben erschöpft (getestet mit einem v10-artigen Zustand). Teilzustände gab es vorher nicht; eine Migration ist daher nicht nötig.
- **Anti-Dupe:**
  - Der Plan ist deterministisch pro Zyklus (Saat Map + Knoten + Zyklus) und wird beim ersten Schritt gespeichert. Unterbrechen, Laden oder erneutes Interagieren würfelt nie neu.
  - Jeder Schritt ist eine Transaktion: Material, Fortschritt und XP gehen zusammen; jede Ablehnung ändert nichts.
  - Widersprüchliche oder unlesbare Zustände geben keine Belohnung, der Knoten gilt als erschöpft.

## Animationen und Platzhalter

Es gibt **keine Sprites, Werkzeug- oder Sammel-Animationen** im Projekt. Umgesetzt als klar dokumentierte Zeichnungs-Platzhalter:

**Spieler:**
- Rein visuelles Werkzeug je Beruf: Axt, Spitzhacke, Sichel, Messer.
- Es holt über 70 % des Schritts aus und schlägt in den letzten 30 % zu.
- Kein Item, Slot, Haltbarkeit oder Quick-Swap; der Waffen-Slot bleibt unberührt.

**Knoten:**

| Beruf | Während der Schritte | Erschöpft |
|---|---|---|
| Woodcutting | Kerbe wächst | Baum fällt (0,6 s), Stumpf |
| Mining | Risse, Erzflecken verschwinden | Geröll |
| Herbalism | Halme werden einzeln entfernt | Stoppeln |
| Skinning | Hautstreifen | Knochen |

**Rückmeldung:**
- Partikel pro Schritt (`CombatFx` SPARKS in Materialfarbe).
- HUD-Meldung pro Schritt.
- Prompt „Hold to gather … (n/N)“.

## Prototypwerte

- **Schrittzeiten:** Woodcutting 0,75 s, Mining 0,85 s, Herbalism 0,65 s, Skinning 0,90 s.
- **Schrittzahlen:** Oak 3, Old Oak 4; Forest Rock 3, Iron Vein 4, Rich Iron Vein 5, Ancient Deposit 5; Duskleaf Patch 1, Wild Flax 2, Duskleaf Cluster 3; Stag 2, Elk 3.
- **Abschlussbonus:** jeweils 1 Einheit.
- **Budgets:** Mengen und XP sind die bisherigen Gesamtwerte, nur auf die Schritte verteilt; kein neues Economy-Balancing.

## Verbliebene Punkte

1. **Interpretationen, bitte bestätigen:**
   - Trinken (1/2) startet während des Sammelns nicht.
   - Shift (Block/Parry) bleibt möglich und unterbricht nicht, weil es nicht auf der Unterbrechungsliste steht.
   - Die Reichweite ist die vorhandene Interaktions-Area des Knotens.
2. **Kein Teilzustands-Verfall:** Ein angearbeiteter Knoten bleibt dauerhaft angearbeitet, bis er erschöpft ist; der Respawn beginnt erst danach (nicht spezifiziert).
3. **Schrittzahlen** innerhalb der Spannen sind von mir je Ressourcentyp gewählt – bitte prüfen.
4. **Knoten mit 1 Schritt** (Duskleaf Patch, Ertrag 1): Der einzige Schritt ist zugleich der Abschlussbonus.
5. **Wiederverwendbarer Shortcut:** `ResourceGathering.gather()` bzw. `ResourceNode.gather()` erntet alle Schritte sofort. Das Spiel selbst nutzt es nicht; es dient nur Tests und Simulationen.
6. **Gegenlauf mit breiterem Test:** `test_loop` wurde laut Strategie nicht ausgeführt (s. Empfehlung).
