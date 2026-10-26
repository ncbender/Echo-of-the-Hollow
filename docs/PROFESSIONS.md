# Berufe (Professions Foundation 1.0)

Neun klassenunabhängige Berufe. Jeder Charakter hat alle neun, jeweils Stufe 1–100. Spielerseitige Texte sind Englisch.

| Art | Beruf | Werkbank (Haven) | Sammelknoten |
|---|---|---|---|
| Herstellung | Blacksmithing | The Old Smithy | – |
| Herstellung | Leatherworking | The Tanner's Lodge | – |
| Herstellung | Tailoring | The Weaver's House | – |
| Herstellung | Woodworking | The Woodwright's Workshop | – |
| Herstellung | Alchemy | The Alchemist's Cottage | – |
| Sammeln | Mining | – | Iron Vein, Ancient Deposit, Forest Rock |
| Sammeln | Herbalism | – | Wild Flax, Duskleaf Patch |
| Sammeln | Woodcutting | – | Oak Tree |
| Sammeln | Skinning | – | Stag Remains |

## Architektur
- **Definitionen (Resources):**
  - `ProfessionDefinition` (`data/professions/professions/`): id, Art, Farbe, Werkbank (Ruinen-ID), max. Stufe,
    XP-Kurve `xp_to_next(level) = round(60 · 1.045^(level-1))`.
  - `ProfessionRecipeDefinition` (`data/professions/recipes/`): id, Beruf, Stufe, Werkbank (leer = die des Berufs),
    Materialien (`ItemCost`), Ergebnis + Menge, XP, `is_processing` (Schmelzen, Gerben, Weben, Sägen),
    Freischaltquelle (`AUTOMATIC`, `TRAINER`, `RECIPE_ITEM`, `QUEST`, `DROP`) + Referenz, `craftable` +
    `unavailable_reason`, `output_parameters` (vorbereitet für spätere Material-/Affixparameter, ungenutzt).
  - `ResourceNodeDefinition` erweitert um `profession_id`, `required_level`, `gather_xp`.
  - `ItemDefinition.teaches_recipe_id` (Rezeptgegenstand), `RuinDefinition.profession_id` (Werkbank der Ruine).
- **Laufzeit:** `CharacterProfessions` (`Character.professions`): Stufe/XP je Beruf, gelernte Rezepte,
  Rezepte mit vergebenem Erstherstellungsbonus. Signale `changed`, `leveled_up`, `recipe_learned` für die UI.
- **Regeln:** nur `ProfessionService` (zustandslos). Keine berufs- oder rezeptspezifischen Verzweigungen im Code.
- **Spielstand:** `professions` im Save (v7), siehe `docs/SAVE_SYSTEM.md`.

## Stufen, Ränge, XP
- Ränge: Apprentice 1–20, Journeyman 21–40, Artisan 41–60, Expert 61–80, Master 81–100.
- Mehrere Stufenaufstiege auf einmal möglich. Auf Stufe 100 wird keine XP mehr gespeichert.
- Anteil der Basis-XP nach Abstand Berufsstufe − Rezeptstufe: ≤ 5 → 100 %, 6–15 → 50 %, 16–25 → 15 %, > 25 → 0 %.
  Dieselben Bänder gelten fürs Sammeln (`gather_xp`, `required_level` des Knotens).
- Erstherstellungsbonus: Die erste erfolgreiche Herstellung eines Rezepts gibt einmalig zusätzlich 100 % der
  Basis-XP. Der Bonus ist im Save vermerkt, also gibt es ihn auch nach Save/Load nicht zweimal.
- XP gibt es nur für erfolgreiche Transaktionen. Lernen gibt nie XP.

## Rezepte lernen
- `AUTOMATIC`: wird gelernt, sobald die Stufe reicht (neuer Charakter, Laden, Stufenaufstieg).
- `RECIPE_ITEM`: `ProfessionService.learn_from_item` verbraucht den Gegenstand und lernt das Rezept in einem Schritt.
  Ist das Rezept schon bekannt, wird abgelehnt und der Gegenstand bleibt erhalten.
- `TRAINER`, `QUEST`, `DROP`: als Daten vorbereitet, noch ohne Quelle im Spiel.
- Gelernte Rezepte bleiben dauerhaft. Doppeltes Lernen ändert nichts (keine XP, keine Items).

## Herstellen (Transaktion)
`ProfessionService.craft(character, recipe_id, station_id)` prüft alles vorab und ändert bei einer Ablehnung nichts.
Prüfreihenfolge:
1. Rezept existiert
2. herstellbar
3. gelernt
4. Stufe
5. Werkbank („Craft this at …“)
6. Materialien („Missing materials: Iron Ore 1/3.“)
7. Platz in der Tasche fürs Ergebnis

