# Loot & Equipment 2.5 – Material & Economy Reality Audit

Status: **READ-ONLY-Audit**, keine Implementierung. Stand: Branch `audit/loot-equipment-2-5-economy`
(abgezweigt von `dev/echo-blade-migration-fix` @ `6c3a64c`), 2026-10-27.
Geprüft wurden ausschließlich Daten (`data/`), Szenen (`scenes/maps/`) und Code (`scripts/`). Es wurden keine Tests,
Playtests oder Saves gestartet bzw. geöffnet. Alle Upgrade-Zahlen stammen aus dem Prototyp-Designstand (nicht im Code).

Begriffe für die Beschaffbarkeit:
- **REGULÄR** – im normalen Spiel ohne Debug erreichbar (Platzierung in einer spielbaren Karte, Drop, Rezept).
- **CODE, NICHT REGULÄR** – Definition/Logik vorhanden, aber kein regulärer Bezug.
- **NUR DEBUG** – nur über Debug-Hotkeys (`scripts/world/game_map.gd`: F4/F7/F10), Tests oder Save-Migrationen.
- **GEPLANT** – nur in Doku/Design, nicht implementiert.

---

## 1. Executive Summary

- **Materialbasis existiert, aber nur auf Einstiegsniveau.** Es gibt genau vier Rohstoff→Verarbeitungs-Ketten
  (Erz→Barren, Holz→Brett, Haut→Leder, Flachs→Leinen), alle `rarity = Normal`, alle Item-Level-neutral. Es gibt **keine**
  höherstufigen Erze/Hölzer/Leder/Stoffe – die Level-Bänder 25–100 des Prototyps haben kein Material.
- **Gathering ist regulär und reproduzierbar**, aber klein: 11 Knotenarten an 3 Karten, ein voller Durchlauf aller
  Knoten liefert ca. **13 Erz, 20 Holz, 7 Häute, 4 Flachs** (inkl. Grunt-Drops). Das ergibt ≈ 4 Barren, 10 Bretter,
  3 Leder, 1 Leinen pro Respawn-Zyklus.
- **Gold ist fast nicht vorhanden.** Einmalig ≈ 55–70 Gold aus Story/Bossen, wiederholbar nur **9 Gold pro Betreten
  des Whisper Forest** (3 Grunts) und 2 Gold je nicht-persistenter Wolfsbegegnung. Kein Händler, kein Verkauf
  (kein Item hat `base_value`), keine Kisten, keine Quest-Goldbelohnungen.
- **Prototyp-Goldpreise sind gegen die heutige Wirtschaft um 1–3 Größenordnungen zu hoch** (z. B. Rare L12 Reforge
  77 Gold ≈ 26 Grunts; Epic L70 Quality 0→20 = 5 131 Gold). Dies ist kein Argument gegen die Formeln, sondern
  belegt, dass die **Goldquellen fehlen** (siehe `docs/ECONOMY.md` „Offen“).
- **Keine seltene Komponente erfüllt „Kampf ODER Gathering“.** Einziger Kandidat mit regulärer Quelle ist
  `hollow_essence` (nur Kampf). Echte Content-Lücke.
- **Bestehende Resonance-Forge-Operationen** (`reforge`, `quality`, …) laufen heute über Crafting-Währungen
  (`transmute_core`, `forge_crystal`, …), die **nur per Debug** erhältlich sind.

---

## 2. Materialbestand mit Quellenstatus

Alle Rohstoffe/verarbeiteten Materialien: `category = 4` (Material), `rarity = 0`, `max_stack = 50`
(Pfad `data/items/<id>.tres`).

### 2.1 Berufsmaterialien

