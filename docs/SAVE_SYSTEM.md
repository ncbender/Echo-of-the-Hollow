# Save-System

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Dateien ✅
- Spieler-Slot: `user://saves/slot_1.save.json` (Windows:
  `%APPDATA%\Godot\app_userdata\Echoes of the Hollow\saves\`). **F6** speichern, **F9** laden.
- Tests/Playtests nutzen ausschließlich `user://test_saves/…` und überschreiben den Spieler-Slot nie.

## Format (Version 4) ✅
```json
{ "format": "echoes_of_the_hollow_save", "version": 4, "saved_at": 1761460000,
  "checksum": "<sha256 of payload text>", "payload": "<exact JSON text>" }
```
Die Nutzdaten werden als **exakter JSON-Text** gespeichert, damit die SHA-256-Prüfsumme genau die
Bytes abdeckt, die geparst werden (erneutes Serialisieren von JSON ist nicht stabil: `1` → `1.0`).

Payload (nur Quelldaten):
| Schlüssel | Inhalt |
|---|---|
| `id`, `name` | Charakter-ID, Name |
| `classes` | aktive Klasse, pro Klasse unlocked/level/xp |
| `mastery` | pro Familie level/xp |
| `inventory` | Iteminstanzen (id, def, qty; falls gesetzt: ilvl, quality, material, affixes, essences, sockets, evolution, progress, rev) |
| `orphaned_items` | nicht wiederherstellbare Items (Rohdaten, werden weitergespeichert) |
| `loadouts` | pro Klasse Slot → Instanz-ID |
| `world` | Map-ID, Spawnpunkt-ID, Flags, Gebäude |
| `class_builds` | pro freigeschalteter Klasse: Talentränge, 4 Skill-Slots, Mods je Skill, Sonder-Freischaltungen, Respec-Zähler, 5 Presets (v4) |
| `prologue` | Stufe (not_started/in_progress/completed), abgeschlossene Trials, gewählte Klasse (v4) |
| `quests` | Klassenquests: Zustand + Zielfortschritt (v4) |

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
Aktuell: Version 4.
- 1→2 ergänzt `world.map_states` (Overnight 3).
- 2→3 (Crafting Foundation 0.1): Items in `inventory` und `orphaned_items` bekommen `ilvl` 1 und
  `quality` 0. Das vorbereitete Feld `essence` wird zu `essences` (Liste), Unbekanntes landet in
  `progress.legacy_essence`. Affixe ohne Affix-ID werden als `legacy` markiert (wirken weiter, nicht
  umformbar). Es wird **nichts neu gewürfelt**.
- 3→4 (Class Foundation 0.2): `class_builds` = {}, `quests` = {}, `prologue` ergänzt. War in einem alten
  Stand bereits eine Prolog-Klasse freigeschaltet (Debug-Freischaltung vor 0.2), gilt der Prolog als
  abgeschlossen mit dieser Klasse; sonst „not_started“. Nichts Freigeschaltetes wird wieder gesperrt; Items,
  Crafting-Zustand und Loadouts bleiben unverändert. Talentpunkte ergeben sich aus dem vorhandenen Level.

Nach dem Laden repariert `ItemStats.sanitize` den Crafting-Zustand gegen die aktuellen Daten:
- Qualität wird auf das Maximum begrenzt.
- Essenzen bzw. Sockel über dem Limit werden als inaktiv in `progress` geparkt, nicht gelöscht.
- Die Evolutionsstufe wird begrenzt.

JSON-Zahlentypen werden normalisiert, damit gespeicherte Werte bitgleich zurückkommen.
Unbekannte Essenz-, Einlage- und Affix-IDs bleiben erhalten und werden beim Effektaufbau ignoriert.

## Offen
⬜ Mehrere Slots/Slot-Auswahl-UI, ⬜ Autosave, ⬜ exakte Position statt Spawnpunkt.
