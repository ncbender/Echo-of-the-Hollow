# NPC Quest Turn-ins 1.1 – M3: Mixed Reward Guidance & Visual Acceptance

Branch `dev/npc-quest-turnins-11-m3` von `dev/npc-quest-turnins-11-m2` @ `b5a9c78`. Save bleibt **v15**.
Commits: `e88caf4` (Code/Daten/Texte), `d5c3232` (Suite `quest_turnin_mara_ui`), `a7c814a` (Galerie-Bildschirme), dieses Dokument.

Unverändert: `QuestRewardService` (Auszahlung, Prüfungen, Rollback), Story, Entitlement, Trial-Sperre, Reward-Mengen.

---

## 1. Gemeinsame Reward-Formatierung

Eine Quelle für Karte, Erfolgstext, Journal: `QuestRewardPanel.reward_parts(db, quest)` (aus M2) und `reward_summary`.
- Gold nur bei `turn_in_gold > 0`, danach die Materialien in Datenreihenfolge (`QuestRewardService.reward_items`)
- Itemnamen aus `ItemDefinition.display_name`, Mengen aus den Daten
- nie „0 Gold“

| Verwendung | Form | Beispiel |
|---|---|---|
| Karte | eine Zeile pro Teil | `30 Gold` / `3 Timber` / `2 Stone` |
| Erfolg, Journal „received“ | `reward_summary` | `30 Gold, 3 Timber and 2 Stone` |
| Journal „pending“ (mit Ort) | Teile mit Komma | `30 Gold, 3 Timber, 2 Stone` |

Erkennung „hat Reward“ überall über `QuestRewardService.has_reward` (seit M2; Rest-Suche nach `turn_in_gold > 0` in `scripts/ui`
und `scripts/world`: nur noch die Gold-Teil-Formatierung).

## 2. Ort der Abholung: `turn_in_place`

Neues Anzeigefeld `StoryQuestDefinition.turn_in_place` (reiner Text, kein Spielstand, keine Regel). `the_broken_cart`:
`"Mara in Haven"`. Leer (Edrin) = die T3-Zeilen mit dem NPC-Namen, Wort für Wort unverändert.

Grund: Die Texte sollen „Mara in Haven“ nennen (nicht „Mara Veyne“), damit der Hinweis auf der Old Road nicht auf die dortige
Begleiterin zeigt. Ein Feld in den Daten statt einer NPC-/Quest-Sonderbehandlung im Code.

## 3. Journal (`JournalPanel.reward_text`)

| Zustand | Mara (`turn_in_place`) | Edrin (leer) |
|---|---|---|
| pending | `Reward available: Return to Mara in Haven.` + Zeile `Reward: 30 Gold, 3 Timber, 2 Stone.` | `Reward available: Return to Edrin Vale (60 Gold).` |
| claimed | `Reward received: 30 Gold, 3 Timber and 2 Stone.` | `Reward received: 60 Gold.` |
| none | keine Zeile | keine Zeile |

- Material-only: `Reward: 3 Timber, 2 Stone.` bzw. `Reward received: 3 Timber and 2 Stone.` (Test).
- Ohne Ort fiel der Pending-Text früher auf `(%d Gold)`; jetzt `(%s)` mit `reward_summary`, für Edrin dieselbe Ausgabe.
- Struktur unverändert: Zeile auf der Karte der abgeschlossenen Quest, Farbe pending = SUCCESS, received = MUTED.
- Schlüssel: `UI_QUEST_REWARD_JOURNAL_PENDING` (jetzt `%s`), neu `…_PENDING_AT`, `…_PARTS`; `…_CLAIMED` (jetzt `%s`).

## 4. Tracker (`ObjectivePanel.reward_lines`)

- Mara pending: `Collect your reward from Mara in Haven.` (`UI_QUEST_REWARD_TRACKER_AT`). Steht ab dem Ende von
  `mara_road_end`, also schon auf der Old Road; die Road-Mara bleibt ohne Claim und ohne „?“ (Test in der Old-Road-Szene).
