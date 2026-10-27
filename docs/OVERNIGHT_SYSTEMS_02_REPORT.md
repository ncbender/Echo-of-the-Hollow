# Overnight Development Session 2.0 – Bericht

Branch `dev/overnight-systems-02`, lokal aus `dev/overnight-artisan-crafting-01` (Ausgangs-Commit `761c671`). Kein Push.

## Git
| Commit | Paket |
|---|---|
| `2a41764` | 1 Item Integrity & Salvaging 1.0 (Save v8) |
| `2abac3b` | 2 Hearth Flask & Consumables 1.0 (Save v9) |
| `61036e0` | 3 Armor Mastery Foundation 1.0 (Save v10) |
| `ed07398` | 4 Hollowwood Loot Economy 1.0 – Grundlage und Simulation |
| dieser Commit | Bericht, CLAUDE.md, Roadmap, Teststrategie |

**Sicherheit:**
- `project.godot` (fremde Änderung) wurde nie verändert, gestaged oder committet. Der SHA-256 `68321b98…` wurde
  nach jedem Godot-Lauf geprüft und ist am Ende gleich; die Datei ist weiterhin uncommittet.
- Echte Spielstände und `settings.cfg` wurden vor Beginn gehasht und nach jedem Lauf geprüft: unverändert.
  - Tests nutzen `user://test_saves/`.
  - Die Startprüfung lief in einer umbenannten Projektkopie mit eigenem Benutzerordner (danach gelöscht).
  - Der Vergleichslauf auf dem Basis-Commit lief in einem temporären Worktree (danach entfernt).
- `docs/tasks/` bleibt ungetrackt. Es gab keine Force-Operationen auf dem Repository.

## 1. Item Integrity & Salvaging 1.0 – umgesetzt
- **Iteminstanz:**
  - Neue Felder `favorite`, `locked` und `origin`: `found`, `crafted`, `quest_reward`, `starting`, `unknown_legacy`,
    `""` = nicht erfasst.
  - Die Felder gibt es nur bei Einzelitems; Stapel tragen sie nicht, damit sie weiter zusammenfallen.
  - Herkunft wird beim Entstehen gesetzt: Herstellen, Startausrüstung, Welt-Pickups, Lesbares, Story-Pickups.
  - Es gibt noch keine Quest-Item-Belohnungen, darum ist `quest_reward` nur vorbereitet.
- **Save v8:**
  - Die Migration v7→v8 markiert jedes gespeicherte Item `unknown_legacy`; es wird nichts geraten.
  - Unbekannte Herkunftswerte werden ebenfalls zu `unknown_legacy`.
  - ID, Affixe, Qualität, Imprint, Essenzen, Sockel und Evolution bleiben (getestet).
- **Bedienung:**
  - Inventar und Lager: **Strg+Klick = Favorit, Alt+Klick = Sperre**. Rechtsklick (Ausrüsten/Einlagern) ist
    unverändert.
  - Symbole: Raute für Favorit, Schloss für Sperre. Die Tooltip-Zeile zeigt „Favourite · Locked · Origin: …“.
  - Auf der Salvage-Seite gibt es Knöpfe „Favourite“/„Lock“.
- **Schutz** (`ItemProtection.destroy_block`) gegen Verwerten und Verkaufen:
  - Questitem
  - Unique/Set (beim Verwerten immer gesperrt)
  - in irgendeinem Klassen-Loadout ausgerüstet
  - in einem Build-Preset
  - gesperrt
  - Favorit
- **Salvaging** (`SalvageService`, Seite „Salvage“ im Berufefenster):
  - Nur an der Werkbank des Berufs, dessen *eindeutiges* Herstellungsrezept das Item macht: Blacksmithing,
    Leatherworking, Tailoring, Woodworking. Alles andere ist gesperrt, z. B. Iron Sword aus dem Forge-Rezept,
    Fundstücke ohne Rezept, Alchemie.
  - **Rückgewinnung:**
    - Basis ist das Rohmaterial der Itembasis; verarbeitete Inputs werden über ihre Verarbeitungsrezepte
      zurückgerechnet.
    - Davon kommt ein Anteil nach Seltenheit zurück: Normal/Magic 20–30 %, Rare/Epic 25–35 %, Legendary 30–40 %.
    - Der Anteil wird **einmal pro Instanz** gewürfelt (deterministisch aus der ID). Die Vorschau zeigt genau
      das Ergebnis; Save/Load würfelt nicht neu.
    - Das Ergebnis wird abgerundet. Ergibt das nichts, wird abgelehnt (z. B. Rope Belt) und das Item bleibt.
  - Keine Rückgabe von Affixen, Qualität, Essenzen, Sockeln, Katalysatoren oder Gold. Keine Residues. **Keine XP.**
  - **Bestätigung:** über `UiConfirmDialog` mit dem Ertrag und einer Warnung bei Upgrades (Cancel hat den Fokus).
    Der Knopf steht in der festen Fußzeile.
  - **Atomar:**
    - Vorab werden Schutz, Werkstatt, Ertrag und der Platz für alle Erträge nach dem Freiwerden des Slots geprüft.
    - Scheitert die Gutschrift, werden die Erträge zurückgenommen und dieselbe Instanz kehrt zurück (getestet).
  - **Keine Schleife:** Höchstens 40 % des Rohmaterials kommen zurück. Jedes Rezept wurde 10× hergestellt und
    verwertet; das Rohmaterial sinkt immer.

