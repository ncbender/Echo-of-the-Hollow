# Loot & Progress Feedback 1.0 – Batch 3A (+ Read-only-Befund Batch 3B)

Beute und Fortschritt werden einheitlich, knapp und nur nach tatsächlicher Vergabe angezeigt: ein Loot-Feed unten rechts
für Items, Gold und Berufs-XP, eine kompakte Meldung für Hero- und Mastery-Level-ups mit kurzem Welt-Impuls. Technische
Zwischenstände und die Parry-Texte am Helden sind entfernt. Keine Änderung an Erträgen, XP, Levelschwellen, Mastery,
Kampf, Karten, Menüaufbau oder Save (v15). Keine neuen PNGs; die 136 vorhandenen sind unberührt.

Prüfregel dieses Batches: visuelle Prüfung nur 1920 × 1080 bei 100 %. 75/125/150 % übernimmt der Entwickler.

## 1. Umgesetzte Änderungen und verbindliche Ereignisquellen

| Ergebnis | verbindliche Quelle (erst nach Erfolg) | Anzeige jetzt | vorher |
|---|---|---|---|
| Item-Pickup in der Welt | `ItemPickup` nach `Inventory.add_item` → `bridge.item_received` | Loot-Feed | Loot-Feed (unverändert) |
| Gathering-Schritt | `ResourceGathering.complete_step` (Ergebnis `items`, `xp`, `error`) in `ResourceNode._report` | Feed: Ressource + „Woodcutting +n XP“; Fehler (z. B. „inventory full“) als Toast | Toast „Oak Tree 1/3 · +1 Timber · Woodcutting 2 · exhausted“ |
| Prompt am Knoten | – | „Hold to gather Oak Tree“ | „… (1/3)“ |
| Sentinel's Cache | `BossRewardService.claim` (Instanz) → `bridge.item_received` | nur Feed (Instanz-Rarity, Wort „Rare“) | Feed **und** Toast (doppelt) |
| Fundstück (Readable) | `Inventory.add_item` gelungen → `bridge.item_received` | Feed | Toast „Found: …“ |
| Story-Pickup | `StoryPickup.take()` == "" → `bridge.item_received` | Feed (ohne Item: Toast „Recovered: …“) | Toast „Recovered: …“ |
| Crafting / Salvage | `ProfessionService.craft`, `SalvageService.salvage` | Ergebniszeile im geöffneten Fenster (unverändert, kein Feed) | gleich |
| Questbelohnungen | `QuestRewardService.claim` | Belohnungsfenster (unverändert, kein Feed) | gleich |
| Hero-Level-up | `CharacterClasses.add_xp` → `leveled_up` (nur aktive Klasse) → `bridge.progress(&"hero")` | `ProgressNotice` + goldener Ring | Toast „Warrior reached level n“ (je Level) |
| Mastery-Level-up, Combo, Technik | `WeaponMastery.add_xp` → `leveled_up` / `path_unlocked` / `unlocked` → `bridge.progress(&"mastery")` | `ProgressNotice` + Rauten-Impuls | bis zu 3 Toasts je Level |
| „Counter!“, „Parry 1.2s“ | – | entfernt | Text unter den Dash-Segmenten |

- „Hero-Level“ ist im Spiel das Level der **aktiven Klasse** (`Character.classes`; dasselbe wie EXP-Balken und
  Level-Abzeichen). Es gibt kein separates Charakterlevel und es wurde keins eingeführt. Level-ups einer nicht aktiven
  Klasse (nur Debug-Vergaben) behalten den kurzen Toast.
- Neue Bridge-Signale (`PlayerProgressionBridge`): `profession_xp(profession_id, amount)` und
  `progress(kind, id, level, detail)`. Beide feuern nur innerhalb echter Vergaben (`add_xp`); Laden (`from_dict`),
  Klassenwechsel und `refresh_unlocks` lösen nichts aus.
- Unverändert sichtbar: alle Fehler- und Interaktionsmeldungen (volle Tasche, fehlende Werkstatt, gesperrte Aktionen,
  „Class changed“, „Class unlocked“, Quest-, Save-Meldungen).

