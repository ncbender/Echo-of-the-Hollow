# NPC Quest Turn-ins 1.1 – Mixed Rewards: Quest- und Inventar-Audit

Read-only. Branch `audit/npc-turnins-11-mixed-rewards` von `dev/npc-quest-turnins-10-t3` @ `2f44058` (Save v15).

Was dieses Audit nicht getan hat:
- keine Implementierung, keine Daten- oder Wertänderung
- keine Tests oder Playtests
- keine echten Saves geöffnet

Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`) wurden nicht angefasst. Grundlage sind die Dokumente
`docs/NPC_QUEST_TURNINS_1_0_AUDIT.md`, `_T1.md`, `_T2.md` und `_T3.md` sowie der Code in diesem Stand.

---

## 1. Kurzfazit

- **`the_broken_cart` ist als Quest geeignet**, der NPC ist aber das Problem:
  - Der natürliche Geber ist **Mara**. Auf der Old Road ist sie ein `CompanionNpc` ohne Service.
  - Sie verschwindet dort mit `prologue.haven_discovered`, also beim ersten Betreten von Haven.
  - In Haven ist ihr einziger Service-Slot mit `hearth_flask` belegt.
  - **Ohne eine kleine Erweiterung an Maras Fenster ist eine Abgabe bei Mara nicht möglich.**
- **T3-Befund:** `StoryNpc.has_pending_reward` prüft nur `offers_service`, nicht den Service-Typ (`scripts/world/story_npc.gd`).
  Bekäme Mara heute einen Reward, stünde ein „?“ über ihr, aber G öffnete das Flask-Fenster ohne Abholmöglichkeit. Marker und
  Abholweg müssen zusammen kommen.
- **Atomare Mixed-Auszahlung ist mit vorhandenen Mitteln sicher machbar.** Es braucht keine neue Inventory-Engine:
  - Gesamtplatzprüfung nach dem Muster `SalvageService._room_after_removal`
  - Gutschrift über `Inventory.add_item` (pro Item alles-oder-nichts)
  - Rollback über `remove_quantity` (Muster `SalvageService.apply`)
  - Gold zuletzt, weil Währung keinen Slot braucht
  - Das Claimed-Flag erst ganz am Ende
- **Material-Empfehlung:** **30 Gold + 3 Timber + 2 Stone**. Das sind höchstens zwei neue Taschenplätze. Beide Materialien
  sind unverkäuflich (`base_value` 0) und werden früh gebraucht (Old Storehouse 4 Timber / 2 Stone).
- **Alternative ohne Mara-Eingriff:** `shelter_among_the_trees` bei **Edrin**. Seine Quest endet mit `talk:edrin_intro`, und
  Edrin hat den Service `quest_rewards` schon. Das wäre eine reine Datenänderung plus Mixed-Vertrag.
- **Altstände:** Der T1-Hook (`QuestRewardService.register_completion` in `StoryService._settle`, nur live) greift
  automatisch für jede Quest mit Reward-Daten. Historische Abschlüsse und `resettle` erzeugen nichts. Keine Migration, v15
  bleibt.

---

## 2. Quest-/NPC-Eignung (Audit A)

### 2.1 `the_broken_cart` (`data/story/the_broken_cart.tres`)

| # | Punkt | Befund |
|---|---|---|
| 1 | Ziele | S0 `encounter:cart_attack` · S1 `talk:mara_cart` (Flag `prologue.mara_rescued`) · S2 `interact:supply_crate` ×2, **kumulativ** (`prologue.supplies_recovered`) · S3 `encounter:cart_second_wave` (`prologue.cart_defended`) · S4 `talk:mara_road_end` |
| 2 | Abschluss / Nachfolger | Dialog `mara_road_end` → `notify(talk:mara_road_end)` → `_settle` → `completed`, Flag `prologue.cart_done`, Start von `shelter_among_the_trees` |
| 3 | Geber | Mara Veyne (`data/npcs/mara.tres`). Alle Storydialoge der Quest gehören ihr (`mara_cart`, `mara_crates_hint`, `mara_road_end`) |
| 4 | Erreichbarkeit danach | Old-Road-Mara (`scenes/maps/old_road.tscn:410-417`, `CompanionNpc`): Bedingung `C_mara` = `road_walked` ∧ ¬`haven_discovered`. Sie folgt dem Spieler ab `cart_done` (`C_follow`) und **verschwindet beim Betreten von Haven**. Die Old Road bleibt erreichbar (`home_base.tscn:339`, `target_map_id = old_road`), Mara dort aber nicht. Haven-Mara (`home_base.tscn:293-301`) ist ab `haven_discovered` **dauerhaft** da |
| 5 | Dialoge, Marker, Services | Haven: `mara_return` (first_binding S1), `mara_welcome` (shelter S1, „!“), `mara_smithy_hint` (wiederholbar), `mara_history` (wiederholbar ab `dialogue.mara_welcome`). Service `hearth_flask` (`FlaskPanel`) mit „Talk to Mara Veyne“-Knopf. Road: Companion, `offers_service = false` |
| 6 | Service-Kollision | **ja**: ein Service pro NPC (`NpcDefinition.service`), Haven-Mara hat `hearth_flask` |
| 7 | Soft-Lock-Gefahr | **keine** mit dem T1-Modell. Der Abschluss setzt `cart_done` und startet die Nachfolger wie heute, die Abgabe hängt nur am Reward. Mit Option 2/3 aus dem 1.0-Audit (Story erst bei Abgabe) wäre der **Weg nach Haven** blockiert (`cart_done` steuert Folgen und Übergang). Das ist ausgeschlossen, weil kein neues Statusmodell kommt |

**Zeitlicher Ablauf für den Spieler:**
1. Der Anspruch entsteht auf der Old Road (Ende von `mara_road_end`).
2. Die Road-Mara kann ihn nicht auszahlen (kein Service).
3. In Haven hat zuerst `mara_welcome` („!“) Vorrang.
4. Danach öffnet Mara den Flask-Service.

Die Abholung ist also frühestens nach `mara_welcome` in Haven möglich, und dann dauerhaft.

### 2.2 Alternativen (vorhandene Quests/NPCs)

| | A1 `shelter_among_the_trees` → Edrin | A2 `the_broken_cart` → Edrin |
|---|---|---|
| Abschluss | `talk:edrin_intro` (Edrin, Haven), Flag `prologue.haven_settled` öffnet das Nordtor | wie 2.1 |
| Service | Edrin hat `quest_rewards` (T2), **keine Kollision** | dto. |
| Eingriff | nur Daten + Mixed-Vertrag | nur Daten + Mixed-Vertrag |
| Nachteil | anderer Questpilot als gewünscht | erzählerisch unstimmig (Maras Karren, Edrin zahlt); Edrins Fenster hätte zwei Karten (siehe §5.2) |

Empfehlung: **`the_broken_cart` bei Mara (Haven)**, wenn Mara als Geberin gewollt ist (kleine Erweiterung §5.1). Sonst **A1**
als konfliktfreie Variante. A2 ist nicht empfohlen.

---

## 3. Vorhandene Materialkandidaten (Audit B)

| Item-ID | Name | Stack | Inventar | Verwendung (Daten) | früh verfügbar | Wirtschaft |
|---|---|---|---|---|---|---|
| `timber` | Timber | 50 (`data/items/timber.tres`) | Material (Kategorie 4), stapelbar, 1 Slot je 50 | Ruinen: Old Storehouse 4, Tanner's Lodge 6, Woodwright 8, Weaver's/Alchemist's; Rezepte `ww_saw_planks` (2 → 1 Oak Plank), `al_barkskin_tonic`, `al_ember_draught`; Base-Gebäude | Oak Tree/Old Oak (`yield 3`), Torn Note (+2) auf der Old Road | `base_value` 0 → **unverkäuflich**, kein Gold-Loop |
| `stone` | Stone | 50 (`data/items/stone.tres`) | dto. | Ruinen: Old Storehouse 2, Tanner's 3, Woodwright 4, Weaver's/Alchemist's; `al_stoneskin` | Forest Rock (`yield 3`) | unverkäuflich |
| `iron_ore` | Iron Ore | 50 (`data/items/iron_ore.tres`) | dto. | `bs_smelt_iron` (3 → 1 Iron Ingot), Evolution `stormcaller`, `al_resonance_elixir` | Iron Vein (`yield 2`), Grunt-Drop 2, Grove Warden 2 | unverkäuflich; aber schon reichlich über Kämpfe |

Nicht empfohlen:
- `hollow_essence`: Magic-Rarity, Crafting-Material, auch Readable-Reward und Bossdrop
- `supply_crate`: Questitem

**Empfehlung: 30 Gold + 3 Timber + 2 Stone** (Designfreigabe nötig). Begründung:
- **Thema:** Baumaterial aus Maras Wagenladung, passend zur folgenden Haven-Restaurierung.
- **Menge:** ungefähr ein Sammelzyklus pro Material. Das ist **knapp unter** den Kosten des Old Storehouse (4/2), der als
  nächste Ruine nach der Schmiede freigeschaltet wird (`data/haven/ruins/old_storehouse.tres`, `C_after_smithy`). Die Belohnung
  hilft also spürbar, ersetzt das Sammeln aber nicht.
- **Kapazität:** schlimmstenfalls 2 neue Slots (keine passenden Stapel vorhanden), Gold keinen.
- **Wirtschaft:** Beide sind unverkäuflich, also kein Gold-Loop. Sie sind über Sammelknoten ohnehin unbegrenzt verfügbar, die
  Belohnung spart nur Zeit.

Variante „Storehouse geschenkt“: 4 Timber + 2 Stone, als bewusste Designentscheidung.

---

## 4. Inventarkapazität und Atomizität (Audit C)

### 4.1 Vorhandene Mittel

| Baustein | Ort | Eignung |
|---|---|---|
| `Inventory.room_for(id)` | `scripts/rpg/items/inventory.gd:72-86` | pro Item korrekt (Stapel zuerst, dann freie Slots). **Nicht additiv**: zwei Materialien sehen dieselben freien Slots |
| `Inventory.add_item(id, n)` | `inventory.gd:91-117` | pro Item alles-oder-nichts, füllt Stapel zuerst |
| `Inventory.remove_quantity(id, n)` | `inventory.gd:164-179` | Rollback-Baustein, nimmt kleinste Stapel zuerst; die Menge stimmt, die Stapelaufteilung kann sich ändern |
| Gesamtplan | `SalvageService._room_after_removal` (`scripts/rpg/professions/salvage_service.gd:159-173`) | genau die nötige Rechnung (Stapel-Rest abziehen, `ceil(left/max_stack)` Slots), aber **privat**, mit fest eingebautem `+1` (entferntes Item), ohne Währungs-Sonderfall und ohne Zusammenfassen doppelter IDs |
| Rollback | `SalvageService.apply` (`salvage_service.gd:139-153`) | Muster: Schritt für Schritt hinzufügen, bei Fehler alles Hinzugefügte mit `remove_quantity` zurücknehmen |
| Negativ-Vorbild | `Readable.interact` (`scripts/world/readable.gd:34-49`) | Prüfung je Reward einzeln, Flag **vor** der Gutschrift, Rückgabewert ignoriert → Teilauszahlung möglich (bekannt, Audit 1.0 E9, nicht behoben) |

### 4.2 Kleinste Erweiterung (Empfehlung, nicht umgesetzt)
- **Daten:** `StoryQuestDefinition.turn_in_items: Array[ItemCost]` neben `turn_in_gold` (`ItemCost` =
  `scripts/rpg/base/item_cost.gd`). Edrin/`the_first_binding` bleibt leer, also bleibt sein Claim byte-gleich.
- **Prüfung:** `QuestRewardService.can_claim` bekommt zusätzlich eine Gesamtplatzprüfung, etwa
  `_room_for_all(character, items)`:
  - pro Item-ID summiert, Währung übersprungen
  - Stapel-Rest abziehen, Slots `ceil` addieren, Vergleich mit `free_slots()`
  - Rechnung von `_room_after_removal` ohne das `+1`

  Wird ein Teil davon zu einer kleinen statischen Funktion an `Inventory` oder einem gemeinsamen Helfer extrahiert, bleibt
  Salvage verhaltensgleich (Optional; sonst eigene private Kopie im Service).
- **Auszahlung** in `claim`:
  1. alle Prüfungen (Anspruch, nicht abgeholt, keine Trial, Gesamtplatz)
  2. Materialien nacheinander über `add_item(id, n, ORIGIN_QUEST)`; bei einem Fehler alle bereits hinzugefügten über
     `remove_quantity` zurücknehmen, Rückgabe des Fehlers, **kein Flag**
  3. Gold zuletzt (Währung, praktisch nie abgelehnt). Scheitert es doch, werden die Materialien ebenfalls zurückgenommen
  4. erst dann das Claimed-Flag setzen, danach `request_critical_save`
- **Volle Tasche:** Es gibt keine Gutschrift, die Meldung lautet z. B. „Your bag is full. Make room to receive …“, und der
  Anspruch bleibt `pending`. Das Fenster zeigt den Grund als deaktivierten Knopf und Tooltip, wie bei der Trial-Sperre.
- **Fälle, die abgedeckt sein müssen:**

| Fall | Erwartung |
|---|---|
| vorhandener, teilweise gefüllter Stapel | 0 neue Slots, wenn der Rest reicht |
| volle Stapel | neuer Slot |
| alle Slots belegt, aber Stapel-Rest reicht | Claim erlaubt |
| ein Material passt, das zweite nicht | Ablehnung **vor** jeder Gutschrift |
| erzwungener Fehler im zweiten Schritt | Rollback (Test-Hook wie `SalvageService.apply`) |

- **Wiederholung und Save/Load:** unverändert über die T1-Flags. Tasche, Gold und Flag ändern sich im selben synchronen
  Aufruf, also enthält jeder Snapshot alles oder nichts.
- **Herkunft:** Materialien sind Stapel, `origin` wird auf Stapeln nicht gespeichert (`inventory.gd` `add_item`). Das ist
  bewusst unproblematisch.

Ergebnis: **Sichere atomare Auszahlung ist möglich**, ohne eine neue Inventory-Engine.

---

## 5. Service-/UI-Konflikte (Audit D)

### 5.1 Mara
- Der vorhandene Service `hearth_flask` (`data/npcs/mara.tres`, `FlaskPanel`, `GameHud.open_npc_service`) und der Knoten
  `offers_service = true` (`home_base.tscn:293-301`) bleiben.
- **Kleinste sichere Option (Empfehlung):** ein Knopf „Quest Rewards“ im `FlaskPanel`, genau nach dem Muster des
  vorhandenen „Talk to Mara Veyne“-Knopfs (`scripts/ui/flask_panel.gd:62-68`).
  - Er ist nur sichtbar, wenn für Mara eine Reward-Quest `pending` oder `claimed` ist.
  - Er ruft `hud.open_npc_service(&"quest_rewards", site)` auf, also das unveränderte `QuestRewardPanel` mit Maras Quests
    (`quests()` filtert nach `npc_id()` des Knotens).
  - Kein Multi-Service-System, keine Änderung an Flask-Upgrades.
- Alternativen:
  - `NpcDefinition.service` als Liste plus Auswahl: eine Architekturänderung, für einen zweiten Turn-in zu groß.
  - Reward-Karten direkt im Flask-Fenster: dupliziert die Logik des `QuestRewardPanel`.
- **Marker-Anpassung zwingend:** `StoryNpc.has_pending_reward` muss neben `offers_service` prüfen, ob die Abholung von diesem
  NPC erreichbar ist (Service `quest_rewards` **oder** Maras Flask-Knopf). Sonst zeigt der Marker in die Irre (§1).
  Kleinste Lösung: Das „?“ gilt für Knoten mit `offers_service`, deren Service-Fenster den Reward erreicht. Das wird über die
  Service-ID entschieden, und der Flask-Service bekommt den Knopf. Diese Regel muss Design festlegen.
- Interaktionspriorität bleibt: Ein ungehörter Storydialog (`mara_welcome`, `mara_return`) zeigt „!“ und hat Vorrang.

### 5.2 `QuestRewardPanel` bei mehreren Karten
- Heute claimt der Footer-Knopf die **erste** `pending`-Quest des NPCs (`pending_quest()`, sortiert nach ID,
  `scripts/ui/quest_reward_panel.gd`). Das ist eindeutig, solange pro NPC **eine** Quest einen Reward hat.
- **Mara + `the_broken_cart`:** ein NPC, eine Quest → eindeutig, keine Panel-Änderung nötig.
- **A2 (Edrin mit zwei Quests):** Der Footer zahlt nach ID-Reihenfolge (`the_broken_cart` vor `the_first_binding`), der
  Spieler kann nicht wählen. Dann bräuchte es einen Claim-Knopf pro Karte (`claim(quest_id)`). Das ist ein weiterer Grund
  gegen A2.
- **Edrins Claim ändert sich nicht:** Sein Fenster listet nur Quests mit `turn_in_npc_id == edrin`. Mit leerem
  `turn_in_items` bleibt `the_first_binding` reines Gold, und `can_claim` ändert sich für ihn nur um eine immer erfüllte
  Platzprüfung (keine Items).

### 5.3 Anzeige des Mixed Rewards
- `QuestRewardPanel._quest_card` zeigt heute nur „Reward: N Gold“. Für Materialien braucht es je eine Zeile
  („3 Timber“, „2 Stone“) oder Item-Icons (`ItemIcon`).
- Die Erfolgsmeldung muss den Gesamtreward nennen. Der Text `UI_QUEST_REWARD_SUCCESS` „Received %d Gold.“ reicht nicht.
- Journal- und Tracker-Zeile (`JournalPanel.reward_text`, `ObjectivePanel.reward_lines`) nennen heute „(60 Gold)“. Für
  Mixed-Rewards braucht es eine Formulierung mit Materialien oder ohne Mengen.

---

## 6. Story und Altstand-Sicherheit (Audit E)
- **Hook:** `StoryService._settle` ruft bei einem Live-Abschluss (`announce`) `QuestRewardService.register_completion(character,
  quest)` auf. Es setzt `quest_reward_entitled.<id>`, wenn `turn_in_gold > 0`.
  - Für die zweite Quest muss die Bedingung „hat einen Reward“ lauten, also `turn_in_gold > 0 or not turn_in_items.is_empty()`.
    Eine Zeile, sonst ist nichts nötig.
  - `the_broken_cart` endet live über `DialogueService.finish(mara_road_end)` → `notify` → `_settle(announce = true)`.
- **R-B automatisch:**
  - Stände, in denen `the_broken_cart` schon `completed` ist (auch durch die v4→v5-Migration,
    `scripts/rpg/save/save_migrations.gd` `_v4_to_v5`), haben kein Entitled-Flag und bekommen nichts.
  - Stände, die die Quest unter T1–T3 abgeschlossen haben, also **vor** den Reward-Daten, haben ebenfalls kein Flag, weil
    `register_completion` damals `turn_in_gold = 0` sah. Korrekt.
- **`resettle`:** Es läuft mit `announce = false` und registriert nie (Test aus T1). `the_broken_cart` hat einen
  **kumulativen** Schritt (S2 Kisten). `resettle` kann ihn nachziehen, den letzten Schritt (`talk:mara_road_end`, nicht
  kumulativ) aber nicht ohne gespeicherten Fortschritt. Selbst wenn die Quest still abgeschlossen würde, entstünde kein Anspruch.
- **Keine Questfortschritte ändern:** Ziele, Schrittfolge, `cart_done` und Nachfolger bleiben unverändert. Es gibt keine
  Migration, v15 bleibt (neue Flags `quest_reward_*.the_broken_cart` sind freie `world.flags`).
- **Restrisiko:** Ein Stand, der genau zwischen `mara_road_end` und dem Eintreffen der Reward-Daten gespeichert wurde, bekommt
  nichts (R-B gewollt).

---

## 7. Minimaler Meilensteinplan (Audit F)

**M1 – Mixed-Reward-Vertrag und atomare Auszahlung**
- Systeme:
  - `StoryQuestDefinition.turn_in_items`
  - `QuestRewardService` (`register_completion`-Bedingung, Gesamtplatzprüfung, Auszahlung mit Rollback,
    `validate_quest`: Items existieren, stapelbar, keine Währung, Menge > 0)
  - noch keine Daten an `the_broken_cart`, nur Testdaten
- Risiken: Rollback-Ordnung, Stapelrechnung, unveränderter Edrin-Claim.
- Tests: neue Suite `quest_turnin_11` (teilweise Stapel, volle Slots, ein von zwei Materialien passt nicht, erzwungener
  Fehler mit Rollback, Gold zuletzt, Flag zuletzt, ein Save), dazu `quest_turnin_t1` (Edrin unverändert), `save`.
- Entscheidungen: keine (rein technisch).

**M2 – `the_broken_cart`-Daten und Mara-Anbindung**
- Systeme:
  - `data/story/the_broken_cart.tres` (Reward-Daten nach Freigabe)
  - `FlaskPanel` („Quest Rewards“-Knopf)
  - `StoryNpc.has_pending_reward` (Erreichbarkeitsregel)
  - `QuestRewardPanel._quest_card` (Materialzeilen) und Erfolgstext
  - Bei A1 entfällt der Flask-Teil.
- Risiken:
  - Maras Interaktionspriorität (`mara_welcome` zuerst)
  - Flask-Fenster unverändert nutzbar
  - Marker nie ohne Abholweg
- Tests: `quest_turnin_11` (Mara-Fluss: Abschluss auf der Road, Abholung in Haven, Rückweg ins Flask-Fenster), `consumables`
  (Flask unverändert), `quest_turnin_t2`/`t3` (Edrin unverändert), `haven`.
- Entscheidungen: Material und Menge, NPC (Mara vs. A1), Mara-Erweiterung freigeben.

**M3 – Marker, Journal, Tracker, UI-Abnahme**
- Systeme: Texte für Mixed-Rewards in `JournalPanel.reward_text`, `ObjectivePanel.reward_lines` und `localization/ui.csv`;
  Galerie-Bildschirme (Mara pending/claimed, Flask mit Knopf).
- Risiken: Textlänge im Tracker (HUD-Spaltenbreite), Lesbarkeit der Materialliste.
- Tests: `quest_turnin_11` (Texte), `hud`, `world_ui`; begrenzte Galerie `--only=…` bei 1080p und 720p/150 %.
- Entscheidungen: Formulierungen.

Ausgeschlossen in allen Phasen:
- Full-Suite, Prolog-/Haven-Gesamtloops, Crafting-Loops, Arena, Galerie-Gesamtlauf
- Readable-Fix, Multi-Service-Architektur, Edrin-Werte

---

## 8. Noch benötigte Designfreigaben
- **D1 – NPC:** `the_broken_cart` bei **Mara in Haven** (empfohlen, wenn Mara gewollt ist) · A1 `shelter_among_the_trees` bei
  Edrin (konfliktfrei) · A2 nicht empfohlen.
- **D2 – Mara-Erweiterung:** „Quest Rewards“-Knopf im Flask-Fenster (empfohlen) oder ein anderes Muster.
- **D3 – Reward:** 30 Gold + **3 Timber + 2 Stone** (empfohlen) · 4 Timber + 2 Stone (Old Storehouse komplett) · andere
  Werte.
- **D4 – Marker-Regel:** „?“ nur, wenn der Reward von genau diesem NPC-Fenster aus abholbar ist (empfohlen).
- **D5 – Texte:** Kartenzeilen, Erfolgsmeldung, Journal- und Tracker-Formulierung für Gold + Material; Meldung bei voller Tasche.
- **D6 – Reihenfolge der Abholung:** frühestens nach `mara_welcome` in Haven. Ob das als „Return to Mara Veyne“ im Tracker
  bereits ab der Old Road angezeigt werden soll, obwohl die Road-Mara nicht auszahlt, ist eine Designfrage.