Danach wird der **Materialplan** verbraucht, das Ergebnis hinzugefügt (Fehler → Rückabwicklung), die Erstherstellung
markiert und XP vergeben. Schnelle Wiederholungen sind unabhängige Transaktionen und werden jeweils neu geprüft.
Ergebnisse sind normale Iteminstanzen aus dem bestehenden Itemmodell. Die Forge-Affixe bleiben unverändert.

**Lager-Materialien:** An einer Haven-Werkbank (eine Ruine) zählt nach der Restaurierung des Old Storehouse
(`StashService.is_upgraded`) auch das Haven-Lager. Zuerst wird die Tasche verbraucht, dann das Lager.
`material_plan` erzeugt den Plan einmal; Anzeige („bag 18, stash 6“), Prüfung und Verbrauch nutzen denselben Plan,
jede Einheit wird über `Inventory.count` einmal gezählt. Ohne Werkbank wird nie aufs Lager zugegriffen.

## Inhalte (Vertical Slice)
| Rezept | Beruf | Stufe | XP | Materialien → Ergebnis |
|---|---|---|---|---|
| Smelt Iron Ingot (Verarbeitung) | Blacksmithing | 1 | 8 | 3 Iron Ore → Iron Ingot |
| Militia Sword | Blacksmithing | 1 | 30 | 3 Iron Ingot + 1 Oak Plank → Militia Sword |
| Tan Hide (Verarbeitung) | Leatherworking | 1 | 8 | 2 Raw Hide → Cured Leather |
| Leather Gloves | Leatherworking | 1 | 25 | 3 Cured Leather + 1 Flax Fiber → Leather Gloves |
| Leather Bracers | Leatherworking | 3 | 30 | 4 Cured Leather → Leather Bracers (Pattern: Leather Bracers) |
| Weave Linen (Verarbeitung) | Tailoring | 1 | 8 | 3 Flax Fiber → Linen Cloth |
| Linen Trousers | Tailoring | 1 | 25 | 4 Linen Cloth → Linen Trousers |
| Saw Oak Planks (Verarbeitung) | Woodworking | 1 | 8 | 2 Timber → Oak Plank |
| Oak Shield | Woodworking | 1 | 30 | 4 Oak Plank + 1 Cured Leather → Oak Shield (Schild, vorhandener Itemtyp; keine Bögen) |
| Stoneskin Draught | Alchemy | 1 | 25 | 2 Duskleaf + 1 Stone → nur Daten, **nicht herstellbar** |

Alchemie: Das Spiel hat noch kein Verbrauchsgut-System mit Buffs. Der Trank ist deshalb nur als Daten angelegt und
in UI und Service klar als „Potions cannot be used yet“ gekennzeichnet. Es werden keine nutzlosen Tränke ausgegeben.

## Sammeln
`ResourceGathering.gather` prüft zusätzlich die Berufsstufe des Knotens und vergibt nach Erfolg Sammel-XP.
Die Erschöpfung liegt in `WorldState.map_states` mit Echtzeit-Stempel. Sie wird gespeichert, also setzt Save/Load
einen Knoten nicht zurück und es gibt keine doppelte Ernte oder XP.

## Artisan Quarter (Haven)
- Haven wächst nach Westen: ein ummauerter Bereich (x −728…−400) hinter dem verbreiterten Westdurchgang.
  Vier Werkstätten in zwei Reihen an einem Weg. Das Tor zur Proving Arena sitzt jetzt an der Westmauer des Viertels.
- Haven hat zehn feste Gebäude (keine freien Bauplätze).
- Werkstätten sind `RuinSite`s mit `profession_id`. Werkbank und Schild sind gezeichnet, die Werkbank funktioniert
  schon als Ruine. Ihre Stufen kommen aus dem bestehenden Restaurierungssystem; die Restaurierung ist in dieser Version
  noch nicht freigegeben.
- Old Smithy = Blacksmithing:
  - Ruine: Restaurierungsfenster wie bisher (Prolog), mit Knopf „Use the Workbench“.
  - Restauriert: Resonance Forge, im Reiter Craft mit Knopf „Blacksmithing Workbench“.
- Keine Werkbänke in Common Hall, Trading House, Fallen Barracks, Forgotten Study.

## UI
`ProfessionsPanel` (P überall zum Ansehen; an einer Werkbank mit deren Beruf):
- Book Tabs Crafting/Gathering, kompakte Berufskarten (Stufe, Rang, XP-Balken)
- Detailseite mit Rezeptliste; gesperrte Rezepte mit Grund
- ausgewähltes Rezept: Ergebnis mit Item-Tooltip, Werkbank, Stufe, XP-Vorschau, Materialien mit Bestand
  (inkl. Lager), Craft, Learn (Rezeptgegenstand), Rückmeldung
- Sammelseite: Knoten mit Stufe, Ertrag, XP
