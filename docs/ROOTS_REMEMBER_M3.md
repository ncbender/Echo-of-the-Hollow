# Chapter 1 – „The Roots Remember“ · M3 – Warden's Rest / Rootbound Sentinel

Branch `dev/roots-remember-m3` von `dev/roots-remember-m2` @ `4839a9f`. Keine neue KI-Architektur, kein neues globales
Kampfsystem, keine neue Save-Version (bleibt **v15**), keine Migration. Fremde Änderungen (`project.godot`, `docs/Design/`,
`docs/tasks/`) unberührt.

## 1. Technischer Boss-Check (Phase A)

| Frage | Befund im Code |
|---|---|
| Schwere, angekündigte Angriffe | Jede Gegnerfamilie hat `root_heavy`; `Enemy` wählt jeden n-ten Angriff schwer (`heavy_attack_interval`). Telegraph = `startup` der Angriffsdefinition, gezeichnet als sich füllender Kegel (rot/dicker bei Heavy) in `EnemyView`. Grove Warden / Grunt Slam: startup 0.7 / recovery 0.7 |
| Poise/Stagger/Defensive | `HealthComponent`: Poise, Stagger (`stagger_duration`), Regeneration. Gegner werden **nur** durch Poise-Bruch unterbrochen (`Enemy._on_poise_broken`). `AttackDefinition.uninterruptible_phases` wirkt nur über `HitReactionComponent` – das haben nur Spieler. Empfängerseitige Poise-Skalierung hat Präzedenz (`parry_poise_multiplier`, Item-Effekte) |
| Warden vs. Guardian vs. Husk | Grove Warden: Grunt-Werte (90 HP / 35 Poise, Szenen-Standard), Tempo 70, Knockback-immun, Slam unblockbar, Parry unterbricht nicht. Bastion Guardian (= Hardened Husk): 160 / 70, Tempo 50, jeder 2. Angriff schwer, KB-Resistenz 0.5. Rootbound Husk: 70 / 30, Tempo 58, nur leichte Angriffe |
| Grundlage | Bastion-Guardian-Profil (langsam, schwer, Heavy jedes 2. Mal) + eigene Angriffsfamilie mit längerem Windup/Recovery |
| Ohne neue KI? | Ja: Windup/Recovery/Tempo sind Daten. „Defensive Phase“ als kleinste lokale Variante (Abschnitt 4) |
| Einmalige Bosskills | Platzierter `Enemy` mit `persistent_id` → `GameMap._on_persistent_enemy_defeated` setzt `defeated.<id>`; `_remove_defeated_enemies` entfernt ihn bei späterem Laden |
| Reset / Verlassen / Tod | Karte verlassen oder laden → frischer Boss (volle HP). Spielertod → Respawn auf der Karte **ohne** Neuladen, Boss behält seine HP (bestehende Regel, unverändert). Kein Flag ohne echten Bosstod |
| Quest ↔ Defeat-Flag | Kein Story-Event für Kills. Lösung: Fundort existiert nur bei gesetztem Defeat-Flag (`StoryConditional`), sein Event ist kumulativ (Abschnitt 6) |

**Vorbestehender Befund (nicht behoben, außerhalb M3):** Platzierte Gegner bekommen ihr Ziel in `Enemy._ready` über die
Gruppe `player`; der Player tritt ihr erst in seinem eigenen `_ready` bei. In Karten, in denen `Enemies` vor `Player` steht,
bleibt `target == null` – geprüft im Whisper Forest: **Grunts und Grove Warden haben kein Ziel und greifen nie an**.
Encounter-Gegner sind nicht betroffen (`spawn_enemy` setzt das Ziel). Eine generische Korrektur (z. B. `GameMap` weist das
Ziel zu) würde Grove Warden und Whisper Forest verändern und bleibt einer eigenen Freigabe vorbehalten. In Warden's Rest
steht `Player` deshalb **vor** `Enemies` (reine Szenenreihenfolge, Y-Sortierung unverändert); ein Test sichert das Ziel ab.

## 2. Karte Warden's Rest

`scenes/maps/wardens_rest.tscn`, `data/world/maps/wardens_rest.tres` (Region `hollow_outskirts`, Zelle (4,1), Nachbar
`chapel`). 640×400, nur vorhandene Bausteine (`ArenaFloor`, `WallBlock`, `Readable`, `StoryConditional`, Grunt-Szene):

