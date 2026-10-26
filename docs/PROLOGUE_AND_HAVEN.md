# Prolog & Haven (Vertical Slice 0.1)

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

Alle spielersichtbaren Texte sind englisch. Story, Gespräche, Ruinen und Wegsteine sind Daten unter
`data/`; der Code kennt keine einzelne Quest, Figur oder Ruine.

## Ablauf ✅

| # | Quest (`data/story`) | Ort | Schritte (Event → Flag) |
|---|---|---|---|
| 1 | **A Road Forgotten** | Old Road | `reach:road_signpost` → `encounter:road_ambush` (`prologue.road_cleared`) → `reach:cart_site`; Abschluss `prologue.road_walked` |
| 2 | **The Broken Cart** | Old Road | `encounter:cart_attack` → `talk:mara_cart` (`prologue.mara_rescued`) → 2× `interact:supply_crate` (`prologue.supplies_recovered`) → `encounter:cart_second_wave` (`prologue.cart_defended`) → `talk:mara_road_end`; Abschluss `prologue.cart_done` |
| 3 | **Shelter Among the Trees** | Haven | `enter:home_base` (`prologue.haven_discovered`) → `talk:mara_welcome` → `restore:old_smithy` (`prologue.smithy_restored`) → `talk:edrin_intro`; Abschluss `prologue.haven_settled` (Nordtor öffnet) |
| 4 | **The Whispering Stone** | Whispering Stone | `enter:whispering_stone` (`prologue.shrine_reached`) → 3× `trial_complete` → `class_chosen` (`prologue.first_class_selected`) → `waystone:whispering_stone`; Abschluss `prologue.stone_awakened` |
| 5 | **The First Binding** | Haven | `enter:home_base` → `talk:mara_return` → `talk:edrin_threat`; Abschluss `prologue.completed` |
| – | **The Roots Remember: The First Signs** | – | Hauptquest-Stub (`open_ended`, wartet auf ein späteres Update) |

`prologue.started` setzt die Charaktererstellung. Die Flags sind stabile IDs; Migration v4→v5 setzt sie
für Altstände (`SAVE_SYSTEM.md`).

## Story-System ✅
- `StoryQuestDefinition` (Schritte) → `StoryStep` (Ziele, `completion_flag`) → `StoryObjective` (`event_id`,
  Menge, `cumulative`). Fortschritt im bestehenden `QuestLog` (Zustand, `step`, Fortschritt).
- `StoryService.notify(character, event)`: einziger Eingang. Zählt jedes Event als Weltzähler
  `count.<event>`; kumulative Ziele lesen den Zähler (z. B. Echos, die vor dem Schritt gegangen wurden).
  Ereignisse für spätere Schritte überspringen nichts.
- Jeder abgeschlossene Schritt → `QuestLog.story_progressed` → `SessionState` fordert einen
  Meilenstein-Save an und zeigt bei Questabschluss „Quest complete: …“.
- HUD „Journey“: Kapitel, Quest, aktueller Schritt, Zähler.

## Welt-Bausteine (datengetrieben) ✅
| Knoten | Zweck |
|---|---|
| `StoryCondition` (Resource) | Flags benötigt/verboten, Quest-Zustand, Schrittbereich |
| `StoryTrigger` | Bereich → Story-Event und/oder einmaliger Tutorialhinweis (`hint.<id>`) |
| `Encounter` + `EncounterSpawn` | Gegnergruppe mit Varianten; persistent (`encounter.<id>`) oder pro Besuch; Bark/Hinweis beim Start; Laden mitten im Kampf startet ihn neu |
| `StoryNpc` / `CompanionNpc` | NPC je Map per Bedingung; Dialog oder Idle-Zeile; „!“ bei Story-Dialog |
| `StoryPickup` | Versorgungskisten: Item genau einmal (`pickup.<id>`), Event |
| `Readable` | Wegweiser, Notiz, Memory Fragment; Belohnung einmal (`read.<id>`), nie bei vollem Inventar |
| `StoryConditional` | blendet Kinder samt Kollision ein/aus (Trümmer auf der Straße, Nordtor) |
| `Checkpoint` | Rastplatz: Respawn + Spawn-ID, heilt; speichert nie |
| `Waystone` | Wegstein (siehe unten) |

