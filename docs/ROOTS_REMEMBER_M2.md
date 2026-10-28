# Chapter 1 – „The Roots Remember“ · M2 – The Chapel / Lost Sanctuary

Branch `dev/roots-remember-m2` von `dev/roots-remember-m1` @ `322d1e7` (M1 abgenommen). Kein neues System, keine neue
Save-Version (bleibt **v15**), keine Migration. Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) unberührt.

## 1. Chapel-Karte

`scenes/maps/chapel.tscn`, `data/world/maps/chapel.tres`: **The Chapel** (`chapel`), Region `hollow_outskirts`, Kartenzelle
(3,1) östlich der Tangled Wood, Nachbar `tangled_wood`. Kanon gab nur „Chapel Waystone“ vor; „The Chapel“ ist der
Kartenname. Größe 640×400, ausschließlich vorhandene Bausteine (`ArenaFloor`, `WallBlock`, `Readable`, `StoryTrigger`,
`Encounter`, Old-Road-Baummuster):

| Bereich | Inhalt |
|---|---|
| Eingang (West) | Erdpfad von der Tangled Wood, alte **Markersteine** an den Wegrändern (Wegekennzeichnung), Mauerreste |
| Chapel | verfallener Steinbau mit Moos-Mauerkronen, Westtür, eingestürzte Nordlücke, zwei Bankreihen (eine Bank zerbrochen) beiderseits eines abgetretenen Mittelgangs, Moosflächen, Wurzeln an der Ostwand (Apsis) und am Nordrand |
| Chapel Waystone | in der Apsis am Ende des Mittelgangs (150, 0) |
| Nische (optional) | durch eine Lücke in der Südwand: alte Zufluchtsecke mit kalter Feuerstelle (Steinkreis), zwei Vorratskisten, Schlafstelle, **Faded Note** |
| Späterer Ostanschluss | Pfad nördlich um die Chapel bis zur Ostwand; Lücke dort durch Wurzeln (`SealedWay`) und zwei umgestürzte Steine verschlossen, einmaliger Hinweis `hint.chapel_east_way`: „Roots and fallen stone choke the old way east. It will not open - not yet.“ – kein Übergang, kein Interaktionsprompt |

Alle Kollisionen sind sichtbare Blöcke; Moos, Gang, Feuerstelle, Schlafstelle sind reine Bodenflächen. Keine Sammelknoten,
keine Checkpoints, keine Pickups. Interaktionen in der Karte: genau `ChapelWaystone` und `FadedNote`.

## 2. Tangled-Wood-Anschluss

- Ostwand der Tangled Wood geteilt (`EastRoots` → `EastRootsNorth`/`EastRootsSouth`), Lücke 48 px bei y 16…64 an der
  Südostecke der Lichtung (außerhalb der Reichweite der Twisted Roots).
- `ToChapel` (332, 40) → `chapel`/`from_tangled`, Label „The Chapel“; Rückkehr-Spawn `from_chapel` (286, 40).
- Chapel: `ToTangledWood` (−332, 0) → `tangled_wood`/`from_chapel`; Spawns `default`/`from_tangled` (−280, 0).
- Weltkarte: `tangled_wood.neighbors` += `chapel`; Region `map_ids` += `chapel`.
- **Prolog-Gate:** Die Chapel ist nur aus der Tangled Wood erreichbar, die Tangled Wood nur über den gesperrten
  Whisper-Forest-Ausgang (`EastPath`, `prologue.completed`) bzw. aus der Chapel. Das prüft ein Topologietest über **alle**
  Kartenszenen. Der neue Übergang selbst braucht deshalb keine eigene Bedingung. Keine anderen Transitions, Haven-Tore
  oder Wegsteine geändert.

## 3. Questschritte (`data/story/the_first_signs.tres`)