- Edrin pending: `Return to Edrin Vale for your reward.` unverändert.
- Nach dem Claim verschwindet die Zeile sofort (der Tracker liest jeden Frame). Bei none: keine Zeile. Die Quest bleibt completed.
- **Beide offen:** Die Struktur erlaubte schon eine Zeile pro offenem Reward. Beide stehen untereinander, eindeutig benannt,
  ein Claim entfernt nur die eigene Zeile.
- Priorität unverändert: Trial-Block (Titel, Ziele) → Story-Zeilen → Reward-Hinweise → Klassenquests (Test mit laufender Trial
  und mit Story-Hinweis).

## 5. Flask- und Reward-Fenster

- Flask-Fenster: unverändert plus Knopf „Quest Rewards“ (M2).
- Reward-Fenster bei Mara:
  - Karte mit drei Zeilen, „Talk to Mara Veyne“
  - neu **„Back“**: öffnet den eigenen Service des NPCs wieder (`hud.open_npc_service(npc.service, site)`), nur wenn der Service
    nicht das Reward-Fenster selbst ist; bei Edrin also kein Back
  - kein neuer Navigationszustand
- Pending: Tastaturfokus auf „Claim Reward“ (T3-Verhalten, auch beim Öffnen über den Flask-Knopf; Test und Screenshot).
- BAG_FULL: „Not enough inventory space. Make room to claim the full reward.“ als Status (und Tooltip), „Claim Reward“
  deaktiviert, Anspruch pending. Nach dem Platzschaffen wird der Knopf ohne Neuöffnen aktiv (M2), regulärer Claim möglich.
- Edrins Fenster: 60 Gold, „Received 60 Gold.“, kein Back.

## 6. Marker und Dialogpriorität

Nicht geändert (kein Fehler gefunden). Verifiziert (Tests und Screenshots):
- Old-Road-Mara: kein „?“
- Haven-Mara: pending → „?“, ungehörtes `mara_welcome` → „!“, nach dem Claim kein Marker
- Edrin unverändert
- historisch completed ohne Entitlement → kein „?“

## 7. Visuelle Abnahme

Galerie-Bildschirme (`GalleryScreens`, Lauf mit `--only`, Fenster, echte Renderbilder unter `tests/output/gallery/`, nicht
eingecheckt):

| Zustand | Bildschirm |
|---|---|
| A Flask mit Reward-Knopf | `flask_quest_rewards` |
| B / C / D Reward pending / claimed / none | `mara_rewards`, `mara_rewards_claimed`, `mara_rewards_none` (none: Fenster direkt geöffnet, im Spiel ohne Knopf) |
| E BAG_FULL | `mara_rewards_full` (Tasche voll, Timber/Stone-Stapel des Galerie-Charakters aufgefüllt; `reset` macht beides rückgängig) |
| F + J „?“ und Tracker | `hud_mara_reward` |
| G „!“ | `hud_mara_story` (`mara_welcome` ungehört, Shelter Schritt 1; `reset` stellt zurück) |
| H / I Journal | `journal_cart_reward`, `journal_cart_claimed` |
| beide offen | `hud_both_rewards` |
| Vergleich Edrin | `quest_rewards`, `journal_reward` |

Lauf: `ui_gallery.gd -- --res=1920x1080,1280x720 --scale=1.0,1.5 --only=…` → `RESULT: OK (120 checks, 0 failed)`.

**Angesehen** (Bilder geöffnet und beurteilt):
- 1080p/100 %: alle Bildschirme oben
- 720p/150 %: `mara_rewards`, `mara_rewards_claimed`, `mara_rewards_full`, `flask_quest_rewards`, `hud_both_rewards`,
  `hud_mara_story`, `journal_cart_reward`
- Erzeugt, aber nicht einzeln angesehen: die übrigen 720p/150-%-Bilder sowie 1080p/150 % und 720p/100 % (Nebenprodukt des
  Kreuzlaufs)