| Bereich | Inhalt |
|---|---|
| Alter Zugang | Erdpfad vom Westrand (Ankunft aus der Chapel) |
| Befestigung | Steinwall (Nord-/Südabschnitt bis an den Kartenrand) mit verfallenem Tor und zwei Turmstümpfen |
| Hof / Arena | ca. 330×300 px Steinboden mit Moosflächen, zwei sichtbare Säulenstümpfe als Deckung, sonst frei |
| Wächterstein | gespaltener Steinblock am Nordrand des Hofs, Wurzeln an beiden Seiten; davor startet der Sentinel |
| Wachhütte (optional) | eingestürzte Hütte im Nordosten (Pritsche, Waffengestell), **Scratched Tally** |
| Wurzelspuren | Wurzelrücken außen am Wall, am Südrand, an der Ostwand (Wurzelwand) |

Abstände: Ankunft → Sentinel 400 px, Tor → Sentinel 225 px (Aggro 200: Ankunft und Tor wecken ihn nicht), Ausgang → Arenarand
240 px (kein versehentlicher Kartenwechsel im Kampf; Boss verfolgt nur innerhalb seiner Aggro-Reichweite). Ostwand
geschlossen. Interaktionen vor dem Sieg: nur Scratched Tally.

## 3. Übergänge

- **Chapel-Ostweg geöffnet** (Muster des Whisper-Forest-Ostausgangs): `SealedEast` (Wurzelsperre + Hinweis „not yet“) solange
  `chapter1.chapel_waystone_examined` fehlt; `OpenEast/ToWardensRest` (332, −162) → `wardens_rest`/`from_chapel`, sobald es
  gesetzt ist. Das Flag setzt Schritt 2 beim Abschluss – jeder Stand ab Schritt 3 hat es.
- Zurück: `ToChapel` (−332, 0) → `chapel`/`from_wardens_rest` (282, −162).
- Weltkarte/Region: `chapel.neighbors` += `wardens_rest`; `map_ids` += `wardens_rest`.
- Prolog-Gate: Warden's Rest nur aus der Chapel (hinter dem Waystone-Flag), die Chapel nur aus der Tangled Wood, diese nur
  hinter `prologue.completed` (Topologietest über alle Kartenszenen). Haven-Tore, andere Übergänge, Wegsteine unverändert.

## 4. Rootbound Sentinel

Platzierter Grunt-`Enemy` mit eigener Config und Familie (Grove-Warden-Muster, aber eigene Identität: langsam, schwer, bremst).

`data/enemies/rootbound_sentinel.tres` (Referenzen: Bastion Guardian/Hardened Husk 160/70/50, Grove Warden):

| Wert | Sentinel | Referenz |
|---|---|---|
| HP / Poise | 200 / 80 | Guardian 160 / 70 (+25 % / +14 %) |
| Tempo | 42 | Guardian 50, Warden 70 |
| Aggro / Angriffsreichweite / Stopp | 200 / 32 / 20 | Guardian 240 / 28 / 18 |
| Cooldown / Heavy-Intervall | 1.3 s / jeder 2. | Guardian 1.2 / 2 |
| Knockback-Resistenz | 0.8 (Elite-Stufe) | Guardian 0.5, Warden 1.0 |
| Parry | unterbricht (Standard), Poise ×0.6 | Warden: unterbricht nicht |
| Rank | 2 (Boss-Leiste) | wie Bastion Guardian / Passage Alpha |
| Drops | 1 Hollow Essence + 4 Gold, keine Equipment-Tabelle | identisch Hardened Husk |

`data/enemies/sentinel_attacks.tres` (Familie `sentinel_roots`):

| Angriff | Startup / Active / Recovery | Schaden / Poise / KB | Reichweite / Bogen | Abwehr | Besonderheit |
|---|---|---|---|---|---|
| Sentinel Strike (leicht) | 0.55 / 0.1 / 0.55 | 12 / 12 / 5 | 32 / 90° | block- und parierbar | nie „braced“ |
| Sentinel Root Slam (schwer) | **1.0** / 0.12 / **1.3** | 22 / 25 / 14 | 38 / 120° | blockbar (nicht parierbar) | `uninterruptible_phases = Startup` |

Referenz Warden-Slam: 0.7 / 0.12 / 0.7, 20 Schaden. Der Sentinel-Slam ist länger angekündigt und lässt danach länger offen.