| ID | Anzeigename | Art | Rezept (Pfad `data/professions/recipes/`) | Beruf | Bezugsquelle | Status | Heutige Verwendung |
|---|---|---|---|---|---|---|---|
| `iron_ore` | Iron Ore | Roh | Input `bs_smelt_iron` | Mining | Iron Vein, Rich Iron Vein, Ancient Deposit; Drop Grunt (2) & Grove Warden (2) | REGULÄR | Barren, Resonance Elixir, Smithy-Rezept Iron Sword (3), Debug-Kits |
| `iron_ingot` | Iron Ingot | Verarbeitet | Output `bs_smelt_iron` (3 Erz → 1) | Blacksmithing | nur Herstellung | REGULÄR | Militia Sword (3), Revitalisierung Tanner's Lodge (2) / Woodwright (2) |
| `timber` | Timber | Roh | Input `ww_saw_planks` | Woodcutting | Oak Tree, Old Oak; Torn Note (2, einmalig) | REGULÄR | Bretter, Restaurierungen, Barkskin/Ember, Smithy-Rezept (1) |
| `oak_plank` | Oak Plank | Verarbeitet | Output `ww_saw_planks` (2 Holz → 1) | Woodworking | nur Herstellung | REGULÄR | Oak Shield (4), Militia Sword (1), Revitalisierungen (4–6) |
| `raw_hide` | Raw Hide | Roh | Input `lw_tan_hide` | Skinning | Stag Remains, Elk Remains | REGULÄR | Leder, Restaurierung Tanner's Lodge (2) |
| `cured_leather` | Cured Leather | Verarbeitet | Output `lw_tan_hide` (2 Häute → 1) | Leatherworking | nur Herstellung | REGULÄR | Gloves (3), Bracers (4), Boots (3), Mantle (1), Shield (1), Revitalisierungen |
| `flax_fiber` | Flax Fiber | Roh | Input `tl_weave_linen` | Herbalism | Wild Flax | REGULÄR | Leinen, Rope Belt (4), Gloves (1), Quickstep (2), Restaurierung Weaver's House (4) |
| `linen_cloth` | Linen Cloth | Verarbeitet | Output `tl_weave_linen` (3 Flachs → 1) | Tailoring | nur Herstellung | REGULÄR | Trousers (4), Mantle (3), Cloak (5), Boots (1), Revitalisierungen |
| `duskleaf` | Duskleaf | Roh (Kraut) | Input aller Alchemie-Rezepte | Herbalism | Duskleaf Patch, Duskleaf Cluster | REGULÄR | Tränke (2–4), Restaurierung Alchemist's Cottage |
| `stone` | Stone | Roh | – (keine Verarbeitung) | Mining | Forest Rock | REGULÄR | Restaurierungen, Stoneskin (Rezept gesperrt) |

Alchemie-Produkte (`category = 5`): `ember_draught`, `quickstep_tincture`, `barkskin_tonic`, `resonance_elixir` –
REGULÄR herstellbar; `stoneskin_draught`, `whisperbloom_concentrate` – **CODE, NICHT REGULÄR**
(`craftable = false`, `al_stoneskin.tres`, `al_whisperbloom_concentrate.tres`).

**Nicht vorhanden (GEPLANT/fehlt):** jede höhere Erz-/Holz-/Leder-/Stoffstufe (Stahl, Hartholz, …), Juwelier-
Materialien, Nebenprodukte/Residues (`docs/PROFESSIONS.md` „Salvaging“: „keine Rückstände“).

### 2.2 Resonance-Forge-Materialien und Sonstiges

| ID | Rarity | Stack | Bezugsquelle | Status |
|---|---|---|---|---|
| `hollow_essence` | Rare | 99 | Drop Grunt (1), Hardened Husk (1), Grove Warden (1); Readable „Memory Fragment“ Whispering Stone (1, einmalig) | REGULÄR (nur Kampf) |
| `storm_ore`, `blood_steel_ingot`, `frost_glass` | Magic | 99 | nur `DEBUG_CRAFTING_ITEMS` (F4) | NUR DEBUG |
| `transmute_core`, `forge_crystal`, `focus_catalyst`, `imprint_shard`, `socket_chisel`, `essence_siphon`, `awakening_stone` | Magic–Epic | – | nur F4 | NUR DEBUG |
| `garnet`, `impact_rune`, `storm_wolf_essence`, `stone_golem_essence` | Rare/Epic | – | nur F4 | NUR DEBUG |
| `supply_crate` | Normal (Quest) | 5 | Story-Pickups Old Road (2×) | REGULÄR, einmalig (Old-Smithy-Restaurierung) |
| `pattern_leather_bracers` | Magic | – | Story-Pickup „Hunter's Pack“ Whisper Forest | REGULÄR, einmalig |
| `gold_coin` | Normal, `is_currency` | 9999 | siehe Abschnitt 5 | REGULÄR (klein) |

