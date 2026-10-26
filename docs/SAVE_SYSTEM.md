# Save-System

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Dateien & Slots ✅ (Save Foundation 1.1)
- **5 manuelle Slots**: `user://saves/slot_1 … slot_5.save.json` (Slot 1 = bisheriger Spieler-Slot, F6/F9).
- **3 rotierende Autosaves**: `user://saves/autosave_1 … autosave_3.save.json`; geschrieben wird in den
  ungültigen bzw. ältesten (`SaveSlots.next_auto_slot`), manuelle Slots werden nie berührt.
- Windows: `%APPDATA%\Godot\app_userdata\Echoes of the Hollow\saves\`.
- Tests/Playtests nutzen ausschließlich `user://test_saves/…`; gescriptete Läufe (Main Loop = Skript)
  setzen `save_path` automatisch auf `user://test_saves/scripted/slot_1.save.json`, damit auch Autosaves
  und Meilenstein-Saves nie Spielerdateien erreichen.
- UI: Titelbildschirm (Continue = neuester gültiger Save, New Game mit Bestätigung, Load Game, Options,
  Quit) und Pausemenü (Esc: Resume, Save Game in 5 Slots, Load Game inkl. Autosaves, Options, Quit to Title).
  Slotinfo: Ort · Klasse/Level · Spielzeit · Datum. Beschädigte Dateien werden markiert und nie geladen.

## Schreib-Koordinator (`SaveCoordinator`, Kind des Autoloads) ✅
- Anfragen: `request_manual(slot)`, `request_autosave(reason)` und `request_critical(reason)` (über
  `SessionState.request_critical_save`).
- Höchstens eine Schreiboperation pro Frame. Der Snapshot entsteht synchron im selben Frame.
- Mehrere offene Auto- und Meilenstein-Anfragen werden zu **einem** Schreibvorgang zusammengefasst.
- **Periodischer Autosave** alle 300 s **aktiver** Spielzeit. Gezählt wird nur ungepausiert, nur auf einer
  bereiten Map und nicht während einer Reise. Option „Periodic Autosave“, Standard an.
- **Meilenstein-Saves (kritisch)** bei jedem abgeschlossenen Story-Schritt (dazu gehört die Ankunft in
  Haven), bei Restaurierung, Klassenwahl und Wegstein.
  - Sie werden **nie** durch die Option oder einen Cooldown unterdrückt.
  - Ein fehlgeschlagener Meilenstein-Save wird nach 5 s wiederholt.
- HUD-Anzeige unten rechts:
  - „Saving…“ während des Schreibens
  - „Progress saved“ erst **nach** erfolgreichem Schreiben
  - „Save failed“ immer sichtbar, auch wenn „Show Save Indicator“ aus ist
- Tod und Respawn speichern nie. Rastplätze (Respawn) und Saves sind getrennt.
- Testhaken: `SaveSystem.fail_next_write` lässt den nächsten Schreibvorgang nach dem Temp-File scheitern.

## Format (Version 10) ✅
```json
{ "format": "echoes_of_the_hollow_save", "version": 10, "saved_at": 1761460000, "order": 1761460000123,
  "checksum": "<sha256 of payload text>", "payload": "<exact JSON text>",
  "meta": { "location": "Haven", "class": "Warrior", "level": 3, "play_time": 812,
            "kind": "manual|autosave|milestone", "reason": "..." } }
```
`order` ist eine streng steigende Millisekunden-Ordnung (neuester Save = Continue). `meta` dient nur der
Slotanzeige; die Prüfsumme deckt den Payload ab.
Die Nutzdaten werden als **exakter JSON-Text** gespeichert, damit die SHA-256-Prüfsumme genau die
Bytes abdeckt, die geparst werden (erneutes Serialisieren von JSON ist nicht stabil: `1` → `1.0`).