| Schritt | Beschreibung (Tracker) | Ziel | Flag |
|---|---|---|---|
| 0 | unverändert (M1) | `enter:tangled_wood` | `chapter1.tangled_wood_reached` |
| 1 | unverändert (M1) | `interact:tangled_roots` (kumulativ) | `chapter1.roots_examined` |
| 2 | „The roots all bend the same way, east past the Tangled Wood. Follow them and find what they are pulling toward.“ | `interact:chapel_waystone` (kumulativ, neu) – „Examine the old waystone at the chapel“ | `chapter1.chapel_waystone_examined` |
| 3 | „Even the roots around the old waystone pull further east, toward a way choked with stone. Your journey continues in a future update.“ | – (M3-Platzhalter) | – |

Keine Schritte vor Index 2. `open_ended = true` bleibt, kein `next_quest_ids`, kein Turn-in, kein Kapitelabschluss.
Schritt 3 verweist auf den sichtbar verschlossenen Ostweg, täuscht aber keine Interaktion vor (Tracker zeigt nur
Überschrift + Beschreibung, keine Zählerzeile).

**Warum kumulativ:** Die Chapel ist schon bei Schritt 1 erreichbar (Twisted Roots übersprungen). Wird der Waystone dann
untersucht, feuert sein einmaliges Event bei Schritt 1. Nicht kumulativ würde Schritt 2 danach nie erfüllt (Soft-Lock).
Kumulativ über eine **neue** ID: keine historischen Zähler, das frühe Ereignis wird beim Erreichen von Schritt 2 sofort
angerechnet (live bzw. still über `resettle`). Mutationsprobe bestätigt: nicht kumulativ → Soft-Lock-Test rot.

## 4. Neue Event-IDs

| Event | Quelle | Questziel |
|---|---|---|
| `interact:chapel_waystone` | `Readable` „Chapel Waystone“ – einmal pro Charakter (`read.chapel_old_stone`) | Schritt 2 |
| `enter:chapel` | `GameMap._ready` (jeder Besuch) | nein |
| `encounter:chapel_yard` | `Encounter._finish` | nein |

## 5. Chapel Waystone (M2-Vertrag)

- Ein **`Readable`** (`verb = "Examine"`, neuer `Look.WAYSTONE`), **kein** `Waystone`-Knoten: Silhouette und Riss wie ein
  stiller Waystone, Wurzeln um den Fuß, Label „Chapel Waystone (silent)“, „?“ bis zur Untersuchung.
- Text: „Roots have curled around the old waystone, tight as a closing hand. The stone is cold and silent. Every root that
  holds it strains toward the east.“ – keine Aktivierung behauptet, keine Ursache.
- `data/world/waystones/chapel_waystone.tres` **unverändert** (`available = false`, kein `map_id`): keine Schnellreise,
  kein Reiseziel, keine `waystone.*`-Flags, kein `waystone:`-Event, `world.waystones` unverändert (Tests).
- Wiederholte Untersuchung: Text erneut, kein zweites Event, keine Items.
- `Readable`-Erweiterung rückwärtskompatibel (Enum angehängt, alte Indizes gleich).

## 6. Optionale Entdeckung

**Faded Note** in der Nische (`Readable`, Notiz): „Kept the fire low and the door barred, as those before us did. Left what
bread we could spare for whoever comes next.“ Deutet den Zufluchtsort an; keine Fraktion, keine Religion, keine
Geschichte festgelegt. Kein Event, keine Belohnung, keine Quest, blockiert nichts.

## 7. Encounter

`ChapelYard` (`chapel_yard`) im Vorhof am Pfad, Radius 110: 2× Rootbound Husk + 1× Hollowfang Wolf. Pro Besuch
(`persistent = false`), keine Bedingung, **keine** Equipment-Tabelle (gemischte Gruppe wie `shrine_path`; feste
Config-Drops unverändert). Kein Boss, keine `persistent_id`, kein Pflichtkampf. Der Waystone hängt an keinem Encounter.
Arrival-Spawn liegt außerhalb des Triggers (150 px).

## 8. Save-/Altstand-Kompatibilität

- M1-Stände auf Schritt 0/1/2 laden auf denselben Schritt; `resettle` (3×, mit historischen Zählern inkl. M1-Zählern,
  Boss-/Cache-/Trial-Flags) bewegt nichts. Schritt 2 wird durch keinen alten Zähler übersprungen (neue ID).