Beleg Debug: `scripts/world/game_map.gd:18-28` (`DEBUG_MATERIALS`, `DEBUG_CRAFTING_ITEMS`). Eine Suche nach allen
Forge-Währungs-IDs außerhalb `data/items` und `data/crafting` findet ausschließlich `game_map.gd`.

---

## 3. Gathering-Erträge

Regeln: `scripts/rpg/world/resource_gathering.gd`, `docs/GATHERING.md`. Ertrag = festes Budget `yield_quantity`
pro Zyklus, auf `steps` verteilt, `completion_bonus = 1` garantiert auf dem letzten Schritt (Teil des Budgets,
kein Zusatz). Plan einmal pro Zyklus fest (Seed Map/Knoten/Zyklus), Respawn in Echtzeit, Erschöpfung im Save.
Keine Bonus-/Crit-/Werkzeugmechanik (Werkzeuge reine Optik).

| Knoten (`data/world/resource_nodes/`) | Ressource | Fundort (Anzahl) | Beruf / Stufe | Ertrag/Zyklus | Schritte | Respawn | Weiterverarbeitung |
|---|---|---|---|---|---|---|---|
| `oak_tree` | Timber | Whisper Forest (4), Old Road (1) | Woodcutting 1 | 3 | 3 | 90 s | 2 → 1 Brett |
| `old_oak` | Timber | Whispering Stone (1) | Woodcutting 3 | 5 | 4 | 150 s | 2 → 1 Brett |
| `forest_rock` | Stone | Whisper Forest (3), Old Road (1) | Mining 1 | 3 | 3 | 90 s | – |
| `iron_vein` | Iron Ore | Whisper Forest (2) | Mining 1 | 2 | 4 | 120 s | 3 → 1 Barren |
| `rich_iron_vein` | Iron Ore | Whispering Stone (1) | Mining 3 | 3 | 5 | 180 s | 3 → 1 Barren |
| `ancient_deposit` | Iron Ore | Whisper Forest (1) | Mining 1 | 3 | 5 | **einmalig** (`respawn_seconds = 0`) | 3 → 1 Barren |
| `wild_flax` | Flax Fiber | Whisper Forest (2) | Herbalism 1 | 2 | 2 | 90 s | 3 → 1 Leinen |
| `duskleaf_patch` | Duskleaf | Whisper Forest (1) | Herbalism 1 | 1 | 1 | 150 s | Alchemie |
| `duskleaf_cluster` | Duskleaf | Whispering Stone (1) | Herbalism 3 | 2 | 3 | 180 s | Alchemie |
| `stag_remains` | Raw Hide | Whisper Forest (2) | Skinning 1 | 2 | 2 | 180 s | 2 → 1 Leder |
| `elk_remains` | Raw Hide | Whispering Stone (1) | Skinning 3 | 3 | 3 | 240 s | 2 → 1 Leder |

Platzierung: `scenes/maps/whisper_forest.tscn:117-203`, `scenes/maps/whispering_stone.tscn` (Resources),
`scenes/maps/old_road.tscn:399-406`. „Hollowwood“ ist kein eigener Knoten-/Kartenname, sondern der Weltname
(Region `hollow_outskirts` mit Whisper Forest, Old Road, Whispering Stone; `waystone_definition.gd`). Kein Knoten liegt
in Haven.

**Ertrag pro vollem Zyklus** (alle Knoten aller drei Karten einmal + die 3 Whisper-Forest-Grunts, ohne einmalige Quellen):

| Material | Knoten | + Kampf | Summe | → verarbeitet |
|---|---|---|---|---|
| Iron Ore | 4 + 3 | 6 (3 Grunts) | **13** | ≈ 4 Iron Ingot |
| Timber | 12 + 3 + 5 | – | **20** | 10 Oak Plank |
| Raw Hide | 4 + 3 | – | **7** | 3 Cured Leather (Rest 1) |
| Flax Fiber | 4 | – | **4** | 1 Linen Cloth (Rest 1) |
| Duskleaf | 1 + 2 | – | **3** | – |
| Stone | 9 + 3 | – | **12** | – |

Einmalig zusätzlich: Ancient Deposit 3 Erz, Grove Warden 2 Erz, Torn Note 2 Holz.

**Stundenraten: NICHT BESTIMMBAR.** Laufwege, Ladezeiten, Kampfdauer und das reale Verhalten beim Zurückkehren
(Kartenwechsel ↔ Echtzeit-Respawn) sind nicht gemessen. Die Respawn-Zeiten sind nur eine theoretische Obergrenze.

