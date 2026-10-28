# Class Trials 2.0 – M4: Magic Class Reward 1.0

Branch `dev/class-trials-20-m4` (von `c474c1a`). Trial-Balance, TrialGate, Gegner, reguläre Drops: unverändert.

## Reward-Anspruch und Claim-Zustände
`PrologueState.class_reward` (gespeichert unter `prologue.class_reward`, Save v15):

| Zustand | Bedeutung | Übergang |
|---|---|---|
| `none` | kein Anspruch (Standard, neue Charaktere, unbelegte Altstände) | → `pending` nur durch `PrologueService.choose_starting_class` |
| `pending` | Anspruch besteht, Waffe noch nicht abgeholt | → `claimed` nur durch `PrologueService.claim_class_reward` |
| `claimed` | Waffe übergeben | Endzustand |

- Der Anspruch entsteht **nur** in `choose_starting_class`, nach allen Prüfungen von `can_choose`, im selben Aufruf, der
  `chosen_class` und `stage = completed` setzt, und nur aus `none`. Die Wahl läuft nie zweimal (`can_choose`), also gibt es nie
  einen zweiten Anspruch.
- Keinen Anspruch erzeugen: Trial-Start, Trial-Abbruch oder -Abschluss, Besuch der Trial-Grounds (Preview), temporäre
  Trial-Klasse, Debug-Klassenwechsel (`classes.unlock/set_active`), ein wiederholtes `class_chosen`-Story-Ereignis, abgelehnte
  Wahlen (fremde, ungültige Klasse, Klasse ohne eigenes Echo).
- Ein unbekannter gespeicherter Zustand wird beim Laden mit Warnung zu `none`. Ein Anspruch wird nie geraten.

## Claim am Heart of the Stone
`ClassChoicePanel` (Altar of Choice) zeigt nach der Wahl im `UiWindow.footer` den Status und die Aktion **„Receive the stone's
gift“** (`UI_CLASS_REWARD_CLAIM`). Danach steht dort „Gift received“ (deaktiviert). Wahl und Abholung sind getrennte Aktionen;
die Wahl selbst legt kein Item an. Nach erfolgreicher Abholung fordert das Panel einen Meilenstein-Save an (`request_critical_save`).

`PrologueService.claim_class_reward(character, rng, claimed)`:
1. `can_claim_class_reward` prüft: Zustand `pending`, keine laufende Trial, gültige gewählte Prolog-Klasse mit Reward-Item,
   Platz in der Tasche (`Inventory.room_for(model) ≥ 1`). Bei einem Fehler wird nichts erzeugt und nichts verändert.
2. `ItemCreation.generate(model, Magic, db, rng, class_reward_tier_weights, 5, ORIGIN_QUEST)` erzeugt **eine** Instanz.
3. Die Instanz geht unverändert über `Inventory.add_instance` in die Tasche. Erst danach wird `class_reward = claimed` gesetzt.
   Scheitert das Einfügen trotzdem, bleibt der Zustand `pending` und die Instanz wird verworfen (sie existierte nur im Speicher).

**Atomarität:** Tasche und Claim-Zustand ändern sich im selben synchronen Aufruf. Der Save-Snapshot (`SaveCoordinator`) sieht
also entweder beides oder keines. Ein Absturz vor dem nächsten Save führt zurück auf `pending` ohne Waffe. Es gibt nie Waffe +
`pending` (doppelter Claim) und nie `claimed` ohne Waffe.

## Klassen-Waffen-Zuordnung (Daten)
`ProgressionRules` (Gruppe Prologue, `data/progression/progression_rules.tres`):

| Klasse (`prologue.chosen_class`) | Modell |
|---|---|
| warrior | `steel_greatsword` |
| arcanist | `oak_staff` |
| shadowrunner | `iron_dagger` |