## 2. Feed-, Bündelungs- und Anzeigezeitregeln (`LootFeed`)

- Zeile: Icon (Platzhalter-Art, ohne Mengen-Badge) · Name in Rarity-Farbe · „×n“ ab 2; Rarity-Wort für Nicht-Normal;
  Gold: „+40 Gold Coin“ in Warnfarbe; Berufs-XP: Farbstreifen des Berufs + „Mining  +12 XP“ (Caption, gedämpft).
- **Bündeln:** gleicher Schlüssel innerhalb von `BUNDLE_WINDOW` = 2,5 s seit Erscheinen der Zeile → Menge addiert,
  Ausblendung startet neu. Schlüssel: stapelbares Item + Rarity (`max_stack > 1`), bzw. Beruf bei XP. Einzelitems
  (`max_stack` 1: gewürfelte Ausrüstung, Uniques) bekommen immer eine eigene Zeile. Nur Anzeige – jede Vergabe
  wird genau einmal gemeldet (genau ein Emitter je Quelle, ein Listener).
- **Lebenszeit:** `LIFETIME` 4,0 s ab letzter Bündelung, Einblenden 0,15 s, Ausblenden 0,6 s; Höchstdauer einer Zeile
  2,5 + 4,0 = 6,5 s (spätere Ereignisse verlängern sie nicht weiter).
- **Begrenzung:** höchstens `max_rows` (5; 3 bei engem HUD) Zeilen. Weitere Ereignisse warten (max. 20, ebenfalls
  gebündelt); solange etwas wartet, hat die älteste Zeile höchstens 0,6 s Restzeit. Kein Layoutsprung: die Unterkante
  bleibt fest (Feed wächst nach oben, Abstand zum Save-Status unverändert).
- **Pause:** Feed und Meldung altern nicht, solange der Baum pausiert ist (HUD erbt die Pause).
- **Szenenwechsel:** Zeilen jünger als 2,0 s und Wartende kommen auf der nächsten Karte zurück (statischer
  Sitzungsspeicher, nur für denselben Charakter, nie im Save). Ältere Zeilen nicht.

## 3. Hero-/Mastery-Level-up-Verhalten (`ProgressNotice`, `LevelUpFx`)

- **Zusammenfassen:** alle `progress`-Ereignisse eines Frames werden je Art + Id vereint → eine Meldung
  „Level 56 → 58“ und ein Effekt statt einer Serie.
- **Reihenfolge:** Hero vor Mastery, nacheinander (2,6 s + 0,4 s Ausblenden je Meldung), nie übereinander; die
  Meldung sitzt in der unteren Mitte über den Toasts.
- **Hero:** Klassen-Emblem, Bronze-Akzent, „Warrior · Level n“; Zeile „+n talent points“ nur, wenn
  `TalentRules.points_at_level` zwischen altem und neuem Level wirklich Punkte ergibt (und die Klasse Bäume hat).
  Welt: flacher goldener Ring weitet sich von den Füßen, sechs Pixel-Funken steigen auf (0,9 s).
- **Mastery:** Icon der neuesten Combo bis zu diesem Level (`ComboIcons`), Cyan-Akzent, „Axe mastery · Level 2“,
  „New: Rough Hewing (L-L-L)“ nur bei echter Freischaltung (aus `path_unlocked` / `unlocked`). Welt: kleinere
  stahl-cyane Raute (eckig statt rund, 0,45 s).
- Effekte sind Kinder des Spielers (folgen ihm, enden mit der Karte), ganzpixlig, ohne Weichzeichnung, ohne Gameplay.
- **Dialog:** Solange die untere Mitte ausgeblendet ist, wartet die Meldung. **Szenenwechsel:** Wartende und eine
  noch junge Meldung kommen auf der nächsten Karte zurück (ohne Save).
- Keine permanente Mastery-Anzeige im HUD.

## 4. Ausgeführte Tests (automatisiert)