**Telegraph:** bestehender roter Heavy-Kegel, der sich über 1.0 s füllt, + Bracing-Ring.

**Defensive Phase (kleinste lokale Variante):** Neu `EnemyConfig.braced_poise_taken` (Standard 1.0 = jeder bestehende Gegner
unverändert). Während eine Angriffsphase in `uninterruptible_phases` liegt, nimmt der Gegner nur diesen Anteil an Poise-Schaden
(`Enemy._on_hit_received`, eine Skalierung beim Empfänger wie Parry-Poise). Sentinel: 0.4 im Slam-Windup. Ein normaler Treffer
stoppt den Slam nicht, genug Poise bricht ihn weiterhin (Stagger). Sichtbar als steinfarbener Ring (`EnemyView`,
nur wenn `Enemy.is_braced()` – kein bestehender Gegner hat eine solche Phase). Keine globale Poise-Regel geändert.

**Erholungsphase:** 1.3 s Recovery nach dem Slam, `move_multiplier = 0` (steht still), danach 1.3 s Cooldown. Neu
`EnemyConfig.recovery_cue` (Standard aus): Körper gedimmt + „...“ während der Recovery eines Heavy-Angriffs (`EnemyView`,
reine Darstellung).

## 5. Boss-Persistenz und Reset

- `persistent_id = wardens_rest_rootbound_sentinel` → Flag **`defeated.wardens_rest_rootbound_sentinel`** (Projektkonvention
  `GameMap.defeat_flag`).
- Neu `Enemy.defeat_milestone` (Standard aus): `GameMap._on_persistent_enemy_defeated` fordert beim **ersten** Setzen des Flags
  einen Meilenstein-Save an („boss defeated …“). Der Grove Warden bleibt beim bisherigen Weg (sein `BossRewardCache`).
- Später: kein Respawn (Kartenwechsel, Laden). Vor dem Sieg: Verlassen/Laden → frischer Sentinel; Spielertod → Respawn ohne
  Flag, Sentinel bleibt (bestehende Regel). Wiederholte Todessignale: kein zweiter Save.

## 6. Questschritte und Event-IDs (`the_first_signs`)

| Schritt | Beschreibung | Ziel | Flag |
|---|---|---|---|
| 0–2 | unverändert (M1/M2) | `enter:tangled_wood`, `interact:tangled_roots`, `interact:chapel_waystone` | unverändert |
| 3 | „Even the roots around the old waystone pull further east, toward a way choked with stone. Find a way through.“ | `enter:wardens_rest` (live) | `chapter1.wardens_rest_reached` |
| 4 | „Something rooted still keeps watch over the old post at Warden's Rest. Get past it and search the post.“ | `interact:wardens_rest_watchstone` (kumulativ, neu) | `chapter1.watchstone_examined` |
| 5 | „The roots have reached even the old watch post. Edrin should hear of this. Your journey continues in a future update.“ | – (M4-Platzhalter) | – |

`open_ended` bleibt, kein Nachfolger, kein Reward, kein Kapitelabschluss, Edrin unverändert.

**Soft-Lock-Sicherheit:** Der Fundort existiert nur bei gesetztem Defeat-Flag; sein Event zählt kumulativ. Sieg und Untersuchung
vor Schritt 4 (z. B. alter Stand mit Flag) werden beim Erreichen von Schritt 4 sofort angerechnet (live bzw. still über
`resettle`). Das Flag allein schaltet nichts weiter. Schritt 3 ist bewusst live: Warden's Rest ist erst ab Schritt 3 erreichbar.

## 7. Storyfundort

**Split Watchstone** (`Readable`, „Examine Split Watchstone“, Wurzel-Look, „?“ bis zur Untersuchung) vor dem gespaltenen Stein,
in `AfterSentinel` (`StoryConditional`, `required_flags = [defeated.wardens_rest_rootbound_sentinel]`). Vor dem Sieg ist nur der
Stein selbst sichtbar, ohne Prompt. Text: „An old marker stone of the watch post, split from top to bottom. Roots have forced
their way up through the crack. Like every root since the Tangled Wood, they lean east.“ – keine Ursache, kein Bewusstsein.
Einmal pro Charakter (`read.wardens_rest_watchstone`), keine Belohnung.

Optional: **Scratched Tally** in der Hütte („… The last row was never finished.“) – kein Event, keine Belohnung.