Dialoge: `NpcDefinition` (`data/npcs`) mit `DialogueDefinition`-Liste (Bedingung, Zeilen, Event,
wiederholbar). Erster passender Dialog gewinnt. `DialoguePanel`: G/Enter weiter, Esc verlässt
(nichts abgeschlossen, neu startbar). Event erst nach der letzten Zeile.

## Mara Veyne ✅
- Bark am Wagen: „If you've got a blade, now's the time to use it!“
- Begrenzte Kampfhilfe, solange `the_broken_cart` Schritt ≤ 3: alle 2,4 s ein Treffer (6 Schaden,
  12 Poise) auf den nächsten Gegner im Umkreis von 110 px, über `Hurtbox.receive_hit`. Sie ist unverwundbar und gibt keine XP.
- Eskorte (`prologue.cart_done` bis Haven):
  - Mara folgt der Brotkrumenspur des Spielers. Sie braucht keine Wegfindung und kann nicht hängen bleiben.
  - Ist sie länger als 1,2 s weiter als 190 px entfernt, erscheint sie mit Einblendung hinter dem Spieler.
    Das passiert höchstens alle 4 s, es gibt also keinen Teleport-Spam.
  - Übergänge prüfen nur den Spieler.
  - Nach Laden oder Mapwechsel erscheint Mara neben dem Spieler.

## Haven & Restaurierung ✅
- Ummauertes Ruinendorf mit zehn festen Ruinen (`data/haven/ruins`, davon vier Werkstätten im Artisan Quarter).
  Freie Bauplätze gibt es nicht.
- Vier Tore: Süden zur Old Road, Norden zum Whispering Stone (gesperrt bis zu Edrins Gespräch), Osten zum
  Whisper Forest, Westen zur Proving Arena.
- Haven hat Klassenstation (Klassenwechsel, Talente, Presets, Respec) und Wegstein, aber keine Gegner.
- `RestorationService.advance(character, ruin, target)` ist atomar; `restore` ist der Schritt nach `restored`.
  Der Ablauf:
  1. Ziel prüfen: genau die nächste Stufe (wiederholte oder veraltete Anfragen, z. B. Doppelklick, werden
     abgelehnt - nie wird eine Stufe übersprungen), Bedingung, Materialplan.
  2. Den Materialplan einmal verbrauchen (`ProfessionService.material_plan`/`consume_plan`, derselbe Plan wie
     an den Werkbänken: Tasche, nach Restaurierung des Old Storehouse auch das Haven-Lager, Tasche zuerst).
  3. Flag `haven.<id>.restored` bzw. `haven.<id>.revitalized` setzen.
  4. Stufe setzen. `WorldState.restoration_changed` löst den Meilenstein-Save aus.
  5. Kapazität neu berechnen.
  6. Story-Event melden (nur beim Restaurieren).
- Stufen: Ruined → Restored → Revitalized. Revitalisieren gibt es, wo die Daten `revitalize_costs` haben
  (die vier Werkstätten des Artisan Quarter). Old Smithy und Old Storehouse: nur Restored.
- Restaurieren und Revitalisieren ändern Aussehen, Ordnung und Atmosphäre - nie Werte, Kapazität oder
  Produktionsmengen.
- `RuinSite` erweitert `BuildPlot`. Restauriert zeigt sie das Gebäude der Ruine mit seiner bisherigen
  Funktion (Schmiede: Resonance Forge und Rezepte, Lager: +10 Slots, Kaserne: Trainingsplatz).
- Werkstätten (Ruine mit `profession_id`, ohne `building_id`): G öffnet in jeder Stufe zuerst die Werkbank.
  Dort zeigt das Berufefenster die Stufe und den Knopf „Restore/Revitalize the workshop“. Das
  Restaurierungsfenster zeigt Kosten (Bestand, Tasche/Lager, Fehlmenge) und das Ergebnis; der Knopf steht
  in der festen Fußzeile, nach einem Schritt schließt das Fenster.
- In der Welt sind die drei Stufen unterscheidbar: Trümmer; geschlossene Wände, Dielen, Vorrat;
  zusätzlich Laternen, Werkzeugleiste, Banner in Berufsfarbe, Pflanzkasten. Werkbank und Schild bleiben
  an ihrem Platz.
- Save bleibt v7: Stufen standen schon im Save (`world.restoration`); alte Spielstände laden die
  Werkstätten als Ruined, ohne etwas abzubuchen.

