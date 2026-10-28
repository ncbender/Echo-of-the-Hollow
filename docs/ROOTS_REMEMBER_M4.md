# Chapter 1 – „The Roots Remember“ · M4 – The First Signs / Return to Edrin

Branch `dev/roots-remember-m4` von `fix/whisper-forest-enemy-targets` @ `eab43bf` (enthält M3 `2ff3a6b` und den Target-Fix).
Nur Daten (Quest, NPC-Dialog, eine neue Quest) – kein Code, keine neue Dialog- oder Queststatus-Architektur, keine Save-Version
(bleibt **v15**), keine Migration. Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) unberührt.

## 1. Edrins neuer Dialog

`data/npcs/edrin.tres`: **`edrin_first_signs_report`**, als **erster** Eintrag der Dialogliste (erster passender gewinnt).

| Feld | Wert |
|---|---|
| Bedingung | `the_first_signs` **aktiv** und Schritt **genau 5** (`min_step = max_step = 5`) |
| `repeatable` | `false` – nach dem Lesen nie wieder angeboten |
| `event_id` | `talk:edrin_first_signs_report` (neu, sonst nirgends verwendet) |

Zeilen (6): Spieler – Wurzeln in der Tangled Wood weisen nach Osten; ruhender, umwurzelter Waystone an der Chapel; Edrin fragt
nach; Spieler – Wachposten, „Something rooted stood guard there“, gespaltener Stein, dieselben Wurzeln nach Osten; Edrin – „no
single patch of sick ground … reaches further than I feared“; „I can't tell you what waits at the end of that pull …“. Keine
Ursache, kein Hollow, keine Fraktion.

Bestehende Dialoge (`edrin_threat`, `edrin_intro`, `edrin_early`, `edrin_shrine_hint`), Idle-Zeilen und der Service
`quest_rewards` bleiben unverändert (Reihenfolge dahinter gleich).

## 2. Questabschluss und Schutz

`data/story/the_first_signs.tres`: Schritte 0–4 unverändert. Schritt 5 („… Return to Haven and tell Edrin Vale what you found.“)
erhält das Ziel `talk:edrin_first_signs_report`, **nicht kumulativ**. `open_ended` entfernt, `completion_flag =
chapter1.the_first_signs_completed`, `next_quest_ids = [beyond_the_roots]`, kein `turn_in_*`.

Abschluss genau einmal, nur über den vorhandenen Dialogpfad: `DialoguePanel` ruft `DialogueService.finish` erst nach der letzten
Zeile → `dialogue.edrin_first_signs_report` + `StoryService.notify` → `_settle` (live) schließt die Quest ab, startet den Nachfolger.

| Situation | Ergebnis |
|---|---|
| Edrin ansprechen / Dialog vorzeitig schließen | nichts (Dialog wird erneut angeboten) |
| Service-Fenster, Haven betreten, Laden | nichts |
| Sentinel-Flag, Split Watchstone | nur bis Schritt 5 (M3), nie Abschluss |
| `resettle` vor dem Gespräch, auch mit `count.talk:edrin_first_signs_report = 3` | nichts (Ziel nicht kumulativ → zählt nur live im Schritt) |
| Wiederholtes `finish` / `resettle` danach | kein zweiter Abschluss, Nachfolger einmal (`StoryService.start` ist No-op) |
| Dialog vor Schritt 5 | nicht angeboten (Bedingung), Edrin öffnet direkt Quest Rewards |

Ein Soft-Lock (Flag gesetzt, Quest noch Schritt 5) ist nicht erreichbar: der Dialog wird nur bei Schritt 5 angeboten, und sein
Event erfüllt im selben Aufruf das Ziel. Sentinel besiegt + Watchstone schon untersucht → M3-Nachholung erreicht Schritt 5,
der Bericht ist verfügbar (Test).

## 3. Nachfolger

`data/story/beyond_the_roots.tres` – **`beyond_the_roots`**, „Beyond the Roots“ (technischer Platzhalter, keine Kapitelüberschrift;
`chapter = "Main Quest"` als Kennzeichnung im Tracker/Journal). Ein zielloser Schritt: „The trail continues beyond Warden's Rest.
Further story content is not yet available.“ `open_ended`, kein Nachfolger, keine Belohnung, keine Gebiete/NPCs/Reisen.
Vorab geprüft: keine vorhandene Quest-ID, Kapitel-2-Planung oder Namenskollision im Repo.

## 4. Edrins Reward-Service und Belohnungen