Payload (nur Quelldaten):
| Schlüssel | Inhalt |
|---|---|
| `id`, `name` | Charakter-ID, Name |
| `classes` | aktive Klasse, pro Klasse unlocked/level/xp |
| `mastery` | pro Familie level/xp |
| `inventory` | Iteminstanzen (id, def, qty; falls gesetzt: ilvl, quality, material, affixes, essences, sockets, evolution, progress, rev) |
| `stash` | Haven-Lager (v6): `{"items": [...]}`, Iteminstanzen im selben Format wie `inventory`; die Kategorien werden nicht gespeichert, sondern aus der Definition abgeleitet (`docs/STASH.md`) |
| `orphaned_items` | nicht wiederherstellbare Items (Rohdaten, werden weitergespeichert) |
| `loadouts` | pro Klasse Slot → Instanz-ID |
| `world` | Map-ID, Spawnpunkt-ID, Flags (inkl. Story-Flags `prologue.*`, `haven.*`, Zähler `count.<event>`), Gebäude, `waystones` (v5), `restoration` Ruine → ruined/restored/revitalized (v5) |
| `play_time` | aktive Spielzeit in Sekunden (v5) |
| `class_builds` | pro freigeschalteter Klasse: Talentränge, 4 Skill-Slots, Mods je Skill, Sonder-Freischaltungen, Respec-Zähler, 5 Presets (v4) |
| `prologue` | Stufe (not_started/in_progress/completed), abgeschlossene Trials, gewählte Klasse (v4) |
| `quests` | Klassen- und Storyquests: Zustand, `step` (v5), Zielfortschritt des aktuellen Schritts |
| `professions` | Berufe (v7): `levels` Beruf → {level, xp}, `known_recipes` (dauerhaft gelernte Rezepte), `first_crafts` (Rezepte mit bereits vergebenem Erstherstellungsbonus); siehe `docs/PROFESSIONS.md` |

**Nicht gespeichert (rekonstruiert):** Stats, aktuelle HP, Klassenressource, Cooldowns, Buffs, aktive
Effekte/Modifier, Combat-Waffe, Combo-Freischaltungen, Statuseffekte auf Gegnern, **laufende Prolog-Trials**
(Trial-Klasse, -Build, -Loadout, -Fortschritt: ein Laden führt immer zum Zustand vor der Trial) – alles wird beim Binden aus den Quelldaten neu aufgebaut.

## Sicheres Schreiben ✅
1. `<pfad>.tmp` schreiben und schließen
2. zurücklesen, Format + Prüfsumme verifizieren
3. vorhandene `<pfad>` nach `<pfad>.bak` kopieren (eine rollierende Sicherung)
4. Temp-Datei auf `<pfad>` umbenennen

Bricht der Vorgang ab, sind entweder der alte Stand oder dessen `.bak` intakt. Unter Windows ersetzt
`rename` das Ziel nicht in einem einzigen atomaren Schritt – deshalb existiert Schritt 3 vorher.
Es werden **keine** Spielstände automatisch gelöscht (nur die eigene `.bak` wird ersetzt).

## Robustes Laden ✅
- Ungültiges JSON, fremdes Format, fehlende/zu neue Version, Prüfsummenfehler → Fehler, kein Absturz;
  automatischer Rückgriff auf `.bak` (mit Hinweis).
- Unbekannte Itemdefinitionen → Item wird als „Orphan“ aufbewahrt und weitergespeichert.
- Loadout-Referenzen auf fehlende Items oder Regelverstöße → Referenz entfernt, Item bleibt.
- Unbekannte Klassen/Waffenfamilien → Rohdaten werden aufbewahrt.
- Werte außerhalb der Grenzen (Level, XP) → geklemmt; ungültige aktive Klasse → Fallback.
Alle Korrekturen landen als Warnungen in `SaveSystem.LoadResult.warnings`.

## Migrationen ✅
`SaveMigrations._steps()` bildet `version → Funktion(payload) → payload(version+1)`. Ablauf bei
Schemaänderung: `SaveSystem.VERSION` erhöhen, Schritt ergänzen, Test mit gespeicherter Alt-Payload.
Alte Dateien werden nur im Speicher migriert und beim nächsten Speichern im neuen Format geschrieben.
Aktuell: Version 10.
- 1→2 ergänzt `world.map_states` (Overnight 3).
- 2→3 (Crafting Foundation 0.1): Items in `inventory` und `orphaned_items` bekommen `ilvl` 1 und
  `quality` 0. Das vorbereitete Feld `essence` wird zu `essences` (Liste), Unbekanntes landet in
  `progress.legacy_essence`. Affixe ohne Affix-ID werden als `legacy` markiert (wirken weiter, nicht
  umformbar). Es wird **nichts neu gewürfelt**.