Befunde:
- Texte lesbar, drei Reward-Zeilen sichtbar, keine Überlappung, BAG_FULL zweizeilig umbrochen und nicht abgeschnitten, Fokusrahmen
  auf „Claim Reward“ sichtbar, Marker „?“/„!“ frei über Mara, Stil wie die übrigen Fenster.
- Erster Lauf: `mara_rewards_full` zeigte keinen Bag-full-Zustand. Ursache war der Galerie-Zustand (der Charakter hat teilweise
  gefüllte Timber/Stone-Stapel aus dem Crafting-Kit, die Belohnung passte), kein UI-Fehler. Galerie-Zustand korrigiert, danach
  korrekt.
- 720p/150 %: Im Flask-Fenster liegt „Quest Rewards“ unter den Upgrade-Karten, im Journal die Reward-Zeile von „The Broken Cart“
  unterhalb des sichtbaren Bereichs. Beide liegen im Scrollbereich (Scrollbalken sichtbar; die Layoutprüfung der Galerie meldet
  sie als im ScrollContainer). Der **gescrollte** Zustand ist nicht als Bild geprüft.
- Kein Code-Fix an der Darstellung nötig.

## 8. Tests

Neue Suite `tests/integration/test_quest_turnin_mara_ui.gd` (12 Tests, echte Haven-/Old-Road-Szene, echtes HUD):

| Auftrag # | Test |
|---|---|
| 1, 2 | `journal_lines_follow_the_reward_state`, `journal_window_shows_the_line_on_the_completed_card` |
| 3, 10 | `no_reward_line_without_entitlement` |
| 4, 5 | `material_only_and_gold_only_formats` |
| 6, 7, 11 | `tracker_names_mara_in_haven_from_the_road_on` |
| 8, 9 | `both_open_rewards_stay_findable_after_the_story_lines`, `trial_lines_keep_priority` |
| 12, 13, 14 | `haven_markers_and_priority` |
| 15, 16 | `bag_full_keeps_pending_and_room_unlocks_the_claim` |
| 17, 18 | `flask_rewards_back_talk_and_focus` |
| 19 | `edrins_window_has_no_back_and_pays_60` |
| 20 | `guidance_changes_no_state` (Journal, Tracker, Marker, Fenster ändern den Spielstand nicht; `play_time` ausgenommen) |

Lauf: `quest_turnin_mara_ui, quest_turnin_mara, quest_turnin_mixed_rewards, quest_turnin_t1, quest_turnin_t2, quest_turnin_t3,
consumables, haven, old_road, shrine, story, world_ui` → **122 passed, 0 failed**. `check_project.ps1`: OK.
Bestehende Edrin-Texte in T3 (exakte Strings) unverändert grün.
Im ersten Lauf der neuen Suite schlugen zwei Tests am Testaufbau fehl (Kartenbetreten beendet eine echte Trial; `play_time` im
Vergleich), korrigiert.

Nicht gelaufen: Full-Suite, Galerie-Gesamtlauf, Playtests, `prologue` (bekannter Altfehler `test_migration_v3_to_v4`).

## 9. Offene UI-Grenzen

- 720p/150 %: „Quest Rewards“ im Flask-Fenster und die Journal-Reward-Zeile erst nach Scrollen sichtbar; der gescrollte Zustand
  ist nicht als Bild geprüft. Eine Umsortierung des Flask-Fensters wäre eine Layoutänderung (nicht beauftragt).
- „Back“ ist ein schlichter Text ohne Zielnamen (kein Service-Titel-Register).
- Reihenfolge mehrerer Tracker-Hinweise folgt der Datenbank-Ladereihenfolge der Quests, nicht der Storyreihenfolge.
- `turn_in_place` ist ein freier Text in den Questdaten (nicht über `ui.csv` lokalisiert, wie Quest-Beschreibungen).
- Galerie-Bildschirme teilen den Charakterzustand: Edrins `journal_reward` zeigt nach den Mara-Bildschirmen deren letzten Zustand.
