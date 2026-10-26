# Welt, Basisbau & Ressourcen

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Regionen & Maps ✅
| Daten | Inhalt |
|---|---|
| `data/world/regions/hollow_outskirts.tres` | erste Region, listet ihre Maps |
| `data/world/maps/*.tres` (`MapDefinition`) | ID, Region, Name, Szenenpfad, Standard-Spawn |

| Map-ID | Szene | Inhalt | Ausgänge |
|---|---|---|---|
| `old_road` | `scenes/maps/old_road.tscn` | **New-Game-Start** (Prolog-Teil 1, Mara, Wagen) | Nord → Haven |
| `home_base` | `scenes/maps/home_base.tscn` | **Haven**: sechs Ruinen, Klassenstation, Wegstein, Mara, Edrin; keine Gegner | Süd → Old Road, Nord → Whispering Stone (nach Edrin), Ost → Wald, West → Arena |
| `whispering_stone` | `scenes/maps/whispering_stone.tscn` | Echos, Klassenwahl, Wegstein, Memory Fragment | Süd → Haven |
| `whisper_forest` | `scenes/maps/whisper_forest.tscn` | 3 Grunts (respawnen), Test-Boss „Grove Warden“ (persistent), 10 Ressourcenknoten | West → Haven |
| `test_arena` | `scenes/arena/test_arena.tscn` | Combat-Testarena (unverändert spielbar, direkt startbar), Entwickler-Tor zu den Prologue Grounds | West → Haven |
| `prologue` | `scenes/maps/prologue.tscn` | Prologue Grounds (Entwicklerzugang, alte Trial-Testsequenz) | → Haven |

Hauptszene ist der Titelbildschirm (`scenes/ui/title_screen.tscn`). Prolog, Haven und Wegsteine:
`PROLOGUE_AND_HAVEN.md`.

- **Spawnpunkte:** `SpawnPoint`-Nodes mit `spawn_id` (pro Map eindeutig, `default` Pflicht).
- **Übergänge:** `MapTransition`-Areas in sichtbaren Wanddurchgängen (Portal-Markierung + Zielname).
- **Zentrale Übergangsverwaltung:** `SessionState.travel(map_id, spawn_id, fade)` (Autoload
  `GameSession`): Fade-out (0,2 s) → Szenenwechsel → `GameMap` platziert den Spieler am Spawnpunkt,
  bindet **denselben** `Character` → Fade-in. Anfragen während eines Übergangs werden ignoriert.
- **`GameMap`** (Basisskript jeder Map): Spawn, Charakterbindung, HUD, lokaler Hitstop, Gegner-Drops,
  persistente Pickups/Bosse, Interaktion (G), Speichern/Laden (F6/F9), Debug-Tasten (F1–F8) auf allen Maps.
- Datenbank-Validierung: Szene existiert, Region→Map-Referenzen; der `world`-Test lädt zusätzlich alle
  Szenen und prüft, dass jedes Übergangsziel (Map + Spawnpunkt) existiert.

## Persistenz der Welt ✅
| Was | Wo | Regel |
|---|---|---|
| aktuelle Map + Spawnpunkt | `WorldState.map_id/spawn_id` | beim Betreten gesetzt, gespeichert |
| Welt-Flags | `WorldState.flags` | bool/int/String, gespeichert |
| Mapzustände | `WorldState.map_states[map][key]` | z. B. `visits`, Ressourcen-Timer (Save v2) |
| normale Gegner | – | **respawnen** bei jedem Betreten |
| Boss-/Quest-Gegner | Flag `defeated.<persistent_id>` | bleiben dauerhaft besiegt |
| platzierte Pickups | Flag `pickup_taken.<persistent_id>` | kein erneutes Erscheinen (Anti-Duplikation) |
| Gebäude | `WorldState.buildings[plot] = building` | gespeichert |

## Basisbau ✅ (Regeln; in Haven seit Slice 0.1 durch feste Ruinen ersetzt)
> Haven hat **keine freien Bauplätze** mehr: Die sechs Ruinen (`RuinSite`, `RestorationService`,
> `PROLOGUE_AND_HAVEN.md`) nutzen die Gebäudedefinitionen unten für ihre Funktion. `BaseBuilder` und die
> Plotdaten bleiben als Regelwerk (Tests `base`) erhalten; v4-Plotgebäude werden zu Ruinen migriert.
- `BuildingPlotDefinition` (`data/base/plots/`): ID, Map, erlaubte Gebäude (leer = alle), Größe.
  (Früher in der Basis: `plot_west`, `plot_east`, `plot_north`.)
- `BuildingDefinition` (`data/base/buildings/`): Kosten, Voraussetzungs-Flag, Einmaligkeit, Szene,
  Lagerbonus, Rezepte.

| Gebäude | Kosten | Funktion |
|---|---|---|
| Smithy | 6 Timber, 4 Stone, 3 Iron Ore | Rezept „Forge Iron Sword“ (3 Iron Ore + 1 Timber → Iron Sword) – **nur technischer Crafting-Durchstich** |
| Storage | 8 Timber, 2 Stone | +10 Inventarplätze (auch nach dem Laden neu berechnet) |
| Training Ground | 4 Timber, 4 Stone, **benötigt Smithy** | eingezäunter Hof mit echter Trainingspuppe |

- `BaseBuilder.build()` prüft *alles* zuerst (Platz frei, Gebäude erlaubt, Voraussetzung, Einmaligkeit,
  Material) und verbraucht erst dann exakt die Kosten → keine Teilkosten, keine negativen Mengen.
- Gebäude erscheinen nach dem Bau (Gebäudeszene auf dem Platz) und nach Kartenwechsel/Neustart.
- Keine Crafting-Regeln für lebendige Materialien oder Essenzen festgelegt (bewusst offen).

## Ressourcen ✅
- `ResourceNodeDefinition` (`data/world/resource_nodes/`): Ertrag (Item + Menge), Wiedererscheinen.
- `ResourceNode` (Szene `scenes/world/resource_node.tscn`): wiederverwendbare Sammelkomponente,
  **G** in Reichweite; Regeln in `ResourceGathering` (Zeit als Parameter → deterministisch testbar).
- **Gewählte Regel:** Nach dem Abbau ist ein Knoten für `respawn_seconds` **Echtzeit** erschöpft
  (Unix-Zeit, läuft also auch bei geschlossenem Spiel weiter); `respawn_seconds = 0` = dauerhaft
  erschöpft. Volles Inventar → Abbau abgelehnt, Knoten bleibt verfügbar.

| Knoten | Ertrag | Wiedererscheinen | Anzahl im Wald |
|---|---|---|---|
| Oak Tree | 3 Timber | 90 s | 4 |
| Forest Rock | 3 Stone | 90 s | 3 |
| Iron Vein | 2 Iron Ore | 120 s | 2 |
| Ancient Ore Deposit | 3 Iron Ore | dauerhaft erschöpft | 1 |

Grunts droppen zusätzlich 2 Iron Ore + 1 Hollow Essence. Ein Waldbesuch liefert genug für Smithy +
Training Ground oder Storage.

## Offen
⬜ große Regionen/weitere Maps, ⬜ Quest-System (nur Flags), ⬜ Produktionsketten/Wirtschaft,
⬜ Gebäude-Upgrades/Abriss, ⬜ Entscheidung, ob Ressourcen in Spielzeit statt Echtzeit nachwachsen.