Keine Questbelohnung für `the_first_signs`/`beyond_the_roots`: `QuestRewardService.register_completion` setzt bei Quests ohne Gold
und Materialien kein Entitlement – kein Code geändert. `the_first_binding` bleibt 60 Gold.

`StoryNpc.interact` (unverändert): ungehörter Dialog vor dem Service. Bei Schritt 5 zeigt Edrin „!“ (vor dem „?“ einer offenen
60-Gold-Belohnung), G öffnet den Bericht; danach „?“ und G öffnet Quest Rewards mit genau „The First Binding · 60 Gold“, Claim
genau einmal.

## 5. Save-/Altstand-Kompatibilität

Stände auf Schritt 0–5 laden auf denselben Index; `resettle` (3×, mit historischen Zählern anderer Edrin-Gespräche) bewegt
nichts; der Bericht wird nur bei Schritt 5 angeboten. Save/Load vor und nach dem Gespräch korrekt (Abschluss, Dialog-Flag,
genau ein Nachfolger). Klassenwahl, Trials, Mara-/Edrin-Rewards, Grove-Warden- und Sentinel-Flags, ruhende Wegsteine unverändert.

## 6. Gezielte Tests

`tests/integration/test_roots_remember_m4.gd` (8): Quest-/Dialogdaten (Schritte 0–4, Priorität, Event exklusiv, Edrins
Dialogreihenfolge, Service, 60 Gold), Bericht nur bei Schritt 5, einmaliger Abschluss + ein Nachfolger + Tracker, Stände 0–5
inkl. Dialogzähler, Sentinel/Watchstone früh erledigt, Save/Load vor/nach, **echter Edrin in Haven** (Story vor Service, vorzeitiges
Schließen, Lesen bis zum Ende, danach Quest Rewards, exakt 60 Gold einmal), Edrin vor Schritt 5.

Angepasst (bisheriger Endzustand, nicht Verhalten): `roots_remember_m1/m2/m3` – „offen / ohne Nachfolger / letzter Schritt ohne
Ziel“ durch „letzter Schritt nur über Live-Event, höchstens ein Nachfolger, keine Belohnung“; `story` – Questkette endet jetzt mit
`beyond_the_roots`.

Ergebnisse (headless): `roots_remember_m4` 8/8; mit `roots_remember_m1–m3, story, quest_turnin_t1, t2, t3, quest_turnin_mara,
quest_turnin_mara_ui, quest_turnin_mixed_rewards, hud, menus_ui, save_foundation`: **154/154** grün. Mutationsprobe (Schritt-5-Ziel
kumulativ) → 2 Tests rot, zurückgesetzt. `check_project.ps1`: OK. Nicht gelaufen (Efficient Testing 1.1): Full-Suite,
Prolog-/Haven-Loops, Class-Trial-Läufe, Crafting/Arena/Galerie. `test_migration_v3_to_v4` unberührt.

## 7. Visuelle Ergebnisse

`tests/playtest/roots_m4_visual_check.gd` in Haven, echtes Fenster, **1920×1080 @ 100 %** und **1280×720 @ 150 %**, 18/18 OK,
Screenshots (`tests/output/roots_m4/`) angesehen: Edrin bei Schritt 4 („?“, Quest Rewards), bei Schritt 5 („!“), Bericht Zeile 1/4/6,
Tracker nach dem Abschluss („Main Quest: Beyond the Roots … not yet available“, Toast „Quest complete: The First Signs“,
„Progress saved“), Journal (Beyond the Roots aktuell; nach Scrollen „The Roots Remember · The First Signs · Completed“ ohne
Rewardzeile, The First Binding mit offenen 60 Gold), Quest Rewards nach dem Bericht (nur The First Binding, 60 Gold). Keine
Darstellungsfehler, keine Korrekturen.

## 8. Offene Folgekapitel-Fragen

- Inhalt und Name des nächsten Abschnitts (ersetzt den Schritt von `beyond_the_roots`; nie vor Index 0 einfügen – Stände stehen dort).
- Rolle und Erweckung von Chapel Waystone / Warden's Rest (weiter `available = false`).
- Ob Kapitelabschlüsse künftig Belohnungen tragen (bewusst keine in M4).
- Weitere Kapitel-Dialoge bei Mara/Edrin nach dem Abschluss (derzeit nur Idle-Zeilen/Service).
- Bekannt: Der Tracker zeigt bei offener First-Binding-Belohnung weiterhin „Return to Edrin Vale for your reward.“ neben der
  Kapitelzeile (bestehendes Turn-in-Verhalten).
