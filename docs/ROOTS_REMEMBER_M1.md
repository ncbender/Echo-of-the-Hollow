# Chapter 1 – „The Roots Remember“ · M1 – The First Signs / First Playable Area

Branch `dev/roots-remember-m1` von `audit/ashen-trail-story-world-10` @ `0614190` (enthält `dev/npc-quest-turnins-11-m3`
@ `97dcd43`). Grundlage: `docs/ASHEN_TRAIL_STORY_WORLD_1_0_AUDIT.md` (§8–§10, Empfehlungen E1/E3/E5/E8/E9 umgesetzt:
Kapitelname bleibt, Zugang Whisper Forest Ost, `the_first_signs` wird ausgebaut, „the Hollow“ bleibt offen, Zugang erst nach
`prologue.completed`). Kein neues System, keine neue Save-Version (bleibt **v15**), keine Migration.

## 1. Neue Szene und Übergänge

| Element | Datei | Inhalt |
|---|---|---|
| Karte **The Tangled Wood** | `scenes/maps/tangled_wood.tscn`, `data/world/maps/tangled_wood.tres` | Region `hollow_outskirts`, Kartenzelle (2,1) östlich des Whisper Forest, Nachbar `whisper_forest` |
| Region | `data/world/regions/hollow_outskirts.tres` | `tangled_wood` in `map_ids` ergänzt |
| Weltkarte | `data/world/maps/whisper_forest.tres` | `neighbors` += `tangled_wood` (vor dem ersten Besuch nur „?“) |
| Ostausgang | `scenes/maps/whisper_forest.tscn` | Ostwand geteilt (`East` → `EastBottom`), Lücke 48 px im **oberen** Abschnitt (y −180…−132) |
| Übergang hin | `EastPath/ToTangledWood` (MapTransition) | → `tangled_wood` / `from_forest`, Label „Tangled Wood“ |
| Übergang zurück | `ToWhisperForest` (Westrand der neuen Karte, y = 0) | → `whisper_forest` / `from_tangled` |
| Spawns | `SpawnFromTangled` (262, −164) im Forest; `SpawnDefault`/`SpawnFromForest` (−280, 0) im Wood | beide frei von Wänden/Knoten (Test) |

Warum oben statt mittig: Der Grove Warden (Aggro 260 px) steht bei (260, 120). Lücke, Annäherung über den Nordrand und
Rückkehr-Spawn liegen außerhalb seiner Reichweite (Spawn 286 px). Der Warden ist damit **keine** Voraussetzung und wird
beim Rückweg nicht geweckt. Der HUD-Boss-Rahmen (Anzeige ab 340 px, `target_frame.gd`) kann am Ausgang sichtbar sein –
reine Anzeige, bestehendes Verhalten. Die normalen Grunts des Whisper Forest bleiben unverändert (Farmgebiet).

Keine vorhandenen Ausgänge entfernt, Haven-Tore und Wegsteine unverändert (Chapel Waystone/Warden's Rest weiter
`available = false`, keine Wegstein-Knoten in der neuen Karte).

## 2. Zugangsvoraussetzung

Nur über das vorhandene Muster des Haven-Nordtors (`StoryConditional` + `StoryTrigger`-Hinweis):

- `EastRoots` (`forbidden_flags = [prologue.completed]`): Wurzelbarriere (`WallBlock` 16×48 in der Lücke) + einmaliger
  Hinweis `hint.east_roots`: „A knot of roots has grown across the way east. There is no way through - not yet.“
- `EastPath` (`required_flags = [prologue.completed]`): der `MapTransition` existiert physikalisch nur danach
  (deaktivierte `StoryConditional`-Kinder sind unsichtbar und aus der Physik entfernt) – doppelte Sicherung.

Vor dem Prologabschluss: kein Kartenwechsel, Spieler bleibt vor der Barriere. Danach: Barriere weg, Übergang aktiv.

## 3. Questschritte (`data/story/the_first_signs.tres`)

Bestehende Quest erweitert, **keine** neue/parallele Quest, Schritt 0 bleibt Index 0:

| Schritt | Beschreibung (Tracker) | Ziel | Flag |
|---|---|---|---|
| 0 | „Edrin warned that the roots under the Hollowwood are moving. Follow the Whisper Forest east, deeper into the woods.“ | `enter:tangled_wood` (nicht kumulativ) – „Find the way east of the Whisper Forest“ | `chapter1.tangled_wood_reached` |
| 1 | „The roots grow wild in the Tangled Wood. Search it for a sign of what moves them.“ | `interact:tangled_roots` (kumulativ, neue ID) – „Examine the twisted roots“ | `chapter1.roots_examined` |
| 2 | „The roots all bend the same way, deeper into the woods. Your journey continues in a future update.“ | – (M2-Platzhalter) | – |

