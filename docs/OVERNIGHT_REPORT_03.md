# Overnight Report 03 – Welt, Basisbau & erster Gameplay-Loop (Phasen 8–10)

**Engine:** Godot 4.7.2.stable.official · **Branch:** `dev/rpg-foundation` (lokal, nicht gepusht)

## 1. Ergebnis
Ein kleiner, spielbarer Action-RPG-Loop existiert: **in der Basis starten → in den Wald gehen → kämpfen →
Holz/Stein/Erz sammeln → zurückkehren → auf einem festen Bauplatz bauen → speichern → laden → alles ist
noch da.** Der Loop ist automatisiert (headless E2E-Test) und grafisch (skriptierter Playtest mit echtem
Laufen, Angreifen, G-Interaktion, UI-Klicks, F6/F9) durchgespielt. **Kein menschlicher Playtest.**

| Phase | Status | Commit |
|---|---|---|
| 8 Regionen & Maps | ✅ | `2045d3e` |
| 9 Basisbau mit festen Bauplätzen | ✅ | `24cd312` |
| 10 Integrierter Gameplay-Loop | ✅ | `aca1847` |
| Dokumentation | ✅ | letzter Commit des Branches |

Combat-Timings, Bewegung, Dash und Combos wurden **nicht** verändert.

## 2. Map- und Regionsstruktur (Details `WORLD_SYSTEM.md`)
- Region `hollow_outskirts` mit den Maps `home_base` (neue Startmap), `whisper_forest`, `test_arena`.
- Datengetrieben: `RegionDefinition`, `MapDefinition` (`data/world/`); Spawnpunkte als `SpawnPoint`-Nodes.
- Übergänge über sichtbare Wanddurchgänge (`MapTransition`), zentral über `SessionState.travel()` mit
  Fade-out/-in und Schutz vor Doppel-Übergängen. Basis Ost ↔ Wald West, Basis Nord ↔ Arena West.
- Persistenz: Map/Spawn, Welt-Flags, **Mapzustände** (`map_states`, neu → Save-Schema **v2** mit echter
  Migration v1→v2), dauerhaft besiegter Test-Boss „Grove Warden“, normale Grunts respawnen.
- Kein zusätzlicher Manager und keine zweite Charakterinstanz: jede Map hat ihren eigenen Player-Node, der an
  den einzigen `Character` im Autoload gebunden wird (getestet: genau ein Player, identisches Objekt).

## 3. Gebäude und Bauplätze
| Bauplatz | Map | Gebäude | Kosten | Funktion |
|---|---|---|---|---|
| `plot_west`, `plot_east`, `plot_north` | home_base | Smithy | 6 Timber, 4 Stone, 3 Iron Ore | Testrezept 3 Iron Ore + 1 Timber → Iron Sword |
| | | Storage | 8 Timber, 2 Stone | +10 Inventarplätze |
| | | Training Ground | 4 Timber, 4 Stone, benötigt Smithy | Hof mit Trainingspuppe |

Bauen nur auf freiem, zulässigem Platz mit ausreichendem Material; Kosten werden erst nach erfolgreicher
Gesamtprüfung exakt abgezogen; jedes Gebäude einmal pro Basis. Bau-UI per **G** am Platz.
Crafting ist ausdrücklich nur ein technischer Durchstich (keine Regeln für Essenzen/lebende Materialien).

## 4. Ressourcen & Loop-Verknüpfung
- `ResourceNodeDefinition` + wiederverwendbarer `ResourceNode` (G), Regeln in `ResourceGathering`.
- **Regel:** feste Echtzeit-Wiederkehr (Bäume/Felsen 90 s, Erzadern 120 s) als Mapzustand gespeichert;
  eine „Ancient Ore Deposit“ ist dauerhaft erschöpfbar. Volles Inventar → kein Abbau, kein Verlust.
- Erträge landen im bestehenden `Inventory`; Gebäude verbrauchen daraus; alles läuft durch das bestehende
  Save-System (Gebäude in `world.buildings`, Ressourcen-Timer in `world.map_states`).

## 5. Tests (tatsächlich gelaufen, chronologisch)
| Anlass | Suites | Ergebnis |
|---|---|---|
| P8 | world (neu, echte Szenenwechsel) | 7/7 ✅ |
| P8 Abh. (Schema v2, Hauptszene, Arena, Drops) | save, project, enemy, pickup | 25/25 ✅ |
| P8 Debug-Tasten nach `GameMap` | world, project, enemy, pickup | 22/22 ✅ |
| P9 | base (neu) | 7/7 ✅ |
| P9 Abh. | save, world, project | 20/20 ✅ |
| P10 | gathering (neu) 6/6 ✅; loop (neu, E2E) 0/1 ❌ – Testfehler: Spieler lief gegen die Wand statt zur Tür | → steuernd korrigiert: 1/1 ✅ |
| P10 Abh. (Datenbank, Waldszene) | world, base | 14/14 ✅ |
| Startprüfung nach jeder Phase | Import + 300 Frames, Fehler/Warnungen | OK |

