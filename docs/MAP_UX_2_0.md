# Map UX 2.0 – Batch 4

Gebiets- und Regionskarte (Fenster M) sind leichter erfassbar und mit der Maus bedienbar. Keine Änderung an
Weltlayout, Kollision, Kamera-Grenzen, Fog-Regeln, Markerregeln, FLOOR/WALL-Farben (`is_solid`), Questbedingungen,
Waystone-Freischaltung, Reiseregeln, Reisezielen, Kampf oder Save (v15). Keine neuen oder geänderten PNGs.

## 1. Neue Bedienung und Regionsstruktur

**Area (Standard)**
- Eine schmale Werkzeugzeile: Kartenname · Symbolzeile der Marker (echte Pixel-Art bzw. MapPainter-Glyphen, Wort im
  Tooltip) · Hilfe „?“ (alle Symbole und die Bedienung, per Hover und Tastaturfokus) · Zentrier-Knopf (Spielerpfeil,
  Tooltip „Center on player“). Die große Textlegende unter der Karte entfällt; die Karte füllt den Rest des Rahmens.
- Maßstab: die ganze Karte, wenn sie bei bis zu 1,0 hineinpasst, sonst nie unter 0,5 View-px je Welt-px – in Schritten
  von 1/8, sodass ein Kartenpixel (8 Welt-px) immer ganze Bildschirmpixel belegt. Große Karten (Whisper Forest,
  Tangled Wood) sind damit größer als die Fläche und werden verschoben; Haven passt ganz hinein und steht mittig.
- Marker, Fog und Spielerpfeil wie bisher (`MapMarkers`, `MapPainter`, gleiche Daten wie die Minimap).

**Region**
- Schematisches Netz aus `MapDefinition.map_cell` und `.neighbors` (echte Daten, keine erfundenen Orte): kompakte
  Ortsknoten 168 × 52 im Raster 206 × 104, Linien für echte Nachbarschaften (vor den Knoten gezeichnet, also nie durch
  Namen), ein unbekannter Nachbar als namenloses „?“. Hinweis „schematic, not to scale“ in der Kopfzeile.
- Knoten: voller Name (bei Bedarf zweizeilig, nie abgeschnitten – `MapGraph.names_fit`), aktueller Ort = Spielerpfeil
  im Knoten + Resonanzlinie unten, gewählter Ort = Goldrahmen (beides gleichzeitig unterscheidbar), Waystone-Symbol
  (wach / grau „silent“) rechts im Knoten – nur bei `known_waystones`.
- Detailzone unter dem Netz: Ortsname, „You are here“ / „Visited“, Waystone mit Zustand, Reiseaktion bzw. Grund.
- Tastatur: Pfeiltasten wählen den nächsten bekannten Ort in dieser Richtung; Tab erreicht Hilfe, Zentrierknopf und
  „Travel“. Klick wählt nur.

## 2. Zentrierung und Ziehen (`WorldMapPanel.PanCanvas`)

- Gemeinsame Basis beider Ansichten: abgeschnittene Fläche mit Versatz `pan`, immer innerhalb des Inhalts
  (`clamp_offset`): ist der Inhalt auf einer Achse kleiner, steht er dort mittig; sonst kein leerer Rand.
- Öffnen (und jedes erneute Öffnen): `follow_layout` – zentriert auf den Spieler (Area) bzw. den aktuellen Ort (Region),
  erst nach gültiger Layoutgröße, und bei jeder Größenänderung erneut, bis der Spieler selbst verschiebt. Kein Folgen
  danach. Am Kartenrand bleibt die Fläche an der Kante, der Spieler steht dann außermittig.
- Ziehen mit gedrückter linker Maustaste: unmittelbar, ohne Nachschwingen. Schwelle 5 px: darunter ist es ein Klick
  (Region: Auswahl), darüber ein Drag, der nie klickt. Tabs, Knöpfe und Hilfen liegen außerhalb der Fläche und werden
  nicht abgefangen. Pfeiltasten verschieben die Area-Fläche um 64 px.
- Keine Scrollleisten mehr in der Karte (die frühere `RegionScroll` entfällt) – eine einzige Verschiebelogik.
- Zentrier-Knopf: Area „Center on player“, Region „Center on your place“.

## 3. Waystone-Liste und Reisen

- Die frühere Liste „Waystones“ unter der Region war reine Wiederholung (Name + awake/silent, keine Aktion) und
  entfällt; der Zustand steht jetzt am Knoten und in der Detailzone.
- Reisen bleibt ausschließlich eine ausdrückliche Aktion: „Travel“ in der Detailzone eines gewählten Orts mit wachem
  Waystone. Erlaubt nur, wenn der Spieler an einem wachen Waystone steht (`WorldMapPanel.standing_waystone`) und
  `WaystoneService.travel_error` nichts meldet (nicht hier, keine Gegner nah, keine Trial). Sonst sichtbar der Grund,
  z. B. „Travel starts at an awake waystone.“. Kein Teleport von beliebigen Orten.
- Eine gemeinsame Reiselogik: `WaystonePanel.start_travel` (vom Waystone-Fenster und von der Karte genutzt).
- „Return to Haven“ ist nicht Teil dieses Batches.

