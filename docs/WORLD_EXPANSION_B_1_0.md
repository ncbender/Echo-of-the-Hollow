# Region 1 – World Expansion B 1.0: The Chapel + Warden's Rest

Auf dem uncommitteten Stand von Paket A (`docs/WORLD_EXPANSION_A_1_0.md`), Branch `dev/roots-remember-m4` @ `16dd2fc`.
Save bleibt **v15**; keine Änderung an Zoom, `project.godot`, Combat, Boss, Hauptquest, Edrin/Mara. Nur die beiden Szenen,
Tests und diese Doku.

## Karten

| Karte | Fläche (Floor) | `camera_bounds` | Bildschirme 512×288 / 640×360 |
|---|---|---|---|
| The Chapel | `Rect2(-800, -576, 1600, 1152)` | Fläche + 32 px | 3,1×4,0 / 2,5×3,2 |
| Warden's Rest | `Rect2(-640, -512, 1280, 1024)` | Fläche + 32 px | 2,5×3,6 / 2,0×2,8 |

Bau wie Paket A (32-px-Raster, Wald füllt den Rest), dazu Steinbauten aus `WallBlock`s mit Türlücken.

### The Chapel
- **Hof (West)** −770…−300: Zugang aus der Tangled Wood (−812, 0), Grabsteine, Mauerreste, `chapel_yard` (−470, 0),
  Lore „Weathered Headstone“, Oak Tree.
- **Kirchenschiff** `(-300, -200, 660, 400)`: Westtür (Breite 96) → Mittelgang → **ChapelWaystone (290, 0)** in der
  bemoosten Apsis; Bankreihen in drei Blöcken, eingestürzte Ecke (SW), Wurzeln in der Apsis. Türen: Nord (−105) →
  Kreuzgang, Nordost (270) → Ostweg, Süd (70) → Shelter.
- **Ostweg** (270, −200) → (420, −300) → (812, −380): `SealedEast`/`SealedWay` (808, −380) + `SealedHint` (766, −380,
  `chapel_east_way`) bis zur Waystone-Untersuchung, dann `OpenEast/ToWardensRest` (812, −380); Rückkehr-Spawn
  `from_wardens_rest` (754, −380).
- **Kreuzgang (Nord, optional)** `(-380, -540, 560, 260)`: Säulen, eingestürzter Glockenturm, Lore „Cracked Bell“, Iron Vein,
  Forest Rock, `chapel_cloister` (2 Husks); Rückweg über die Nordtür oder als Schleife Ost auf den Ostweg (430, −320).
- **Shelter-Flügel (Süd)** `(-280, 250, 580, 270)`: Schlafraum | Herdraum (Rastplatz `chapel_rest` (40, 410), kalte
  Feuerstelle) | Vorratsraum (Kisten, **FadedNote** (230, 430)). Westtür zum Kräutergarten (2× Duskleaf, Wild Flax),
  Rundweg zurück zum Hof. `QuestAnchors/Shelter*` für „Embers of Shelter“ (Paket C).

### Warden's Rest
- **Vorhof** −600…−240: Zugang (−652, 0), `wr_forecourt` (2 Husks) (−430, 0), Rastplatz `wardens_rest_gate` (−300, 70),
  Oak Tree.
- **Arena** `(-240, -208, 672, 416)`, innen 640×384: Tor (Breite 80) zwischen `GateTowerNorth/South` (−232, ±64),
  **RootboundSentinel** (100, 0), Mitte frei (≥ 120 px um den Sentinel geprüft), vier Säulenstümpfe nur an den Ecken,
  Watchstone-Block (100, −165), **AfterSentinel/SplitWatchstone** (100, −128).
- **Wachhütte (NO)** `(340, -480, 280, 190)` über Lücke Nord (380): **ScratchedTally** (560, −440), Pritsche/Gestell,
  `QuestAnchors/WardenFootlocker` (440, −440) für einen späteren kleinen Fund.
- **Baracke (Süd)** über Lücke Süd (200): Mauerreste, Lore „Watch Captain's Log“, Rich Iron Vein (L3), Forest Rock,
  `wr_barracks_wolves` (2 Wölfe, optional).
- **Ostweg angedeutet**: Lücke Ost → Stich bis zur Wurzelwand (596, 0), Hinweis `wardens_rest_east_roots`. Kein Übergang.

## Begegnungen und Rückweg
- Einmalig (Hauptweg): `chapel_yard` (jetzt `persistent = true`; vorher pro Besuch), `wr_forecourt`.
- Pro Besuch (optional): `chapel_cloister`, `wr_barracks_wolves`.
- Mit Paket A ist der gesamte Rückweg Warden's Rest → Haven nach dem ersten Durchgang frei von Pflichtkämpfen.
- Hinweis: Alte Saves haben kein `encounter.chapel_yard`-Flag – der Hof wird dort noch einmal gekämpft, danach nie mehr.

## Erhaltene IDs
`chapel`/`wardens_rest`, Spawns `default`/`from_tangled`/`from_wardens_rest`/`from_chapel`, `chapel_old_stone`,
`interact:chapel_waystone`, `chapter1.chapel_waystone_examined` (SealedEast/OpenEast), `chapel_east_way`,
`chapel_faded_note`, `wardens_rest_rootbound_sentinel` (+ `defeat_milestone`, Config/Attacks), `defeated.*`-Bedingung von
`AfterSentinel`, `wardens_rest_watchstone`, `interact:wardens_rest_watchstone`, `wardens_rest_tally`, Knotenpfade aus den Tests.
Wegsteine bleiben `available = false` (kein Waystone-Knoten).

## Tests
`test_world_expansion_b` (neu, 7). Angepasst: `roots_remember_m2` (Koordinaten aus der Szene; Interaktionen = Waystone +
Notiz + optionale Funde ohne Event/Reward; ein Rastplatz; `chapel_yard` einmalig + optionaler Kreuzgang),
`roots_remember_m3` (Koordinaten/Tor aus der Szene; vor dem Sieg nur optionale Funde, nie der Watchstone).

## Offen
- Playtest-Skripte `roots_m2/m3/m4_visual_check` nutzen noch alte Koordinaten (nicht gelaufen).
- Keine gespielte Bosskampf-Abnahme in der neuen Arena (nur Headless-Prüfungen und Screenshots).