**Engpässe:** Flachs (nur 2 Knoten à 2, Linen braucht 3 Flachs) ist der härteste; Häute (2 Karten, 180–240 s);
Erz (Barren 3:1). Holz/Stein sind reichlich. Stufe-3-Knoten verlangen Berufsstufe 3.

---

## 4. Verarbeitung und Berufe

Berufe: `data/professions/professions/` – Sammeln: Mining, Herbalism, Woodcutting, Skinning (keine Werkbank).
Handwerk: Blacksmithing (`old_smithy`), Leatherworking (`tanners_lodge`), Tailoring (`weavers_house`), Woodworking
(`woodwrights_workshop`), Alchemy (`alchemists_cottage`). **Kein Jewelcrafting**, keine Arkan-/Bogenbauer-Spezialisierung.

| Rezept | Werkbank | Stufe | Input → Output | XP | Status |
|---|---|---|---|---|---|
| `bs_smelt_iron` | Old Smithy | 1 | 3 Iron Ore → 1 Iron Ingot | 8 | REGULÄR |
| `ww_saw_planks` | Woodwright's Workshop | 1 | 2 Timber → 1 Oak Plank | 8 | REGULÄR |
| `lw_tan_hide` | Tanner's Lodge | 1 | 2 Raw Hide → 1 Cured Leather | 8 | REGULÄR |
| `tl_weave_linen` | Weaver's House | 1 | 3 Flax Fiber → 1 Linen Cloth | 8 | REGULÄR |
| `bs_militia_sword` | Old Smithy | 1 | 3 Ingot + 1 Plank | 30 | REGULÄR |
| `lw_leather_gloves` | Tanner's Lodge | 1 | 3 Leather + 1 Flax | 25 | REGULÄR |
| `lw_worn_boots` | Tanner's Lodge | 2 | 3 Leather + 1 Linen | 28 | REGULÄR |
| `lw_leather_bracers` | Tanner's Lodge | 3 | 4 Leather; Freischaltung über `pattern_leather_bracers` | 30 | REGULÄR (Muster einmalig) |
| `tl_rope_belt` | Weaver's House | 1 | 4 Flax | 20 | REGULÄR |
| `tl_linen_trousers` | Weaver's House | 1 | 4 Linen | 25 | REGULÄR |
| `tl_padded_mantle` | Weaver's House | 2 | 3 Linen + 1 Leather | 28 | REGULÄR |
| `tl_traveler_cloak` | Weaver's House | 3 | 5 Linen | 32 | REGULÄR |
| `ww_oak_shield` | Woodwright's Workshop | 1 | 4 Plank + 1 Leather | 30 | REGULÄR |
| `al_*` (4 Tränke) | Alchemist's Cottage | 1–3 | 2–3 Duskleaf + Holz/Flachs/Erz | 20–30 | REGULÄR |
| Smithy `forge_iron_sword` | Old Smithy (`data/base/buildings/smithy.tres`) | – | 3 Iron Ore + 1 Timber → Iron Sword | – | REGULÄR (Legacy-Rezept) |

