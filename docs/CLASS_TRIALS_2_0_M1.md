# Class Trials 2.0 – M1: Trial Progression & Save Safety 1.0

Stand: 2026-10-28 · Branch `dev/class-trials-20-m1` · Save **v14 (unverändert)**
Grundlage: `docs/CLASS_TRIALS_2_0_TECH_AUDIT.md` (§E, §G M1).

## Regeln

- **Ein bestandener Trial genügt** für den Story-Schritt „Walk an echo“ (`the_whispering_stone`, Schritt 1).
- Endgültig wählbar ist **nur eine Klasse, deren eigener Trial bestanden ist**
  (`PrologueService.can_choose`, Fehler „Walk the echo of this path first.“). Ein fremder Trial öffnet keine Klasse.
- Weitere Trials bleiben vor der Wahl freiwillig (`can_begin_trial` unverändert); nach der Wahl sind keine Trials mehr möglich.
- Die Wahl bleibt einmalig und dauerhaft; Klassenidentität bleibt `prologue.chosen_class`.
- Trial-IDs `trial_warrior`, `trial_arcanist`, `trial_shadowrunner` und gespeicherte `completed_trials` bleiben gültig.

## Soft-Lock: Ursache und Fix

**Ursache.** `StoryService._settle` lief nur bei `start` oder wenn ein Event ein Ziel des **aktuellen** Schritts berührte.
Ein Altstand mit 1–2 Trials stand nach der Regeländerung auf Schritt 1, dessen kumulatives Ziel bereits erfüllt war – aber
ohne neues `trial_complete` wurde er nie abgeschlossen. War die Klasse schon gewählt, kam auch kein Trial mehr; das
`class_chosen`-Ereignis war (nicht kumulativ) verloren → Flag `prologue.first_class_selected` fehlte → Wegstein gesperrt.

**Fix.**
1. `StoryService.resettle(character)` (`scripts/rpg/quests/story_service.gd`): wertet alle **aktiven Story-Quests** erneut über
   den vorhandenen `_settle`-Weg aus. Neu ist nur ein Parameter `announce` (Default `true`) an `_settle`/`start`; mit
   `false` werden weder `story_progressed` noch `quests.changed` gesendet → kein Meilenstein-Save, kein Toast, kein HUD-Event.
   Idempotent (ein zweiter Aufruf ändert nichts), Klassenquests werden übersprungen (keine Story-Definition).
2. Aufruf einmal in `Character.from_dict` nach `world.from_dict` (Zähler/Flags sind geladen).
3. Daten: das Wahl-Ziel `class_chosen` in `data/story/the_whispering_stone.tres` ist jetzt `cumulative = true`. Der Zähler
   `count.class_chosen` wird von `StoryService.notify` seit jeher immer geschrieben, daher auch in bestehenden Saves vorhanden.

## Geänderte Dateien

| Datei | Änderung |
|---|---|
| `scripts/rpg/quests/story_service.gd` | `resettle`, `announce`-Parameter an `start`/`_settle` |
| `scripts/rpg/character.gd` | `StoryService.resettle` nach dem Laden |
| `scripts/rpg/prologue/prologue_service.gd` | `can_choose`: eigener Trial statt „alle drei“; Kopfkommentar |
| `data/story/the_whispering_stone.tres` | Echo-Ziel `amount` 3 → 1 (Default), Schritttext, Wahl-Ziel kumulativ |
| `scripts/ui/class_choice_panel.gd` | Karten ohne eigenen Trial: „Locked (walk its echo)“, deaktiviert; `choosable_classes()`; Intro-/Statustexte |
| `scripts/ui/objective_panel.gd` | Prolog-Hinweis „Walk a class trial … (n/3 walked)“ |
| `scripts/world/class_choice_station.gd` | Kommentar |

UI und Service prüfen beide: Der Knopf wird über `can_choose` gesperrt, und `ClassChoicePanel.choose` ruft vor jeder Aktion
`can_choose` auf; `choose_starting_class` prüft erneut.

## Save-Version und Altstände

Keine neue Save-Version, keine Migration: vorhandene Daten (`completed_trials`, `count.trial_complete`, `count.class_chosen`)
reichen. Verhalten beim Laden:

| Altstand | Ergebnis |
|---|---|
| 0 Trials, Schritt 1 | unverändert |
| 1–2 Trials, Schritt 1 (alte Regel) | → Schritt 2 („Choose your path“), keine Klasse gewählt |
| 1–3 Trials + Klasse gewählt, Schritt 1 hängt | → Schritt 3 (Wegstein), Flag `prologue.first_class_selected` gesetzt |
| Prolog fertig / migriert v4→v5 | unverändert |
| Laufender Trial im Save | wie bisher: wird nie gespeichert |

## Tests (gezielt)

Neue Suite `tests/integration/test_class_trials_m1.gd` (nur synthetische Dicts über `to_dict`/`from_dict`, keine Dateien;
der Panel-Meilenstein-Save wird auf `user://test_saves/class_trials_m1/` umgelenkt und verworfen):
Soft-Lock-Wiederherstellung, Idempotenz/keine Signale, kein Trial → keine Klasse, je ein Trial → nur diese Klasse (Panel + Service,
fremde Klasse direkt abgelehnt), zwei/drei Trials, optionale weitere Trials, Save/Load mit 0–3 Trials, alte Saves mit 1/2 Trials
(mit und ohne gewählte Klasse), fertiger Prolog unverändert, Trial-IDs/Waffenfamilienrechte unverändert, Wegstein und
`the_first_binding` erreichbar.

Angepasste Erwartungen in `test_prologue.gd`, `test_shrine.gd`, `test_story.gd` (ein Trial schließt Schritt 1 sofort ab).

Lauf: `run_tests.ps1 -Suite "class_trials_m1,story,prologue,shrine"` → 35 bestanden, 1 fehlgeschlagen:
`test_prologue.gd::test_migration_v3_to_v4` (erwartet Item-Dict ohne `rarity`). **Vorbestehend**: schlägt auf `b1b2069`
identisch fehl (Loot Foundation 1.0 fügte `rarity` hinzu), unabhängig von M1, nicht angefasst.

## Offene Risiken

- Saves mit gewählter Klasse, aber `count.class_chosen = 0` (nur über Debug/Playtest-Code, z. B. `class_playtest.gd` setzt
  `chosen_class` direkt) bleiben auf Schritt 2 stehen. Kein regulärer Spielweg erzeugt diesen Zustand.
- `resettle` schließt generell jeden aktiven Schritt ab, dessen Ziele schon erfüllt sind (auch andere kumulative Ziele wie
  `restore:old_smithy`, `interact:supply_crate`). Das ist das bestehende `_settle`-Verhalten, nur nach dem Laden.
- Nachgezogene Schritte erzeugen beim Laden keine Meldung und keinen Save; der Zustand landet im nächsten regulären Save.
- Pedestale, unendliche Wellen und persistente Trial-Nebenprodukte (Gold, Mastery-XP) bestehen weiter (M2/M3, Audit §D).

## Ausdrücklich unverändert

Trial-Karten/Portale, Pedestale (`TrialStation`), Gegner/KI, Drops/Mastery, Hearth Flask, Trial-Loadouts/-Builds,
Magic-Klassenbelohnung, Grove-Warden-Rare, NPC-Abgaben, Gold-/Materialwerte, Waffenfamilien- und Schildrechte,
Dialoge/Weltobjekte, `SaveSystem.VERSION`/Migrationen, `choose_starting_class`, `can_begin_trial`, Wegstein-Bedingung,
`the_first_binding`.