`open_ended = true` bleibt (nur der letzte Schritt ist ziellos, `validate_data`). Die Quest kann in M1 **nicht** abschließen,
kein `next_quest_ids`, kein Turn-in-Reward. Kapitel/Name/Beschreibung unverändert. Prologquests unverändert.

## 4. Event-IDs

| Event | Quelle | Hinweis |
|---|---|---|
| `enter:tangled_wood` | `GameMap._ready` (bei jedem Betreten) | zählt nur live ab Schritt 0; weitere Besuche ändern nichts |
| `interact:tangled_roots` | `Readable` „Twisted Roots“ (`event_id`) | feuert **einmal pro Charakter** (`read.tangled_twisted_roots`), wiederholtes Untersuchen zeigt nur den Text |
| `encounter:tangled_path_husks`, `encounter:tangled_hollow_wolves` | `Encounter._finish` | kein Questziel |

Kumulativ bei Schritt 1 ist bewusst: Die ID ist neu, Altstände haben keinen Zähler. Falls die Untersuchung je vor
Schritt 1 gezählt wurde, holt `resettle` den Schritt beim Laden still nach (ohne Toast/Save/Reward) und bleibt am
ziellosen Platzhalter stehen. Keine historischen Whisper-Forest-, Encounter- oder Boss-Zähler sind Questziele.

## 5. Storyhinweis

`Readable` mit neuem optionalem Verb und Look (rückwärtskompatibel, `scripts/world/readable.gd`):
`verb` (Standard „Read“ → alle bisherigen Prompts identisch), `Look.ROOTS` (an das Enum angehängt, alte Indizes gleich).

- **Twisted Roots** (Lichtung, Prompt „G Examine Twisted Roots“, „?“ bis zur Untersuchung): „Thick roots have torn up through
  the ground here, the earth around them still loose and damp. Every one of them bends the same way - east, deeper into the
  woods - as if something had dragged them there in the night.“
- **Gnawed Roots** (optionale Senke, ohne Event/Reward): „Something has gnawed these roots down to the pale wood. The marks are
  wider than any wolf's.“

Nur bestehende Motive (Hollowwood, sich bewegende Wurzeln, ungewöhnliche Kreaturen, Edrins Warnung). Keine Ursache, keine
neue Figur, kein Asche-/Glut-Motiv, „the Hollow“ bleibt ungeklärt.

## 6. Gebiet und Encounter

Kompakt (640×360 wie der Whisper Forest) aus vorhandenen Bausteinen (`ArenaFloor`, `WallBlock`, Old-Road-Baum-Muster):
dunklerer Waldboden, Erdpfad West → Biegung nach Norden um einen Wurzelwall → Lichtung im Osten; Wurzelrücken als
Leitmotiv, Ostrand als Wurzelwand (geschlossen, M2-Anschluss). Optionale **Senke** im Süden (Wandlücke, Muster der
Whispering-Stone-Seitenfläche). Keine Sammelknoten, keine Checkpoints, kein Wegstein.

| Encounter | Gegner | Typ | Loot |
|---|---|---|---|
| `PathHusks` (`tangled_path_husks`) am Nordpfad, Radius 110 | 2× Rootbound Husk | pro Besuch (`persistent = false`), keine Bedingung | keine Equipment-Tabelle (feste Config-Drops: 2 Gold) |
| `HollowWolves` (`tangled_hollow_wolves`) in der Senke, Radius 90 | 2× Hollowfang Wolf | pro Besuch, keine Bedingung | `hollowwood_wolves_equipment` – exakt das SideWolves-Muster (ein Wurf je Abschluss) |

Keine neuen Gegnertypen/KI, kein Boss, keine `persistent_id`, keine garantierten Rare/Magic-Rewards. Die Untersuchung
hängt an keinem Encounter.

## 7. Altstand-Kompatibilität (v15, keine Migration)

- Alle Stände nach dem Prolog (inkl. v4→v5-migrierter) haben `the_first_signs` `active`/Schritt 0/`{}` → sie erhalten
  **dieselbe** erste Aufgabe wie ein neuer Spieler. Kein Neu-Initialisieren (`StoryService.start` ist No-op), keine
  Doppelaktivierung.