## 4. Erhaltene Fog-, Spoiler- und Save-Regeln

- Fog nur durch echte Bewegung (`GameMap._update_fog`), gespeichert in `WorldState.map_states[map]["fog"]`; nichts
  davon geändert. Marker nur auf erkundetem Boden (`MapMarkers`, unverändert).
- Region: nur besuchte Orte mit Namen (`known_maps`), unbekannte Nachbarn als „?“; Waystones nur nach
  `known_waystones` (wach, oder auf einem besuchten Ort als „silent“). Das Raster umfasst wie bisher die ganze Region,
  damit seine Größe nichts verrät. Keine Gegner-, Loot- oder Questinformationen.
- Save v15 unverändert; keine neuen gespeicherten Felder (Zentrierung und Auswahl sind Fensterzustand).
- FLOOR/WALL-Farben und `AreaMap.is_solid` unberührt.

## 5. Ausgeführte Tests

- `./tools/check_project.ps1`: **Startup check OK**.
- Neu `test_map_ux` (3 Tests, echte Mausereignisse über `push_input`): großer Wald zentriert beim Öffnen; Drag bewegt
  1:1; Begrenzung an beiden Ecken ohne Leerrand; Zentrierknopf; Pfeiltasten; Spieler an der Ecke (Fläche an der Kante);
  erneutes Öffnen zentriert wieder; kleine Karte mittig und unverschiebbar; Region aus echten Daten, unbesuchter Ort
  nicht benannt, Namen ganz, aktueller Ort gewählt und sichtbar, Drag wählt nichts, Klick wählt, Wahl reist nicht,
  Reisegrund abseits eines Waystones, Pfeiltaste wählt Nachbar, am wachen Waystone Haven: „Travel“ aktiv und startet die
  Reise. Erster Lauf: Testfehler (Fensterkoordinaten statt Viewport-Koordinaten, Spawn am Kartenrand, Drag über den
  Fensterrand) → Test korrigiert, **3 passed**.
- `-Suite "map_fog,world_ui,main_window_layout,ui_tab_geometry,map_marker_art,ui_window_foundation"`: **25 passed**
  (inkl. Fog-Save/Load, Spoilerschutz, Fenstergeometrie).
- `-Suite "ui_layout_lock,world_expansion_b,shrine,save_foundation"`: **31 passed**.
- UI-Galerie 1080p/100 %: `map`, `map_region`, `waystones`: **OK** (Layout, HUD ohne Überlappung).
- Neuer Fenster-Check `tests/playtest/map_ux_check.gd` (1920 × 1080, 100 %): **OK (3 checks)**.
- Keine Full-Suite, keine Gameplay-Loops, kein Asset-Validator (keine Assets).

## 6. Selbst angesehene Screenshots (1920 × 1080, 100 %)

`tests/output/map_ux/`: `area_haven` (ganze Karte mittig), `area_forest_centred` (Spieler mittig, Symbolzeile,
Hilfe, Zentrierknopf), `area_forest_dragged` (echter Maus-Drag), `area_forest_recentred`, `area_forest_edge` (Spieler
an der unteren rechten Ecke, kein Leerrand), `region_partial` (Haven wach, Whispering Stone silent, zwei „?“),
`region_chosen_help` (Whispering Stone gewählt, aktueller Ort Whisper Forest, Hilfe per Tastaturfokus, im Bild),
`region_travel` (am Haven-Waystone: „Travel“ zur Whispering Stone).

## 7. Offene Punkte für die gemeinsame Endabnahme

1. Maßstab der Gebietskarte (mind. 0,5) – lesbar genug, oder lieber mehr Übersicht?
2. Das Waystone-Symbol im Ortsknoten ist klein (16-px-Art 1:1); genügt es neben dem Text in der Detailzone?
3. Die Symbolzeile der Area ist kompakt; die Bedeutungen stehen in Tooltips und der Hilfe.
4. Reisen aus der Karte nur an einem wachen Waystone – passt das zur erwarteten Bedienung?
5. Kartenfenster zusammen mit Kampf-HUD und Außenreitern anderer Fenster; 75/125/150 % beim Entwickler.

## 8. Commit

- **`563fecc`**: `waystone_panel.gd` (gemeinsamer `start_travel`), `test_map_ux.gd` (+ `.uid`),
  `tests/playtest/map_ux_check.gd` (+ `.uid`), dieses Dokument. Ein Folge-Commit trägt diesen Abschnitt nach.
- **Bewusst uncommittet:** `scripts/ui/world_map_panel.gd` – die Hauptumsetzung. Die Datei enthielt schon vor diesem
  Batch die uncommittete Map-&-Fog-Arbeit und hängt von weiterhin untracked Dateien ab (`area_map.gd`,
  `map_markers.gd`, `map_painter.gd`); eine saubere Trennung ist nicht möglich. Ebenso `docs/MAP_AND_FOG_OF_WAR_1_0.md`
  (untracked, Ablösungshinweise) und `CLAUDE.md`.
- Der Commit allein ist nicht lauffähig (der Test braucht die neue `world_map_panel.gd`); lauffähig ist der Arbeitsbaum.