## 2. Hearth Flask & Consumables 1.0 – umgesetzt
Details: `docs/CONSUMABLES.md`.
- **Flask:**
  - 2 Ladungen, 30 % Heilung, 1,1 s Trinkdauer, Heilung und Verbrauch erst am Ende.
  - Während des Trinkens 45 % Gehtempo; keine Angriffe, Skills oder Blocks; kein Cooldown.
  - Unterbrechung durch Dash, Treffer ab INTERRUPT, Tod oder Szenenwechsel: nichts verbraucht.
  - Rastplätze heilen voll, füllen die Flask, setzen den Respawn, speichern nicht und lassen keine Gegner
    zurückkehren.
- **Mara (Haven):**
  - Fenster „Hearth Flask“ mit Capacity (150/450/1100/2400) und Potency (200/550/1300/2800), nur Gold, atomar.
  - Ungehörte Dialoge kommen zuerst. Gefundener Fehler: Maras Geschichtsdialog ist wiederholbar und hätte das
    Fenster für immer verdeckt. Er ist jetzt über „Talk to Mara Veyne“ im Fenster erreichbar.
- **Tränke:** fünf Spezialtränke als stapelbare Items mit `PotionEffectDefinition`; die Werte stehen in
  `CONSUMABLES.md`.
  - Ein Buff gleichzeitig, ein neuer ersetzt den alten.
  - 0,7 s Trinkdauer, Verbrauch erst am Ende, 30 s gemeinsamer Cooldown.
  - Der Tod beendet den Buff. Buff und Cooldown werden mit Restzeit gespeichert.
  - Neue Stats: `damage_dealt`, `damage_reduction`, `move_speed`, `status_resistance`.
  - Quickstep ändert nur das Gehen, nie den Dash (getestet).
  - Resonance läuft über `resource_efficiency` mit Deckel 50 %; die Kosten werden nie negativ (getestet).
- **Alchemie:** Ember, Quickstep, Barkskin und Resonance sind in der Alchemist's Cottage herstellbar (Duskleaf,
  Timber, Flax, Iron Ore).
  - **Abweichung:** Whisperbloom ist eingebaut, aber nicht herstellbar. Kein Gegner belegt den Spieler bisher mit
    Status, der Trank wäre also funktionslos. Das Rezept ist mit Grund gesperrt.
  - Das alte Rezept „Stoneskin Draught“ gehört nicht zu den fünf und bleibt Datenrezept („Not brewed in this
    version“).
- **Tasten 1/2:** zur Laufzeit registriert, `project.godot` bleibt unberührt.
  - **Folge:** Die Aktionen `weapon_slot_1/2` verlieren zur Laufzeit die Tasten 1/2. Der Waffen-Schnellwechsel hat
    damit derzeit keine Taste – das ist eine offene Entscheidung.
  - Rechtsklick auf einen Trank legt ihn auf Slot 2; die Zuordnung bleibt bei leerem Stapel erhalten.
- **HUD:**
  - Quick-Use-Slots (1 Flask, 2 Trank mit Anzahl und Cooldown) und eine allgemeine Effektleiste über dem Player
    Frame.
  - Pro Effekt gibt es ein quadratisches Icon mit Ring, der im Uhrzeigersinn ab 12 Uhr abläuft; abgelaufene Teile
    werden abgedunkelt; darunter steht die Zeit m:ss.
  - Die Leiste ist nur Anzeige.
- **Save v9:** Migration v8→v9 (Flask ohne Upgrades, volle Ladungen, kein Slot, kein Buff).