Werkstattstufen (Ruined/Restored/Revitalized) ändern laut `docs/PROFESSIONS.md` „nur Aussehen und Atmosphäre,
nie Rezepte, Mengen oder Werte“. Restaurierung kostet Rohstoffe (z. B. Woodwright 8 Holz + 4 Stein), Revitalisierung
verarbeitete Materialien (z. B. Tanner's Lodge 4 Bretter + 3 Leder + 2 Barren); kein Gold.
`common_hall`, `fallen_barracks`, `forgotten_study`, `trading_house` haben keine Kosten/Werkbank.

**Lager-Verbrauch:** `ProfessionService.material_plan` zieht an Haven-Werkbänken Tasche zuerst, dann Lager
(`scripts/rpg/professions/profession_service.gd:149-165`). Die **Resonance Forge** (`CraftingService`) zählt und
verbraucht nur die **Tasche** (`crafting_service.gd:57`, `:444`) – relevant für ein späteres Upgrade-Menü.

**Ausrüstungstypen mit Berufsrezept:** 1 Waffe (Militia Sword) + Iron Sword (Legacy), 1 Schild, Handschuhe, Bracers,
Stiefel, Hose, Gürtel, Mantel, Umhang. **Ohne Herstellungsweg:** Kopf (Leather Cap, Helme), Brust (Wanderer Coat,
Warden Mail), alle anderen Waffenfamilien (Axt, Dolch, Streitkolben, Stab, Zauberstab, Bogen, Speer, Großschwert),
Ringe, Amulette. Alle berufshergestellten Items sind `base_item_level = 1` bzw. ohne Level (→ 1) und Normal/Magic.

**Mischmaterial-Items:** Militia Sword (Barren+Brett), Gloves (Leder+Flachs), Boots (Leder+Leinen), Mantle (Leinen+
Leder), Oak Shield (Brett+Leder). Eine Regel „welches Hauptmaterial nutzt ein Upgrade?“ existiert nicht.

**Herstellbarkeit der Prototyp-Mengen** (Bezug: Abschnitt 3, ein voller Zyklus):

| Pro Aktion benötigt | Rohstoff | ≈ volle Zyklen |
|---|---|---|
| 3 Iron Ingot | 9 Erz | 0,7 |
| 4 Oak Plank | 8 Holz | 0,4 |
| 3 Cured Leather | 6 Häute | 0,9 |
| 3 Linen Cloth | 9 Flachs | 2,3 |

Einzelaktionen im Band 10–24 sind also heute machbar; Serien (siehe Abschnitt 6) nicht.

---

## 5. Goldquellen und Gold-Senken

### 5.1 Quellen

| Quelle | Wert | Wiederholbar | Erreichbarkeit | Beleg |
|---|---|---|---|---|
| Grunt (Whisper Forest, 3×) | 3 Gold (+1 Essence, +2 Erz) | **ja**, bei jedem Laden der Karte (kein `persistent_id`) | regulär | `data/enemies/grunt_config.tres`, `whisper_forest.tscn:220-229` |
| Grove Warden | 25 Gold (+1 Essence, +2 Erz) | nein (`persistent_id`) | regulär | `grove_warden_config.tres` |
| Rootbound Husk | 2 | nur in nicht-persistenten Begegnungen | Story-Begegnungen, Trials | `rootbound_husk.tres` |
| Hollowfang Wolf | 1 | `road_side_wolves`, `shrine_side_wolves` (`persistent = false`) | regulär | `hollowfang_wolf.tres`, `old_road.tscn:466` |
| Hardened Husk | 4 | nein (Cart Second Wave), Warrior-Trial | Story | `hardened_husk.tres` |
| Story-Begegnungen Old Road / Shrine | Ambush 4, Cart Attack 5, Second Wave 6, Shrine Path 3 | nein (persistent) | regulär, einmalig | Kartenszenen |
| Torn Note (Readable) | 12 Gold + 2 Timber | nein (`read.road_note`) | regulär | `old_road.tscn:388-394` |
| Klassen-Trials (Prolog/Whispering Stone) | 4–8 Gold pro Welle (Configs in `data/trials/`) | Welle wiederholt sich, solange Ziel offen; Trial temporär | an Prologverlauf gebunden – **nicht als Dauerquelle beurteilbar** | `trial_station.gd:39-74` |
| Debug F10 | 100 Gold | – | NUR DEBUG | `game_map.gd:16` |
| Verkauf (`EconomyService.sell`) | `base_value × Faktor` | – | **CODE, NICHT REGULÄR**: kein Händler, kein Item hat `base_value` | `economy_service.gd:1-12`, `docs/ECONOMY.md` |
| Quest-Goldbelohnung, Kisten | – | – | **GEPLANT / nicht vorhanden** | `docs/ECONOMY.md` „Offen“ |

**Summe einmalig** (ohne Trials): 4+5+6+3 (Begegnungen) + 25 (Warden) + 12 (Note) = **55 Gold**.
**Wiederholbar pro Schleife:** 9 Gold (Whisper Forest) + 2 je Wolfsbegegnung. **Gold pro Stunde: NICHT BESTIMMBAR**
(Laufwege/Ladezeiten unbekannt).

### 5.2 Senken

| Senke | Kosten | Beleg |
|---|---|---|
| Hearth Flask Capacity (Mara) | 150 / 450 / 1 100 / 2 400 (Σ 4 100) | `progression_rules.gd:57` (Default, nicht in `.tres` überschrieben) |
| Hearth Flask Potency (Mara) | 200 / 550 / 1 300 / 2 800 (Σ 4 850) | `progression_rules.gd:60` |
| Talent-Respec | 1. frei, danach 10 + 2 × Klassenstufe | `data/progression/talent_rules.tres`, `talent_service.gd:110` |
| Klassen-Freischaltquests | je 20 Gold + 3 Hollow Essence | `data/quests/unlock_*.tres` |
| Crafting / Berufe / Restaurierung / Salvage | **kein Gold** | Rezepte, Ruinen, `SalvageService` |
| Ausrüstungs-/Verbrauchskauf | **nicht vorhanden** (kein Händler) | `docs/ECONOMY.md` |

Bereits die bestehenden Flask-Upgrades (8 950 Gold) übersteigen die reguläre Goldmenge um das ~160-Fache des
einmaligen Goldes.

---

## 6. Vergleich mit Upgrade-Prototypkosten

`B = round[(10 + 2L) × rarity]`. Werte mit exakter Arithmetik (n = s = f = q-Startwert 0, wenn nicht anders genannt).

| Item | B | Reforge (n=0 / n≥6) | 7 Reforges Σ | Refine T3 / T1 | Elevate T5→T4 / T2→T1 | Elevate-Kette Σ | Quality q0 / q19 | Quality 0→20 Σ |
|---|---|---|---|---|---|---|---|---|
| Normal L1 | 12 | 18 / 35 | 186 | 12 / 27 | 12 / 60 | 130 | 4 / 23 | 227 |
| Magic L12 | 41 | 62 / 117 | 627 | 41 / 91 | 41 / 205 | 443 | 13 / 76 | 748 |
| Rare L12 | 51 | 77 / 146 | 779 | 51 / 113 | 51 / 255 | 551 | 16 / 94 | 928 |
| Epic L45 | 190 | 285 / 542 | 2 895 | 190 / 418 | 190 / 950 | 2 052 | 57 / 350 | 3 423 |
| Epic L70 | 285 | 428 / 813 | 4 342 | 285 / 627 | 285 / 1 425 | 3 078 | 86 / 525 | 5 131 |

Hinweis Implementierung: `ceil(190 × 2.2)` ergibt in Float-Arithmetik 419 statt 418 – Formeln später ganzzahlig
(Prozent-/Promille-Faktoren) rechnen.

**In Grunts (3 Gold) ausgedrückt:** Normal L1 Reforge = 6 Grunts; Rare L12 Reforge = 26; Rare L12 Quality 0→20 = 310;
Epic L70 Reforge = 143. Gegen die **55 Gold einmalig** ist schon eine Rare-L12-Reforge (77) nicht bezahlbar.

**Materialserien (Hauptmaterial, Prototyp-Tabelle):**

| Serie | L1–9 | L10–24 |
|---|---|---|
| Quality 0→20 (Basis × 20 + 6 + 8) | 34 | 54 |
| 7 Reforges (Basis × 7 + 0+0+1+1+2+2+3) | 23 | 30 |
| Elevate-Kette T5→T1 | 12 + 3 selten | 16 + 3 selten |

Quality 0→20 an einer L12-Waffe = 54 Barren = 162 Erz ≈ **12 volle Zyklen**; an einem Tailoring-Item = 54 Leinen =
162 Flachs ≈ **40 Zyklen**.

**Item-Level-Realität:** Höchstes reguläres Item-Level ist 1 (Berufe, Startausrüstung, Funde). L12 existiert nur bei
`forged_blade`/`forged_greatsword` (Debug F4), L15 nur bei `echo_blade`, `crushing_oath`, `stormcaller_fang`
(Save-Migration/Debug). Items der Level 45/70 und Epic-Rarität mit Affixen sind regulär nicht beschaffbar; es gibt
auch keine zufälligen Ausrüstungsdrops (Gegner-`drops` sind feste `ItemCost`-Listen ohne Ausrüstung).

---

## 7. Seltene Materialien / fehlende Quellen

| Kandidat | Kampf | Gathering | Konkurrierende Nutzung | Bewertung |
|---|---|---|---|---|
| `hollow_essence` (Rare) | ja: Grunt 1 (wiederholbar), Hardened Husk 1, Warden 1 | **nein** | Klassenquests (3 je), Evolution `stormcaller` | erfüllt nur Kampf |
| `iron_ore` | ja (Grunt/Warden) | ja | Grundmaterial | erfüllt beide Wege, aber **nicht selten** |
| `storm_wolf_essence`, `stone_golem_essence`, `awakening_stone`, `garnet`, `impact_rune`, Forge-Währungen | nein | nein | Resonance Forge | NUR DEBUG |
| Seltene Gathering-Ressource (Erzader-Bonus, Seltenkraut, …) | – | – | – | **nicht vorhanden** |

**Ergebnis: echte Design-/Content-Lücke.** Kein existierendes Item erfüllt „selten + Kampf ODER Gathering“.
Es gibt zudem keinen Zufalls-/Chance-Mechanismus für Drops (`EnemyConfig.drops` = feste Mengen,
`game_map.gd:115-120`) und keinen Bonus-Ertrag beim Sammeln – eine seltene Komponente bräuchte also neue Mechanik,
nicht nur ein neues Item.

---

## 8. Konkrete Blocker

1. **Goldquellen fehlen.** 55 Gold einmalig + 9 Gold pro Whisper-Forest-Schleife; Verkauf technisch vorhanden,
   aber ohne Händler und ohne `base_value`. Jede Gold-Komponente der Formeln ist heute nicht bedienbar.
2. **Keine seltene Komponente mit zwei Bezugswegen**, außerdem weder Drop-Chancen noch Bonus-Ertrag im Sammeln.
   Elevate T3→T2 / T2→T1 ist damit nicht umsetzbar.
3. **Kein Material und kein Content über Item-Level 1 (regulär).** Level-Bänder 10–100 haben weder Ausrüstung noch
   Materialstufen; das Prototyp-Mengenmodell ist nur für 1–9 (eingeschränkt 10–24) überprüfbar.
4. **Hauptmaterial-Zuordnung undefiniert.** Kein Mapping Ausrüstungstyp → Material; Mischmaterial-Items und Typen ohne
   Beruf (Ringe, Amulette, Helme, Brust, 8 Waffenfamilien) haben keinen natürlichen Kandidaten.
5. **Flachs/Leinen-Engpass**: Tailoring-Upgrades wären mehr als 3× so teuer in Spielzeit wie Schmiede-Upgrades.
6. **Zwei konkurrierende Upgrade-Wege**: bestehende Resonance-Forge-Operationen `reforge`/`quality` mit Debug-Währungen
   (`data/crafting/operations/`) vs. neues Gold+Material-Design; zudem verbraucht die Forge nur aus der Tasche.

---

## 9. Empfehlungen für die nächsten Designentscheidungen

Keine neuen Balancewerte – nur zu treffende Entscheidungen:

1. **Goldquelle festlegen, bevor Goldpreise kalibriert werden.** Entscheiden, ob Händler/Verkauf (`base_value`-Tabelle,
   Trading House) und/oder Quest-/Kisten-Gold kommen. Erst danach lassen sich B-Faktoren gegen eine Einnahmerate
   prüfen; bis dahin sind alle Goldpreise **NICHT BEURTEILBAR** gegen ein Ziel, nur „zu hoch für heute“.
2. **Hauptmaterial-Mapping und Resonance-Forge-Verhältnis klären.** (a) Pro Ausrüstungstyp ein Hauptmaterial (inkl.
   Mischitems und Typen ohne Beruf: Schmuck, Helme, Brust, Fernkampf/Arkan-Waffen); (b) ob die neuen Aktionen die
   Forge-Operationen `reforge`/`quality` ersetzen oder deren Debug-Währungen regulär werden; (c) Tasche oder Tasche+Lager.
3. **Seltene Komponente als Content-Paket entscheiden:** welches Item, welcher Kampfweg (fester Drop eines persistenten
   Gegners vs. neue Drop-Chance-Mechanik) und welcher Gathering-Weg (neuer Knoten vs. Bonus-Ertrag) – inklusive der
   Frage, ob `hollow_essence` (bereits Senke in Klassenquests) dafür wiederverwendet werden darf.

Zusätzlich vorzumerken: Materialstufen für Level 10+ (oder bewusst „ein Material für alle Level, Menge skaliert“),
und Flachs-Ertrag/Linen-Verhältnis prüfen, bevor Tailoring-Items Upgrades bekommen.