- `resettle` bei Schritt 0: Ziel nicht kumulativ, Fortschritt leer → keine Bewegung, auch mit hohen historischen Zählern.
  Am Platzhalter (Schritt 2) kein Ziel → nie abgeschlossen.
- Klassenwahl, Trials, Quest-Reward-Flags (Edrin pending, Mara claimed), Boss-/Cache-Flags bleiben unverändert.
- Neue Zustände sind generisch: `count.*`, `chapter1.*`, `read.tangled_*`, `hint.east_roots`, `hint`/Map-`visits`.

## 8. Gezielte Tests

`tests/integration/test_roots_remember_m1.gd` (12 Tests):
Questdaten (Stub erweitert, IDs exklusiv, Kette/Flags des Prologs unverändert), Kartendaten/Region/Wegsteine,
Prologabschluss live → Schritt 0, Schritte nur über eigene Events und je genau ein `story_progressed`, `resettle`
(Schritt 0 mit historischen Zählern, Platzhalter mit Zählern 99), Legacy-Payload Schritt 0 (echte v15-Datei),
Save/Load nach jedem Schritt + kumulatives Nachholen, echte Karten: Sperre vor dem Prolog (kein Wechsel, Hinweis),
Hin-/Rückweg zu Fuß + wiederholte Wechsel, Spawns frei/außerhalb Warden-Aggro/ohne Sammel-Prompt, Untersuchung in der
Szene (3× → 1 Event, Save/Load in der neuen Karte), Encounter-Integration.

Ergebnisse (headless, `run_tests.ps1`):
- `roots_remember_m1`: 12/12 grün. Mutationsprobe: `EastPath` mit Sperrbedingung → 2 Tests rot; zurückgesetzt.
- Abhängigkeiten: `story, world, world_ui, old_road, shrine, hollowwood, hollowwood_loot, grove_warden_reward,
  class_trials_m2`: 67/67 grün; nach den visuellen Korrekturen `roots_remember_m1, world`: 19/19 grün.
- `check_project.ps1`: OK (Import + 300 Frames, keine Fehler/Warnungen).
- Nicht gelaufen (bewusst, Efficient Testing 1.1): Full-Suite, Prolog-/Haven-/Loop-Playtests, Class-Trial-Läufe,
  Crafting/Arena, Galerie, `save`-Suites (Schema unverändert). Bekannter Altfehler `test_migration_v3_to_v4` unberührt.

## 9. Visuelle Prüfung

`tests/playtest/roots_m1_visual_check.gd` im echten Fenster (1600×900, `--fixed-fps 60`), Screenshots
`tests/output/roots_m1/` (nicht versioniert). 12/12 Prüfungen OK, Screenshots angesehen:
Wurzelbarriere + Hinweis (Prolog), offener Ausgang mit Label, Ankunft, Gesamtübersicht, Husks am Pfad, Prompt
„Examine Twisted Roots“, Text, Tracker-Platzhalter, Wölfe in der Senke, Gnawed Roots, Rückkehr (Warden bleibt stehen,
kein Interaktionsprompt). Korrigiert: Rückkehr-Spawn lag auf dem Ancient Ore Deposit (Sammel-Prompt) → (262, −164);
Nahtstelle Pfad/Lichtung → Lichtung bis y −90. Kein kompletter Prolog-Playtest.

## 10. Offene M2-Anschlüsse

- Schritt 2 von `the_first_signs` ist der Platzhalter; M2 ersetzt ihn durch ein echtes Ziel und hängt ggf. weitere Schritte an
  (nie vor Index 2 einfügen; Altstände stehen auf 0, 1 oder 2).
- Ostrand der Tangled Wood (Wurzelwand) als nächster Übergang (z. B. Chapel-Umfeld, Chapel Waystone).
- Edrin hat weiterhin keinen Kapitel-Dialog (bewusst: kein Eingriff in die Turn-in-Interaktion); ein Dialog müsste vorne in
  `edrin.tres` mit Schrittbedingung stehen (Audit §9 R8).
- Abschluss, Folgequest, Turn-in-Reward erst in späteren Meilensteinen (`open_ended` dann entfernen).
- Alte Doku (`PROLOGUE_AND_HAVEN.md`: „The First Signs“ als Stub) nicht angepasst – außerhalb des M1-Umfangs.