## 3. Armor Mastery Foundation 1.0 – umgesetzt
Details: `docs/ARMOR_MASTERY.md`.
- **Rüstungstypen:** `ItemDefinition.armor_type`; vergeben nur bei eindeutigen Daten.
  - Leather: Cap, Gloves, Boots. Cloth: Linen Trousers. Mail: Hollow-Warden-Set.
  - Wanderer's Coat und Warlord Helm bleiben ohne Typ. Plate-Items gibt es in den Daten nicht (Tests nutzen
    Testitems).
- **Burden:** nur die fünf vorhandenen Slots, Tabelle und Stufen wie entworfen; volle Platte = 39 = Heavy.
  - Waffen, Schilde und Shoulders/Back/Wrists/Belt zählen nicht.
  - Wirkt nur auf das Gehtempo und die Recovery-Phase. Dash und Parry/Block bleiben unberührt (getestet).
- **XP:**
  - Quellen: Kill-Mastery-XP des Gegners, einmal pro Instanz; Block/Parry echter Angriffe: 3 XP einmal pro
    Angriff, höchstens 15 je Gegner.
  - Keine XP aus eingesteckten Treffern oder Trainingszielen.
  - Verteilung nach Abdeckung (15/40/10/25/10 %); Anteile leerer Slots gehen verloren.
  - Kurve 100 · 1,15^(n−1), **provisorisch**.
- **Meilensteine:** wie entworfen, skaliert mit der Abdeckung; Iron Discipline senkt die Gehstrafe.
  - Neue Stats: magic/physical resistance, skill/attack recovery speed, poise, block efficiency.
- **UI:** Seite „Armor“ im Character-Buch. Das Fenster hat immer volle Größe, die Tabs springen nicht (class_ui
  geprüft).
- **Save v10:** Migration v9→v10 (alle Tracks Stufe 1). Items, Slots und Loadouts bleiben unangetastet.

## 4. Hollowwood Loot Economy 1.0 – Grundlage, Balance gestoppt
Details: `docs/ECONOMY.md`, Bericht unter `tests/output/economy_report.txt`.
- **Umgesetzt:**
  - Felder `base_value` und `special_sell_value`, Seltenheitsfaktoren 1,0/1,6/2,5/4,0/7,0.
  - `EconomyService`: Verkaufswert und Verkaufstransaktion hinter dem Itemschutz.
  - `EconomySimulation`.
- **Ergebnis:** keine Material-, Gold- oder XP-Schleife.
  - Gold kann keine Items kaufen, weil es keinen Händler gibt.
  - Ein besiegter persistenter Boss bleibt über Save/Load weg und bringt keine neue Belohnung (getestet).
- **Nicht geändert:** Lootdrops und Goldmengen.
- **Offen** (fehlende Designwerte, nicht geraten):
  - Item-Basiswerte – deshalb ist derzeit nichts verkaufbar.
  - Gegnerränge Elite/Boss und deren Gold.
  - Gold aus Quests und Truhen (beides existiert nicht).
  - Händler/Verkaufsort und ob Unique/Set beim Verkauf eine Bestätigung brauchen.
  - Größenordnung: Alle Flask-Upgrades zusammen kosten 8950 Gold, ein Grunt bringt 3 Gold.

## Nicht umgesetzt (Ausschlüsse eingehalten)
Nicht umgesetzt wurden:
- Weapon Mastery und Kombos
- Combat-Rework
- Bogen, Guardian/Soulbinder
- Questlinien
- Affixmigration
- Forge-Rework, Awakening
- neue Regionen und Berufe

## Testläufe (alle tatsächlich ausgeführt)
Godot 4.7.2, `--path .`; jeder Lauf über einen Wrapper mit Hash-Prüfung von `project.godot` und den echten Saves.