**Bewusst nicht erneut ausgeführt:** alle Combat-Suites (movement, dash, combo, light/heavy_attack,
combat_data, input, collision, hit_reaction, weapon_switch, hits) sowie mastery, classes, inventory,
equipment, item_effects – deren Code und direkte Abhängigkeiten wurden in Phase 8–10 nicht verändert.
Kein vollständiger Testlauf (nicht erforderlich).

## 6. Playtests (grafisch, Fenster, Vulkan)
`tests/playtest/loop_playtest.gd`, Screenshots/Log in `tests/output/` (git-ignoriert):
1. `--tour`: Basis → Wald → Basis → Arena → Basis, Eintrittspositionen geprüft ✅
2. `--build-only`: Bau-UI öffnen, Smithy bauen, Rezept herstellen ✅
3. **Standard = kompletter Loop:** Grunt mit Light-Angriffen besiegt, Drops aufgesammelt, 10 Knoten per G
   (Timber 12, Stone 9, Ore 2→9), zurück, Bau-UI → Smithy, F6, neuer Charakter, F9 → Zustand identisch,
   Smithy steht ✅. Erster Lauf: 1 Fehlschlag, weil der Vergleich den Besuchszähler einschloss, den das
   Betreten der Map nach dem Laden erhöht (erwartet) → Vergleich angepasst.
4. `rpg_playtest.gd` erneut (wegen Fade beim Laden): 1 Fehlschlag durch Skript-Timing → Warten auf den
   Szenenwechsel ergänzt → ✅.
Gefundene und behobene Darstellungsfehler: grauer Hintergrund außerhalb der Maps, abgeschnittene
Bodenkacheln, Interaktionshinweis über den Hilfezeilen.

## 7. Bekannte Fehler & Risiken
- Keine bekannten funktionalen Fehler.
- Ressourcen wachsen in **Echtzeit** nach (auch bei geschlossenem Spiel) – Designentscheidung offen.
- Nach dem Laden erscheint der Spieler am gespeicherten **Spawnpunkt** (letzter Eingang), nicht an der
  exakten Position.
- Gebäude-Körper sind einfache Rechtecke; Spieler kann nach dem Bau neben dem Platz leicht verschoben werden
  (Godot-Recovery), bisher unauffällig.
- Grunts im Wald greifen während des Sammelns an – gewollt, aber Balance unbestätigt.
- Platzhaltergrafik; Lesbarkeit nur per Screenshot geprüft.

## 8. Starten & Testen
```powershell
cd "C:\Users\ncbha\GameDev\Echo of the Hollow"
..\tools\godot\Godot_v4.7.2-stable_win64.exe --path .          # Spiel (startet in der Basis)
..\tools\godot\Godot_v4.7.2-stable_win64.exe --path . -e       # Editor
# Combat-Feel-Test direkt in der Arena: test_arena.tscn im Editor öffnen und F6 (Szene starten)
.\tools\run_tests.ps1 -Suite loop,world,base,gathering        # neue Suites
..\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --fixed-fps 60 -s res://tests/playtest/loop_playtest.gd
```
**Loop selbst spielen:** Spiel starten → nach Osten durch den Durchgang (Whisper Forest) → Grunts
bekämpfen, Drops einsammeln → an Bäumen/Felsen/Erz **G** drücken → zurück nach Westen → zu einem
gestrichelten Bauplatz → **G** → „Build“ (Smithy) → **F6** speichern → Spiel beenden/neu starten → **F9**.

Tasten: WASD, Maus, LMB/RMB, Space, 1/2 Waffe, **G** Interaktion, **I** Inventar, **F6** speichern, **F9**
laden, Debug (alle Maps): F1 Hitboxen, F2 Gegner, F3 +Mastery-XP, F5 Map neu laden, F7 Item-/Material-Kit,
F8 +Klassen-XP. Spieler-Spielstand: `%APPDATA%\Godot\app_userdata\Echoes of the Hollow\saves\slot_1.save.json`.

## 9. Empfohlene nächste Schritte
1. Menschlicher Combat-Feel-Test (Arena) und danach ein Loop-Playtest (Wald-Schwierigkeit, Ressourcenmengen).
2. Designentscheidungen: Ressourcen-Respawn (Echt- vs. Spielzeit), Crafting-Grundregeln, Dash durch Gegner.
3. Inhalte: zweiter Gegnertyp und echte Sprites/Animationen, damit der Loop sich lohnend anfühlt.