## 8. Save-Kompatibilität

Stände auf Schritt 0–3 (M1/M2) laden unverändert, `resettle` (3×, historische Zähler inkl. M1/M2, Grove-Warden-/Cache-Flags)
bewegt nichts; jeder läuft danach bis Schritt 4 weiter. Klassenwahl, Trials, Quest-Reward-Flags, Wegsteine, Grove Warden
unverändert. Neue Zustände generisch (`defeated.*`, `count.*`, `chapter1.*`, `read.wardens_rest_*`).

## 9. Gezielte Tests

`tests/integration/test_roots_remember_m3.gd` (14): Questdaten ab Index 3, Sentinel-Werte gegen Referenzen und unveränderte
Bestandsgegner, Stände Schritt 0–3, Soft-Lock (vor/nach Schritt, über Save), Schritt 5 einmalig, Topologie, Chapel-Weg öffnet
nach dem Waystone + beide Richtungen, Spawns/Prompts/sichere Ankunft/Ziel gesetzt, **Telegraph/Brace/Recovery in echten Frames**
(Windup 54–66, Recovery 72–84 Frames, still), Brace-Poise (voll im Leerlauf, ×0.4 im Windup, brechbar), einmaliger Sieg +
Meilenstein + Fundort + kein Respawn + Save/Load, Reset bei Verlassen/Tod/Laden, Sieg vor dem Schritt in der Szene, Tally.

Angepasst (M2-Endzustand, nicht Verhalten): `roots_remember_m2` – Schrittzahl/letzter Platzhalter, Chapel-Zugänge (+ Warden's
Rest), nur aktive Ausgänge, Ostweg geschlossen **vor** der Waystone-Untersuchung. `roots_m2_visual_check` prüft den Ostweg
entsprechend vor der Untersuchung.

Ergebnisse (headless): `roots_remember_m3` 14/14; mit `roots_remember_m1, roots_remember_m2, story, world, world_ui, enemy, hits,
defense, combat_feedback, economy, grove_warden_reward, hollowwood_loot`: **118/118** grün. Mutationsprobe
(`braced_poise_taken = 1.0`) → 2 Tests rot, zurückgesetzt. `check_project.ps1`: OK. Nicht gelaufen (Efficient Testing 1.1):
Full-Suite, Prolog-/Haven-/Loop-Playtests, Class-Trial-Läufe, Crafting/Arena/Galerie, `save`-Suites. `test_migration_v3_to_v4`
unberührt.

## 10. Visuelle Ergebnisse

`tests/playtest/roots_m3_visual_check.gd` im echten Fenster, **1920×1080 @ 100 %** und **1280×720 @ 150 %**, 30/30 Prüfungen OK,
Screenshots (`tests/output/roots_m3/`, nicht versioniert) angesehen. Bewegungsprüfung im laufenden Fenster (nicht nur
Standbild): Slam-Windup 60 Frames durchgehend braced, Recovery 78 Frames durchgehend „exposed“, Positionsänderung 0,7 px
(Körperkontakt mit dem danebenstehenden Spieler), Frame-Folgen 04a–c (Windup), 05 (aktiv), 06a/b (Recovery), 07 (leichter
Schlag ohne Ring). Außerdem: geöffneter Chapel-Ostweg, Ankunft, Übersicht (Wall, Tor, Hof, Säulen, Wächterstein, Hütte),
Fundort nach dem Sieg, Text, Tracker Schritt 5, Tally, Rückweg.
Korrigiert: „?“ des Fundorts lag auf dem Stein → Fundort 10 px nach unten. Bekannt/unverändert: Schadenszahlen können kurz über
dem Boss stehen (bestehendes FX).

## 11. Offene M4-Anschlüsse

- Schritt 5 ersetzen (nie vor Index 5 einfügen; Stände stehen auf 0–5): Rückkehr zu Edrin (neuer Dialog vorne in `edrin.tres`,
  Schrittbedingung), danach Abschluss (`open_ended` entfernen), `next_quest_ids`, optional Turn-in-Reward.
- Warden's-Rest-/Chapel-Wegsteine weiterhin `available = false`; Erweckung nur mit eigener Freigabe.
- Vorbestehender Befund „platzierte Gegner ohne Ziel“ (Abschnitt 1) – eigene Entscheidung, betrifft Grove Warden/Whisper Forest.