Weitere Felder: `class_reward_rarity = MAGIC`, `class_reward_item_level = 5` und `class_reward_tier_weights =
data/loot/hollowwood_early_tiers.tres`. Das ist die freigegebene frühe Hollowwood-Tabelle, die auch der Crafting-Pool nutzt:
bei ilvl 1–9 nur T5. Das Modell kommt **ausschließlich** aus `prologue.chosen_class`. Aktive Klasse und ausgerüstete Waffe
spielen keine Rolle. `GameDatabase.validate` prüft, ob jede Prolog-Klasse ein generierbares Reward-Item hat und die Tabelle
ilvl 5 abdeckt.

## Affix- und Item-Level-Vertrag
- Keine Sonderregeln, kein eigener Roller. Anzahl aus `ItemCreation.AFFIX_COUNTS[MAGIC]` = 1/2/3 zu 40/40/20. Identität, Tier und
  Wert über `AffixRoller.roll_one` mit den `generation_affixes` des Modells, inklusive LOCAL. Eligibility, Gruppen, Exclusion und
  Familie gelten unverändert.
- ilvl 5: Die Tabelle gibt nur T5 frei. Essenzen (auch Monster-Essenzen) setzt `generate` nie, `essences` bleibt leer.
- Die Waffenbasis wird einmalig über `ItemCreation.create` → `WeaponDamage.base_for_level(model, 5)` gespeichert. Am Modell ändert
  sich nichts.
- Herkunft `quest_reward` (`ItemInstance.ORIGIN_QUEST`, vorhandene Konstante).

Beispiele (feste Seeds, `claim_class_reward`):

| Klasse | Seed | Item | Basis | Affixe |
|---|---|---|---|---|
| warrior | 1 | steel_greatsword Magic ilvl 5 | 23.056 | Striking T5 +0.9 Weapon Damage (local) |
| warrior | 2 | steel_greatsword Magic ilvl 5 | 23.056 | Keen T5 +0.9 Crit %, Bloodthirsty T5 +1 Life on Hit |
| warrior | 3 | steel_greatsword Magic ilvl 5 | 23.056 | Executioner's T5 +7 Heavy Finisher %, Striking T5 +0.7 (local) |
| arcanist | 1 | oak_staff Magic ilvl 5 | 13.624 | Striking T5 +0.5 (local) |
| arcanist | 3 | oak_staff Magic ilvl 5 | 13.624 | Executioner's T5 +7 %, Striking T5 +0.4 (local) |
| shadowrunner | 2 | iron_dagger Magic ilvl 5 | 9.432 | Keen T5 +0.9 Crit %, Bloodthirsty T5 +1 Life on Hit |

Der Test mit 60 festen Seeds erreicht 1, 2 und 3 Affixe. Dabei gibt es keine statistischen Grenzen.

## Volles Inventar
`room_for(model) < 1` → „Your bag is full. Make room to receive the stone's gift.“ Der Knopf ist deaktiviert, der Grund steht als
Tooltip und als Statuszeile da. Der Anspruch bleibt `pending`, auch über Save/Load. Es wird keine Instanz erzeugt, nichts
gedroppt und keine Wahl zurückgenommen. Ist wieder Platz in der Tasche, funktioniert der Claim normal.

## Save/Load und Altspielstände
- **Save v15** (`SaveSystem.VERSION` 14 → 15, Schritt `_v14_to_v15`). Das ist technisch begründet:
  (a) Laut Projektregel braucht jede Schemaänderung Version + Migration + Tests.
  (b) Ein älterer Build würde einen v15-Stand ablehnen, statt `class_reward` stillschweigend zu verwerfen und einen offenen
  Anspruch beim nächsten Speichern zu verlieren.
  (c) Die Migration legt die Altstand-Regel ausdrücklich fest.
