# Region 1 – Side Quests & Rewards 1.0 (Paket C)

Auf dem uncommitteten Stand der Pakete A/B (`docs/WORLD_EXPANSION_A_1_0.md`, `_B_1_0.md`). Save bleibt **v15** (neue Quests,
Flags und Zähler liegen in den bestehenden QuestLog-/WorldState-Strukturen; keine Migration). Hauptquest, Grove Warden,
Warden's Cache, Klassenwaffe, The First Binding und The Broken Cart unverändert.

## Technische Erweiterungen (klein, datengetrieben)
- `StoryQuestDefinition.start_event_id` + `start_condition`: `StoryService.notify` startet nach dem Fortschrittsdurchlauf jede
  noch unbekannte Quest mit passendem Start-Event und erfüllter Bedingung. Das Start-Event zählt nie für Schritt 0
  (`validate_data` meldet Start-Event = Schritt-0-Event, Start-Event-Quests in `next_quest_ids` und die erste Quest).
- `ProfessionService.craft` meldet nach der abgeschlossenen Transaktion `craft:<recipe_id>` (fehlgeschlagene, abgelehnte oder
  zurückgerollte Crafts melden nichts; Debug-Kits craften nicht).

## The Lost Hunter (`the_lost_hunter`, Whisper Forest)
Start: Mara-Dialog `mara_lost_hunter` (`talk:mara_lost_hunter`, nach `prologue.completed`, einmal).
0 Lager `LostHunter/Clues/Camp` → 1 drei Spuren `TrackA/B/C` (`interact:lost_hunter_track` ×3) → 2 Bau-Encounter
`lost_hunter_den` (Hardened Husk + Hollowfang Wolf, einmalig, erst nach `lost_hunter.tracks_followed`) → 3 `LostHunter/Horn`
(StoryPickup ohne Item, erst nach `encounter.lost_hunter_den`) → 4 Mara `mara_lost_hunter_return`.
Hinweis-Dialog `mara_lost_hunter_hint` (Schritte 0–3). Reward bei Mara (QuestRewardService): **40 Gold + 2 `cured_leather`**.
Clues erscheinen erst, wenn die Quest bekannt ist (`StoryConditional`, `quest_state = started`).

## What the Roots Keep (`what_the_roots_keep`, Tangled Wood)
Start: `RootsKeep/KnottedMarker` (`interact:roots_keep_marker`). 0 drei `Carved Root` (`interact:roots_keep_mark` ×3,
kumulativ – vorher gelesene Zeichen zählen) → Flag `roots_keep.marks_found` öffnet `RootsKeep/Seal` (vier Wurzelwände um den
Cache) → 1 `RootsKeep/Cache` (Readable: **25 Gold, 2 `iron_ingot`, 2 `duskleaf`**, alles oder nichts; volle Tasche: nichts
genommen, kein Flag, kein Abschluss). Optional: `roots_keep_guardians` (Hardened Husk + Husk, einmalig, ab `marks_found`, kein
Gate). Kein Turn-in, keine Schmucktabelle.

## Embers of Shelter (`embers_of_shelter`, Chapel + Haven)
Start: neues `EmbersOfShelter/Ledger` (`interact:shelter_ledger`) – **nicht** die alte `FadedNote`. 0 `Found/HearthBox`
(erscheint mit der Quest; **2 `duskleaf`, 2 `timber`**, alles oder nichts) → 1 `craft:al_ember_draught` (nicht kumulativ:
nur ein Craft während dieses Schritts zählt; Rezept 2 Duskleaf + 1 Timber, Alchemie 1, Station `alchemists_cottage`, jede
Werkstattstufe) → 2 Mara `mara_embers`. Reward bei Mara: **30 Gold + 4 `duskleaf`** (Masterplan-Wert; Material für zwei
weitere Draughts, kein Gerät, kein Rare).

## Mara
Neue Dialoge vor dem wiederholbaren `mara_history`: `mara_lost_hunter_return`, `mara_embers`, `mara_lost_hunter`,
`mara_lost_hunter_hint`. Bestehende Dialoge unverändert; Prolog-Dialoge behalten Vorrang.

## Tests
`test_side_quests` (12). Angepasst (Bestandslisten um die beiden Mara-Quests bzw. Questobjekte erweitert):
`quest_turnin_mara`, `quest_turnin_mixed_rewards`, `quest_turnin_t1`, `roots_remember_m2`, `world_expansion_a`.

## Offen
- Das Horn ist kein Inventar-Item (Pickup-Platzhalter mit Kistengrafik).
- HUD-Tracker wird mit mehreren aktiven Nebenquests lang.
- Kein gespielter Durchlauf der Quests (nur Headless-Tests und Screenshots).