- 3→4 (Class Foundation 0.2): `class_builds` = {}, `quests` = {}, `prologue` ergänzt. War in einem alten
  Stand bereits eine Prolog-Klasse freigeschaltet (Debug-Freischaltung vor 0.2), gilt der Prolog als
  abgeschlossen mit dieser Klasse; sonst „not_started“. Nichts Freigeschaltetes wird wieder gesperrt; Items,
  Crafting-Zustand und Loadouts bleiben unverändert. Talentpunkte ergeben sich aus dem vorhandenen Level.
- 4→5 (Prologue & Haven Slice 0.1):
  - Neu: `play_time` = 0 und `world.waystones` = ["haven"].
  - Plot-Gebäude werden zu restaurierten Ruinen: smithy → old_smithy, storage → old_storehouse,
    training_ground → fallen_barracks. Sie verlassen die Plotliste, damit der Lagerbonus nicht doppelt
    zählt. Je restaurierter Ruine wird `haven.<ruin>.restored` gesetzt.
  - Die Old Smithy gilt immer als restauriert: Ein v4-Charakter lebt bereits in Haven, also sind Straßen-
    und Haven-Teil des Prologs abgeschlossen (Flags, Quests, Zähler).
  - Mit getroffener Klassenwahl ist der ganze Prolog fertig, der Whispering-Stone-Wegstein ist aktiv und
    die Hauptquest „The First Signs“ läuft.
  - Ohne Klassenwahl geht es bei „The Whispering Stone“ weiter. Bereits absolvierte Trials zählen als
    gegangene Echos.
  - Items, Klassen, Builds und Loadouts bleiben unverändert.
  - Geprüft wurde auch der echte v2-Spielstand des Nutzers, und zwar als Kopie unter `test_saves`: Er lädt
    ohne Warnungen.
- 5→6 (Inventory & Haven Stash 1.0): leerer `stash` (`{"items": []}`). Inventar, Loadouts, Quests,
  Klassen und Talente bleiben unverändert. Beim Laden wird eine Instanz-ID, die schon in der Tasche liegt,
  nicht ein zweites Mal aus dem Lager geladen: Diese Kopie wird als `orphaned_items` aufbewahrt (nie gelöscht)
  und als Warnung gemeldet.
- 6→7 (Professions Foundation 1.0): leeres `professions` (`{"levels": {}, "known_recipes": [], "first_crafts": []}`).  Beim Laden starten alle neun Berufe auf Stufe 1, automatische Stufe-1-Rezepte werden gelernt. Tasche, Lager,  Restaurierungen, Klassen, Talente und Builds bleiben unverändert. Unbekannte Berufe werden mit Warnung  ignoriert, Stufe/XP auf gültige Werte begrenzt, unbekannte Rezept-IDs bleiben erhalten (aber unbenutzbar).
- 7→8 (Item Integrity 1.0): jeder Item-Eintrag in `inventory`, `stash.items` und `orphaned_items` ohne Herkunft bekommt
  `"origin": "unknown_legacy"` (nie geraten). Keine Markierungen; ID, Affixe, Qualität, Essenzen, Sockel, Evolution bleiben.
  Beim Laden verlieren Stapel Herkunft und Markierungen (nur Einzelitems tragen sie).
- 8→9 (Hearth Flask & Consumables 1.0): `consumables` = keine Upgrades, volle Grundladungen (`charges` -1 → beim Laden aus den Regeln), kein
  Trankslot, kein Buff, kein Cooldown. Sonst ändert sich nichts. Laden begrenzt Stufen/Ladungen und setzt einen laufenden Buff wieder ein.
- 9→10 (Armor Mastery 1.0): leeres `armor_mastery` → alle vier Tracks Stufe 1 ohne XP. Items, Slots und Loadouts unverändert.

Nach dem Laden repariert `ItemStats.sanitize` den Crafting-Zustand gegen die aktuellen Daten:
- Qualität wird auf das Maximum begrenzt.
- Essenzen bzw. Sockel über dem Limit werden als inaktiv in `progress` geparkt, nicht gelöscht.
- Die Evolutionsstufe wird begrenzt.

JSON-Zahlentypen werden normalisiert, damit gespeicherte Werte bitgleich zurückkommen.
Unbekannte Essenz-, Einlage- und Affix-IDs bleiben erhalten und werden beim Effektaufbau ignoriert.

## Offen
✅ Mehrere Slots und Autosave (1.1) · ⬜ exakte Position statt Spawnpunkt · ⬜ Slots umbenennen/löschen im Menü.
