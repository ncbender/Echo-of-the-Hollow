# Inventory Save/Load Roundtrip 1.0

Klärt Handoff-Befund #3 (`docs/CHATGPT_PROJECT_HANDOFF.md`, Abschnitt 7): Im `rpg_playtest` war nach Save/Load
der Vergleich „loaded state equals the saved snapshot“ fehlgeschlagen, laut Bericht nur unter `inventory`.
Save v15 unverändert, keine Codekorrektur.

## 1. Reproduktionsweg und getestete Daten

Neuer Test `tests/integration/test_inventory_save_roundtrip.gd` (4 Tests). Er nutzt die echte Pipeline:
`Character.to_dict` → `SaveSystem.save_to` (JSON-Payload mit Checksumme, Datei unter `user://test_saves/`)
→ `SaveSystem.load_from` (JSON-Parse, Migration, `Character.from_dict`, `Inventory.from_array` mit
`ItemStats.sanitize`). Echte Spielstände werden weder gelesen noch geschrieben. Die Testdateien werden in
`after_each` gelöscht.

Die Items stammen nur aus vorhandenen Erzeugungswegen:

| Art | Items | Erzeugung |
|---|---|---|
| Startausrüstung (ausgerüstet im Basic-Adventurer-Loadout) | `iron_sword`, `leather_cap`, `wanderer_coat`; `steel_greatsword` in der Tasche | `CharacterFactory.create_new` |
| Verbrauchsgegenstand (Stapel) | 3× `minor_potion` | Startitems |
| Material (Stapel) | 37× `iron_ore`, 5× `timber` | `Inventory.add_item` |
| Items aus dem Save-Ablauf des Playtests | `militia_sword`, `oak_shield`, `copper_ring`, `echo_blade` | `Inventory.add_item(..., ORIGIN_FOUND)` |
| Evolvierende Waffe | `stormcaller_fang` (einziges Item mit `evolution_id`) | `Inventory.add_item` |
| Gewürfeltes Equipment | Rare-`steel_greatsword`, Item-Level 7 (Affixe mit `tier`/`tier_model`, gespeicherter Basisschaden, Instanz-Rarity, Herkunft) | `ItemCreation.generate` (Seed 4711, `crafting_tier_weights`) |
| Inaktives Loadout | Wechsel zum Warrior: Das Basic-Adventurer-Loadout (Schwert, Kappe, Mantel) wird inaktiv; im Warrior-Loadout liegen Rare-Greatsword und Ring | `Character.switch_class`, `CharacterEquipment.equip` |

Verglichen werden:
- **streng**: Typ und Wert an jedem Pfad, jeder Schlüssel, die Itemreihenfolge;
- `Inventory.to_array()` und `CharacterEquipment.to_dict()` (alle Loadouts);
- der ganze `Character.to_dict()` wie im Playtest (`loop_playtest.comparable`: ohne Spielzeit und Besuchszähler);
- Instanz-IDs, Definition und Slot jeder Loadout-Referenz, aktiv und inaktiv;
- Itemanzahl, belegte Taschenplätze, `integrity_errors`, Stats;
- der Waffenschaden, wie ihn `PlayerProgressionBridge` an den Kampf gibt (`WeaponDamage.of`), und der Itemtext (`ItemDescriber.text`).

Jede Abweichung wird mit Pfad, beiden Werten und Typ ausgegeben.

Der veraltete Teil des Playtests (Inventarknopf „Equip“, `rpg_playtest.gd` Zeilen 98/102) ist nicht übernommen.
Ausgerüstet wird direkt über `CharacterEquipment.equip`.

## 2. Wurde die ursprüngliche Abweichung reproduziert?

**Ja, in derselben Form:** Nach dem ersten Save/Load unterscheidet sich im ganzen Charakter-Dictionary nur der
Schlüssel `inventory`. Genau zwei Pfade weichen ab:

| Pfad | Vorher | Nachher |
|---|---|---|
| `inventory[7].base_damage` (`militia_sword`) | `12.600000000000001` (float) | `12.6` (float) |
| `inventory[11].evolution` (`stormcaller_fang`) | fehlt (Instanz hat `evolution = {}`) | `{"path": "", "stage": 1, "xp": 0}` |

**Nicht bewiesen ist**, dass der alte Playtest-Lauf an genau diesen Pfaden scheiterte. Sein Log
(`tests/output/rpg_playtest_log.txt`) nennt keinen Pfad, und der Playtest wurde nicht erneut ausgeführt. Er hatte
`militia_sword` in der Tasche, aber keine `stormcaller_fang`. Die Basis-Abweichung ist deshalb die wahrscheinliche
Ursache, aber nicht rückwirkend belegt.

Der fehlerhafte Equip-Ablauf verfälscht den Vergleich selbst nicht. Snapshot und Laden liegen beide nach diesem
Ablauf; die fehlgeschlagenen Klicks ändern nur, was vorher ausgerüstet war.

## 3. Ursachen und Bewertung

**a) `base_damage`: Parse-Genauigkeit von Godot-JSON.**
- `SaveSystem.write_payload` schreibt mit `full_precision` und damit korrekt: `"12.600000000000001"`.
- Godots JSON-Parser liest diese 17-stellige Zahl aber als `12.6` zurück, einen um 1 ULP anderen Double.
- Gegenprobe: `14.016000000000002` (`echo_blade`, `stormcaller_fang`) kommt bitgleich zurück. Es ist also kein
  allgemeiner Verlust, sondern betrifft einzelne Werte.