- Ein M1-Stand auf dem alten Platzhalter (Schritt 2) erhält die neue Chapel-Aufgabe.
- Klassenwahl, Trials, Quest-Reward-Flags (Edrin pending, Mara claimed), Grove-Warden-Status bleiben unverändert;
  Warden besiegt oder nicht: Route unverändert.
- Neue Zustände sind generisch (`count.*`, `chapter1.*`, `read.chapel_*`, `hint.chapel_east_way`, Map-`visits`).

## 9. Gezielte Tests

`tests/integration/test_roots_remember_m2.gd` (13 Tests): Questdaten ab Index 2 (0/1 unverändert), Kartendaten,
Waystone-Definition unverändert + keine Schnellreise, Routentopologie über alle Kartenszenen, Schritt 2 einmalig,
frühe Untersuchung ohne Soft-Lock (live und über `resettle`), M1-Saves auf Schritt 0/1/2 mit historischen Zählern,
Save/Load nach Schritt 2/3, Prolog-Gate, Hin-/Rückweg Wood ↔ Chapel + wiederholte Wechsel + M1-Rückweg zum Forest,
Spawns frei und ohne falsche Prompts (nur zwei Interaktionen, nur ein Ausgang), verschlossener Ostweg, Waystone in der
Szene (3× → 1 Event, Save/Load in der Chapel), optionale Notiz, Encounter.

`roots_remember_m1`: drei Assertions, die „Schritt 2 = letzter leerer Platzhalter“ festschrieben, auf die weiter gültige
Invariante umgestellt (Schritte 0/1 unverändert, letzter Schritt ziellos, Spur führt nach Osten). Alle M1-Verhaltens-
prüfungen unverändert.

Ergebnisse (headless): `roots_remember_m2` 13/13; zusammen mit `roots_remember_m1, story, world, world_ui, old_road, shrine,
class_trials_m2`: 64/64 grün. Mutationsprobe (Schritt 2 nicht kumulativ) → 2 Tests rot, zurückgesetzt.
`check_project.ps1`: OK. Nicht gelaufen (Efficient Testing 1.1): Full-Suite, Prolog-/Haven-/Loop-Playtests,
Class-Trial-Läufe, Crafting/Arena, Galerie, `save`-Suites (Schema unverändert). `test_migration_v3_to_v4` unberührt.

## 10. Visuelle Ergebnisse

`tests/playtest/roots_m2_visual_check.gd` im echten Fenster, **1920×1080 @ 100 %** und **1280×720 @ 150 %**, synthetischer
Stand (Schritt 2). 22/22 Prüfungen OK; Screenshots (`tests/output/roots_m2/`, nicht versioniert) angesehen: Ostausgang der
Wood mit Label, Ankunft, Gesamtübersicht (Pfad, Ruine, Gang, Waystone, Nische, Ostweg), Vorhof-Encounter, Waystone-Prompt
und -Text, Tracker Schritt 3, Nische mit Notiz-Prompt, verschlossener Ostweg mit Hinweis, Rückweg. Keine Darstellungsfehler
gefunden, keine Korrekturen nötig. Bekannt/unverändert: Weltlabels werden vom HUD verdeckt, wenn sie unter einem Panel liegen.

## 11. Offener M3-Anschluss

- Schritt 3 ist der Platzhalter; M3 ersetzt ihn (nie vor Index 3 einfügen; Stände stehen auf 0–3).
- `SealedWay` (Chapel-Ostwand, y −186…−138) ist der vorbereitete Übergang Richtung Warden's Rest; Öffnen z. B. per
  `StoryConditional` (Muster Whisper-Forest-Ostausgang) mit einem M3-Flag.
- Chapel Waystone: Erweckung/Schnellreise erst mit einer bewussten Entscheidung (`available = true`, `map_id = chapel`,
  `Waystone`-Knoten statt `Readable`, Spawn `waystone`); der `read.chapel_old_stone`-Status bleibt davon unabhängig.
- Edrin weiterhin ohne Kapitel-Dialog (bewusst, Turn-in-Interaktion unverändert).