| Ruine | Restaurierbar | Kosten | Bedingung |
|---|---|---|---|
| The Old Smithy („A Fire Rekindled“, Pflicht) | ja | 2 Supply Crate (vom Wagen) | Haven erreicht |
| The Old Storehouse (optional, +10 Slots) | ja | 4 Timber, 2 Stone (Seitenweg der Old Road) | Old Smithy restauriert |
| The Tanner's Lodge | ja + Revitalized | 6 Timber, 3 Stone, 2 Raw Hide · Revitalized: 4 Oak Plank, 3 Cured Leather, 2 Iron Ingot | Haven erreicht |
| The Weaver's House | ja + Revitalized | 6 Timber, 3 Stone, 4 Flax Fiber · Revitalized: 4 Oak Plank, 3 Linen Cloth, 1 Cured Leather | Haven erreicht |
| The Woodwright's Workshop | ja + Revitalized | 8 Timber, 4 Stone · Revitalized: 6 Oak Plank, 2 Iron Ingot, 1 Cured Leather | Haven erreicht |
| The Alchemist's Cottage | ja + Revitalized | 6 Timber, 3 Stone, 2 Duskleaf · Revitalized: 4 Oak Plank, 2 Linen Cloth, 4 Duskleaf | Haven erreicht |
| The Fallen Barracks, The Common Hall, The Trading House, The Forgotten Study | nein | – | „Restoration unavailable for now.“ |

Werkstattkosten sind provisorisch balanciert (Overnight Artisan Crafting 01): nur Material aus Whisper Forest
bzw. Whispering Stone und deren Verarbeitung auf Stufe 1, keine Mine nötig.

## Whispering Stone & Klassenwahl ✅
- Pfad mit Begegnung, optionaler Seitenbereich (Memory Fragment „Three stood here when the stone was
  whole.“), Rastplatz, drei Echos um das „Heart of the Stone“, beschädigter Wegstein.
- Echos nutzen die Trial-Infrastruktur. Reihenfolge frei, Wiederholung erlaubt, nichts bleibt dauerhaft.
  - Tod oder Abbruch beendet das Echo sauber, ein Neustart ist sofort möglich.
  - Fallen alle Gegner vor den Zielen, kommt eine neue Welle.
  - Trials laufen nur auf `rules.trial_map_ids`.
- Die drei Echos:
  - Warrior: 50 Rage, Furious-Strike-Treffer, Poise-Bruch des Hardened Husk (`POISE_BREAKS`, `EnemyConfig.id`)
  - Arcanist: 4 Zauber (Mana), Arcane-Bolt-Treffer, Marken, Detonation
  - Shadowrunner: 40 Focus, Shadowstep, Weak Points, Execution
- Die Wahl gibt es erst nach allen drei Echos, mit zwei Klicks (Wählen, Bestätigen).
  - Genau eine Klasse wird freigeschaltet und aktiv, die anderen bleiben gesperrt. Es bleibt kein
    Trial-Zustand übrig.
  - Danach wird ein Meilenstein-Save angefordert. Erfolg zeigt das Fenster erst nach erfolgreichem Schreiben.
  - Bei Fehler sieht der Spieler einen Hinweis; der Save wird wiederholt.
- Guardian und Soulbinder erscheinen nirgends: nicht in der Wahl, nicht in Klassen- oder Questliste.

## Wegsteine ✅
- Genau vier sind geplant (`data/world/waystones`): Haven (von Anfang an aktiv), The Whispering Stone,
  Chapel Waystone, Warden's Rest.
- Nur die ersten beiden funktionieren im Slice; die anderen stehen in der Liste als „undiscovered“.
- Erwecken (nach der Klassenwahl): „May the road remember those who return.“, gefolgt von einem
  Meilenstein-Save.
- Schnellreise zwischen aktiven Wegsteinen ist kostenlos, aber nicht mit Gegnern im Umkreis von 220 px
  und nicht in einem Echo.

## Offen
- ⬜ Mehr Hollowwood mit Chapel Waystone und Warden's Rest
- ✅ Revitalisierung der vier Werkstätten (Overnight Artisan Crafting 01); ⬜ für die übrigen Ruinen
- ⬜ Weitere Restaurierungen
- ⬜ Echte Grafik und Sound
- ⬜ Begleiter-KI über die gescriptete Hilfe hinaus
- ⬜ Gegnernamen am Gegner