- **Nachweis echter Wahl:** Der Story-Zähler `world.flags["count.class_chosen"]` wird nur von `choose_starting_class` (über
  `StoryService.notify`) geschrieben. Keine Migration setzt ihn: 4→5 setzt nur `count.trial_complete` und
  `count.interact:supply_crate`.
  - v5–v14-Stand mit Zähler ≥ 1, `stage completed` und gültiger Prolog-Klasse → `pending`. Der Spieler hat die Wahl nachweislich
    am Altar getroffen.
  - **Kein Anspruch (`none`):**
    - Klasse aus alten Unlocks abgeleitet (v3→v4)
    - Wahl aus der v4-Zeit ohne Story-Zähler, nicht von abgeleiteten Klassen unterscheidbar
    - fehlender oder fehlerhafter Zähler
    - ungültige oder fehlende Klassen-ID
    - unfertiger Prolog
    - Stand ohne Klassenwahl
  - Ein vorhandener `class_reward`-Wert wird nie überschrieben. Ohne `prologue` wird nichts ergänzt.
- Die Instanz (Rarity, ilvl, Basis, Affixe, Herkunft) wird über das bestehende `ItemInstance.to_dict/from_dict` gespeichert und
  nie neu gewürfelt.

## Konkrete Änderungen am Persistenzmodell
- `prologue.class_reward`: `"none" | "pending" | "claimed"` (neu, v15)
- `SaveSystem.VERSION = 15` und `SaveMigrations._v14_to_v15` mit der eingefrorenen Tabelle `V15_PROLOGUE_CLASSES`
- Sonst keine Schemaänderung. Kein Mailbox- oder Reward-System, keine World-Pickups.

## Gezielte Tests
Neue Suite `test_class_trials_m4` (14 Tests, synthetische Saves, eigener Testprofilpfad `user://test_saves/class_trials_m4/`):
jede Klasse und ihr Modell, die Pipeline-Gleichheit mit `ItemCreation.generate` (gleicher Seed → gleiche Affixe), 60 feste Seeds
(nur T5, Pool, keine Duplikate, keine Essenzen), kein Anspruch ohne Wahl (Preview, Trial, Trial-Abschluss, Debug-Wechsel),
ungültige Klassen, Modell aus der Wahl statt aus der aktiven Klasse (M1-Freischaltung bleibt), volle Tasche,
Wiederholungen/Ereignisse, Save/Load pending und claimed, unbekannter Zustand, Migration 14→15 (8 Fälle + Bestandsschutz),
v3-abgeleitete Klasse, Datenvalidierung, Altar-Aktion im Panel (volle Tasche, Abholung, zweiter Klick).

| Suite | Ergebnis |
|---|---|
| class_trials_m4 | 14/14 grün |
| class_trials_m1, m2, m3, m31, save, save_foundation, loot_foundation, hollowwood_loot, crafting_save | grün |
| prologue | 9/10, rot: **bekannter Altfehler** `test_migration_v3_to_v4` (Fixture erwartet Item ohne `"rarity": 0` aus v14), unverändert und nicht von M4 |
| `check_project.ps1` | OK |

`test_loot_foundation` prüfte `VERSION == 14`. Die Prüfung lautet jetzt `>= 14`, da sie direkt von der Versionserhöhung abhängt.
Nicht gelaufen (Efficient Testing 1.1): Full-Suite, Prolog-, Haven-, Klassen-, Crafting-, Arena- und Galerie-Playtests. Die
Footer-Darstellung des Altars wurde nur headless geprüft, nicht im Fenster.

## Verbliebene Risiken
- **Altstand-Regel:** v5–v14-Stände mit echter Wahl erhalten einen nachträglichen Anspruch. Ist das nicht gewünscht, genügt eine
  Zeile in `_v14_to_v15`: immer `"none"`.
- Ein manuell editierter Save kann den Zähler fälschen. Das ist für ein Einzelspielerspiel akzeptabel.
- Abholung ohne laufende Session (nur Tests): kein Meilenstein-Save. Im Spiel speichert erst der Meilenstein-Save. Bis dahin ist
  der Zustand konsistent (siehe Atomarität).
- Die Altar-UI ist ein Footer im vorhandenen Fenster. Es gibt keinen Galerie-Eintrag, weil kein neuer Bildschirm entstanden ist.