- Der Kommentar in `save_system.gd` („load back bit-identical“) gilt deshalb nicht für jeden Wert.

Wirkung:
- relativ ca. 1e-16;
- `WeaponDamage.of` vorher und nachher innerhalb 1e-14;
- Itemtext gleich;
- nach dem ersten Laden stabil: Der zweite Save/Load ist bitgleich, es gibt kein fortlaufendes Driften.

Itemdaten gehen nicht verloren. Eine exakte Korrektur bräuchte ein anderes Zahlenformat im Save (z. B. Bits als
Ganzzahl oder Hex-Text), also eine Schemaänderung. Darauf habe ich bewusst verzichtet, weil der Nutzen fehlt.

**b) `evolution`: Normalisierung beim Laden.**
- `Inventory.from_array` ruft `ItemStats.sanitize` auf. Für Items mit Evolution setzt das den expliziten
  Startzustand `{"stage": 1, "xp": 0, "path": ""}`.
- Eine frisch erzeugte, unbenutzte Waffe hat `{}` (der Zustand entsteht sonst erst beim ersten Treffer,
  `ItemEvolution._ensure_state`).
- Die Zugriffe `evolution_stage()`/`evolution_xp()`/`evolution_path()` lesen vorher wie nachher 1 / 0 / "".

Folgen im Spiel:
- Zwei Stellen fragen `evolution.is_empty()` ab:
  - `StashService._plain` gilt nur für Stapel, und evolvierende Items stapeln nicht.
  - `SalvageService.has_investments` (Warnung „upgrades are lost“). Hier ist `stormcaller_fang` das einzige
    evolvierende Item, und es hat kein Herstellungsrezept. Es ist also nicht zerlegbar, und die Abfrage wird für
    dieses Item nie erreicht.
- **Heute ohne Verhaltenswirkung**, deshalb keine Korrektur.
- **Latentes Risiko:** Bekommt ein evolvierendes Item später ein Rezept, würde ein unbenutztes Exemplar erst nach
  Save/Load als „mit Investitionen“ gewarnt.
- Begrenzter Vorschlag für diesen Fall: `has_investments` sinngemäß prüfen (Stufe > 1, XP > 0 oder Pfad gesetzt)
  statt `is_empty()`. Ohne Schemaänderung.

**Reihenfolge und Zahlentypen:**
- Die Itemreihenfolge bleibt erhalten.
- int/float-Typen ändern sich nicht: `ItemInstance.from_dict` normalisiert `tier`/`tier_model`, `flat`/`percent`
  und Evolution, und die Affixe des Rare-Items sind nach dem Laden typ- und wertgleich.

**Verlust oder Veränderung echter Daten:** keiner. IDs, Definitionen, Mengen, Rarity, Item-Level, Affixe,
Herkunft, alle Loadout-Referenzen (aktiv und inaktiv), Anzahl, Plätze und Stats sind gleich.

**Grenzen der Untersuchung:**
- Nicht abgedeckt sind Essenzen, Sockel, Quality, `progress` und Lager-Items. Diese entstehen nur über
  Crafting bzw. Lagertransfers und wurden nicht über eigene Wege erzeugt.
- Der Haven-Lager-Roundtrip läuft in den bestehenden Stash-Tests.

## 4. Korrektur

Keine Codeänderung. Der Test vergleicht streng und erlaubt genau zwei benannte Regeln, jede eng gefasst:
- `FLOAT_PARSE`: nur `base_damage`, relativ ≤ 1e-14;
- `EVOLUTION_DEFAULT`: nur ein fehlender Evolution-Zustand, der als exakt der Startzustand eines evolvierenden
  Items zurückkommt.

Er prüft außerdem, dass es **genau diese zwei** Befunde sind. Zusätzlich muss der zweite Roundtrip ohne jede
Regel bitgleich sein. Jede neue Abweichung schlägt fehl.

`rpg_playtest.gd` ist unverändert. Sein strenger Vergleich wird bei vorhandener `militia_sword` mit diesem
Basiswert weiter fehlschlagen. Ihn auf die aktuellen Regeln anzupassen (Equip-Knopf, semantischer Vergleich)
bleibt ein eigener Auftrag.

## 5. Ausgeführte Tests

- `./tools/run_tests.ps1 -Suite inventory_save_roundtrip`: **4 passed, 0 failed**.
  - `test_inventory_survives_the_save_pipeline`
  - `test_second_roundtrip_is_bit_identical`
  - `test_loadout_references_resolve_after_load`
  - `test_whole_character_snapshot_as_in_the_playtest`
- Ein erster, rein strenger Lauf derselben Datei schlug wie erwartet an genau den zwei Pfaden aus Abschnitt 2 fehl.
- Hilfsprobe im Scratch-Verzeichnis (außerhalb des Projekts): JSON-Roundtrip der Basiswerte pro Item. Daraus
  stammen der Parse-Befund und die Gegenprobe `14.016000000000002`.
- Keine weiteren Suites, kein `check_project.ps1` (keine Codekorrektur), kein Playtest, keine Full-Suite.

## 6. Commit und uncommittete Anteile

- Commit: `b98c662`, nur `tests/integration/test_inventory_save_roundtrip.gd` (+ `.uid`) und dieses Dokument.
- Alle übrigen lokalen Änderungen des Branches `dev/roots-remember-m4` bleiben unberührt und uncommittet,
  insbesondere `CLAUDE.md`, `project.godot` und die vielen ungetrackten Dateien früherer Arbeiten.
