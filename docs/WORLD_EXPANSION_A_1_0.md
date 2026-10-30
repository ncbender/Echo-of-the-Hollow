# Region 1 – World Expansion A 1.0: Whisper Forest + Tangled Wood

Branch `dev/roots-remember-m4` @ `16dd2fc` (uncommitted). Grundlage: Masterplan 1.0 (Region 1). Keine Save-Version
(bleibt **v15**), keine Zoom-, Combat-, XP- oder Questlogik-Änderung. Fremde Änderungen (`project.godot`, `docs/Design/`,
`docs/tasks/`) unberührt.

## Karten

| Karte | Fläche (Floor) | `camera_bounds` | Bildschirme 512×288 / 640×360 |
|---|---|---|---|
| Whisper Forest | `Rect2(-1280, -720, 2560, 1440)` | Fläche + 32 px | 5,0×5,0 / 4,0×4,0 |
| Tangled Wood | `Rect2(-1152, -864, 2304, 1728)` | Fläche + 32 px | 4,5×6,0 / 3,6×4,8 |

Wald ist auf einem 32-px-Raster aus begehbaren Formen (Hauptweg, Nebenwege, Lichtungen) gebaut; alles andere füllen
`WallBlock`s (`Walls/Forest*`, spaltenweise zusammengefasst) plus Rahmen mit 48-px-Lücken an den Ausgängen. Hauptweg = helle
Erde (`MainRoad/*`), Nebenwege = dunklere Erde (`SidePaths/*`), Teilgebiete haben eigene Bodentöne.

### Whisper Forest
- **Hauptweg** Haven (−1292, 0) → Split Oak (−300, −20, Rastplatz `forest_rest`) → (150, −180) → (650, −300) → Ostausgang
  (1292, −420), ≈2 500 px. Prolog-Gate `EastRoots` (Bar + Hinweis `east_roots`) / `EastPath` unverändert, nur verschoben.
- **Forager's Path** (Südwesten): Hauptsammelgebiet, sicher am Eingang, Wölfe (`wf_forager_wolves`) im östlichen Teil,
  Geheimpfad zum **Hunter's Pack** (−1195, 655, unverändert `forest_hunters_pack` → `pattern_leather_bracers`). Schleife
  im Süden bis zur Clearing.
- **Hunter's Trail** (Norden): Rundweg Split Oak → Grunt-Lichtung (`GruntA/B`) → Hunter's Camp (Zelt) → Nordpfad
  (`wf_trail_wolves`, `GruntC`) → Den → Abstieg zum Hauptweg; innerer Querweg. L3-Funde `TrailElk`, `TrailDuskleaf`,
  einmaliges `deposit` im Den. `QuestAnchors/LostHunter*` (leere Marker) für Paket C.
- **Warden's Clearing** (Südosten): Schlucht ab (150, −170) mit Warnstein, Arena ≈480×360 (Ellipse um (820, 420)),
  `GroveWarden` (820, 400), `WardensCache` (900, 560). Werte, Claim und Rare unverändert.

### Tangled Wood
- **Hauptweg** (−1164, 0) → Root Arch → Bogen (`tw_bend_wolves`) → Heart of the Roots (Rastplatz `tangled_rest`,
  **TwistedRoots** (260, −200) direkt am Weg) → (420, 60) → `tw_heart_watch` → Chapel-Ausgang (1164, 300), ≈2 540 px.
- **Nordschleife**: `PathHusks` (`tangled_path_husks`), `NorthHardened`, Old Oak (L3), Lore „Swallowed Cart“.
- **Senke** (Süden): `HollowWolves` (`tangled_hollow_wolves`, Wolf-Tabelle), `GnawedRoots`.
- **Sunken Grove** (Südwesten) mit Rundweg zur Senke: Duskleaf Cluster (L3), Iron Vein, Lore „Sunken Stones“.
  `QuestAnchors/RootsKeep*` (leere Marker) für Paket C.
- **Abkürzung** (420, 60) → Root Arch: `Shortcut/BrittleRoots` (Readable, verb „Tear“, kein Reward, kein Event) öffnet
  einmalig von Osten; `Shortcut/Closed` (`StoryConditional`, `forbidden_flags [read.tw_brittle_roots]`) trägt die Barriere.
  Gespeichert als normales Welt-Flag – kein neues System.

## Begegnungen und Rückweg
- Hauptweg-Kämpfe sind **einmalig** (`persistent = true`): `wf_road_husks`, `tw_bend_wolves`, `tw_heart_watch`.
- Optionale Kämpfe kommen pro Besuch wieder (bestehende Mechanik): Grunts A–C (platziert, Equipment-Roll), `wf_trail_wolves`,
  `wf_forager_wolves`, `tangled_path_husks`, `tw_north_hardened`, `tangled_hollow_wolves`.
- Platzierte Gegner nur im Whisper Forest, `Player` steht vor `Enemies`. Grunts ≥ 370 px vom Hauptweg (Aggro 260),
  Grove Warden ≥ 720 px.
- Rückweg Chapel → Haven: in WF/TW kein Pflichtkampf mehr nach dem ersten Durchgang.

## Technik
- `GameMap.camera_bounds` (Export, Standard leer = freie Kamera wie bisher): setzt die `Camera2D`-Limits; nach dem
  Platzieren springt die Kamera auf den Spawn (`reset_smoothing`, nur mit Bounds). Zoom unverändert.
- Erhaltene IDs: alle `node_id`s, `persistent_id`s, Spawn-IDs (`default`, `from_home`, `from_tangled`, `from_forest`,
  `from_chapel`), Encounter-IDs, Knotennamen/-pfade aus den Tests. Neue Spawn-IDs nur über Checkpoints.

## Tests
`test_world_expansion_a` (neu, 9): IDs/Trigger/Gate, Einmal- vs. Pro-Besuch-Kämpfe, Kamera-Limits, freie Spawns und
Plätze, Hauptweg zu Fuß (WF → TW, TW → Twisted Roots → Chapel), Abkürzung inkl. Save/Load, Rückweg ohne Wiederholung,
alte Saves auf allen Spawns. Angepasst (nur Koordinaten → aus der Szene gelesen): `roots_remember_m1`, `roots_remember_m2`,
`whisper_forest_target_fix`, `hollowwood` (Laufwege), `loop`, Playtest `forest_target_visual_check`.