| Lauf | Ergebnis |
|---|---|
| `--headless --import` (nach jedem Paket) | PASS, keine Fehler |
| Startprüfung (Import + 300 Frames Hauptszene, Filter ERROR/WARNING) in isolierter Kopie | PASS, 0 Treffer |
| Paket 1: `salvage` | erst 4 FAIL (Testfehler: Rope Belt ergibt meist nichts, Rezepte nicht gelernt) → PASS 9/9 |
| Paket 1: professions, save, save_foundation, stash, stash_ui, inventory_ui, equipment, presets, crafting_save, professions_ui, hollowwood, workshops, loop, inventory, crafting_loop, ui_layout, haven | erst 3 FAIL (alte Migrationstests kannten `origin` nicht; Stapel bekamen `unknown_legacy` → Fix: Stapel werden beim Laden bereinigt) → PASS |
| Paket 2: `consumables` | Fehler gefunden: Maras Fenster unerreichbar (siehe 2); nach Fix PASS 12/12 |
| Paket 2: 22 Suites (prologue, story, old_road, haven, stash, save*, hud, inventory_ui, class_ui, input, combat_feedback, defense, dash, movement, light_attack, skills, Klassen, status_effects, talents) | erst 1 FAIL (Migrationstest `test_prologue`) → PASS 187/187 |
| Paket 3: `armor_mastery` | PASS 8/8 |
| Paket 3: 31 Combat-/Klassen-/Save-Suites | PASS 284/284 |
| Paket 4: `economy`, `salvage` | PASS 13/13 |
| Abschluss gezielt, 52 von 71 Suite-Dateien (alle oben genannten Bereiche) | **PASS 404/404** |
| `ui_gallery.gd` nur geänderte Screens, 1920×1080 bei 100 % und 150 % (bei Salvage zusätzlich `inventory_tooltip`): `professions_salvage`, `hud`, `hud_combat`, `hud_consumables`, `flask_upgrades`, `character_armor`, `character` | PASS (6/6, 12/12, 3/3 je Skala) |
| `prologue_playtest.gd` (`--fixed-fps 60`) | PASS |
| `ui_playtest.gd` | PASS 213/213 |
| `loop_playtest.gd` | PASS |
| `class_playtest.gd` | FAIL 1/430 („1080p_125 tooltip for war_bb_price on hover“), 2× reproduziert. **Vorbestehend:** auf dem Basis-Commit `761c671` (temporärer Worktree) tritt derselbe Fehler auf; dort gab es zusätzlich 18 weitere Fehler im frischen Worktree, die nicht weiter untersucht wurden. |
| Volle Unit-Suite, volle Galerie, Auflösungsmatrix, 720p/4K | NOT RUN (Testpolitik) |
| Sichtprüfung Screenshots | MANUAL ONLY: Salvage-Seite 150 %, HUD mit Trankbuff 150 %, Mara-Fenster 150 %, Armor-Seite 150 % |

## Save
- Version **10**. Migrationen: 7→8 (Herkunft `unknown_legacy`), 8→9 (Consumables), 9→10 (Armor Mastery).
- Alle früheren Migrationen sind erhalten.
- Migrationen wurden nur an Test-Payloads geprüft; echte Spielstände wurden nicht geladen.
- Echte v7-Spielstände des Nutzers würden beim nächsten Laden im Speicher migriert und erst beim nächsten Speichern
  als v10 geschrieben.

## Bekannte Einschränkungen
- **Tasten 1/2:** Der Waffen-Schnellwechsel hat keine Taste mehr (Entscheidung nötig).
- **Ohne sichtbare Wirkung, solange Inhalte fehlen:**
  - Whisperbloom/Statusresistenz (keine Status-Angriffe auf den Spieler)
  - Magic Resistance (Gegner machen nur physischen Schaden)
  - Mail/Plate-Poise (Spieler-Poise hat keine Spielwirkung)
- **Provisorisch:** Armor-XP-Werte und -Kurve, Trank-/Flask-/Salvage-Werte, Alchemie-Rezepte.
- **Kein Händler:** Verkaufen existiert nur als Regel. Basiswerte fehlen.
- **Trinken:** Die Gehgeschwindigkeit beim Trank (45 %) übernimmt den Flask-Wert, weil kein eigener Wert entworfen
  war.
- **Tod/Respawn:** Ladungen bleiben unverändert (nicht spezifiziert).
- **Trinken bei vollen HP:** erlaubt.
- **Bestehender Fehler:** `class_playtest`-Hover-Fehler bei 1080p/125 % (siehe oben).

## Empfehlungen für den nächsten Auftrag
1. Neue Tasten für den Waffen-Schnellwechsel festlegen (oder bewusst streichen) und Options › Controls anpassen.
2. Item-Basiswerte und Gegnerränge (Elite/Boss) entwerfen, dann einen Händler (Trading House) mit Verkauf und
   Bestätigung für Unique/Set bauen.
3. Status-Angriffe von Gegnern auf den Spieler und eine Spieler-Poise-Mechanik. Dann Whisperbloom freigeben;
   Mail/Plate-Poise und Magic Resistance werden spürbar.
4. Plate-Rüstungsteile und Typen für Wanderer's Coat und Warlord Helm entscheiden; danach Armor-XP-Kurve im
   Playtest balancieren.
5. Den `class_playtest`-Hover-Fehler bei 1080p/125 % untersuchen (vorbestehend).