- `./tools/check_project.ps1`: **Startup check OK**.
- Neu `test_loot_progress_feedback` (9 Tests): Bündelung ohne Doppelzählung und Bündelfenster, Einzelitems getrennt,
  Begrenzung + Warteschlange (8 Ereignisse, nichts verloren), Gathering Erfolg vs. volle Tasche (Grund sichtbar,
  nichts im Feed, Prompt ohne Zähler), Hero 3 Level in einer Vergabe (eine Meldung, ein Effekt, Talentzeile nur wenn
  echt), Hero + Mastery gleichzeitig (nacheinander, Combo-Name, Rauten-Effekt, keine Level-Toasts), kein Feedback
  bei Klassenwechsel und nach Laden, Feed über Kartenwechsel, Pause.
- `-Suite "loot_progress_feedback,combat_hud,hud,hud_notifications,chapter_1_rare_reward,gathering_hold,
  gathering_steps,ui_layout_lock,hud_xp_bar,forge_ui,gameplay_polish,mastery,defense"`: **108 passed, 0 failed**
  (Endlauf; ein Zwischenlauf der neuen Suite hatte 3 Fehler – zwei Testfehler und ein echter Fehler: Combo-Namen
  gingen verloren, weil `PackedStringArray` als Wertkopie ergänzt wurde; behoben).
- `-Suite "old_road,hollowwood,roots_remember_m1,roots_remember_m2,side_quests,world_expansion_a,world_expansion_b,
  class_trials_m1"`: **78 passed, 0 failed**.
- Angepasst: `test_combat_hud` (Konterfenster und Parry-Cooldown zeigen keinen Text), `test_hud` (keine
  `defense_text`-Anzeige mehr).
- UI-Galerie 1080p/100 %: `hud_loot_feed`, `hud_level_hero`, `hud_level_mastery`, `hud_dash`, `hud_notifications`:
  **OK** (inkl. HUD-Überlappungsprüfung, keine Scriptfehler).
- Kein Asset-Validator (keine Assets geändert), keine Full-Suite, keine Gameplay-Loops.

## 5. Selbst angesehene Screenshots (1920 × 1080, 100 %)

- `hud_loot_feed`: Iron Ore ×3 (gebündelt), +40 Gold Coin, Mining +12 XP (gebündelt, gedämpft), Forged Blade,
  Duskleaf ×3; Feed über dem Save-Platz, rechts bündig.
- `hud_level_hero`: „Warrior · Level 56 → 58“, „+2 talent points“, goldener Ring mit Funken am Helden.
- `hud_level_mastery` (Lauf nach Hero): Hero-Meldung läuft, Mastery wartet – keine Überlagerung.
- `hud_level_mastery` (allein, Ausschnitt): „Axe mastery · Level 2“, „New: Rough Hewing (L-L-L)“, Combo-Icon,
  cyane Raute (danach tiefer gesetzt: Zentrum −6 statt −14, nicht erneut aufgenommen).

## 6. Read-only-Befund und Vorschlag für Batch 3B (Eliteangriffe, Parry-Telegraphen)

**Befund (nur gelesen, nichts geändert):**
1. **Elitegegner:** `EnemyConfig.rank` (Normal/Elite/Boss) ist laut Kommentar *nur Darstellung* (Zielrahmen „ELITE“).
   Einziger Elite: **Hardened Husk** (`rank = 1`), er nutzt die normalen Grunt-Angriffe. Elite-Modifikatoren oder
   eigene Eliteangriffe **existieren nicht**. Bosse (`rank = 2`): Grove Warden, Rootbound Sentinel, Bastion Guardian,
   Sanctum Warden, Passage Alpha.
2. **Angriffe/Parierbarkeit:** `AttackDefinition.defense_flags` (Bitflags Blockable 1, Parryable 2, Guard Breaking 4;
   Standard 3), Auswertung in `Hurtbox.hit_filter` / `DefenseComponent.resolve`; `is_unblockable()` = weder blockbar
   noch parierbar. Daten: `grunt_attacks` (Swipe 3, Slam 7), `grove_warden_attacks` (Strike 1 = nur blockbar,
   Slam 0 = unblockbar), `sentinel_attacks` (3 und 1).
3. **Datengetrieben unterscheidbar:** ja – parierbar = Flag 2, nicht parierbar = ohne Flag 2 (blockbar-only oder
   unblockbar). Kein Codepfad je Gegner nötig.
4. **Windup/Telegraph:** `Enemy.State.TELEGRAPH` = Startup-Phase der Angriffsdefinition (`startup`, z. B. 0,45 / 0,7 s);
   `CombatComponent.phase_progress()` liefert den Fortschritt. `EnemyView._draw_telegraph` zeichnet einen Kegel
   (Orange leicht / Rot schwer, Fülle wächst mit dem Fortschritt), `_draw_unblockable` einen violetten Zickzack-Rand
   + Welttext „!!“ + Warnsound (`unblockable_warn`). „Nur blockbar“ (Flag 1) sieht heute aus wie ein normaler Angriff.
5. **Form/Farbe:** im selben `_draw` über die Flags verzweigen, ohne Hitbox/Timing anzufassen:
   - parierbar: kurzer heller Kreuzfunke / Waffenblitz an der Waffenspitze in den letzten ~30 % des Startups
     (Weiß-Gold, Form „+“);
   - nicht parierbar: roter gebrochener Ring (Bogensegmente mit Lücken) bzw. gezackter Impuls um den Gegner während
     des ganzen Startups (Form „gebrochen“, Farbe Rot statt Violett);
   - unblockbar zusätzlich wie heute gezackt; „!!“-Text entfällt zugunsten der Form (Entscheidung offen).
6. **Betroffene Dateien (begrenzte Umsetzung):** `scripts/enemies/enemy_view.gd` (Zeichnung, Farbkonstanten),
   optional `scripts/fx/combat_fx.gd` (wiederverwendbarer Kreuzfunke), Tests `test_combat_feedback`, `test_enemy`,
   `test_defense` (nur lesend gegen Flags), ein Galerie-Fall mit eingefrorenem Telegraph je Flag-Kombination.
   Keine Änderung an `AttackDefinition`-Daten, `CombatComponent`, Hitboxen oder Timings.

**Vorschlag 3B (begrenzt):** Telegraph-Sprache nur in `EnemyView` aus `defense_flags` ableiten (drei Fälle: parierbar,
nur blockbar, unblockbar), eine Galerieansicht pro Fall, Tests prüfen nur „Darstellung folgt Flags, Timing gleich“.

**Offene Designfragen 3B:**
1. Elite-Angriffe gibt es nicht: Soll 3B nur die Telegraph-Sprache für vorhandene Gegner liefern, oder braucht es
   zuerst eine (separat zu entscheidende) Elite-Architektur?
2. „Nur blockbar, nicht parierbar“ (Warden Strike, Sentinel-Slam) – gleiche rote Sprache wie unblockbar oder eigene
   Zwischenstufe?
3. Soll der „!!“-Welttext bleiben (der Entwickler möchte weniger Text)?
4. Ab welchem Startup-Anteil erscheint der Kreuzfunke, damit er vor dem Treffer fair lesbar ist (Vorschlag: ab 70 %)?
5. Farbe Violett (heute unblockbar) vs. Rot (Designvorgabe) – Rot kollidiert mit dem schweren Telegraphen (Rot).

## 7. Offene Punkte für die gemeinsame Endabnahme

1. „PARRY“-Welttext beim gelungenen Parieren (`Player._on_parried`, Combat-Feedback 0.4) ist **geblieben** – er ist
   ein Kampfeffekt in der Welt, kein HUD-Text. Soll er ebenfalls entfallen?
2. Crafting/Salvage/Questbelohnungen erscheinen bewusst nicht zusätzlich im Feed (Ergebnis im Fenster). Passt das?
3. Gold-Zeile „+40 Gold Coin“ nutzt das Material-Platzhalter-Icon.
4. Anzeigezeiten (4 s Feed, 2,6 s Meldung) und das Bündelfenster (2,5 s) beim Spielen bewerten.
5. Mastery-Raute nach der Höhenkorrektur nicht erneut aufgenommen.
6. 75/125/150 % und Menü-/Außenreiter-Überlappungen mit dem Kampf-HUD: beim Entwickler.

## 8. Commit

Siehe unten (nachgetragen).
